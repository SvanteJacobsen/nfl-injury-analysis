-- Verify that each description occurrence is retained exactly once.
with row_changes as (

    select
        injury_description_id,
        1 as row_change
    from {{ ref('int_injury_report_descriptions') }}

    union all

    select
        injury_description_id,
        -1 as row_change
    from {{ ref('int_injury_report_descriptions_classified') }}

)

select
    injury_description_id,
    sum(row_change) as row_difference
from row_changes
group by injury_description_id
having sum(row_change) <> 0