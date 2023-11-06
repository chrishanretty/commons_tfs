library(tidyverse)
library(arrow)
library(doParallel)
library(foreach)
here::i_am("R/07_aggregate.R")

infiles <- list.files(here::here("working/distilled"),
                      full.names = TRUE)

parse_file <- function(i) {
    the_date <- sub(".*debates", "", i)
    the_date <- gsub("[^0-9]", "", the_date)
    the_date <- as.Date(the_date, format = "%Y%m%d")
    ### Aggregate to speaker/topic/da
    retval <- read_parquet(i) |>
        mutate(date = the_date) |>
        mutate(speaker = as.character(speaker),
               person = as.character(person)) |>
        dplyr::select(-docid, -newtext) |>
        group_by(speaker, person, date,
                 heading, oral_heading) |>
        summarize(Present = mean(Present, na.rm = TRUE),
                  Past = mean(Past, na.rm = TRUE),
                  Future = mean(Future, na.rm = TRUE),
                  .groups = "drop") |>
        as.data.frame()
    return(retval)
}

num_cores <- 20
cl <- makeCluster(num_cores)
registerDoParallel(cl)
clusterEvalQ(cl, library(tidyverse))
clusterEvalQ(cl, library(arrow))
Sys.time()
dat <- foreach(i=infiles,.combine = 'bind_rows') %dopar% {
    parse_file(i)
}
Sys.time()

stopCluster(cl)

saveRDS(dat, file = here::here("outputs", "daily_speaker_by_heading.rds"))
