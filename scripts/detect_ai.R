# detect_ai.R
# R implementation of AI-pattern detection for QDM/text documents
# Mirrors the logic of the provided Python script

suppressWarnings({
  suppressMessages({
    library(jsonlite)
    library(stringr)
  })
})

load_patterns <- function(filepath) {
  patterns <- fromJSON(readLines(filepath))
  
  # --- AI-heavy phrases to ensure are present ---
  ai_phrases <- list(
    high = c(
      "provide a valuable insight",
      "left an indelible mark",
      "a stark reminder",
      "a nuanced understanding",
      "significant role in shaping",
      "the complex interplay",
      "a pivotal moment",
      "play a pivotal role",
      "underscore the importance",
      "gain a deeper understanding",
      "far-reaching implications",
      "stand in stark contrast"
    ),
    medium = c(
      "a comprehensive understanding",
      "a significant milestone",
      "a significant step forward",
      "play a crucial role",
      "highlight the potential",
      "delve deeper into",
      "address the root cause",
      "pave the way for the future",
      "the transformative power",
      "a delicate balance",
      "the path ahead"
    ),
    low = c(
      "gain an insight",
      "add a layer",
      "offer a valuable",
      "a unique blend",
      "couldn't help but wonder",
      "the journey begins",
      "aim to explore",
      "ready to embrace"
    )
  )
  
  # British / US spelling normalization
  spelling_variants <- function(x) {
    v <- unique(c(
      x,
      gsub("behaviour", "behavior", x),
      gsub("behaviour", "behaviour", x),
      gsub("centre", "center", x),
      gsub("centre", "centre", x),
      gsub("programme", "program", x),
      gsub("programme", "programme", x),
      gsub("organisation", "organization", x),
      gsub("organisation", "organisation", x)
    ))
    v
  }
  
  for (intensity in names(ai_phrases)) {
    if (is.null(patterns[[intensity]])) patterns[[intensity]] <- c()
    
    for (phrase in ai_phrases[[intensity]]) {
      variants <- spelling_variants(phrase)
      for (v in variants) {
        if (!v %in% patterns[[intensity]]) {
          patterns[[intensity]] <- c(patterns[[intensity]], v)
        }
      }
    }
  }
  
  patterns
}

detect_ai_patterns <- function(text, patterns) {
  results <- list(high = list(), medium = list(), low = list())
  detections <- list()
  
  text_lower <- tolower(text)
  
  # Flatten patterns into (base_phrase, intensity)
  all_patterns <- data.frame(
    phrase = character(),
    intensity = character(),
    stringsAsFactors = FALSE
  )
  
  for (intensity in names(patterns)) {
    for (phrase in patterns[[intensity]]) {
      all_patterns <- rbind(all_patterns,
                            data.frame(phrase = phrase, intensity = intensity,
                                       stringsAsFactors = FALSE))
    }
  }
  
  # Longer phrases first
  all_patterns <- all_patterns[order(nchar(all_patterns$phrase), decreasing = TRUE), ]
  
  matched_spans <- list()
  
  for (i in seq_len(nrow(all_patterns))) {
    base_phrase <- all_patterns$phrase[i]
    intensity <- all_patterns$intensity[i]
    
    # Allow basic conjugation / plural variation on last word
    tokens <- unlist(strsplit(base_phrase, "\\s+"))
    
    if (length(tokens) > 1) {
      tokens[length(tokens)] <- paste0(tokens[length(tokens)], "(s|es|ed|ing)?")
    } else {
      tokens <- paste0(tokens, "(s|es|ed|ing)?")
    }
    
    pattern <- paste0("\\b", paste(tokens, collapse = "\\s+"), "\\b")
    
    matches <- stringr::str_locate_all(text_lower, regex(pattern, ignore_case = TRUE))[[1]]
    if (nrow(matches) == 0) next
    
    for (j in seq_len(nrow(matches))) {
      span <- matches[j, ]
      
      # Overlap check
      overlap <- FALSE
      for (s in matched_spans) {
        if (span[1] < s[2] && span[2] > s[1]) {
          overlap <- TRUE
          break
        }
      }
      if (overlap) next
      
      matched_spans[[length(matched_spans) + 1]] <- span
      
      exact_text <- substr(text, span[1], span[2])
      
      detections[[length(detections) + 1]] <- list(
        base_phrase = base_phrase,
        detected_phrase = exact_text,
        intensity = intensity,
        start = span[1],
        end = span[2]
      )
      
      key <- paste(base_phrase, exact_text, sep = " | ")
      if (is.null(results[[intensity]][[key]])) {
        results[[intensity]][[key]] <- 1
      } else {
        results[[intensity]][[key]] <- results[[intensity]][[key]] + 1
      }
    }
  }
  
  list(summary = results, details = detections)
}

calculate_score <- function(results, total_words) {
  weights <- c(high = 3, medium = 2, low = 1)
  
  total_score <- 0
  detected_count <- 0
  
  for (intensity in names(results)) {
    for (word in names(results[[intensity]])) {
      count <- results[[intensity]][[word]]
      total_score <- total_score + count * weights[[intensity]]
      detected_count <- detected_count + count
    }
  }
  
  if (total_words == 0) return(list(score = 0, detected = 0))
  
  normalized_score <- (total_score / total_words) * 100
  list(score = normalized_score, detected = detected_count)
}

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  
  # Default: current directory
  if (length(args) == 0) {
    input_folder <- "."
  } else {
    input_folder <- args[1]
  }
  
  if (!dir.exists(input_folder)) {
    stop(paste("Error: Folder", input_folder, "not found."))
  }
  
  files <- list.files(input_folder, pattern = "\\.qmd$", full.names = TRUE)
  if (length(files) == 0) {
    stop("No .qmd files found in input folder.")
  }
  
  patterns <- load_patterns("scripts/ai_patterns.json")
  
  # Create output file with timestamp
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  output_file <- paste0("ai_detection_report_", timestamp, ".txt")
  
  # Open file connection
  output_conn <- file(output_file, "w")
  
  cat("AI Pattern Detection Report\n", file = output_conn)
  cat("Generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n", file = output_conn)
  cat("Input Folder:", normalizePath(input_folder), "\n\n", file = output_conn)
  
  for (file in files) {
    cat("\n==============================\n", file = output_conn)
    cat("File:", basename(file), "\n", file = output_conn)
    cat("==============================\n", file = output_conn)
    
    text <- paste(readLines(file, warn = FALSE), collapse = "\n")
    
    detected <- detect_ai_patterns(text, patterns)
    results <- detected$summary
    details <- detected$details
    
    total_words <- length(unlist(stringr::str_extract_all(text, "\\w+")))
    score_data <- calculate_score(results, total_words)
    
    cat("--- AI Word Detection Report ---\n", file = output_conn)
    cat("Total Words:", total_words, "\n", file = output_conn)
    cat("Detected AI Patterns:", score_data$detected, "\n", file = output_conn)
    cat(sprintf("AI Intensity Score: %.2f\n", score_data$score), file = output_conn)
    cat("\nBreakdown:\n", file = output_conn)
    
    for (intensity in c("high", "medium", "low")) {
      if (length(results[[intensity]]) > 0) {
        cat("\n[", toupper(intensity), " INTENSITY]\n", sep = "", file = output_conn)
        sorted <- sort(unlist(results[[intensity]]), decreasing = TRUE)
        for (key in names(sorted)) {
          cat("-", key, ":", sorted[[key]], "\n", file = output_conn)
        }
      }
    }
    
    if (length(details) > 0) {
      cat("\n--- Detailed Detections ---\n", file = output_conn)
      for (d in details) {
        cat(sprintf(
          "[%s] '%s' (matched from '%s') at chars %d–%d\n",
          toupper(d$intensity),
          d$detected_phrase,
          d$base_phrase,
          d$start,
          d$end
        ), file = output_conn)
      }
    }
  }
  
  close(output_conn)
  
  cat("\n✓ Report saved to:", output_file, "\n")
}

if (sys.nframe() == 0) {
  main()
}
