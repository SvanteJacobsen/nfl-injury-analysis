-- The represented source records must equal the staging row count.
with staging as (

    select count(*) as staging_records
    from {{ ref('stg_ir_transactions') }}

),

deduplicated as (

    select
        coalesce(sum(source_record_count), 0) as represented_source_records
    from {{ ref('int_ir_transactions_deduplicated') }}

)

select
    s.staging_records,
    d.represented_source_records

from staging as s
cross join deduplicated as d

where s.staging_records <> d.represented_source_records
