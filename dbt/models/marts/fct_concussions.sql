{{ config(materialized='table', schema='marts') }}

-- Grain: one season of aggregate reported concussion counts.
select
    c.season,
    c.preseason_practice_concussions,
    c.preseason_game_concussions,
    c.regular_season_practice_concussions,
    c.regular_season_game_concussions,
    c.total_concussions,

    g.preseason_games,
    g.regular_season_games,

    c.preseason_game_concussions
        / nullif(g.preseason_games, 0)
        as preseason_game_concussions_per_game,

    c.regular_season_game_concussions
        / nullif(g.regular_season_games, 0)
        as regular_season_game_concussions_per_game

from {{ ref('stg_concussions') }} as c

left join {{ ref('season_game_counts') }} as g
    on c.season = g.season
