-- Each original transaction reference must remain exactly once.
with record_balance as (

    select
        source_file_sha256,
        source_row_number,
        1 as record_delta
    from {{ ref('int_ir_player_matches') }}

    union all

    select
        source_file_sha256,
        source_row_number,
        -1 as record_delta
    from {{ ref('int_ir_player_matches_reviewed') }}

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
