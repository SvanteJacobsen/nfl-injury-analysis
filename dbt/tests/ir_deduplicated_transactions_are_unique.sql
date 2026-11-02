-- Return transaction groups that still contain multiple records.
select
    season,
    transaction_date,
    player_name,
    from_team,
    to_team,
    transaction_type,
    count(*) as transaction_records

from {{ ref('int_ir_transactions_deduplicated') }}

group by
    season,
    transaction_date,
    player_name,
    from_team,
    to_team,
    transaction_type

having count(*) > 1
