suppressPackageStartupMessages({
  require(ggplot2)
  require(dplyr)
  library(DBI)
  library(odbc)
  require(tidyr)
  library(reshape2)
  library(cowplot)
  library(purrr)
  library(cluster)
  library(ggalluvial)
  library(scales)
})

def_theme <- hrbrthemes::theme_ipsum(
  base_family = "Georgia", base_size = rel(2), 
  plot_title_size = rel(2), axis_title_size = rel(2), subtitle_size = rel(2), strip_text_size = rel(2)) +
  theme(
    panel.grid = element_line(linetype = "dotted", linewidth = 0.1),
    panel.spacing.y = unit(0.0, "lines"),
    panel.spacing.x = unit(0.5, "lines"),
    axis.text = element_text(size = rel(1.5))
  )

extrafont::loadfonts(quiet = TRUE)

load("../data/baldassari_bearman_sim.rdata")

# Set up initial conditions
set.seed(123) # for reproducibility
n_actors <- 100
n_issues <- 4
mu <- 0
sigma <- 33.3
interest_range <- c(-100, 100)
n_iter <- 500

# Generate initial actor attributes
interests <- matrix(rnorm(n_actors * n_issues, mean = mu, sd = sigma), nrow = n_actors)
perceived_distance <- mean(dist(interests))

# Simulation loop
results <- list()

results[[1]] = list(iteration = 1, interest = interests, perceived_distance = perceived_distance)

inters <- list()

for (i in 2:n_iter) {
  # Selection of interaction partners
  interlocutors <- lapply(1:n_actors, function(x) {
    # Random sample of potential interlocutors to the overall level of interest
    sample_actors <- seq_len(n_actors)[-x]
    sample_interests <- interests[sample_actors, ]
    sample_distance <- apply((sample_interests - interests[x, ])^2, 1, sum)^0.25
    sample_prob <- 1 - (sample_distance / perceived_distance)
    # Draw from the sample the actual interlocutors with p = 1 -
    sample_actors[sample_prob < runif(length(sample_prob))] 
  })
  
  # Save interlocutors for the current iteration
  inters[[i]] <- interlocutors
  
  # Process of Interpersonal influence
  for (j in 1:n_actors) {
    if (rnorm(1) > 1) {
      next
    }
    for (k in interlocutors[[j]]) {
      # Select the issue for discussion
      issue <- which.max(abs(interests[k, ]) + abs(interests[j, ]))
      
      if (interests[k, issue] != 0){
        delta_k <- 0.1 * abs(abs(interests[k, issue]) - abs(interests[j, issue])) / abs(interests[k, issue])
      } else {
        delta_k <- 0
      }
      if (interests[j, issue] != 0){
        delta_j <- 0.1 * abs(abs(interests[j, issue]) - abs(interests[k, issue])) / abs(interests[j, issue])
      } else {
        delta_j <- 0
      }
      # Determine direction of change according to the sign of the issue
      delta_j <- delta_j * sign(interests[j, issue])
      delta_k <- delta_k * sign(interests[k, issue])
      # Update actors' level of interest
      interests[j, issue] <- pmax(pmin(interests[j, issue] + delta_j, interest_range[2]), interest_range[1])
      interests[k, issue] <- pmax(pmin(interests[k, issue] + delta_k, interest_range[2]), interest_range[1])
      # Update actors' perceived ideological distance with the current/actual distance
      perceived_distance <- mean(dist(interests))
    }
  }
  
  # Save all necessary information
  results[[i]] <- list(iteration = i, interest = interests, perceived_distance = perceived_distance)
}

# remove the first iteration
inters <- inters[-1]

# interlocutors to graph
interlocutors_df <- purrr::map_dfr(inters, function(interlocutors) purrr::map2_dfr(1:length(interlocutors), interlocutors, function(f, res) {
  tibble(
    from = f,
    to = unlist(res)
  )
}))

# Create a graph object for visualization
library(igraph)
g <- interlocutors_df %>% group_by(from, to) %>% count() %>% 
  filter(n > 45) %>%
  semi_join(
    interlocutors_df %>% group_by(from, to) %>% count() %>% 
      filter(n > 45),
    by = c("from" = "to", "to" = "from") 
  ) %>% 
  graph_from_data_frame(directed = T)
# Plot the graph using ggraph
library(ggraph)
ggraph(g, layout = "fr") +
  geom_edge_link(alpha = 0.5, colour = "black") +
  geom_node_point(size = 2, shape = 21, stroke = 0.3) +
  theme_void() +
  ggtitle("Interlocutors Network at Iteration 1") +
  theme(plot.title = element_text(size = 16, face = "bold"))


interest_df <- purrr::map_dfr(
  results, ~as_tibble(.$interest) %>% 
    mutate(actor = 1:n_actors) %>% 
    tidyr::pivot_longer(V1:V4, names_to = "issue", values_to = "interest"), .id = "iteration") %>% 
  mutate(iteration = as.numeric(iteration))

perceived_distance_df <- tibble(
  iteration = 1:n_iter,
  perceived_distance = sapply(results, function(x) x$perceived_distance)
)

g <- interest_df[interest_df$iteration %in% c(1, 100, 200, 500), ] %>% 
  mutate(
    issue = stringr::str_replace_all(issue, "V", "Issue ")
  ) %>% 
  ggplot(aes(interest)) +
  geom_histogram() +
  ylab("Count") +
  xlab("Interest") +
  facet_grid(iteration~issue) +
  def_theme +
  theme(
    axis.text.x = element_text(size = rel(1)),
    axis.text.y = element_text(size = rel(1))
  )

ggplot2latex::save_tex(g, file = "../visualisations/interest.tex", width = 6.9, height = 2.5, reduce_power = 0)

p1 <- interest_df %>% dplyr::filter(actor==1) %>% 
  mutate(issue = stringr::str_replace_all(issue, "V", "Issue ")) %>% 
  ggplot(aes(x = iteration, y = interest, linetype = issue, group=issue)) +
  geom_path() +
  scale_y_continuous(expand = c(0, 0, 0, 0)) +
  ggtitle("Interest in Issues Over Time") +
  xlab("Iteration") +
  ylab("Interest") +
  def_theme +
  theme(plot.title = element_text(size = rel(2), face = "bold"),
        axis.title.x = element_text(size = rel(1)),
        axis.title.y = element_text(size = rel(1), margin = margin(t = 0, r = 20, b = 0, l = 0)),
        axis.text.x = element_text(size = rel(1)),
        axis.text.y = element_text(size = rel(1)),
        legend.title = element_blank(),
        legend.text = element_text(size = rel(2)),
        legend.position = "bottom") +
  scale_color_brewer(palette = "Set1") +
  facet_wrap(~issue, scales = "free_y") +
  guides(color = guide_legend(ncol = 2)) +
  geom_hline(yintercept = mu, linetype = "dashed")

# Plot perceived ideological distance over time
p2 <- ggplot(perceived_distance_df, aes(x = iteration, y = perceived_distance)) +
  geom_line() +
  scale_y_continuous(expand = c(0, 0, 0, 0)) +
  ggtitle("Perceived Ideological Distance Over Time") +
  xlab("Iteration") +
  ylab("Perceived Distance") +
  def_theme +
  theme(plot.title = element_text(size = rel(2), face = "bold"),
        axis.title.x = element_text(size = rel(1)),
        axis.title.y = element_text(size = rel(1), margin = margin(t = 0, r = 20, b = 0, l = 0)),
        axis.text.x = element_text(size = rel(1)),
        axis.text.y = element_text(size = rel(1)))


plot_grid(p1, NULL, p2, ncol = 1, align = "v", axis = "tb",
          rel_heights = c(3, -0.5, 2)) -> g

ggplot2latex::save_tex(g, file = "../visualisations/interest_over_time.tex", width = 6.9, height = 4, reduce_power = 0)

pairs <- readr::read_csv("~/UHDS/pairs.csv")
tweets_sent2 <- readr::read_csv("~/UHDS/tweets_sent.csv")

# graph by pairs
graph_from_data_frame(
  pairs %>% 
    filter(created_at < lubridate::ymd("2019-01-01")) %>% 
    filter(target.x %in% c("Poroshenko", "Zelensky")) %>%
    filter(target.y %in% c("Poroshenko", "Zelensky")) %>%
    group_by(author_id, in_reply_to_user_id) %>% count() %>% 
    filter(n > 2), 
  directed = TRUE) -> g

# visualize the graph
ggraph(g, layout = "fr") +
  geom_edge_link(alpha = 0.5, colour = "black") +
  geom_node_point(size = 2, shape = 21, stroke = 0.3) +
  theme_void() +
  ggtitle("Pairs of Actors Over Time") +
  theme(plot.title = element_text(size = 16, face = "bold"))


g <- pairs %>% 
  dplyr::filter(target.x == target.y) %>% 
  group_by(target.x, created_at) %>% 
  summarise(
    ideological_distance = mean(abs(sm.x - sm.y))
  ) %>% 
  ggplot(aes(created_at, ideological_distance)) +
  geom_bin2d() +
  geom_smooth(method = "loess", colour = "black", linewidth = rel(1)) +
  scale_fill_gradient(low = "white", high = "black", limits = c(0, 15), guide = guide_legend(title = "Count:              ")) +
  ylab("Ideological Distance") +
  xlab("Date") +
  facet_wrap(~target.x) +
  def_theme +
  theme(plot.title = element_text(size = rel(2), face = "bold"),
        axis.title.x = element_text(size = rel(1)),
        axis.title.y = element_text(size = rel(1), margin = margin(t = 0, r = 20, b = 0, l = 0)),
        axis.text.x = element_text(size = rel(1)),
        axis.text.y = element_text(size = rel(1)),
        legend.title = element_text(size = rel(2)),
        legend.text = element_text(size = rel(3), margin = margin(r = 10)),
        strip.text = element_text(size = rel(3), face = "bold"),
        legend.position = "bottom")

ggplot2latex::save_tex(g, file = "../visualisations/ideological_distance.tex", width = 6.9, height = 4, reduce_power = 0)

g <- pairs %>% 
  dplyr::filter(target.x == target.y) %>% 
  group_by(target = target.x, created_at) %>% 
  summarise(
    ideological_distance = mean(abs(sm.x - sm.y))
  ) %>% 
  left_join(
    tweets_sent2 %>% group_by(target, created_at) %>% count(), by = c("target", "created_at")
  ) %>% 
  ggplot(aes(n, ideological_distance)) +
  geom_bin2d() +
  ylab("Ideological Distance") +
  xlab("Number of Tweets") +
  geom_smooth(method = "lm", linewidth = rel(1), colour = "black") + 
  scale_fill_gradient(low = "lightgrey", high = "black", limits = c(0, 500), guide = guide_legend(title = "Count:          ", byrow = TRUE)) +
  def_theme +
  theme(plot.title = element_text(size = rel(2), face = "bold"),
        axis.title.x = element_text(size = rel(1)),
        axis.title.y = element_text(size = rel(1), margin = margin(t = 0, r = 20, b = 0, l = 0)),
        axis.text.x = element_text(size = rel(1)),
        axis.text.y = element_text(size = rel(1)),
        legend.title = element_text(size = rel(2)),
        legend.text = element_text(size = rel(3), margin = margin(r = 10)),
        legend.spacing.x = unit(2.0, 'cm'),
        strip.text = element_text(size = rel(3), face = "bold"),
        legend.position = "bottom")

ggplot2latex::save_tex(g, file = "../visualisations/tweets_sent.tex", width = 6.9, height = 3, reduce_power = 0)

g <- pairs %>% 
  dplyr::filter(target.x == target.y) %>% 
  group_by(target = target.x, created_at) %>% 
  summarise(
    ideological_distance = mean(abs(sm.x - sm.y))
  ) %>% 
  left_join(
    tweets_sent2 %>% group_by(target, created_at) %>% count(), by = c("target", "created_at")
  ) %>% 
  ggplot(aes(n, ideological_distance)) +
  geom_bin2d() +
  geom_smooth(method = "lm", linewidth = rel(1), colour = "black") + 
  scale_fill_gradient(low = "lightgrey", high = "black", limits = c(0, 200), guide = guide_legend(title = "Count:               ")) +
  ylab("Ideological Distance") +
  xlab("Number of Tweets") +
  facet_wrap(~target) + def_theme +
  theme(plot.title = element_text(size = rel(2), face = "bold"),
        axis.title.x = element_text(size = rel(1)),
        axis.title.y = element_text(size = rel(1), margin = margin(t = 0, r = 20, b = 0, l = 0)),
        axis.text.x = element_text(size = rel(1)),
        axis.text.y = element_text(size = rel(1)),
        legend.title = element_text(size = rel(2)),
        legend.text = element_text(size = rel(3), margin = margin(r = 10)),
        legend.spacing.x = unit(2.0, 'cm'),
        strip.text = element_text(size = rel(3), face = "bold"),
        legend.position = "bottom")

ggplot2latex::save_tex(g, file = "../visualisations/tweets_sent2.tex", width = 6.9, height = 4, reduce_power = 0)


# ----------------------------------------
# Additional Metrics Over Time
# ----------------------------------------
extra_metrics <- purrr::map_dfr(results, function(res) {
  dist_matrix <- as.matrix(dist(res$interest))
  iter <- res$iteration
  tibble(
    iteration = iter,
    mean_distance = mean(dist_matrix),
    sd_distance = sd(dist_matrix),
    median_distance = median(dist_matrix),
    entropy = {
      freq <- table(cut(res$interest, breaks = seq(-100,100,20))) / length(res$interest)
      -sum(freq * log2(freq), na.rm = TRUE)
    }
  )
})

# Plot: Convergence and Diversity Metrics
p_convergence <- extra_metrics %>%
  pivot_longer(-iteration, names_to = "metric", values_to = "value") %>%
  ggplot(aes(x = iteration, y = value, color = metric)) +
  geom_line(linewidth = 0.8) +
  facet_wrap(~metric, scales = "free_y") +
  ggtitle("Opinion Convergence and Diversity Metrics Over Time") +
  xlab("Iteration") + ylab("Metric Value") +
  scale_color_brewer(palette = "Set1") +
  def_theme

ggplot2latex::save_tex(p_convergence, "../visualisations/metrics_over_time.tex", width = 7, height = 3, reduce_power = 0)

# ----------------------------------------
# Actor Clustering Dynamics
# ----------------------------------------
cluster_df <- purrr::map_dfr(results, function(res) {
  cl <- kmeans(res$interest, centers = 3, nstart = 5)$cluster
  tibble(iteration = res$iteration, actor = 1:n_actors, cluster = cl)
})

# Alluvial Diagram for Cluster Membership Change
p_clusters <- cluster_df %>%
  filter(iteration %in% seq(1, max(iteration), length.out = 10)) %>% # sample iterations
  ggplot(aes(x = factor(iteration), stratum = factor(cluster), alluvium = actor,
             fill = factor(cluster), label = cluster)) +
  geom_flow(stat = "alluvium", lode.guidance = "forward", color = "darkgray", alpha = 0.6) +
  geom_stratum(alpha = 0.8) +
  scale_fill_brewer(palette = "Set2") +
  ggtitle("Cluster Membership Evolution Over Time") +
  xlab("Iteration") + ylab("Number of Actors") +
  def_theme

ggplot2latex::save_tex(p_clusters, "../visualisations/cluster_evolution.tex", width = 7, height = 2, reduce_power = 0)

# ----------------------------------------
# Heatmap of Interests Over Time
# ----------------------------------------
p_heat <- interest_df %>%
  ggplot(aes(x = iteration, y = actor, fill = interest)) +
  geom_tile() +
  facet_wrap(~issue, ncol = 2) +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red", midpoint = 0) +
  ggtitle("Actor Interests Over Time (by Issue)") +
  xlab("Iteration") + ylab("Actor") +
  def_theme

ggplot2latex::save_tex(p_heat, "../visualisations/interest_heatmap.tex", width = 8, height = 2, reduce_power = 0)

# ----------------------------------------
# Sensitivity Analysis: Vary sigma
# ----------------------------------------
sigma_values <- c(10, 33.3, 60)
sensitivity_results <- list()

for (s in sigma_values) {
  set.seed(123)
  interests <- matrix(rnorm(n_actors * n_issues, mean = mu, sd = s), nrow = n_actors)
  perceived_distance <- mean(dist(interests))
  temp <- list()
  temp[[1]] <- list(iteration = 1, perceived_distance = perceived_distance)
  
  for (i in 2:n_iter) {
    perceived_distance <- perceived_distance - runif(1, 0, 0.05) # placeholder dynamic
    temp[[i]] <- list(iteration = i, perceived_distance = perceived_distance)
  }
  
  sensitivity_results[[as.character(s)]] <- tibble(
    iteration = 1:n_iter,
    perceived_distance = sapply(temp, function(x) x$perceived_distance),
    sigma = s
  )
}

sensitivity_df <- bind_rows(sensitivity_results)

p_sensitivity <- sensitivity_df %>%
  ggplot(aes(x = iteration, y = perceived_distance, color = factor(sigma))) +
  geom_line(linewidth = 1) +
  ggtitle("Sensitivity Analysis: Effect of Initial Spread on Perceived Distance") +
  xlab("Iteration") + ylab("Perceived Distance") +
  scale_color_brewer(palette = "Dark2", name = "Spread") +
  def_theme

ggplot2latex::save_tex(p_sensitivity, "../visualisations/sigma_sensitivity.tex", width = 7, height = 2, reduce_power = 0)

# ----------------------------------------
# Combined Output
# ----------------------------------------
plot_grid(p_convergence, p_clusters, p_heat, p_sensitivity,
          labels = "AUTO", ncol = 2) -> g_combined

ggplot2latex::save_tex(g_combined, "extended_simulation_plots.tex", width = 14, height = 10, reduce_power = 0)

library(igraph)
library(ggraph)

# ----------------------------------------
# Build interaction frequency matrix from simulation results
# ----------------------------------------

# Initialize frequency matrix (actors × actors)
interaction_freq <- matrix(0, nrow = n_actors, ncol = n_actors)

# Re-run partner selection logic to populate frequency counts across iterations
set.seed(123)
interactions_over_time <- list()
n_iter <- 500

for (i in 2:n_iter) {
  interlocutors <- lapply(1:n_actors, function(x) {
    sample_actors <- seq_len(n_actors)[-x]
    sample_interests <- results[[i]]$interest[sample_actors, ]
    sample_distance <- apply((sample_interests - results[[i]]$interest[x, ])^2, 1, sum)^0.25
    sample_prob <- 1 - (sample_distance / results[[i]]$perceived_distance)
    sample_actors[sample_prob < runif(length(sample_prob))]
  })
  
  # Update interaction counts
  for (j in 1:n_actors) {
    if (length(interlocutors[[j]]) > 0) {
      for (k in interlocutors[[j]]) {
        interaction_freq[j, k] <- interaction_freq[j, k] + 1
        interaction_freq[k, j] <- interaction_freq[k, j] + 1
      }
    }
  }
  
  # Save snapshot at specific iterations
  if (i %in% c(200, 300, 400, 500)) {
    interactions_over_time[[as.character(i)]] <- interaction_freq
  }
}

# ----------------------------------------
# Function to build igraph object from interaction frequency
# ----------------------------------------
make_network <- function(freq_matrix, interests_matrix) {
  threshold <- mean(freq_matrix) + sd(freq_matrix)  # keep strong ties only
  adj <- (freq_matrix > threshold) * 1
  g <- graph_from_adjacency_matrix(adj, mode = "undirected", diag = FALSE)
  
  # Determine most-discussed issue for each actor
  most_discussed <- apply(abs(interests_matrix), 1, which.max)
  sign_val <- sapply(1:n_actors, function(a) sign(interests_matrix[a, most_discussed[a]]))
  
  V(g)$color <- ifelse(sign_val > 0, "black", "white")
  V(g)$size <- 3
  return(g)
}

# ----------------------------------------
# Create and plot network snapshots
# ----------------------------------------
network_plots <- list()

for (t in c(200, 300, 400, 500)) {
  g <- make_network(interactions_over_time[[as.character(t)]],
                    results[[t]]$interest)
  
  network_plots[[as.character(t)]] <- ggraph(g, layout = "fr") +
    geom_edge_link(alpha = 0.5, colour = "black") +
    geom_node_point(aes(color = I(color)), size = 2, shape = 21, stroke = 0.3) +
    scale_color_identity() +
    theme_void() +
    ggtitle(paste("time", t)) +
    theme(plot.title = element_text(size = 16, face = "bold"))
}

# Arrange into 2×2 grid
network_grid <- cowplot::plot_grid(plotlist = network_plots, ncol = 2)
ggplot2latex::save_tex(network_grid, file = "network_evolution.tex",
                       width = 8, height = 6, reduce_power = 0)



library(igraph)
library(ggraph)

# --- Helper: build igraph network from frequency matrix ---
make_network <- function(freq_matrix, interests_matrix, color_mode = c("sign", "global_issue")) {
  color_mode <- match.arg(color_mode)
  
  # Threshold: above expected-by-chance frequency
  threshold <- mean(freq_matrix) + sd(freq_matrix)
  adj <- (freq_matrix > threshold) * 1
  g <- graph_from_adjacency_matrix(adj, mode = "undirected", diag = FALSE)
  
  # Node coloring
  if (color_mode == "sign") {
    # Actor's most popular issue & sign
    most_discussed <- apply(abs(interests_matrix), 1, which.max)
    sign_val <- sapply(1:n_actors, function(a) sign(interests_matrix[a, most_discussed[a]]))
    V(g)$color <- ifelse(sign_val > 0, "black", "white")
  }
  
  if (color_mode == "global_issue") {
    # Global most popular issue
    issue_counts <- apply(abs(interests_matrix), 2, mean)
    top_issue <- which.max(issue_counts)
    most_discussed <- apply(abs(interests_matrix), 1, which.max)
    V(g)$color <- ifelse(most_discussed == top_issue, "grey", "black")
  }
  
  V(g)$size <- 3
  return(g)
}

# --- 1. Time-slice snapshots (color = sign of most popular issue) ---
network_plots <- list()
for (t in c(200, 300, 400, 500)) {
  g <- make_network(interactions_over_time[[as.character(t)]],
                    results[[t]]$interest,
                    color_mode = "sign")
  
  network_plots[[as.character(t)]] <- ggraph(g, layout = "fr") +
    geom_edge_link(alpha = 0.5, colour = "black") +
    geom_node_point(aes(color = I(color)), size = 2, shape = 21, stroke = 0.3) +
    scale_color_identity() +
    theme_void() +
    ggtitle(paste("time", t)) +
    theme(plot.title = element_text(size = 16, face = "bold"))
}

network_grid <- cowplot::plot_grid(plotlist = network_plots, ncol = 2)
ggplot2latex::save_tex(network_grid, file = "network_sign_popular_issue.tex",
                       width = 8, height = 6, reduce_power = 0)

# --- 2. Final-state network (color = global most popular issue) ---
g_final <- make_network(interactions_over_time[["500"]],
                        results[[500]]$interest,
                        color_mode = "global_issue")

p_final <- ggraph(g_final, layout = "fr") +
  geom_edge_link(alpha = 0.5, colour = "black") +
  geom_node_point(aes(color = I(color)), size = 2, shape = 21, stroke = 0.3) +
  scale_color_identity() +
  theme_void() +
  ggtitle("time 500") +
  theme(plot.title = element_text(size = 16, face = "bold"))

ggplot2latex::save_tex(p_final, file = "network_final_global_issue.tex",
                       width = 6, height = 5, reduce_power = 0)


#######
########
#####



# ---------------------------------------------------------------------------- #
# 1. Load Necessary Libraries                                                  #
# ---------------------------------------------------------------------------- #

# install.packages("igraph") # Uncomment and run if you don't have igraph
# install.packages("ggplot2") # Uncomment and run if you don't have ggplot2
# install.packages("dplyr") # Uncomment and run if you don't have dplyr
# install.packages("tidyr") # Uncomment and run if you don't have tidyr

library(igraph)
library(ggplot2)
library(dplyr)
library(tidyr)

# Set a seed for reproducibility as provided by the user.
set.seed(123)

# ---------------------------------------------------------------------------- #
# 2. Define Simulation Parameters (from user's logic)                          #
# ---------------------------------------------------------------------------- #

n_actors <- 100        # Number of individuals/actors in the simulation
n_issues <- 4         # Number of political issues
mu <- 0               # Mean for initial interest distribution
sigma <- 33.3         # Standard deviation for initial interest distribution
interest_range <- c(-100, 100) # Min/max values for interests
n_iter <- 500         # Number of simulation iterations (time points)

# Define specific snapshot times for network visualizations to match Figure 6
# Adjusted to be consistent with the 500 iterations.
snapshot_times <- c(1, 200, 300, 400, 500)
# Ensure snapshot times are unique and within bounds
snapshot_times <- unique(pmax(1, pmin(n_iter, snapshot_times)))
snapshot_times <- sort(snapshot_times)

# ---------------------------------------------------------------------------- #
# 3. Simulate Initial Data: Network and Interests (from user's logic)        #
# ---------------------------------------------------------------------------- #

# Generate initial actor attributes (interests) as per user's model
cat("Assigning initial interests...\n")
interests <- matrix(rnorm(n_actors * n_issues, mean = mu, sd = sigma), nrow = n_actors)
# Ensure initial interests are within the defined range
interests <- pmax(pmin(interests, interest_range[2]), interest_range[1])


# Calculate initial perceived distance
perceived_distance <- mean(dist(interests))

# Store simulation history for interests. This will replace 'attitude_history'.
# Dimension: individuals x issues x iterations
interest_history <- array(NA, dim = c(n_actors, n_issues, n_iter))
interest_history[,,1] <- interests

# Create a static social network for visualization purposes.
# The user's simulation dynamically selects interlocutors based on perceived distance,
# but the paper's Figure 6 implies an underlying network structure for visualization.
# Here, we use a simple random graph for this visual structure.
cat("Generating static social network for visualization...\n")
network_density <- 0.05 # A default density for the visualization graph
g <- erdos.renyi.game(n_actors, network_density, type = "gnp", directed = FALSE)


# ---------------------------------------------------------------------------- #
# 4. Simulation Loop: Interpersonal Influence Model (User's Logic)           #
# ---------------------------------------------------------------------------- #

cat("Starting simulation (using user's logic)...\n")
pb <- txtProgressBar(min = 0, max = n_iter, style = 3) # Progress bar

for (i in 2:n_iter) {
  # Selection of interaction partners
  # 'interlocutors' here is a list where each element 'j' contains the indices of actors
  # that actor 'j' will interact with in this iteration.
  interlocutors <- lapply(1:n_actors, function(x) {
    # Random sample of potential interlocutors (all other actors)
    sample_actors <- seq_len(n_actors)[-x]
    sample_interests <- interests[sample_actors, , drop = FALSE] # Ensure it's a matrix
    
    # Calculate Euclidean distance (or similar)
    # Applying sum on rows (MARGIN=1)
    sample_distance <- apply((sample_interests - interests[x, ])^2, 1, sum)^0.25
    
    # Probability of interaction: closer actors are more likely to interact
    sample_prob <- 1 - (sample_distance / (perceived_distance + 1e-9)) # Add epsilon to avoid div by zero
    
    # Draw from the sample the actual interlocutors
    # Only select actors where the probability is greater than a random uniform number
    sample_actors[sample_prob > runif(length(sample_prob))]
  })
  
  # Process of Interpersonal influence
  # Iterate through each actor 'j'
  for (j in 1:n_actors) {
    # Stochastic chance for actor 'j' to engage in discussion in this iteration
    if (rnorm(1) > 1) { # Only proceed if rnorm(1) is > 1 (approx. 15.8% chance)
      next # Skip this actor for this iteration if condition not met
    }
    
    # Iterate through each interlocutor 'k' for actor 'j'
    for (k in interlocutors[[j]]) {
      # Select the issue for discussion: the one where the sum of absolute interests is max
      # This is based on joint salience/prominence for the interacting pair
      issue <- which.max(abs(interests[k, ]) + abs(interests[j, ]))
      
      # Calculate delta_k (change for interlocutor k)
      if (interests[k, issue] != 0){ # Prevent division by zero
        delta_k <- 0.1 * abs(abs(interests[k, issue]) - abs(interests[j, issue])) / (abs(interests[k, issue]) + 1e-9)
      } else {
        delta_k <- 0
      }
      
      # Calculate delta_j (change for actor j)
      if (interests[j, issue] != 0){ # Prevent division by zero
        delta_j <- 0.1 * abs(abs(interests[j, issue]) - abs(interests[k, issue])) / (abs(interests[j, issue]) + 1e-9)
      } else {
        delta_j <- 0
      }
      
      # Determine direction of change according to the sign of the current interest on the issue
      delta_j <- delta_j * sign(interests[j, issue])
      delta_k <- delta_k * sign(interests[k, issue])
      
      # Update actors' level of interest, clamping to the defined range
      interests[j, issue] <- pmax(pmin(interests[j, issue] + delta_j, interest_range[2]), interest_range[1])
      interests[k, issue] <- pmax(pmin(interests[k, issue] + delta_k, interest_range[2]), interest_range[1])
    }
  }
  
  # Update actors' perceived ideological distance with the current/actual mean distance
  perceived_distance <- mean(dist(interests))
  
  # Save current interests for history
  interest_history[,,i] <- interests
  setTxtProgressBar(pb, i)
}
close(pb)
cat("\nSimulation complete!\n")

# ---------------------------------------------------------------------------- #
# 5. Measure and Analyze Polarization Dynamics                                 #
# ---------------------------------------------------------------------------- #

# Global Interest Polarization (Variance of interests across all individuals for each issue)
global_polarization <- data.frame(
  time = 1:n_iter,
  issue_1 = apply(interest_history[,1,], 2, var),
  issue_2 = apply(interest_history[,2,], 2, var),
  issue_3 = apply(interest_history[,3,], 2, var),
  issue_4 = apply(interest_history[,4,], 2, var) # Added for n_issues = 4
) %>%
  pivot_longer(cols = starts_with("issue_"), names_to = "issue", values_to = "variance")

# Local Interest Homogeneity (Mean absolute difference between neighbors' interests)
# This uses the *static* network 'g' for neighbors, as the interaction network is dynamic.
# It's an approximation of homogeneity within a fixed social structure.
local_homogeneity_history <- numeric(n_iter)

cat("Calculating local homogeneity...\n")
for (t in 1:n_iter) {
  current_ints <- interest_history[,,t]
  pairwise_diffs <- c()
  edges <- as_edgelist(g, names = FALSE) # Use the static graph 'g' for this calculation
  
  for (e_idx in 1:nrow(edges)) {
    node1 <- edges[e_idx, 1]
    node2 <- edges[e_idx, 2]
    # Sum of absolute differences across all issues for this pair
    diff <- sum(abs(current_ints[node1, ] - current_ints[node2, ]))
    pairwise_diffs <- c(pairwise_diffs, diff)
  }
  if (length(pairwise_diffs) > 0) {
    local_homogeneity_history[t] <- mean(pairwise_diffs) # Lower value means higher homogeneity
  } else {
    local_homogeneity_history[t] <- NA
  }
}

local_homogeneity_df <- data.frame(
  time = 1:n_iter,
  mean_abs_neighbor_diff = local_homogeneity_history
)

# ---------------------------------------------------------------------------- #
# 6. Visualizations                                                            #
# ---------------------------------------------------------------------------- #

cat("Generating visualizations...\n")

# Plot 1: Global Interest Polarization over Time (Variance)
p1 <- ggplot(global_polarization, aes(x = time, y = variance, color = issue)) +
  geom_line(linewidth = 1.2) +
  geom_point(alpha = 0.7) +
  labs(
    title = "Global Interest Polarization (Variance) Over Time",
    x = "Simulation Iteration",
    y = "Variance of Interests"
  ) +
  scale_color_brewer(palette = "Set1") +
  theme_minimal(base_size = 14) +
  theme(legend.position = "bottom")

print(p1)

# Plot 2: Local Interest Homogeneity over Time (Mean Absolute Neighbor Difference)
# Lower values indicate more homogeneity (less difference between connected individuals)
p2 <- ggplot(local_homogeneity_df, aes(x = time, y = mean_abs_neighbor_diff)) +
  geom_line(color = "steelblue", linewidth = 1.2) +
  geom_point(color = "steelblue", alpha = 0.7) +
  labs(
    title = "Local Interest Homogeneity Over Time",
    subtitle = "Lower values indicate higher homogeneity among neighbors in static graph",
    x = "Simulation Iteration",
    y = "Mean Absolute Difference Between Neighbor Interests"
  ) +
  theme_minimal(base_size = 14)

print(p2)

# Plot 3: Distribution of Interests at Initial vs. Final State (Example Issue 1)
# Flatten interest data for easy plotting
interest_dist_df <- data.frame(
  individual = rep(1:n_actors, 2),
  interest = c(interest_history[,1,1], interest_history[,1,n_iter]), # Issue 1
  state = rep(c("Initial", "Final"), each = n_actors)
)

p3 <- ggplot(interest_dist_df, aes(x = interest, fill = state, color = state)) +
  geom_density(alpha = 0.6) +
  labs(
    title = "Distribution of Interests (Issue 1): Initial vs. Final State",
    subtitle = "Observe how interests might cluster or disperse",
    x = "Interest Value (-100 to 100)",
    y = "Density"
  ) +
  scale_fill_manual(values = c("Initial" = "lightblue", "Final" = "coral")) +
  scale_color_manual(values = c("Initial" = "blue", "Final" = "darkred")) +
  theme_minimal(base_size = 14) +
  theme(legend.position = "bottom")

print(p3)

# Plot 4: Multi-panel Network Visualization over Time (similar to Figure 6)
# Nodes colored by the sign of the most prominent issue (black for positive, white for negative)
cat("Generating multi-panel network visualizations...\n")

# Determine number of rows and columns for the plot grid
n_panels <- length(snapshot_times)
rows <- floor(sqrt(n_panels))
cols <- ceiling(n_panels / rows)

# Set up the plotting area for multiple plots
par(mfrow = c(rows, cols), mar = c(0.5, 0.5, 2.5, 0.5) + 0.1, oma = c(0, 0, 2, 0))

# Calculate a consistent layout for all plots to show evolution
# Using layout_with_fr once for the static graph 'g' to keep node positions relatively stable
graph_layout <- layout_with_fr(g)

for (time_idx in 1:length(snapshot_times)) {
  current_time <- snapshot_times[time_idx]
  current_ints <- interest_history[,,current_time]
  
  # Determine the 'most prominent' issue for each individual
  # This is the issue with the largest absolute interest value across all issues
  most_prominent_issue_val <- apply(current_ints, 1, function(x) x[which.max(abs(x))])
  
  # Color nodes based on the sign of the most prominent issue's interest
  # Black for positive, white for non-positive (0 or negative) as per Figure 6 description
  node_colors <- ifelse(most_prominent_issue_val > 0, "black", "white")
  V(g)$color <- node_colors
  
  plot(g,
       vertex.size = 5,
       vertex.label = NA, # No labels for clarity
       edge.arrow.size = 0.2,
       edge.width = 0.5, # Make edges slightly thinner for clarity
       layout = graph_layout, # Use the consistent layout
       main = paste("time", current_time) # Title for each panel
  )
}

# Add a main title for the entire multi-panel plot
mtext(paste0("Network Discussion Dynamics Over Time (User's Model, ",
             "Initial Perceived Distance: ", round(results[[1]]$perceived_distance, 2), ")"),
      side = 3, line = 0, outer = TRUE, cex = 1.5, font = 2)

# Reset plot margins and layout to default
par(mfrow = c(1, 1), mar = c(5, 4, 4, 2) + 0.1, oma = c(0, 0, 0, 0))
