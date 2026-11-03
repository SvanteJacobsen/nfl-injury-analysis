-- Return records with inconsistent candidate counts or assignments.
select
    season,
    player_name,
    ir_team_code,
    candidate_player_count,
    matched_gsis_id,
    player_match_status

from {{ ref('int_ir_player_matches') }}

where
    (
        player_match_status = 'matched_exact'
        and (
            candidate_player_count <> 1
            or matched_gsis_id is null
        )
    )

    or (
        player_match_status = 'ambiguous'
        and (
            candidate_player_count <= 1
            or matched_gsis_id is not null
        )
    )

    or (
        player_match_status = 'unmatched'
        and (
            candidate_player_count <> 0
            or matched_gsis_id is not null
        )
    )
