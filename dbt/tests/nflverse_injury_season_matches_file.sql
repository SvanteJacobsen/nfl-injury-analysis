-- Return records whose reported season differs from their source file.
-- Missing season values are checked by separate not_null tests.
select
    season,
    source_file_season,
    gsis_id,
    player_name,
    source_filename,
    source_row_number

from {{ ref('stg_nflverse_injuries') }}

where season <> source_file_season
