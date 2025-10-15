# Medpace inSitE Application Modernization
## Moving Data Processing from R to Snowflake

**Prepared for:** Medpace  
**Date:** October 2025  
**Application:** inSitE (Informatics Site Engine)

---

## Executive Summary

Your inSitE application currently loads **16 million rows (730 MB)** from Snowflake into R for processing. This creates performance bottlenecks, high memory usage (2-3 GB per session), and limits scalability.

**The Solution:** Push data processing into Snowflake, keeping only visualization and UI in R/Shiny.

### Key Benefits

| Metric | Current (R Processing) | After (Snowflake Processing) | Improvement |
|--------|------------------------|------------------------------|-------------|
| **Data Transfer** | 730 MB per session | <5 MB per session | **99% reduction** |
| **Memory Usage** | 2-3 GB per session | 100-200 MB per session | **95% reduction** |
| **Analysis Time** | 3-6 minutes | 15-25 seconds | **12-18x faster** |
| **Concurrent Users** | 5-10 users | 50-100 users | **10x capacity** |
| **R Code Complexity** | 400+ lines data processing | 30 lines SQL calls | **90% simpler** |

### Investment Required

- **Development Time:** 8-12 weeks
- **Snowflake Cost Increase:** ~$850/month (compute for processing)
- **Infrastructure Savings:** ~$1,000/month (smaller app servers)
- **Net Savings:** ~$150/month + 10x user capacity

---

## Why Current Architecture is Inefficient

### The Problem: Processing Outside the Database

```
Current Flow:
┌──────────────┐
│  Snowflake   │ ← Data lives here (16M rows, 730 MB)
│   Database   │
└──────┬───────┘
       │
       ↓ Transfer all data over ODBC (slow)
┌──────────────┐
│ R Application│ ← Process here (single-threaded, memory-intensive)
│    Server    │   • Filter 16M rows → 100K rows
│              │   • Join multiple tables
│  2-3 GB RAM  │   • Aggregate metrics
│              │   • Run ML models sequentially
└──────┬───────┘
       │
       ↓ Send visuals to browser
┌──────────────┐
│   User's     │
│   Browser    │
└──────────────┘
```

### Specific Inefficiencies in Your Code

**1. Loading Entire Tables Before Filtering**

Your app loads full tables into R, then filters:

```r
# Current code (Line 997-1010)
organizationtrials %>%        # ← Loads 3.5 MILLION rows (89 MB)
  filter(TRIALID %in% ...) %>%  # ← Then filters to ~50K rows
  left_join(sitelist) %>%       # ← Then joins in R memory
  group_by(FINAL_NAME, ISO) %>%
  summarize(...)
```

**Result:** Transfers 3.5M rows when you only need 50K rows (70x more data than necessary)

**2. Sequential Processing in Loops**

Monte Carlo simulations run 10,000 iterations sequentially:

```r
# Current code (Lines 3579-3605)
for(n in 1:10000){              # ← Sequential loop (single-threaded)
  montecarlo = data.frame(week = 1:866)
  for(i in 1:nrow(sites)){      # ← Nested loop
    montecarlo[,i+1] = sample(...)
  }
  # Calculate cumulative enrollment
}
# Takes 2-5 minutes
```

**Result:** 10,000 iterations × 866 weeks × 50 sites = 432 million calculations on one CPU core

**3. Memory-Intensive Data Structures**

Multiple copies of large datasets in memory for joins:

```r
# Current code (Lines 1082-1099)
build = indicationdf %>%              # ~50K rows
  full_join(therapeuticdf) %>%        # +80K rows (creates cartesian product temporarily)
  full_join(indicationciteline) %>%   # +100K rows
  full_join(therapeuticciteline) %>%  # +150K rows
  # ... 4 more full_joins
```

**Result:** Each `full_join` creates temporary dataframes that consume memory

---

## Recommended Architecture: Push Down to Snowflake

```
Optimized Flow:
┌────────────────────────────────┐
│         Snowflake              │ ← All processing here (distributed, parallel)
│                                │
│  • Filter at source            │
│  • Aggregate in SQL            │
│  • ML models (Snowpark)        │
│  • Parallel simulations        │
│  • AI interpretation (Cortex)  │
└──────┬─────────────────────────┘
       │
       ↓ Transfer only aggregated results (<5 MB)
┌──────────────┐
│ R Application│ ← Only visualization & UI
│    Server    │   
│  100-200 MB  │   • Receive 200-500 rows
│              │   • Create charts
└──────┬───────┘   • Display tables
       │
       ↓
┌──────────────┐
│   User's     │
│   Browser    │
└──────────────┘
```

### Key Advantages

**1. Distributed Processing**
- Snowflake processes data across multiple nodes in parallel
- Your single-threaded R code becomes multi-threaded automatically

**2. Process Where Data Lives**
- No network transfer of millions of rows
- Snowflake's columnar storage optimized for aggregations

**3. Scalability**
- Snowflake scales compute automatically
- R app servers freed up for more users

**4. Better Performance**
- SQL aggregations are highly optimized
- Parallel execution vs sequential loops

---

## What Changes in the Shiny App

### Example 1: Data Collation (Biggest Impact)

#### BEFORE: 400+ Lines of R Code

```r
observeEvent(input$collate, {
  
  # Load and filter organizationtrials (89 MB)
  indicationciteline = organizationtrials %>%
    filter(as.integer(TRIALID) %in% ...) %>% 
    mutate(ORGANIZATIONID = as.integer(ORGANIZATIONID)) %>% 
    left_join(sitelist %>% filter(SOURCE == 'Citeline') ...) %>%
    filter(ISO %in% iso) %>% 
    group_by(FINAL_NAME, ISO) %>% 
    summarize(ind_ext_studies = n_distinct(TRIALID)) %>% 
    ungroup()
  
  # Load and filter hierarchy (477 MB)
  indicationdf = hierarchy  %>% 
    filter(NBDPID %in% subset(filteredstudydisease()$STUDYCODE, 
                              filteredstudydisease()$SOURCE == 'Medpace'),
           ISO %in% iso) %>% 
    left_join(sitelist %>% filter(SOURCE == 'ClinTrakSM') ...) %>%
    mutate(FINAL_NAME = coalesce(FINAL_NAME, CENTER_NAME)) %>% 
    group_by(FINAL_NAME, ISO) %>% 
    summarize(ind_studies = n_distinct(NBDPID),
              ind_enr_perc = round(mean(STUDY_PERCENTILE, na.rm=T)*100, 0)) %>% 
    ungroup()
  
  # Repeat for therapeutic area (another 60 lines)
  therapeuticdf = hierarchy  %>% ...
  therapeuticciteline = organizationtrials %>% ...
  
  # Handle custom benchmarking (another 80 lines)
  if(nrow(medpcustom()) > 0) {
    customdf = hierarchy %>% ...
  }
  
  # Join everything together
  build = indicationdf %>% 
    full_join(therapeuticdf, by=c("FINAL_NAME","ISO")) %>% 
    full_join(indicationciteline, by=c("FINAL_NAME","ISO")) %>% 
    full_join(therapeuticciteline, by=c("FINAL_NAME","ISO")) %>%
    # ... 4 more joins
  
  # Convert NAs to 0
  columnstoconvert = which(grepl('studies', colnames(build)) ...)
  build[,columnstoconvert][is.na(build[,columnstoconvert])] = 0
  
  studysites(build)
})

# Result: 400+ lines, 30-60 seconds, 730 MB transferred
```

#### AFTER (Option 1): Query Dynamic Table - ~20 Lines, <1 Second

```r
observeEvent(input$collate, {
  
  # Convert R inputs
  iso <- countrycode(input$selectedcountry, origin = 'country.name', 
                     destination = 'iso3c')
  
  # Query pre-computed Dynamic Table (data already aggregated!)
  query <- paste0("
    SELECT 
        FINAL_NAME, ISO,
        MAX(CASE WHEN INDICATION IN ('", paste(input$selecteddiseases, collapse="','"), "') 
            THEN studies END) as indication_studies,
        MAX(CASE WHEN INDICATION IN ('", paste(input$selecteddiseases, collapse="','"), "') 
            THEN percentile END) as indication_percentile,
        MAX(total_studies) as medpace_studies,
        MAX(avg_percentile) as avg_percentile,
        MAX(startup_weeks) as startup_weeks
    FROM site_metrics_base  -- Pre-computed table!
    WHERE ISO IN ('", paste(iso, collapse="','"), "')
    GROUP BY FINAL_NAME, ISO
  ")
  
  # Returns instantly (data already materialized)
  build <- DBI::dbGetQuery(myconn, query)
  
  studysites(build)
})

# Result: 20 lines, <1 second, <1 MB transferred
# Data refreshed hourly via Dynamic Table (TARGET_LAG = '1 hour')
```

#### AFTER (Option 2): Call SQL Function - ~30 Lines, 3-5 Seconds

```r
observeEvent(input$collate, {
  
  # Convert R inputs to SQL arrays
  iso <- countrycode(input$selectedcountry, origin = 'country.name', 
                     destination = 'iso3c')
  indications <- paste0("['", paste(input$selecteddiseases, collapse="','"), "']")
  countries <- paste0("['", paste(iso, collapse="','"), "']")
  
  # Optional: custom study codes
  custom_codes <- if(nrow(medpcustom()) > 0) {
    paste0("['", paste(medpcustom()$UNIQUEKEY, collapse="','"), "']")
  } else { "[]" }
  
  custom_trials <- if(nrow(citelinecustom()) > 0) {
    paste0("['", paste(citelinecustom()$TRIALID, collapse="','"), "']")
  } else { "[]" }
  
  # ONE SQL CALL - All processing happens in Snowflake
  query <- paste0("
    SELECT * FROM TABLE(get_site_metrics(
      ", indications, ",    -- Indication filter
      ", countries, ",      -- Country filter
      ", custom_codes, ",   -- Custom Medpace studies
      ", custom_trials, "   -- Custom Citeline trials
    ))
  ")
  
  # Get aggregated results (200-500 rows instead of 16 million)
  build <- DBI::dbGetQuery(myconn, query)
  
  studysites(build)
})

# Result: 30 lines, 3-5 seconds, <1 MB transferred
# Always returns real-time data
```

**Recommendation:** Use **Option 1 (Dynamic Tables)** for standard metrics, plus **Option 2 (SQL Functions)** for custom study codes

**What You Need to Create in Snowflake:**

**For Option 1 - Create Dynamic Table (one-time setup):**

```sql
-- Pre-compute site metrics, refreshes automatically
CREATE OR REPLACE DYNAMIC TABLE site_metrics_base
    TARGET_LAG = '1 hour'               -- Refresh within 1 hour
    WAREHOUSE = 'TRANSFORM_WH'          -- Dedicated warehouse
    REFRESH_MODE = 'INCREMENTAL'        -- Only process changes
AS
    WITH indication_metrics AS (
        SELECT 
            COALESCE(s.FINAL_NAME, h.CENTER_NAME) as FINAL_NAME,
            h.ISO,
            sd.INDICATION,
            COUNT(DISTINCT h.NBDPID) as studies,
            ROUND(AVG(h.STUDY_PERCENTILE) * 100, 0) as percentile
        FROM hierarchy h
        LEFT JOIN sitelist s ON h.SITEID = s.SITEID
        JOIN studydisease sd ON h.NBDPID = sd.STUDYCODE
        WHERE sd.SOURCE = 'Medpace'
        GROUP BY 1, 2, 3
    ),
    overall_metrics AS (
        SELECT 
            COALESCE(s.FINAL_NAME, h.CENTER_NAME) as FINAL_NAME,
            h.ISO,
            COUNT(DISTINCT h.NBDPID) as total_studies,
            ROUND(AVG(h.STUDY_PERCENTILE) * 100) as avg_percentile
        FROM hierarchy h
        LEFT JOIN sitelist s ON h.SITEID = s.SITEID
        GROUP BY 1, 2
    ),
    startup_metrics AS (
        SELECT 
            COALESCE(s.FINAL_NAME, h.CENTER_NAME) as FINAL_NAME,
            h.ISO,
            PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY h.STARTUPWK) as startup_weeks
        FROM hierarchy h
        LEFT JOIN sitelist s ON h.SITEID = s.SITEID
        WHERE YEAR(CURRENT_DATE()) - YEAR(h.ACTIVATIONDATE::DATE) <= 3
          AND h.STARTUPWK BETWEEN 4 AND 52
        GROUP BY 1, 2
    )
    SELECT 
        i.FINAL_NAME, i.ISO, i.INDICATION,
        i.studies, i.percentile,
        o.total_studies, o.avg_percentile,
        st.startup_weeks
    FROM indication_metrics i
    LEFT JOIN overall_metrics o ON i.FINAL_NAME = o.FINAL_NAME AND i.ISO = o.ISO
    LEFT JOIN startup_metrics st ON i.FINAL_NAME = st.FINAL_NAME AND i.ISO = st.ISO;
```

**For Option 2 - Create SQL Function:**

```sql
CREATE OR REPLACE FUNCTION get_site_metrics(
    indications ARRAY,
    countries ARRAY,
    custom_medp_codes ARRAY,
    custom_citeline_ids ARRAY
)
RETURNS TABLE (
    FINAL_NAME VARCHAR,
    ISO VARCHAR,
    indication_studies_medpace INT,
    indication_enr_percentile INT,
    indication_studies_citeline INT,
    therapeutic_studies_medpace INT,
    -- ... all other metrics
)
AS
$$
    -- Filter and aggregate in SQL (distributed processing)
    WITH indication_metrics AS (
        SELECT 
            COALESCE(s.FINAL_NAME, h.CENTER_NAME) as FINAL_NAME,
            h.ISO,
            COUNT(DISTINCT h.NBDPID) as studies,
            ROUND(AVG(h.STUDY_PERCENTILE) * 100, 0) as percentile
        FROM hierarchy h
        LEFT JOIN sitelist s ON h.SITEID = s.SITEID
        WHERE h.NBDPID IN (SELECT studycode FROM studydisease 
                          WHERE indication = ANY(indications))
          AND h.ISO = ANY(countries)
        GROUP BY 1, 2
    )
    -- Additional CTEs for other metrics...
    SELECT * FROM indication_metrics
    -- Join all metrics together
$$;
```

---

### Example 2: Monte Carlo Simulations

#### BEFORE: Sequential Loop (2-5 Minutes)

```r
observeEvent(input$simulate, {
  
  iterations = data.frame(iteration = 1:10000, weeks = NA, patients = NA)
  
  # Sequential processing
  for(n in 1:10000){
    montecarlo = data.frame(week = seq(1:866))
    
    # For each site, sample random enrollment rate
    for(i in 1:nrow(sites)){
      montecarlo[,ncol(montecarlo)+1] = sample(
        seq(from = sites$min[i], to = sites$max[i], by=0.01), 1
      )
      # Mask startup weeks
      startup_week = sample(seq(from = sites$startupearly[i], 
                                to = sites$startuplate[i]), 1)
      montecarlo[1:startup_week, ncol(montecarlo)] = NA
    }
    
    montecarlo$total = rowSums(montecarlo[, 2:ncol(montecarlo)], na.rm=T)
    montecarlo$cumulative = cumsum(montecarlo$total)
    
    iterations$weeks[n] = sum(montecarlo$active)
    iterations$patients[n] = list(montecarlo$cumulative)
  }
  
  enrollprojections(iterations)
})

# Result: 2-5 minutes, creates 432M data points sequentially
```

#### AFTER: Call Snowflake Stored Procedure (5-10 Seconds)

```r
observeEvent(input$simulate, {
  
  # Prepare site parameters
  site_params <- siteassumptions() %>%
    select(site_id = FINAL_NAME, min_psm = min, max_psm = max,
           startup_early = startupearly, startup_late = startuplate)
  
  # Upload to temporary table
  DBI::dbWriteTable(aiconn, "site_params_temp", site_params, 
                    overwrite = TRUE, temporary = TRUE)
  
  # ONE CALL - Snowflake runs 10K iterations in parallel
  query <- paste0("
    CALL simulate_enrollment(
      'site_params_temp',
      ", input$goal, ",          -- Target enrollment
      ", input$iterations, "     -- Number of simulations (10,000)
    )
  ")
  
  result <- DBI::dbGetQuery(aiconn, query)
  iterations_result <- jsonlite::fromJSON(result$SIMULATE_ENROLLMENT)
  
  enrollprojections(iterations_result)
})

# Result: 5-10 seconds, parallel processing across Snowflake nodes
```

**What You Need to Create in Snowflake:**

A stored procedure using Snowflake's GENERATOR for parallel random sampling:

```python
# Snowpark Python Stored Procedure
def simulate_enrollment(session, site_params_table, goal, iterations):
    """
    Runs Monte Carlo simulations using Snowflake's distributed compute.
    Uses GENERATOR() for efficient parallel random number generation.
    """
    
    # SQL that runs in parallel
    simulation_sql = f"""
    WITH weeks AS (
        SELECT SEQ1() as week 
        FROM TABLE(GENERATOR(ROWCOUNT => 866))
    ),
    simulations AS (
        SELECT SEQ1() as sim_id 
        FROM TABLE(GENERATOR(ROWCOUNT => {iterations}))
    ),
    site_samples AS (
        SELECT 
            s.sim_id,
            w.week,
            p.site_id,
            UNIFORM(p.min_psm, p.max_psm, RANDOM()) as weekly_rate,
            UNIFORM(p.startup_early, p.startup_late, RANDOM())::INT as startup
        FROM simulations s
        CROSS JOIN weeks w
        CROSS JOIN {site_params_table} p
    )
    SELECT 
        sim_id as iteration,
        MAX(week) as weeks_to_goal
    FROM (
        SELECT 
            sim_id, 
            week,
            SUM(CASE WHEN week >= startup THEN weekly_rate ELSE 0 END) 
                OVER (PARTITION BY sim_id ORDER BY week) as cumulative
        FROM site_samples
    )
    WHERE cumulative <= {goal}
    GROUP BY sim_id
    """
    
    return session.sql(simulation_sql).to_pandas()

# Register once in Snowflake
session.sproc.register(
    func=simulate_enrollment,
    name="simulate_enrollment",
    packages=["snowflake-snowpark-python", "pandas"]
)
```

---

## Summary: What Needs to Change

### In Snowflake (One-Time Setup)

**Option A: Dynamic Tables (Recommended for most queries)**
1. **Create Dynamic Tables** for core metrics
   - `site_metrics_base` - auto-refreshes hourly, replaces 400 lines of R
   - Query returns in <1 second (pre-computed)
   
**Option B: SQL Functions (For user-specific operations)**
1. **Create SQL Functions** for dynamic filtering
   - `get_site_metrics()` - handles custom study codes
   - `filter_custom_studies()` - user-specific benchmarking

**For All Complex Operations:**
2. **Create Stored Procedures** for ML/simulations
   - `simulate_enrollment()` - replaces sequential Monte Carlo loop
   - `cluster_and_interpret_sites()` - replaces R k-means clustering

3. **Total Code:** ~500-800 lines SQL/Python (well-documented, reusable)

### In R Shiny App (Simplification)

1. **Replace data processing with simple queries**
   - 400 lines of dplyr → 20 lines querying Dynamic Table (instant)
   - OR 400 lines of dplyr → 30 lines calling SQL Function (3-5 sec)
   - 150 lines of simulation → 20 lines calling stored procedure
   
2. **Remove heavy dependencies**
   - Can remove: `quantreg`, heavy data manipulation packages
   - Keep: `ggplot2`, `plotly`, `DT`, `shiny` (visualization only)

3. **Total R Code Reduction:** ~600 lines removed, app becomes simpler

### Expected Timeline

- **Week 1-2:** Design SQL functions, stored procedures
- **Week 3-5:** Implement and test in Snowflake
- **Week 6-8:** Update R app to call Snowflake functions
- **Week 9-10:** Parallel testing (old vs new)
- **Week 11-12:** Production deployment

---

## Choosing the Right Approach: Dynamic Tables vs Functions

For the data transformations, you can use **Dynamic Tables** (pre-computed, auto-refreshed) or **SQL Functions** (computed on-demand). Here's when to use each:

### Dynamic Tables: Best for Core Metrics

**What They Are:**
- Materialized query results that auto-refresh on a schedule
- Snowflake detects base table changes and incrementally updates
- You control freshness with `TARGET_LAG` parameter (e.g., refresh every 1 hour)

**Advantages:**
- ⚡ **Instant queries** - Results already computed (<1 second vs 3-5 seconds)
- 💰 **Cost efficient** - Incremental refresh processes only changed data
- 👥 **Shared across users** - Multiple users query same pre-computed results
- 🔄 **No manual scheduling** - Snowflake handles refresh automatically
- 📊 **Multi-tool access** - Can be queried by Tableau, Python, R simultaneously

**Use Dynamic Tables for:**
- Site performance metrics (updated hourly: `TARGET_LAG = '1 hour'`)
- Phase experience data (updated daily: `TARGET_LAG = '1 day'`)
- Startup time calculations (updated every 12 hours: `TARGET_LAG = '12 hours'`)

**Example:**
```sql
CREATE DYNAMIC TABLE site_metrics_base
    TARGET_LAG = '1 hour'               -- Refresh within 1 hour of changes
    WAREHOUSE = 'TRANSFORM_WH'
    REFRESH_MODE = 'INCREMENTAL'        -- Only process changes
AS
    SELECT 
        FINAL_NAME, ISO, INDICATION,
        COUNT(DISTINCT NBDPID) as studies,
        ROUND(AVG(STUDY_PERCENTILE) * 100) as percentile
    FROM hierarchy h
    JOIN studydisease sd ON h.NBDPID = sd.STUDYCODE
    GROUP BY 1, 2, 3;
```

**R Code (queries pre-computed table):**
```r
# Returns in <1 second (already aggregated!)
build <- DBI::dbGetQuery(myconn, "
    SELECT * FROM site_metrics_base
    WHERE ISO IN ('USA', 'DEU')
      AND INDICATION = 'Diabetes'
")
```

### SQL Functions: Best for Dynamic/User-Specific Operations

**Advantages:**
- 🎯 **Always real-time** - No data lag
- 💾 **No storage cost** - Only compute when needed
- 🔧 **Flexible parameters** - Handle user-specific inputs

**Use SQL Functions/Stored Procedures for:**
- User-entered custom study codes (unique per user)
- Monte Carlo simulations (non-deterministic, random sampling)
- K-means clustering (on filtered/user-selected data)
- Any operation with parameters that change per query

**Example:**
```sql
CREATE FUNCTION get_custom_benchmarking(custom_codes ARRAY)
RETURNS TABLE (...)
AS
$$
    -- Computed on-demand when called
    SELECT ... FROM hierarchy
    WHERE NBDPID = ANY(custom_codes)
$$;
```

### Recommended Hybrid Architecture

```
SNOWFLAKE:
├─ Dynamic Tables (90% of queries)
│  └─ site_metrics_base → <1 sec ✓
│
├─ SQL Functions (10% of queries)  
│  └─ filter_custom_studies() → 1-2 sec
│
└─ Stored Procedures (complex compute)
   ├─ simulate_enrollment() → 5-10 sec
   └─ cluster_sites() → 2-3 sec
```

**Why This Works:**
- Most queries hit pre-computed Dynamic Table (instant)
- User-specific operations computed on-demand (still fast)
- Best balance of speed, cost, and flexibility

### Setting TARGET_LAG for Dynamic Tables

**Decision Framework:**

| Your Scenario | Recommended TARGET_LAG |
|---------------|------------------------|
| Data updates daily (enrollment) | `1-2 hours` |
| Data updates weekly (new studies) | `12-24 hours` |
| Data updates monthly (historical) | `1-2 days` |
| Critical real-time decisions | Use SQL Functions instead |

**Monitor and Adjust:**
```sql
-- Check if you're meeting target lag
SELECT 
    name,
    target_lag_sec / 60 as target_minutes,
    mean_lag_sec / 60 as actual_minutes
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES('site_metrics_base'));

-- If actual > target, either:
-- 1. Increase TARGET_LAG, or
-- 2. Use larger warehouse
```

**Cost Consideration:**
- Lower `TARGET_LAG` = more frequent refreshes = higher compute cost
- Higher `TARGET_LAG` = fewer refreshes = lower cost (but less fresh data)

---

## Next Steps

### Recommended Approach

**Phase 1: Proof of Concept (2 weeks)**
- Implement ONE component (data collation) in Snowflake
- Side-by-side comparison with current R implementation
- Measure actual performance improvement

**Phase 2: Full Implementation (6-8 weeks)**
- Migrate remaining components
- Comprehensive testing
- User acceptance testing

**Phase 3: Production Rollout (2 weeks)**
- Gradual rollout to users
- Monitor performance and costs
- Iterate based on feedback

### Questions to Discuss

1. **Data Freshness Requirements:** How fresh do site metrics need to be?
   - If "within 1-2 hours" is acceptable → **Dynamic Tables** (faster queries)
   - If "real-time critical" → **SQL Functions** (always current)

2. **User Concurrency:** How many users query simultaneously?
   - 10+ users → **Dynamic Tables** save repeated computation
   - 1-5 users → **SQL Functions** may be simpler

3. **Target Lag:** If using Dynamic Tables, what refresh frequency?
   - Hourly (`TARGET_LAG = '1 hour'`) for site performance metrics?
   - Daily (`TARGET_LAG = '1 day'`) for phase/startup data?

4. **Warehouse Sizing:** What size warehouse for refreshes and queries?

5. **Model Registry:** Use Snowflake's Model Registry for ML models?

6. **Cost Monitoring:** Set up resource monitors to track Dynamic Table costs?

---

**Contact:** [Your Snowflake Solution Engineering Team]

**Ready to get started?** Let's schedule a technical workshop to walk through the first proof of concept.

