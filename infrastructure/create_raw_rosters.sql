-- Create raw tables for nflverse season and weekly roster snapshots.
-- Prerequisites:
--   1. setup_snowflake.sql
--   2. setup_roles.sql

USE ROLE NFL_LOADER_ROLE;
USE SECONDARY ROLES NONE;

USE DATABASE NFL_INJURY_ANALYSIS;
USE SCHEMA RAW;

-- Preserve every observed source column as text.
-- Data types and analytical field selection belong in dbt.
CREATE TABLE IF NOT EXISTS NFLVERSE_ROSTERS (
    SEASON                      VARCHAR,
    TEAM                        VARCHAR,
    POSITION                    VARCHAR,
    DEPTH_CHART_POSITION        VARCHAR,
    JERSEY_NUMBER               VARCHAR,
    STATUS                      VARCHAR,
    FULL_NAME                   VARCHAR,
    FIRST_NAME                  VARCHAR,
    LAST_NAME                   VARCHAR,
    BIRTH_DATE                  VARCHAR,
    HEIGHT                      VARCHAR,
    WEIGHT                      VARCHAR,
    COLLEGE                     VARCHAR,
    GSIS_ID                     VARCHAR,
    ESPN_ID                     VARCHAR,
    SPORTRADAR_ID               VARCHAR,
    YAHOO_ID                    VARCHAR,
    ROTOWIRE_ID                 VARCHAR,
    PFF_ID                      VARCHAR,
    PFR_ID                      VARCHAR,
    FANTASY_DATA_ID             VARCHAR,
    SLEEPER_ID                  VARCHAR,
    YEARS_EXP                   VARCHAR,
    HEADSHOT_URL                VARCHAR,
    NGS_POSITION                VARCHAR,
    WEEK                        VARCHAR,
    GAME_TYPE                   VARCHAR,
    STATUS_DESCRIPTION_ABBR     VARCHAR,
    FOOTBALL_NAME               VARCHAR,
    ESB_ID                      VARCHAR,
    GSIS_IT_ID                  VARCHAR,
    SMART_ID                    VARCHAR,
    ENTRY_YEAR                  VARCHAR,
    ROOKIE_YEAR                 VARCHAR,
    DRAFT_CLUB                  VARCHAR,
    DRAFT_NUMBER                VARCHAR,

    -- Record the source snapshot and each record's position within it.
    SOURCE_FILE_SEASON          NUMBER(4, 0) NOT NULL,
    SOURCE_FILENAME             VARCHAR NOT NULL,
    SOURCE_FILE_SHA256          VARCHAR NOT NULL,
    SOURCE_ROW_NUMBER           NUMBER(38, 0) NOT NULL,
    LOADED_AT                   TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Create an empty weekly table with the same column definitions.
-- LIKE copies the structure, not the stored rows.
CREATE TABLE IF NOT EXISTS NFLVERSE_WEEKLY_ROSTERS
    LIKE NFLVERSE_ROSTERS;

-- Verify both table structures.
DESCRIBE TABLE NFLVERSE_ROSTERS;
DESCRIBE TABLE NFLVERSE_WEEKLY_ROSTERS;
