{{ config(materialized='table', schema='marts') }}

select
    -- Identify the retained source row within the archived snapshot.
    md5(
        source_file_sha256
        || ':'
        || cast(source_row_number as varchar)
    ) as ir_placement_id,

    season,
    transaction_date,
    ir_team_code,
    player_name,

    final_gsis_id as gsis_id,
    final_position_group as position_group,

    final_match_status as player_match_status,
    position_group_status,
    position_group_source,
    position_group_review_reason,

    -- Preserve traceability to the original source.
    source_filename,
    source_file_sha256,
    source_row_number,
    source_record_count

from {{ ref('int_ir_transactions_positioned') }}
