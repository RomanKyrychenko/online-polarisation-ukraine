suppressPackageStartupMessages({
  library(tidyverse)
  library(tidygeocoder)
  library(sp)
  library(rworldmap)
  library(DBI)
  library(odbc)
})

con <- dbConnect(RPostgres::Postgres(), "twitter")

res <- dbSendQuery(con, "SELECT location, count(*) as n from users group by location order by n desc")

locations <- as_tibble(dbFetch(res))

res <- dbSendQuery(con, "SELECT location from locations")

locations_ready <- as_tibble(dbFetch(res))

locations <- locations %>% filter(!(location %in% locations_ready$location))

locations_chunks <- split(locations, (as.numeric(rownames(locations))-1) %/% 200)

purrr::map(locations_chunks, function(x){
  data <- geocode(x, location, method = 'osm', lat = latitude, long = longitude)
  dbWriteTable(con, "locations", data, append=TRUE)
}, .progress = TRUE)

