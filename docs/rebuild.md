# Rebuild guide

This guide describes how to recreate the implemented pipeline
in a new Snowflake account.

Current scope:

- Manually collected IR transactions.
- Manually collected concussion statistics.
- nflverse injury reports for seasons 2015–2025.
- Python ingestion into Snowflake RAW tables.

Transformations, analytical models, and dashboards are not yet included.

## 1. Prerequisites

- A local copy of the project repository.
- Python 3.13.5, the version used during development.
- A Snowflake account with access to SYSADMIN and SECURITYADMIN.
- Access to the original nflverse archive, or internet access to
  download the currently published source files.

The repository includes the two manually collected CSV snapshots.
It excludes credentials and the installed Python environment.

The original nflverse snapshots and metadata are backed up in a private
Google Drive archive maintained by the project author. Restore them to
data/raw/nflverse/injuries/ before rebuilding with the original snapshots.

Archive filename:

nflverse_injuries_2015-2025_snapshot_2026-10-29.zip

Other users can run the download script to retrieve the currently
published files, which may differ from the original snapshots.
The private archive's link and account details are not included
in this repository.

## 2. Verify the source files

### Manually collected sources

The repository includes:

- data/raw/ir_transactions.csv
- data/raw/concussions.csv

Use these files unchanged when rebuilding. Do not remove duplicates,
edit values, or re-export them before loading.

Expected data rows, excluding headers:

| Source file | Rows |
|---|---:|
| ir_transactions.csv | 5,356 |
| concussions.csv | 10 |

The IR snapshot contains 75 exact duplicate rows beyond their first
occurrences. These are intentionally preserved in RAW.

These counts describe the source snapshots. They do not prove that
the original data collection is complete.

### nflverse injury reports

Extract the original archive and place its contents in:

data/raw/nflverse/injuries/

The directory must contain 22 files: eleven CSV files and eleven
matching metadata files.

Each season from 2015 through 2025 requires:

- injuries_YEAR.csv
- injuries_YEAR.csv.metadata.json

Each metadata file records:

- Source filename and download URL.
- Download timestamp in UTC.
- GitHub source asset ID and update timestamp.
- File size in bytes.
- SHA-256 checksum.

Restore both the CSV and its matching metadata file. Ensure that
extraction does not introduce an additional nested injuries directory.

If the archive is unavailable, the download script can retrieve the
currently published files. Those files may differ from the snapshots
used in the original build. A fresh download is therefore not a
guaranteed restoration of the original data.

## 3. Recreate the Python environment

Open a terminal in the project root.

The following commands are for macOS/Linux:

```bash
python3 --version
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python -m pip check
```

Confirm that python3 uses the intended Python version before creating
the environment.

The pinned dependencies were captured on the development machine.
Another operating system or Python version may require compatibility
checks.

requirements.in lists the direct dependencies.
requirements.txt records the installed dependency versions.

## 4. Inspect the local sources

Inspect the manually collected files:

```bash
python ingestion/inspect_sources.py
```

If the nflverse files have been restored from the original archive,
inspect them:

```bash
python ingestion/inspect_nflverse_injuries.py
```

These scripts report file structure and basic quality information.
They do not modify source files.

### Downloading nflverse data when needed

Skip this download step if the original archive has already been
restored.

To check published file availability:

```bash
python ingestion/inspect_nflverse_release.py
```

To download files that are not already archived locally:

```bash
python ingestion/download_nflverse_injuries.py
```

Then inspect the downloaded files:

```bash
python ingestion/inspect_nflverse_injuries.py
```

The downloader preserves existing local snapshots and verifies them
against their saved checksums. It does not automatically replace them
when newer source versions are published.

If a CSV or its matching metadata file is missing, or a checksum
differs, investigate the archive before proceeding.

### Observed nflverse source limitations

The following observations apply to the original project snapshots:

- No preseason records were observed in the downloaded files.
- The 2023 file contains REG and WC records only.
- The 2018 conference round contains records for three teams;
  the reason has not yet been established.
- The 2025 file includes season_type but omits date_modified.
- The 2015–2024 files include date_modified but omit season_type.

All inspected seasons contain records for 32 teams and all regular
season week numbers. This does not establish that every expected
team-week report or player record is present.

Injury-report rows must not be interpreted automatically as distinct
injury events.

## 5. Create the Snowflake infrastructure

In a Snowflake SQL worksheet, run the complete contents of these files
in this order:

1. infrastructure/setup_snowflake.sql
2. infrastructure/setup_roles.sql
3. infrastructure/create_raw_tables.sql
4. infrastructure/create_raw_injuries.sql

The scripts create:

| Object | Name |
|---|---|
| Warehouse | NFL_ANALYTICS_WH |
| Database | NFL_INJURY_ANALYSIS |
| Raw schema | RAW |
| Loader role | NFL_LOADER_ROLE |
| IR table | RAW.IR_TRANSACTIONS |
| Concussion table | RAW.CONCUSSIONS |
| nflverse injury table | RAW.NFLVERSE_INJURIES |

All RAW tables belong to the NFL_INJURY_ANALYSIS database.

The role setup assigns NFL_LOADER_ROLE to the user running the script.

The warehouse is configured as X-Small, with automatic resume and
automatic suspension after approximately 60 seconds of inactivity.

The setup scripts preserve existing objects. They do not automatically
migrate an existing table whose structure differs from the saved SQL.

## 6. Configure the connection

Copy .env.example to .env in the project root.

Update these variables for the new account:

- SNOWFLAKE_ACCOUNT
- SNOWFLAKE_USER
- SNOWFLAKE_PASSWORD

Use the organization-account identifier for SNOWFLAKE_ACCOUNT.
Do not include https:// or the .snowflakecomputing.com suffix.

Keep these project settings:

```dotenv
SNOWFLAKE_ROLE=NFL_LOADER_ROLE
SNOWFLAKE_WAREHOUSE=NFL_ANALYTICS_WH
SNOWFLAKE_DATABASE=NFL_INJURY_ANALYSIS
SNOWFLAKE_SCHEMA=RAW
```

Never commit .env or upload it to GitHub.
Keep only placeholder values in .env.example.

Authentication must comply with the new account's settings, including
MFA where required.

Test the connection:

```bash
python ingestion/test_connection.py
```

Confirm that the output shows the project role, warehouse, database,
and schema listed above.

## 7. Load the manually collected sources

Run:

```bash
python ingestion/load_manual_sources.py
```

For empty destination tables, expect:

- 5,356 rows loaded into RAW.IR_TRANSACTIONS.
- 10 rows loaded into RAW.CONCUSSIONS.

The loader preserves source text, empty strings, and duplicate records.
The CSV headers from and to map to FROM_TEAM and TO_TEAM.

Each row receives:

- SOURCE_FILENAME
- SOURCE_FILE_SHA256
- SOURCE_ROW_NUMBER
- LOADED_AT

Row numbering starts at 1 for the first CSV data record, excluding
the header. A CSV record may span multiple physical lines.

Each file is committed separately. If a file fails before its commit,
its inserts are rolled back. Previously committed files remain loaded.

## 8. Load nflverse injury reports

Run:

```bash
python ingestion/load_nflverse_injuries.py
```

The loader imports shared connection and CSV-reading functions from
ingestion/load_manual_sources.py. Both scripts must remain available.

It validates all eleven local files before starting the load, including:

- Expected CSV headers and field counts.
- Checksums against the archived metadata.
- Season values against the season expected from the filename.

Source values are preserved as text. Columns absent from a source file
receive SQL NULL:

- SEASON_TYPE is NULL for the 2015–2024 snapshots.
- DATE_MODIFIED is NULL for the 2025 snapshot.

Each row also receives SOURCE_FILE_SEASON and the four metadata fields
used by the manual-source loader.

Each season is committed separately. A later failure does not roll back
earlier committed seasons.

Expected row counts for the original snapshots:

| Season | Rows |
|---|---:|
| 2015 | 5,232 |
| 2016 | 5,115 |
| 2017 | 5,104 |
| 2018 | 5,133 |
| 2019 | 5,392 |
| 2020 | 5,661 |
| 2021 | 5,587 |
| 2022 | 5,682 |
| 2023 | 5,599 |
| 2024 | 6,215 |
| 2025 | 6,068 |
| Total | 60,788 |

Newly downloaded source versions may have different counts or column
structures. Investigate differences rather than treating updated
sources as equivalent to the original snapshots.

## 9. Verify the loaded tables

Run the following SQL in Snowflake:

```sql
USE ROLE NFL_LOADER_ROLE;
USE SECONDARY ROLES NONE;
USE WAREHOUSE NFL_ANALYTICS_WH;

-- Verify the manually collected source snapshots.
SELECT
    'IR_TRANSACTIONS' AS source_table,
    COUNT(*) AS row_count,
    COUNT(DISTINCT SOURCE_FILE_SHA256) AS file_versions,
    COUNT(DISTINCT SOURCE_ROW_NUMBER) AS distinct_row_numbers,
    MIN(SOURCE_ROW_NUMBER) AS first_row_number,
    MAX(SOURCE_ROW_NUMBER) AS last_row_number
FROM NFL_INJURY_ANALYSIS.RAW.IR_TRANSACTIONS

UNION ALL

SELECT
    'CONCUSSIONS',
    COUNT(*),
    COUNT(DISTINCT SOURCE_FILE_SHA256),
    COUNT(DISTINCT SOURCE_ROW_NUMBER),
    MIN(SOURCE_ROW_NUMBER),
    MAX(SOURCE_ROW_NUMBER)
FROM NFL_INJURY_ANALYSIS.RAW.CONCUSSIONS;
```

Expected results:

| Table | Rows | File versions | Distinct row numbers | First | Last |
|---|---:|---:|---:|---:|---:|
| IR_TRANSACTIONS | 5,356 | 1 | 5,356 | 1 | 5,356 |
| CONCUSSIONS | 10 | 1 | 10 | 1 | 10 |

Then verify nflverse files by season:

```sql
SELECT
    SOURCE_FILE_SEASON,
    COUNT(*) AS row_count,
    COUNT(DISTINCT SOURCE_FILE_SHA256) AS file_versions,
    COUNT(DISTINCT SOURCE_ROW_NUMBER) AS distinct_row_numbers,
    MIN(SOURCE_ROW_NUMBER) AS first_row_number,
    MAX(SOURCE_ROW_NUMBER) AS last_row_number
FROM NFL_INJURY_ANALYSIS.RAW.NFLVERSE_INJURIES
GROUP BY SOURCE_FILE_SEASON
ORDER BY SOURCE_FILE_SEASON;
```

For each season restored from the original archive:

- row_count must match the baseline in section 8.
- file_versions must equal 1.
- distinct_row_numbers must equal row_count.
- first_row_number must equal 1.
- last_row_number must equal row_count.

These checks verify counts and row numbering. They do not compare every
loaded source value with its original CSV value.

## 10. Verify safe sequential reruns

After the initial loads finish, run both loaders again:

```bash
python ingestion/load_manual_sources.py
python ingestion/load_nflverse_injuries.py
```

Expected behavior:

- Both manually collected files report SKIPPED.
- All eleven nflverse files report SKIPPED.
- Table row counts remain unchanged.

The loaders check stored file hashes and record numbering before
skipping a file. They do not perform a value-by-value integrity check.

Run only one loader process at a time. The current implementation does
not prevent concurrent processes from inserting the same file.

A different source version or an inconsistent existing load causes the
loader to stop. Investigate before changing or deleting stored data.

## 11. Verification status

Verified through successful execution in the initial account:

- Python connection using NFL_LOADER_ROLE.
- Initial loading of the two manually collected sources.
- Sequential rerun skipping both unchanged manual sources.
- Downloading eleven nflverse injury files with metadata.
- Initial loading of all eleven nflverse injury files.
- Sequential rerun skipping all eleven unchanged nflverse files.

The project author has also saved a copy of the original nflverse
archive to a private Google Drive location. Recovery from that backup
has not yet been tested.

Not yet verified:

- Complete rebuild in a separate empty database or new account.
- Downloading and restoring the private archive backup.
- Recovery from interrupted loads.
- Value-by-value comparison between source files and loaded tables.

Still required:

- Add roster ingestion and its rebuild instructions.
- Add dbt transformations, tests, and analytical models.
- Add dashboard and report rebuild instructions.

This guide documents the implemented pipeline and will be extended
as additional components are completed.
