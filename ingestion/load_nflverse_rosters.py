import json
from uuid import uuid4

import pandas as pd
from snowflake.connector.pandas_tools import write_pandas

from load_manual_sources import PROJECT_ROOT, get_connection, read_source


SOURCE_DIR = PROJECT_ROOT / "data" / "raw" / "nflverse"

# Keep the exact source column order observed during inspection.
SOURCE_COLUMNS = [
    "season", "team", "position", "depth_chart_position",
    "jersey_number", "status", "full_name", "first_name",
    "last_name", "birth_date", "height", "weight", "college",
    "gsis_id", "espn_id", "sportradar_id", "yahoo_id",
    "rotowire_id", "pff_id", "pfr_id", "fantasy_data_id",
    "sleeper_id", "years_exp", "headshot_url", "ngs_position",
    "week", "game_type", "status_description_abbr", "football_name",
    "esb_id", "gsis_it_id", "smart_id", "entry_year",
    "rookie_year", "draft_club", "draft_number",
]

# Keep season and weekly records in separate destination tables.
SOURCE_GROUPS = {
    "rosters": ("roster", "NFLVERSE_ROSTERS"),
    "weekly_rosters": ("roster_weekly", "NFLVERSE_WEEKLY_ROSTERS"),
}


def prepare_source(source_group: str, prefix: str, season: int):
    """Validate one archived source and prepare its raw-table columns."""
    filename = f"{prefix}_{season}.csv"
    path = SOURCE_DIR / source_group / filename

    # Reuse strict CSV reading and hashing without cleaning source values.
    file_hash, rows = read_source(str(path), SOURCE_COLUMNS)

    metadata_path = path.with_name(f"{filename}.metadata.json")
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))

    if metadata["sha256"] != file_hash:
        raise ValueError(f"{filename}: archived checksum mismatch.")

    df = pd.DataFrame(rows, columns=SOURCE_COLUMNS)

    if not df["season"].eq(str(season)).all():
        raise ValueError(f"{filename}: unexpected source season values.")

    # Match Snowflake's uppercase column names.
    # This changes column labels only, not source values.
    df.columns = [column.upper() for column in SOURCE_COLUMNS]

    df["SOURCE_FILE_SEASON"] = season
    df["SOURCE_FILENAME"] = filename
    df["SOURCE_FILE_SHA256"] = file_hash
    df["SOURCE_ROW_NUMBER"] = range(1, len(df) + 1)

    print(f"VALIDATED: {filename} — {len(df):,} rows.")
    return filename, file_hash, df


def stored_records(cursor, table: str, season: int):
    """Return file hashes and row numbers for one stored source season."""
    # Table names are supplied only by the fixed mapping or generated locally.
    cursor.execute(
        f"""
        SELECT SOURCE_FILE_SHA256, SOURCE_ROW_NUMBER
        FROM {table}
        WHERE SOURCE_FILE_SEASON = %s
        ORDER BY SOURCE_ROW_NUMBER
        """,
        (season,),
    )
    return cursor.fetchall()


def load_source(connection, table, season, filename, file_hash, df):
    """Bulk-load one file through a temporary buffer before committing RAW."""
    expected = [
        (file_hash, row_number)
        for row_number in range(1, len(df) + 1)
    ]

    try:
        with connection.cursor() as cursor:
            existing = stored_records(cursor, table, season)

            if existing:
                if existing != expected:
                    raise ValueError(
                        f"{filename}: a different or incomplete load exists. "
                        "Stopped without replacing data."
                    )

                connection.commit()
                print(f"SKIPPED: {filename} — existing load verified.")
                return

            # Create the buffer before opening the RAW insert transaction.
            # Snowflake DDL can implicitly commit an active transaction.
            buffer_table = f"ROSTER_BUFFER_{uuid4().hex.upper()}"
            cursor.execute(
                f"CREATE TEMPORARY TABLE {buffer_table} LIKE {table}"
            )

        # Bulk upload into the buffer, leaving the destination untouched.
        success, _, uploaded_rows, _ = write_pandas(
            conn=connection,
            df=df,
            table_name=buffer_table,
            chunk_size=20000,
            auto_create_table=False,
            overwrite=False,
            on_error="ABORT_STATEMENT",
        )

        if not success or uploaded_rows != len(df):
            raise ValueError(f"{filename}: buffer upload failed.")

        with connection.cursor() as cursor:
            if stored_records(cursor, buffer_table, season) != expected:
                raise ValueError(f"{filename}: buffer verification failed.")

        # Finish buffer work before beginning the destination transaction.
        connection.commit()

        columns = ", ".join(f'"{column}"' for column in df.columns)

        with connection.cursor() as cursor:
            cursor.execute("BEGIN TRANSACTION")

            # Recheck the destination before inserting.
            if stored_records(cursor, table, season):
                raise ValueError(
                    f"{filename}: destination changed during loading. "
                    "Stop other loader processes before retrying."
                )

            # LOADED_AT is populated by the destination table's default.
            cursor.execute(
                f"""
                INSERT INTO {table} ({columns})
                SELECT {columns}
                FROM {buffer_table}
                """
            )

            if stored_records(cursor, table, season) != expected:
                raise ValueError(f"{filename}: RAW verification failed.")

        connection.commit()
        print(f"LOADED: {filename} — {len(df):,} rows.")

        # Buffer tables are automatically removed when the session closes.

    except Exception:
        connection.rollback()
        raise


def main() -> None:
    """Load season and weekly snapshots sequentially, one file at a time."""
    # Check that all required archive files exist before connecting.
    for source_group, (prefix, _) in SOURCE_GROUPS.items():
        for season in range(2015, 2026):
            path = SOURCE_DIR / source_group / f"{prefix}_{season}.csv"

            for required_path in (
                path,
                path.with_name(f"{path.name}.metadata.json"),
            ):
                if not required_path.is_file():
                    raise FileNotFoundError(
                        f"Required archive file not found: {required_path}"
                    )

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("USE SECONDARY ROLES NONE")

        for source_group, (prefix, table) in SOURCE_GROUPS.items():
            for season in range(2015, 2026):
                filename, file_hash, df = prepare_source(
                    source_group, prefix, season
                )
                load_source(
                    connection, table, season, filename, file_hash, df
                )
                del df

    print("Roster ingestion completed.")


if __name__ == "__main__":
    main()
