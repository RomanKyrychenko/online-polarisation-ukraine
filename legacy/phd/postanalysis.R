require(dplyr)
require(stringr)
require(ggplot2)


softmax <- function(x){
  exp(x)/sum(exp(x))
}


twi_ent <- readr::read_csv("twi_named_entities_scored.csv") %>% 
  select(-text) %>% 
  bind_rows(
    readr::read_csv("twi_named_entities_scored_2.csv") %>% select(-text)
    ) %>% 
  distinct() %>% 
  left_join(
    readr::read_csv("twitter.csv") %>% 
      select(id, author_id, created_at) %>% 
      bind_rows(
        readr::read_rds("tweets_2018_2022.rds") %>% 
          select(id, author_id, created_at)
      ) %>% distinct(), by = "id"
  ) %>% 
  filter(!is.na(author_id)) %>% 
  filter(str_count(name) < 50) %>% 
  mutate(name = str_to_lower(name),
         created_at = lubridate::date(created_at)) %>% 
  mutate(
    name = case_when(
      type=="POLITICS" & str_detect(name, "зелен") ~ "Zelensky",
      type=="POLITICS" & str_detect(name, "зе$") ~ "Zelensky",
      type=="GEOPOL" & str_detect(name, "укра(и|ї)н") ~ "Ukraine",
      type=="GEOPOL" & str_detect(name, "рос") ~ "Russia",
      type=="GEOPOL" & str_detect(name, "сша") ~ "USA",
      type=="GEOPOL" & str_detect(name, "ссср") ~ "USSR",
      type=="GEOPOL" & str_detect(name, "рф$") ~ "Russia",
      type=="GEOPOL" & str_detect(name, "кр(и|ы)м") ~ "Crimea",
      type=="GEOPOL" & str_detect(name, "донбас") ~ "Donbas",
      type=="GEOPOL" & str_detect(name, "ки(е|ї)в") ~ "Kyiv",
      type=="GEOPOL" & str_detect(name, "(е|є)с$") ~ "EU",
      type=="ORG" & str_detect(name, "мвф") ~ "IMF",
      type=="ORG" & str_detect(name, "(г|д)бр") ~ "SBS",
      type=="POLITICS" & str_detect(name, "пут(і|и)н") ~ "Putin",
      type=="POLITICS" & str_detect(name, "поро") ~ "Poroshenko",
      type=="POLITICS" & str_detect(name, "трамп") ~ "Trump",
      type=="POLITICS" & str_detect(name, "лукашенк") ~ "Lukashenko",
      type=="POLITICS" & str_detect(name, "байден") ~ "Biden",
      type=="POLITICS" & str_detect(name, "тимошенк") ~ "Tymoshenko",
      type=="POLITICS" & str_detect(name, "макрон") ~ "Macron",
      type=="POLITICS" & str_detect(name, "януков") ~ "Yanukovych",
      type=="POLITICS" & str_detect(name, "ме(д|рт)ведчук") ~ "Medvedchuk",
      type=="POLITICS" & str_detect(name, "аваков") ~ "Avakov",
      type=="SOCGROUPS" & str_detect(name, "укра(ї|и)нц") ~ "ukrainians",
      type=="POLSTATUS" & str_detect(name, "президент(|а|у|ом) рф") ~ "President of Russia",
      type=="POLSTATUS" & str_detect(name, "президент(|а|у|ом) рос") ~ "President of Russia",
      type=="POLSTATUS" & str_detect(name, "президент(|а|у|ом) сша") ~ "POTUS",
      type=="POLSTATUS" & str_detect(name, "президент(|а|у|ом) укра(ї|и)н") ~ "President of Ukraine",
      TRUE ~ name
    )
  ) %>% filter(name %in% c("Poroshenko", "Zelensky", "Putin", 
                     "Ukraine", "Russia", "Trump", "USA", "Biden", 
                     "Lukashenko", 
                     "ukrainians", "Donbas", 
                     "POTUS", "Medvedchuk", "Crimea", "Yanukovych", 
                     "President of Ukraine", "Tymoshenko", 
                     "President of Russia", "Avakov", "EU", 
                     "USSR", "SBS",  "Kyiv", "IMF"))

sent_norm <- apply(twi_ent %>% 
                     select(negative, neutral, positive), 1, softmax) %>% 
  t() %>% as_tibble()

twi_ent <- twi_ent %>% bind_cols(
  sent_norm %>% rename(normalized_negative=negative, 
                     normalized_neutral=neutral,
                     normalized_positive=positive))

readr::write_csv(twi_ent, "twi_selected.csv")
