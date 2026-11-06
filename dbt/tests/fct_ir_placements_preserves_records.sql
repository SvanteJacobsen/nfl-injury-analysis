-- Return any difference between the intermediate and mart records.
with expected as (

    select
        source_file_sha256,
        source_row_number,
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
        source_filename,
        source_record_count
    from {{ ref('int_ir_transactions_positioned') }}

),

actual as (

    select
        source_file_sha256,
        source_row_number,
        season,
        transaction_date,
        ir_team_code,
        player_name,
        gsis_id,
        position_group,
        player_match_status,
        position_group_status,
        position_group_source,
        position_group_review_reason,
        source_filename,
        source_record_count
    from {{ ref('fct_ir_placements') }}

),

missing_or_changed as (

    select * from expected
    minus
    select * from actual

),

unexpected_or_changed as (

    select * from actual
    minus
    select * from expected

)

select * from missing_or_changed

union all

select * from unexpected_or_changed
