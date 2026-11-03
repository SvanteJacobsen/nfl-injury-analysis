from uuid import uuid4

import pandas as pd
from snowflake.connector.pandas_tools import write_pandas

from load_manual_sources import PROJECT_ROOT, get_connection, read_source


SOURCE_PATH = PROJECT_ROOT / "data" / "raw" / "players.csv"

DATABASE = "NFL_INJURY_ANALYSIS"
SCHEMA = "RAW"
TABLE = f"{DATABASE}.{SCHEMA}.NFLVERSE_PLAYERS"

# Pin the exact snapshot reviewed for this project.
EXPECTED_SHA256 = (
    "dd4e38586b4d9982098760b823d87367824"
    "a1a58c80a1fb77f00273b73ee33e5"
)

# Preserve the original source column order and values.
SOURCE_COLUMNS = [
    "gsis_id", "display_name", "common_first_name", "first_name",
    "last_name", "short_name", "football_name", "suffix",
    "esb_id", "nfl_id", "pfr_id", "pff_id", "otc_id",
    "espn_id", "smart_id", "birth_date", "position_group",
    "position", "ngs_position_group", "ngs_position",
    "height", "weight", "headshot", "college_name",
    "college_conference", "jersey_number", "rookie_season",
    "last_season", "latest_team", "status", "ngs_status",
    "ngs_status_short_description", "years_of_experience",
    "pff_position", "pff_status", "draft_year", "draft_round",
    "draft_pick", "draft_team",
]


def prepare_source():
    """Validate the archived CSV and add record-level provenance."""
    file_hash, rows = read_source(str(SOURCE_PATH), SOURCE_COLUMNS)

    if file_hash != EXPECTED_SHA256:
        raise ValueError(
            "players.csv does not match the reviewed source snapshot. "
            "Stopped without loading data."
        )

    if not rows:
        raise ValueError("players.csv contains no records.")

    df = pd.DataFrame(rows, columns=SOURCE_COLUMNS)

    # Change column labels only; preserve all original source values.
    df.columns = [column.upper() for column in SOURCE_COLUMNS]

    df["SOURCE_FILENAME"] = SOURCE_PATH.name
    df["SOURCE_FILE_SHA256"] = file_hash
    df["SOURCE_ROW_NUMBER"] = range(1, len(df) + 1)

    print(f"VALIDATED: {SOURCE_PATH.name} — {len(df):,} rows.")
    return file_hash, df


def stored_records(cursor, table):
    """Return the provenance records stored in a fixed project table."""
    # Table identifiers come only from constants or a generated UUID.
    cursor.execute(
        f"""
        SELECT SOURCE_FILE_SHA256, SOURCE_ROW_NUMBER
        FROM {table}
        ORDER BY SOURCE_ROW_NUMBER, SOURCE_FILE_SHA256
        """
    )
    return cursor.fetchall()


def load_source(connection, file_hash, df):
    """Verify a temporary upload before inserting into the RAW table."""
    expected = [
        (file_hash, row_number)
        for row_number in range(1, len(df) + 1)
    ]

    try:
        with connection.cursor() as cursor:
            existing = stored_records(cursor, TABLE)

            if existing:
                if existing != expected:
                    raise ValueError(
                        "A different or incomplete player-register load exists. "
                        "Stopped without replacing data."
                    )

                connection.commit()
                print("SKIPPED: players.csv — existing load verified.")
                return

            # Create the temporary table before the RAW insert transaction.
            buffer_name = f"PLAYERS_BUFFER_{uuid4().hex.upper()}"
            buffer_table = f"{DATABASE}.{SCHEMA}.{buffer_name}"

            cursor.execute(
                f"CREATE TEMPORARY TABLE {buffer_table} LIKE {TABLE}"
            )

        # Upload to the temporary table, leaving RAW untouched.
        success, _, uploaded_rows, _ = write_pandas(
            conn=connection,
            df=df,
            table_name=buffer_name,
            database=DATABASE,
            schema=SCHEMA,
            chunk_size=20000,
            auto_create_table=False,
            overwrite=False,
            on_error="ABORT_STATEMENT",
        )

        if not success or uploaded_rows != len(df):
            raise ValueError("Player-register buffer upload failed.")

        with connection.cursor() as cursor:
            if stored_records(cursor, buffer_table) != expected:
                raise ValueError("Player-register buffer verification failed.")

        connection.commit()

        columns = ", ".join(f'"{column}"' for column in df.columns)

        with connection.cursor() as cursor:
            cursor.execute("BEGIN TRANSACTION")

            # Detect a destination change before inserting.
            if stored_records(cursor, TABLE):
                raise ValueError(
                    "Destination changed during loading. "
                    "Stop other loader processes before retrying."
                )

            # The destination default supplies LOADED_AT.
            cursor.execute(
                f"""
                INSERT INTO {TABLE} ({columns})
                SELECT {columns}
                FROM {buffer_table}
                """
            )

            if stored_records(cursor, TABLE) != expected:
                raise ValueError("Player-register RAW verification failed.")

        connection.commit()
        print(f"LOADED: players.csv — {len(df):,} rows.")

    except Exception:
        connection.rollback()
        raise


def main():
    """Load one reviewed player-register snapshot."""
    # Validate locally before opening a Snowflake connection.
    file_hash, df = prepare_source()

    with get_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("USE SECONDARY ROLES NONE")

        load_source(connection, file_hash, df)

    print("Player-register ingestion completed.")


if __name__ == "__main__":
    main()
