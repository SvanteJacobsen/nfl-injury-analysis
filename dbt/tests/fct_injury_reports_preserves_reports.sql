-- Return report records whose values or row counts changed.
with expected as (

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

),

row_changes as (

    select
        *,
        1 as row_change
    from expected

    union all

    select
        injury_report_id,
        season,
        season_phase,
        game_type,
        week,
        team_code,
        gsis_id,
        player_name,
        position_group,
        has_injury_information,
        -1 as row_change

    from {{ ref('fct_injury_reports') }}

)

select
    injury_report_id,
    season,
    season_phase,
    game_type,
    week,
    team_code,
    gsis_id,
    player_name,
    position_group,
    has_injury_information,
    sum(row_change) as net_row_change

from row_changes

group by
    injury_report_id,
    season,
    season_phase,
    game_type,
    week,
    team_code,
    gsis_id,
    player_name,
    position_group,
    has_injury_information

having sum(row_change) <> 0
