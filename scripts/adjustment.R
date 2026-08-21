# Load necessary libraries
library(dplyr)
library(ggplot2)
library(tidyr)
library(DBI)


dbicon  <-  DBI::dbConnect( 
  #odbc::odbc(),
  RPostgres::Postgres(),
  #driver = "PostgreSQL Unicode", 
  dbname = "twitter", 
  host = "18.225.7.125", 
  port = "5432", 
  user = "propaganda_tutkija",
  password = Sys.getenv('PGPASSWORD')|p)urra.")

dbGetQuery(dbicon, "select count(*) from entities_sentiment")

oli <- dbGetQuery(dbicon, "select * from tweet_sentiment_apc")

oli <- oli %>% as_tibble()

oli %>% 
  readr::write_csv("data/tweet_sentiment_apc.csv")

dbGetQuery(dbicon, "DELETE FROM tweet_sentiment_apc
WHERE target = 'Minsk';")

dbGetQuery(dbicon, "DELETE FROM tweet_sentiment_apc a
USING tweet_sentiment_apc b
WHERE a.ctid > b.ctid
AND a.id = b.id
AND a.target = b.target
AND a.author_id = b.author_id;")


dbGetQuery(dbicon, "select count(*) from tweet_sentiment_apc")

name_stats <- dbGetQuery(
  dbicon,
  "
  SELECT
    target,
    AVG(negative) AS negative,
    AVG(positive) AS positive,
    COUNT(DISTINCT author_id) AS author_count
  FROM (
    SELECT
      author_id,
      target,
      AVG(negative) AS negative,
      AVG(positive) AS positive
    FROM tweet_sentiment_apc
    GROUP BY target, author_id
  ) AS t
  GROUP BY target
  "
)

name_stats$polar <- name_stats$negative + name_stats$positive

name_stats$polar_s <- name_stats$negative * name_stats$positive

zepo <- dbGetQuery(dbicon, "select * from tweet_sentiment_apc where target in ('Zelenskyy', 'Poroshenko')")

political_groups <- zepo %>% 
  mutate(combined_sentiment = positive + neutral) %>%
  group_by(author_id, target) %>%
  mutate(n = n()) %>% 
  ungroup() %>% 
  filter(n > 2) %>% 
  group_by(author_id) %>%
  mutate(n = n_distinct(target)) %>% 
  ungroup() %>% 
  filter(n == 2) %>% 
  group_by(author_id) %>%
  do(broom::tidy(t.test(combined_sentiment ~ target, data = .))) %>% 
  ungroup()  %>% 
  ungroup() %>% 
  filter(p.value < 0.05) %>% 
  mutate(
    political_group = case_when(
      estimate1 > 0.5 & (estimate1 > estimate2) ~ "Poroshenko Supporter",
      estimate2 > 0.5 & (estimate2 > estimate1) ~ "Zelenskyy Supporter",
      T ~ "Other"
    )
  )


topic_sentiments <- dbGetQuery(dbicon, "
SELECT 
    ts.id, 
    ts.target,
    ts.negative, 
    ts.neutral, 
    ts.positive, 
    tt.topic_id, 
    t.author_id, 
    DATE(t.created_at) AS created_date,
    uc.country,
    b.prob_bot
FROM tweets_sent ts
LEFT JOIN (
    SELECT tweet_id, topic_id 
    FROM tweet_topics
) tt 
    ON ts.id::text = tt.tweet_id::text
LEFT JOIN tweets t 
    ON ts.id::text = t.id
LEFT JOIN users_country uc 
    ON t.author_id = uc.id
LEFT JOIN bots b 
    ON t.author_id = b.user_id;
") %>% as_tibble()

softmax <- function(x) {
  exp_x <- exp(x - max(x))  # for numerical stability
  exp_x / sum(exp_x)
}

topic_sentiments <- topic_sentiments %>%
  distinct() %>% 
  rowwise() %>%
  mutate(
    softmax_values = list(softmax(c(negative, neutral, positive))),
    negative = softmax_values[[1]][1],
    neutral  = softmax_values[[2]][1],
    positive = softmax_values[[3]][1]
  ) %>%
  select(-softmax_values) 

def_theme <- hrbrthemes::theme_ipsum(
  base_family = "Georgia", base_size = rel(2), 
  plot_title_size = rel(2), axis_title_size = rel(2), subtitle_size = rel(2), strip_text_size = rel(2)) +
  theme(
    panel.grid = element_line(linetype = "dotted", linewidth = 0.1),
    panel.spacing.y = unit(0.0, "lines"),
    panel.spacing.x = unit(0.5, "lines"),
    plot.margin = margin(0, 0, 0, 0),
    axis.text = element_text(size = rel(0.5)), 
    axis.title.x = element_text(size = rel(0.8), face = "bold", margin = margin(t = 5, r = 0, b = 0, l = 0)),
    axis.title.y = element_text(size = rel(0.8), face = "bold", margin = margin(t = 0, r = 5, b = 0, l = 0)),
    legend.title = element_text(size = rel(1)),
    legend.position = "bottom",
    legend.text = element_text(size = rel(1.5)),
    legend.spacing.x = unit(2.0, 'cm'),
    legend.spacing.y = unit(2.0, 'cm'),
    legend.key.size = unit(0.5, "cm"),
  )

twi_selected <- readr::read_csv("~/UHDS/twi_selected.csv", col_types = readr::cols(), progress = F)
twi_sentiments <- readr::read_csv("~/UHDS/tweets_sent.csv", col_types = readr::cols(), progress = F)
# --- 1. Identify Political Groups ---
# The document states: "Users are classified as Zelensky supporters if their average sentiment toward Zelensky exceeds their sentiment toward Poroshenko by a specified threshold, and vice versa for Poroshenko supporters."
# We need to calculate average sentiment for each author_id towards Zelensky and Poroshenko.
# The `twi_selected` dataframe contains `name` (Zelensky/Poroshenko) and sentiment scores.

# Calculate average sentiment for each author towards Zelensky and Poroshenko
#author_sentiment_summary <- twi_selected %>%
#  filter(name %in% c("Zelensky", "Poroshenko")) %>%
#  group_by(author_id, name) %>%
#  summarise(
#    avg_negative = mean(normalized_negative, na.rm = TRUE),
#    avg_neutral = mean(normalized_neutral, na.rm = TRUE),
#    avg_positive = mean(normalized_positive, na.rm = TRUE),
#    .groups = "drop"
#  )
#
## Reshape to wide format for easier comparison
#author_sentiment_wide <- author_sentiment_summary %>%
#  pivot_wider(
#    names_from = name,
#    values_from = c(avg_negative, avg_neutral, avg_positive)
#  )

# Define a threshold for classification. The document doesn’t specify, so we’ll use a placeholder.
# A simple approach: if avg_positive_Zelensky > avg_positive_Poroshenko + threshold, then Zelensky supporter.
# And vice versa. For now, let’s use a simple difference in positive sentiment.
# A more robust approach might involve a combined sentiment score (e.g., positive - negative).
# Let’s use a simple difference in positive sentiment for initial classification.

# For simplicity, let’s define ‘sentiment’ as normalized_positive - normalized_negative
# Recalculate author_sentiment_summary with a combined sentiment score
#author_sentiment_summary_combined <- twi_selected %>%
#  filter(name %in% c("Zelensky", "Poroshenko")) %>%
#  mutate(combined_sentiment = normalized_positive - normalized_negative) %>%
#  group_by(author_id, name) %>%
#  summarise(
#    avg_combined_sentiment = median(combined_sentiment, na.rm = TRUE),
#    .groups = "drop"
#  )
#
#author_sentiment_wide_combined <- author_sentiment_summary_combined %>%
#  pivot_wider(
#    names_from = name,
#    values_from = avg_combined_sentiment
#  )

# Classify supporters based on the combined sentiment difference
# Let’s use a threshold of 0.1 for demonstration. This can be adjusted.
#classification_threshold <- 0.05

#political_groups <- author_sentiment_wide_combined %>%
#  mutate(political_group = case_when(
#    (Zelensky > 0) & (Zelensky > Poroshenko) ~ "Zelensky_Supporter",
#    (Poroshenko > 0) & (Poroshenko > Zelensky) ~ "Poroshenko_Supporter",
#    TRUE ~ "Neutral_or_Unclassified" # Users not clearly aligned
#  )) %>%
#  select(author_id, political_group)

political_groups <- twi_selected %>%
  filter(name %in% c("Zelensky", "Poroshenko")) %>%
  mutate(combined_sentiment = normalized_positive + normalized_neutral) %>%
  group_by(author_id, name) %>%
  mutate(n = n()) %>% 
  ungroup() %>% 
  filter(n > 2) %>% 
  group_by(author_id) %>%
  mutate(n = n_distinct(name)) %>% 
  ungroup() %>% 
  filter(n == 2) %>% 
  group_by(author_id) %>%
  do(broom::tidy(t.test(combined_sentiment ~ name, data = .))) %>% 
  ungroup() %>% 
  filter(p.value < 0.05) %>% 
  mutate(
    political_group = case_when(
      estimate1 > 0.5 & (estimate1 > estimate2) ~ "Poroshenko Supporter",
      estimate2 > 0.5 & (estimate2 > estimate1) ~ "Zelenskyy Supporter",
      T ~ "Other"
    )
  )
  

print("Political Groups before filtering:")
political_groups %>% group_by(political_group) %>% count() 

# Filter out neutral/unclassified for opinion adjustment analysis
political_groups_filtered <- political_groups %>%
  filter(political_group %in% c("Zelenskyy Supporter", "Poroshenko Supporter"))

print("Political Groups after filtering:")
print(political_groups_filtered)

# --- 2. Analyze Sentiment Patterns Across Secondary Topics ---
# Join topic_sentiments with political_groups to get sentiment by group and topic
# topic_sentiments has ‘id’ (tweet id) and ‘topic_id’, and sentiment scores.
# We need to link tweets to authors to get their political group.
# twi_selected has ‘id’ (tweet id) and ‘author_id’.

# First, join twi_selected with topic_sentiments to get topic_id for each tweet with sentiment
#tweet_topic_sentiment <- twi_selected %>%
#  select(id, author_id) %>%
#  mutate(id = as.character(id), author_id = as.character(author_id)) %>% # Ensure id is character for joining
#  inner_join(topic_sentiments, by = c("author_id", "id"))

# Now, join with political_groups to get the political group for each tweet
tweet_topic_sentiment_grouped <- oli %>% #topic_sentiments %>%
  inner_join(political_groups_filtered, by = "author_id") #%>% mutate(author_id = as.character(author_id)), by = "author_id")

diff_sign <- tweet_topic_sentiment_grouped %>% 
  group_by(author_id, political_group, target) %>% 
  summarise(avg_topic_sentiment = mean(positive + neutral, na.rm = TRUE),
            .groups = "drop") %>% 
  group_by(target) %>% 
  do(broom::tidy(t.test(avg_topic_sentiment ~ political_group, data = .))) %>% 
  select(target, p.value)


g <- tweet_topic_sentiment_grouped %>% 
  filter(!(target %in% c("EuropeanSolidarity", "Moroz", "Shokin", "Symonenko", "Johnson&Johnson", "Batkivshchyna", 
                         "eGovernment", "Syrskyy", "Concession", "Nash", "IT", "Budget", "Taxes", "Coal",
                         "Euro", "Dollar", "GDP", "Pension", "OilSector", "Agriculture", "Banking", "Customs",
                         "Education", "EnergySector", "Inflation", "Hryvnia", "Railways", "Reconstruction", "Yandex",
                         "NuclearPower", "Odnoklassniki", "VKontakte", "Facebook", "Instagram", "GasSector",
                         "YouTube", "TikTok", "Zeleboty", "USSR", "Kremlebots", "Porokhoboty", "Budanov",
                         "Surkis", "Johnson", "Venice", "Telegram", "Healthcare", "Lutsenko", "Javelin",
                         "Kostin", "Steinmeier", "Kyiv", "Sanctions", "Prigozhin", "Moderna", "AstraZeneca",
                         "MilitaryAid", "FinancialAid", "Victory", "CouncilOfEurope", "Lyashko", "Kobolev",
                         "Vitrenko", "Humanitarian", "Kholodnitsky", "Rabinovich", "Boyko", "Sytnik", "Venediktova",
                         "Saakashvili", "Turchynov", "Yatsenyuk", "Parubiy", "Groysman", "Pashinsky", "Arestovych",
                         "DTEK", "Burisma", "Ukrenergo", "Smeshko", "Erdogan", "WTO", "POTUS",
                         "WarCrimes", "Duma", "Shoigu", "Peskov"))) %>% 
  group_by(author_id, political_group, target) %>% 
  summarise(avg_topic_sentiment = mean(positive + neutral, na.rm = TRUE),
            .groups = "drop") %>% 
  group_by(target, political_group) %>% 
  do(broom::tidy(t.test(.$avg_topic_sentiment)))  %>% 
  select(-p.value) %>% 
  mutate(conf.high = ifelse(conf.high > 1, 1, conf.high)) %>% 
  left_join(diff_sign, by = "target") %>%
  mutate(topic = case_when(
    target %in% c("WarCrimes", "War", "SteinmeierFormula", "Separatists", "Crimea", "Donbas", "ORDLO", "DPR", "LPR", "Novorossiya", "Normandy", "Minsk") ~ "War in Donbas",
    target %in% c("Kuleba", "Erdogan", "POTUS", "WTO", "UN", "G7", "Trump", "Biden", "USA", "EU", "NATO", "Poland", "Germany", "France", "Turkey", "Belarus", "China", "Macron", "Merkel", "Lukashenko", "OSCE") ~ "International relations",
    target %in% c("Diia", "IMF", "Land", "Reforms", "Privatization", "Privatbank", "Naftogaz", "DTEK", "Ukrposhta", "Ukrzaliznytsia", "Ukrenergo", "Energoatom", "Burisma") ~ "Economic and political reforms",
    target %in% c("Deoligarchization", "Oligrarkhs", "Medvedchuk", "Akhmetov", "Kolomoisky", "Pinchuk", "Firtash") ~ "Oligarchs",
    target %in% c("COVID19", "Vaccine", "Masks", "Pfizer", "Lockdowns", "SputnikV", "Moderna", "AstraZeneca", "Stepanov", "Liashko", "Suprun", "Johnson&Johnson")~ "COVID-19 pandemic",
    target %in% c("Fedorov", "Stefanchuk", "Arakhamia", "Danilov", "Bogdan", "Yermak", "Shariy", "Razumkov", "Goncharuk", "Shmyhal", "Elections", "Zelenskyy", "Poroshenko", "Tymoshenko", "PresidentOfUkraine", "Smeshko", "Vakarchuk") ~ "Political competition",
    target %in% c("Anticorrupcioners", "NAPC", "NABU", "SAP", "Soros") ~ "Anti-corruption agenda",
    target %in% c("Kuchma", "Kravchuk", "Yushchenko", "Yanukovych") ~ "Former presidents of Ukraine",
    target %in% c("Gazprom", "Russia", "Shoigu", "Medvedev", "FSB", "Kadyrov", "Kremlin", "Lavrov", "Putin", "Peskov", "Wagner", "Duma", "RussianArmy", "RussianLanguage", "Russians", "Navalny") ~ "Russia",
    target %in% c("Reznikov", "Avakov", "Azov", "DBR", "Zaluzhny", "Police", "AFU", "SBU", "GUR", "NationalGuard", "MVS") ~ "Army and police",
    target %in% c("PoliticalParties", "Rada", "Parties", "EuropeanSolidarity", "ServantOfThePeople", "Holos", "ShariyParty", "Batkivshchyna", "OPZZh") ~ "Political parties",
    target %in% c("Usyk", "Lomachenko", "Shakhtar", "DynamoKyiv") ~ "Sport",
    #target %in% c("NBU", "CEC", "Media", "Maidan", "GovernmentOfUkraine", "Court") ~ "Institutions",
    target %in% c("KyivPatriarchate", "Tomos", "Church", "OCU", "MoscowPatriarchate") ~ "Church", 
    target %in% c("1+1", "5Channel", "Inter", "ICTV", "Ukraine24" ) ~ "TV-Channels",
    target %in% c("Klychko", "Vilkul", "Kernes", "Trukhanov", "Terekhov", "Filatov") ~ "Mayors",
    T ~ "Miscellaneous"
  )) %>% 
  mutate(target = case_when(
    p.value < 0.001 ~ paste0(target, "***"),
    p.value < 0.01 ~ paste0(target, "**"),
    p.value < 0.05 ~ paste0(target, "*"),
    T ~ target
  )) %>% 
  mutate(across(topic, ~factor(., levels=c(
    "Political competition", "International relations", 
    "COVID-19 pandemic", "War in Donbas",
    "Army and police", "Russia",
    "Anti-corruption agenda", "Church", 
    "Economic and political reforms", "Miscellaneous",
    "Political parties", "Oligarchs",
    "Mayors", "TV-Channels",
    "Former presidents of Ukraine", "Sport"
    )
    )
    )
    ) %>% 
  ggplot(aes(estimate, reorder(target, desc(estimate)), shape = political_group, group = political_group)) +
  geom_point(size = 1) +
  geom_errorbar(aes(xmin = conf.low, xmax = conf.high)) +
  scale_shape(guide = guide_legend(title = "", byrow = TRUE)) +
  xlab("Positive + Neutral sentiment") +
  ylab("Target topic") +
  labs(caption = "p.values for differences between groups: *** - < 0.001, ** - < 0.01, * - < 0.05") +
  def_theme +
  theme(
    plot.caption = element_text(size = rel(3)),
    strip.text = element_text(face = "bold", size = rel(2)),
    legend.text = element_text(size = rel(2), margin = margin(r = 30, unit = "pt")),
    legend.spacing.x = unit(2.0, 'cm')
    ) +
  facet_wrap(~topic, ncol = 2, scales = "free_y") +
  ggh4x::force_panelsizes(rows = c(17, 10, 12, 5, 10, 7, 5, 4))

ggplot2latex::save_tex(g, "../visualisations/avg_topic_sentiment_by_group.tex", width = 6.9, height = 9)


time_stat <- tweet_topic_sentiment_grouped %>% 
  filter(!(target %in% c("EuropeanSolidarity", "Moroz", "Shokin", "Symonenko", "Johnson&Johnson", "Batkivshchyna", 
                         "eGovernment", "Syrskyy", "Concession", "Nash", "IT", "Budget", "Taxes", "Coal",
                         "Euro", "Dollar", "GDP", "Pension", "OilSector", "Agriculture", "Banking", "Customs",
                         "Education", "EnergySector", "Inflation", "Hryvnia", "Railways", "Reconstruction", "Yandex",
                         "NuclearPower", "Odnoklassniki", "VKontakte", "Facebook", "Instagram", "GasSector",
                         "YouTube", "TikTok", "Zeleboty", "USSR", "Kremlebots", "Porokhoboty", "Budanov",
                         "Surkis", "Johnson", "Venice", "Telegram", "Healthcare", "Lutsenko", "Javelin",
                         "Kostin", "Steinmeier", "Kyiv", "Sanctions", "Prigozhin", "Moderna", "AstraZeneca",
                         "MilitaryAid", "FinancialAid", "Victory", "CouncilOfEurope", "Lyashko", "Kobolev",
                         "Vitrenko", "Humanitarian", "Kholodnitsky", "Rabinovich", "Boyko", "Sytnik", "Venediktova",
                         "Saakashvili", "Turchynov", "Yatsenyuk", "Parubiy", "Groysman", "Pashinsky", "Arestovych",
                         "DTEK", "Burisma", "Ukrenergo", "Smeshko", "Erdogan", "WTO", "POTUS",
                         "WarCrimes", "Duma", "Shoigu", "Peskov"))) %>% 
  mutate(date = lubridate::round_date(date, "month")) %>% 
  group_by(author_id, political_group, target, date) %>% 
  summarise(avg_topic_sentiment = mean(positive + neutral, na.rm = TRUE),
            .groups = "drop") %>% 
  ungroup() %>% 
  group_by(author_id, target) %>%
  arrange(author_id, target, date) %>%
  mutate(avg_topic_sentiment = slider::slide_dbl(avg_topic_sentiment, mean, .before = 1, .after = 0)) %>%
  ungroup() 

time_stat <- time_stat %>% group_by(author_id, political_group, target) %>% 
  summarise(
    date = list(seq(lubridate::ymd("2018-12-01"), lubridate::ymd("2022-02-01"), by = "month")),
    .groups = "drop"
  ) %>%
  unnest(date) %>% 
  left_join(
    time_stat, by = c("date", "author_id", "political_group", "target")
  )

time_stat <- time_stat %>% 
  group_by(author_id, political_group, target) %>% 
  tidyr::fill(avg_topic_sentiment, .direction = "updown") %>% 
  ungroup()

time_stat <- time_stat %>% 
  group_by(target, political_group, date) %>% 
  mutate(n = n()) %>% 
  filter(n >= 2) %>% 
  do(broom::tidy(t.test(.$avg_topic_sentiment)))  %>% 
  #select(-p.value) %>% 
  mutate(conf.high = ifelse(conf.high > 1, 1, conf.high)) %>% 
  #left_join(diff_sign, by = "target") %>%
  mutate(topic = case_when(
    target %in% c("WarCrimes", "War", "SteinmeierFormula", "Separatists", "Crimea", "Donbas", "ORDLO", "DPR", "LPR", "Novorossiya", "Normandy", "Minsk") ~ "War in Donbas",
    target %in% c("Kuleba", "Erdogan", "POTUS", "WTO", "UN", "G7", "Trump", "Biden", "USA", "EU", "NATO", "Poland", "Germany", "France", "Turkey", "Belarus", "China", "Macron", "Merkel", "Lukashenko", "OSCE") ~ "International relations",
    target %in% c("Diia", "IMF", "Land", "Reforms", "Privatization", "Privatbank", "Naftogaz", "DTEK", "Ukrposhta", "Ukrzaliznytsia", "Ukrenergo", "Energoatom", "Burisma") ~ "Economic and political reforms",
    target %in% c("Deoligarchization", "Oligrarkhs", "Medvedchuk", "Akhmetov", "Kolomoisky", "Pinchuk", "Firtash") ~ "Oligarchs",
    target %in% c("COVID19", "Vaccine", "Masks", "Pfizer", "Lockdowns", "SputnikV", "Moderna", "AstraZeneca", "Stepanov", "Liashko", "Suprun", "Johnson&Johnson")~ "COVID-19 pandemic",
    target %in% c("Fedorov", "Stefanchuk", "Arakhamia", "Danilov", "Bogdan", "Yermak", "Shariy", "Razumkov", "Goncharuk", "Shmyhal", "Elections", "Zelenskyy", "Poroshenko", "Tymoshenko", "PresidentOfUkraine", "Smeshko", "Vakarchuk") ~ "Political competition",
    target %in% c("Anticorrupcioners", "NAPC", "NABU", "SAP", "Soros") ~ "Anti-corruption agenda",
    target %in% c("Kuchma", "Kravchuk", "Yushchenko", "Yanukovych") ~ "Former presidents of Ukraine",
    target %in% c("Gazprom", "Russia", "Shoigu", "Medvedev", "FSB", "Kadyrov", "Kremlin", "Lavrov", "Putin", "Peskov", "Wagner", "Duma", "RussianArmy", "RussianLanguage", "Russians", "Navalny") ~ "Russia",
    target %in% c("Reznikov", "Avakov", "Azov", "DBR", "Zaluzhny", "Police", "AFU", "SBU", "GUR", "NationalGuard", "MVS") ~ "Army and police",
    target %in% c("PoliticalParties", "Rada", "Parties", "EuropeanSolidarity", "ServantOfThePeople", "Holos", "ShariyParty", "Batkivshchyna", "OPZZh") ~ "Political parties",
    target %in% c("Usyk", "Lomachenko", "Shakhtar", "DynamoKyiv") ~ "Sport",
    #target %in% c("NBU", "CEC", "Media", "Maidan", "GovernmentOfUkraine", "Court") ~ "Institutions",
    target %in% c("KyivPatriarchate", "Tomos", "Church", "OCU", "MoscowPatriarchate") ~ "Church", 
    target %in% c("1+1", "5Channel", "Inter", "ICTV", "Ukraine24" ) ~ "TV-Channels",
    target %in% c("Klychko", "Vilkul", "Kernes", "Trukhanov", "Terekhov", "Filatov") ~ "Mayors",
    T ~ "Miscellaneous"
  )) %>% 
  #mutate(target = case_when(
  #  p.value < 0.001 ~ paste0(target, "***"),
  #  p.value < 0.01 ~ paste0(target, "**"),
  #  p.value < 0.05 ~ paste0(target, "*"),
  #  T ~ target
  #)) %>% 
  mutate(across(topic, ~factor(., levels=c(
    "Political competition", "International relations", 
    "COVID-19 pandemic", "War in Donbas",
    "Army and police", "Russia",
    "Anti-corruption agenda", "Church", 
    "Economic and political reforms", "Miscellaneous",
    "Political parties", "Oligarchs",
    "Mayors", "TV-Channels",
    "Former presidents of Ukraine", "Sport"
  )
  )
  )
  ) 


time_stat %>% 
  ungroup() %>% 
  filter(p.value < 0.001) %>% 
  group_by(target) %>% 
  mutate(n = n()) %>% 
  filter(n >= 78) %>% 
  tidyr::pivot_wider(id_cols = c(target, date), names_from = political_group, values_from = estimate) %>% 
  mutate(diff = `Zelenskyy Supporter` - `Poroshenko Supporter`) %>% 
  tidyr::pivot_wider(id_cols = date, names_from = target, values_from = diff) %>% 
  select_if(is.numeric) %>% cor() %>% as_tibble(rownames="target") %>% 
  tidyr::pivot_longer(names_to = "target2", cols = -target) %>% 
  filter(value != 1) %>% 
  arrange(desc(value))

time_stat <- time_stat %>% 
  ungroup() %>% 
  filter(p.value < 0.001) %>% 
  group_by(target) %>% 
  mutate(n = n()) %>% 
  filter(n >= 78) %>% 
  filter(target %in% diff_sign$target[diff_sign$p.value < 0.001]) %>% 
  filter(target != "Zelenskyy") %>% 
  filter(target != "Poroshenko") %>% 
  tidyr::pivot_wider(id_cols = c(target, date), names_from = political_group, values_from = estimate) %>% 
  mutate(diff = `Zelenskyy Supporter` - `Poroshenko Supporter`) %>% 
  select(target, date, diff)

library(directlabels)

g <- time_stat %>% 
  bind_rows(
    time_stat %>% 
      group_by(date) %>% summarise(diff=mean(diff)) %>% 
      mutate(target = "AVG")
  ) %>% 
  filter(!(target %in% c("Vakarchuk", "Reznikov", "Germany", "NationalGuard", "Klychko", "MVS", 
                         "COVID19", "Kuleba", "PresidentOfUkraine", "OSCE", "POTUS", "Kuchma",
                         "Elections", "Naftogaz", "Turkey", "Trump", "Privatbank", "Avakov"))) %>% 
  ggplot(aes(date, diff, group = target)) +
  geom_dl(aes(label = target), method = list(dl.combine("first.points", "last.points"), cex = 0.3)) +
  geom_path(aes(alpha = target == "AVG"), size = rel(0.5)) +
  scale_y_continuous(limits = c(0, 0.17)) +
  xlab("Positive + Neutral sentiment") +
  ylab("Target topic") +
  def_theme +
  theme(
    plot.caption = element_text(size = rel(3)),
    strip.text = element_text(face = "bold", size = rel(2)),
    legend.text = element_text(size = rel(2), margin = margin(r = 30, unit = "pt")),
    legend.spacing.x = unit(2.0, 'cm'),
    legend.position = "none"
  ) 

ggplot2latex::save_tex(g, "../visualisations/avg_topic_sentiment_by_group_dynamic.tex", width = 6, height = 9)


time_stat %>% 
  group_by(date) %>% summarise(diff=mean(diff)) %>% 
  ggplot(aes(date, diff)) +
  geom_path() +
  #scale_y_continuous(limits = c(0, 0.17)) +
  xlab("Positive + Neutral sentiment") +
  ylab("Target topic") +
  def_theme +
  theme(
    plot.caption = element_text(size = rel(3)),
    strip.text = element_text(face = "bold", size = rel(2)),
    legend.text = element_text(size = rel(2), margin = margin(r = 30, unit = "pt")),
    legend.spacing.x = unit(2.0, 'cm')
  ) 

tweet_topic_sentiment_grouped %>% 
  group_by(author_id, political_group, target) %>% 
  summarise(avg_topic_sentiment = mean(positive - negative, na.rm = T)) %>% 
  group_by(political_group, target) %>% 
  summarise(avg_topic_sentiment = mean(avg_topic_sentiment, na.rm = T)) %>% 
  ggplot(aes(avg_topic_sentiment, target, shape = political_group)) +
  geom_point(size = 5, guide = guide_legend(title = "")) +
  xlab("Positive + Neutral sentiment") +
  ylab("Target topic") +
  labs(caption = "p.values for differences between groups: *** - < 0.001, ** - < 0.01, * - < 0.05") +
  def_theme


# Calculate average sentiment for each political group per topic
# Using normalized_positive - normalized_negative as a general sentiment score for topics
# Note: topic_sentiments has ‘negative’, ‘neutral’, ‘positive’ directly. Let’s use these.
# The document implies using sentiment towards topics, not normalized sentiment from twi_selected.
# Let’s use (positive - negative) from topic_sentiments as the topic sentiment score.

topic_sentiment_by_group <- tweet_topic_sentiment_grouped %>%
  mutate(topic_sentiment_score = positive + neutral - negative) %>%
  group_by(political_group, target) %>%
  summarise(
    avg_topic_sentiment = mean(topic_sentiment_score, na.rm = TRUE),
    n = n(), # Count of tweets per topic and group
    .groups = "drop"
  )

# Add topic names for better readability
#topic_sentiment_by_group <- topic_sentiment_by_group %>%
#  left_join(topics %>% select(topic_id, topic_name), by = "topic_id")

# --- 3. Visualizations ---
# Bar plot of average sentiment per topic for each political group

# Filter out topic_id -1 if it’s a general category or not relevant for specific topic analysis
topic_sentiment_by_group_filtered <- topic_sentiment_by_group %>%
  distinct(political_group, target, .keep_all = TRUE) %>% 
  filter(n > 100) %>% # Filter out topics with very few tweets to ensure reliability)
  select(-n)

# Order topics by sentiment difference for better visualization of polarization
sentiment_diff <- topic_sentiment_by_group_filtered %>%
  pivot_wider(names_from = political_group, values_from = avg_topic_sentiment)

print("Sentiment Difference Dataframe:")
print(sentiment_diff)

sentiment_diff <- sentiment_diff %>%
  mutate(sentiment_difference = `Zelenskyy Supporter` - `Poroshenko Supporter`) %>%
  arrange(abs(sentiment_difference)) %>% 
  distinct(target, .keep_all = TRUE)

#ordered_topics <- sentiment_diff$topic_name

#topic_sentiment_by_group_filtered$topic_name <- factor(topic_sentiment_by_group_filtered$topic_name, levels = ordered_topics)

# Visualization 1: Bar plot of average topic sentiment by political group
g <- ggplot(topic_sentiment_by_group_filtered %>% 
              tidyr::pivot_wider(
                names_from = political_group, 
                values_from = avg_topic_sentiment
              ) %>% filter(!is.na(Zelensky_Supporter) & !is.na(Poroshenko_Supporter)) %>% 
              mutate(
                topic_name = stringr::str_replace_all(topic_name, "&", "and") # Clean up topic names
              ) %>% 
              arrange(abs(Zelensky_Supporter - Poroshenko_Supporter)), aes(x = reorder(topic_name, abs(Zelensky_Supporter - Poroshenko_Supporter)), y = Poroshenko_Supporter, yend = Zelensky_Supporter)) +
  geom_segment() +
  geom_point(aes(y = Zelensky_Supporter, shape = "Zelenskyy Supporters"), size = 1) +
  geom_point(aes(y = Poroshenko_Supporter, shape = "Poroshenko Supporters"), size = 1) +
  scale_shape(guide = guide_legend(title = "")) +
  coord_flip() + # Flip coordinates for better readability of topic names
  labs(
    #title = "Average Topic Sentiment by Political Group",
    x = "Topic",
    y = "Average Sentiment (Positive - Negative)",
  ) +
  def_theme +
  theme(
    legend.text = element_text(size = rel(3)),
    legend.position = "bottom"
  )

ggplot2latex::save_tex(g, "../visualisations/avg_topic_sentiment_by_group.tex", width = 6.9, height = 3)

# Visualization 2: Scatter plot of Zelensky vs Poroshenko sentiment on topics
# This helps visualize the correlation and divergence.

sentiment_wide_for_plot <- topic_sentiment_by_group_filtered %>%
  pivot_wider(names_from = political_group, values_from = avg_topic_sentiment) %>% 
  mutate(
    sentiment_difference = `Zelenskyy Supporter` - `Poroshenko Supporter`
  )

g <- ggplot(sentiment_wide_for_plot, aes(x = `Poroshenko Supporter`, y = `Zelenskyy Supporter`, label = target)) +
  geom_point(aes(color = sentiment_difference), size = rel(1)) + # Color by sentiment difference
  ggrepel::geom_text_repel(vjust = -0.5, hjust = 0.5, size = rel(1)) + # Add topic names as labels
  #geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "gray") + # Line of equality
  geom_segment(aes(x = -1, xend = 1, y = -1, yend = 1), linetype = "dotted", color = "black") + # Vertical line at x=0
  scale_color_gradient(low = "white", high = "black", limits = c(0, 1), guide = guide_legend()) +
  labs(
    #title = "Topic Sentiment: Zelensky vs Poroshenko Supporters",
    x = "Poroshenko Supporter Average Sentiment",
    y = "Zelenskyy Supporter Average Sentiment",
    color = "Sentiment Difference\n(Zelenskyy - Poroshenko)"
  ) +
  def_theme +
  theme(
    legend.position = "bottom",
    legend.text = element_text(size = rel(3))
  )

ggplot2latex::save_tex(g, "../visualisations/sentiment_scatter_zelensky_vs_poroshenko.tex", width = 6.9, height = 4)

# --- 4. Tables ---
# Table 1: Sentiment differences between groups per topic

sentiment_difference_table <- sentiment_diff %>%
  arrange(desc(abs(sentiment_difference))) # Order by absolute difference for most polarizing topics

print(sentiment_difference_table)

# Save table to CSV
#write.csv(sentiment_difference_table, "sentiment_differences_table.csv", row.names = FALSE)

# Table 2: Top N topics where Zelensky supporters are more positive/negative than Poroshenko supporters
# (and vice versa)

# Top 10 topics where Zelensky supporters are more positive
top_zelensky_positive <- sentiment_difference_table %>%
  filter(sentiment_difference > 0) %>%
  arrange(desc(sentiment_difference)) %>%
  head(10)

print("Top 10 topics where Zelensky supporters are more positive:")
print(top_zelensky_positive)
#write.csv(top_zelensky_positive, "top_zelensky_positive_topics.csv", row.names = FALSE)

# Top 10 topics where Poroshenko supporters are more positive
top_poroshenko_positive <- sentiment_difference_table %>%
  filter(sentiment_difference < 0) %>%
  arrange(sentiment_difference) %>%
  head(10)

print("Top 10 topics where Poroshenko supporters are more positive:")
print(top_poroshenko_positive)
#write.csv(top_poroshenko_positive, "top_poroshenko_positive_topics.csv", row.names = FALSE)

# --- Further Analysis (as suggested in issues.qmd) ---
# The document also mentions:
# - "correlation between political identity and sentiment toward secondary topics"
# - "consistency of these patterns across time and topics"
# - "temporal dimension of the analysis allows examination of how opinion adjustment evolves"
# - "Cross-validation techniques", "Sensitivity analyses", "controls for potential confounding factors"

# These require more complex statistical modeling and time-series analysis.
# For initial script, we focus on the core sentiment comparison and visualization.
# A correlation analysis could be added:

# Prepare data for correlation: each row is a topic, columns are sentiment for each group
correlation_data <- topic_sentiment_by_group_filtered %>%
  pivot_wider(names_from = political_group, values_from = avg_topic_sentiment)

# Calculate correlation between Zelensky and Poroshenko supporter sentiments across topics
if ("Zelensky_Supporter" %in% names(correlation_data) && "Poroshenko_Supporter" %in% names(correlation_data)) {
  correlation_value <- cor(correlation_data$Zelensky_Supporter, correlation_data$Poroshenko_Supporter, use = "pairwise.complete.obs")
  print(paste("Correlation between Zelensky and Poroshenko supporter sentiments across topics:", round(correlation_value, 3)))
} else {
  print("Cannot calculate correlation: one or both political groups not found in topic sentiment data.")
}

library(lubridate)

# --- TIME SERIES ANALYSIS ---

# Merge tweets with political group
tweets_with_group <- twi_selected %>%
  left_join(political_groups, by = "author_id") %>%
  filter(!is.na(political_group)) %>%
  mutate(sentiment_score = normalized_positive - normalized_negative,
         month = floor_date(created_at, "month"))

# --- 1. LEADER SENTIMENT GAP OVER TIME ---
leader_monthly_sentiment <- tweets_with_group %>%
  group_by(month, political_group, name) %>%
  summarise(avg_sentiment = mean(sentiment_score, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = political_group, values_from = avg_sentiment) %>%
  mutate(sentiment_gap = Zelensky_Supporter - Poroshenko_Supporter)

# Pick the facet where you want the annotation
first_facet_name <- unique(leader_monthly_sentiment$name)[1]

# Create a small data frame with annotation coordinates + facet name
annotation_df <- data.frame(
  month = min(leader_monthly_sentiment$month),
  y = c(0.05, -0.05),
  yend = c(0.5, -0.5),
  label = c("Zelensky supporters \n more positive",
            "Poroshenko supporters \n more positive"),
  name = first_facet_name
)

g <- ggplot(leader_monthly_sentiment, aes(x = month, y = sentiment_gap)) +
  geom_point() +
  geom_smooth(method = "loess", se = FALSE) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
  
  # Segments/arrows
  geom_segment(data = annotation_df,
               aes(x = month, xend = month,
                   y = y, yend = yend),
               arrow = arrow(length = unit(0.1, "cm")),
               linewidth = 0.1, inherit.aes = FALSE) +
  
  # Text labels
  geom_text(data = annotation_df,
            aes(x = month - 15, y = yend, label = label),
            inherit.aes = FALSE, 
            hjust = c(1, 0), vjust = 0, 
            size = rel(1), angle = 90) +
  
  labs(
    x = "Month",
    y = "Sentiment Gap"
  ) +
  facet_wrap(~ name) +
  def_theme



ggplot2latex::save_tex(g, "../visualisations/leader_sentiment_gap_over_time.tex", width = 7.6, height = 6)

# --- 2. TOPIC SENTIMENT GAP OVER TIME ---
# Join tweet IDs with topic sentiments
tweet_topic_sentiment_time <- twi_selected %>%
  select(id, author_id, created_at) %>%
  mutate(id = as.character(id)) %>%
  inner_join(topic_sentiments, by = "id") %>%
  left_join(political_groups_filtered, by = "author_id") %>%
  filter(!is.na(political_group)) %>%
  mutate(topic_sentiment_score = positive - negative,
         month = floor_date(created_at, "month")) %>%
  group_by(month, political_group, topic_id) %>%
  summarise(avg_topic_sentiment = mean(topic_sentiment_score, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = political_group, values_from = avg_topic_sentiment) %>%
  mutate(sentiment_gap = Zelensky_Supporter - Poroshenko_Supporter) %>%
  left_join(topics %>% select(topic_id, topic_name), by = "topic_id") %>%
  filter(topic_id != -1)

# Example: plot sentiment gap over time for the top N most discussed topics
top_topics <- tweet_topic_sentiment_time %>%
  count(topic_name, sort = TRUE) %>%
  slice_head(n = 5) %>%
  pull(topic_name)

g <- ggplot(tweet_topic_sentiment_time %>% filter(topic_name %in% top_topics) %>% 
              mutate(topic_name = stringr::str_replace_all(topic_name, "&", "and")),
       aes(x = month, y = sentiment_gap, color = topic_name)) +
  geom_point() +
  geom_smooth(method = "loess", se = FALSE) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
  labs(
    #title = "Opinion Adjustment Over Time by Topic",
    #subtitle = "Sentiment gap: Zelensky supporters − Poroshenko supporters",
    x = "Month",
    y = "Sentiment Gap",
    color = "Topic"
  ) +
  def_theme +
  theme(
    legend.position = "bottom",
    legend.text = element_text(size = rel(2))
  )

ggplot2latex::save_tex(g, "../visualisations/topic_sentiment_gap_over_time.tex", width = 7.6, height = 3)

# --- 3. ARE THEY GETTING MORE DIFFERENT? ---
# We'll measure average absolute gap across all topics each month
polarization_trend <- tweet_topic_sentiment_time %>%
  group_by(month) %>%
  summarise(mean_abs_gap = mean(abs(sentiment_gap), na.rm = TRUE), .groups = "drop")

# Fit a simple linear model to test trend
polarization_model <- lm(mean_abs_gap ~ as.numeric(month), data = polarization_trend)
trend_slope <- coef(polarization_model)[2]

if (trend_slope > 0) {
  cat("Result: The average opinion gap between groups is INCREASING over time.\n")
} else {
  cat("Result: The average opinion gap between groups is DECREASING over time.\n")
}

# Plot polarization trend
g <- ggplot(polarization_trend, aes(x = month, y = mean_abs_gap)) +
  geom_line(size = 1) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE, linetype = "dotted") +
  labs(
    #title = "Average Polarization Across Topics Over Time",
    x = "Month",
    y = "Average Absolute\nSentiment Gap"
  ) +
  def_theme

ggplot2latex::save_tex(g, "../visualisations/polarization_trend.tex", width = 3.5, height = 2)

