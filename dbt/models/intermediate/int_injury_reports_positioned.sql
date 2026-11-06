{{ config(materialized='view', schema='intermediate') }}

with prepared_reports as (

    -- Remove surrounding spaces, tabs and line breaks for matching.
    select
        *,
        nullif(
            upper(
                trim(
                    position,
                    ' ' || chr(9) || chr(10) || chr(13)
                )
            ),
            ''
        ) as cleaned_position

    from {{ ref('int_injury_reports_classified') }}

),

weekly_roster_groups as (

    -- Summarize roster evidence before joining it to reports.
    select
        r.season,
        r.week,
        r.roster_team_code,
        r.gsis_id,
        count(distinct m.position_group) as group_count,
        min(m.position_group) as candidate_group

    from {{ ref('int_roster_observations') }} as r

    inner join {{ ref('position_group_mapping') }} as m
        on upper(trim(r.position)) = m.position_code

    where
        r.roster_source = 'weekly_roster'
        and r.gsis_id is not null

    group by
        r.season,
        r.week,
        r.roster_team_code,
        r.gsis_id

),

position_evidence as (

    select
        r.*,
        m.position_group as reported_position_group,
        coalesce(w.group_count, 0) as roster_position_group_count,
        w.candidate_group as roster_position_group_candidate

    from prepared_reports as r

    left join {{ ref('position_group_mapping') }} as m
        on r.cleaned_position = m.position_code

    left join weekly_roster_groups as w
        on r.season = w.season
        and r.week = w.week
        and upper(trim(r.team)) = w.roster_team_code
        and r.gsis_id = w.gsis_id
        -- Restrict this fallback to regular-season reports.
        and r.game_type = 'REG'
        and m.position_code is null

)

select
    * exclude (roster_position_group_candidate),

    case
        when reported_position_group is not null
            then reported_position_group
        when roster_position_group_count = 1
            then roster_position_group_candidate
    end as position_group,

    case
        when reported_position_group is not null then 'injury_report'
        when roster_position_group_count = 1 then 'weekly_roster'
        when roster_position_group_count > 1 then 'ambiguous_roster'
        else 'none'
    end as position_group_source

from position_evidence