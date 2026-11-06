{{ config(materialized='table', schema='marts') }}

-- Grain: one retained weekly report per player, team and game type.
-- Rows represent reports, not distinct injury events.
select
    injury_report_id,
    season,

    case
        when game_type = 'REG' then 'REG'
        when game_type in ('WC', 'DIV', 'CON', 'SB') then 'POST'
    end as season_phase,

    game_type,
    week,
    team_code,
    gsis_id,
    player_name,
    position_group,
    has_injury_information

from {{ ref('int_injury_reports_team_normalized') }}
