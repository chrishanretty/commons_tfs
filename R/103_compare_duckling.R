library(tidyverse)
here::i_am("R/103_compare_duckling.R")

no_duck <- readRDS(here::here("outputs", "daily_speaker_by_heading_no_duckling.rds"))
has_duck <- readRDS(here::here("outputs", "daily_speaker_by_heading.rds"))

dat <- left_join(has_duck,
                 no_duck,
                 by = join_by(speaker, person, date, heading, oral_heading),
                 suffix = c("", ".noduck")) |>
    filter(!is.na(nchars))

dat <- dat |>
    group_by(date) |>
    summarize(Future = weighted.mean(Future, nchars),
              Future.noduck = weighted.mean(Future.noduck, nchars))

plot_df <- dat |>
    dplyr::select(date, Future, Future.noduck) |>
    pivot_longer(cols = c(Future, Future.noduck))

ggplot(plot_df, aes(x = date, y = value,
                    colour = name)) +
    geom_point(alpha = 1/50) +
    geom_smooth(se = FALSE) + 
    theme_bw()
