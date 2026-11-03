{{ config(materialized='view', schema='intermediate') }}

with transactions as (

    -- Keep existing identity decisions and add a comparison key.
    select
        *,
        {{ normalize_player_name('player_name') }}
            as normalized_player_name_key
    from {{ ref('int_ir_player_matches_reviewed') }}

),

roster_names as (

    -- Apply the same name rule to the roster observations.
    select
        season,
        roster_team_code,
        gsis_id,
        {{ normalize_player_name('player_name') }}
            as normalized_player_name_key
    from {{ ref('int_roster_observations') }}
    where gsis_id is not null

),

candidate_summary as (

    -- Count different player identities for each matching key.
    select
        season,
        roster_team_code,
        normalized_player_name_key,
        count(distinct gsis_id) as candidate_count,

        case
            when count(distinct gsis_id) = 1 then min(gsis_id)
        end as candidate_gsis_id

    from roster_names
    where normalized_player_name_key is not null
    group by
        season,
        roster_team_code,
        normalized_player_name_key

)

select
    t.*,

    coalesce(c.candidate_count, 0)
        as normalized_candidate_count,

    coalesce(t.resolved_gsis_id, c.candidate_gsis_id)
        as final_gsis_id,

    case
        when t.resolved_match_status = 'unmatched'
            and c.candidate_count = 1
            then 'matched_normalized'
        else t.resolved_match_status
    end as final_match_status

from transactions as t

left join candidate_summary as c
    on t.season = c.season
    and t.ir_team_code = c.roster_team_code
    and t.normalized_player_name_key = c.normalized_player_name_key
    and t.resolved_match_status = 'unmatched'
