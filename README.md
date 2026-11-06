# NFL Injury Analysis

An individual Data Analyst project exploring NFL injury reporting,
injured reserve placements, and reported concussions over time.

The project combines a reproducible data pipeline with a planned
analytical dashboard and narrative report. The analysis will move
from injury reporting and IR trends to a deeper discussion of
concussions, head impacts, and player safety.

## Analytical questions

- How has reported injury burden changed across seasons?
- Which standardized injury categories appear most frequently?
- How do injury reports and affected-player counts vary by position group?
- How have IR placements and the number of identified players placed
  on IR changed?
- How have reported concussions changed over time?
- What does published research suggest about Guardian Caps and
  longer-term neurological outcomes?

Weekly injury reports, distinct players, IR placements, and aggregate
concussion counts are different measures. Definitions and denominators
must be established before results are interpreted as injury rates
or risk.

## Current status

The pipeline reaches tested analytical marts for IR placements and
weekly injury reports.

Implemented:

- Python acquisition and ingestion scripts with source metadata
  and SHA-256 checksums.
- Snowflake infrastructure and separate loader and transformer roles.
- dbt staging models for all six source tables.
- IR deduplication, franchise normalization, player matching, and
  position-group assignment.
- Injury-report version selection, description classification,
  standardized injury categories, and team and position normalization.
- Three analytical mart tables.
- Automated tests for required values, uniqueness, relationships,
  mapping coverage, and record preservation.
- Rebuild documentation.

Remaining work:

- Validate analytical metrics and appropriate denominators.
- Transform aggregate concussion data beyond staging as needed.
- Explore and interpret trends.
- Build the dashboard and narrative report.
- Review research evidence before using it in the report.
- Test a complete rebuild in another environment.

Validation checkpoints describe the current source snapshots.
Passing tests do not establish source completeness, clinical validity,
or independently verified player-matching accuracy.

## Architecture

Source files → local raw snapshots → Python ingestion → Snowflake RAW
→ dbt staging → dbt intermediate models → analytical marts
→ dashboard and narrative report.

Python handles source acquisition and ingestion. dbt executes SQL
transformations and tests in Snowflake.

| Layer | Purpose |
|---|---|
| RAW | Preserve ingested source records and provenance |
| Staging | Apply basic type conversion, field selection, and text cleanup |
| Intermediate | Resolve duplicates, normalize values, match players, and classify descriptions |
| Marts | Provide focused tables for analysis and visualization |

Development schemas:

- `NFL_INJURY_ANALYSIS.RAW`
- `NFL_INJURY_ANALYSIS.DBT_DEV_STAGING`
- `NFL_INJURY_ANALYSIS.DBT_DEV_INTERMEDIATE`
- `NFL_INJURY_ANALYSIS.DBT_DEV_MARTS`

dbt seeds are stored in `NFL_INJURY_ANALYSIS.DBT_DEV`.

## Data inventory

| RAW table | Current snapshot coverage | Loaded rows |
|---|---|---:|
| IR_TRANSACTIONS | Seasons 2015–2025; August–February collection window | 5,356 |
| CONCUSSIONS | Seasons 2015–2024; preseason and regular-season measures | 10 |
| NFLVERSE_INJURIES | Seasons 2015–2025; observed regular-season and postseason records | 60,788 |
| NFLVERSE_ROSTERS | Seasons 2015–2025 | 33,195 |
| NFLVERSE_WEEKLY_ROSTERS | Seasons 2015–2025 | 498,381 |
| NFLVERSE_PLAYERS | Archived player-register snapshot | 24,863 |

The concussion dataset currently contains no 2025 row.

For IR transactions, January and February belong to the season that
began in the preceding calendar year. Collection completeness has
not been independently established.

## Analytical marts

All three marts are materialized as tables in `DBT_DEV_MARTS`.

| Table | Grain | Current rows |
|---|---|---:|
| `fct_ir_placements` | One deduplicated IR placement | 5,281 |
| `fct_injury_reports` | One retained report per season, game type, week, team, and player ID | 60,786 |
| `bridge_injury_report_categories` | One report and standardized injury category pair | 55,995 |

### IR placements

`fct_ir_placements` contains placement dates, seasons, normalized
franchises, player names and IDs, broad position groups, assignment
provenance, and source metadata.

Current coverage:

- 5,281 placements with unique placement identifiers.
- All placements have an assigned position group.
- 5,278 placements have a resolved player ID.
- Three placements retain unresolved player IDs: Jimmie Hunt,
  Melvin Meggs, and Christion Jones.
- Transaction-specific reviewed decisions assign their position
  groups as WR, OL, and WR respectively.

Player identity matching uses exact matches, reviewed overrides,
and standardized names:

| Identity status | Placements |
|---|---:|
| matched_exact | 5,046 |
| matched_manual | 183 |
| matched_normalized | 49 |
| unmatched | 3 |

Identity coverage is approximately 99.94%. This measures coverage,
not independently verified matching accuracy.

Placement counts include all mart rows. Distinct player-ID counts
exclude unresolved IDs and must be recalculated at the selected
reporting level.

An IR placement is not necessarily a distinct injury or a
season-ending injury.

### Weekly injury reports

`fct_injury_reports` contains ten columns:

| Column | Purpose |
|---|---|
| `injury_report_id` | Identify the retained report and link it to categories |
| `season` | NFL season |
| `season_phase` | REG or POST |
| `game_type` | REG, WC, DIV, CON, or SB |
| `week` | Source week number |
| `team_code` | Standardized franchise code |
| `gsis_id` | Player identifier |
| `player_name` | Source player name |
| `position_group` | Standardized analytical position group |
| `has_injury_information` | Whether a description contains injury information |

All reports remain in the table, including reports concerning illness,
non-injury absences, or missing descriptions.

Filter `has_injury_information = true` when analyzing reports
containing injury information. The flag can coexist with illness
or non-injury content. A false value does not establish that the
player is healthy.

Current results:

- 60,786 retained reports representing 60,788 source records.
- 52,655 reports containing injury information.
- Seven reports without descriptions, retained in the table.
- Complete position-group and team-code assignment.
- 32 standardized franchises.

Original descriptions, availability statuses, classification coverage,
and source metadata remain available in intermediate models.

### Injury categories

`bridge_injury_report_categories` contains:

- `injury_report_id`
- `injury_category`

The combination identifies a unique row. A report may have several
categories, but repeated mentions of the same category across its
description fields produce only one report-category pair.

Examples:

- `rib`, `ribs`, and `rib cage` map to `ribs`.
- `knee`, `left knee`, and `right knee` map to `knee`.
- `hip flexor` maps to `hip`.
- `knee, ankle` maps to both `knee` and `ankle`.

Current results:

- 55,995 report-category pairs.
- 52,655 reports represented.
- 61 standardized categories.

Categories retain the specificity supported by the source. They include
anatomical labels and explicitly reported conditions such as concussion;
they are not a clinical diagnostic hierarchy. A general knee description
does not establish an ACL injury.

When joining categories to reports, one report can produce multiple
rows. Count distinct `injury_report_id` when calculating report totals
across categories.

## Transformation decisions

### IR deduplication and matching

The IR pipeline reduces 5,356 source records to 5,281 placements.
The 75 extra duplicate records remain available in RAW and staging.

Identity matching combines season and weekly roster observations,
shared franchise codes, reviewed decisions, and standardized names.

Position evidence prioritizes reviewed decisions, same-season roster
evidence, player-register attributes, and historical roster evidence.
Conflicts at the selected evidence level prevent automatic assignment.

The player register provides general attributes rather than
season-specific historical positions.

### Injury-report version selection

Reports are grouped by season, game type, week, team, and player ID.
When multiple versions exist, the latest source modification timestamp
determines the retained version, with deterministic tie-breaking.

The current snapshot has two reports with multiple versions.
Selecting their latest versions reduces 60,788 records to 60,786 reports.
Original versions remain available upstream.

### Description classification

The four primary and secondary report and practice fields are expanded
into description occurrences and classified using an exact-text seed.

The current snapshot contains 98,623 populated description occurrences.
All have a classification under the current rules.

Classes distinguish injury, illness, non-injury content, evaluation,
unspecified information, other health content, COVID-related references,
and mixed descriptions.

Classification coverage does not establish clinical correctness.
New descriptions require review when they do not match existing rules.

A separate category seed contains 303 mappings covering 217 distinct
injury-containing description keys.

### Shared team and position mappings

Historical team aliases share a franchise code. For example, `STL`
maps to the Rams franchise code `LA`. Original values remain upstream.

Broad position groups are:

`QB`, `RB`, `TE`, `WR`, `OL`, `DL`, `LB`, `DB`, and `K/P/LS`.

For injury reports:

- 60,774 reports use their own mapped position.
- Twelve reports use unambiguous weekly roster evidence from the
  same player, season, week, and team.
- Those twelve source position fields contained a line-break character.
- The implemented roster fallback is restricted to regular-season reports.

## Validation

Latest selected injury-report mart build, 2026-11-06:

- Four seeds, eleven views, and two tables.
- 108 passing data tests.
- `PASS=125, WARN=0, ERROR=0`.

The selected IR mart checkpoint completed with:

- Five seeds, eleven views, and one table.
- 97 passing data tests.
- `PASS=114, WARN=0, ERROR=0`.

These are separate selected builds, not the result of one complete
project-wide run.

Tests cover required fields, identifiers, accepted values,
relationships, mapping coverage, and preservation of records.
The injury-report mart preservation test also compares all ten
selected column values against the expected upstream projection.

Identifiers derived from source-file hashes and retained row numbers
are snapshot-dependent. They may change when source snapshots change.

## Important interpretation limits

- Weekly reports are not distinct injury events. The same injury can
  appear over multiple weeks.
- A player can have several injury categories within one report.
  Category totals are therefore not additive report totals.
- Distinct player counts measure affected players, not injury events.
- IR placements do not establish that injuries were season-ending.
- Descriptions such as non-football injury do not establish an
  injury caused by NFL participation. Original text is retained upstream.
- No preseason records were observed in the downloaded nflverse injury
  or weekly roster snapshots.
- The 2023 injury source contains REG and WC records only, with no
  DIV, CON, or SB coverage.
- The 2018 injury conference round contains records for three teams;
  the reason remains unresolved.
- Source file structures differ in 2025, including an absent injury
  modification-timestamp field.
- Roster files contain missing IDs, names, or positions. The 2015 files
  contain fewer unique player IDs than later seasons.
- Position comparisons require an explicit population and denominator.
  Roster membership alone does not measure playing exposure.
- Existing per-game concussion values require validation against the
  intended numerator and actual game counts.
- Observational trends cannot establish the causal effect of Guardian
  Caps or diagnose CTE.

Regular-season comparisons should be separated from playoff comparisons
and interpreted alongside source coverage.

## Data sources

### Manually collected sources

- [NFL injury and concussion data](https://amp.nfl.com/playerhealthandsafety/health-and-wellness/injury-data/injury-data)
- [NFL reserve-list transactions: example page](https://www.nfl.com/transactions/league/reserve-list/2024/1)

The manually compiled CSV snapshots are included in `data/raw/`.

### nflverse sources

- [Injury reports](https://github.com/nflverse/nflverse-data/releases/tag/injuries)
- [Season rosters](https://github.com/nflverse/nflverse-data/releases/tag/rosters)
- [Weekly rosters](https://github.com/nflverse/nflverse-data/releases/tag/weekly_rosters)
- [Player register](https://github.com/nflverse/nflverse-data/releases/tag/players)
- [Injury data dictionary](https://nflreadr.nflverse.com/articles/dictionary_injuries.html)
- [Roster data dictionary](https://nflreadr.nflverse.com/articles/dictionary_rosters.html)

Downloaded injury and roster snapshots and metadata are backed up in
private Google Drive archives maintained by the project author.
These snapshots are not included in the repository.

The archived player-register snapshot, `data/raw/players.csv`, is
versioned in the repository.

Published download URLs may later serve revised files. Exact
reproduction requires the original archived snapshots.

### Research sources for contextual analysis

- [CTE prevalence in deceased NFL players](https://www.bmj.com/content/394/bmj-2026-100418)
- [CTE and dementia](https://pmc.ncbi.nlm.nih.gov/articles/PMC12836376/)
- [Suicide rates: NFL, NBA and MLB](https://hsph.harvard.edu/news/study-shows-rise-in-suicide-rate-among-nfl-players/)

These sources are candidates for the report's research discussion.
They have not been ingested into Snowflake. Their methods, populations,
and limitations must be reviewed before findings are used.

## Repository structure

| Path | Purpose |
|---|---|
| `ingestion/` | Source acquisition, inspection, and loading scripts |
| `infrastructure/` | Snowflake setup and RAW-table SQL |
| `dbt/models/staging/` | Source type conversion and basic cleanup |
| `dbt/models/intermediate/` | Matching, deduplication, normalization, and classification |
| `dbt/models/marts/` | Focused analytical tables |
| `dbt/seeds/` | Shared mappings, classification rules, and reviewed overrides |
| `dbt/macros/` | Reusable transformation logic |
| `dbt/tests/` | Custom data quality and preservation tests |
| `docs/` | Rebuild instructions and project documentation |
| `notebooks/` | Exploratory analysis |
| `data/raw/` | Source snapshots; selected files are versioned |
| `requirements.in` | Direct ingestion-environment dependencies |
| `requirements.txt` | Pinned ingestion-environment dependencies |
| `.env.example` | Connection configuration template without credentials |

## Rebuilding the project

Follow [docs/rebuild.md](docs/rebuild.md) for setup, ingestion,
transformation commands, and validation checkpoints.

The documented environment uses Python 3.13.5:

- `.venv` for acquisition and ingestion.
- `.venv-dbt` for dbt.
- A local `.env` file for account-specific connection settings.

dbt runs locally and executes transformations in Snowflake using
`NFL_TRANSFORMER_ROLE`. RAW ingestion uses `NFL_LOADER_ROLE`.

Credentials, local connection profiles, virtual environments, and
generated dbt artifacts are excluded from version control.

Sequential loader reruns have been tested. Concurrent loader execution
and a complete rebuild in a fresh Snowflake account have not been tested.

## Next steps

1. Validate aggregate concussion measures and required denominators.
2. Define analysis metrics for weekly reports, affected players,
   injury categories, and IR placements.
3. Explore regular-season trends and position-group differences.
4. Build the dashboard with clear metric definitions and coverage notes.
5. Review research evidence for the narrative report.
6. Test and document a complete rebuild in another environment.
