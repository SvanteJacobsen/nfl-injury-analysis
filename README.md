# NFL Injury Analysis

This project examines reported NFL injuries, injured reserve placements
and concussion trends. It combines a reproducible data pipeline with
an interactive dashboard and a narrative report.

## Research questions

- How have reported injuries and IR placements changed over time?
- Which injury categories are most commonly reported?
- How does the reported injury burden differ between position groups?
- How have concussions changed across preseason and regular-season
  games and practices?
- What does published research suggest about long-term consequences
  of repeated head impacts and preventive measures such as Guardian Caps?

## Data sources

| Source | Content | Current scope |
| --- | --- | --- |
| nflverse injury reports | Reported injuries and player information | 2024 tested; historical coverage to be assessed |
| nflverse rosters | Player IDs, positions and team information | 2015–2025 |
| NFL transaction archive | Manually collected Reserve/Injured transactions | 2015–2025 seasons, August–February |
| NFL injury data | Aggregate concussion counts | 2015–2024, preseason and regular season |
| Published research | CTE research, long term consequences, suicide rates | Literature review |

Source links:

- [nflverse injury reports](https://github.com/nflverse/nflverse-data/releases/tag/injuries)
- [nflverse season rosters](https://github.com/nflverse/nflverse-data/releases/tag/rosters)
- [nflverse weekly rosters](https://github.com/nflverse/nflverse-data/releases/tag/weekly_rosters)
- [NFL transaction archive](https://www.nfl.com/transactions/league/reserve-list/2024/1)
- [NFL injury data](https://www.nfl.com/playerhealthandsafety/health-and-wellness/injury-data/injury-data)
- [CTE prevalence in deceased NFL players](https://www.bmj.com/content/394/bmj-2026-100418)
- [CTE and dementia](https://pmc.ncbi.nlm.nih.gov/articles/PMC12836376/?utm_source=chatgpt.com)
- [Suicide rates - NFL vs NBA & MLB](https://hsph.harvard.edu/news/study-shows-rise-in-suicide-rate-among-nfl-players/)

## Planned data pipeline

Source files → Raw file archive → Python ingestion → Snowflake RAW
→ dbt staging → dbt intermediate → dbt marts
→ Dashboard and narrative report

- Raw files preserve the original source values.
- Python handles acquisition, ingestion and load logging.
- Snowflake stores the raw and transformed data.
- dbt handles standardisation, transformations, tests and model documentation.
- Marts provide documented datasets and metrics for presentation.

## Important definitions and limitations

- An injury report is not necessarily a new injury event.
- An IR placement does not necessarily end a player's season.
- IR transactions and unique players on IR are separate measures.
- The IR dataset includes playoffs; the concussion dataset covers
  preseason and regular season.
- Player matching remains incomplete, particularly for 2015.
- Position comparisons require explicit population and exposure definitions.
- Concussion rates require verified counts of games actually played.
- Changes in reporting, schedules and IR rules must be considered
  when comparing seasons.
- The project data cannot establish that a player developed CTE or
  demonstrate causal effects of Guardian Caps.

## Repository structure

- `docs/`: sources, architecture, definitions and methodological decisions
- `ingestion/`: Python acquisition and loading scripts
- `infrastructure/`: Snowflake setup SQL
- `notebooks/`: exploratory analysis
- `data/raw/`: local source files, excluded from Git

A dbt project will be added during implementation.

## Project status

Initial data exploration and feasibility checks are complete.
Pipeline implementation is starting.

Setup, execution and recovery instructions will be added as the
pipeline is implemented.

## Data and credentials

Raw data is stored locally and must also be backed up separately.
Source datasets are not currently distributed through this repository.

Credentials and private keys must never be committed.
