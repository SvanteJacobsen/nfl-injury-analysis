-- Configure the role used by the Python ingestion scripts.
-- Prerequisite: run infrastructure/setup_snowflake.sql first.

-- Use the security administration role to create and assign roles.
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS NFL_LOADER_ROLE
    COMMENT = 'Loads source data into the NFL injury analysis RAW schema';

-- Keep the project role within the system administration hierarchy.
GRANT ROLE NFL_LOADER_ROLE TO ROLE SYSADMIN;

-- Assign the role to the user running this setup.
-- Resolve the username dynamically so the script works in a new account.
SET setup_user = CURRENT_USER();

GRANT ROLE NFL_LOADER_ROLE TO USER IDENTIFIER($setup_user);

-- Use the infrastructure owner to grant access to project resources.
USE ROLE SYSADMIN;

-- Allow queries and data loading using the project warehouse.
GRANT USAGE ON WAREHOUSE NFL_ANALYTICS_WH
    TO ROLE NFL_LOADER_ROLE;

-- Allow access to the project database and its RAW schema.
GRANT USAGE ON DATABASE NFL_INJURY_ANALYSIS
    TO ROLE NFL_LOADER_ROLE;

GRANT USAGE ON SCHEMA NFL_INJURY_ANALYSIS.RAW
    TO ROLE NFL_LOADER_ROLE;

-- Allow the loader to create raw tables and file-loading objects.
GRANT CREATE TABLE, CREATE STAGE, CREATE FILE FORMAT
    ON SCHEMA NFL_INJURY_ANALYSIS.RAW
    TO ROLE NFL_LOADER_ROLE;

-- Verify access using only the loader role and the public role.
USE ROLE NFL_LOADER_ROLE;
USE SECONDARY ROLES NONE;

USE WAREHOUSE NFL_ANALYTICS_WH;
USE DATABASE NFL_INJURY_ANALYSIS;
USE SCHEMA RAW;

SELECT
    CURRENT_ROLE() AS active_role,
    CURRENT_WAREHOUSE() AS active_warehouse,
    CURRENT_DATABASE() AS active_database,
    CURRENT_SCHEMA() AS active_schema;
