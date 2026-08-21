suppressPackageStartupMessages({
  require(httr)
  require(jsonlite)
  require(dplyr)
  require(glue)
  require(academictwitteR)
})

library(DBI)
# Connect to the default postgres database
library(odbc)
#con <- DBI::dbConnect(odbc::odbc())

#psql
#CREATE DATABASE  twitter;

con <- dbConnect(RPostgres::Postgres(), "twitter")

set_bearer()

#po <- readr::read_csv("twitter.csv") %>% group_by(author_id) %>% count() %>% arrange(n) %>% 
#  filter(n > 1)
#
#flt <- (po$author_id %in% as.numeric(stringr::str_remove_all(list.files("porohotweets", ".rds"), ".rds"))) == F
#
#po <- po[flt, ]

#authors <- unique(po$author_id)

authors <- readr::read_csv("list_of_ids.csv", col_types = list(list_of_ids=readr::col_character()))$list_of_ids

r <- list.files("/Volumes/Seagate Hub/porohotweets", pattern = ".rds") %>% 
  stringr::str_remove_all(".rds")

authors <- authors[!(authors %in% r)]

#authors <- sample(authors)

res <- dbSendQuery(con, "SELECT distinct * from bots_fast")

authors_new <- dbFetch(res)

authors <- authors_new %>% arrange(prob_bot) %>% 
  #filter(!(user_id %in% r)) #%>% 
  filter(user_id %in% authors) %>%
  pull(user_id)
  #filter(user_id %in% ukraine)

#authors_new <- authors_new$author_id

#res <- dbSendQuery(con, "SELECT distinct * from users_country")
#
#users_country <- dbFetch(res)
#
#ukraine <- users_country %>% 
#  filter(country == "Ukraine") %>% 
#  pull(id)
#
#res <- dbSendQuery(con, "SELECT distinct * from locations")
#
#locations <- dbFetch(res)

for (author in authors) {
  tryCatch(
    expr = {
      tweets <-
        get_all_tweets(
          query = "",
          users=author,
          start_tweets = "2018-12-01T00:00:00Z",
          end_tweets = "2022-02-24T00:00:00Z",
          lang="uk",
          file = "porohotweetsfile",
          data_path = "porohodata/",
          n = 100000000000,
        )
      tweets_ru <-
        get_all_tweets(
          query = "",
          users=author,
          start_tweets = "2018-12-01T00:00:00Z",
          end_tweets = "2022-02-24T00:00:00Z",
          lang="ru",
          file = "porohotweetsfile",
          data_path = "porohodata/",
          n = 100000000000,
        )
      tweets <- bind_rows(tweets, tweets_ru)
      if (nrow(tweets) > 0){
        readr::write_rds(tweets, glue::glue("/Volumes/Seagate Hub/porohotweets/{author}.rds"))  
      }
    },
    error = function(e){ 
      print(e)
    }
  )
}

