-- Return records that violate the identity assignment rules.
select *
from {{ ref('int_ir_player_matches_normalized') }}

where

    -- Previously resolved identities must remain unchanged.
    (
        resolved_match_status <> 'unmatched'
        and (
            final_gsis_id is distinct from resolved_gsis_id
            or final_match_status is distinct from resolved_match_status
        )
    )

    -- New normalized matches require exactly one candidate identity.
    or (
        final_match_status = 'matched_normalized'
        and (
            resolved_match_status <> 'unmatched'
            or normalized_candidate_count <> 1
            or final_gsis_id is null
        )
    )

    -- Unmatched records must not have an assigned identity.
    or (
        final_match_status = 'unmatched'
        and final_gsis_id is not null
    )

    -- A previously unmatched record may only gain a normalized match.
    or (
        resolved_match_status = 'unmatched'
        and final_match_status not in (
            'unmatched',
            'matched_normalized'
        )
    )
