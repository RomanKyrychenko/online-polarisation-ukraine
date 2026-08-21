suppressPackageStartupMessages({
  library(tidyverse)
  library(tidygeocoder)
  library(sp)
  library(rworldmap)
  library(DBI)
  library(odbc)
})

users <- list.files("porohodata", pattern = "users", full.names = T)

sizes <- map_int(users, file.size)

dat <- tibble(
  users, sizes
) %>% 
  filter(sizes > 10) %>% 
  arrange(sizes)

exc <- c("Россия", "Russia", "USA", "Москва", "Washington", "Санкт-Петербург", "Bulgaria",
         "Los Angeles", "New York", "London", "England", "Kazakhstan", "Israel", "Kyrgyzstan", 
         "Беларусь", "Moscow", "Moskova", "United States", "Polska", "France", "San Francisco", 
         "Paris", "United Kingdom", "Chicago", "Houston", "NY", "México", "Mongolia", "Portland", 
         "Argentina", "日本", "Canada", "Brasil", "TX", "UK", "MA", "WA", "Australia", "Poland", 
         "Ontario", "Yhdysvallat", "Berlin", "GA", "Venäjä", "Sofia", "Минск", "Georgia", "Prague",
         "Minsk", "Warszawa", "Germany", "東京", "India", "Mexico", "España", "Amsterdam", "PA",
         "Tokyo", "Azerbaijan", "Brussels", "California", "Belgium", "Japan", "Puola", "Armenia",
         "San Diego, CA", "Ranska", "Nederland", "FL", "CO", "Toronto", 
         "Texas", "Austria", "São Paulo", "Venezuela", "Vancouver", "Deutschland", "Italia", 
         "The Netherlands", "Türkiye", "Hong Kong", "NV", "Singapore", "MN", "Québec", "Ulaanbaatar", 
         "Buenos Aires", "Finland", "TN", "Ciudad Autónoma de Buenos Aire", "Ireland", "South Africa",
         "Sweden", "Victoria", "Madrid", "Rio de Janeiro", "Warsaw", "Brooklyn", "AZ", "Netherlands", 
         "Lithuania", "Switzerland", "CA", "Porto Alegre", "Türkiye", "Seattle", "Estonia", "Italy", 
         "Tbilisi", "Самара", "New Zealand", "Belarus", "Latvia", "Chile", "Boston", "Kenya", 
         "MD", "Barcelona", "Sao Paulo, Brazil", "Cyprus",  "Scotland", "Guadalajara", 
         "Madrid", "Morelia", "Switzerland", "Sydney", "Brazil", "Glasgow, Scotland", 
         "Orlando", "Yhdistynyt kuningaskunta", "Florida", "Stockholm", "Sweden", "MI", "WI", 
         "Meksiko", "Sydney", "Belgium", "Monterrey", "Yerevan", "Armenia", "Харьков", "Istanbul", 
         "Turkey", "Baku", "Azerbaijan", "Columbus", "OH", "Edinburgh", "Scotland", "Ranska", "大阪", 
         "Madrid", "Spain", "Metaverse", "Oslo", "Norway", "Boulder", "CO", "DC", "Guatemala", 
         "Oregon", "Philadelphia", "Arlington", "VA", "Dubai", "United Arab Emirates", "Kraków", 
         "Munich", "Bavaria", "Panamá", "Barcelona", "Spain", "Colombia", "Dublin", "Ireland", 
         "New Orleans", "LA", "Portugal", "Southern California", "Thailand", "Zurich", "Switzerland", 
         "Екатеринбург", "Новосибирск", "СССР", "Dublin", "Ireland", "Indonesia", "Michigan", 
         "Milwaukee", "WI", "Saksa", "Colorado", "Helsinki", "Suomi", "New Haven", "CT", "Pakistan", 
         "San Jose", "CA", "Vancouver", "BC", "Virginia", "Улаанбаатар", "神奈川県", "Louisville", 
         "KY", "Norway", "Raleigh", "NC", "Saint-Petersburg", "Spain", "The Hague", "The Netherlands", 
         "Alexandria", "VA", "Berkeley", "CA", "Lagos", "Nigeria", "Latvia", "North Carolina", 
         "Rio de Janeiro", "Brazil", "Ankara", "Türkiye", "Atlanta", "Beijing", "Berliini", "Saksa", 
         "Cape Town", "South Africa", "Charlotte", "NC", "Durham", "NC", "Estonia", "Helsinki", 
         "Istanbul", "Krakova", "Puola", "LA", "Lebanon", "New Jersey", "nyc", "Sacramento", "CA", 
         "Salt Lake City", "UT", "Sverige", "Ruotsi","Almaty", "Bishkek", "Macedonia", "Skopje", "moscow","Казань", "Алматы", "Бишкек", "България", 
         "Ульяновск", "Краснодар", "Красноярск", "Тула", "St. Petersburg", "Vladivostok", "Пермь", 
         "Saint Petersburg", "Uzbekistan", "Novosibirsk", "Ufa", "Astana", "москва", "Нижний Новгород", 
         "София", "Челябинск", "Belgrad", "Serbia", "Belgrade", "Republic of Serbia", "Kazan", "Moldova", 
         "Montenegro", "Montevideo", "Uruguay", "Perm", "Vilna", "Liettua", "Владивосток", "Иваново", 
         "EU", "Milano", "Tallinna", "Viro", "Воронеж", "Мордор", "Ростов-на-Дону", "Тюмень", 
         "ישראל", "Czech Republic", "Former Yugoslav Republic", "St.Petersburg", "Budapest", "Hungary",
         "Milan", "Lombardy", "Republic of Macedonia", "Riga", "Samara", "Seoul", "Republic of Korea", 
         "Астана", "Белгород", "Владимир", "Скопје", "Тбилиси",  "Mars", "SPb", "Tyumen", "Брянск", 
         "Казахстан", "Крым", "Македонија", "Мурманск", "СПб", "Tel Aviv", "Wien", "Österreich", 
         "Казань", "Татарстан республика", "Калининград", "Петербург", "Томск", "Уфа", "Ярославль", 
         "Brno", "Czech Republic", "Neverland",  "Plovdiv", "Roma", "Siberia", "Yekaterinburg", 
         "Волгоград", "Кыргызстан", "Тверь", "Хабаровск", "대한민국 서울","Budapest", 
         "Krasnodar", "Liverpool", "Luxembourg", "München", "Bayern", "Rostov-on-Don", "spb", 
         "Tashkent", "Vilnius", "Yakutsk", "Бишкек", "Кыргызстан", "Питер", "РФ", "대한민국", 
         "Belgrade", "Serbia", "Ekaterinburg", "İstanbul", "Krasnoyarsk", "Milano", "Lombardia", 
         "Praha", "Česká republika", "Rīga", "Latvija", "Serbia", "Silicon Valley", "Uruguay", 
         "Vienna", "Владивосток", "Приморский край", "Иркутск", "Ленинград", "Магадан", 
         "Мухосранск", "Омск", "Сибирь", "спб", "Хабаровск", "Хабаровский край"
         ) %>% unique()

read_json <- function(x){
  JSON <-  jsonlite::fromJSON(txt = x, simplifyVector = F)
  
  tibble(
    created_at = JSON$users %>% map_chr("created_at") %>% lubridate::ymd_hms(),
    name = JSON$users %>% map_chr("name"),
    id = JSON$users %>% map_chr("id"),
    description = JSON$users %>% map_chr("description"),
    profile_image_url = JSON$users %>% map_chr("profile_image_url"),
    username = JSON$users %>% map_chr("username"),
    protected = JSON$users %>% map_lgl("protected"),
    verified = JSON$users %>% map_lgl("verified"),
    public_metrics = JSON$users %>% map_dfr("public_metrics"),
    location = JSON$users %>% map("location") %>% map_chr(~ifelse(is.null(.), NA, .))
  ) %>% 
    unnest("public_metrics") #%>% 
    #filter((!str_detect(location, paste0("(", paste(exc, collapse = "|"), ")"))) | is.na(location))
}

con <- dbConnect(RPostgres::Postgres(), "twitter")

dbListTables(con)

users_df <- read_json(dat$users[1])

for (i in dat$users[2:100]) {
  users_df <- bind_rows(users_df, read_json(i)) %>% distinct(id, .keep_all = T)
  cat(paste(which(dat$users == i)/nrow(dat), "\n"))
}

dbRemoveTable(con, "users")
dbCreateTable(con, "users", users_df)

user_list <- unique(users_df$id)

for (i in dat$users[101:length(dat$users)]) {
  
  us <- read_json(i)
  
  us <- us %>% filter(!(id %in% user_list)) %>% distinct(id, .keep_all = T)
  
  if (nrow(us) > 0){
    dbWriteTable(con, "users", us, append=TRUE)
    user_list <- c(user_list, us$id)
  }
  
  cat(paste(which(dat$users == i)/nrow(dat), "\n"))
}


#users_df %>% group_by(location) %>% count() %>% arrange(desc(n)) %>% head(200) %>% pull(location) %>% 
#  paste(collapse = '", "') %>% cat()
#
#
#lat_longs <- users_df %>%
#  group_by(location) %>% count() %>% arrange(desc(n)) %>% 
#  head(3600) %>% 
#  geocode(location, method = 'osm', lat = latitude , long = longitude)
#
#lat_longs <- lat_longs %>% filter(!is.na(latitude))


coords2country = function(points) {  
  countriesSP <- getMap(resolution='low')
  pointsSP = SpatialPoints(points, proj4string=CRS(proj4string(countriesSP)))  
  indices = over(pointsSP, countriesSP)
  indices$ADMIN  
}

#lat_longs$country <- coords2country(lat_longs %>% select(longitude, latitude) %>% filter(!is.na(longitude)))
#
#lat_longs %>% group_by(country) %>% summarise(n = sum(n)) %>% arrange(desc(n))
#
#users_df <- users_df %>% left_join(lat_longs, by = "location")
#
#ua <- users_df %>% filter(country == "Ukraine")
#
#po <- readr::read_csv("twitter.csv") %>% 
#  group_by(author_id) %>% count() %>% arrange(n)
#
#flt <- (po$author_id %in% as.numeric(stringr::str_remove_all(list.files("porohotweets", ".rds"), ".rds"))) == F
#
#po <- po[flt, ]
#
#authors <- as.character(unique(po$author_id))
#
#list_of_ids <- authors[authors %in% ua$id]
#
#list_of_ids <- sample(list_of_ids)
#
#write_csv(tibble(list_of_ids), "list_of_ids.csv")




