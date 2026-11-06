-- Verify that each retained report is represented exactly once.
with row_changes as (

    select
        source_file_sha256,
        source_row_number,
        1 as row_change
    from {{ ref('int_injury_reports_deduplicated') }}

    union all

    select
        source_file_sha256,
        source_row_number,
        -1 as row_change
    from {{ ref('int_injury_reports_classified') }}

)

select
    source_file_sha256,
    source_row_number,
    sum(row_change) as row_difference
from row_changes
group by source_file_sha256, source_row_number
having sum(row_change) <> 0