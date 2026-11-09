-- Return seasons with missing or invalid game denominators.
select
    c.season,
    g.preseason_games,
    g.regular_season_games

from {{ ref('stg_concussions') }} as c

left join {{ ref('season_game_counts') }} as g
    on c.season = g.season

where
    g.regular_season_games is null
    or g.regular_season_games <= 0
    or g.regular_season_games <> floor(g.regular_season_games)

    or g.preseason_games is null
    or g.preseason_games < 0
    or g.preseason_games <> floor(g.preseason_games)

    or (
        c.season = 2020
        and g.preseason_games <> 0
    )

    or (
        c.season <> 2020
        and g.preseason_games = 0
    )
