################################################################################
## Cortex REST API Response Parser for R
## 
## This script provides helper functions to parse responses from the 
## Snowflake Cortex LLM REST API (/api/v2/cortex/inference:complete)
##
## Supports both response formats:
##   - Streaming (text/event-stream) - DEFAULT
##   - Non-streaming (application/json)
##
## Usage:
##   source("cortex_api_parser.R")
##   result <- parse_cortex_response(response)  # Automatically detects format
##   text <- extract_cortex_text(result)
################################################################################

library(httr)
library(jsonlite)
library(dplyr)

################################################################################
## Core Parsing Functions
################################################################################

#' Parse Cortex REST API Response
#' 
#' Handles both regular JSON and streaming (text/event-stream) responses
#' 
#' @param response httr response object from POST call to Cortex API
#' @return List containing parsed response or NULL if error
#' @examples
#' response <- POST(...)
#' parsed <- parse_cortex_response(response)
parse_cortex_response <- function(response) {
  
  # Check if response is valid
  if (is.null(response)) {
    warning("Response is NULL")
    return(NULL)
  }
  
  # Check for HTTP errors
  if (http_error(response)) {
    error_msg <- sprintf("HTTP %s: %s", 
                        status_code(response),
                        content(response, "text", encoding = "UTF-8"))
    warning(error_msg)
    return(NULL)
  }
  
  # Check content type to determine parsing strategy
  content_type <- headers(response)$`content-type`
  
  # Handle streaming response (text/event-stream)
  if (!is.null(content_type) && grepl("text/event-stream", content_type, ignore.case = TRUE)) {
    return(parse_streaming_response(response))
  }
  
  # Handle regular JSON response
  tryCatch({
    parsed <- content(response, as = "parsed", encoding = "UTF-8")
    return(parsed)
  }, error = function(e) {
    warning(paste("Failed to parse response:", e$message))
    return(NULL)
  })
}


#' Parse Streaming Response (Server-Sent Events)
#' 
#' Parses text/event-stream format from Cortex API
#' 
#' @param response httr response object with streaming content
#' @return List containing parsed response (last complete message)
parse_streaming_response <- function(response) {
  
  tryCatch({
    # Get raw text content
    raw_text <- content(response, as = "text", encoding = "UTF-8")
    
    # Split by lines
    lines <- strsplit(raw_text, "\n")[[1]]
    
    # Filter lines that start with "data: " and extract JSON
    data_lines <- lines[grepl("^data: ", lines)]
    
    if (length(data_lines) == 0) {
      warning("No data lines found in streaming response")
      return(NULL)
    }
    
    # Parse each data line and collect
    chunks <- list()
    full_text <- ""
    last_parsed <- NULL
    
    for (line in data_lines) {
      # Remove "data: " prefix
      json_str <- sub("^data: ", "", line)
      
      # Parse JSON
      chunk <- tryCatch({
        fromJSON(json_str, simplifyVector = FALSE)
      }, error = function(e) {
        NULL
      })
      
      if (!is.null(chunk)) {
        chunks[[length(chunks) + 1]] <- chunk
        last_parsed <- chunk
        
        # Accumulate text from delta content if present
        if (!is.null(chunk$choices) && length(chunk$choices) > 0) {
          choice <- chunk$choices[[1]]
          if (!is.null(choice$delta) && !is.null(choice$delta$content)) {
            full_text <- paste0(full_text, choice$delta$content)
          }
        }
      }
    }
    
    # Return combined response using last chunk's structure
    if (!is.null(last_parsed)) {
      # Update with accumulated text
      if (nchar(full_text) > 0 && !is.null(last_parsed$choices) && length(last_parsed$choices) > 0) {
        # Create a unified response structure
        result <- last_parsed
        result$choices[[1]]$messages <- list(list(content = full_text))
        result$full_text <- full_text
        result$num_chunks <- length(chunks)
        return(result)
      }
      return(last_parsed)
    }
    
    warning("Could not parse streaming response")
    return(NULL)
    
  }, error = function(e) {
    warning(paste("Error parsing streaming response:", e$message))
    return(NULL)
  })
}


#' Extract Text from Cortex Response
#' 
#' Handles multiple response formats from Cortex API including streaming
#' 
#' @param parsed_response Parsed JSON response from parse_cortex_response()
#' @return Character string of response text, or NULL if extraction fails
extract_cortex_text <- function(parsed_response) {
  
  if (is.null(parsed_response)) {
    return(NULL)
  }
  
  tryCatch({
    # Format 0: Streaming response - check for accumulated full_text first
    if (!is.null(parsed_response$full_text)) {
      return(parsed_response$full_text)
    }
    
    # Check if choices array exists
    if (is.null(parsed_response$choices) || length(parsed_response$choices) == 0) {
      warning("No choices found in response")
      return(NULL)
    }
    
    choice <- parsed_response$choices[[1]]
    
    # Handle different response formats
    # Format 1: choices[[1]]$messages (direct string)
    if (!is.null(choice$messages) && is.character(choice$messages)) {
      return(choice$messages)
    }
    
    # Format 2: choices[[1]]$messages[[1]]$content (nested structure)
    if (!is.null(choice$messages) && is.list(choice$messages)) {
      if (length(choice$messages) > 0 && !is.null(choice$messages[[1]]$content)) {
        return(choice$messages[[1]]$content)
      }
    }
    
    # Format 3: choices[[1]]$delta$content (streaming format - single chunk)
    if (!is.null(choice$delta) && !is.null(choice$delta$content)) {
      return(choice$delta$content)
    }
    
    # Format 4: choices[[1]]$message$content (alternative format)
    if (!is.null(choice$message) && !is.null(choice$message$content)) {
      return(choice$message$content)
    }
    
    warning("Could not extract text from response structure")
    return(NULL)
    
  }, error = function(e) {
    warning(paste("Error extracting text:", e$message))
    return(NULL)
  })
}


#' Extract Token Usage Statistics
#' 
#' @param parsed_response Parsed JSON response from parse_cortex_response()
#' @return Data frame with token usage statistics
extract_cortex_usage <- function(parsed_response) {
  
  if (is.null(parsed_response) || is.null(parsed_response$usage)) {
    return(data.frame(
      prompt_tokens = NA,
      completion_tokens = NA,
      guard_tokens = NA,
      total_tokens = NA
    ))
  }
  
  usage <- parsed_response$usage
  
  data.frame(
    prompt_tokens = ifelse(is.null(usage$prompt_tokens), NA, usage$prompt_tokens),
    completion_tokens = ifelse(is.null(usage$completion_tokens), NA, usage$completion_tokens),
    guard_tokens = ifelse(is.null(usage$guard_tokens), NA, usage$guard_tokens),
    total_tokens = ifelse(is.null(usage$total_tokens), NA, usage$total_tokens)
  )
}


#' Extract Response Metadata
#' 
#' @param parsed_response Parsed JSON response from parse_cortex_response()
#' @return List with metadata (id, model, created timestamp)
extract_cortex_metadata <- function(parsed_response) {
  
  if (is.null(parsed_response)) {
    return(list(id = NA, model = NA, created = NA))
  }
  
  list(
    id = ifelse(is.null(parsed_response$id), NA, parsed_response$id),
    model = ifelse(is.null(parsed_response$model), NA, parsed_response$model),
    created = ifelse(is.null(parsed_response$created), NA, parsed_response$created),
    created_datetime = ifelse(is.null(parsed_response$created), 
                              NA, 
                              as.POSIXct(parsed_response$created, origin = "1970-01-01", tz = "UTC"))
  )
}


#' All-in-One Parser: Extract Everything
#' 
#' @param response httr response object from POST call to Cortex API
#' @return List containing text, usage, and metadata
#' @examples
#' response <- POST(...)
#' result <- parse_cortex_full(response)
#' print(result$text)
#' print(result$usage)
#' print(result$metadata)
parse_cortex_full <- function(response) {
  
  parsed <- parse_cortex_response(response)
  
  list(
    text = extract_cortex_text(parsed),
    usage = extract_cortex_usage(parsed),
    metadata = extract_cortex_metadata(parsed),
    raw = parsed
  )
}


################################################################################
## Specialized Parsing Functions
################################################################################

#' Parse Cluster Interpretations (Medpace-specific)
#' 
#' Extracts cluster interpretations from LLM response, filtering for lines
#' that start with "Cluster"
#' 
#' @param llm_text Character string from extract_cortex_text()
#' @return Data frame with cluster interpretations
parse_cluster_interpretations <- function(llm_text) {
  
  if (is.null(llm_text) || nchar(llm_text) == 0) {
    return(data.frame(Interpretation = character(0)))
  }
  
  tryCatch({
    data.frame(results = strsplit(llm_text, '\n')[[1]]) %>%
      rowwise() %>%
      mutate(
        firstword = ifelse(length(strsplit(results, " ")[[1]]) > 0,
                          strsplit(results, " ")[[1]][1],
                          ""),
        cluster = grepl('cluster', firstword, ignore.case = TRUE)
      ) %>%
      filter(cluster == TRUE) %>% 
      select(Interpretation = results) %>%
      ungroup()
  }, error = function(e) {
    warning(paste("Error parsing cluster interpretations:", e$message))
    return(data.frame(Interpretation = character(0)))
  })
}


#' Parse Bulleted List from LLM Response
#' 
#' Extracts lines that start with bullets (-, *, •, or numbers)
#' 
#' @param llm_text Character string from extract_cortex_text()
#' @return Character vector of bullet points
parse_bullet_list <- function(llm_text) {
  
  if (is.null(llm_text) || nchar(llm_text) == 0) {
    return(character(0))
  }
  
  lines <- strsplit(llm_text, '\n')[[1]]
  
  # Match lines starting with -, *, •, or numbers followed by . or )
  bullet_pattern <- "^\\s*([\\-\\*•]|\\d+[\\.\\)])"
  
  lines[grepl(bullet_pattern, lines)]
}


#' Split Multi-Section LLM Response
#' 
#' Splits response by markdown headers (##, ###) or section dividers
#' 
#' @param llm_text Character string from extract_cortex_text()
#' @return Named list of sections
parse_sections <- function(llm_text) {
  
  if (is.null(llm_text) || nchar(llm_text) == 0) {
    return(list())
  }
  
  lines <- strsplit(llm_text, '\n')[[1]]
  
  # Find header lines
  header_pattern <- "^#{1,3}\\s+(.+)$"
  header_indices <- which(grepl(header_pattern, lines))
  
  if (length(header_indices) == 0) {
    return(list(content = llm_text))
  }
  
  sections <- list()
  
  for (i in seq_along(header_indices)) {
    header_line <- lines[header_indices[i]]
    section_name <- gsub(header_pattern, "\\1", header_line)
    section_name <- trimws(section_name)
    
    # Get content between this header and next (or end)
    start_idx <- header_indices[i] + 1
    end_idx <- ifelse(i < length(header_indices), 
                     header_indices[i + 1] - 1, 
                     length(lines))
    
    section_content <- paste(lines[start_idx:end_idx], collapse = "\n")
    sections[[section_name]] <- trimws(section_content)
  }
  
  return(sections)
}


################################################################################
## Error Handling Wrapper
################################################################################

#' Safe Cortex API Call with Automatic Parsing
#' 
#' Makes API call and handles all parsing automatically
#' 
#' @param url API endpoint URL
#' @param token Bearer token
#' @param model Model name (e.g., "claude-4-sonnet")
#' @param messages List of message objects with role and content
#' @param max_tokens Maximum tokens in response
#' @param temperature Temperature parameter (0-1)
#' @return List with success flag, text, usage, metadata, and any error message
cortex_api_call <- function(url, 
                           token, 
                           model, 
                           messages, 
                           max_tokens = 500,
                           temperature = 0) {
  
  result <- list(
    success = FALSE,
    text = NULL,
    usage = NULL,
    metadata = NULL,
    error = NULL
  )
  
  tryCatch({
    response <- POST(
      url = url,
      add_headers(
        "Authorization" = paste("Bearer", token),
        "Content-Type" = "application/json",
        "Accept" = "application/json"
      ),
      body = toJSON(list(
        model = model,
        messages = messages,
        max_tokens = max_tokens,
        temperature = temperature
      ), auto_unbox = TRUE),
      encode = "json",
      timeout(30)
    )
    
    if (http_error(response)) {
      result$error <- sprintf("HTTP %s: %s", 
                             status_code(response),
                             content(response, "text"))
      return(result)
    }
    
    parsed <- parse_cortex_full(response)
    
    result$success <- !is.null(parsed$text)
    result$text <- parsed$text
    result$usage <- parsed$usage
    result$metadata <- parsed$metadata
    
    return(result)
    
  }, error = function(e) {
    result$error <- e$message
    return(result)
  })
}


################################################################################
## Example Usage
################################################################################

# Example 1: Basic usage
# response <- POST(url, headers, body)
# text <- parse_cortex_response(response) %>% extract_cortex_text()

# Example 2: Full extraction
# response <- POST(url, headers, body)
# result <- parse_cortex_full(response)
# print(result$text)
# print(result$usage)

# Example 3: Cluster interpretations (Medpace-specific)
# response <- POST(url, headers, body)
# text <- parse_cortex_response(response) %>% extract_cortex_text()
# clusters <- parse_cluster_interpretations(text)

# Example 4: All-in-one safe call
# result <- cortex_api_call(
#   url = "https://account.snowflakecomputing.com/api/v2/cortex/inference:complete",
#   token = session_token,
#   model = "claude-4-sonnet",
#   messages = list(
#     list(role = "system", content = "You are a helpful assistant"),
#     list(role = "user", content = "Explain k-means clustering")
#   )
# )
# if (result$success) {
#   print(result$text)
# } else {
#   print(result$error)
# }

