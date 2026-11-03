{{ config(materialized='view', schema='staging') }}

-- Prepare player identity and general position attributes.
-- Preserve every source record and its ingestion metadata.
select
    nullif(trim(gsis_id), '') as gsis_id,
    nullif(trim(display_name), '') as player_name,
    nullif(trim(common_first_name), '') as common_first_name,
    nullif(trim(first_name), '') as first_name,
    nullif(trim(last_name), '') as last_name,
    nullif(trim(football_name), '') as football_name,
    nullif(trim(suffix), '') as name_suffix,

    try_to_date(nullif(trim(birth_date), ''), 'YYYY-MM-DD')
        as birth_date,

    nullif(upper(trim(position)), '') as position,
    nullif(upper(trim(position_group)), '') as source_position_group,

    try_to_number(nullif(trim(rookie_season), ''))
        as rookie_season,

    try_to_number(nullif(trim(last_season), ''))
        as last_season,

    nullif(upper(trim(latest_team)), '') as latest_team,

    source_filename,
    source_file_sha256,
    source_row_number,
    loaded_at

from {{ source('nflverse_players_raw', 'players') }}
