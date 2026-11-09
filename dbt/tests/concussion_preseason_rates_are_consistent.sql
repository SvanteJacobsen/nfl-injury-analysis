-- Return invalid counts or totals that disagree with their components.
select *
from {{ ref('fct_concussions') }}

where
    preseason_practice_concussions < 0
    or preseason_game_concussions < 0
    or regular_season_practice_concussions < 0
    or regular_season_game_concussions < 0
    or total_concussions < 0

    or (
        season <> 2020
        and preseason_game_concussions is null
    )

    or total_concussions is distinct from (
        preseason_practice_concussions
        + coalesce(preseason_game_concussions, 0)
        + regular_season_practice_concussions
        + regular_season_game_concussions
    )
