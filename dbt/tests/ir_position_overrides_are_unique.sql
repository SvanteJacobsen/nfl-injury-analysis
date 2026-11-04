-- Return duplicate reviewed decision keys.
select
    season,
    ir_team_code,
    gsis_id,
    count(*) as decision_count
from {{ ref('ir_position_group_overrides') }}
group by season, ir_team_code, gsis_id
having count(*) > 1