{{ config(materialized='view', schema='intermediate') }}

with mapped_descriptions as (

    -- Attach every applicable category to each injury description.
    select
        d.source_file_sha256,
        d.source_row_number,
        d.source_field,
        m.injury_category

    from {{ ref('int_injury_report_descriptions_classified') }} as d

    inner join {{ ref('injury_description_category_mapping') }} as m
        on d.injury_description_key = m.injury_description_key

    where d.has_injury_information = true

),

report_categories as (

    -- Keep one row per retained report and category.
    select
        source_file_sha256,
        source_row_number,
        injury_category,
        count(distinct source_field) as source_field_count

    from mapped_descriptions

    group by
        source_file_sha256,
        source_row_number,
        injury_category

)

select
    md5(
        source_file_sha256
        || ':' || cast(source_row_number as varchar)
        || ':' || injury_category
    ) as injury_report_category_id,

    md5(
        source_file_sha256
        || ':' || cast(source_row_number as varchar)
    ) as injury_report_id,

    source_file_sha256,
    source_row_number,
    injury_category,
    source_field_count

from report_categories