-- Return inconsistent position assignments.
select *
from {{ ref('int_ir_transactions_positioned') }}
where
    (
        position_group_status = 'assigned'
        and (
            final_position_group is null
            or selected_position_group_count <> 1
            or final_gsis_id is null
        )
    )
    or (
        position_group_status <> 'assigned'
        and final_position_group is not null
    )
    or (
        selected_position_group_count > 1
        and position_group_status <> 'ambiguous'
    )
    or (
        reviewed_position_group is not null
        and (
            position_group_source <> 'reviewed'
            or final_position_group is distinct from reviewed_position_group
        )
    )
