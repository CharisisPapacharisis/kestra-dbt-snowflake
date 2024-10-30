select
replace(v:competition.name,'"', '') as competition_name,
replace(v:season.startDate,'"', '') as season_start_date,
replace(year(v:season.startDate::date),'"', '') as season,
replace(s.value:stage,'"', '') as competition_stage,
replace(s.value:type,'"', '') as competition_type,
f.value:team.id as team_id,
replace(f.value:team.name,'"', '') as team_name,
f.value:position as position,
f.value:playedGames as played_games,
f.value:won as won,
f.value:draw as draw,
f.value:lost as lost,
f.value:points as points,
f.value:goalsFor as goals_for,
f.value:goalsAgainst as goals_against

from
{{ source('premier_league_data', 'raw_standings') }}, 
lateral flatten (input => v:standings) s, -- Flatten the standings array
lateral flatten (input => s.value:table) f -- Flatten the table array
where competition_stage = 'REGULAR_SEASON' 
    and competition_type = 'TOTAL'