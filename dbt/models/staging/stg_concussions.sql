{{ config(materialized='view', schema='staging') }}

-- Grain: one row per season in the current source snapshot.
with source as (

    select *
    from {{ source('nfl_raw', 'concussions') }}

),

typed as (

    select
        try_to_number(trim(year), 4, 0) as season,

        try_to_number(trim(preseason_practice), 38, 0)
            as preseason_practice_concussions,

        -- Preserve unavailable values as NULL rather than assuming zero.
        try_to_number(trim(preseason_game), 38, 0)
            as preseason_game_concussions,

        try_to_number(trim(regular_season_practice), 38, 0)
            as regular_season_practice_concussions,

        try_to_number(trim(regular_season_game), 38, 0)
            as regular_season_game_concussions,

        try_to_number(trim(total_concussions), 38, 0)
            as total_concussions,

        -- Retain provenance for tracing values back to their source.
        source_filename,
        source_file_sha256,
        source_row_number,
        loaded_at

    from source

)

select *
from typed
