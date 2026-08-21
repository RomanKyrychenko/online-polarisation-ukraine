suppressPackageStartupMessages({
  library(ggplot2)
  library(reshape2)
  library(cowplot)
  library(dplyr)
})

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

for (i in 2:n_iter) {
  print(i)
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


interest_df <- purrr::map_dfr(
  results, ~as_tibble(.$interest) %>% 
    mutate(actor = 1:n_actors) %>% 
    tidyr::pivot_longer(V1:V4, names_to = "issue", values_to = "interest"), .id = "iteration") %>% 
  mutate(iteration = as.numeric(iteration),
         issue = stringr::str_replace_all(issue, "V", "Topic "))

perceived_distance_df <- tibble(
  iteration = 1:n_iter,
  perceived_distance = sapply(results, function(x) x$perceived_distance)
  )

def_theme <- hrbrthemes::theme_ipsum(base_family = "Lato", base_size = 5, plot_title_size = 8, axis_title_size = 6, subtitle_size = 7, strip_text_size = 3.5) +
  theme(
    panel.grid = element_line(linetype = "dotted", linewidth = 0.1),
    panel.spacing.y = unit(0.5, "lines")
  )

interest_df[interest_df$iteration %in% c(1, 100, 200, 500), ] %>% 
  ggplot(aes(interest)) +
  geom_histogram() +
  facet_grid(iteration~issue) +
  def_theme

p1 <- ggplot(interest_df %>% filter(actor==1), 
             aes(x = iteration, y = interest, color = issue, group=issue)) +
  geom_path() +
  ggtitle("Interest in Issues Over Time") +
  xlab("Iteration") +
  ylab("Interest") +
  scale_color_brewer(palette = "Set1") +
  facet_wrap(~issue) + #, scales = "free_y") +
  guides(color = guide_legend(ncol = 2)) +
  geom_hline(yintercept = mu, linetype = "dashed") +
  def_theme

# Plot perceived ideological distance over time
p2 <- ggplot(perceived_distance_df, aes(x = iteration, y = perceived_distance)) +
  geom_line() +
  ggtitle("Perceived Ideological Distance Over Time") +
  xlab("Iteration") +
  ylab("Perceived Distance") +
  def_theme


plot_grid(p1, p2, ncol = 1, align = "v", axis = "tb",
          rel_heights = c(2, 1))
