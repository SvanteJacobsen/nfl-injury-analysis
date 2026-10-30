-- Configure the role used by dbt transformations.
-- Prerequisites:
--   1. setup_snowflake.sql
--   2. setup_roles.sql
--   3. Raw tables created and loaded

USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS NFL_TRANSFORMER_ROLE
    COMMENT = 'Reads RAW sources and builds dbt transformation models';

-- Keep the project role within the administration hierarchy.
GRANT ROLE NFL_TRANSFORMER_ROLE TO ROLE SYSADMIN;

-- Assign the role to the user running this setup.
SET setup_user = CURRENT_USER();

GRANT ROLE NFL_TRANSFORMER_ROLE TO USER IDENTIFIER($setup_user);

-- Grant access using the infrastructure owner.
USE ROLE SYSADMIN;

GRANT USAGE ON WAREHOUSE NFL_ANALYTICS_WH
    TO ROLE NFL_TRANSFORMER_ROLE;

GRANT USAGE ON DATABASE NFL_INJURY_ANALYSIS
    TO ROLE NFL_TRANSFORMER_ROLE;

-- Allow dbt to create its output schemas inside this project database.
GRANT CREATE SCHEMA ON DATABASE NFL_INJURY_ANALYSIS
    TO ROLE NFL_TRANSFORMER_ROLE;

-- Allow read access to existing and future RAW tables.
GRANT USAGE ON SCHEMA NFL_INJURY_ANALYSIS.RAW
    TO ROLE NFL_TRANSFORMER_ROLE;

GRANT SELECT ON ALL TABLES IN SCHEMA NFL_INJURY_ANALYSIS.RAW
    TO ROLE NFL_TRANSFORMER_ROLE;

GRANT SELECT ON FUTURE TABLES IN SCHEMA NFL_INJURY_ANALYSIS.RAW
    TO ROLE NFL_TRANSFORMER_ROLE;

-- Verify the role without inheriting other assigned roles.
USE ROLE NFL_TRANSFORMER_ROLE;
USE SECONDARY ROLES NONE;

USE WAREHOUSE NFL_ANALYTICS_WH;

SELECT CURRENT_ROLE() AS active_role;

-- Verify that the transformation role can read a source table.
SELECT COUNT(*) AS concussion_source_rows
FROM NFL_INJURY_ANALYSIS.RAW.CONCUSSIONS;
