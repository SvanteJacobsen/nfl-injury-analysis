{{ config(materialized='view', schema='intermediate') }}

select
    r.*,
    a.franchise_code as team_code

from {{ ref('int_injury_reports_positioned') }} as r

left join {{ ref('team_aliases') }} as a
    on lower(trim(r.team)) = lower(trim(a.team_alias))