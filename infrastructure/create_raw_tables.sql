-- Create raw tables before running the Python ingestion scripts.
-- Prerequisites:
--   1. setup_snowflake.sql
--   2. setup_roles.sql

USE ROLE NFL_LOADER_ROLE;
USE SECONDARY ROLES NONE;

USE DATABASE NFL_INJURY_ANALYSIS;
USE SCHEMA RAW;

-- Preserve source values as text.
-- FROM_TEAM and TO_TEAM map to the CSV headers "from" and "to".
CREATE TABLE IF NOT EXISTS IR_TRANSACTIONS (
    CALENDAR_YEAR       VARCHAR,
    SEASON              VARCHAR,
    FROM_TEAM           VARCHAR,
    TO_TEAM             VARCHAR,
    DATE                VARCHAR,
    PLAYER_NAME         VARCHAR,
    POSITION            VARCHAR,
    TRANSACTION_TYPE    VARCHAR,

    -- Record where each row came from and when it was loaded.
    SOURCE_FILENAME     VARCHAR NOT NULL,
    SOURCE_FILE_SHA256  VARCHAR NOT NULL,
    SOURCE_ROW_NUMBER   NUMBER(38, 0) NOT NULL,
    LOADED_AT           TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Preserve source metrics, including existing per-game values.
-- Validated metrics will be calculated in the transformation layer.
CREATE TABLE IF NOT EXISTS CONCUSSIONS (
    YEAR                        VARCHAR,
    PRESEASON_PRACTICE           VARCHAR,
    PRESEASON_GAME               VARCHAR,
    PRESEASON_PER_GAME           VARCHAR,
    REGULAR_SEASON_PRACTICE      VARCHAR,
    REGULAR_SEASON_GAME          VARCHAR,
    REGULAR_SEASON_PER_GAME      VARCHAR,
    TOTAL_CONCUSSIONS           VARCHAR,

    SOURCE_FILENAME             VARCHAR NOT NULL,
    SOURCE_FILE_SHA256          VARCHAR NOT NULL,
    SOURCE_ROW_NUMBER           NUMBER(38, 0) NOT NULL,
    LOADED_AT                   TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Confirm that both tables exist.
SHOW TABLES IN SCHEMA NFL_INJURY_ANALYSIS.RAW;
