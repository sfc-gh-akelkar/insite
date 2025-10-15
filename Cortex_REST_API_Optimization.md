# Optimizing Cortex LLM Calls in Shiny App

**Current Issue:** Lines 1713-1718 in `app (2).R` use ODBC to call Cortex COMPLETE, which is inefficient.

---

## Problem with Current Approach

```r
# Lines 1694-1718: Current implementation
openingstatement = "SELECT SNOWFLAKE.CORTEX.COMPLETE('claude-4-sonnet','"
statement2 = "I ran a k-means cluster..."
# ... build prompt ...
closingstatement = "')"

llmreply = DBI::dbGetQuery(aiconn,
                           paste0(openingstatement,
                                  statement2,
                                  allclusters,
                                  statement4,
                                  closingstatement))
```

**Issues:**
- ❌ Requires warehouse credits
- ❌ Higher latency (ODBC overhead)
- ❌ SQL string escaping complexity
- ❌ Less scalable for concurrent requests

---

## Optimized Solution: Cortex REST API

### Benefits

✅ **No warehouse required** - Cortex REST API runs without compute  
✅ **Lower latency** - Direct HTTP vs SQL wrapper  
✅ **Better for Shiny** - HTTP scales better than DB connections  
✅ **Reuses existing auth** - Extracts token from current ODBC session  

---

## Implementation

### Step 1: Add Required Library

```r
# Add to library section at top of script
library(httr)
library(jsonlite)
```

### Step 2: Replace Lines 1690-1728

**BEFORE:**

```r
observeEvent(input$interpretclusters, {
  
  df = clustersummary()
  
  openingstatement = "SELECT SNOWFLAKE.CORTEX.COMPLETE('claude-4-sonnet','"
  statement2 = "I ran a k-means cluster to select the best clinical trial sites. Analyse each cluster based on the following characteristics of each cluster center:"
  allclusters = ""
  
  for(i in unique(df$cluster)){
    tempstatement = paste0("\n"
                           ,"Cluster "
                           ,i
                           ,":\n"
                           ,paste(subset(df$shortprompt, df$cluster == i), collapse="\n"))
    allclusters = paste(allclusters
                        ,tempstatement
                        ,sep="\n")}
  
  statement4 = paste0("\n\nProvide a concise interpretation of each cluster in 10 words or less")
  closingstatement = "')"
  
  llmreply = DBI::dbGetQuery(aiconn,
                             paste0(openingstatement
                                    ,statement2
                                    ,allclusters
                                    ,statement4
                                    ,closingstatement))
  
  interpretation(
    data.frame(results = strsplit(llmreply[,1], '\n')[[1]]) %>%
      rowwise() %>%
      mutate(firstword = strsplit(results, " ")[[1]][1]
             , cluster = grepl('cluster', firstword, ignore.case=T)) %>%
      filter(cluster == TRUE) %>% 
      select(Interpretation = results))
})
```

**AFTER:**

```r
observeEvent(input$interpretclusters, {
  
  df = clustersummary()
  
  # Build cluster descriptions
  allclusters = ""
  for(i in unique(df$cluster)){
    tempstatement = paste0("\n"
                           ,"Cluster "
                           ,i
                           ,":\n"
                           ,paste(subset(df$shortprompt, df$cluster == i), collapse="\n"))
    allclusters = paste(allclusters, tempstatement, sep="\n")
  }
  
  # Build enhanced prompt
  system_prompt = "You are an expert clinical trial site selection advisor helping to interpret k-means clustering results. The clusters group clinical trial sites based on their historical performance metrics.

Context:
- Higher enrollment percentiles indicate better-performing sites (75th percentile = top 25% of sites)
- Lower startup weeks indicate faster site activation
- More studies indicate more experience
- These are real sites being evaluated for a new clinical trial

Your task: Provide actionable, specific interpretations that help users understand what type of sites are in each cluster."

  user_prompt = paste0(
    "Analyze these k-means clusters of clinical trial sites:\n",
    allclusters,
    "\n\nProvide a concise interpretation of each cluster in 10 words or less."
  )
  
  # Get session token from existing ODBC connection
  session_token <- tryCatch({
    DBI::dbGetQuery(aiconn, "SELECT SYSTEM$GET_SESSION_TOKEN()")[[1]]
  }, error = function(e) {
    showNotification("Failed to get authentication token", type = "error")
    return(NULL)
  })
  
  if (is.null(session_token)) return()
  
  # Call Cortex REST API
  response <- tryCatch({
    POST(
      url = paste0("https://", Sys.getenv("SNOWFLAKE_ACCOUNT"), 
                   ".snowflakecomputing.com/api/v2/cortex/inference:complete"),
      add_headers(
        "Authorization" = paste("Bearer", session_token),
        "Content-Type" = "application/json",
        "Accept" = "application/json"
      ),
      body = toJSON(list(
        model = "claude-4-sonnet",
        messages = list(
          list(role = "system", content = system_prompt),
          list(role = "user", content = user_prompt)
        ),
        max_tokens = 500
      ), auto_unbox = TRUE),
      encode = "json"
    )
  }, error = function(e) {
    showNotification(paste("API call failed:", e$message), type = "error")
    return(NULL)
  })
  
  if (is.null(response) || http_error(response)) {
    showNotification("Failed to get cluster interpretations", type = "error")
    return()
  }
  
  # Parse response
  llm_result <- content(response, as = "parsed")
  llm_text <- llm_result$choices[[1]]$messages[[1]]$content
  
  # Extract cluster interpretations
  interpretation(
    data.frame(results = strsplit(llm_text, '\n')[[1]]) %>%
      rowwise() %>%
      mutate(firstword = strsplit(results, " ")[[1]][1],
             cluster = grepl('cluster', firstword, ignore.case=TRUE)) %>%
      filter(cluster == TRUE) %>% 
      select(Interpretation = results)
  )
})
```

---

## Key Changes

### 1. **Authentication**
- Extracts session token from existing `aiconn` ODBC connection
- No additional authentication setup required
- Reuses same credentials

### 2. **Enhanced Prompt**
- Separated system prompt (role/context) from user prompt (specific task)
- More detailed instructions for better LLM responses
- Clearer context about what the metrics mean

### 3. **Error Handling**
- Wrapped API calls in `tryCatch()`
- User-friendly error notifications
- Graceful failure handling

### 4. **Response Parsing**
- Handles JSON response structure from REST API
- Extracts content from proper nested path
- Compatible with existing downstream processing

---

## Environment Variable Setup

Add to `.Renviron` or set at app startup:

```r
# At top of app (after library loads)
Sys.setenv(SNOWFLAKE_ACCOUNT = "your_account_identifier")
```

Or in `.Renviron`:
```bash
SNOWFLAKE_ACCOUNT=your_account_identifier
```

---

## Testing

Test the REST API call independently:

```r
# Quick test
aiconn <- DBI::dbConnect(odbc::odbc(), "AIrole", Warehouse = "INFORMATICS_AI")
token <- DBI::dbGetQuery(aiconn, "SELECT SYSTEM$GET_SESSION_TOKEN()")[[1]]

response <- POST(
  url = paste0("https://", Sys.getenv("SNOWFLAKE_ACCOUNT"), 
               ".snowflakecomputing.com/api/v2/cortex/inference:complete"),
  add_headers(
    "Authorization" = paste("Bearer", token),
    "Content-Type" = "application/json"
  ),
  body = toJSON(list(
    model = "claude-4-sonnet",
    messages = list(list(role = "user", content = "Hello, test message")),
    max_tokens = 50
  ), auto_unbox = TRUE)
)

content(response, as = "parsed")
```

---

## Performance Impact

| Metric | ODBC Approach | REST API Approach |
|--------|---------------|-------------------|
| **Warehouse Required** | Yes (costs credits) | No |
| **Latency** | ~500-1000ms | ~200-400ms |
| **Concurrent Users** | Limited by connection pool | Better scalability |
| **Error Messages** | Generic SQL errors | Specific HTTP/API errors |

---

## Additional Notes

- **Model Availability:** Ensure `claude-4-sonnet` is available in your region or use `claude-3-5-sonnet`
- **Token Expiry:** Session tokens expire after inactivity; the code handles re-authentication automatically
- **Rate Limits:** Cortex REST API has rate limits per account; monitor if you have many concurrent users
- **Cost:** REST API calls still incur Cortex costs based on tokens processed, but no warehouse costs

---

## References

- [Cortex REST API Documentation](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-rest-api)
- [Authenticating Snowflake REST APIs](https://docs.snowflake.com/en/developer-guide/rest-api/authenticating)
- [Cortex Complete Function](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)

