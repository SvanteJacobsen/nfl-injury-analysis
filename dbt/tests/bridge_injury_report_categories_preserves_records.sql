-- Return missing, extra or duplicated report-category pairs.
with expected_pairs as (

    select distinct
        injury_report_id,
        injury_category

    from {{ ref('int_injury_report_categories') }}

),

row_changes as (

    select
        injury_report_id,
        injury_category,
        1 as row_change

    from expected_pairs

    union all

    select
        injury_report_id,
        injury_category,
        -1 as row_change

    from {{ ref('bridge_injury_report_categories') }}

)

select
    injury_report_id,
    injury_category,
    sum(row_change) as net_row_change

from row_changes

group by
    injury_report_id,
    injury_category

having sum(row_change) <> 0
