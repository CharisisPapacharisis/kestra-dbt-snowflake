------------------------------------------------------------------------------------
--SETUP

--create database
CREATE DATABASE MY_DB;

--create schema
CREATE SCHEMA MY_SCHEMA;

--create target tables for scorers and standings data
CREATE TABLE MY_SCHEMA.raw_scorers(v variant);
CREATE TABLE MY_SCHEMA.raw_standings(v variant);

--create storage location
CREATE OR REPLACE STORAGE INTEGRATION my_s3_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::XXXXXXXXX:role/charisis-snowflake-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://charisis-data-lake/');

  --describe integration
DESCRIBE INTEGRATION my_s3_integration;

-- create s3 stage
CREATE OR REPLACE STAGE my_s3_stage
  STORAGE_INTEGRATION = my_s3_integration
  URL = 's3://charisis-data-lake';

-- list files included under the stage
LIST @my_s3_stage;


------------------------------------------------------------------------------------
--QUERIES

--copy into destination tables
copy into raw_scorers
from @my_s3_stage/premier-league/scorers/
FILE_FORMAT = (TYPE = 'JSON');

select * from raw_scorers;

copy into raw_standings
from @my_s3_stage/premier-league/standings/
FILE_FORMAT = (TYPE = 'JSON');

select * from raw_standings;

--truncate tables (we will use Kestra for the COPY INTO activity)
truncate table my_db.my_schema.raw_scorers;
truncate table my_db.my_schema.raw_standings;

--flattening json in snowflake 
select
replace(v:competition.name,'"', '') as competition_name,
replace(v:season.startDate,'"', '') as season_start_date,
replace(year(v:season.startDate::date),'"', '') as season,
replace(value:player.name,'"', '') as scorer,
replace(value:player.id,'"', '') as scorer_id,
replace(value:player.nationality,'"', '') as nationality,
replace(value:team.name,'"', '') as team_name,
replace(value:team.id,'"', '') as team_id,
value:playedMatches as playedMatches,
value:goals as goals,
value:assists as assists,
value:penalties as penalties
from
my_db.my_schema.raw_scorers, lateral flatten (input => v:scorers); -- Flatten the scorers array


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
my_db.my_schema.raw_standings,
lateral flatten (input => v:standings) s, -- Flatten the standings array
lateral flatten (input => s.value:table) f -- Flatten the table array
where competition_stage = 'REGULAR_SEASON'
    and competition_type = 'TOTAL';