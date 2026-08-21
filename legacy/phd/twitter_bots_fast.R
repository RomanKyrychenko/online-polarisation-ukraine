suppressPackageStartupMessages({
  library(tweetbotornot)
  library(DBI)
  library(odbc)
  library(tidyverse)
})


con <- dbConnect(RPostgres::Postgres(), "twitter")


get_bot_score <- function(){
  res <- dbSendQuery(con, glue::glue("
  select created_at as account_created_at, id as user_id, description, description as text,
username, verified, followers_count, following_count as friends_count, name,
tweet_count as statuses_count, listed_count, location from users"))
  
  user <- dbFetch(res) %>% 
    mutate(#is_retweet=map_lgl(text, ~substr(., 1, 2) == ": "),
           #is_quote=!is.na(in_reply_to_user_id),
           favourites_count=0, 
    )
  
  dbClearResult(res)
  
  data <- tweetbotornot(user, fast = TRUE)
  dbWriteTable(con, "bots_fast", data, append=TRUE)
}

get_bot_score()
