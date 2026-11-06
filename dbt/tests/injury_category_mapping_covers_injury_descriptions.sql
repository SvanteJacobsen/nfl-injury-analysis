-- Return injury descriptions without a standardized category mapping.
select
    d.injury_description_key,
    count(*) as description_occurrences

from {{ ref('int_injury_report_descriptions_classified') }} as d

left join {{ ref('injury_description_category_mapping') }} as m
    on d.injury_description_key = m.injury_description_key

where
    d.has_injury_information = true
    and m.injury_description_key is null

group by
    d.injury_description_key