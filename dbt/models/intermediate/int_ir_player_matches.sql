{{ config(materialized='view', schema='intermediate') }}

with transactions as (

    select
        *,
        lower(trim(player_name)) as player_name_key

    from {{ ref('int_ir_transactions_team_normalized') }}

),

roster_candidates as (

    -- Repeated weekly observations of one player count as one candidate.
    select distinct
        season,
        player_name_key,
        roster_team_code,
        gsis_id

    from {{ ref('int_roster_observations') }}

    where
        gsis_id is not null
        and player_name_key is not null
        and roster_team_code is not null

),

candidate_summary as (

    -- Produce one summary row per matching key before joining to IR.
    select
        season,
        player_name_key,
        roster_team_code,
        count(*) as candidate_player_count,

        -- Assign an identity only when exactly one player fits.
        case
            when count(*) = 1 then min(gsis_id)
            else null
        end as matched_gsis_id,

        -- Retain candidate IDs for reviewing ambiguous matches.
        listagg(gsis_id, ', ')
            within group (order by gsis_id) as candidate_gsis_ids

    from roster_candidates

    group by
        season,
        player_name_key,
        roster_team_code

)

select
    t.*,
    coalesce(c.candidate_player_count, 0) as candidate_player_count,
    c.matched_gsis_id,
    c.candidate_gsis_ids,

    case
        when c.candidate_player_count = 1 then 'matched_exact'
        when c.candidate_player_count > 1 then 'ambiguous'
        else 'unmatched'
    end as player_match_status

from transactions as t

left join candidate_summary as c
    on t.season = c.season
    and t.player_name_key = c.player_name_key
    and t.ir_team_code = c.roster_team_code
