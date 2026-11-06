{{ config(materialized='view', schema='intermediate') }}

with description_summary as (

    -- Summarize all description fields belonging to the same report.
    select
        source_file_sha256,
        source_row_number,

        count(*) as description_count,

        count_if(
            classification_status = 'needs_review'
        ) as unmapped_description_count,

        count_if(
            has_injury_information
        ) as injury_description_count,

        count_if(
            has_illness_information
        ) as illness_description_count,

        count_if(
            has_non_injury_information
        ) as non_injury_description_count,

        count_if(
            has_other_health_information
        ) as other_health_description_count,

        count_if(
            has_covid_related_information
        ) as covid_related_description_count,

        count_if(
            description_class = 'evaluation'
        ) as evaluation_description_count,

        count_if(
            description_class = 'unspecified'
        ) as unspecified_description_count

    from {{ ref('int_injury_report_descriptions_classified') }}

    group by
        source_file_sha256,
        source_row_number

)

select
    r.*,

    -- Identify the retained report within the archived source snapshot.
    md5(
        r.source_file_sha256
        || ':'
        || cast(r.source_row_number as varchar)
    ) as injury_report_id,

    coalesce(d.description_count, 0) as description_count,

    coalesce(
        d.unmapped_description_count, 0
    ) as unmapped_description_count,

    coalesce(
        d.injury_description_count, 0
    ) > 0 as has_injury_information,

    coalesce(
        d.illness_description_count, 0
    ) > 0 as has_illness_information,

    coalesce(
        d.non_injury_description_count, 0
    ) > 0 as has_non_injury_information,

    coalesce(
        d.other_health_description_count, 0
    ) > 0 as has_other_health_information,

    coalesce(
        d.covid_related_description_count, 0
    ) > 0 as has_covid_related_information,

    coalesce(
        d.evaluation_description_count, 0
    ) > 0 as has_evaluation_information,

    coalesce(
        d.unspecified_description_count, 0
    ) > 0 as has_unspecified_information,

    case
        when coalesce(d.description_count, 0) = 0
            then 'missing_description'
        when coalesce(d.unmapped_description_count, 0) > 0
            then 'needs_review'
        else 'mapped'
    end as report_classification_status

from {{ ref('int_injury_reports_deduplicated') }} as r

left join description_summary as d
    on r.source_file_sha256 = d.source_file_sha256
    and r.source_row_number = d.source_row_number