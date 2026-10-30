# Rebuild guide

This guide describes how to recreate the implemented ingestion pipeline
in a new Snowflake account.

Current scope:

- Manually collected IR transactions.
- Manually collected concussion statistics.
- nflverse injury reports, season rosters, and weekly rosters.
- Python ingestion into five Snowflake RAW tables.

Transformations, analytical models, and dashboards are not yet included.

## 1. Prerequisites

- A local copy of the project repository.
- Python 3.13.5, the version used during development.
- A Snowflake account with access to SYSADMIN and SECURITYADMIN.
- Access to the original nflverse archives, or internet access to
  download currently published files.

The repository includes the two manually collected CSV snapshots.
It excludes credentials and the installed Python environment.

The original nflverse snapshots and metadata are backed up in private
Google Drive archives maintained by the project author. Private links
and account details are not included in this repository.

The injury archive was saved as:

nflverse_injuries_2015-2025_snapshot_2026-10-29.zip

A separate roster archive contains the rosters and weekly_rosters
directories, including their metadata files.

Other users can retrieve currently published files using the download
scripts. Those files may differ from the original snapshots.

## 2. Restore the source files

### Manually collected sources

The repository includes:

- data/raw/ir_transactions.csv
- data/raw/concussions.csv

Use these files unchanged. Do not remove duplicates, edit values,
or re-export them before loading.

| Source file | Data rows, excluding the header |
|---|---:|
| ir_transactions.csv | 5,356 |
| concussions.csv | 10 |

The IR snapshot contains 75 exact duplicate rows beyond their first
occurrences. These are intentionally preserved in RAW.

These counts describe the snapshots and do not establish collection
completeness.

### nflverse sources

Restore the archived directories to:

- data/raw/nflverse/injuries/
- data/raw/nflverse/rosters/
- data/raw/nflverse/weekly_rosters/

Each directory contains eleven CSV files and eleven matching metadata
files for seasons 2015–2025.

| Directory | CSV filename pattern |
|---|---|
| injuries | injuries_YEAR.csv |
| rosters | roster_YEAR.csv |
| weekly_rosters | roster_weekly_YEAR.csv |

Each CSV has a matching file named:

CSV_FILENAME.metadata.json

For example:

- injuries_2015.csv
- injuries_2015.csv.metadata.json

Metadata records the source URL, download timestamp, source asset ID,
source update timestamp, file size, and SHA-256 checksum.

Restore both files in each pair. Avoid additional nested directories
when extracting archives.

Across all three directories, expect 33 CSV files and 33 metadata files.

A fresh download is not a guaranteed restoration of the original data.

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

Confirm that python3 uses the intended version before creating .venv.

Pinned dependencies were captured on the development machine.
Another operating system or Python version may require compatibility
checks.

requirements.in lists direct dependencies.
requirements.txt records the installed dependency versions.

## 4. Download sources if the archives are unavailable

Skip this section if the original snapshots have been restored.

Check injury-file availability and download the published files:

```bash
python ingestion/inspect_nflverse_release.py
python ingestion/download_nflverse_injuries.py
```

Download season and weekly roster files:

```bash
python ingestion/download_nflverse_rosters.py
```

The roster downloader imports the shared download function from
download_nflverse_injuries.py. Keep both scripts available.

The downloaders:

- Preserve existing local snapshots.
- Verify existing files against their saved checksums.
- Check downloaded file sizes.
- Check published SHA-256 digests when GitHub provides them.
- Save source metadata alongside each CSV.

They do not automatically replace snapshots when upstream files change.

A missing file pair or checksum mismatch requires investigation.

## 5. Inspect the sources

Run:

```bash
python ingestion/inspect_sources.py
python ingestion/inspect_nflverse_injuries.py
python ingestion/inspect_nflverse_rosters.py
```

These scripts report structure and basic quality information without
modifying source files.

### Observed injury-file limitations

- No preseason records were observed.
- The 2023 file contains REG and WC records only.
- The 2018 conference round contains records for three teams;
  the reason remains unresolved.
- The 2025 file includes season_type but omits date_modified.
- The 2015–2024 files include date_modified but omit season_type.

All seasons contain records for 32 teams and all regular season week
numbers. This does not establish complete team-week or player coverage.

### Observed roster limitations

- Both roster types have the same observed 36 source columns.
- Missing IDs, names, and positions occur in some files.
- No exact duplicate rows were found during inspection.
- Weekly files include regular season and postseason week numbers.
- No preseason records were observed in the weekly-file summary.
- Both 2015 roster files contain 2,064 unique nonblank player IDs,
  fewer than later seasons.

Nonblank-ID counts do not independently validate every ID.
Repeated player IDs are not automatically duplicate records.

## 6. Create the Snowflake infrastructure

In a Snowflake SQL worksheet, run the complete contents of these files
in order:

1. infrastructure/setup_snowflake.sql
2. infrastructure/setup_roles.sql
3. infrastructure/create_raw_tables.sql
4. infrastructure/create_raw_injuries.sql
5. infrastructure/create_raw_rosters.sql

The scripts create:

| Object | Name |
|---|---|
| Warehouse | NFL_ANALYTICS_WH |
| Database | NFL_INJURY_ANALYSIS |
| Schema | RAW |
| Loader role | NFL_LOADER_ROLE |
| Table | RAW.IR_TRANSACTIONS |
| Table | RAW.CONCUSSIONS |
| Table | RAW.NFLVERSE_INJURIES |
| Table | RAW.NFLVERSE_ROSTERS |
| Table | RAW.NFLVERSE_WEEKLY_ROSTERS |

All tables belong to NFL_INJURY_ANALYSIS.

The role setup assigns NFL_LOADER_ROLE to the user running the script.

The warehouse uses X-Small compute, automatic resume, and automatic
suspension after approximately 60 seconds of inactivity.

Setup scripts preserve existing objects. They do not automatically
migrate tables whose structures differ from the saved SQL.

## 7. Configure the connection

Copy .env.example to .env in the project root.

Update:

- SNOWFLAKE_ACCOUNT
- SNOWFLAKE_USER
- SNOWFLAKE_PASSWORD

Use the organization-account identifier for SNOWFLAKE_ACCOUNT,
without https:// or the .snowflakecomputing.com suffix.

Keep these project settings:

```dotenv
SNOWFLAKE_ROLE=NFL_LOADER_ROLE
SNOWFLAKE_WAREHOUSE=NFL_ANALYTICS_WH
SNOWFLAKE_DATABASE=NFL_INJURY_ANALYSIS
SNOWFLAKE_SCHEMA=RAW
```

Never commit .env or upload it to GitHub.
Keep placeholder values in .env.example.

Authentication must comply with the new account's settings, including
MFA where required.

Test:

```bash
python ingestion/test_connection.py
```

Confirm the expected role, warehouse, database, and schema.

## 8. Load the source files

Run these commands sequentially:

```bash
python ingestion/load_manual_sources.py
python ingestion/load_nflverse_injuries.py
python ingestion/load_nflverse_rosters.py
```

All loaders depend on functions defined in load_manual_sources.py.
Keep that file available alongside the other ingestion scripts.

Run only one loader process at a time.

### Manual-source loading

Both files are validated locally before loading.

Source text, empty strings, and duplicate records are preserved.
The CSV headers from and to map to FROM_TEAM and TO_TEAM.

Each file is committed separately.

### Injury-report loading

All eleven files are validated locally before loading.

Checks include expected headers, field counts, metadata checksums,
and source season values.

Absent source columns receive SQL NULL:

- SEASON_TYPE for 2015–2024.
- DATE_MODIFIED for 2025.

Each season is committed separately.

### Roster loading

Archive-file existence is checked before connecting.
Each source file is then validated and loaded individually.

The loader:

1. Checks headers, field counts, metadata checksum, and season values.
2. Preserves all 36 source fields as text.
3. Bulk-loads the prepared records into a temporary buffer table.
4. Checks the buffer's file hash and row-number sequence.
5. Inserts the records into RAW in a separate transaction.
6. Verifies the RAW file hash and row-number sequence before committing.

Buffer creation and bulk loading happen before the RAW transaction.
Temporary buffer tables are removed when the connection closes.

Each source file is committed separately. A failure in a later file
does not roll back earlier committed files.

### Record provenance

All RAW tables include:

- SOURCE_FILENAME
- SOURCE_FILE_SHA256
- SOURCE_ROW_NUMBER
- LOADED_AT

The nflverse tables also include SOURCE_FILE_SEASON.

Row numbering starts at 1 for the first CSV data record, excluding
the header. A CSV record may span multiple physical lines.

## 9. Expected row counts

These baselines apply to the original project snapshots.

| RAW table | Rows |
|---|---:|
| IR_TRANSACTIONS | 5,356 |
| CONCUSSIONS | 10 |
| NFLVERSE_INJURIES | 60,788 |
| NFLVERSE_ROSTERS | 33,195 |
| NFLVERSE_WEEKLY_ROSTERS | 498,381 |

Season-level nflverse baselines:

| Season | Injury reports | Season rosters | Weekly rosters |
|---|---:|---:|---:|
| 2015 | 5,232 | 2,190 | 32,098 |
| 2016 | 5,115 | 3,061 | 35,020 |
| 2017 | 5,104 | 3,082 | 51,321 |
| 2018 | 5,133 | 3,142 | 52,238 |
| 2019 | 5,392 | 3,114 | 51,632 |
| 2020 | 5,661 | 3,068 | 44,130 |
| 2021 | 5,587 | 2,961 | 46,696 |
| 2022 | 5,682 | 3,134 | 46,163 |
| 2023 | 5,599 | 3,090 | 45,655 |
| 2024 | 6,215 | 3,216 | 46,579 |
| 2025 | 6,068 | 3,137 | 46,849 |
| Total | 60,788 | 33,195 | 498,381 |

Newly downloaded files may have different counts or structures.
Investigate differences rather than treating updated sources as
equivalent to the original snapshots.

## 10. Verify the loaded tables

Run in Snowflake:

```sql
USE ROLE NFL_LOADER_ROLE;
USE SECONDARY ROLES NONE;
USE WAREHOUSE NFL_ANALYTICS_WH;

SELECT 'IR_TRANSACTIONS' AS source_table, COUNT(*) AS row_count
FROM NFL_INJURY_ANALYSIS.RAW.IR_TRANSACTIONS

UNION ALL

SELECT 'CONCUSSIONS', COUNT(*)
FROM NFL_INJURY_ANALYSIS.RAW.CONCUSSIONS

UNION ALL

SELECT 'NFLVERSE_INJURIES', COUNT(*)
FROM NFL_INJURY_ANALYSIS.RAW.NFLVERSE_INJURIES

UNION ALL

SELECT 'NFLVERSE_ROSTERS', COUNT(*)
FROM NFL_INJURY_ANALYSIS.RAW.NFLVERSE_ROSTERS

UNION ALL

SELECT 'NFLVERSE_WEEKLY_ROSTERS', COUNT(*)
FROM NFL_INJURY_ANALYSIS.RAW.NFLVERSE_WEEKLY_ROSTERS;
```

Compare the results with section 9.

Verify the nflverse loads by source season:

```sql
WITH source_records AS (
    SELECT
        'NFLVERSE_INJURIES' AS source_table,
        SOURCE_FILE_SEASON,
        SOURCE_FILE_SHA256,
        SOURCE_ROW_NUMBER
    FROM NFL_INJURY_ANALYSIS.RAW.NFLVERSE_INJURIES

    UNION ALL

    SELECT
        'NFLVERSE_ROSTERS',
        SOURCE_FILE_SEASON,
        SOURCE_FILE_SHA256,
        SOURCE_ROW_NUMBER
    FROM NFL_INJURY_ANALYSIS.RAW.NFLVERSE_ROSTERS

    UNION ALL

    SELECT
        'NFLVERSE_WEEKLY_ROSTERS',
        SOURCE_FILE_SEASON,
        SOURCE_FILE_SHA256,
        SOURCE_ROW_NUMBER
    FROM NFL_INJURY_ANALYSIS.RAW.NFLVERSE_WEEKLY_ROSTERS
)
SELECT
    source_table,
    SOURCE_FILE_SEASON,
    COUNT(*) AS row_count,
    COUNT(DISTINCT SOURCE_FILE_SHA256) AS file_versions,
    COUNT(DISTINCT SOURCE_ROW_NUMBER) AS distinct_row_numbers,
    MIN(SOURCE_ROW_NUMBER) AS first_row_number,
    MAX(SOURCE_ROW_NUMBER) AS last_row_number
FROM source_records
GROUP BY source_table, SOURCE_FILE_SEASON
ORDER BY source_table, SOURCE_FILE_SEASON;
```

For every table and source season:

- row_count must match its baseline.
- file_versions must equal 1.
- distinct_row_numbers must equal row_count.
- first_row_number must equal 1.
- last_row_number must equal row_count.

These checks verify counts and numbering, not every loaded source value.

## 11. Verify safe sequential reruns

After the initial loads finish, run:

```bash
python ingestion/load_manual_sources.py
python ingestion/load_nflverse_injuries.py
python ingestion/load_nflverse_rosters.py
```

Expected behavior:

- Two manual files report SKIPPED.
- Eleven injury files report SKIPPED.
- Twenty-two roster files report SKIPPED.
- Table row counts remain unchanged.

The loaders check file fingerprints and row numbering before skipping.
They do not compare every stored source value with the CSV.

Concurrent execution is not supported by the current implementation.
The checks do not guarantee protection against simultaneous loaders.

A different source version or inconsistent existing load causes the
loader to stop. Investigate before changing or deleting stored data.

## 12. Backup and verification status

Verified through successful execution in the initial account:

- Python connection using NFL_LOADER_ROLE.
- Downloads of injury and roster snapshots with metadata.
- Download rerun checks for the roster snapshots.
- Initial loading of all five RAW datasets.
- Sequential reruns skipping all previously loaded source files.

The project author has saved injury and roster archives to private
Google Drive storage.

Not yet verified:

- Downloading and restoring the Google Drive backups.
- Complete rebuild in a separate empty database or new account.
- Recovery from interrupted loads.
- Value-by-value comparison between CSV values and loaded RAW values.

Still required:

- Configure dbt and transformation permissions.
- Add staging models, player matching, tests, and analytical marts.
- Add dashboard and narrative-report rebuild instructions.

Update this guide when additional components are implemented or
verification results change.
