suppressPackageStartupMessages({
  library(tidyverse)
  library(tidygeocoder)
  library(sp)
  library(rworldmap)
  library(DBI)
  library(odbc)
})


coords2country = function(points) {  
  countriesSP <- getMap(resolution='low')
  pointsSP = SpatialPoints(points, proj4string=CRS(proj4string(countriesSP)))  
  indices = over(pointsSP, countriesSP)
  indices$ADMIN  
}


con <- dbConnect(RPostgres::Postgres(), "twitter")
dbListTables(con)

res <- dbSendQuery(con, "SELECT * from locations where location is not NULL and longitude is not NULL")
locations <- as_tibble(dbFetch(res))
locations$country <- coords2country(locations %>% select(longitude, latitude))

# tibble(country) %>% group_by(country) %>% count() %>% arrange(desc(n))

res <- dbSendQuery(con, "SELECT author_id as id, lon,lat from locations_by_tweets")
locations_by_tweets <- as_tibble(dbFetch(res))
locations_by_tweets$country <- coords2country(locations_by_tweets %>% select(lon, lat))
locations_by_tweets %>% group_by(country) %>% count() %>% arrange(desc(n))


res <- dbSendQuery(con, "SELECT author_id as id, lang, count(*) as n from tweets 
                   group by author_id, lang")
lang_stat <- as_tibble(dbFetch(res))
lang_stat <- lang_stat %>% group_by(id) %>% mutate(p = n / sum(n), n = sum(n))
lang_stat <- lang_stat %>% filter(n > 10)
lang_stat <- lang_stat %>% pivot_wider(id, names_from = lang, values_from = p, values_fill = 0)
# lang_stat %>% group_by(lang) %>% count() %>% arrange(desc(n))


res <- dbSendQuery(con, "select a.id, location, name from (SELECT distinct author_id as id from tweets) a left join 
                   (select id, location, name from users) b on a.id=b.id")

# res <- dbSendQuery(con, "select id, location from users")

users <- as_tibble(dbFetch(res))

users_final <- users %>% 
  left_join(locations, by="location") %>% 
  left_join(lang_stat, by="id") %>% 
  left_join(locations_by_tweets, by="id") %>% 
  mutate(
    country = case_when(
      uk > 0.2 ~ "Ukraine",
      uk > 0 & is.na(country.x) ~ "Ukraine",
      country.x == "Ukraine" ~ "Ukraine",
      country.y == "Ukraine" ~ "Ukraine",
      T ~ "Other"
      )
  ) 


users_final %>% filter(country.x == "Russia") %>% pull(uk) %>% hist()

users_final %>% 
  group_by(country) %>% count()


dbWriteTable(con, "users_country", users_final %>% select(id, country))

res <- dbSendQuery(con, "SELECT distinct user_id as id, prob_bot from bots")
bots <- as_tibble(dbFetch(res))

res <- dbSendQuery(con, "SELECT distinct user_id as id, prob_bot from bots_fast")
bots_fast <- as_tibble(dbFetch(res))

users_final %>% select(name, id, country) %>% left_join(bots_fast, by = "id") %>% View()

users_final %>% select(name, id, country) %>% 
  left_join(bots_fast, by = "id") %>% 
  pull(prob_bot) %>% hist() 
