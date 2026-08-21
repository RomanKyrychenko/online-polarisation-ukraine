# Baldassarri and Bearman (2007) polarisation simulations

suppressPackageStartupMessages({
  require(ggplot2)
  require(dplyr)
})

load("../data/baldassari_bearman_sim.rdata")

p <- p$data %>% 
  mutate(
    iteration = case_when(
      iteration == 1 ~ " 1st iter",
      iteration == 100 ~ "100th iter",
      iteration == 200 ~ "200th iter",
      iteration == 500 ~ "500th iter",
    )
  ) %>% 
  ggplot(aes(interest)) +
  geom_histogram(binwidth = 20) +
  ylab("Count") +
  xlab("Interest") +
  facet_grid(iteration~issue) +
  hrbrthemes::theme_ipsum(
    base_family = "Georgia", base_size = rel(2), 
    plot_title_size = rel(2), axis_title_size = rel(2), subtitle_size = rel(2)
    ) +
  theme(
    panel.grid = element_line(linetype = "dotted", linewidth = 0.1),
    panel.spacing.y = unit(0.1, "lines"),
    panel.spacing.x = unit(0.1, "lines"),
    
    # Axis Text (The numbers -100, 0, 100)
    axis.text = element_text(size = rel(0.5)), 
    
    # Axis Titles (Controls "count", "interest", AND your custom "Topic"/"Iterations")
    axis.title.x = element_text(size = rel(0.8), face = "bold", margin = margin(t = 5, r = 0, b = 0, l = 0)),
    axis.title.y = element_text(size = rel(0.8), face = "bold", margin = margin(t = 0, r = 5, b = 0, l = 0)),
    
    # Strip Text (The headers: "Topic 1" and "1", "100")
    # Make these clearly visible.
    strip.text.x = element_text(size = rel(0.4), face = "bold", hjust = 0.5),
    
    # Ensure the right-side text (y-strips) is rotated correctly
    strip.text.y = element_text(size = rel(0.4), face = "bold", angle = -90), # Usually 0 is easier to read for iterations, or -90
    
    # Add some breathing room for the outer labels
    plot.margin = margin(0, 0, 0, 0),
    axis.title.x.top = element_text(size = rel(1), face = "bold"),
    
    # Make the "Iterations" label smaller and adjust rotation
    axis.title.y.right = element_text(size = rel(1), face = "bold", angle = -90),
  ) 

ggplot2latex::save_tex(p, file = "../visualisations/baldassari_bearman_sim.tex", width = 3.5, height = 2.5, reduce_power = 0)
