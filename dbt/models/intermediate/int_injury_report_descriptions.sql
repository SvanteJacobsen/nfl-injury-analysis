{{ config(materialized='view', schema='intermediate') }}

with reports as (

    select *
    from {{ ref('int_injury_reports_deduplicated') }}

),

descriptions as (

    select
        source_file_sha256,
        source_row_number,
        'report_primary_injury' as source_field,
        report_primary_injury as injury_description
    from reports

    union all

    select
        source_file_sha256,
        source_row_number,
        'report_secondary_injury' as source_field,
        report_secondary_injury as injury_description
    from reports

    union all

    select
        source_file_sha256,
        source_row_number,
        'practice_primary_injury' as source_field,
        practice_primary_injury as injury_description
    from reports

    union all

    select
        source_file_sha256,
        source_row_number,
        'practice_secondary_injury' as source_field,
        practice_secondary_injury as injury_description
    from reports

)

select
    md5(
        source_file_sha256
        || ':'
        || cast(source_row_number as varchar)
        || ':'
        || source_field
    ) as injury_description_id,

    source_file_sha256,
    source_row_number,
    source_field,
    injury_description,
    lower(trim(injury_description)) as injury_description_key

from descriptions
where injury_description is not null