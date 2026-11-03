-- Return source records whose occurrence count changed between models.
with record_changes as (

    select
        source_file_sha256,
        source_row_number,
        1 as row_change
    from {{ ref('int_ir_player_matches_reviewed') }}

    union all

    select
        source_file_sha256,
        source_row_number,
        -1 as row_change
    from {{ ref('int_ir_player_matches_normalized') }}

)

select
    source_file_sha256,
    source_row_number,
    sum(row_change) as net_row_change
from record_changes
group by
    source_file_sha256,
    source_row_number
having sum(row_change) <> 0
