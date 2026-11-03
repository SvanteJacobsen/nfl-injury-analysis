{{ config(materialized='view', schema='intermediate') }}

-- Grain: one original roster observation from either source.
-- Repeated player observations are intentionally retained.
with roster_observations as (

    select
        'season_roster' as roster_source,
        season,
        source_week as week,
        source_game_type as game_type,
        gsis_id,
        player_name,
        first_name,
        last_name,
        football_name,
        team,
        position,
        depth_chart_position,
        roster_status,
        roster_status_description,
        source_file_season,
        source_filename,
        source_file_sha256,
        source_row_number,
        loaded_at

    from {{ ref('stg_nflverse_rosters') }}

    union all

    select
        'weekly_roster' as roster_source,
        season,
        week,
        game_type,
        gsis_id,
        player_name,
        first_name,
        last_name,
        football_name,
        team,
        position,
        depth_chart_position,
        roster_status,
        roster_status_description,
        source_file_season,
        source_filename,
        source_file_sha256,
        source_row_number,
        loaded_at

    from {{ ref('stg_nflverse_weekly_rosters') }}

),

team_aliases as (

    select
        team_alias,
        franchise_code
    from {{ ref('team_aliases') }}

)

select
    r.*,

    -- Apply the same franchise mapping used for IR transactions.
    a.franchise_code as roster_team_code,

    -- Prepare a conservative name key for the initial matching rule.
    -- Preserve punctuation, accents and suffixes at this stage.
    nullif(lower(trim(r.player_name)), '') as player_name_key

from roster_observations as r

left join team_aliases as a
    on lower(trim(r.team)) = a.team_alias
