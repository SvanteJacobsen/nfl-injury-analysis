{{ config(materialized='view', schema='intermediate') }}

with automatic_matches as (

    select *
    from {{ ref('int_ir_player_matches') }}

),

reviewed_decisions as (

    select *
    from {{ ref('ir_player_match_overrides') }}

)

select
    a.*,

    -- Prefer the reviewed identity when a decision exists.
    coalesce(o.gsis_id, a.matched_gsis_id) as resolved_gsis_id,

    -- Preserve how the identity was assigned.
    case
        when o.gsis_id is not null then 'matched_manual'
        else a.player_match_status
    end as resolved_match_status,

    o.review_reason as identity_review_reason

from automatic_matches as a

left join reviewed_decisions as o
    on a.season = o.season
    and a.transaction_date = o.transaction_date
    and a.player_name_key = o.player_name_key
    and a.ir_team_code = o.ir_team_code
