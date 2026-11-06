-- Return repeated report keys after version selection.
select
    season,
    game_type,
    week,
    team,
    gsis_id,
    count(*) as report_count
from {{ ref('int_injury_reports_deduplicated') }}
group by season, game_type, week, team, gsis_id
having count(*) > 1