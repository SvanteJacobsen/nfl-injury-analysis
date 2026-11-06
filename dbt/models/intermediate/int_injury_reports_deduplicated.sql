{{ config(materialized='view', schema='intermediate') }}

with prepared as (

    select
        *,
        try_to_timestamp_tz(
            source_date_modified_text
        ) as source_modified_at
    from {{ ref('stg_nflverse_injuries') }}

),

ranked as (

    select
        *,

        count(*) over (
            partition by season, game_type, week, team, gsis_id
        ) as source_record_count,

        row_number() over (
            partition by season, game_type, week, team, gsis_id
            order by
                source_modified_at desc nulls last,
                source_file_sha256,
                source_filename,
                source_row_number
        ) as report_version_rank

    from prepared

)

select
    * exclude (report_version_rank)
from ranked
where report_version_rank = 1