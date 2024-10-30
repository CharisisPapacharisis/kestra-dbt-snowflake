select
replace(v:competition.name,'"', '') as competition_name,
replace(v:season.startDate,'"', '') as season_start_date,
replace(year(v:season.startDate::date),'"', '') as season,
replace(value:player.name,'"', '') as scorer,
replace(value:player.id,'"', '') as scorer_id,
replace(value:player.nationality,'"', '') as nationality,
replace(value:team.name,'"', '') as team_name,
replace(value:team.id,'"', '') as team_id,
value:playedMatches as played_matches,
value:goals as goals,
value:assists as assists,
value:penalties as penalties

from
{{ source('premier_league_data', 'raw_scorers') }}, lateral flatten (input => v:scorers)