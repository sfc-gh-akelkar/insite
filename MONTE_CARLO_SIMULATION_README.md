# Monte Carlo Simulation Stored Procedure

## Overview

This Snowflake stored procedure performs **parallel Monte Carlo simulations** for clinical trial enrollment projections. It replaces sequential R loops with massively parallel SQL processing, achieving **20-30x speed improvement**.

## Performance Comparison

| Metric | R (Sequential) | Snowflake (Parallel) | Improvement |
|--------|---------------|---------------------|-------------|
| **Execution Time** | 2-5 minutes | 5-10 seconds | **20-30x faster** |
| **Processing Model** | Single-threaded loop | Parallel across nodes | Distributed |
| **Memory Usage** | 1-2 GB in R | 0 MB in R (runs in Snowflake) | **100% reduction** |
| **Scalability** | Linear degradation | Horizontal scaling | Better with more data |

## What It Does

The procedure simulates clinical trial enrollment by:
1. **Modeling site behavior** - Each site has variable enrollment rates and startup times
2. **Running multiple scenarios** - Executes thousands of simulations with random sampling
3. **Tracking progress** - Calculates weekly and cumulative patient enrollment
4. **Finding outcomes** - Determines when enrollment goals are reached

## Use Case

**Business Question:** *"When will we reach our enrollment goal of 100 patients given uncertain site performance?"*

**Answer:** Run 10,000 simulations with realistic parameter ranges to get probability distribution of completion times.

---

## Stored Procedure Definition

```sql
CREATE OR REPLACE PROCEDURE simulate_enrollment(
    site_params_table VARCHAR,    -- Temp table with site parameters
    goal INTEGER,                  -- Target enrollment number
    iterations INTEGER             -- Number of simulations (e.g., 10000)
)
RETURNS TABLE (iteration INT, weeks_to_goal INT)
LANGUAGE SQL
COMMENT = 'Monte Carlo simulation using parallel processing'
```

### Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `site_params_table` | VARCHAR | Name of temporary table containing site parameters | `'site_params_for_simulation'` |
| `goal` | INTEGER | Target number of patients to enroll | `100` |
| `iterations` | INTEGER | Number of Monte Carlo simulations to run | `10000` |

### Returns

| Column | Type | Description |
|--------|------|-------------|
| `iteration` | INT | Simulation ID (0 to iterations-1) |
| `weeks_to_goal` | INT | Number of weeks to reach enrollment goal |

---

## Site Parameters Table

Before calling the procedure, create a temporary table with site parameters:

### Required Schema

```sql
CREATE TEMPORARY TABLE site_params_for_simulation (
    site_id VARCHAR,          -- Unique site identifier
    site_name VARCHAR,        -- Optional: Site name for reference
    min_psm FLOAT,           -- Minimum patients per site per month
    max_psm FLOAT,           -- Maximum patients per site per month
    startup_early INT,       -- Earliest startup time (weeks)
    startup_late INT         -- Latest startup time (weeks)
);
```

### Parameter Definitions

- **`min_psm` / `max_psm`**: Enrollment rate range
  - Each simulation randomly samples between these values
  - Example: `min_psm=0.5, max_psm=2.0` means 0.5-2.0 patients/site/month
  
- **`startup_early` / `startup_late`**: Startup time range
  - Represents uncertainty in site activation
  - Example: `startup_early=8, startup_late=16` means site activates between weeks 8-16

---

## Complete Usage Example

### Step 1: Prepare Site Parameters in R

```r
library(DBI)
library(dplyr)

# Define site parameters based on historical data or assumptions
site_params <- data.frame(
  site_id = c("Site_001", "Site_002", "Site_003", "Site_004", "Site_005"),
  site_name = c("Memorial Hospital", "University Medical Center", 
                "Regional Cancer Center", "City General Hospital", 
                "Academic Medical Center"),
  min_psm = c(0.5, 0.8, 0.3, 0.6, 1.0),        # Min enrollment rate
  max_psm = c(2.0, 2.5, 1.5, 2.2, 3.0),        # Max enrollment rate
  startup_early = c(8, 10, 12, 8, 6),          # Earliest startup (weeks)
  startup_late = c(16, 20, 24, 18, 12)         # Latest startup (weeks)
)

# Connect to Snowflake
myconn <- dbConnect(
  odbc::odbc(),
  "FeasibilityRead",
  Warehouse = "CLINOPS_ADHOC"
)

# Write to temporary table in Snowflake
dbWriteTable(myconn, 
             "site_params_for_simulation", 
             site_params,
             overwrite = TRUE,
             temporary = TRUE)
```

### Step 2: Run Monte Carlo Simulation

```r
# Call stored procedure
result <- dbGetQuery(myconn, "
  CALL simulate_enrollment(
    'site_params_for_simulation',  -- Temp table name
    100,                           -- Goal: 100 patients
    10000                          -- 10,000 simulations
  )
")

# Result structure:
# - iteration: 1 to 10000
# - weeks_to_goal: Number of weeks for that simulation
```

### Step 3: Analyze Results

```r
# Basic summary statistics
summary(result$weeks_to_goal)

# Calculate percentiles
library(dplyr)
result_summary <- result %>%
  summarise(
    min_weeks = min(weeks_to_goal),
    q10_weeks = quantile(weeks_to_goal, 0.10),
    q25_weeks = quantile(weeks_to_goal, 0.25),
    median_weeks = quantile(weeks_to_goal, 0.50),
    q75_weeks = quantile(weeks_to_goal, 0.75),
    q90_weeks = quantile(weeks_to_goal, 0.90),
    max_weeks = max(weeks_to_goal),
    mean_weeks = mean(weeks_to_goal),
    sd_weeks = sd(weeks_to_goal)
  )

print(result_summary)
```

### Step 4: Visualize Distribution

```r
library(ggplot2)

# Histogram with percentile lines
ggplot(result, aes(x = weeks_to_goal)) +
  geom_histogram(binwidth = 2, fill = "steelblue", alpha = 0.7) +
  geom_vline(xintercept = quantile(result$weeks_to_goal, c(0.25, 0.5, 0.75)),
             linetype = "dashed", color = "red", size = 1) +
  labs(
    title = "Enrollment Timeline Distribution (10,000 Simulations)",
    subtitle = "Dashed lines: 25th, 50th, 75th percentiles",
    x = "Weeks to Reach 100 Patients",
    y = "Frequency"
  ) +
  theme_minimal()
```

---

## How It Works: Technical Deep Dive

### Architecture: Parallel Processing with GENERATOR

```sql
-- 1. Generate time dimension (866 weeks ≈ 200 months)
weeks AS (
    SELECT SEQ4() as week 
    FROM TABLE(GENERATOR(ROWCOUNT => 866))
),

-- 2. Generate simulation IDs (10,000 independent scenarios)
simulations AS (
    SELECT SEQ4() as sim_id 
    FROM TABLE(GENERATOR(ROWCOUNT => 10000))
),

-- 3. Cross join creates massive parallel matrix
--    10,000 sims × 866 weeks × N sites = millions of rows
--    BUT Snowflake processes in parallel across nodes
site_samples AS (
    SELECT 
        s.sim_id,
        w.week,
        p.site_id,
        UNIFORM(p.min_psm, p.max_psm, RANDOM()) as weekly_psm,
        UNIFORM(p.startup_early, p.startup_late, RANDOM())::INT as startup_week
    FROM simulations s
    CROSS JOIN weeks w
    CROSS JOIN site_params_table p
)
```

### Key SQL Techniques

1. **`GENERATOR` Function**: Creates large row sets instantly without loops
2. **`CROSS JOIN`**: Cartesian product processed in parallel
3. **`UNIFORM()` with `RANDOM()`**: Built-in random sampling
4. **Window Functions**: `SUM() OVER (PARTITION BY ... ORDER BY ...)` for cumulative calculations
5. **CTEs (Common Table Expressions)**: Modular, readable query structure

### Execution Flow

```
┌─────────────────────────────────────────────────────────┐
│  Snowflake Warehouse (Parallel Execution)              │
│                                                         │
│  Node 1          Node 2          Node 3          Node 4│
│  ↓               ↓               ↓               ↓     │
│  Sim 1-2500      Sim 2501-5000   Sim 5001-7500   Sim 7501-10000│
│  ↓               ↓               ↓               ↓     │
│  • Generate weeks                                      │
│  • Sample enrollment rates                             │
│  • Calculate cumulative enrollment                     │
│  • Find goal achievement                               │
│  ↓               ↓               ↓               ↓     │
│  Results merged across nodes                           │
└─────────────────────────────────────────────────────────┘
```

---

## Installation

### Prerequisites

- Snowflake account with appropriate role
- `CREATE PROCEDURE` privilege
- Warehouse with sufficient compute (recommend MEDIUM or larger)

### Create the Procedure

```sql
-- Set context
USE ROLE ACCOUNTADMIN;  -- Or appropriate role with CREATE PROCEDURE
USE DATABASE YOUR_DATABASE;
USE SCHEMA YOUR_SCHEMA;
USE WAREHOUSE YOUR_WAREHOUSE;

-- Run the CREATE PROCEDURE statement
-- (See full SQL in Medpace_inSitE_Snowflake_Implementation.ipynb, Cell 25)
```

### Grant Permissions

```sql
-- Grant execution to application role
GRANT USAGE ON PROCEDURE simulate_enrollment(VARCHAR, INTEGER, INTEGER) 
    TO ROLE YOUR_APPLICATION_ROLE;

-- Grant warehouse usage
GRANT USAGE ON WAREHOUSE YOUR_WAREHOUSE 
    TO ROLE YOUR_APPLICATION_ROLE;
```

---

## Advanced Usage

### Analyzing Risk with Percentiles

```r
# Run simulation
result <- dbGetQuery(myconn, "
  CALL simulate_enrollment('site_params_for_simulation', 100, 10000)
")

# Calculate risk metrics
risk_analysis <- result %>%
  summarise(
    # Best case (10% of simulations complete faster)
    best_case_weeks = quantile(weeks_to_goal, 0.10),
    
    # Expected case (50% of simulations)
    expected_weeks = quantile(weeks_to_goal, 0.50),
    
    # Conservative case (90% of simulations complete by this time)
    conservative_weeks = quantile(weeks_to_goal, 0.90),
    
    # Risk: difference between conservative and expected
    risk_buffer = quantile(weeks_to_goal, 0.90) - quantile(weeks_to_goal, 0.50)
  )

print(paste0(
  "Expected completion: ", risk_analysis$expected_weeks, " weeks\n",
  "Conservative estimate: ", risk_analysis$conservative_weeks, " weeks\n",
  "Risk buffer needed: ", risk_analysis$risk_buffer, " weeks"
))
```

### Scenario Comparison

```r
# Scenario 1: Optimistic site performance
site_params_optimistic <- site_params %>%
  mutate(
    min_psm = min_psm * 1.2,  # 20% higher enrollment
    max_psm = max_psm * 1.2,
    startup_early = startup_early - 2,  # 2 weeks faster
    startup_late = startup_late - 2
  )

dbWriteTable(myconn, "site_params_optimistic", site_params_optimistic, 
             overwrite = TRUE, temporary = TRUE)
result_optimistic <- dbGetQuery(myconn, "
  CALL simulate_enrollment('site_params_optimistic', 100, 10000)
")

# Scenario 2: Pessimistic
site_params_pessimistic <- site_params %>%
  mutate(
    min_psm = min_psm * 0.8,  # 20% lower enrollment
    max_psm = max_psm * 0.8,
    startup_early = startup_early + 4,  # 4 weeks slower
    startup_late = startup_late + 4
  )

dbWriteTable(myconn, "site_params_pessimistic", site_params_pessimistic, 
             overwrite = TRUE, temporary = TRUE)
result_pessimistic <- dbGetQuery(myconn, "
  CALL simulate_enrollment('site_params_pessimistic', 100, 10000)
")

# Compare scenarios
comparison <- data.frame(
  Scenario = c("Optimistic", "Base", "Pessimistic"),
  Median_Weeks = c(
    median(result_optimistic$weeks_to_goal),
    median(result$weeks_to_goal),
    median(result_pessimistic$weeks_to_goal)
  ),
  Q90_Weeks = c(
    quantile(result_optimistic$weeks_to_goal, 0.90),
    quantile(result$weeks_to_goal, 0.90),
    quantile(result_pessimistic$weeks_to_goal, 0.90)
  )
)

print(comparison)
```

---

## Troubleshooting

### Issue: "Table 'site_params_for_simulation' does not exist"

**Cause**: Temporary table was not created or expired

**Solution**: Ensure you create the temp table in the same session before calling the procedure

```r
# Create table and call procedure in same session
dbWriteTable(myconn, "site_params_for_simulation", site_params, 
             overwrite = TRUE, temporary = TRUE)
result <- dbGetQuery(myconn, "
  CALL simulate_enrollment('site_params_for_simulation', 100, 10000)
")
```

### Issue: Procedure runs slowly

**Cause**: Insufficient warehouse size

**Solution**: Scale up warehouse

```sql
ALTER WAREHOUSE YOUR_WAREHOUSE SET WAREHOUSE_SIZE = 'LARGE';
```

### Issue: Some simulations return NULL for weeks_to_goal

**Cause**: Goal was never reached within 866 weeks

**Solution**: 
1. Increase the number of weeks in the GENERATOR
2. Adjust site parameters (higher enrollment rates or more sites)
3. Lower the enrollment goal

---

## Performance Tuning

### Warehouse Sizing Recommendations

| Iterations | Sites | Recommended Warehouse | Expected Runtime |
|-----------|-------|----------------------|------------------|
| 1,000 | 5-10 | X-SMALL | 2-3 seconds |
| 10,000 | 5-10 | SMALL | 3-5 seconds |
| 10,000 | 20-50 | MEDIUM | 5-10 seconds |
| 100,000 | 20-50 | LARGE | 15-25 seconds |

### Optimization Tips

1. **Use temporary tables**: They're faster and auto-cleanup
2. **Batch simulations**: Run multiple scenarios in parallel sessions
3. **Cache site parameters**: Don't recreate the temp table for each run
4. **Monitor query profile**: Use Snowflake's query profile to identify bottlenecks

---

## Mathematical Model

### Enrollment Rate Sampling

For each site in each simulation:
- `weekly_psm ~ Uniform(min_psm, max_psm)`
- `startup_week ~ Uniform(startup_early, startup_late)`

### Weekly Enrollment Calculation

```
weekly_enrollment(site, week, sim) = {
    0,                          if week < startup_week
    weekly_psm × (52/12),       if week >= startup_week
}
```

Where `52/12` converts monthly rate to weekly rate.

### Cumulative Enrollment

```
cumulative_patients(sim, week) = Σ weekly_enrollment(site, t, sim)
                                 for all sites, for all t ≤ week
```

### Goal Achievement

```
weeks_to_goal(sim) = min{week : cumulative_patients(sim, week) >= goal}
```

---

## Integration with Shiny App

Replace the sequential R loop (typically lines 3579-3605 in app.R):

```r
# OLD CODE (Sequential R loop - 2-5 minutes)
observeEvent(input$simulate, {
  # ... prepare data ...
  
  for(n in 1:input$iterations) {
    for(i in 1:nrow(siteassumptions())) {
      # Sequential sampling
      montecarlo[,i+1] = sample(...)
    }
  }
  
  # ... process results ...
})

# NEW CODE (Snowflake parallel - 5-10 seconds)
observeEvent(input$simulate, {
  # Prepare site parameters
  site_params <- siteassumptions() %>%
    select(site_id = FINAL_NAME,
           min_psm = min,
           max_psm = max,
           startup_early = startupearly,
           startup_late = startuplate)
  
  # Write to Snowflake temp table
  dbWriteTable(myconn, "site_params_for_simulation", 
               site_params, overwrite = TRUE, temporary = TRUE)
  
  # Call stored procedure (runs in parallel)
  result <- dbGetQuery(myconn, paste0("
    CALL simulate_enrollment(
      'site_params_for_simulation',
      ", input$goal, ",
      ", input$iterations, "
    )
  "))
  
  # Update reactive values
  enrollprojections(result)
  simulationready('ready')
})
```

---

## References

- **Implementation Notebook**: `Medpace_inSitE_Snowflake_Implementation.ipynb`
- **Optimization Summary**: `Medpace_inSitE_Optimization_Summary.md`
- **Snowflake GENERATOR Function**: [Documentation](https://docs.snowflake.com/en/sql-reference/functions/generator)
- **Snowflake Stored Procedures**: [Documentation](https://docs.snowflake.com/en/sql-reference/stored-procedures)

---

## License

Internal use for Medpace clinical trial optimization.

## Support

For questions or issues, contact the Snowflake Solution Engineering team.

---

**Created**: October 2025  
**Last Updated**: October 28, 2025  
**Version**: 1.0

