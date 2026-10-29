import json

from load_manual_sources import PROJECT_ROOT, get_connection, read_source


SOURCE_DIR = PROJECT_ROOT / "data" / "raw" / "nflverse" / "injuries"

# Combined source columns across the observed file structures.
SOURCE_COLUMNS = [
    "season", "season_type", "game_type", "team", "week",
    "gsis_id", "position", "full_name", "first_name", "last_name",
    "report_primary_injury", "report_secondary_injury", "report_status",
    "practice_primary_injury", "practice_secondary_injury",
    "practice_status", "date_modified",
]

# Inspect every stored record for one source-file season.
VERIFY_SQL = """
    SELECT SOURCE_FILE_SHA256, SOURCE_ROW_NUMBER
    FROM NFLVERSE_INJURIES
    WHERE SOURCE_FILE_SEASON = %s
    ORDER BY SOURCE_ROW_NUMBER
"""


def prepare_source(season: int):
    """Validate one archived CSV and map it to the raw table structure."""
    filename = f"injuries_{season}.csv"
    path = SOURCE_DIR / filename

    # Use the exact column structures observed during source inspection.
    absent_column = "date_modified" if season == 2025 else "season_type"
    headers = [
        column for column in SOURCE_COLUMNS
        if column != absent_column
    ]

    # Reuse the existing CSV validation and file fingerprint calculation.
    file_hash, rows = read_source(str(path), headers)

    metadata_path = SOURCE_DIR / f"{filename}.metadata.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))

    if metadata["sha256"] != file_hash:
        raise ValueError(f"{filename}: archived checksum mismatch.")

    records = []

    for row_number, row in enumerate(rows, start=1):
        source = dict(zip(headers, row))

        if source["season"] != str(season):
            raise ValueError(
                f"{filename}: unexpected season in data row {row_number}."
            )

        # Missing source columns become SQL NULL.
        # Existing empty strings and other source values are preserved.
        values = tuple(source.get(column) for column in SOURCE_COLUMNS)

        records.append(
            values + (season, filename, file_hash, row_number)
        )

    print(f"VALIDATED: {filename} — {len(records):,} rows.")
    return season, filename, file_hash, records


def load_season(connection, season, filename, file_hash, records):
    """Load one season atomically, or skip an existing complete load."""
    expected = [
        (file_hash, row_number)
        for row_number in range(1, len(records) + 1)
    ]

    try:
        with connection.cursor() as cursor:
            cursor.execute(VERIFY_SQL, (season,))
            existing = cursor.fetchall()

            if existing:
                if existing != expected:
                    raise ValueError(
                        f"{filename}: a different or incomplete load exists. "
                        "Stopped without replacing data."
                    )

                connection.commit()
                print(f"SKIPPED: {filename} — existing load verified.")
                return

            # Identifiers come from the fixed column list above.
            columns = [column.upper() for column in SOURCE_COLUMNS] + [
                "SOURCE_FILE_SEASON",
                "SOURCE_FILENAME",
                "SOURCE_FILE_SHA256",
                "SOURCE_ROW_NUMBER",
            ]
            quoted_columns = ", ".join(f'"{name}"' for name in columns)
            placeholders = ", ".join(["%s"] * len(columns))

            insert_sql = (
                f"INSERT INTO NFLVERSE_INJURIES ({quoted_columns}) "
                f"VALUES ({placeholders})"
            )

            # Keep every batch for this season in the same transaction.
            for start in range(0, len(records), 1000):
                cursor.executemany(insert_sql, records[start:start + 1000])

            cursor.execute(VERIFY_SQL, (season,))
            if cursor.fetchall() != expected:
                raise ValueError(f"{filename}: post-load verification failed.")

        connection.commit()
        print(f"LOADED: {filename} — {len(records):,} rows.")

    except Exception:
        connection.rollback()
        raise


def main() -> None:
    """Validate all source files before loading them sequentially."""
    prepared_sources = [
        prepare_source(season)
        for season in range(2015, 2026)
    ]

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("USE SECONDARY ROLES NONE")

        for source in prepared_sources:
            load_season(connection, *source)

    print("NFLverse injury ingestion completed.")


if __name__ == "__main__":
    main()
