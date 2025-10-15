################################################################################
## Cortex REST API - Complete Example
## 
## This script demonstrates how to use the cortex_api_parser.R functions
## with the Medpace inSitE Shiny app
################################################################################

library(httr)
library(jsonlite)
library(dplyr)
library(DBI)
library(odbc)

# Load the parser functions
source("cortex_api_parser.R")

################################################################################
## Setup Connection and Get Credentials
################################################################################

# Connect using existing DSN (works with OAuth, key pair, username/password, etc.)
aiconn <- DBI::dbConnect(odbc::odbc(), "AIrole", Warehouse = "INFORMATICS_AI")

# Get session token
session_token <- DBI::dbGetQuery(aiconn, "SELECT SYSTEM$GET_SESSION_TOKEN()")[[1]]

# Get account identifier
account_info <- DBI::dbGetQuery(aiconn, 
  "SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() as account")[[1]]

# Build API URL
api_url <- paste0("https://", account_info, 
                 ".snowflakecomputing.com/api/v2/cortex/inference:complete")


################################################################################
## Example 1: Simple Question-Answer
################################################################################

simple_example <- function() {
  cat("\n=== Example 1: Simple Question-Answer ===\n")
  
  result <- cortex_api_call(
    url = api_url,
    token = session_token,
    model = "claude-4-sonnet",
    messages = list(
      list(role = "user", content = "What is k-means clustering in 2 sentences?")
    ),
    max_tokens = 200
  )
  
  if (result$success) {
    cat("\nResponse:\n", result$text, "\n")
    cat("\nTokens used:", result$usage$total_tokens, "\n")
  } else {
    cat("\nError:", result$error, "\n")
  }
  
  return(result)
}


################################################################################
## Example 2: System Prompt + User Prompt (Recommended)
################################################################################

system_prompt_example <- function() {
  cat("\n=== Example 2: System Prompt + User Prompt ===\n")
  
  result <- cortex_api_call(
    url = api_url,
    token = session_token,
    model = "claude-4-sonnet",
    messages = list(
      list(role = "system", content = "You are a clinical trial expert. Provide concise, actionable advice."),
      list(role = "user", content = "What factors indicate a high-performing clinical trial site?")
    ),
    max_tokens = 300
  )
  
  if (result$success) {
    cat("\nResponse:\n", result$text, "\n")
    
    # Extract bullet points if present
    bullets <- parse_bullet_list(result$text)
    if (length(bullets) > 0) {
      cat("\nExtracted bullet points:\n")
      print(bullets)
    }
  } else {
    cat("\nError:", result$error, "\n")
  }
  
  return(result)
}


################################################################################
## Example 3: Cluster Interpretation (Medpace Use Case)
################################################################################

cluster_interpretation_example <- function(cluster_data) {
  cat("\n=== Example 3: Cluster Interpretation ===\n")
  
  # Build cluster descriptions
  statement2 = "You are an expert clinical trial site selection advisor helping to interpret k-means clustering results. The clusters group clinical trial sites based on their historical performance metrics.

Context:
- Higher enrollment percentiles indicate better-performing sites (75th percentile = top 25% of sites)
- Lower startup weeks indicate faster site activation
- More studies indicate more experience
- These are real sites being evaluated for a new clinical trial

Your task: Provide actionable, specific interpretations that help users understand what type of sites are in each cluster."
  
  allclusters = ""
  for(i in unique(cluster_data$cluster)){
    tempstatement = paste0("\n",
                           "Cluster ",
                           i,
                           ":\n",
                           paste(subset(cluster_data$shortprompt, 
                                       cluster_data$cluster == i), 
                                 collapse="\n"))
    allclusters = paste(allclusters, tempstatement, sep="\n")
  }
  
  statement4 = "\n\nProvide a concise interpretation of each cluster in 10 words or less"
  
  # Make API call
  result <- cortex_api_call(
    url = api_url,
    token = session_token,
    model = "claude-4-sonnet",
    messages = list(
      list(role = "system", content = statement2),
      list(role = "user", content = paste0(allclusters, statement4))
    ),
    max_tokens = 500
  )
  
  if (result$success) {
    cat("\nFull Response:\n", result$text, "\n")
    
    # Parse cluster interpretations
    interpretations <- parse_cluster_interpretations(result$text)
    cat("\nParsed Cluster Interpretations:\n")
    print(interpretations)
    
    cat("\nTokens used:", result$usage$total_tokens, "\n")
    
    return(interpretations)
  } else {
    cat("\nError:", result$error, "\n")
    return(NULL)
  }
}


################################################################################
## Example 4: Manual Response Parsing (Low-Level)
################################################################################

manual_parsing_example <- function() {
  cat("\n=== Example 4: Manual Response Parsing ===\n")
  
  # Make raw POST call
  response <- POST(
    url = api_url,
    add_headers(
      "Authorization" = paste("Bearer", session_token),
      "Content-Type" = "application/json",
      "Accept" = "application/json"
    ),
    body = toJSON(list(
      model = "claude-4-sonnet",
      messages = list(
        list(role = "user", content = "List 3 benefits of Snowflake")
      ),
      max_tokens = 200
    ), auto_unbox = TRUE),
    encode = "json"
  )
  
  # Parse step by step
  cat("\nStep 1: Check HTTP status\n")
  cat("Status:", status_code(response), "\n")
  
  if (!http_error(response)) {
    cat("\nStep 2: Parse JSON\n")
    parsed <- parse_cortex_response(response)
    cat("Response ID:", parsed$id, "\n")
    cat("Model:", parsed$model, "\n")
    
    cat("\nStep 3: Extract text\n")
    text <- extract_cortex_text(parsed)
    cat("Text:\n", text, "\n")
    
    cat("\nStep 4: Extract metadata\n")
    metadata <- extract_cortex_metadata(parsed)
    print(metadata)
    
    cat("\nStep 5: Extract usage stats\n")
    usage <- extract_cortex_usage(parsed)
    print(usage)
  } else {
    cat("Error:", content(response, "text"), "\n")
  }
}


################################################################################
## Example 5: Error Handling
################################################################################

error_handling_example <- function() {
  cat("\n=== Example 5: Error Handling ===\n")
  
  # Test 1: Invalid model
  cat("\nTest 1: Invalid model name\n")
  result <- cortex_api_call(
    url = api_url,
    token = session_token,
    model = "invalid-model-name",
    messages = list(list(role = "user", content = "Hello")),
    max_tokens = 50
  )
  cat("Success:", result$success, "\n")
  if (!result$success) {
    cat("Error:", result$error, "\n")
  }
  
  # Test 2: Empty messages
  cat("\nTest 2: Empty messages\n")
  result <- cortex_api_call(
    url = api_url,
    token = session_token,
    model = "claude-4-sonnet",
    messages = list(),
    max_tokens = 50
  )
  cat("Success:", result$success, "\n")
  if (!result$success) {
    cat("Error:", result$error, "\n")
  }
}


################################################################################
## Run Examples
################################################################################

# Uncomment to run individual examples:

# simple_example()
# system_prompt_example()

# For cluster example, provide sample data:
# sample_cluster_data <- data.frame(
#   cluster = c(1, 1, 2, 2, 3, 3),
#   shortprompt = c(
#     "High enrollment (85th percentile), Fast startup (4 weeks), 15 studies",
#     "High enrollment (90th percentile), Fast startup (3 weeks), 20 studies",
#     "Medium enrollment (50th percentile), Medium startup (8 weeks), 8 studies",
#     "Medium enrollment (55th percentile), Medium startup (7 weeks), 10 studies",
#     "Low enrollment (20th percentile), Slow startup (15 weeks), 3 studies",
#     "Low enrollment (15th percentile), Slow startup (18 weeks), 2 studies"
#   )
# )
# cluster_interpretation_example(sample_cluster_data)

# manual_parsing_example()
# error_handling_example()


################################################################################
## Integration with Shiny App
################################################################################

# To use in your Shiny app, replace the observeEvent code with:
#
# observeEvent(input$interpretclusters, {
#   
#   df = clustersummary()
#   
#   # Build prompts (same as before)
#   statement2 = "You are an expert clinical trial site selection advisor..."
#   allclusters = ""
#   for(i in unique(df$cluster)){
#     tempstatement = paste0("\nCluster ", i, ":\n",
#                            paste(subset(df$shortprompt, df$cluster == i), 
#                                  collapse="\n"))
#     allclusters = paste(allclusters, tempstatement, sep="\n")
#   }
#   statement4 = "\n\nProvide a concise interpretation of each cluster in 10 words or less"
#   
#   # Get account info
#   session_token <- DBI::dbGetQuery(aiconn, "SELECT SYSTEM$GET_SESSION_TOKEN()")[[1]]
#   account_info <- DBI::dbGetQuery(aiconn, 
#     "SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() as account")[[1]]
#   api_url <- paste0("https://", account_info, 
#                    ".snowflakecomputing.com/api/v2/cortex/inference:complete")
#   
#   # Make API call with helper function
#   result <- cortex_api_call(
#     url = api_url,
#     token = session_token,
#     model = "claude-4-sonnet",
#     messages = list(
#       list(role = "system", content = statement2),
#       list(role = "user", content = paste0(allclusters, statement4))
#     ),
#     max_tokens = 500
#   )
#   
#   if (result$success) {
#     # Parse interpretations
#     interpretation(parse_cluster_interpretations(result$text))
#   } else {
#     showNotification(paste("API call failed:", result$error), type = "error")
#   }
# })

