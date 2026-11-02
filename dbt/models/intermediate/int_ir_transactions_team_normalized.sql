{{ config(materialized='view', schema='intermediate') }}

-- Grain: one row per deduplicated IR transaction.
with transactions as (

    select *
    from {{ ref('int_ir_transactions_deduplicated') }}

),

team_aliases as (

    select
        team_alias,
        franchise_code
    from {{ ref('team_aliases') }}

)

select
    t.*,

    -- Use the destination team for Reserve/Injured transactions.
    -- Keep the original From and To values in the output.
    a.franchise_code as ir_team_code

from transactions as t

-- Retain the transaction even if its team cannot be mapped.
left join team_aliases as a
    on lower(trim(t.to_team)) = a.team_alias
