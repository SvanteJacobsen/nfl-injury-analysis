-- Multiple versions require usable timestamps for chronological selection.
with checked as (

    select
        *,
        count(*) over (
            partition by season, game_type, week, team, gsis_id
        ) as source_record_count
    from {{ ref('stg_nflverse_injuries') }}

)

select *
from checked
where source_record_count > 1
    and try_to_timestamp_tz(source_date_modified_text) is null