-- Return inconsistent preseason game counts or rates.
select *
from {{ ref('fct_concussions') }}

where
    (
        preseason_games = 0
        and (
            preseason_game_concussions is not null
            or preseason_game_concussions_per_game is not null
        )
    )

    or (
        preseason_games > 0
        and (
            preseason_game_concussions is null
            or preseason_game_concussions_per_game is null
            or abs(
                preseason_game_concussions_per_game
                - (
                    preseason_game_concussions
                    / nullif(preseason_games, 0)
                )
            ) > 0.000001
        )
    )
