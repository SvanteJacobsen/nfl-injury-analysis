-- Each decision key must occur once and match exactly one transaction.
select
    o.season,
    o.transaction_date,
    o.player_name_key,
    o.ir_team_code,
    count(a.source_row_number) as matching_transaction_records

from {{ ref('ir_player_match_overrides') }} as o

left join {{ ref('int_ir_player_matches') }} as a
    on o.season = a.season
    and o.transaction_date = a.transaction_date
    and o.player_name_key = a.player_name_key
    and o.ir_team_code = a.ir_team_code

group by
    o.season,
    o.transaction_date,
    o.player_name_key,
    o.ir_team_code

having count(a.source_row_number) <> 1
