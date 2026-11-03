-- Check each source separately so that a change in one source
-- cannot cancel out a change in the other.
with expected as (

    select
        'season_roster' as roster_source,
        count(*) as expected_records
    from {{ ref('stg_nflverse_rosters') }}

    union all

    select
        'weekly_roster' as roster_source,
        count(*) as expected_records
    from {{ ref('stg_nflverse_weekly_rosters') }}

),

actual as (

    select
        roster_source,
        count(*) as actual_records
    from {{ ref('int_roster_observations') }}
    group by roster_source

)

select
    coalesce(e.roster_source, a.roster_source) as roster_source,
    e.expected_records,
    a.actual_records

from expected as e

full outer join actual as a
    on e.roster_source = a.roster_source

where
    coalesce(e.expected_records, 0)
        <> coalesce(a.actual_records, 0)
