### PURPOSE OF THIS CODE: to read in the sentences and pass them to duckling, which will return a JSON file

### Load libraries
library(tidyverse)
library(jsonlite)

here::i_am("R/03_get_duckling.R")

### Make sure there's a duckling server running on port 8000
duckling <- function(x, ref_datetime) {
    if (!inherits(ref_datetime, "POSIXct")) {
        stop("ref_datetime must have class POSIXct")
    }


    ref <- paste0(format(as.integer(ref_datetime) * 1000, scientific = FALSE))

    sys_call_pre <- "curl -XPOST http://0.0.0.0:8000/parse --data "

    ### if we shQuote, it wraps in single quotes, which we don't want
    x <- shQuote(paste0("locale=en_GB&text=",
                        x,
                        "&dims=[\"time\"]&reftime=",
                        ref
                        ))

    syscall <- paste0(sys_call_pre,
                      x)
    
    retval <- system(syscall,
           intern = TRUE,
           ignore.stdout = FALSE,
           ignore.stderr = TRUE)
    
    if ("status" %in% names(attributes(retval))) {
        warning(syscall)
        retval <- "[]"
    }
    
    retval <- paste(retval, collapse = "\n")
    return(retval)
}

handle_file <- function(f) {
    require(tidyverse)
    outfile <- sub("working/debates/", "working/duckling", f, fixed = TRUE)
    if (file.exists(outfile)) {
        return(TRUE)
    }
    
    ref_date <- gsub("[^0-9]", "", f)
    ref_datetime <- paste0(ref_date, " 11:59")
    ref_datetime <- as.POSIXct(ref_datetime,
                               format = "%Y%m%d %H:%M")
    dat <- readRDS(f)
    dat <- dat |>
        mutate(json = map_chr(sents, duckling, ref_datetime)) |>
        dplyr::select(-sents)
###
    saveRDS(dat, outfile)
    return(TRUE)
}

infiles <- list.files(here::here("working/debates/"),
                      pattern = "debate.*.rds",
                      full.names = TRUE)

### shuffle
infiles <- sample(infiles, size = length(infiles), replace = FALSE)
### 10 files = 137seconds single-threaded
### 20 files = 44 seconds 20-threaded

### This is definitely an overnight-and-next-morning job; there are
### one or two files that choke the duckling handlers

library(parallel)
cl <- makeCluster(20)
clusterExport(cl, "duckling")
system.time(res <- parLapply(cl, infiles, handle_file))
stopCluster(cl)
