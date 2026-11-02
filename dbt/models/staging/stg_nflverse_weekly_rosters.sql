{{ config(materialized='view', schema='staging') }}

-- Grain: one row per original weekly-roster source record.
-- No deduplication or player matching is applied here.
with source as (

    select *
    from {{ source('nflverse_roster_raw', 'weekly_rosters') }}

),

cleaned as (

    select
        try_to_number(trim(season), 4, 0) as season,
        try_to_number(trim(week), 3, 0) as week,
        nullif(trim(game_type), '') as game_type,

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

        -- Roster status does not establish actual game participation.
        nullif(trim(status), '') as roster_status,
        nullif(trim(status_description_abbr), '') as roster_status_description,

        -- Retain provenance for validation and matching reviews.
        source_file_season,
        source_filename,
        source_file_sha256,
        source_row_number,
        loaded_at

    from source

)

select *
from cleaned
