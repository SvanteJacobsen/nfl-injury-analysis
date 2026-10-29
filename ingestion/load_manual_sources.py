import csv
import hashlib
import io
import os
from pathlib import Path

import snowflake.connector
from dotenv import load_dotenv


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = PROJECT_ROOT / "data" / "raw"

# Define the expected CSV headers and their destination tables.
SOURCES = {
    "ir_transactions.csv": {
        "table": "IR_TRANSACTIONS",
        "headers": [
            "calendar_year", "season", "from", "to",
            "date", "player_name", "position", "transaction_type",
        ],
        "columns": [
            "CALENDAR_YEAR", "SEASON", "FROM_TEAM", "TO_TEAM",
            "DATE", "PLAYER_NAME", "POSITION", "TRANSACTION_TYPE",
        ],
    },
    "concussions.csv": {
        "table": "CONCUSSIONS",
        "headers": [
            "year", "preseason_practice", "preseason_game",
            "preseason_per_game", "regular_season_practice",
            "regular_season_game", "regular_season_per_game",
            "total_concussions",
        ],
        "columns": [
            "YEAR", "PRESEASON_PRACTICE", "PRESEASON_GAME",
            "PRESEASON_PER_GAME", "REGULAR_SEASON_PRACTICE",
            "REGULAR_SEASON_GAME", "REGULAR_SEASON_PER_GAME",
            "TOTAL_CONCUSSIONS",
        ],
    },
}


def read_source(filename: str, expected_headers: list[str]):
    """Read and validate a CSV without cleaning its source values."""
    path = RAW_DIR / filename

    # Hash and parse the same bytes so the fingerprint matches the data.
    content = path.read_bytes()
    file_hash = hashlib.sha256(content).hexdigest()

    # utf-8-sig also handles CSV files containing a UTF-8 byte-order mark.
    text = content.decode("utf-8-sig")
    reader = csv.reader(io.StringIO(text, newline=""), strict=True)
    headers = next(reader, None)

    if headers != expected_headers:
        raise ValueError(
            f"{filename}: unexpected headers.\n"
            f"Expected: {expected_headers}\n"
            f"Received: {headers}"
        )

    rows = list(reader)

    if not rows:
        raise ValueError(f"{filename}: no data rows found.")

    # Reject malformed records instead of silently dropping or shifting values.
    for row_number, row in enumerate(rows, start=1):
        if len(row) != len(expected_headers):
            raise ValueError(
                f"{filename}: data row {row_number} has "
                f"{len(row)} fields; expected {len(expected_headers)}."
            )

    return file_hash, rows


def get_connection():
    """Read local configuration and open a Snowflake connection."""
    env_path = PROJECT_ROOT / ".env"
    if not env_path.is_file():
        raise FileNotFoundError(f"Configuration file not found: {env_path}")

    load_dotenv(env_path, interpolate=False)

    parameters = (
        "account", "user", "password",
        "role", "warehouse", "database", "schema",
    )
    config = {}

    for parameter in parameters:
        variable = f"SNOWFLAKE_{parameter.upper()}"
        value = os.getenv(variable)

        if not value:
            raise ValueError(f"Missing configuration variable: {variable}")

        config[parameter] = value

    # Disable autocommit so each file can be committed or rolled back as a unit.
    return snowflake.connector.connect(
        **config,
        autocommit=False,
        login_timeout=60,
        validate_default_parameters=True,
    )


def load_source(connection, filename, specification, file_hash, rows):
    """Load one file, or skip it if its row sequence is already present."""
    # Table and column names come exclusively from the fixed SOURCES mapping.
    table = specification["table"]

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                f"SELECT DISTINCT SOURCE_FILE_SHA256 FROM {table}"
            )
            existing_hashes = {record[0] for record in cursor.fetchall()}

            # Revised snapshots need an explicit replacement/versioning policy.
            if existing_hashes - {file_hash}:
                raise ValueError(
                    f"{table}: another source version already exists. "
                    "Stopped without replacing existing data."
                )

            expected_numbers = list(range(1, len(rows) + 1))

            if file_hash in existing_hashes:
                cursor.execute(
                    f"SELECT SOURCE_ROW_NUMBER FROM {table} "
                    "WHERE SOURCE_FILE_SHA256 = %s "
                    "ORDER BY SOURCE_ROW_NUMBER",
                    (file_hash,),
                )
                actual_numbers = [record[0] for record in cursor.fetchall()]

                if actual_numbers != expected_numbers:
                    raise ValueError(
                        f"{table}: existing load has missing or duplicate "
                        "row numbers. Manual investigation required."
                    )

                connection.commit()
                print(f"SKIPPED: {filename} — {len(rows):,} rows already loaded.")
                return

            columns = specification["columns"] + [
                "SOURCE_FILENAME",
                "SOURCE_FILE_SHA256",
                "SOURCE_ROW_NUMBER",
            ]
            quoted_columns = ", ".join(f'"{name}"' for name in columns)
            placeholders = ", ".join(["%s"] * len(columns))

            insert_sql = (
                f"INSERT INTO {table} ({quoted_columns}) "
                f"VALUES ({placeholders})"
            )

            records = [
                tuple(row) + (filename, file_hash, row_number)
                for row_number, row in enumerate(rows, start=1)
            ]

            # Insert in manageable batches within the same transaction.
            for start in range(0, len(records), 1000):
                cursor.executemany(insert_sql, records[start:start + 1000])

            # Verify the complete row sequence before committing the file.
            cursor.execute(
                f"SELECT SOURCE_ROW_NUMBER FROM {table} "
                "WHERE SOURCE_FILE_SHA256 = %s "
                "ORDER BY SOURCE_ROW_NUMBER",
                (file_hash,),
            )
            actual_numbers = [record[0] for record in cursor.fetchall()]

            if actual_numbers != expected_numbers:
                raise ValueError(f"{table}: post-load verification failed.")

        connection.commit()
        print(f"LOADED: {filename} — {len(rows):,} rows.")

    except Exception:
        connection.rollback()
        raise


def main() -> None:
    """Validate both files locally, then load them one at a time."""
    prepared_sources = []

    for filename, specification in SOURCES.items():
        file_hash, rows = read_source(filename, specification["headers"])
        prepared_sources.append((filename, specification, file_hash, rows))
        print(f"VALIDATED: {filename} — {len(rows):,} rows.")

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("USE SECONDARY ROLES NONE")

        for source in prepared_sources:
            load_source(connection, *source)

    print("Ingestion completed.")


if __name__ == "__main__":
    main()
