{{ config(materialized='view', schema='staging') }}

-- Grain: one row per original season-roster source record.
-- Select fields needed for player matching and position analysis.
-- All original columns remain available in RAW.
with source as (

    select *
    from {{ source('nflverse_roster_raw', 'rosters') }}

),

cleaned as (

    select
        try_to_number(trim(season), 4, 0) as season,

        -- Keep identifiers as text to preserve their original format.
        nullif(trim(gsis_id), '') as gsis_id,

        -- Retain alternative names for later matching.
        nullif(trim(full_name), '') as player_name,
        nullif(trim(first_name), '') as first_name,
        nullif(trim(last_name), '') as last_name,
        nullif(trim(football_name), '') as football_name,

        nullif(trim(team), '') as team,
        nullif(trim(position), '') as position,
        nullif(trim(depth_chart_position), '') as depth_chart_position,

        -- Retain roster context without assuming active playing exposure.
        nullif(trim(status), '') as roster_status,
        nullif(trim(status_description_abbr), '') as roster_status_description,
        nullif(trim(game_type), '') as source_game_type,
        try_to_number(trim(week), 3, 0) as source_week,

        -- Retain provenance for matching reviews and troubleshooting.
        source_file_season,
        source_filename,
        source_file_sha256,
        source_row_number,
        loaded_at

    from source

)

select *
from cleaned
