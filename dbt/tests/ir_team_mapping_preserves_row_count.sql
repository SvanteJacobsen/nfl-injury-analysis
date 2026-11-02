-- Return a failure if the team-mapping join changes the row count.
with before_mapping as (

    select count(*) as transaction_count
    from {{ ref('int_ir_transactions_deduplicated') }}

),

after_mapping as (

    select count(*) as transaction_count
    from {{ ref('int_ir_transactions_team_normalized') }}

)

select
    b.transaction_count as before_mapping_count,
    a.transaction_count as after_mapping_count

from before_mapping as b
cross join after_mapping as a

where b.transaction_count <> a.transaction_count
