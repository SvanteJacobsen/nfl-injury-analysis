-- Return report identifiers whose row counts changed.
with row_changes as (

    select
        injury_report_id,
        1 as row_change
    from {{ ref('int_injury_reports_classified') }}

    union all

    select
        injury_report_id,
        -1 as row_change
    from {{ ref('int_injury_reports_positioned') }}

)

select
    injury_report_id,
    sum(row_change) as net_row_change
from row_changes
group by injury_report_id
having sum(row_change) <> 0