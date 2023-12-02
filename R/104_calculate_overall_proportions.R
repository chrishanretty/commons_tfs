library(tidyverse)
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
        mutate(nchars = nchar(newtext))
### return the total number of sentences and average proportions
    retval <- retval |>
        ungroup() |>
        summarize(nsents = n(),
                  uw_Future = mean(Future, na.rm = TRUE),
                  wtd_Future = weighted.mean(Future, nchars),
                  uw_Past = mean(Past, na.rm = TRUE),
                  wtd_Past = weighted.mean(Past, nchars))

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
