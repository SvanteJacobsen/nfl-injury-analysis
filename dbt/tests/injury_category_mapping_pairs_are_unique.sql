-- Return duplicate description/category pairs in the mapping seed.
select
    injury_description_key,
    injury_category,
    count(*) as mapping_rows
from {{ ref('injury_description_category_mapping') }}
group by
    injury_description_key,
    injury_category
having count(*) > 1
