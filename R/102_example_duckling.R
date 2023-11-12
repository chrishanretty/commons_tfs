library(here)
library(tidyverse)
set.seed(1163)

here::i_am("R/102_example_duckling.R")

files <- list.files(here::here("working/ducked"),
                    pattern = "debates.*",
                    full.names = TRUE)

#f <- "working/duckling/debates1974-12-18a.rds"
f <- sample(files, 1)
### Get the corresponding original
orig <- sub("ducked", "debates", f)
orig <- readRDS(orig)

dat <- readRDS(f)

dat <- left_join(dat, orig,
                 by = join_by(speaker, person, date, heading,
                              oral_heading, speech_id, docid))
