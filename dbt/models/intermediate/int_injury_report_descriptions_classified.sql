{{ config(materialized='view', schema='intermediate') }}

with classified as (

    select
        d.*,
        c.description_class,

        case
            when c.injury_description_key is null then 'needs_review'
            else 'mapped'
        end as classification_status

    from {{ ref('int_injury_report_descriptions') }} as d

    left join {{ ref('injury_description_classification') }} as c
        on d.injury_description_key = c.injury_description_key

)

select
    *,

    description_class in (
        'injury',
        'injury_and_illness',
        'injury_and_non_injury'
    ) as has_injury_information,

    description_class in (
        'illness',
        'injury_and_illness'
    ) as has_illness_information,

    description_class in (
        'non_injury',
        'injury_and_non_injury'
    ) as has_non_injury_information,

    description_class = 'health_other'
        as has_other_health_information,

    description_class = 'covid_related'
        as has_covid_related_information

from classified