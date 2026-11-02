{{ config(materialized='view', schema='staging') }}

-- Grain: one row per original injury-report source record.
-- No injury classification, filtering or deduplication is applied here.
with source as (

    select *
    from {{ source('nfl_raw', 'nflverse_injuries') }}

),

cleaned as (

    select
        try_to_number(trim(season), 4, 0) as season,
        try_to_number(trim(week), 3, 0) as week,

        -- Preserve both source fields because file structures vary by year.
        nullif(trim(game_type), '') as game_type,
        nullif(trim(season_type), '') as source_season_type,

        nullif(trim(team), '') as team,
        nullif(trim(position), '') as position,

        -- Player identifiers remain text to preserve their original format.
        nullif(trim(gsis_id), '') as gsis_id,
        nullif(trim(full_name), '') as player_name,
        nullif(trim(first_name), '') as first_name,
        nullif(trim(last_name), '') as last_name,

        -- Preserve injury descriptions for classification in later models.
        nullif(trim(report_primary_injury), '') as report_primary_injury,
        nullif(trim(report_secondary_injury), '') as report_secondary_injury,
        nullif(trim(report_status), '') as report_status,

        nullif(trim(practice_primary_injury), '') as practice_primary_injury,
        nullif(trim(practice_secondary_injury), '') as practice_secondary_injury,
        nullif(trim(practice_status), '') as practice_status,

        -- Retain the source timestamp as text until its format is validated.
        -- This field is absent from the 2025 source file.
        nullif(trim(date_modified), '') as source_date_modified_text,

        -- Retain ingestion metadata for traceability and validation.
        source_file_season,
        source_filename,
        source_file_sha256,
        source_row_number,
        loaded_at

    from source

)

select *
from cleaned
