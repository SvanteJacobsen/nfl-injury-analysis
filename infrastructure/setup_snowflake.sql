-- Set up the infrastructure for the NFL injury analysis project.
-- Run this script before creating tables or loading source data.
-- Existing objects are preserved when the script is run again.

-- Use the system role intended for managing databases and warehouses.
USE ROLE SYSADMIN;

-- Create dedicated compute for this project.
-- Start suspended to avoid running compute before it is needed.
CREATE WAREHOUSE IF NOT EXISTS NFL_ANALYTICS_WH
    WAREHOUSE_TYPE = 'STANDARD'
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

-- Apply the intended settings even when the warehouse already exists.
ALTER WAREHOUSE NFL_ANALYTICS_WH SET
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

-- Create the project database without replacing existing data.
CREATE DATABASE IF NOT EXISTS NFL_INJURY_ANALYSIS;

-- Store source records in a separate raw schema.
-- Transformation schemas will be configured when we set up dbt.
CREATE SCHEMA IF NOT EXISTS NFL_INJURY_ANALYSIS.RAW;

-- Select the project resources for this session.
USE WAREHOUSE NFL_ANALYTICS_WH;
USE DATABASE NFL_INJURY_ANALYSIS;
USE SCHEMA RAW;

-- Verify the active session context.
SELECT
    CURRENT_ROLE() AS active_role,
    CURRENT_WAREHOUSE() AS active_warehouse,
    CURRENT_DATABASE() AS active_database,
    CURRENT_SCHEMA() AS active_schema;
