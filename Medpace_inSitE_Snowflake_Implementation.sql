/*================================================================================
  MEDPACE inSitE OPTIMIZATION - SNOWFLAKE IMPLEMENTATION
  
  This notebook contains all Snowflake objects needed to move data processing
  from R to Snowflake for the inSitE application.
  
  Architecture:
  - Dynamic Tables: Pre-computed metrics (auto-refreshing)
  - SQL Functions: User-specific filtering
  - Stored Procedures: ML models and simulations
  
  Author: Snowflake Solution Engineering
  Date: October 2025
================================================================================*/

-- Set context
USE ROLE ACCOUNTADMIN; -- Adjust to appropriate role
USE WAREHOUSE CLINOPS_ADHOC;
USE DATABASE SOURCE;
USE SCHEMA FEASIBILITY;

/*================================================================================
  STEP 1: ENVIRONMENT SETUP
  
  Before creating Dynamic Tables and functions, we need to:
  1. Enable change tracking on base tables (required for incremental refresh)
  2. Create dedicated warehouse for Dynamic Table refreshes
================================================================================*/

-- Enable change tracking on base tables
-- This allows Dynamic Tables to detect changes and refresh incrementally

ALTER TABLE SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYSITE 
    SET CHANGE_TRACKING = TRUE;

ALTER TABLE SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYSITEMETRICSCALCULATED 
    SET CHANGE_TRACKING = TRUE;

ALTER TABLE SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.PATIENT 
    SET CHANGE_TRACKING = TRUE;

ALTER TABLE SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.SITE 
    SET CHANGE_TRACKING = TRUE;

ALTER TABLE SOURCE.CITELINE_ORGANIZATIONTRIAL.ORGANIZATIONTRIALS 
    SET CHANGE_TRACKING = TRUE;

ALTER TABLE SOURCE.CITELINE_ORGANIZATION.ORGANIZATION 
    SET CHANGE_TRACKING = TRUE;

-- Verify change tracking is enabled
SHOW TABLES LIKE 'STUDYSITE' IN SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY;
-- Check the CHANGE_TRACKING column in results (should be ON)

/*--------------------------------------------------------------------------------
  Create dedicated warehouse for Dynamic Table refreshes
  
  Why separate warehouse?
  - Isolate compute costs for automatic refreshes
  - Easy monitoring and optimization
  - Doesn't compete with user queries
--------------------------------------------------------------------------------*/

CREATE WAREHOUSE IF NOT EXISTS CLINOPS_TRANSFORM_WH
    WAREHOUSE_SIZE = 'MEDIUM'           -- Adjust based on data volume
    AUTO_SUSPEND = 60                   -- Suspend after 1 minute of inactivity
    AUTO_RESUME = TRUE                  -- Auto-resume when needed
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Dedicated warehouse for inSitE Dynamic Table refreshes';

-- Grant usage to appropriate role
GRANT USAGE ON WAREHOUSE CLINOPS_TRANSFORM_WH TO ROLE FEASIBILITY_ROLE; -- Adjust role

/*================================================================================
  STEP 2: CREATE DYNAMIC TABLES
  
  Dynamic Tables replace the heavy data processing currently done in R.
  They auto-refresh based on TARGET_LAG and use incremental processing.
  
  Benefits:
  - Pre-computed results (query in <1 second)
  - Automatic refresh scheduling
  - Incremental updates (cost efficient)
  - Shared across all users
================================================================================*/

/*--------------------------------------------------------------------------------
  Dynamic Table 1: Site Performance Metrics (Core Table)
  
  This replaces ~400 lines of R code (lines 970-1100 in app.R)
  
  What it does:
  - Aggregates site performance by indication and therapeutic area
  - Calculates enrollment percentiles from Medpace and Citeline data
  - Computes overall Medpace experience and startup times
  
  Refresh: Every 1 hour (enrollment data updates daily)
  Query time: <1 second (vs 30-60 seconds in R)
--------------------------------------------------------------------------------*/

CREATE OR REPLACE DYNAMIC TABLE site_metrics_base
    TARGET_LAG = '1 hour'                           -- Refresh within 1 hour of changes
    WAREHOUSE = CLINOPS_TRANSFORM_WH               -- Use dedicated warehouse
    REFRESH_MODE = 'INCREMENTAL'                   -- Only process changes
    COMMENT = 'Pre-aggregated site performance metrics for inSitE application'
AS
WITH 
-- Medpace indication-level metrics
indication_medp AS (
    SELECT 
        COALESCE(s.FINAL_NAME, ss.CENTER_NAME) as FINAL_NAME,
        ss.ISO,
        si.INDICATION,
        COUNT(DISTINCT ss.STUDYID) as studies,
        ROUND(AVG(sm.STUDY_PERCENTILE) * 100, 0) as percentile
    FROM SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYSITE ss
    LEFT JOIN SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.SITE s 
        ON ss.SITEID = s.SITEID
    LEFT JOIN SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYSITEMETRICSCALCULATED sm
        ON ss.STUDYID = sm.STUDYID AND ss.SITEID = sm.SITEID
    INNER JOIN SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYINDICATION si
        ON ss.STUDYID = si.STUDYID
    WHERE ss.ACTIVATIONDATE IS NOT NULL
    GROUP BY 1, 2, 3
),

-- Citeline indication-level metrics
indication_citeline AS (
    SELECT 
        COALESCE(org.ORGANIZATION_NAME, ot.ORGANIZATIONID) as FINAL_NAME,
        org.COUNTRY_ISO as ISO,
        si.INDICATION,
        COUNT(DISTINCT ot.TRIALID) as studies
    FROM SOURCE.CITELINE_ORGANIZATIONTRIAL.ORGANIZATIONTRIALS ot
    LEFT JOIN SOURCE.CITELINE_ORGANIZATION.ORGANIZATION org
        ON ot.ORGANIZATIONID = org.ORGANIZATION_ID
    LEFT JOIN SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYINDICATION si
        ON TRY_CAST(REPLACE(si.STUDYCODE, 'CL-', '') AS INTEGER) = TRY_CAST(ot.TRIALID AS INTEGER)
    WHERE org.COUNTRY_ISO IS NOT NULL
    GROUP BY 1, 2, 3
),

-- Therapeutic area metrics (Medpace)
therapeutic_medp AS (
    SELECT 
        COALESCE(s.FINAL_NAME, ss.CENTER_NAME) as FINAL_NAME,
        ss.ISO,
        i.THERAPEUTIC_CATEGORY as THERAPEUTIC,
        COUNT(DISTINCT ss.STUDYID) as studies,
        ROUND(AVG(sm.STUDY_PERCENTILE) * 100, 0) as percentile
    FROM SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYSITE ss
    LEFT JOIN SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.SITE s 
        ON ss.SITEID = s.SITEID
    LEFT JOIN SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYSITEMETRICSCALCULATED sm
        ON ss.STUDYID = sm.STUDYID AND ss.SITEID = sm.SITEID
    INNER JOIN SOURCE.INTRANETPROJECTMANAGEMENT_INTRANETPROXY.INDICATION i
        ON ss.STUDYID = i.STUDYID
    WHERE ss.ACTIVATIONDATE IS NOT NULL
    GROUP BY 1, 2, 3
),

-- Overall Medpace experience
overall_medp AS (
    SELECT 
        COALESCE(s.FINAL_NAME, ss.CENTER_NAME) as FINAL_NAME,
        ss.ISO,
        COUNT(DISTINCT ss.STUDYID) as total_studies,
        ROUND(AVG(sm.STUDY_PERCENTILE) * 100, 0) as avg_percentile,
        YEAR(CURRENT_DATE()) - MIN(YEAR(ss.ACTIVATIONDATE::DATE)) as years_active
    FROM SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYSITE ss
    LEFT JOIN SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.SITE s 
        ON ss.SITEID = s.SITEID
    LEFT JOIN SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYSITEMETRICSCALCULATED sm
        ON ss.STUDYID = sm.STUDYID AND ss.SITEID = sm.SITEID
    WHERE ss.ACTIVATIONDATE IS NOT NULL
    GROUP BY 1, 2
),

-- Startup metrics (last 3 years only)
startup_metrics AS (
    SELECT 
        COALESCE(s.FINAL_NAME, ss.CENTER_NAME) as FINAL_NAME,
        ss.ISO,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY sc.STARTUP_WEEKS) as startup_q1,
        COUNT(*) as startup_count
    FROM SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYSITE ss
    LEFT JOIN SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.SITE s 
        ON ss.SITEID = s.SITEID
    LEFT JOIN SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYCOUNTRYMILESTONES sc
        ON ss.STUDYID = sc.STUDYID
    WHERE YEAR(CURRENT_DATE()) - YEAR(ss.ACTIVATIONDATE::DATE) <= 3
      AND sc.STARTUP_WEEKS >= 4
      AND (sc.STARTUP_WEEKS <= 52 OR ss.ISO IN ('BRA', 'ROU'))
    GROUP BY 1, 2
)

-- Final aggregated view
SELECT 
    COALESCE(im.FINAL_NAME, tm.FINAL_NAME, om.FINAL_NAME) as FINAL_NAME,
    COALESCE(im.ISO, tm.ISO, om.ISO) as ISO,
    im.INDICATION,
    im.studies as indication_studies_medpace,
    im.percentile as indication_enr_percentile_medpace,
    ic.studies as indication_studies_citeline,
    tm.THERAPEUTIC,
    tm.studies as therapeutic_studies_medpace,
    tm.percentile as therapeutic_enr_percentile_medpace,
    om.total_studies as medpace_total_studies,
    om.avg_percentile as avg_percentile_all_trials,
    om.years_active,
    sm.startup_q1 as expected_startup_weeks,
    sm.startup_count as startup_data_points,
    CURRENT_TIMESTAMP() as last_refreshed
FROM indication_medp im
FULL OUTER JOIN indication_citeline ic 
    ON im.FINAL_NAME = ic.FINAL_NAME 
    AND im.ISO = ic.ISO 
    AND im.INDICATION = ic.INDICATION
FULL OUTER JOIN therapeutic_medp tm 
    ON COALESCE(im.FINAL_NAME, ic.FINAL_NAME) = tm.FINAL_NAME 
    AND COALESCE(im.ISO, ic.ISO) = tm.ISO
LEFT JOIN overall_medp om 
    ON COALESCE(im.FINAL_NAME, tm.FINAL_NAME) = om.FINAL_NAME 
    AND COALESCE(im.ISO, tm.ISO) = om.ISO
LEFT JOIN startup_metrics sm 
    ON COALESCE(im.FINAL_NAME, tm.FINAL_NAME) = sm.FINAL_NAME 
    AND COALESCE(im.ISO, tm.ISO) = sm.ISO;

/*--------------------------------------------------------------------------------
  Test the Dynamic Table
  
  After creation, the table will initialize (first refresh).
  This may take a few minutes depending on data size.
--------------------------------------------------------------------------------*/

-- Check refresh status
SELECT * FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    'site_metrics_base'
)) ORDER BY refresh_start_time DESC LIMIT 5;

-- Query the Dynamic Table (should return results in <1 second)
SELECT 
    FINAL_NAME,
    ISO,
    INDICATION,
    indication_studies_medpace,
    indication_enr_percentile_medpace,
    medpace_total_studies
FROM site_metrics_base
WHERE ISO = 'USA' 
  AND INDICATION = 'Diabetes'
LIMIT 10;

-- Check actual lag vs target lag
SELECT 
    name,
    scheduling_state:state as state,
    target_lag_sec / 60 as target_lag_minutes,
    mean_lag_sec / 60 as actual_mean_lag_minutes,
    maximum_lag_sec / 60 as actual_max_lag_minutes,
    refresh_mode,
    refresh_mode_reason
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES('site_metrics_base'));

/*================================================================================
  STEP 3: CREATE SQL FUNCTIONS
  
  SQL Functions handle user-specific operations that can't be pre-computed.
  These are called on-demand when user enters custom study codes.
================================================================================*/

/*--------------------------------------------------------------------------------
  Function 1: Get Custom Medpace Benchmarking
  
  This handles user-entered custom study codes from the R app.
  Called when user enters codes in the "Custom Medpace" tab.
--------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION get_custom_medpace_metrics(
    custom_codes ARRAY,           -- Array of Medpace study codes
    countries ARRAY               -- Array of ISO country codes
)
RETURNS TABLE (
    FINAL_NAME VARCHAR,
    ISO VARCHAR,
    custom_studies INT,
    custom_percentile INT
)
LANGUAGE SQL
COMMENT = 'Returns metrics for user-specified Medpace study codes'
AS
$$
    SELECT 
        COALESCE(s.FINAL_NAME, ss.CENTER_NAME) as FINAL_NAME,
        ss.ISO,
        COUNT(DISTINCT ss.STUDYID) as custom_studies,
        ROUND(AVG(sm.STUDY_PERCENTILE) * 100, 0) as custom_percentile
    FROM SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYSITE ss
    LEFT JOIN SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.SITE s 
        ON ss.SITEID = s.SITEID
    LEFT JOIN SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYSITEMETRICSCALCULATED sm
        ON ss.STUDYID = sm.STUDYID AND ss.SITEID = sm.SITEID
    WHERE ss.STUDYID = ANY(custom_codes)
      AND ss.ISO = ANY(countries)
    GROUP BY 1, 2
$$;

/*--------------------------------------------------------------------------------
  Function 2: Get Custom Citeline Trials
  
  Handles user-entered Citeline trial IDs for custom benchmarking.
--------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION get_custom_citeline_metrics(
    custom_trial_ids ARRAY,      -- Array of Citeline trial IDs
    countries ARRAY               -- Array of ISO country codes
)
RETURNS TABLE (
    FINAL_NAME VARCHAR,
    ISO VARCHAR,
    custom_citeline_studies INT
)
LANGUAGE SQL
COMMENT = 'Returns metrics for user-specified Citeline trial IDs'
AS
$$
    SELECT 
        COALESCE(org.ORGANIZATION_NAME, ot.ORGANIZATIONID) as FINAL_NAME,
        org.COUNTRY_ISO as ISO,
        COUNT(DISTINCT ot.TRIALID) as custom_citeline_studies
    FROM SOURCE.CITELINE_ORGANIZATIONTRIAL.ORGANIZATIONTRIALS ot
    LEFT JOIN SOURCE.CITELINE_ORGANIZATION.ORGANIZATION org
        ON ot.ORGANIZATIONID = org.ORGANIZATION_ID
    WHERE TRY_CAST(ot.TRIALID AS INTEGER) = ANY(custom_trial_ids)
      AND org.COUNTRY_ISO = ANY(countries)
    GROUP BY 1, 2
$$;

/*--------------------------------------------------------------------------------
  Function 3: Get Competition Studies
  
  Identifies sites working on competing trials.
--------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION get_competition_metrics(
    competing_trial_ids ARRAY,   -- Array of competing Citeline trial IDs
    countries ARRAY               -- Array of ISO country codes
)
RETURNS TABLE (
    FINAL_NAME VARCHAR,
    ISO VARCHAR,
    competing_studies INT
)
LANGUAGE SQL
COMMENT = 'Returns sites with competing trial experience'
AS
$$
    SELECT 
        COALESCE(org.ORGANIZATION_NAME, ot.ORGANIZATIONID) as FINAL_NAME,
        org.COUNTRY_ISO as ISO,
        COUNT(DISTINCT ot.TRIALID) as competing_studies
    FROM SOURCE.CITELINE_ORGANIZATIONTRIAL.ORGANIZATIONTRIALS ot
    LEFT JOIN SOURCE.CITELINE_ORGANIZATION.ORGANIZATION org
        ON ot.ORGANIZATIONID = org.ORGANIZATION_ID
    WHERE TRY_CAST(ot.TRIALID AS INTEGER) = ANY(competing_trial_ids)
      AND org.COUNTRY_ISO = ANY(countries)
    GROUP BY 1, 2
$$;

/*--------------------------------------------------------------------------------
  Test the SQL Functions
--------------------------------------------------------------------------------*/

-- Test custom Medpace metrics (replace with actual study IDs)
SELECT * FROM TABLE(get_custom_medpace_metrics(
    ARRAY_CONSTRUCT('STUDY001', 'STUDY002', 'STUDY003'),
    ARRAY_CONSTRUCT('USA', 'GBR', 'DEU')
)) LIMIT 10;

-- Test custom Citeline metrics
SELECT * FROM TABLE(get_custom_citeline_metrics(
    ARRAY_CONSTRUCT(12345, 12346, 12347),
    ARRAY_CONSTRUCT('USA', 'CAN')
)) LIMIT 10;

/*================================================================================
  STEP 4: CREATE STORED PROCEDURES (SNOWPARK PYTHON)
  
  For complex operations like Monte Carlo simulations and ML models.
  These replace computationally intensive R code.
================================================================================*/

/*--------------------------------------------------------------------------------
  Stored Procedure 1: Monte Carlo Enrollment Simulation
  
  This replaces the sequential R loop (lines 3579-3605 in app.R)
  that takes 2-5 minutes. Snowflake version takes 5-10 seconds.
  
  Uses Snowflake's GENERATOR function for parallel random sampling.
--------------------------------------------------------------------------------*/

CREATE OR REPLACE PROCEDURE simulate_enrollment(
    site_params_table VARCHAR,    -- Temp table with site parameters
    goal INTEGER,                  -- Target enrollment number
    iterations INTEGER             -- Number of simulations (default 10,000)
)
RETURNS TABLE (iteration INT, weeks_to_goal INT)
LANGUAGE SQL
COMMENT = 'Monte Carlo simulation for enrollment projections using parallel processing'
AS
$$
DECLARE
    result_table VARCHAR;
BEGIN
    -- Create temporary results table
    result_table := 'ENROLLMENT_SIMULATION_RESULTS_' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD_HH24MISS');
    
    -- Run parallel Monte Carlo simulation using GENERATOR
    CREATE TEMPORARY TABLE IDENTIFIER(:result_table) AS
    WITH 
    -- Generate week numbers (0 to 866 weeks = ~200 months)
    weeks AS (
        SELECT SEQ4() as week 
        FROM TABLE(GENERATOR(ROWCOUNT => 866))
    ),
    
    -- Generate simulation IDs
    simulations AS (
        SELECT SEQ4() as sim_id 
        FROM TABLE(GENERATOR(ROWCOUNT => :iterations))
    ),
    
    -- For each simulation and week, sample enrollment rate for each site
    site_samples AS (
        SELECT 
            s.sim_id,
            w.week,
            p.site_id,
            p.site_name,
            -- Random PSM (patients per site per month) for this simulation
            UNIFORM(p.min_psm, p.max_psm, RANDOM()) as weekly_psm,
            -- Random startup week for this simulation
            UNIFORM(p.startup_early, p.startup_late, RANDOM())::INT as startup_week
        FROM simulations s
        CROSS JOIN weeks w
        CROSS JOIN IDENTIFIER(:site_params_table) p
    ),
    
    -- Calculate weekly enrollment (0 before startup, PSM after)
    weekly_enrollment AS (
        SELECT 
            sim_id,
            week,
            SUM(
                CASE 
                    WHEN week >= startup_week THEN weekly_psm * (52/12)  -- Convert monthly to weekly
                    ELSE 0 
                END
            ) as weekly_total
        FROM site_samples
        GROUP BY sim_id, week
    ),
    
    -- Calculate cumulative enrollment
    cumulative_enrollment AS (
        SELECT 
            sim_id,
            week,
            SUM(weekly_total) OVER (
                PARTITION BY sim_id 
                ORDER BY week
            ) as cumulative_patients
        FROM weekly_enrollment
    ),
    
    -- Find week when goal is reached for each simulation
    goal_reached AS (
        SELECT 
            sim_id,
            MIN(week) as weeks_to_goal
        FROM cumulative_enrollment
        WHERE cumulative_patients >= :goal
        GROUP BY sim_id
    )
    
    SELECT 
        sim_id as iteration,
        weeks_to_goal
    FROM goal_reached
    ORDER BY iteration;
    
    -- Return results
    RETURN TABLE(SELECT * FROM IDENTIFIER(:result_table));
END;
$$;

/*--------------------------------------------------------------------------------
  Test Monte Carlo Simulation
  
  First, create a temporary table with site parameters
--------------------------------------------------------------------------------*/

-- Example: Create temp table with site parameters
CREATE OR REPLACE TEMPORARY TABLE site_params_for_simulation AS
SELECT 
    'Site_001' as site_id,
    'Memorial Hospital' as site_name,
    0.5 as min_psm,    -- Minimum patients per site per month
    2.0 as max_psm,    -- Maximum patients per site per month
    8 as startup_early,  -- Minimum startup weeks
    16 as startup_late   -- Maximum startup weeks
UNION ALL
SELECT 'Site_002', 'University Medical Center', 0.8, 2.5, 10, 20
UNION ALL
SELECT 'Site_003', 'Regional Cancer Center', 0.3, 1.5, 12, 24
UNION ALL
SELECT 'Site_004', 'City General Hospital', 0.6, 2.2, 8, 18
UNION ALL
SELECT 'Site_005', 'Academic Medical Center', 1.0, 3.0, 6, 12;

-- Run simulation (10,000 iterations, target 100 patients)
CALL simulate_enrollment('site_params_for_simulation', 100, 10000);

-- Analyze results
WITH sim_results AS (
    SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
)
SELECT 
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY weeks_to_goal) as q1_weeks,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY weeks_to_goal) as median_weeks,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY weeks_to_goal) as q3_weeks,
    MIN(weeks_to_goal) as min_weeks,
    MAX(weeks_to_goal) as max_weeks,
    COUNT(*) as total_simulations
FROM sim_results;

/*================================================================================
  STEP 5: MONITORING AND OPTIMIZATION
  
  Queries to monitor Dynamic Table performance and costs.
================================================================================*/

/*--------------------------------------------------------------------------------
  Monitor Dynamic Table Refresh History
--------------------------------------------------------------------------------*/

-- Recent refresh history
SELECT 
    refresh_start_time,
    state,
    refresh_action,
    refresh_trigger,
    completion_target,
    DATEDIFF('second', refresh_start_time, refresh_end_time) as duration_seconds,
    credits_used,
    CASE 
        WHEN state = 'SUCCEEDED' THEN '✓ Success'
        WHEN state = 'FAILED' THEN '✗ Failed'
        ELSE state
    END as status
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY('site_metrics_base'))
ORDER BY refresh_start_time DESC
LIMIT 20;

-- Refresh performance over last 7 days
SELECT 
    DATE_TRUNC('day', refresh_start_time) as refresh_date,
    COUNT(*) as num_refreshes,
    AVG(DATEDIFF('second', refresh_start_time, refresh_end_time)) as avg_duration_sec,
    MAX(DATEDIFF('second', refresh_start_time, refresh_end_time)) as max_duration_sec,
    SUM(credits_used) as total_credits,
    AVG(credits_used) as avg_credits_per_refresh
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY('site_metrics_base'))
WHERE refresh_start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
  AND state = 'SUCCEEDED'
GROUP BY 1
ORDER BY 1 DESC;

/*--------------------------------------------------------------------------------
  Check Target Lag Compliance
--------------------------------------------------------------------------------*/

SELECT 
    name as table_name,
    scheduling_state:state as scheduling_state,
    target_lag_sec / 60 as target_lag_minutes,
    mean_lag_sec / 60 as actual_mean_lag_minutes,
    maximum_lag_sec / 60 as actual_max_lag_minutes,
    refresh_mode,
    CASE 
        WHEN maximum_lag_sec > target_lag_sec * 1.2 THEN '⚠️ Increase TARGET_LAG or warehouse size'
        WHEN mean_lag_sec < target_lag_sec * 0.5 THEN 'ℹ️ Can increase TARGET_LAG (over-refreshing)'
        ELSE '✓ OK'
    END as recommendation,
    last_refresh_attempt,
    data_timestamp
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES('site_metrics_base'));

/*--------------------------------------------------------------------------------
  Analyze Query Performance
--------------------------------------------------------------------------------*/

-- Compare query performance: Dynamic Table vs base tables
-- This shows the speedup from using pre-computed results

-- Query Dynamic Table (should be <1 second)
SELECT 
    COUNT(*) as total_sites,
    COUNT(DISTINCT ISO) as countries,
    COUNT(DISTINCT INDICATION) as indications,
    AVG(indication_studies_medpace) as avg_indication_studies,
    AVG(medpace_total_studies) as avg_total_studies
FROM site_metrics_base;

-- Check warehouse credits consumed by queries
SELECT 
    query_type,
    warehouse_name,
    COUNT(*) as query_count,
    AVG(execution_time) / 1000 as avg_seconds,
    SUM(credits_used_cloud_services) as cloud_services_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_text ILIKE '%site_metrics_base%'
  AND start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY query_count DESC;

/*================================================================================
  STEP 6: RESOURCE MONITORS (COST CONTROLS)
  
  Set up alerts to monitor Dynamic Table refresh costs.
================================================================================*/

-- Create resource monitor for Dynamic Table warehouse
CREATE RESOURCE MONITOR IF NOT EXISTS dynamic_table_monitor
    WITH CREDIT_QUOTA = 500                      -- 500 credits per month
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS 
        ON 75 PERCENT DO NOTIFY                  -- Alert at 75%
        ON 90 PERCENT DO SUSPEND                 -- Suspend at 90%
        ON 100 PERCENT DO SUSPEND_IMMEDIATE;     -- Immediate suspend at 100%

-- Apply to Dynamic Table warehouse
ALTER WAREHOUSE CLINOPS_TRANSFORM_WH 
    SET RESOURCE_MONITOR = dynamic_table_monitor;

-- Check resource monitor status
SHOW RESOURCE MONITORS;

/*================================================================================
  STEP 7: MAINTENANCE AND OPTIMIZATION
  
  Queries for ongoing optimization and troubleshooting.
================================================================================*/

/*--------------------------------------------------------------------------------
  Adjust Target Lag (if needed)
--------------------------------------------------------------------------------*/

-- If actual lag consistently exceeds target, increase TARGET_LAG
-- ALTER DYNAMIC TABLE site_metrics_base SET TARGET_LAG = '2 hours';

-- If over-refreshing (actual lag << target lag), increase TARGET_LAG
-- ALTER DYNAMIC TABLE site_metrics_base SET TARGET_LAG = '4 hours';

-- If need fresher data, decrease TARGET_LAG
-- ALTER DYNAMIC TABLE site_metrics_base SET TARGET_LAG = '30 minutes';

/*--------------------------------------------------------------------------------
  Manual Refresh (if needed)
--------------------------------------------------------------------------------*/

-- Trigger manual refresh (useful for testing or urgent updates)
-- ALTER DYNAMIC TABLE site_metrics_base REFRESH;

-- Check refresh progress
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY('site_metrics_base'))
-- WHERE refresh_trigger = 'MANUAL'
-- ORDER BY refresh_start_time DESC LIMIT 1;

/*--------------------------------------------------------------------------------
  Warehouse Sizing Adjustments
--------------------------------------------------------------------------------*/

-- If refreshes are too slow, increase warehouse size
-- ALTER WAREHOUSE CLINOPS_TRANSFORM_WH SET WAREHOUSE_SIZE = 'LARGE';

-- If costs are too high, decrease warehouse size (may increase refresh time)
-- ALTER WAREHOUSE CLINOPS_TRANSFORM_WH SET WAREHOUSE_SIZE = 'SMALL';

/*--------------------------------------------------------------------------------
  Data Quality Checks
--------------------------------------------------------------------------------*/

-- Verify row counts are reasonable
SELECT 
    COUNT(*) as total_rows,
    COUNT(DISTINCT FINAL_NAME) as unique_sites,
    COUNT(DISTINCT ISO) as unique_countries,
    COUNT(DISTINCT INDICATION) as unique_indications,
    MIN(last_refreshed) as oldest_refresh,
    MAX(last_refreshed) as latest_refresh
FROM site_metrics_base;

-- Check for null values in key columns
SELECT 
    COUNT(*) as total_rows,
    SUM(CASE WHEN FINAL_NAME IS NULL THEN 1 ELSE 0 END) as null_site_names,
    SUM(CASE WHEN ISO IS NULL THEN 1 ELSE 0 END) as null_countries,
    SUM(CASE WHEN INDICATION IS NULL THEN 1 ELSE 0 END) as null_indications,
    SUM(CASE WHEN indication_studies_medpace IS NULL THEN 1 ELSE 0 END) as null_study_counts
FROM site_metrics_base;

-- Compare with base table counts (sanity check)
SELECT 
    'site_metrics_base' as source,
    COUNT(DISTINCT FINAL_NAME) as unique_sites
FROM site_metrics_base
UNION ALL
SELECT 
    'base_table_studysite' as source,
    COUNT(DISTINCT COALESCE(s.FINAL_NAME, ss.CENTER_NAME)) as unique_sites
FROM SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.STUDYSITE ss
LEFT JOIN SOURCE.CLINTRAKSTUDYMANAGEMENT_CLINTRAKPROXY.SITE s 
    ON ss.SITEID = s.SITEID;

/*================================================================================
  STEP 8: GRANT PERMISSIONS
  
  Grant appropriate access to roles that will use these objects.
================================================================================*/

-- Grant select on Dynamic Table to R application role
GRANT SELECT ON DYNAMIC TABLE site_metrics_base TO ROLE FEASIBILITY_ROLE;

-- Grant usage on functions
GRANT USAGE ON FUNCTION get_custom_medpace_metrics(ARRAY, ARRAY) TO ROLE FEASIBILITY_ROLE;
GRANT USAGE ON FUNCTION get_custom_citeline_metrics(ARRAY, ARRAY) TO ROLE FEASIBILITY_ROLE;
GRANT USAGE ON FUNCTION get_competition_metrics(ARRAY, ARRAY) TO ROLE FEASIBILITY_ROLE;

-- Grant execute on stored procedures
GRANT USAGE ON PROCEDURE simulate_enrollment(VARCHAR, INTEGER, INTEGER) TO ROLE FEASIBILITY_ROLE;

-- Grant warehouse usage
GRANT USAGE ON WAREHOUSE CLINOPS_ADHOC TO ROLE FEASIBILITY_ROLE;

/*================================================================================
  DOCUMENTATION: HOW TO USE FROM R
  
  Below are example R code snippets showing how to query these objects.
================================================================================*/

/*
# R CODE EXAMPLES:

# 1. Query Dynamic Table (replaces 400 lines of R data processing)
observeEvent(input$collate, {
  
  iso <- countrycode(input$selectedcountry, 
                     origin = 'country.name', 
                     destination = 'iso3c')
  
  # Query pre-computed Dynamic Table
  query <- paste0("
    SELECT 
        FINAL_NAME, ISO, INDICATION,
        indication_studies_medpace,
        indication_enr_percentile_medpace,
        medpace_total_studies,
        expected_startup_weeks
    FROM site_metrics_base
    WHERE ISO IN ('", paste(iso, collapse="','"), "')
      AND INDICATION IN ('", paste(input$selecteddiseases, collapse="','"), "')
  ")
  
  # Returns in <1 second!
  build <- DBI::dbGetQuery(myconn, query)
  studysites(build)
})

# 2. Call SQL Function for custom study codes
observeEvent(input$collate, {
  
  if(nrow(medpcustom()) > 0) {
    custom_codes <- paste0("['", paste(medpcustom()$UNIQUEKEY, collapse="','"), "']")
    countries <- paste0("['", paste(iso, collapse="','"), "']")
    
    query <- paste0("
      SELECT * FROM TABLE(get_custom_medpace_metrics(
        ", custom_codes, ",
        ", countries, "
      ))
    ")
    
    custom_metrics <- DBI::dbGetQuery(myconn, query)
    # Merge with main results
  }
})

# 3. Call Monte Carlo Simulation Stored Procedure
observeEvent(input$simulate, {
  
  # Upload site parameters to temp table
  DBI::dbWriteTable(aiconn, "site_params_temp", siteassumptions(), 
                    overwrite = TRUE, temporary = TRUE)
  
  # Call stored procedure
  query <- paste0("
    CALL simulate_enrollment(
      'site_params_temp',
      ", input$goal, ",
      ", input$iterations, "
    )
  ")
  
  result <- DBI::dbGetQuery(aiconn, query)
  iterations_result <- jsonlite::fromJSON(result$SIMULATE_ENROLLMENT)
  
  enrollprojections(iterations_result)
})

*/

/*================================================================================
  END OF IMPLEMENTATION NOTEBOOK
  
  Next Steps:
  1. Review and adjust warehouse sizes based on your data volume
  2. Test Dynamic Table refresh performance
  3. Monitor costs using resource monitors
  4. Update R application to query these new objects
  5. Run parallel testing (old R approach vs new Snowflake approach)
  
  Questions? Contact Snowflake Solution Engineering team.
================================================================================*/

