require(dplyr)

coded <- purrr::map_dfr(
  list.files("Data coded", full.names = T), 
  readxl::read_excel) %>% 
  filter(stringr::str_count(text) < 500) %>% 
  select(text, POLITICS, PARTIES, GEOPOL, ORG, GEOPHYS, SOCGROUPS, POLGROUPS, POLSTATUS)

coded$POLITICS <- stringr::str_split(coded$POLITICS, ";") %>% 
  purrr::map(stringr::str_squish) %>% 
  purrr::map(~.[.!=""])

coded$PARTIES <- stringr::str_split(coded$PARTIES, ";") %>% 
  purrr::map(stringr::str_squish) %>% 
  purrr::map(~.[.!=""])

coded$GEOPOL <- stringr::str_split(coded$GEOPOL, ";") %>% 
  purrr::map(stringr::str_squish) %>% 
  purrr::map(~.[.!=""])

coded$ORG <- stringr::str_split(coded$ORG, ";") %>% 
  purrr::map(stringr::str_squish) %>% 
  purrr::map(~.[.!=""])

coded$GEOPHYS <- stringr::str_split(coded$GEOPHYS, ";") %>% 
  purrr::map(stringr::str_squish) %>% 
  purrr::map(~.[.!=""])

coded$SOCGROUPS <- stringr::str_split(coded$SOCGROUPS, ";") %>% 
  purrr::map(stringr::str_squish) %>% 
  purrr::map(~.[.!=""])

coded$POLGROUPS <- stringr::str_split(coded$POLGROUPS, ";") %>% 
  purrr::map(stringr::str_squish) %>% 
  purrr::map(~.[.!=""])

coded$POLSTATUS <- stringr::str_split(coded$POLSTATUS, ";") %>% 
  purrr::map(stringr::str_squish) %>% 
  purrr::map(~.[.!=""])

named_entity <- coded %>% tidyr::pivot_longer(POLITICS:POLSTATUS) %>% 
  tidyr::unnest("value") %>% 
  filter(!is.na(value)) %>% 
  filter(!stringr::str_detect(value, "Володимир Зеленський - клоун, Володимир Путін")) %>% 
  filter(!stringr::str_detect(value, "Зеленский\\)")) %>% 
  filter(!stringr::str_detect(value, "зеленского\\)")) %>% 
  filter(!stringr::str_detect(value, "парашенка\\)")) %>% 
  mutate(
    loc = purrr::map(stringr::str_locate_all(pattern = value, text), as_tibble),
    loc = purrr::map2(loc, name, ~.x %>% mutate(type = .y))
  ) %>% group_by(text) %>% 
  summarise(loc = bind_rows(loc)) %>% 
  tidyr::unnest("loc") %>% 
  mutate(
    start = start - 1,
    end = end - 1
  )

readr::write_csv(named_entity, "named_entity_dataset.csv")

