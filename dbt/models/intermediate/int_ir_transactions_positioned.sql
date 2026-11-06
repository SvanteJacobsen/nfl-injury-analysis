{{ config(materialized='view', schema='intermediate') }}

with roster_groups as (

    -- Translate roster positions into the shared analytical groups.
    select
        r.season,
        r.roster_team_code,
        r.gsis_id,
        m.position_group
    from {{ ref('int_roster_observations') }} as r

    inner join {{ ref('position_group_mapping') }} as m
        on upper(trim(r.position)) = m.position_code

    where r.gsis_id is not null

),

same_season_team as (

    -- Summarize groups for each player, season, and franchise.
    select
        season,
        roster_team_code,
        gsis_id,
        count(distinct position_group) as group_count,
        min(position_group) as candidate_group
    from roster_groups
    group by season, roster_team_code, gsis_id

),

same_season as (

    -- Summarize groups across all franchises within a season.
    select
        season,
        gsis_id,
        count(distinct position_group) as group_count,
        min(position_group) as candidate_group
    from roster_groups
    group by season, gsis_id

),

all_seasons as (

    -- Historical fallback, used only when earlier levels have no group.
    select
        gsis_id,
        count(distinct position_group) as group_count,
        min(position_group) as candidate_group
    from roster_groups
    group by gsis_id

),

register_groups as (

    select
        p.gsis_id,
        m.position_group
    from {{ ref('stg_nflverse_players') }} as p

    inner join {{ ref('position_group_mapping') }} as m
        on upper(trim(p.position)) = m.position_code

),

position_evidence as (

    -- Keep every IR transaction and attach summarized evidence.
    select
        t.*,

        -- Combine transaction-specific and player-based reviewed decisions.
        coalesce(
            q.position_group,
            o.position_group
        ) as reviewed_position_group,

        coalesce(
            q.review_reason,
            o.review_reason
        ) as position_group_review_reason,

        coalesce(st.group_count, 0) as same_season_team_group_count,
        st.candidate_group as same_season_team_candidate,

        coalesce(s.group_count, 0) as same_season_group_count,
        s.candidate_group as same_season_candidate,

        p.position_group as register_position_group,

        coalesce(h.group_count, 0) as historical_group_count,
        h.candidate_group as historical_candidate

    from {{ ref('int_ir_player_matches_normalized') }} as t

    left join {{ ref('ir_position_group_overrides') }} as o
        on t.season = o.season
        and t.ir_team_code = o.ir_team_code
        and t.final_gsis_id = o.gsis_id

    -- Apply transaction-specific decisions only when the player ID is missing.
    left join {{ ref('ir_transaction_position_overrides') }} as q
        on t.season = q.season
        and t.transaction_date = q.transaction_date
        and t.ir_team_code = q.ir_team_code
        and t.player_name_key = q.player_name_key
        and t.final_gsis_id is null

    left join same_season_team as st
        on t.season = st.season
        and t.ir_team_code = st.roster_team_code
        and t.final_gsis_id = st.gsis_id

    left join same_season as s
        on t.season = s.season
        and t.final_gsis_id = s.gsis_id

    left join register_groups as p
        on t.final_gsis_id = p.gsis_id

    left join all_seasons as h
        on t.final_gsis_id = h.gsis_id

),

selected_evidence as (

    -- Select the first available evidence level.
    -- A conflict at that level prevents automatic assignment.
    select
        *,

        case
            when reviewed_position_group is not null then 'reviewed'
            when same_season_team_group_count > 0 then 'same_season_team'
            when same_season_group_count > 0 then 'same_season'
            when register_position_group is not null then 'player_register'
            when historical_group_count > 0 then 'other_seasons'
            else 'none'
        end as position_group_source,

        case
            when reviewed_position_group is not null then 1
            when same_season_team_group_count > 0
                then same_season_team_group_count
            when same_season_group_count > 0
                then same_season_group_count
            when register_position_group is not null then 1
            when historical_group_count > 0 then historical_group_count
            else 0
        end as selected_position_group_count,

        case
            when reviewed_position_group is not null
                then reviewed_position_group
            when same_season_team_group_count > 0
                then same_season_team_candidate
            when same_season_group_count > 0
                then same_season_candidate
            when register_position_group is not null
                then register_position_group
            when historical_group_count > 0
                then historical_candidate
        end as selected_position_group_candidate

    from position_evidence

)

select
    * exclude (selected_position_group_candidate),

    case
        when selected_position_group_count = 1
            then selected_position_group_candidate
    end as final_position_group,

    -- Position assignment is independent of player-ID resolution.
    case
        when selected_position_group_count > 1 then 'ambiguous'
        when selected_position_group_count = 1 then 'assigned'
        when final_gsis_id is null then 'missing_identity'
        else 'missing_position'
    end as position_group_status

from selected_evidence
