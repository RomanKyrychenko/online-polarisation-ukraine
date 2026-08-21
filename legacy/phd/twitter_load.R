suppressPackageStartupMessages({
  require(httr)
  require(jsonlite)
  require(dplyr)
  require(glue)
  require(academictwitteR)
})

set_bearer()

po <- readr::read_csv("twitter.csv")

authors <- unique(po$author_id)

tweets <-
  get_all_tweets(
    query = "",
    users=authors[6:length(authors)],
    start_tweets = "2018-12-01T00:00:00Z",
    end_tweets = "2022-02-24T00:00:00Z",
    file = "porohotweets",
    data_path = "porohodata/",
    n = 100000000000,
  )


readr::write_rds(tweets, "poroho_tweets.rds")


Sys.setenv(BEARER_TOKEN = Sys.getenv("TWITTER_BEARER_TOKEN"))

bearer_token <- Sys.getenv("BEARER_TOKEN")   
headers <- c(`Authorization` = sprintf('Bearer %s', bearer_token),
             `User-Agent` = "v2FullArchiveSearchPython")

phrase = "порошенко"

dfs = tibble()

dates <- seq(as.POSIXct("2018-12-01 00:00:00"), as.POSIXct("2022-02-23 23:59:59"), by="6 hours") %>% 
  strftime("%Y-%m-%dT%H:%M:%SZ")


get_data <- function(headers, params){
  response <- httr::GET(url = 'https://api.twitter.com/2/tweets/search/all', httr::add_headers(.headers=headers), query = params)
  
  fas_body <-
    content(
      response,
      as = 'parsed',
      type = 'application/json',
      simplifyDataFrame = TRUE
    )
  
  if (length(fas_body) == 2) {
    return(tibble(fas_body$data))
  } else {
    return(tibble())
  }
}

get_data <- purrr::safely(get_data)

for (i in 1:(length(dates)-1)) {
  print((i/length(dates)) * 100)
  params = list(
    `query` = paste0(phrase, ' -RT'),
    `max_results` = '100',
    start_time = dates[1:(length(dates)-1)][i],
    end_time = dates[2:length(dates)][i],
    `tweet.fields` = 'id,created_at,lang,text,author_id'
  )
  
  re <- get_data(headers, params)
  
  dfs <- bind_rows(dfs, re$result)
  
  print(nrow(dfs))
  
  Sys.sleep(3)
}

readr::write_csv(dfs %>% select(-withheld), paste0(phrase, "_twi.csv"))
