suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(DBI)
  library(odbc)
  require(dplyr)
  require(ggplot2)
  library(showtext)
  library(sf)
  library(rvest)
})

knitr::opts_chunk$set()

font_add(family = "Lato", regular = "Sys.getenv('LATO_FONT_PATH', 'Lato-Light.ttf')")

twi_selected <- readr::read_csv("~/UHDS/twi_selected.csv")

twi_sum <- twi_selected %>% 
  #filter(name == "зеленський") %>% 
  mutate(date = lubridate::round_date(created_at, unit = "month")) %>% 
  group_by(date, author_id, name) %>% 
  summarise(negative = mean(negative),
            normalized_negative = mean(normalized_negative),
            normalized_positive = mean(normalized_positive),
            positive = mean(positive)) 

def_theme <- hrbrthemes::theme_ipsum(
  base_family = "Georgia", 
  base_size = 5, plot_title_size = 8, axis_title_size = 6, subtitle_size = 7, strip_text_size = 3.5) +
  theme(
    panel.grid = element_line(linetype = "dotted", linewidth = 0.1),
    panel.spacing.y = unit(0.5, "lines")
  )


topic <- readr::read_csv("~/UHDS/topics_over_time.csv", col_types = readr::cols(), progress = F) %>% 
  mutate(Timestamp = lubridate::date(Timestamp)) %>% 
  group_by(Timestamp) %>% 
  mutate(Frequency = Frequency / sum(Frequency))

topic_leg <- readr::read_csv("~/UHDS/topic_info.csv", col_types = readr::cols(), progress = F)

topic_doc <- readr::read_csv("~/UHDS/topic_documents.csv")

tweets_sent2 <- readr::read_csv("~/UHDS/tweets_sent.csv")

pairs <- readr::read_csv("~/UHDS/pairs.csv")

con <- dbConnect(RPostgres::Postgres(), "twitter")

res <- dbSendQuery(con, "select target, type, date_trunc('day', created_at) as created_at from tweets_sent 
left join users_country on tweets_sent.author_id=users_country.id
                      where country = 'Ukraine'")

tweets_sent <- dbFetch(res)

tweets_sent <- tweets_sent %>% 
  group_by(target, type, created_at) %>% 
  count() %>% 
  ungroup() %>% 
  pivot_wider(id_cols = c("target", "type"), names_from = "created_at", 
              values_from = "n", values_fill = 0) %>% 
  pivot_longer(cols = -c("target", "type"), names_to = "date", values_to = "n") %>% 
  mutate(date = lubridate::ymd(date)) 

tweets_sent <- tweets_sent %>% 
  semi_join(
    tweets_sent %>% 
      summarise(n = sum(n), .by = c(target, type)) %>% 
      top_n(1, n) %>% 
      select(target, type), by = c("target", "type")) %>% 
  mutate(date = lubridate::round_date(date, "week", 1)) %>% 
  summarise(n = sum(n), .by = c(target, type, date)) %>% 
  arrange(date)

sup <- twi_sum %>% 
  dplyr::filter(name %in% c("Poroshenko", "Zelensky")) %>% 
  group_by(author_id, name) %>% 
  summarise(negative = mean(negative)) %>% 
  ungroup() %>% 
  tidyr::pivot_wider(id_cols = "author_id", 
                     names_from = "name", 
                     values_from = "negative") %>% 
  mutate(
    supporter = case_when(
      (Poroshenko > 0) & (Zelensky < 0) ~ "Zelensky",
      (Poroshenko < 0) & (Zelensky > 0) ~ "Poroshenko",
    )
  ) %>% dplyr::filter(!is.na(supporter)) %>% 
  select(author_id, supporter)
