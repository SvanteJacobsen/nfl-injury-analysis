{{ config(materialized='table', schema='marts') }}

-- Grain: one retained report and standardized injury category pair.
select
    c.injury_report_id,
    c.injury_category

from {{ ref('int_injury_report_categories') }} as c

inner join {{ ref('fct_injury_reports') }} as r
    on c.injury_report_id = r.injury_report_id
