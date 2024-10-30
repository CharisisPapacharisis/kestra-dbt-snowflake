select 
a.scorer,
a.played_matches as scorer_played_games,
a.goals as scorer_goals,
a.assists as scorer_assists,
a.penalties as scorer_penalties,
b.team_name,
b.position,
b.played_games as team_played_games,
b.won as team_games_won,
b.draw as team_games_draw,
b.lost as team_games_lost,
b.points as team_points,
b.goals_for as team_goals_for,
b.goals_against as team_goals_against,
(scorer_played_games/team_played_games)::DECIMAL(10,2) as games_ratio_over_total,
(scorer_goals/team_goals_for)::DECIMAL(10,2) as goals_ratio_over_total,
from {{ ref("stg__scorers") }} a
left join {{ ref("stg__standings") }} b
on a.team_id = b.team_id
