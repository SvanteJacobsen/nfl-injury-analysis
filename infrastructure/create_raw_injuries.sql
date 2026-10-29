-- Create the raw table for archived nflverse injury reports.
-- Prerequisites:
--   1. setup_snowflake.sql
--   2. setup_roles.sql

USE ROLE NFL_LOADER_ROLE;
USE SECONDARY ROLES NONE;

USE DATABASE NFL_INJURY_ANALYSIS;
USE SCHEMA RAW;

-- Preserve source values as text.
-- Support the combined column structure observed across 2015–2025.
CREATE TABLE IF NOT EXISTS NFLVERSE_INJURIES (
    SEASON                      VARCHAR,
    SEASON_TYPE                 VARCHAR,
    GAME_TYPE                   VARCHAR,
    TEAM                        VARCHAR,
    WEEK                        VARCHAR,
    GSIS_ID                     VARCHAR,
    POSITION                    VARCHAR,
    FULL_NAME                   VARCHAR,
    FIRST_NAME                  VARCHAR,
    LAST_NAME                   VARCHAR,
    REPORT_PRIMARY_INJURY       VARCHAR,
    REPORT_SECONDARY_INJURY     VARCHAR,
    REPORT_STATUS               VARCHAR,
    PRACTICE_PRIMARY_INJURY     VARCHAR,
    PRACTICE_SECONDARY_INJURY   VARCHAR,
    PRACTICE_STATUS             VARCHAR,
    DATE_MODIFIED               VARCHAR,

    -- Track the source snapshot and each record's position within it.
    SOURCE_FILE_SEASON          NUMBER(4, 0) NOT NULL,
    SOURCE_FILENAME             VARCHAR NOT NULL,
    SOURCE_FILE_SHA256          VARCHAR NOT NULL,
    SOURCE_ROW_NUMBER           NUMBER(38, 0) NOT NULL,
    LOADED_AT                   TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Verify the table structure.
DESCRIBE TABLE NFLVERSE_INJURIES;
