library(rjson)
library(dplyr)


fd <- fs::dir_info("porohodata") %>% 
  filter(stringr::str_detect(path, "data_")) %>% 
  filter(size > 3) %>% 
  arrange(desc(size))

td <- fd$path

ch <- split(td, ceiling(seq_along(td)/2000))

res <- list()

for (d in ch) {
  json_data <- purrr::map_dfr(d, function(f) {
    jsonlite::read_json(f, simplifyVector = TRUE) %>% 
      select(-one_of("attachments"), -one_of("withheld")) %>% 
      tidyr::unnest("public_metrics") %>% 
      mutate(
        edit_history_tweet_ids = as.numeric(edit_history_tweet_ids),
        conversation_id = as.numeric(conversation_id),
        author_id = as.numeric(author_id),
        id = as.numeric(id),
        created_at = lubridate::ymd_hms(created_at)
      )
  })
  
  json_data <- json_data %>% 
    tidyr::unnest("entities") %>% 
    tidyr::unnest("geo") %>% 
    mutate(
      urls = urls %>% purrr::map("url") %>% purrr::map_chr(~ifelse(is.null(.), NA, .)),
      mentions = mentions %>% purrr::map("id"),
      hashtags = hashtags %>% purrr::map("tag"),
      coordinates = coordinates$coordinates,
      referenced_type = referenced_tweets %>% purrr::map("type"),
      referenced_id = referenced_tweets %>% purrr::map("id")
    ) %>% 
    select(-referenced_tweets) %>% 
    #mutate_if(~purrr::vec_depth(.)==2, function(x){
    #  x[sapply(x, is.null)] <- NA
    #  unlist(x, use.names = FALSE)
    #}) %>% 
    mutate_if(~purrr::vec_depth(.)>2, function(x){
      purrr::map(x, function(y){
        if (is.null(unlist(y))){
          return(NA)
        } else {
          return(y)
        }
      })})
  
  print(nrow(res))
  
  res <- c(res, list(json_data))
}

res <- tibble(bind_rows(res)) %>% select(-cashtags) %>% 
  mutate(
    place_id = as.numeric(place_id),
    in_reply_to_user_id = as.numeric(in_reply_to_user_id)
  ) %>% select(-place_id) %>% 
  mutate(
    long = purrr::map_dbl(tweets$coordinates, ~ifelse(purrr::is_empty(.), NA, .[1])),
    lat = purrr::map_dbl(tweets$coordinates, ~ifelse(purrr::is_empty(.), NA, .[2]))
  ) %>% select(-coordinates)


readr::write_rds(res, "tweets_2018_2022.rds")
