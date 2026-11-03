# NFL Injury Analysis

An individual Data Analyst project exploring reported
NFL injuries, injured reserve placements, and concussions over time.

The project combines a reproducible data pipeline with an analytical
dashboard and a narrative report. The planned story moves from broad
injury reporting and IR trends to a deeper discussion of concussions,
head impacts, and player safety.

## Analytical questions

- How has reported injury burden changed across seasons?
- Which injury categories appear most frequently in injury reports?
- How do reported injuries vary between position groups?
- How have IR placements and the number of players placed on IR changed?
- How have reported concussions changed over time?
- What does published research suggest about Guardian Caps and
  longer-term neurological outcomes?

Definitions and denominators will be documented before analytical
metrics are published.

## Current status

The ingestion stage is implemented for all five current source datasets.

| RAW table | Coverage | Loaded rows |
|---|---|---:|
| IR_TRANSACTIONS | Seasons 2015–2025; August–February collection window | 5,356 |
| CONCUSSIONS | Seasons 2015–2024; preseason and regular season | 10 |
| NFLVERSE_INJURIES | Seasons 2015–2025; observed regular season and postseason records | 60,788 |
| NFLVERSE_ROSTERS | Seasons 2015–2025 | 33,195 |
| NFLVERSE_WEEKLY_ROSTERS | Seasons 2015–2025 | 498,381 |

All tables are stored in NFL_INJURY_ANALYSIS.RAW.

Implemented:

- Local Python environment and pinned dependency versions.
- Snowflake infrastructure and loader-role setup scripts.
- Source inspection scripts.
- nflverse downloads with source metadata and SHA-256 checksums.
- Ingestion preserving source values and record provenance.
- Successful initial loads and sequential rerun checks.
- Private Google Drive backups of downloaded nflverse snapshots.

Not yet implemented:

- dbt transformations and automated analytical tests.
- Final player matching and position-group definitions.
- Validated analytical metrics.
- Dashboard and narrative report.
- Complete rebuild test in another environment.

## Architecture

The intended flow is:

Source files → local raw snapshots → Python ingestion → Snowflake RAW
→ dbt staging → dbt intermediate models → analytical marts
→ dashboard and narrative report.

The pipeline currently reaches Snowflake RAW. Subsequent layers are
planned.

Python handles acquisition and ingestion. dbt will handle data types,
cleaning, deduplication, player matching, and analytical models.
Notebooks can support exploratory analysis.

## Data sources

### Manually collected sources

- [NFL injury and concussion data](https://amp.nfl.com/playerhealthandsafety/health-and-wellness/injury-data/injury-data)
- [NFL reserve-list transactions: example page](https://www.nfl.com/transactions/league/reserve-list/2024/1)

The manually compiled CSV snapshots are included in data/raw/.

The concussion CSV currently covers 2015–2024. It does not include a
2025 row.

The IR collection covers August through February for each season.
January and February belong to the season that began in the preceding
calendar year. Collection completeness has not been independently
established.

### nflverse sources

- [Injury reports](https://github.com/nflverse/nflverse-data/releases/tag/injuries)
- [Season rosters](https://github.com/nflverse/nflverse-data/releases/tag/rosters)
- [Weekly rosters](https://github.com/nflverse/nflverse-data/releases/tag/weekly_rosters)
- [Injury data dictionary](https://nflreadr.nflverse.com/articles/dictionary_injuries.html)
- [Roster data dictionary](https://nflreadr.nflverse.com/articles/dictionary_rosters.html)

Downloaded nflverse snapshots and metadata are backed up in private
Google Drive archives maintained by the project author. They are not
included in the repository.

The download scripts retrieve published files. Source URLs may later
serve revised files, so exact reproduction requires the archived
snapshots.

### Research sources for planned contextual analysis

- [CTE prevalence in deceased NFL players](https://www.bmj.com/content/394/bmj-2026-100418)
- [CTE and dementia](https://pmc.ncbi.nlm.nih.gov/articles/PMC12836376/)
- [Suicide rates: NFL, NBA and MLB](https://hsph.harvard.edu/news/study-shows-rise-in-suicide-rate-among-nfl-players/)

These sources are candidates for the report's research discussion.
They have not been ingested into Snowflake. Their methods, populations,
and limitations must be reviewed before findings are used.

## Important interpretation limits

- An injury-report row is not necessarily a distinct injury event.
  A player can appear in several weeks and have multiple injury fields.
- An IR placement is not equivalent to a season-ending injury.
- Raw records include values that require classification, including
  non-injury absences.
- Existing per-game values in the concussion source require validation
  against the intended numerator and actual game counts.
- Position comparisons require an explicit population and denominator.
  Roster membership alone does not measure playing exposure.
- Observational season trends cannot establish the causal effect of
  Guardian Caps or diagnose CTE.

Observed source issues include:

- 75 exact duplicate IR rows, preserved in RAW.
- Missing IR positions, requiring later player matching.
- No preseason records observed in the downloaded nflverse injury or
  weekly roster snapshots.
- Injury data for 2023 contains REG and WC records only.
- The 2018 injury conference round contains records for three teams;
  the reason remains unresolved.
- Injury-file columns differ in 2025.
- Roster files contain missing IDs, names, or positions.
- The 2015 roster files contain fewer unique player IDs than later
  seasons, limiting assumptions about historical matching coverage.

## Repository structure

| Path | Purpose |
|---|---|
| ingestion/ | Source acquisition, inspection, and loading scripts |
| infrastructure/ | Snowflake setup and raw-table SQL |
| docs/ | Rebuild instructions and project documentation |
| notebooks/ | Exploratory analysis |
| data/raw/ | Source snapshots; only the two manual CSV files are versioned |
| requirements.in | Direct Python dependencies |
| requirements.txt | Pinned installed dependency versions |
| .env.example | Connection configuration template without credentials |

## Rebuilding the project

Follow [docs/rebuild.md](docs/rebuild.md).

The documented development environment uses Python 3.13.5.
The loaders read account-specific settings from a local .env file.

Never upload .env, passwords, private keys, or the .venv directory.

Sequential reruns have been tested. Concurrent loader execution and
full recovery in another Snowflake account have not been tested.

## Next steps

1. Complete raw-data verification and recovery testing.
2. Configure dbt and transformation permissions.
3. Build staging and intermediate models.
4. Resolve player matches and document unresolved cases.
5. Define and test analytical metrics.
6. Build the dashboard and narrative report.

## Transformation progress

The first dbt staging model is implemented and verified.

- Source: `NFL_INJURY_ANALYSIS.RAW.CONCUSSIONS`
- Output view: `NFL_INJURY_ANALYSIS.DBT_DEV_STAGING.STG_CONCUSSIONS`
- Grain: one row per season.
- Current coverage: 10 seasons, 2015–2024.
- Transformations: descriptive column names and numeric data types.
- Unavailable values remain NULL, including preseason game concussions in 2020.
- Source metadata is retained for traceability.

The model builds successfully and all six initial data tests pass.
These tests check season uniqueness and required values; they do not
establish source completeness or validate every reported count.

dbt runs locally in a separate Python environment and executes SQL
in Snowflake using `NFL_TRANSFORMER_ROLE`.

See [the rebuild guide](docs/rebuild.md) for setup and execution.

## IR staging progress

The IR staging view is implemented:
`NFL_INJURY_ANALYSIS.DBT_DEV_STAGING.STG_IR_TRANSACTIONS`.

- Preserves all 5,356 source records, including duplicates.
- Covers 11 NFL seasons, 2015–2025.
- Transaction dates range from 2015-08-17 to 2026-02-03.
- Converts years to numbers and constructs full transaction dates.
- Trims surrounding whitespace and converts blank text to NULL.
- Retains source metadata for traceability.

All six initial IR data tests pass: five required-value checks
and one check of the August–February scope and season assignment.

Deduplication and player matching have not yet been implemented
in the dbt pipeline. IR placements are not treated as season-ending injuries.

## Staging milestone — 2026-11-02

All five staging models build successfully in a single dbt run.
All 30 data tests pass, with no errors or warnings.

| Model | Current snapshot rows |
|---|---:|
| stg_concussions | 10 |
| stg_ir_transactions | 5356 |
| stg_nflverse_injuries | 60788 |
| stg_nflverse_rosters | 33195 |
| stg_nflverse_weekly_rosters | 498381 |

Staging applies basic type conversion and text cleanup while retaining
source records and provenance. Roster models select the fields needed
for matching and analysis; all original columns remain available in RAW.

Known missing roster identifiers, names and positions are retained.
Row counts have been checked against the ingested source snapshots.

These checks do not establish source completeness or validate every value.
Deduplication, player matching, injury classification and analytical
metrics remain to be implemented in subsequent models.

## IR intermediate progress — 2026-11-02

Two IR intermediate models are implemented and verified.

### Deduplication

`int_ir_transactions_deduplicated` groups records by season,
transaction date, player name, From team, To team and transaction type.

- Source records: 5,356.
- Transactions after deduplication: 5,281.
- Extra duplicate records removed: 75.
- Each of the 75 affected transactions appeared twice.

The model retains representative source metadata and a
`source_record_count` showing how many source rows each transaction represents.

### Team normalization

`int_ir_transactions_team_normalized` maps the To team field
to a common franchise code using the `team_aliases` seed.

- Team aliases: 74.
- Transactions retained: 5,281.
- Transactions without a mapped team: 0.
- Distinct franchises: 32.

Historical team names and locations share a franchise code for matching.
Original From and To values are retained.

The selected IR pipeline build completed successfully:
3 view models, 1 seed and 17 passing data tests, with no errors or warnings.

## Player identity matching — checkpoint 2026-11-03

The IR identity pipeline combines season and weekly roster observations,
standardizes franchise names, and matches players within the same season
and franchise.

The matching process preserves the initial automatic result, applies
documented manual decisions from a dbt seed, and attempts additional
matches using standardized player names.

Current results across 5,281 deduplicated IR transactions:

| Identity status | Transactions |
|---|---:|
| matched_exact | 5,046 |
| matched_manual | 183 |
| matched_normalized | 49 |
| unmatched | 3 |

Identity coverage is 5,278 of 5,281 transactions, approximately 99.94%.
This measures coverage, not independently verified matching accuracy.

The three unresolved transactions concern Christion Jones, Jimmie Hunt,
and Melvin Meggs. These records remain in the dataset.

The selected IR matching build passed 50 data tests.

### Player register

An archived nflverse player-register snapshot has been loaded into
RAW.NFLVERSE_PLAYERS and exposed through stg_nflverse_players.

Verified staging results:

- 24,863 records, matching the RAW row count.
- 24,863 distinct player IDs.
- No missing player IDs or positions.
- All four staging tests passed.

The register provides general player attributes rather than historical
positions by season. It will supplement season-specific roster data.

Position assignment to IR transactions has not yet been implemented.
The next step is to inspect conflicting roster positions and implement
documented source priorities.
