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

## Set up and run dbt

Complete the RAW ingestion steps before building the staging model.
Run terminal commands from the project root.

### 1. Create the transformation role

Run `infrastructure/setup_dbt_role.sql` in Snowflake using an
administrative user with the required role-management permissions.

This creates `NFL_TRANSFORMER_ROLE`, grants read access to RAW,
and allows dbt to create output schemas in the project database.

### 2. Create a separate Python environment

The project currently uses Python 3.13.5.

```bash
python3 -m venv .venv-dbt
source .venv-dbt/bin/activate
python -m pip install -r requirements-dbt.txt
python -m pip check
```

If `.venv-dbt` already exists with the dependencies installed,
activate it without recreating it.

### 3. Configure the connection

Copy the tracked example to the local profile:

```bash
cp dbt/profiles.example.yml dbt/profiles.yml
```

The profile reads Snowflake credentials from the local `.env` file.
For a new Snowflake account, update `.env` with the new credentials.

Keep `.env` and `dbt/profiles.yml` out of version control.

### 4. Verify the connection

```bash
dotenv -f .env run -- dbt debug --project-dir dbt --profiles-dir dbt
```

Expected result: `All checks passed!`

### 5. Build and test the staging model

```bash
dotenv -f .env run -- dbt build --select stg_concussions --project-dir dbt --profiles-dir dbt
```

Current verified result:

- One view created: `DBT_DEV_STAGING.STG_CONCUSSIONS`.
- Six data tests passed.
- No errors or warnings.

The schema name combines the profile schema `DBT_DEV` with the
model's custom schema `staging`.

### 6. Inspect the output in Snowflake

```sql
SELECT *
FROM NFL_INJURY_ANALYSIS.DBT_DEV_STAGING.STG_CONCUSSIONS
ORDER BY season;
```

The current snapshot returns 10 rows for 2015–2024.
Preseason game concussions for 2020 remain NULL.

The connection, model build and initial tests have been verified
in the current account. A complete rebuild in a new Snowflake
account has not yet been tested.

## Build and verify IR staging

After loading the manual sources and completing the dbt setup,
run this command from the project root with `.venv-dbt` active:

```bash
dotenv -f .env run -- dbt build --select stg_ir_transactions --project-dir dbt --profiles-dir dbt
```

The verified result is one successfully created view and six passing tests.

Inspect the output in Snowflake:

```sql
SELECT
    COUNT(*) AS source_records,
    MIN(transaction_date) AS first_transaction_date,
    MAX(transaction_date) AS last_transaction_date,
    COUNT(DISTINCT season) AS distinct_seasons
FROM NFL_INJURY_ANALYSIS.DBT_DEV_STAGING.STG_IR_TRANSACTIONS;
```

Expected results for the current source snapshot:

| Check | Expected value |
|---|---:|
| Source records | 5356 |
| First transaction date | 2015-08-17 |
| Last transaction date | 2026-02-03 |
| Distinct seasons | 11 |

Staging retains duplicate source records. Deduplication and
player matching will be implemented in subsequent models.


## Build all staging models

After completing RAW ingestion and dbt setup, activate the dbt
environment and run the project from the repository root:

```bash
source .venv-dbt/bin/activate
dotenv -f .env run -- dbt build --project-dir dbt --profiles-dir dbt
```

Verified on 2026-11-02:

- 5 view models completed successfully.
- 30 data tests passed.
- PASS=35, WARN=0, ERROR=0, SKIP=0.

Views are created in the `DBT_DEV_STAGING` schema.

The tests check required values, concussion season uniqueness,
IR date/season consistency, and agreement between nflverse row
seasons and source-file seasons.

Known missing roster player identifiers, names and positions are
allowed and retained for later review.

A complete recovery into a new Snowflake account remains untested.

## Build IR intermediate models

After completing RAW ingestion and dbt setup, run these commands
from the repository root:

```bash
source .venv-dbt/bin/activate
dotenv -f .env run -- dbt build --select +int_ir_transactions_team_normalized --project-dir dbt --profiles-dir dbt
```

The leading `+` includes upstream dependencies, including the
`team_aliases` seed and the preceding IR models.

Verified result on 2026-11-02:

- 3 view models built successfully.
- 1 seed loaded with 74 mapping rows.
- 17 data tests passed.
- No errors or warnings.

The intermediate views are created in `DBT_DEV_INTERMEDIATE`.
With the current profile, the seed table is created in `DBT_DEV`.

Verify deduplication in Snowflake:

```sql
SELECT
    COUNT(*) AS deduplicated_transactions,
    SUM(source_record_count) AS represented_source_records,
    SUM(source_record_count - 1) AS duplicate_records_removed,
    COUNT_IF(source_record_count > 1) AS transactions_with_duplicates
FROM NFL_INJURY_ANALYSIS.DBT_DEV_INTERMEDIATE.INT_IR_TRANSACTIONS_DEDUPLICATED;
```

Expected values: 5281, 5356, 75 and 75 respectively.

Verify team normalization:

```sql
SELECT
    COUNT(*) AS transactions,
    COUNT_IF(ir_team_code IS NULL) AS unmapped_team_records,
    COUNT(DISTINCT ir_team_code) AS distinct_franchises
FROM NFL_INJURY_ANALYSIS.DBT_DEV_INTERMEDIATE.INT_IR_TRANSACTIONS_TEAM_NORMALIZED;
```

Expected values: 5281, 0 and 32 respectively.

Player matching and position enrichment are not yet implemented.
A complete recovery into a new Snowflake account remains untested.

## Additional rebuild steps — checkpoint 2026-11-03

These steps supplement the existing infrastructure, ingestion, and dbt
setup instructions.

### Restore the player-register snapshot

Restore the archived source file to:

`data/raw/players.csv`

Source URL:

https://github.com/nflverse/nflverse-data/releases/download/players/players.csv

The URL may provide a newer snapshot in the future. To reproduce this
checkpoint, use the archived file with this SHA256 checksum:

`dd4e38586b4d9982098760b823d87367824a1a58c80a1fb77f00273b73ee33e5`

The player-register loader requires this exact checksum. Keep the snapshot
with the project data backups.

### Create and load the RAW table

Run `infrastructure/create_raw_players.sql` in Snowflake.

From the project root, run the loader using the ingestion environment:

```bash
.venv/bin/python ingestion/load_nflverse_players.py
```

Expected source row count: 24,863.

A sequential rerun verifies and skips an existing complete load.
A different or incomplete destination load causes the script to stop.
Run one loader process at a time.

### Build player-register staging

Using the dbt environment, run:

```bash
dotenv -f .env run -- dbt build --select stg_nflverse_players --project-dir dbt --profiles-dir dbt
```

Expected result: one view and four passing data tests.

### Rebuild IR identity matching

Restore the original IR and roster sources using the earlier instructions.
Keep the current models, macro, and reviewed decision seed from the
repository, then run:

```bash
dotenv -f .env run -- dbt build --select +int_ir_player_matches_normalized --project-dir dbt --profiles-dir dbt
```

The leading `+` includes upstream models and seeds.

Expected identity results:

| Status | Transactions |
|---|---:|
| matched_exact | 5,046 |
| matched_manual | 183 |
| matched_normalized | 49 |
| unmatched | 3 |
| Total | 5,281 |

The reviewed decision seed contains 183 transaction-specific decisions.
Preserve the seed to reproduce those assignments.

For this checkpoint, the selected build passed 50 data tests.

### Inspect results in Snowflake

Use NFL_TRANSFORMER_ROLE to inspect dbt models.
NFL_LOADER_ROLE is used for RAW ingestion.

### Remaining work

Position assignment has not yet been implemented. Inspect roster position
conflicts before building the assignment model.

Planned position-source priority:

1. Same season and franchise in roster data.
2. Same season, another franchise in roster data.
3. General position from the player register.
4. Other roster seasons only where the observed position is unambiguous.

The three unresolved identities remain in the IR dataset.

## Build the IR placement mart

### Prerequisites

Complete the RAW ingestion and staging steps for IR transactions,
rosters, weekly rosters, and the player register.

Ensure these seeds are available:
- team_aliases
- ir_player_match_overrides
- position_group_mapping
- ir_position_group_overrides
- ir_transaction_position_overrides

The transaction-specific position seed contains three reviewed decisions:
- Jimmie Hunt: WR, GB, 2015-09-02
- Melvin Meggs: OL, LAC, 2015-09-02
- Christion Jones: WR, MIA, 2015-09-06

These decisions assign position groups without assigning gsis_id values.
They match on season, transaction date, normalized team code, and
player_name_key, and apply only while the player ID remains unresolved.

Keep the normalized franchise code LAC for the historical Melvin Meggs
record, as used by this project's team normalization.

### Activate the dbt environment

Run from the project root:

```bash
source .venv-dbt/bin/activate
```

Use .venv-dbt for dbt commands. The separate .venv environment is used
for ingestion scripts.

### Build and test

```bash
dotenv -f .env run -- dbt build --select +fct_ir_placements ir_transaction_position_overrides_target_one_transaction ir_position_overrides_are_unique --project-dir dbt --profiles-dir dbt
```

The leading + includes upstream dependencies. The two explicitly named
seed-level tests check reviewed decision keys and transaction targets.

The pipeline:
1. Loads the required seeds.
2. Builds upstream staging and intermediate models.
3. Applies reviewed positions independently of player-ID resolution.
4. Creates NFL_INJURY_ANALYSIS.DBT_DEV_MARTS.FCT_IR_PLACEMENTS.
5. Runs selected data tests, including record preservation,
   placement-ID uniqueness, and position-assignment consistency.

The mart contains one row per deduplicated IR placement.
It does not aggregate placements by player or season.

### Verify the result in Snowflake

Use NFL_TRANSFORMER_ROLE and NFL_ANALYTICS_WH.

```sql
select
    count(*) as ir_placements,
    count(distinct ir_placement_id) as distinct_placement_ids,
    count_if(gsis_id is null) as placements_without_player_id,
    count_if(position_group is null) as placements_without_position_group
from NFL_INJURY_ANALYSIS.DBT_DEV_MARTS.FCT_IR_PLACEMENTS;
```

Expected results for the archived project inputs:

| Check | Expected |
|---|---:|
| IR placements | 5281 |
| Distinct placement IDs | 5281 |
| Placements without player ID | 3 |
| Placements without position group | 0 |

The three unresolved register identities remain visible in the mart.
Their position groups come from project-owner-reviewed decisions.

### Interpretation and traceability

- Count mart rows to measure IR placements.
- Count distinct gsis_id values to measure identified unique players.
  This excludes unresolved IDs.
- Recalculate distinct player counts at the selected reporting level;
  do not sum distinct counts across teams or position groups.
- source_record_count includes original duplicate source records.
  Its sum is not the number of IR placements.
- Placement IDs are derived from source_file_sha256 and
  source_row_number. They may change if the source snapshot changes.
- IR placements are not necessarily distinct injuries or
  season-ending injuries.

### Validation checkpoint — 2026-11-06

The selected build executed successfully:
- 5 seeds
- 11 view models
- 1 table model
- 97 data tests
- PASS=114, WARN=0, ERROR=0

This validates the selected pipeline in the existing environment.

## Rebuild the injury-report intermediate models

Run these commands from the repository root:

```bash
source .venv-dbt/bin/activate

dotenv -f .env run -- dbt build --select +int_injury_reports_team_normalized +int_injury_report_categories injury_category_mapping_pairs_are_unique injury_category_mapping_covers_injury_descriptions --project-dir dbt --profiles-dir dbt
```

Both model branches are selected: the report-level transformations and
the report-category mapping. The `+` prefix includes their upstream
dependencies.

The pipeline:

- Retains the latest source version per season, game type, week, team
  and player ID.
- Extracts the four injury-description fields and classifies their text.
- Maps injury descriptions to standardized analytical categories.
- Consolidates repeated category mentions within each retained report.
- Standardizes position groups, using unambiguous weekly roster evidence
  for unmatched regular-season positions.
- Standardizes team aliases to shared franchise codes.

Validated checkpoint, 2026-11-06:

- 60,788 source records represented by 60,786 retained reports.
- 98,623 populated description occurrences, all classified.
- Seven reports without descriptions remain in the report-level model.
- 52,655 reports contain injury information.
- 55,995 report-category rows across 61 categories.
- All reports have a position group: 60,774 from report positions and
  12 from weekly roster evidence.
- All reports have a standardized team code across 32 franchises.

The category mapping contains 303 rows covering 217 description keys.
`hip flexor` maps to `hip`. The shared team mapping includes `stl` → `LA`.

These models represent weekly reports and reported categories, not
distinct injury events. Category counts can overlap within a report.
The 2023 source contains REG and WC reports but lacks DIV, CON and SB
coverage. Compare regular seasons separately from playoffs.

## Rebuild the injury-report marts

Run from the repository root with `.venv-dbt` activated:

```bash
dotenv -f .env run -- dbt build --select +fct_injury_reports +bridge_injury_report_categories injury_category_mapping_pairs_are_unique injury_category_mapping_covers_injury_descriptions --project-dir dbt --profiles-dir dbt
```

Both marts are materialized as tables in DBT_DEV_MARTS.

### fct_injury_reports

One row per retained weekly report. Contains ten columns:

- injury_report_id
- season
- season_phase
- game_type
- week
- team_code
- gsis_id
- player_name
- position_group
- has_injury_information

All reports are retained. Filter has_injury_information to true
when counting reports containing injury information.

### bridge_injury_report_categories

Contains two columns:

- injury_report_id
- injury_category

Each report-category pair occurs once. A report can have multiple
categories. Count distinct injury_report_id when counting reports
across multiple categories.

Original descriptions, classification coverage and source metadata
remain available in intermediate models.

### Validated checkpoint: 2026-11-06

- 60,786 reports with unique report IDs.
- 52,655 reports containing injury information.
- 55,995 report-category pairs across 61 categories.
- Selected build: PASS=125, WARN=0, ERROR=0, including 108 data tests.

These tables support counts of weekly reports and distinct players,
not distinct injury events. The 2023 source lacks DIV, CON and SB
coverage; compare regular seasons separately from playoffs.

