suppressPackageStartupMessages({
  require(ggplot2)
  require(dplyr)
  library(DBI)
  library(odbc)
  require(tidyr)
  library(reshape2)
  library(cowplot)
  library(ggplot2latex)
})

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

topic <- readr::read_csv("~/UHDS/topics_over_time.csv", col_types = readr::cols(), progress = F) %>% 
  mutate(Timestamp = lubridate::date(Timestamp)) %>% 
  group_by(Timestamp) %>% 
  mutate(Frequency = Frequency / sum(Frequency))

topic_leg <- readr::read_csv("~/UHDS/topic_info.csv", col_types = readr::cols(), progress = F)

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
      top_n(100, n) %>% 
      select(target, type), by = c("target", "type")) %>% 
  mutate(date = lubridate::round_date(date, "week", 1)) %>% 
  summarise(n = sum(n), .by = c(target, type, date)) %>% 
  arrange(date)

extrafont::loadfonts(quiet = TRUE)

# Yanukovych mentions frequency
g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target == "Yanukovych") %>% 
  ggplot(aes(date, n)) +
  ylab("Mention count") +
  xlab("Date") +
  geom_path(colour = "black") + def_theme

save_tex(g, file = "../visualisations/yanukovych_mentions.tex", width = 3.5, height = 2, reduce_power = 0)


annotation_data <- data.frame(
  date = as.Date(c("2020-06-15", "2022-01-17")),
  n_start = c(6000, 8000), # Y-coordinate for the arrow head (approximate peak for Poroshenko)
  n_end = c(8500, 10000), # Y-coordinate for the text label
  label = c("Poroshenko's Testimony in \n Yanukovych Treason Case", "Poroshenko's Return to \n Ukraine and Treason Case")
)

g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target %in% c("Zelensky", "Poroshenko")) %>% 
  mutate(target = ifelse(target == "Zelensky", "Zelenskyy", target)) %>% 
  ggplot(aes(date, n, group = target, linetype = target)) +
  scale_linetype(guide = guide_legend(title = "")) +
  ylab("Mention count") +
  xlab("Date") +
  geom_path() + 
  geom_vline(xintercept = lubridate::ymd("2019-05-20"), linetype = "dashed") +
  def_theme +
  # 1. Add arrows pointing to the peaks
  geom_segment(
    data = annotation_data,
    aes(x = date - 50, y = n_end, xend = date, yend = n_start),
    arrow = arrow(length = unit(0.1, "cm")),
    #curvature = 0.2,
    inherit.aes = FALSE,
    linewidth = 0.2
  ) +
  # 2. Add text labels above the arrows
  annotate(
    "text",
    x = lubridate::ymd("2019-05-20"),
    y = 20000, # slightly above the arrow end
    label = "Zelenskyy's inauguration",
    size = rel(1.2),
    hjust = -0.1
  ) +
  annotate(
    "text",
    x = annotation_data$date - 50,
    y = annotation_data$n_end + 500, # slightly above the arrow end
    label = annotation_data$label,
    size = rel(1.2),
    hjust = 0.5
  ) #+
  # Optional: Adjust the y-axis limit to accommodate the new labels
  #ylim(c(0, max(tweets_sent$n, na.rm = TRUE) * 1.05))

save_tex(g, file = "../visualisations/zelensky_poroshenko.tex", width = 3.5, height = 2.5, reduce_power = 0)


g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target == "Zelensky") %>% 
  ggplot(aes(date, n)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/zelensky.tex", width = 3.5, height = 2.5, reduce_power = 0)

g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target == "Poroshenko") %>% 
  ggplot(aes(date, n)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/poroshenko.tex", width = 3.5, height = 2.5, reduce_power = 0)

g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target %in% c("Trump", "Biden")) %>% 
  ggplot(aes(date, n, group = target, linetype = target)) +
  scale_linetype(guide = guide_legend(title = "")) +
  ylab("Mention count") +
  xlab("Date") +
  geom_path() + 
  geom_vline(xintercept = lubridate::ymd("2021-01-20"), linetype = "dashed") +
  def_theme +
  annotate(
    "text",
    x = lubridate::ymd("2021-01-20"),
    y = 3500, # slightly above the arrow end
    label = "Biden's inauguration",
    size = rel(1.2),
    hjust = -0.1
  )

save_tex(g, file = "../visualisations/trump_biden_mentions.tex", width = 7, height = 2.5, reduce_power = 0)


g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target == "Trump") %>% 
  ggplot(aes(date, n)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/trump.tex", width = 3.5, height = 2.5, reduce_power = 0)

g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target == "Biden") %>% 
  ggplot(aes(date, n)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/biden_mentions.tex", width = 3.5, height = 2.5, reduce_power = 0)


number = 3

g <- topic %>% 
  dplyr::filter(Topic == number) %>% 
  ggplot(aes(Timestamp, Frequency)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/elections.tex", width = 3.5, height = 2.5, reduce_power = 0)

number = 32

g <- topic %>% 
  dplyr::filter(Topic == number) %>% 
  ggplot(aes(Timestamp, Frequency)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/presidential_elections.tex", width = 3.5, height = 2.5, reduce_power = 0)


number = 6

g <- topic %>% 
  dplyr::filter(Topic == number) %>% 
  ggplot(aes(Timestamp, Frequency)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/zelensky_topic.tex", width = 3.5, height = 2.5, reduce_power = 0)

number = 1

g <- topic %>% 
  dplyr::filter(Topic == number) %>% 
  ggplot(aes(Timestamp, Frequency)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/covid.tex", width = 3.5, height = 2.5, reduce_power = 0)

number = 40

g <- topic %>% 
  dplyr::filter(Topic == number) %>% 
  ggplot(aes(Timestamp, Frequency)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/vaccination.tex", width = 3.5, height = 2.5, reduce_power = 0)

number = 35

g <- topic %>% 
  dplyr::filter(Topic == number) %>% 
  ggplot(aes(Timestamp, Frequency)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/sputnikv.tex", width = 3.5, height = 2.5, reduce_power = 0)

number = 18

g <- topic %>% 
  dplyr::filter(Topic == number) %>% 
  ggplot(aes(Timestamp, Frequency)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/masks.tex", width = 3.5, height = 2.5, reduce_power = 0)

number = 7

g <- topic %>% 
  dplyr::filter(Topic == number) %>% 
  ggplot(aes(Timestamp, Frequency)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/putin.tex", width = 3.5, height = 2.5, reduce_power = 0)

number = 24

g <- topic %>% 
  dplyr::filter(Topic == number) %>% 
  ggplot(aes(Timestamp, Frequency)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/kremlin.tex", width = 3.5, height = 2.5, reduce_power = 0)

number = 2

g <- topic %>% 
  dplyr::filter(Topic == number) %>% 
  ggplot(aes(Timestamp, Frequency)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/medvedchuk.tex", width = 3.5, height = 2.5, reduce_power = 0)

number = 99

g <- topic %>% 
  dplyr::filter(Topic == number) %>% 
  ggplot(aes(Timestamp, Frequency)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/russians.tex", width = 3.5, height = 2.5, reduce_power = 0)

g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target %in% c("Russia", "USA") & type == "GEOPOL") %>% 
  ggplot(aes(date, n/7, linetype = target)) +
  geom_path() + 
  scale_linetype(guide = guide_legend(title = "")) +
  xlab("Date") +
  ylab("Number of Tweets per Day") +
  def_theme

save_tex(g, file = "../visualisations/russia_usa.tex", width = 6.9, height = 2.5, reduce_power = 0)


g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target %in% c("Putin", "Lukashenko") & type == "POLITICS") %>% 
  ggplot(aes(date, n / 7, linetype = target)) +
  geom_path() + 
  scale_linetype(guide = guide_legend(title = "")) +
  xlab("Date") +
  ylab("Number of Tweets per Day") +
  def_theme  +
  annotate(
    "text",
    x = lubridate::ymd("2020-08-10"),
    y = 900, # slightly above the arrow end
    label = "Protests in Belarus",
    size = rel(1.2),
    hjust = 0.5
  )  +
  annotate(
    "text",
    x = lubridate::ymd("2019-12-10"),
    y = 700, # slightly above the arrow end
    label = "Normand format summit",
    size = rel(1.2),
    hjust = 0.5
  )  +
  annotate(
    "text",
    x = lubridate::ymd("2021-05-23"),
    y = 400, # slightly above the arrow end
    label = "Belarus' hijacked Ryanair flight",
    size = rel(1.2),
    hjust = 0.5
  )


save_tex(g, file = "../visualisations/putin_mentions.tex", width = 6.9, height = 2.5, reduce_power = 0)

g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target == "Medvedchuk") %>% 
  ggplot(aes(date, n)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/medvedchuk_mentions.tex", width = 3.5, height = 2.5, reduce_power = 0)

g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target == "Lukashenko") %>% 
  ggplot(aes(date, n)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/lukashenko_mentions.tex", width = 3.5, height = 2.5, reduce_power = 0)

g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target == "Avakov") %>% 
  ggplot(aes(date, n)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/avakov_mentions.tex", width = 3.5, height = 2.5, reduce_power = 0)

g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target == "Kolomoysky") %>% 
  ggplot(aes(date, n)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/kolomoysky_mentions.tex", width = 3.5, height = 2.5, reduce_power = 0)


g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target == "EU") %>% 
  ggplot(aes(date, n)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/eu_mentions.tex", width = 3.5, height = 2.5, reduce_power = 0)

g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target == "Ukraine") %>% 
  ggplot(aes(date, n)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/ukraine_mentions.tex", width = 3.5, height = 2.5, reduce_power = 0)

g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target == "USA") %>% 
  ggplot(aes(date, n)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/usa_mentions.tex", width = 3.5, height = 2.5, reduce_power = 0)

g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target == "Crimea") %>% 
  ggplot(aes(date, n)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/crimea_mentions.tex", width = 3.5, height = 2.5, reduce_power = 0)

g <- tweets_sent %>% 
  ungroup() %>% 
  dplyr::filter(target == "Donbas") %>% 
  ggplot(aes(date, n)) +
  geom_path() + def_theme

save_tex(g, file = "../visualisations/donbas_mentions.tex", width = 3.5, height = 2.5, reduce_power = 0)

twi_selected <- readr::read_csv("~/UHDS/twi_selected.csv", col_types = readr::cols(), progress = F)

twi_sum <- twi_selected %>% 
  mutate(date = lubridate::round_date(created_at, unit = "month")) %>% 
  summarise(negative = mean(negative),
            normalized_negative = mean(normalized_negative),
            normalized_positive = mean(normalized_positive),
            positive = mean(positive), .by = c(date, author_id, name)) 

sup <- twi_sum %>% 
  dplyr::filter(name %in% c("Poroshenko", "Zelensky")) %>% 
  summarise(negative = mean(negative), .by = c(author_id, name)) %>% 
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

g <- twi_sum %>% 
  summarise(negative = max(negative, na.rm = T),
            positive = max(positive, na.rm = T), .by = c(date, name)) %>%
  mutate(spread = negative+positive) %>% 
  arrange(name, date) %>%
  ggplot(aes(date, spread)) +
  geom_path() +
  geom_smooth(se = F, color = "black", linewidth = 0.5, linetype = "dashed") +
  xlab("Date") +
  ylab("Spread") +
  facet_wrap(~name, nrow = 4) +
  def_theme

ggplot2latex::save_tex(g, file = "../visualisations/spread_by_name.tex", width = 6.9)

#save_tex(g, file = "spread.tex", width = 7, height = 4, reduce_power = 0)

g <- twi_sum %>% 
  summarise(negative = max(negative, na.rm = T),
            positive = max(positive, na.rm = T), .by = date) %>%
  mutate(spread = negative+positive) %>% 
  ggplot(aes(date, spread)) +
  geom_path() +
  geom_smooth(se = F, color = "black", linewidth = 0.5, linetype = "dashed") +
  #scale_y_continuous(limits = c(0, 7.5)) +
  xlab("Date") +
  ylab("Spread") +
  def_theme

ggplot2latex::save_tex(g, file = "../visualisations/spread_total.tex", height = 2, width = 3.5)


# 1. Prepare the Individual Data (by name)
df_individuals <- twi_sum %>% 
  summarise(negative = max(negative, na.rm = T),
            positive = max(positive, na.rm = T), 
            .by = c(date, name)) %>%
  mutate(spread = negative + positive)

# 2. Prepare the Total Data (aggregate)
# We add a 'name' column here so we can bind it to the dataframe above
df_total <- twi_sum %>% 
  summarise(negative = max(negative, na.rm = T),
            positive = max(positive, na.rm = T), 
            .by = date) %>%
  mutate(spread = negative + positive,
         name = " AVERAGE (TOTAL)") # Naming it with a space ensures it appears first or last

# 3. Combine them
df_combined <- bind_rows(df_individuals, df_total)

# 4. Create Categories and Sort
# We define the category for each name, then order the 'name' factor by that category
df_final <- df_combined %>%
  mutate(category = case_when(
    name == " AVERAGE (TOTAL)" ~ "1. Summary",
    
    name %in% c("Biden", "Trump", "Putin", "Zelensky", "Poroshenko", 
                "Lukashenko", "Avakov", "Medvedchuk", "Tymoshenko", 
                "Yanukovych") ~ "2. Persons",
    
    name %in% c("POTUS", "President of Russia", "President of Ukraine") ~ "3. Roles",
    
    name %in% c("USA", "Russia", "Ukraine", "Kyiv", "Crimea", "Donbas", "USSR") ~ "4. Locations",
    
    name %in% c("EU", "IMF", "SBS", "ukrainians") ~ "5. Orgs & Groups",
    
    TRUE ~ "6. Other" # Catch-all for anything missed
  )) %>%
  # This step reorders the 'name' factor based on the 'category' column
  arrange(category, name) %>%
  mutate(name = factor(name, levels = unique(name)))

# 5. Plot
g <- df_final %>%
  arrange(date) %>% 
  ggplot(aes(date, spread, group = name)) +
  geom_path() + # Grey lines for raw data
  geom_smooth(se = F, color = "black", linewidth = 0.5, linetype = "dashed") +
  xlab("Date") +
  ylab("Spread") +
  # Using facet_wrap. 
  # You can keep scales="fixed" to compare magnitude, or "free_y" to see trends regardless of scale.
  facet_wrap(~name, ncol = 5) + 
  def_theme +
  theme(
    strip.text = element_text(size = rel(3), face = "bold"),
    panel.spacing = unit(1, "lines")
  )

# View graph
print(g)

# Save
ggplot2latex::save_tex(g, file = "../visualisations/spread_combined_sorted.tex", width = 6.9, height = 4)


#save_tex(g, file = "spread_total.tex", width = 3.5, height = 2.5, reduce_power = 0)

g <- twi_sum %>% 
  summarise(dispersion = sd(negative-positive, na.rm = T), .by = c(date, name)) %>%
  arrange(name, date) %>%
  ggplot(aes(date, dispersion)) +
  geom_path() +
  geom_smooth(se = F, color = "black", linewidth = 0.5, linetype = "dashed") +
  xlab("Date") +
  ylab("Dispersion") +
  facet_wrap(~name, ncol = 6) +
  def_theme +
  theme(
    strip.text = element_text(size = rel(3), face = "bold"),
    panel.spacing = unit(1, "lines")
  )

ggplot2latex::save_tex(g, file = "../visualisations/dispersion.tex", width = 6.9, height = 4)

coverage <- function(x){
  md = max(x)-min(x)
  r = lag(sort(x))+ 0.01 - sort(x)
  sum(-r[r<0], na.rm = T) / md
}

g <- twi_sum %>% 
  summarise(coverage = coverage(normalized_negative), .by = c(date, name)) %>% 
  arrange(name, date) %>%
  ggplot(aes(date, coverage)) +
  geom_path() +
  geom_smooth(se = F, color = "black", linewidth = 0.5, linetype = "dashed") +
  xlab("Date") +
  ylab("Coverage") +
  facet_wrap(~name, ncol = 6) +
  def_theme +
  theme(
    strip.text = element_text(size = rel(3), face = "bold"),
    panel.spacing = unit(1, "lines")
  )

ggplot2latex::save_tex(g, file = "../visualisations/coverage.tex", width = 6.9, height = 4)

regional <- function(x){
  md = max(x)-min(x)
  r = lag(sort(x))+ 0.01 - sort(x)
  g = cumsum(r[2:length(r)] < 0)
  sum(g - lag(g), na.rm = T)
}

g <- twi_sum %>% 
  summarise(regional = regional(normalized_negative), .by = c(date, name)) %>%
  arrange(name, date) %>% 
  ggplot(aes(date, regional)) +
  geom_path() +
  geom_smooth(se = F, color = "black", linewidth = 0.5, linetype = "dashed") +
  xlab("Date") +
  ylab("Regionalisation") +
  facet_wrap(~name, ncol = 6) +
  def_theme +
  theme(
    strip.text = element_text(size = rel(3), face = "bold"),
    panel.spacing = unit(1, "lines")
  )

ggplot2latex::save_tex(g, file = "../visualisations/regional.tex", width = 6.9, height = 4)

g <- twi_sum %>% 
  summarise(dispersion = e1071::kurtosis(negative)*var(negative), .by = c(date, name)) %>%
  arrange(name, date) %>%
  ggplot(aes(date, dispersion)) +
  geom_path() +
  geom_smooth(se = F, color = "black", linewidth = 0.5, linetype = "dashed") +
  xlab("Date") +
  ylab("Kurtosis × Variance") +
  facet_wrap(~name, ncol = 6) +
  def_theme +
  theme(
    strip.text = element_text(size = rel(3), face = "bold"),
    panel.spacing = unit(1, "lines")
  )

ggplot2latex::save_tex(g, file = "../visualisations/kurtosis.tex", width = 6.9, height = 4)

g <- twi_sum %>% 
  inner_join(sup, by="author_id") %>% 
  ungroup() %>% 
  tidyr::pivot_wider(id_cols = c("name", "date", "author_id"), 
                     names_from = "supporter", 
                     values_from = "negative") %>% 
  group_by(name, date) %>% 
  mutate(n = n()) %>% 
  dplyr::filter(n > 50) %>% 
  summarise(distinctness = ks.test(Poroshenko, Zelensky)$statistic)  %>%
  ggplot(aes(date, distinctness)) +
  geom_path() +
  geom_smooth(se = F, color = "red", linewidth = 0.5) +
  facet_wrap(~name) +
  def_theme

ggplot2latex::save_tex(g, file = "../visualisations/distinctness.tex", width = 7.5)

g <- twi_sum %>% 
  inner_join(sup, by="author_id") %>% 
  ungroup() %>% 
  tidyr::pivot_wider(id_cols = c("name", "date", "author_id"), 
                     names_from = "supporter", 
                     values_from = "negative") %>% 
  group_by(name, date) %>% 
  mutate(n = n()) %>% 
  dplyr::filter(n > 50) %>% 
  summarise(distinctness = ks.test(Poroshenko, Zelensky)$statistic)  %>%
  group_by(date) %>% 
  summarise(distinctness = mean(distinctness)) %>% 
  ggplot(aes(date, distinctness)) +
  geom_path() +
  geom_smooth(se = F, color = "red", linewidth = 0.5) +
  def_theme

ggplot2latex::save_tex(g, file = "../visualisations/distinctness_total.tex", width = 3.5, height = 2.5)


# 1. Base Processing (Calculate Distinctness for Everyone)
# We do the heavy lifting here once to avoid repeating the join and pivot operations.
df_base <- twi_sum %>% 
  inner_join(sup, by="author_id") %>% 
  ungroup() %>% 
  tidyr::pivot_wider(id_cols = c("name", "date", "author_id"), 
                     names_from = "supporter", 
                     values_from = "negative") %>% 
  group_by(name, date) %>% 
  mutate(n = n()) %>% 
  dplyr::filter(n > 50) %>% 
  summarise(distinctness = ks.test(Poroshenko, Zelensky)$statistic, .groups = "drop")

# 2. Create the "Average" Data
# We take the base results and average them by date to get the global trend.
df_total <- df_base %>%
  group_by(date) %>%
  summarise(distinctness = mean(distinctness, na.rm = TRUE), .groups = "drop") %>%
  mutate(name = " AVERAGE (TOTAL)")

# 3. Combine Individuals and Total
df_combined <- bind_rows(df_base, df_total)

# 4. Categorize and Sort
# Using the same logic as before to ensure "Average" is first, followed by Persons, etc.
df_final <- df_combined %>%
  mutate(category = case_when(
    name == " AVERAGE (TOTAL)" ~ "1. Summary",
    
    name %in% c("Biden", "Trump", "Putin", "Zelensky", "Poroshenko", 
                "Lukashenko", "Avakov", "Medvedchuk", "Tymoshenko", 
                "Yanukovych") ~ "2. Persons",
    
    name %in% c("POTUS", "President of Russia", "President of Ukraine") ~ "3. Roles",
    
    name %in% c("USA", "Russia", "Ukraine", "Kyiv", "Crimea", "Donbas", "USSR") ~ "4. Locations",
    
    name %in% c("EU", "IMF", "SBS", "ukrainians") ~ "5. Orgs & Groups",
    
    TRUE ~ "6. Other"
  )) %>%
  arrange(category, name) %>%
  mutate(name = factor(name, levels = unique(name)))

# 5. Plot
g <- df_final %>%
  group_by(name) %>% 
  mutate(n = n()) %>% 
  ungroup() %>% 
  filter(n >= 30) %>% 
  ggplot(aes(date, distinctness)) +
  geom_path(color = "grey60", alpha = 0.8) +
  geom_smooth(se = F, color = "black", linewidth = 0.5, linetype = "dashed") +
  xlab("Date") +
  ylab("Distinctness (KS Statistic)") +
  facet_wrap(~name, ncol = 4) +
  def_theme +
  theme(
    strip.text = element_text(size = rel(3), face = "bold"),
    panel.spacing = unit(1, "lines")
  )

# View
print(g)

# Save
ggplot2latex::save_tex(g, file = "../visualisations/distinctness_combined_sorted.tex", width = 6.9, height = 2)



g <- twi_sum %>% 
  inner_join(sup, by="author_id") %>% 
  group_by(date, name, supporter) %>% 
  summarise(g = mean(normalized_negative, na.rm = T))  %>% 
  ungroup() %>% 
  tidyr::pivot_wider(id_cols = c("name", "date"), 
                     names_from = "supporter", 
                     values_from = "g") %>% 
  mutate(divergence = abs(Poroshenko-Zelensky)) %>%
  ggplot(aes(date, divergence)) +
  geom_path() +
  geom_smooth(se = F, color = "black", linewidth = 0.5, linetype = "dashed") +
  xlab("Date") +
  ylab("Divergence") +
  facet_wrap(~name, ncol = 6) +
  def_theme

ggplot2latex::save_tex(g, file = "../visualisations/divergence.tex", width = 6.9)

g <- twi_sum %>% 
  inner_join(sup, by="author_id") %>% 
  group_by(date, name, supporter) %>% 
  summarise(g = mean(normalized_negative, na.rm = T))  %>% 
  ungroup() %>% 
  tidyr::pivot_wider(id_cols = c("name", "date"), 
                     names_from = "supporter", 
                     values_from = "g") %>% 
  group_by(date) %>% 
  summarise(divergence = mean(abs(Poroshenko-Zelensky), na.rm=T)) %>%
  ggplot(aes(date, divergence)) +
  geom_path() +
  geom_smooth(se = F, color = "black", linewidth = 0.5, linetype = "dashed") +
  xlab("Date") +
  ylab("Divergence") +
  def_theme

ggplot2latex::save_tex(g, file = "../visualisations/divergence_total.tex", width = 3.5, height = 2.5)


# 1. Base Processing (Calculate Divergence for Individuals)
df_base <- twi_sum %>% 
  inner_join(sup, by="author_id") %>% 
  group_by(date, name, supporter) %>% 
  summarise(g = mean(normalized_negative, na.rm = T), .groups = "drop")  %>% 
  tidyr::pivot_wider(id_cols = c("name", "date"), 
                     names_from = "supporter", 
                     values_from = "g") %>% 
  mutate(divergence = abs(Poroshenko - Zelensky))

# 2. Create the "Average" Data
# We aggregate the divergence values by date to see the overall trend.
df_total <- df_base %>% 
  group_by(date) %>% 
  summarise(divergence = mean(divergence, na.rm = T), .groups = "drop") %>% 
  mutate(name = " AVERAGE (TOTAL)")

# 3. Combine Individuals and Total
df_combined <- bind_rows(df_base, df_total)

# 4. Categorize and Sort
df_final <- df_combined %>%
  mutate(category = case_when(
    name == " AVERAGE (TOTAL)" ~ "1. Summary",
    
    name %in% c("Biden", "Trump", "Putin", "Zelensky", "Poroshenko", 
                "Lukashenko", "Avakov", "Medvedchuk", "Tymoshenko", 
                "Yanukovych") ~ "2. Persons",
    
    name %in% c("POTUS", "President of Russia", "President of Ukraine") ~ "3. Roles",
    
    name %in% c("USA", "Russia", "Ukraine", "Kyiv", "Crimea", "Donbas", "USSR") ~ "4. Locations",
    
    name %in% c("EU", "IMF", "SBS", "ukrainians") ~ "5. Orgs & Groups",
    
    TRUE ~ "6. Other"
  )) %>%
  arrange(category, name) %>%
  mutate(name = factor(name, levels = unique(name)))

# 5. Plot
g <- df_final %>%
  ggplot(aes(date, divergence)) +
  geom_path(color = "grey60", alpha = 0.8) +
  # Matches your specific style: black, dashed line
  geom_smooth(se = F, color = "black", linewidth = 0.5, linetype = "dashed") +
  xlab("Date") +
  ylab("Divergence") +
  facet_wrap(~name, ncol = 5) +
  def_theme +
  theme(
    strip.text = element_text(size = rel(3), face = "bold"),
    panel.spacing = unit(1, "lines")
  )

# View
print(g)

# Save
ggplot2latex::save_tex(g, file = "../visualisations/divergence_combined_sorted.tex", width = 6.9, height = 4)



g <- twi_sum %>% 
  inner_join(sup, by="author_id") %>% 
  group_by(date, name, supporter) %>% 
  summarise(g = sd(normalized_negative, na.rm = T)) %>% 
  group_by(date, name) %>% 
  summarise(consensus = 1 - mean(g, na.rm=T)) %>%
  ggplot(aes(date, consensus)) +
  geom_path() +
  geom_smooth(se = F, color = "black", linewidth = 0.5, linetype = "dashed") +
  xlab("Date") +
  ylab("Consensus") +
  facet_wrap(~name, ncol=6) +
  def_theme +
  theme(
    strip.text = element_text(size = rel(3), face = "bold"),
    panel.spacing = unit(1, "lines")
  )


ggplot2latex::save_tex(g, file = "../visualisations/consensus.tex", width = 6.9)

size_parity <- function(x){
  (-(1/log(length(x))))*sum(x*log(x))
}

g <- twi_sum %>% 
  dplyr::filter(name %in% c("Poroshenko", "Zelensky")) %>% 
  group_by(author_id, name, date) %>% 
  summarise(negative = mean(negative)) %>% 
  ungroup() %>% 
  tidyr::pivot_wider(id_cols = c("author_id", "date"), 
                     names_from = "name", 
                     values_from = "negative") %>% 
  mutate(
    supporter = case_when(
      (Poroshenko > 0) & (Zelensky < 0) ~ "Zelensky",
      (Poroshenko < 0) & (Zelensky > 0) ~ "Poroshenko",
    )
  ) %>% dplyr::filter(!is.na(supporter)) %>% 
  group_by(date, supporter) %>% 
  count() %>% 
  ungroup() %>% 
  tidyr::pivot_wider(id_cols = c("date"), 
                     names_from = "supporter", 
                     values_from = "n") %>% 
  mutate(
    po = Poroshenko/(Poroshenko+Zelensky),
    ze = Zelensky/(Poroshenko+Zelensky),
    size_parity = purrr::map2_dbl(ze, po, ~size_parity(c(.x, .y)))
  ) %>% 
  ggplot(aes(date, size_parity)) +
  geom_path() +
  geom_smooth(se = F, color = "black", linewidth = 0.5, linetype = "dashed") +
  xlab("Date") +
  ylab("Size Parity") +
  def_theme

ggplot2latex::save_tex(g, file = "../visualisations/size_parity.tex", width = 3.5, height = 2.5)

r <- twi_sum %>% 
  ungroup() %>% 
  select(date, author_id, name, negative) %>% 
  group_by(author_id) %>% 
  mutate(n = n()) %>% 
  ungroup() %>% 
  dplyr::filter(n>10) %>% 
  group_split(date) %>% 
  purrr::map(
    ~tidyr::pivot_wider(., id_cols = c("date", "author_id"), 
                        names_from = "name", 
                        values_from = "negative") %>% 
      mutate_if(is.numeric,
                ~ifelse(is.na(.), 0, .) #mean(., na.rm=T)
      ) 
  )

cl <- tibble(
  date = as.Date(purrr::map_dbl(r, ~.$date[1]), origin='1970-01-01'),
  community_fragmentation = purrr::map_dbl(r, ~size_parity(prop.table(table(dbscan::dbscan(prcomp(select(., -date, -author_id))$x[, c(1, 2)], 0.5, minPts = 10)$cluster))))
) 

g <- cl %>% 
  ggplot(aes(date, community_fragmentation)) +
  geom_path() +
  geom_smooth(se = F, color = "black", linewidth = 0.5, linetype = "dashed") +
  xlab("Date") +
  ylab("Community Fragmentation") +
  def_theme

ggplot2latex::save_tex(g, file = "../visualisations/community_fragmentation.tex", width = 3.5, height = 2.5)

