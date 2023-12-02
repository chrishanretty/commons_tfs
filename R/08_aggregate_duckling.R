library(tidyverse)
library(arrow)
library(doParallel)
library(foreach)
here::i_am("R/08_aggregate_duckling.R")

parse_json <- function(json) {
    x <- jsonlite:::parse_string(json, bigint_as_char=F)
### This will return a list with number of entries equal to number of references
### Each list with type "value" within the list will have six entries:
    ## - start
    ## - value (a list of lists)
    ## - the value itself
    ## - the type
    ## - the grain
    parse_hit <- function(l) {
        type <- l$value$type
        if (type == "value") {
            retval <- l$value$values[[1]]$value
            retval <- substr(retval, start = 0, stop = 10)
            ## retval <- as.Date(retval, format = "%Y-%m-%d")
            return(retval)
            ## do something
        } else if (type == "interval") {
            if ("to" %in% names(l$value)) { 
                retval <- l$value$to$value
                retval <- substr(retval, start = 0, stop = 10)
                return(retval)
            } else {
                retval <- l$value$from$value
                retval <- substr(retval, start = 0, stop = 10)
                return(retval)
            }
            
            ## return the value of the end of the interval
        } else { 
            return(NA_character_)
            }
        
    }
### If there is nothing there, return early
    nothing <- length(x) == 0
    if (nothing) {
        return(data.frame(pattern = NA_character_,
                          dates = as.Date(NA_character_,
                                          format = "%Y-%m-%d")))
    }

    ### otherwise continue
    texts <- sapply(x, function(l) l$body)
    dates <- sapply(x, parse_hit)
    dates <- as.Date(dates, format = "%Y-%m-%d")
    
    return(data.frame(dates = dates,
               pattern = texts))
}

parse_file <- function(f) { 
    dat <- readRDS(f)
    ref_date <- sub(".*debates", "", f)
    ref_date <- gsub("[^0-9]", "", ref_date)
    ref_date <- as.Date(ref_date, format = "%Y%m%d")
    duckling <- dat |>
        filter(json != "[]") |>
                filter(json != "Need a 'text' parameter to parse") |>
                as_tibble() |>
        mutate(listcol = map(json, parse_json)) |>
        dplyr::select(speech_id, docid, listcol) |>
        unnest(cols = listcol)

    ### Maybe we pick up no dates at all
    if (!is.element("dates", names(duckling))) {
        duckling$dates <- as.Date(NA)
    }
    
    duckling <- duckling |>
        mutate(delta = dates - ref_date,
               ltr = delta > (365.25 * 4)) |>
        group_by(speech_id, docid) |>
        summarize(ltr = as.numeric(any(ltr == 1)),
                  .groups = "drop")
    dat <- left_join(dat, duckling,
                     by = join_by(speech_id, docid),
                     relationship = "one-to-one") |>
        mutate(ltr = coalesce(ltr, 0))
    aux <- sub("duckling","debates", f) |>
        readRDS() |>
        dplyr::select(sents, speech_id, docid) |>
        mutate(nchars = nchar(sents))
    dat <- left_join(dat, aux,
                     by = join_by(speech_id, docid),
                     relationship = "one-to-one")
### Aggregate to speaker by nchars
    dat <- dat |>
        mutate(date = ref_date) |>
        group_by(speaker, person, date,
                 heading, oral_heading) |>
        summarize(ltr = sum(ltr, na.rm = TRUE),
                  nchars = sum(nchars, na.rm = TRUE),
                  .groups = "drop") |>
        as.data.frame()
    return(dat)
}
### Read in a file; work out whether there are future references > 4 years
infiles <- list.files(here::here("working/duckling"),
                      full.names = TRUE)


num_cores <- 20
cl <- makeCluster(num_cores)
registerDoParallel(cl)
clusterEvalQ(cl, library(tidyverse))
clusterEvalQ(cl, library(arrow))

dat <- foreach(i=infiles,.combine = 'bind_rows') %dopar% {
    parse_file(i)
}


stopCluster(cl)

dat$speaker <- factor(dat$speaker)
dat$person <- factor(dat$person)
dat <- as.data.frame(dat)

saveRDS(dat, file = here::here("outputs", "daily_speaker_by_heading_duckling.rds"))
