suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(DBI)
  library(odbc)
})


con <- dbConnect(RPostgres::Postgres(), "twitter")

dbListTables(con)

#res <- dbSendQuery(con, "SELECT * from geo left join (select conversation_id, author_id from tweets) b on geo.conversation_id=b.conversation_id")

#geo_df <- dbFetch(res)
#
#geo_df <- geo_df %>% 
#  group_by(author_id, lon, lat) %>% 
#  count() %>% 
#  group_by(author_id) %>% 
#  top_n(1, n) %>% 
#  slice(1) %>% 
#  select(-n)
#
#
#dbWriteTable(con, "locations_by_tweets", geo_df, append=TRUE)

#res <- dbSendQuery(con, "SELECT created_at from tweets")
#
#df <- dbFetch(res)
#
#hist(df$created_at, 20)

dt <- seq(ymd('2022-01-30'),ymd('2022-04-01'), by = 'month')
#c('2018-11-30', '2019-02-01', '2019-05-01', '2019-08-01', '2019-12-01', '2020-02-01', '2020-05-01', '2020-08-01', '2021-02-01', '2021-05-01', '2021-09-01', '2022-03-01')

#na.omit(lag(dt))

dir.create("top_model_texts")

res <- dbSendQuery(con, 
           glue::glue("select a.id, created_at, text, retweet_count from 
                      ((SELECT id, date_trunc('day', created_at) as created_at, text, author_id, retweet_count, length(text) len from tweets) a 
                      left join users_country on a.author_id=users_country.id) 
                      where country = 'Ukraine' and retweet_count > 10 and len > 20 and substring(text,1,1)!=':' and strpos('withheld', text)=0"))

texts <- dbFetch(res)

texts <- texts %>% filter(!str_detect(text, "withheld")) %>% filter(!str_detect(text, "unavailable"))

res <- dbSendQuery(con, "SELECT * from tweets limit 100")

texts <- dbFetch(res)

res <- dbSendQuery(con, "SELECT * from urls limit 100")

texts <- dbFetch(res)

write_csv(texts, "texts_for_topic.csv")

dbClearResult(res)

map2(na.omit(lag(dt)), dt[2:length(dt)], function(x, y){
  res <- dbSendQuery(con, 
                     glue::glue("SELECT id, created_at, text from tweets 
                   where created_at > '{x}' 
                   and created_at <= '{y}'"))
  print(x)
  write_csv(dbFetch(res), glue::glue("top_model_texts/texts_for_topic_{x}.csv"))
})


res <- dbSendQuery(con, "SELECT * from urls limit 10")
#
df <- dbFetch(res)


