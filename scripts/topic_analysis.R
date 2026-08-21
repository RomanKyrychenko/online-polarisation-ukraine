# Postgres connect using R
library(DBI)
require(dplyr)
# dynamic graph using ggplot
library(ggplot2)
require(ggplot2latex)


graph_theme <- hrbrthemes::theme_ipsum() +
  theme(
    axis.text.x = element_text(
      size = rel(0.8),
      angle = 45,
      hjust = 1,
      colour = "black"
    ),
    axis.text.y = element_text(
      size = rel(0.8),
      colour = "black"
    ),
    panel.grid.major = element_line(
      linewidth = 0.1, 
      linetype = "dotted", 
    ),
    panel.grid.minor = element_line(
      linewidth = 0.1, 
      linetype = "dotted", 
    ),
    panel.spacing = unit(0,'lines'),
    panel.grid = element_line(linetype = "dotted", linewidth = 0.1),
    panel.spacing.y = unit(0.0, "lines"),
    panel.spacing.x = unit(0.5, "lines"),
    plot.margin = margin(0, 0, 0, 0),
    axis.text = element_text(size = rel(0.5)), 
    axis.title.x = element_text(size = rel(0.8), face = "bold", margin = margin(t = 5, r = 0, b = 0, l = 0)),
    axis.title.y = element_text(size = rel(0.8), face = "bold", margin = margin(t = 0, r = 5, b = 0, l = 0)),
    legend.title = element_text(size = rel(1)),
    legend.position = "bottom",
    legend.text = element_text(size = rel(0.8)),
    legend.spacing.x = unit(2.0, 'cm'),
    legend.spacing.y = unit(2.0, 'cm'),
    legend.key.size = unit(0.5, "cm")
  )


dbicon  <-  DBI::dbConnect( 
  #odbc::odbc(),
  RPostgres::Postgres(),
  #driver = "PostgreSQL Unicode", 
  dbname = "twitter", 
  host = "18.225.7.125", 
  port = "5432", 
  user = "propaganda_tutkija",
  password = Sys.getenv('PGPASSWORD')|p)urra.")

dbicon  <-  DBI::dbConnect( 
  #odbc::odbc(),
  RPostgres::Postgres(),
  #driver = "PostgreSQL Unicode", 
  dbname = "twitter")


dbListTables(dbicon)

dbGetQuery(dbicon, "
  SELECT 
    *
  FROM tweets_sent limit 10
")

topics <- dbGetQuery(dbicon, "SELECT * FROM topics;") %>% 
  as_tibble()

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
")

topic_texts <- dbGetQuery(dbicon, "
WITH ranked AS (
    SELECT 
        t.text, 
        tt.topic_id,
        ROW_NUMBER() OVER (PARTITION BY tt.topic_id ORDER BY RANDOM()) AS rn
    FROM tweets t
    LEFT JOIN (
        SELECT tweet_id, topic_id 
        FROM tweet_topics
    ) tt 
        ON t.id::text = tt.tweet_id::text
    WHERE tt.topic_id IS NOT NULL
)
SELECT text, topic_id
FROM ranked
WHERE rn <= 10
ORDER BY topic_id, rn;
") %>% 
  as_tibble()


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


topic_sentiments %>% 
  left_join(
    high_topics, by = "topic_id"
  ) %>% 
  group_by(category, category_name) %>%
  summarise(
    author_count = n_distinct(author_id),
    bot = mean(prob_bot, na.rm = TRUE),
    negative = sd(negative, na.rm = TRUE)+sd(positive, na.rm = TRUE),
    country_ukraine = mean(country == "Ukraine", na.rm = TRUE),
    date = sd(created_date, na.rm = TRUE),
    n = n_distinct(id),
    the_most_common_target = names(sort(table(target), decreasing = TRUE)[1]),
    second_most_common_target = names(sort(table(target), decreasing = TRUE)[2]),
  ) %>% 
  arrange(desc(author_count)) %>%
  left_join(
    topic_sentiments %>% 
      left_join(
        high_topics, by = "topic_id"
      ) %>% 
      group_by(id, author_id, category) %>% 
      summarise(
        negative = sd(negative, na.rm = TRUE),
        neutral = sd(neutral, na.rm = TRUE),
        positive = sd(positive, na.rm = TRUE)
      ) %>% 
      group_by(category) %>%
      summarise(
        sentiment_volatility = mean(negative, na.rm = TRUE)*mean(positive, na.rm = TRUE)
      ) %>% 
      ungroup() %>%
      mutate(
        sentiment_volatility = sentiment_volatility / max(sentiment_volatility, na.rm = TRUE)
      ),
    by = "category"
  ) %>% 
  View()

topic_sentiments %>% 
  left_join(
    high_topics, by = "topic_id"
  ) %>% 
  group_by(author_id, category, target) %>% 
  summarise(
    negative = mean(negative, na.rm = TRUE),
    neutral = mean(neutral, na.rm = TRUE),
    positive = mean(positive, na.rm = TRUE)
  ) %>%
  group_by(category, target) %>%
  summarise(
    negative = sd(positive, na.rm = TRUE),
  ) %>% 
  group_by(category) %>%
  summarise(
    negative = mean(negative, na.rm = TRUE)
  )




topic_sentiments %>% 
  group_by(author_id) %>% 
  summarise(
    negative = mean(negative, na.rm = TRUE),
    neutral = mean(neutral, na.rm = TRUE),
    positive = mean(positive, na.rm = TRUE)
  )


topic_sentiments %>% 
  group_by(topic_id) %>%
  summarise(
    bot = mean(prob_bot, na.rm = TRUE)
  ) %>% 
  arrange(bot) %>% 
  left_join(
    topics %>% 
      select(topic_id, topic_name),
    by = "topic_id"
  )


topic_sentiments %>% 
  group_by(topic_id) %>%
  summarise(
    negative = mean(neutral<0.5, na.rm = TRUE) * sqrt(n()),
    n = n(),
  ) %>% 
  arrange(desc(negative)) %>% 
  left_join(
    topics %>% 
      select(topic_id, topic_name),
    by = "topic_id"
  )



dbGetQuery(dbicon, "SELECT * FROM tweets_sent limit 1;")
dbGetQuery(dbicon, "SELECT * FROM tweet_topics limit 1;")

dbGetQuery(dbicon, "SELECT * FROM mentions limit 1;")
dbGetQuery(dbicon, "SELECT * FROM entities_sentiment limit 1;")
dbGetQuery(dbicon, "SELECT * FROM tweets limit 1;")

# POLITICS, PARTIES, GEOPOL, ORG, GEOPHYS, SOCGROUPS, POLGROUPS, POLSTATUS




tweets_oligarchs_daily <- dbGetQuery(dbicon, "
  SELECT 
    DATE(created_at) AS date,
    COUNT(DISTINCT author_id) AS daily_author_count
  FROM tweets
  WHERE text ~* 'ол[иі]гарх'
  GROUP BY DATE(created_at)
  ORDER BY date;
") %>% as_tibble()

g <- tweets_oligarchs_daily %>% 
  ggplot(aes(x = date, y = daily_author_count)) +
  geom_path() +
  labs(#title = "Oligarchs Tweets Over Time",
       x = "Date",
       y = "Number of Authors") +
  annotate(
    geom = "text",
    label = "De-oligarchization\nlaw passed",
    x = lubridate::ymd("2021-09-23"), y = 600, hjust = 0.5, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 month", expand = c(0, 0)) +
  graph_theme

ggplot2latex::save_tex(g, file = "../visualisations/oligarchs_tweets_over_time.tex", width = 7, height = 2)

targets <- dbGetQuery(dbicon, "SELECT distinct(target) FROM tweets_sent;")

tweets_origarkhs <- dbGetQuery(dbicon, "
  SELECT
    target,
    DATE(created_at) AS date,
    COUNT(DISTINCT author_id) AS n
  FROM tweets_sent
  WHERE target IN ('Kolomoysky', 'Akhmetov', 'Poroshenko', 'Medvedchuk')
  GROUP BY target, DATE(created_at)
  ORDER BY target, date;
") %>% as_tibble()

# Create a data frame for annotations
annot_df <- data.frame(
  target = c("Poroshenko" ,"Akhmetov", "Medvedchuk", "Kolomoysky", "Poroshenko"),  # facet to annotate
  date = c(as.Date("2019-04-01"), as.Date("2021-11-26"), as.Date("2020-10-19"), as.Date("2019-11-13"), as.Date("2020-06-18")),
  n = c(800, 100, 300, 250, 400),
  label = c("The first round of the presidential election", 
            "Akhmetov refused Zelensky's \n statement about his involvement \n in a possible coup",
            "Medvedchuk mention removal from the book about Stus", 
            "Kolomoysky proposed to have \n a friendship with Russia",
            "Poroshenko trial started")
)

g <- tweets_origarkhs %>% 
  ggplot(aes(x = date, y = n)) + #, color = target)) +
  geom_path() +
  labs(#title = "Oligarkhs Tweets Over Time",
       x = "Date",
       y = "Number of Authors") +
  geom_text(
    data = annot_df,
    aes(x = date, y = n, label = label),
    color = "black", hjust = 0, vjust = 0, size = rel(2),
    nudge_y=0.5
  ) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 month", expand = c(0, 0)) +
  #scale_color_manual(
  #  values = c("Kolomoysky" = "#E41A1C", "Akhmetov" = "#377EB8", 
  #             "Poroshenko" = "#4DAF4A", "Medvedchuk" = "#FF7F00")
  #) +
  hrbrthemes::theme_ipsum() +
  graph_theme +
  facet_wrap(~ target, ncol = 1, scales = "free_y")

ggplot2latex::save_tex(g, file = "../visualisations/oligarkhs_mentions_over_time.tex", width = 7, height = 6)





covid <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id in (2, 32, 335, 388);
") %>% 
  as_tibble()

covid_vaccination <- dbGetQuery(dbicon, "WITH base AS (
    SELECT
        t.id,
        t.created_at,
        t.author_id,
        tt.topic_id,
        DATE(t.created_at) AS date,
        CASE 
            WHEN tt.topic_id IN (2, 32, 335, 388) THEN 'COVID-19'
            WHEN tt.topic_id = 9 THEN 'Vaccination'
        END AS topic
    FROM tweet_topics tt
    LEFT JOIN tweets t 
        ON t.id::bigint = tt.tweet_id::bigint
    WHERE tt.topic_id IN (2, 9, 32, 335, 388)
)

SELECT
    date,
    topic,
    COUNT(DISTINCT author_id) AS daily_author_count
FROM base
GROUP BY date, topic
ORDER BY date, topic;") %>% as_tibble()

elections <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id = 1;
") %>% 
  as_tibble()

russian_aggression <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id = 3;
") %>% 
  as_tibble()

elections <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id = 1;
") %>% 
  as_tibble()

belarus <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id = 13;
") %>% 
  as_tibble()

conflict_identity <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id = 0;
") %>% 
  as_tibble()

coloomytsky <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id = 6;
") %>% 
  as_tibble()

vaccination <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id = 9;
") %>% 
  as_tibble()

donbas <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id in (14, 90, 119);
") %>% 
  as_tibble() 

crimea <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id in (15);
") %>% 
  as_tibble()

donbas_crimea <- dbGetQuery(dbicon, "WITH base AS (
    SELECT
        t.id,
        t.created_at,
        t.author_id,
        tt.topic_id,
        DATE(t.created_at) AS date,
        CASE 
            WHEN tt.topic_id IN (14, 90, 119) THEN 'Donbas'
            WHEN tt.topic_id = 15 THEN 'Crimea'
        END AS topic
    FROM tweet_topics tt
    LEFT JOIN tweets t 
        ON t.id::bigint = tt.tweet_id::bigint
    WHERE tt.topic_id IN (14, 90, 119, 15)
)

SELECT
    date,
    topic,
    COUNT(DISTINCT author_id) AS daily_author_count
FROM base
GROUP BY date, topic
ORDER BY date, topic;") %>% as_tibble()

corruption <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id in (45, 51, 86, 96, 99, 124, 138, 165, 176, 177, 181, 190, 244, 254, 261, 313, 517)
") %>% 
  as_tibble()

ua_politics <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id in (8);
") %>% 
  as_tibble()

conflict <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id in (3, 7);
") %>% 
  as_tibble()

nord_stream <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id in (21);
") %>% 
  as_tibble()


steinmeier <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id in (25);
") %>% 
  as_tibble()

mh17 <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id in (26);
") %>% 
  as_tibble()

international_news <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id in (33);
") %>% 
  as_tibble()


other <- dbGetQuery(dbicon, "SELECT t.id, t.created_at, t.author_id, tt.*
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
WHERE tt.topic_id in (-1);
") %>% 
  as_tibble()

# correlation between topics in postgres
dyn <- dbGetQuery(dbicon, "SELECT 
    tt.topic_id,
    DATE(t.created_at) AS date,
    COUNT(DISTINCT t.author_id) AS daily_author_count
FROM tweet_topics tt
LEFT JOIN tweets t ON t.id::bigint = tt.tweet_id::bigint
GROUP BY tt.topic_id, DATE(t.created_at)
ORDER BY tt.topic_id, date;
") %>% 
  as_tibble()

dyn %>% group_by(topic_id) %>% 
  summarise(n = max(daily_author_count) - mean(daily_author_count)) %>% 
  arrange(desc(n))

# pivot dyn and calculate correlation
dyn_cor <- dyn %>% 
  tidyr::pivot_wider(
    id_cols = "date", 
    names_from = "topic_id", 
    values_from = "daily_author_count", 
    values_fill = 0
  ) %>% 
  dplyr::select(-date) %>% 
  mutate_all(as.numeric) %>%
  cor(use = "pairwise.complete.obs") %>% 
  as.data.frame() %>% 
  tibble::rownames_to_column("topic_id") %>% 
  tidyr::pivot_longer(
    cols = -topic_id, 
    names_to = "topic_id2", 
    values_to = "correlation"
  ) %>% 
  dplyr::filter(topic_id != topic_id2)
  

g <- dyn %>%
  filter(topic_id == 1) %>% 
  ggplot(aes(x = date, y = daily_author_count)) +
  geom_path() +
  labs(#title = "Ukrainian Elections and Political Processes Tweets Over Time",
       x = "Day",
       y = "Number of Authors") +
  annotate(
    geom = "text",
    label = "The first round of the presidential election",
    x = lubridate::ymd("2019-04-01"), y = 1600, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "The second round of the presidential election",
    x = lubridate::ymd("2019-04-21"), y = 1300, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "The parliamentary election",
    x = lubridate::ymd("2019-07-21"), y = 1100, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "The local elections",
    x = lubridate::ymd("2020-10-26"), y = 1000, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme


ggplot2latex::save_tex(g, file = "../visualisations/elections_tweets_over_time.tex", width = 7, height = 2)

g <- covid_vaccination %>% 
  ggplot(aes(x = date, y = daily_author_count, group = topic, linetype = topic)) +
  geom_path() +
  scale_linetype(guide = guide_legend(title = "")) +
  labs(#title = "COVID-19 Tweets Over Time",
       x = "Day",
       y = "Number of Authors") +
  annotate(
    geom = "text",
    label = "The first wave of COVID-19",
    x = lubridate::ymd("2020-04-01"), y = 1800, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "The second wave of COVID-19",
    x = lubridate::ymd("2020-10-01"), y = 800, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "The first vaccine is available in Ukraine",
    x = lubridate::ymd("2021-03-01"), y = 600, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "Boosting vaccination starts",
    x = lubridate::ymd("2021-11-01"), y = 800, hjust = 0.5, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

ggplot2latex::save_tex(g, file = "../visualisations/covid_vaccine_tweets_over_time.tex", width = 7, height = 3)

g <- belarus %>% 
  mutate(
    day = as.Date(created_at),
  ) %>% 
  group_by(day) %>%
  summarise(count = n_distinct(author_id)) %>% 
  ungroup() %>% 
  ggplot(aes(x = day, y = count)) +
  geom_path() +
  labs(#title = "Belarusian Protests Tweets Over Time",
       x = "Day",
       y = "Authors Count") +
  annotate(
    geom = "text",
    label = "The presidential election in Belarus",
    x = lubridate::ymd("2020-08-09"), y = 1100, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "Ryanair flight forced landing",
    x = lubridate::ymd("2021-05-23"), y = 600, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

ggplot2latex::save_tex(g, file = "../visualisations/belarus_tweets_over_time.tex", width = 7, height = 2)

g <- conflict_identity %>% 
  mutate(
    day = as.Date(created_at),
  ) %>% 
  group_by(day) %>%
  summarise(count = n_distinct(author_id)) %>% 
  ungroup() %>% 
  ggplot(aes(x = day, y = count)) +
  geom_path() +
  labs(#title = "Conflict Identity Tweets Over Time",
       x = "Day",
       y = "Authors Count") +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

g <- coloomytsky %>%
  mutate(
    day = as.Date(created_at),
  ) %>% 
  group_by(day) %>%
  summarise(count = n_distinct(author_id)) %>% 
  ungroup() %>% 
  ggplot(aes(x = day, y = count)) +
  geom_path() +
  labs(#title = "Coloomytsky Tweets Over Time",
       x = "Day",
       y = "Authors Count") +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

g <- dyn %>%
  filter(topic_id == 9) %>% 
  filter(date >= lubridate::ymd("2020-01-01")) %>%
  ggplot(aes(x = date, y = daily_author_count)) +
  geom_path() +
  labs(#title = "Vaccination Tweets Over Time",
       x = "Day",
       y = "Authors Count") +
  annotate(
    geom = "text",
    label = "The first wave of COVID-19",
    x = lubridate::ymd("2020-03-01"), y = 600, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "The first vaccine is available in Ukraine",
    x = lubridate::ymd("2021-03-01"), y = 600, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "Boosting vaccination starts",
    x = lubridate::ymd("2021-11-01"), y = 800, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

ggplot2latex::save_tex(g, file = "../visualisations/vaccination_tweets_over_time.tex", width = 7, height = 2)

g <- donbas %>%
  mutate(
    day = as.Date(created_at),
  ) %>% 
  group_by(day) %>%
  summarise(count = n_distinct(author_id)) %>% 
  ungroup() %>% 
  ggplot(aes(x = day, y = count)) +
  geom_path() +
  labs(#title = "Donbas Tweets Over Time",
       x = "Day",
       y = "Authors Count") +
  annotate(
    geom = "text",
    label = "Intensive fighting in Donbas",
    x = lubridate::ymd("2020-02-18"), y = 750, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

ggplot2latex::save_tex(g, file = "../visualisations/donbas_tweets_over_time.tex", width = 7, height = 2)

g <- corruption %>%
  mutate(
    day = as.Date(created_at),
  ) %>% 
  group_by(day) %>%
  summarise(count = n_distinct(author_id)) %>% 
  ungroup() %>% 
  ggplot(aes(x = day, y = count)) +
  geom_path() +
  labs(
    x = "Day",
    y = "Number of Authors"
  ) +
  scale_y_continuous(breaks = c(0, 250, 500, 750, 1000, 1250, 1500), limits = c(0, 1500)) +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

ggplot2latex::save_tex(g, file = "../visualisations/corruption_tweets_over_time.tex", width = 7, height = 2)

g <- ua_politics %>%
  mutate(
    day = as.Date(created_at),
  ) %>% 
  group_by(day) %>%
  summarise(count = n_distinct(author_id)) %>% 
  ungroup() %>% 
  ggplot(aes(x = day, y = count)) +
  geom_path() +
  labs(#title = "Ukrainian Politics Tweets Over Time",
       x = "Day",
       y = "Authors Count") +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

g <- conflict %>%
  mutate(
    day = as.Date(created_at),
  ) %>% 
  group_by(day) %>%
  summarise(count = n_distinct(author_id)) %>% 
  ungroup() %>% 
  ggplot(aes(x = day, y = count)) +
  geom_path() +
  labs(#title = "Conflict Tweets Over Time",
       x = "Day",
       y = "Authors Count") +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

g <- donbas_crimea %>% 
  ggplot(aes(x = date, y = daily_author_count, linetype = topic)) +
  geom_path() +
  scale_linetype(guide = guide_legend(title = "")) +
  labs(#title = "Crimea Tweets Over Time",
       x = "Day",
       y = "Authors Count") +
  annotate(
    geom = "text",
    label = "New prime minister of Ukraine proposes\nto resume water supply to Crimea",
    x = lubridate::ymd("2020-03-10"), y = 950, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "Intensive fighting\non Donbas",
    x = lubridate::ymd("2020-02-18"), y = 750, hjust = 1, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "Summit 'Crimea Platform' in Kyiv",
    x = lubridate::ymd("2021-08-23"), y = 600, hjust = 0.5, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "5 years of\nCrimea annexation",
    x = lubridate::ymd("2019-03-18"), y = 750, hjust = 0.5, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

ggplot2latex::save_tex(g, file = "../visualisations/crimea_donbas_tweets_over_time.tex", width = 7, height = 3)

g <- nord_stream %>%
  mutate(
    day = as.Date(created_at),
  ) %>% 
  group_by(day) %>%
  summarise(count = n_distinct(author_id)) %>% 
  ungroup() %>% 
  ggplot(aes(x = day, y = count)) +
  geom_path() +
  labs(#title = "Nord Stream Tweets Over Time",
       x = "Day",
       y = "Authors Count") +
  annotate(
    geom = "text",
    label = "EU parliament resolution on Nord Stream 2",
    x = lubridate::ymd("2018-12-13"), y = 400, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "US sanctions against Nord Stream 2",
    x = lubridate::ymd("2019-12-21"), y = 450, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "Deal between US and Germany on Nord Stream 2",
    x = lubridate::ymd("2021-07-21"), y = 450, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "Nord Stream 2 certification suspended",
    x = lubridate::ymd("2022-02-22"), y = 600, hjust = 1, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

ggplot2latex::save_tex(g, file = "../visualisations/nord_stream_tweets_over_time.tex", width = 7, height = 2)

g <- steinmeier %>%
  mutate(
    day = as.Date(created_at),
  ) %>% 
  group_by(day) %>%
  summarise(count = n_distinct(author_id)) %>% 
  ungroup() %>% 
  ggplot(aes(x = day, y = count)) +
  geom_path() +
  labs(#title = "Steinmeier Formula Tweets Over Time",
       x = "Day",
       y = "Authors Count") +
  annotate(
    geom = "text",
    label = "Agreement on Steinmeier formula implementation",
    x = lubridate::ymd("2019-10-01"), y = 1000, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

ggplot2latex::save_tex(g, file = "../visualisations/steinmeier_tweets_over_time.tex", width = 7, height = 2)


g <- dyn %>%
  filter(topic_id == 3) %>% 
  filter(date >= lubridate::ymd("2020-01-01")) %>%
  ggplot(aes(x = date, y = daily_author_count)) +
  geom_path() +
  labs(#title = "Russian Aggression Tweets Over Time",
       x = "Day",
       y = "Authors Count") +
  annotate(
    geom = "text",
    label = "Russia's military\nbuildup near Ukraine",
    x = lubridate::ymd("2021-04-01"), y = 700, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  scale_y_continuous(
    limits = c(0, 2000)
  ) +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

ggplot2latex::save_tex(g, file = "../visualisations/russian_aggression_tweets_over_time.tex", width = 6.9, height = 2)


g <- mh17 %>%
  mutate(
    day = as.Date(created_at),
  ) %>% 
  group_by(day) %>%
  summarise(count = n_distinct(author_id)) %>% 
  ungroup() %>% 
  ggplot(aes(x = day, y = count)) +
  geom_path() +
  labs(#title = "MH17 Tweets Over Time",
       x = "Day",
       y = "Authors Count") +
  annotate(
    geom = "text",
    label = "The MH17 crash investigation charges announced",
    x = lubridate::ymd("2019-06-19"), y = 650, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_them

ggplot2latex::save_tex(g, file = "../visualisations/mh17_tweets_over_time.tex", width = 7, height = 2)

g <- dyn %>% 
  filter(topic_id == 33) %>%
  ggplot(aes(x = date, y = daily_author_count)) +
  geom_path() +
  labs(#title = "International News Tweets Over Time",
       x = "Day",
       y = "Authors Count") +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

ggplot2latex::save_tex(g, file = "../visualisations/international_news_tweets_over_time.tex", width = 6.9, height = 2)

g <- dyn %>% 
  filter(topic_id == 142) %>% 
  ggplot(aes(x = date, y = daily_author_count)) +
  geom_path() +
  labs(#title = "International News Tweets Over Time",
    x = "Day",
    y = "Authors Count") +
  annotate(
    geom = "text",
    label = "Ortodox Church of Ukraine established",
    x = lubridate::ymd("2018-12-15"), y = 1000, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "Tomos granted to the Orthodox Church of Ukraine",
    x = lubridate::ymd("2019-01-06"), y = 800, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "Orthodox Easter",
    x = lubridate::ymd("2020-04-18"), y = 600, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme

g <- dyn %>% 
  filter(topic_id == 83) %>% 
  ggplot(aes(x = date, y = daily_author_count)) +
  geom_path() +
  labs(#title = "International News Tweets Over Time",
    x = "Day",
    y = "Authors Count") +
  scale_x_date(
    date_labels = "%b %Y",
    date_breaks = "3 month",
    expand = c(0, 0)
  ) +
  graph_theme


tweets_eu <- dbGetQuery(dbicon, "
  SELECT
    DATE(created_at) AS date,
    COUNT(DISTINCT author_id) AS daily_author_count
  FROM tweets_sent
  WHERE target IN ('EU')
  GROUP BY target, DATE(created_at)
  ORDER BY target, date;
") %>% as_tibble()

tweets_nato <- dbGetQuery(dbicon, "
  SELECT 
    DATE(created_at) AS date,
    COUNT(DISTINCT author_id) AS daily_author_count
  FROM tweets
  WHERE text ~* '\\mнато'
  GROUP BY DATE(created_at)
  ORDER BY date;
") %>% as_tibble()


dat_ann <- data.frame(
  target = c("EU", "NATO"),
  date = c(as.Date("2019-02-07"), as.Date("2019-02-07")),
  daily_author_count = c(750, 750),
  label = c("Ukrainian Parliament defines the course towards EU and NATO in the Constitution",
            "")
)

g <- tweets_eu %>%
  mutate(target = "EU") %>%
  bind_rows(
    tweets_nato %>% 
      mutate(target = "NATO")
  ) %>%
  ggplot(aes(x = date, y = daily_author_count, linetype = target)) + #, color = target)) +
  geom_path() +
  geom_text(
    data = dat_ann,
    aes(x = date, y = daily_author_count, label = label),
    color = "black", hjust = 0, vjust = 0, size = rel(2),
    nudge_y=0.5
  ) +
  scale_linetype(guide = guide_legend(title = "")) +
  labs(#title = "EU and NATO Tweets Over Time",
       x = "Date",
       y = "Number of Authors") +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 month", expand = c(0, 0)) +
  graph_theme #+
  #facet_wrap(~ target, ncol = 1, scales = "free_y")

ggplot2latex::save_tex(g, file = "../visualisations/eu_nato_mentions_over_time.tex", width = 7, height = 3)

tweets_reforms <- dbGetQuery(dbicon, "
  SELECT 
    DATE(created_at) AS date,
    COUNT(DISTINCT author_id) AS daily_author_count
  FROM tweets
  WHERE text ~* 'реформ'
  GROUP BY DATE(created_at)
  ORDER BY date;
") %>% as_tibble()

g <- tweets_reforms %>%
  ggplot(aes(x = date, y = daily_author_count)) +
  geom_path() +
  labs(#title = "Reforms Tweets Over Time",
       x = "Date",
       y = "Number of Authors") +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 month", expand = c(0, 0)) +
  graph_theme

ggplot2latex::save_tex(g, file = "../visualisations/reforms_mentions_over_time.tex", width = 7, height = 2)


tweets_imf <- dbGetQuery(dbicon, "
  SELECT 
    DATE(created_at) AS date,
    COUNT(DISTINCT author_id) AS daily_author_count
  FROM tweets
  WHERE text ~* 'МВФ'
  GROUP BY DATE(created_at)
  ORDER BY date;
") %>% as_tibble()

g <- tweets_imf %>%
  ggplot(aes(x = date, y = daily_author_count)) +
  geom_path() +
  annotate(
    geom = "text",
    label = "IMF postpones the next tranche due to the connerns about the connectedness of the \n Ukrainian government with the oligarchs",
    x = lubridate::ymd("2019-11-05"), y = 370, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  labs(#title = "IMF Tweets Over Time",
       x = "Date",
       y = "Number of Authors") +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 month", expand = c(0, 0)) +
  graph_theme

ggplot2latex::save_tex(g, file = "../visualisations/imf_mentions_over_time.tex", width = 7, height = 2)

tweets_land <- dbGetQuery(dbicon, "
  SELECT 
    DATE(created_at) AS date,
    COUNT(DISTINCT author_id) AS daily_author_count
  FROM tweets
  WHERE text ~* 'зем(|.)л'
  GROUP BY DATE(created_at)
  ORDER BY date;
") %>% as_tibble()

g <- tweets_land %>%
  ggplot(aes(x = date, y = daily_author_count)) +
  geom_path() +
  annotate(
    geom = "text",
    label = "Land market law\npreliminary vote",
    x = lubridate::ymd("2019-11-13"), y = 1070, hjust = 0.5, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "Land market\nlaw passed",
    x = lubridate::ymd("2020-03-31"), y = 970, hjust = 0.5, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  labs(#title = "Land Market Tweets Over Time",
       x = "Date",
       y = "Number of Authors") +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 month", expand = c(0, 0)) +
  scale_y_continuous(limits = c(0, 1100)) +
  graph_theme

ggplot2latex::save_tex(g, file = "../visualisations/land_market_mentions_over_time.tex", width = 6.9, height = 2)

tweets_diia <- dbGetQuery(dbicon, "
  SELECT 
    DATE(created_at) AS date,
    COUNT(DISTINCT author_id) AS daily_author_count
  FROM tweets
  WHERE text ~* '\\mдія'
  GROUP BY DATE(created_at)
  ORDER BY date;
") %>% as_tibble()

g <- tweets_diia %>%
  ggplot(aes(x = date, y = daily_author_count)) +
  geom_path() +
  annotate(
    geom = "text",
    label = "Diia app launched",
    x = lubridate::ymd("2020-02-06"), y = 1000, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  annotate(
    geom = "text",
    label = "Diia app launched for business",
    x = lubridate::ymd("2021-02-01"), y = 800, hjust = 0, vjust = 0,
    size = rel(2), colour = "black"
  ) +
  labs(#title = "Diia App Tweets Over Time",
       x = "Date",
       y = "Number of Authors") +
  scale_x_date(date_labels = "%b %Y", date_breaks = "3 month", expand = c(0, 0)) +
  graph_theme
