{{ config(materialized='view', schema='intermediate') }}

-- Grain: one transaction per combination of season, date,
-- player name, From team, To team and transaction type.
with source as (

    select *
    from {{ ref('stg_ir_transactions') }}

),

ranked as (

    select
        *,

        -- Count how many source records represent this transaction.
        count(*) over (
            partition by
                season,
                transaction_date,
                player_name,
                from_team,
                to_team,
                transaction_type
        ) as source_record_count,

        -- Keep one representative record using a reproducible order.
        -- This ordering does not imply that a record is more accurate.
        row_number() over (
            partition by
                season,
                transaction_date,
                player_name,
                from_team,
                to_team,
                transaction_type
            order by
                source_file_sha256,
                source_filename,
                source_row_number
        ) as duplicate_rank

    from source

)

select
    calendar_year,
    season,
    transaction_date,
    source_date_text,
    player_name,
    source_position,
    from_team,
    to_team,
    transaction_type,
    source_record_count,

    -- Metadata identifies the representative source record.
    source_filename,
    source_file_sha256,
    source_row_number,
    loaded_at

from ranked

where duplicate_rank = 1
