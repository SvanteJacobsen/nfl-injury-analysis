-- Each reviewed decision must target exactly one unresolved transaction.
with decisions as (

    select
        *,
        count(*) over (
            partition by
                season,
                transaction_date,
                ir_team_code,
                player_name_key
        ) as decision_key_count
    from {{ ref('ir_transaction_position_overrides') }}

)

select q.*
from decisions as q

where q.decision_key_count <> 1

    or (
        select count(*)
        from {{ ref('int_ir_player_matches_normalized') }} as t
        where t.season = q.season
            and t.transaction_date = q.transaction_date
            and t.ir_team_code = q.ir_team_code
            and t.player_name_key = q.player_name_key
            and t.final_gsis_id is null
    ) <> 1
