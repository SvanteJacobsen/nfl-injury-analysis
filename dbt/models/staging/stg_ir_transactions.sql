{{ config(materialized='view', schema='staging') }}

-- Grain: one row per original source record.
-- Duplicate transactions are retained at this stage.
with source as (

    select *
    from {{ source('nfl_raw', 'ir_transactions') }}

),

cleaned as (

    select
        try_to_number(trim(calendar_year), 4, 0) as calendar_year,
        try_to_number(trim(season), 4, 0) as season,

        -- The source date is MM/DD. Use calendar_year, not season,
        -- to construct the full transaction date.
        trim(date) as source_date_text,

        try_to_date(
            trim(calendar_year) || '-' || replace(trim(date), '/', '-'),
            'YYYY-MM-DD'
        ) as transaction_date,

        -- Remove surrounding whitespace and represent blank text as NULL.
        nullif(trim(player_name), '') as player_name,
        nullif(trim(position), '') as source_position,
        nullif(trim(from_team), '') as from_team,
        nullif(trim(to_team), '') as to_team,
        nullif(trim(transaction_type), '') as transaction_type,

        -- Preserve metadata to trace each record back to its source.
        source_filename,
        source_file_sha256,
        source_row_number,
        loaded_at

    from source

)

select *
from cleaned
