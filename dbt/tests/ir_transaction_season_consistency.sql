-- Return records that violate the documented August–February scope.
-- January and February belong to the preceding NFL season.
select
    season,
    calendar_year,
    source_date_text,
    transaction_date,
    player_name,
    source_filename,
    source_row_number

from {{ ref('stg_ir_transactions') }}

where
    month(transaction_date) not in (8, 9, 10, 11, 12, 1, 2)

    or season <> case
        when month(transaction_date) in (1, 2)
            then year(transaction_date) - 1
        else year(transaction_date)
    end
