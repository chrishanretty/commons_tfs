library(here)
library(tidyverse)
here::i_am("R/102_example_duckling.R")

files <- list.files(here::here("working/duckling"),
                    pattern = "debates199.*",
                    full.names = TRUE)

dat <- bind_rows(lapply(files, readRDS))
dat <- dat |>
    filter(json != "[]") |>
    filter(json != "Need a 'text' parameter to parse")

nrow(dat)
