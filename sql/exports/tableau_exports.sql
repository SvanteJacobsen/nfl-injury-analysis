/*
Tableau dashboard exports.

Export each query result separately as CSV with column headers.

Run after a successful dbt build.
*/


-- 1. Weekly injury reports.
-- Output: data/exports/tableau/fct_injury_reports.csv
select *
from NFL_INJURY_ANALYSIS.DBT_DEV_MARTS.FCT_INJURY_REPORTS;


-- 2. Injury report categories.
-- Output: data/exports/tableau/bridge_injury_report_categories.csv
select *
from NFL_INJURY_ANALYSIS.DBT_DEV_MARTS.BRIDGE_INJURY_REPORT_CATEGORIES;


-- 3. Injured reserve placements.
-- Output: data/exports/tableau/fct_ir_placements.csv
select *
from NFL_INJURY_ANALYSIS.DBT_DEV_MARTS.FCT_IR_PLACEMENTS;


-- 4. Official concussion statistics.
-- Output: data/exports/tableau/fct_concussions.csv
select *
from NFL_INJURY_ANALYSIS.DBT_DEV_MARTS.FCT_CONCUSSIONS;


-- 5. Season-level game counts.
-- Output: data/exports/tableau/season_game_counts.csv
select *
from NFL_INJURY_ANALYSIS.DBT_DEV.SEASON_GAME_COUNTS;
