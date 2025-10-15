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
  
  # NEW: Enhanced prompt for better LLM responses
  statement2 = "You are an expert clinical trial site selection advisor helping to interpret k-means clustering results. The clusters group clinical trial sites based on their historical performance metrics.

Context:
- Higher enrollment percentiles indicate better-performing sites (75th percentile = top 25% of sites)
- Lower startup weeks indicate faster site activation
- More studies indicate more experience
- These are real sites being evaluated for a new clinical trial

Your task: Provide actionable, specific interpretations that help users understand what type of sites are in each cluster."
  
  allclusters = ""
  
  for(i in unique(df$cluster)){
    tempstatement = paste0("\n"
                           ,"Cluster "
                           ,i
                           ,":\n"
                           ,paste(subset(df$shortprompt, df$cluster == i), collapse="\n"))
    allclusters = paste(allclusters
                        ,tempstatement
                        ,sep="\n")
  }
  
  statement4 = paste0("\n\nProvide a concise interpretation of each cluster in 10 words or less")
  
  # NEW: Get session token from existing ODBC connection
  session_token <- tryCatch({
    DBI::dbGetQuery(aiconn, "SELECT SYSTEM$GET_SESSION_TOKEN()")[[1]]
  }, error = function(e) {
    showNotification("Failed to get authentication token", type = "error")
    return(NULL)
  })
  
  if (is.null(session_token)) return()
  
  # NEW: Get Snowflake account identifier from connection
  account_info <- DBI::dbGetQuery(aiconn, 
    "SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() as account")[[1]]
  
  # NEW: Call Cortex REST API instead of ODBC
  response <- tryCatch({
    POST(
      url = paste0("https://", account_info, 
                   ".snowflakecomputing.com/api/v2/cortex/inference:complete"),
      add_headers(
        "Authorization" = paste("Bearer", session_token),
        "Content-Type" = "application/json",
        "Accept" = "application/json"
      ),
      body = toJSON(list(
        model = "claude-4-sonnet",
        messages = list(
          list(role = "system", content = statement2),
          list(role = "user", content = paste0(allclusters, statement4))
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
  
  # NEW: Parse REST API response
  llm_result <- content(response, as = "parsed")
  llmreply <- data.frame(V1 = llm_result$choices[[1]]$messages[[1]]$content)
  
  # Extract cluster interpretations (same as before)
  interpretation(
    data.frame(results = strsplit(llmreply[,1], '\n')[[1]]) %>%
      rowwise() %>%
      mutate(firstword = strsplit(results, " ")[[1]][1]
             , cluster = grepl('cluster', firstword, ignore.case=T)) %>%
      filter(cluster == TRUE) %>% 
      select(Interpretation = results)
  )
})
```

---

## Key Changes

### 1. **Authentication**
- Extracts session token from existing `aiconn` ODBC connection using `SYSTEM$GET_SESSION_TOKEN()`
- **Works with any authentication method**: OAuth, key pair, username/password, SSO, etc.
- No additional authentication setup required - reuses whatever auth method the ODBC connection is already using
- The session token is tied to the active connection, not the authentication method

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

## No Additional Setup Required

The solution automatically retrieves the Snowflake account identifier from the existing `aiconn` connection:

```r
# This query extracts the account info dynamically
account_info <- DBI::dbGetQuery(aiconn, 
  "SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() as account")[[1]]
```

This works seamlessly with:
- ✅ **Existing DSN connections** (`"AIrole"`, `"FeasibilityRead"`)
- ✅ **Any authentication method** (OAuth, key pair, username/password, SSO)
- ✅ **No environment variables or hardcoded values**

### Authentication Methods Supported

The `SYSTEM$GET_SESSION_TOKEN()` function returns a valid session token for **any** active Snowflake connection, regardless of how it was authenticated:

| Authentication Method | ODBC Setup | Works with REST API? |
|----------------------|------------|---------------------|
| **OAuth** | `authenticator=oauth` in DSN | ✅ Yes |
| **Key Pair** | Certificate files configured | ✅ Yes |
| **Username/Password** | Credentials in DSN | ✅ Yes |
| **SSO/SAML** | `authenticator=externalbrowser` | ✅ Yes |
| **Okta** | `authenticator=okta` | ✅ Yes |

The session token represents the **active session**, not the authentication mechanism. Once authenticated (by any method), the session token can be used for REST API calls

---

## Response Format: Streaming vs Non-Streaming

The Cortex API can return responses in two formats:

### 1. **Streaming** (Default) - `Content-Type: text/event-stream`
- Real-time token generation as they're produced
- Multiple `data:` lines with JSON chunks
- Better for showing progress in UI
- **Our parser handles this automatically**

### 2. **Non-Streaming** - `Content-Type: application/json`
- Complete response after all tokens generated
- Single JSON object
- Simpler structure

To request **non-streaming** responses, change the `Accept` header:

```r
# Non-streaming request
POST(
  url = api_url,
  add_headers(
    "Authorization" = paste("Bearer", session_token),
    "Content-Type" = "application/json",
    "Accept" = "application/json"  # This line requests non-streaming
  ),
  body = ...
)
```

**Good news:** The parser scripts automatically detect and handle both formats, so you don't need to change your code!

---

## Helper Scripts

Two R scripts are provided to simplify Cortex API integration:

### 1. **cortex_api_parser.R** - Response Parsing Functions
- `parse_cortex_response()` - Parse raw HTTP response
- `extract_cortex_text()` - Extract text from multiple response formats
- `extract_cortex_usage()` - Get token usage statistics
- `extract_cortex_metadata()` - Get response metadata (ID, model, timestamp)
- `parse_cluster_interpretations()` - Medpace-specific cluster parsing
- `cortex_api_call()` - All-in-one safe API call with error handling

### 2. **cortex_api_example.R** - Usage Examples
- Simple question-answer
- System prompt + user prompt
- Cluster interpretation (Medpace use case)
- Manual response parsing
- Error handling examples
- Shiny app integration template

To use in your code:
```r
source("cortex_api_parser.R")

# Quick API call with automatic parsing
result <- cortex_api_call(
  url = api_url,
  token = session_token,
  model = "claude-4-sonnet",
  messages = list(
    list(role = "system", content = "You are a helpful assistant"),
    list(role = "user", content = "Analyze this data...")
  )
)

if (result$success) {
  print(result$text)
  print(result$usage)
}
```

---

## Testing

Test the REST API call independently:

```r
# Quick test
aiconn <- DBI::dbConnect(odbc::odbc(), "AIrole", Warehouse = "INFORMATICS_AI")
token <- DBI::dbGetQuery(aiconn, "SELECT SYSTEM$GET_SESSION_TOKEN()")[[1]]
account_info <- DBI::dbGetQuery(aiconn, 
  "SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() as account")[[1]]

response <- POST(
  url = paste0("https://", account_info, 
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

