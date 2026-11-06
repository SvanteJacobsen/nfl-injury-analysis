-- Reconcile represented source versions for every report key.
with row_changes as (

    select
        season,
        game_type,
        week,
        team,
        gsis_id,
        1 as record_change
    from {{ ref('stg_nflverse_injuries') }}

    union all

    select
        season,
        game_type,
        week,
        team,
        gsis_id,
        -source_record_count as record_change
    from {{ ref('int_injury_reports_deduplicated') }}

)

select
    season,
    game_type,
    week,
    team,
    gsis_id,
    sum(record_change) as record_difference
from row_changes
group by season, game_type, week, team, gsis_id
having sum(record_change) <> 0