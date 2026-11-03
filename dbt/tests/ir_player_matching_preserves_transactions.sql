-- Check each transaction using its representative source reference.
-- Positive and negative counts must cancel for every reference.
with record_balance as (

    select
        source_file_sha256,
        source_row_number,
        1 as record_delta
    from {{ ref('int_ir_transactions_team_normalized') }}

    union all

    select
        source_file_sha256,
        source_row_number,
        -1 as record_delta
    from {{ ref('int_ir_player_matches') }}

)

select
    source_file_sha256,
    source_row_number,
    sum(record_delta) as record_difference

from record_balance

group by
    source_file_sha256,
    source_row_number

having sum(record_delta) <> 0
