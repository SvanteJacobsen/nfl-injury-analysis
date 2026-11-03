-- Create a raw table for the archived nflverse player register.
-- Preserve source values as text; transformations belong in dbt.

USE ROLE NFL_LOADER_ROLE;
USE SECONDARY ROLES NONE;

USE DATABASE NFL_INJURY_ANALYSIS;
USE SCHEMA RAW;

CREATE TABLE IF NOT EXISTS NFLVERSE_PLAYERS (
    GSIS_ID                         VARCHAR,
    DISPLAY_NAME                    VARCHAR,
    COMMON_FIRST_NAME               VARCHAR,
    FIRST_NAME                      VARCHAR,
    LAST_NAME                       VARCHAR,
    SHORT_NAME                      VARCHAR,
    FOOTBALL_NAME                   VARCHAR,
    SUFFIX                          VARCHAR,
    ESB_ID                          VARCHAR,
    NFL_ID                          VARCHAR,
    PFR_ID                          VARCHAR,
    PFF_ID                          VARCHAR,
    OTC_ID                          VARCHAR,
    ESPN_ID                         VARCHAR,
    SMART_ID                        VARCHAR,
    BIRTH_DATE                      VARCHAR,
    POSITION_GROUP                  VARCHAR,
    POSITION                        VARCHAR,
    NGS_POSITION_GROUP              VARCHAR,
    NGS_POSITION                    VARCHAR,
    HEIGHT                          VARCHAR,
    WEIGHT                          VARCHAR,
    HEADSHOT                        VARCHAR,
    COLLEGE_NAME                    VARCHAR,
    COLLEGE_CONFERENCE              VARCHAR,
    JERSEY_NUMBER                    VARCHAR,
    ROOKIE_SEASON                    VARCHAR,
    LAST_SEASON                      VARCHAR,
    LATEST_TEAM                      VARCHAR,
    STATUS                          VARCHAR,
    NGS_STATUS                      VARCHAR,
    NGS_STATUS_SHORT_DESCRIPTION    VARCHAR,
    YEARS_OF_EXPERIENCE              VARCHAR,
    PFF_POSITION                    VARCHAR,
    PFF_STATUS                      VARCHAR,
    DRAFT_YEAR                      VARCHAR,
    DRAFT_ROUND                     VARCHAR,
    DRAFT_PICK                      VARCHAR,
    DRAFT_TEAM                      VARCHAR,

    SOURCE_FILENAME                 VARCHAR NOT NULL,
    SOURCE_FILE_SHA256              VARCHAR NOT NULL,
    SOURCE_ROW_NUMBER               NUMBER(38, 0) NOT NULL,
    LOADED_AT                       TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

DESCRIBE TABLE NFLVERSE_PLAYERS;
