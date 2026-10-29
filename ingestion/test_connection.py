import os
from pathlib import Path

import snowflake.connector
from dotenv import load_dotenv


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    """Load local configuration and verify the Snowflake connection."""
    env_path = PROJECT_ROOT / ".env"

    if not env_path.is_file():
        raise FileNotFoundError(f"Configuration file not found: {env_path}")

    # Load configuration without overwriting existing environment variables.
    load_dotenv(env_path, interpolate=False)

    # Map Snowflake connection parameters to environment variable names.
    variable_names = {
        "account": "SNOWFLAKE_ACCOUNT",
        "user": "SNOWFLAKE_USER",
        "password": "SNOWFLAKE_PASSWORD",
        "role": "SNOWFLAKE_ROLE",
        "warehouse": "SNOWFLAKE_WAREHOUSE",
        "database": "SNOWFLAKE_DATABASE",
        "schema": "SNOWFLAKE_SCHEMA",
    }

    # Report missing variable names without printing credentials.
    missing = [
        name
        for name in variable_names.values()
        if not os.getenv(name)
    ]
    if missing:
        raise ValueError(
            f"Missing configuration variables: {', '.join(missing)}"
        )

    connection_parameters = {
        parameter: os.environ[variable]
        for parameter, variable in variable_names.items()
    }

    print("Connecting to Snowflake...")

    # Context managers close the cursor and connection after the test.
    with snowflake.connector.connect(
        **connection_parameters,
        login_timeout=60,
        validate_default_parameters=True,
    ) as connection:
        with connection.cursor() as cursor:
            # Verify access without creating or modifying any objects.
            cursor.execute("USE SECONDARY ROLES NONE")
            cursor.execute("""
                SELECT
                    CURRENT_ROLE(),
                    CURRENT_WAREHOUSE(),
                    CURRENT_DATABASE(),
                    CURRENT_SCHEMA()
            """)
            result = cursor.fetchone()

            labels = ("Role", "Warehouse", "Database", "Schema")

            print("\nConnection successful.")
            for label, value in zip(labels, result):
                print(f"{label}: {value}")


if __name__ == "__main__":
    main()
