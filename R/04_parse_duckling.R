library(tidyverse)
library(purrr)

here::i_am("R/04_parse_duckling.R")

infiles <- list.files(here::here("working/debates"),
                      pattern = "*.rds",
                      full.names = TRUE)

### How would I parse this?
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

difftime_to_text <- function(x, level = 1) {
    ## level 1 = year
    ## level 2 = year and month
    ## print(class(x))
    sign_x <- sign(x)
    if (is.na(sign_x)) {
        return(NA_character_)
    }
    if (sign_x == 0) {
        return(NA_character_)
    }
    x <- abs(x)
    
    years <- floor(as.numeric(x) / 365.25)
    residual <- as.numeric(x) - (365.25 * years)
    months <- floor(residual / 30)
    if (level == 1) {
        r <- case_when(years == 0 ~ "less than a year ",
                       years == 1 ~ "one year ",
                       years > 1 ~ paste0(years, " years "))
    } else if (level == 2) {
        r <- case_when(years == 0 & months == 1 ~ "one month ",
                       years == 0 & months > 1 ~ paste0(months, " months "),
                       years == 1 & months == 0 ~ "one year ",
                       years == 1 & months == 1 ~ "one year and one month ",
                       years == 1 & months > 1 ~ paste0("one year and ",
                                                       months, " months "),
                       years > 1 & months == 0 ~ paste0(years, " years "),
                       years > 1 & months == 1 ~ paste0(years, " years and one month "),
                       years > 1 & months > 1 ~ paste0(years, " years and ",
                                                       months, " months "))
    }
    r <- paste0(r, ifelse(sign_x == 1, "from now", "ago"))
    return(r)
}

replace_multiple <- function(text, df, date) {
    if (is.null(df)) {
### Early return
        return(text)
    }
    df$delta <- df$dates - date
    df <- df |>
        filter(delta != 0)
    for (i in seq_len(nrow(df))) {

### if the pattern looks like a year
                if (grepl("(19|20)[0-9]{2}", df$pattern[i])) {
                    text <- sub(df$pattern[i],
                                replacement = difftime_to_text(df$delta[i]),
                                text)
                }
                
    }
    return(text)
}

### for each file
infiles <- sample(infiles, size = length(infiles), replace = FALSE)

for (f in infiles) {
    outfile <- sub("/debates/","/ducked/", f, fixed = TRUE)
    if (file.exists(outfile)) {
    } else { 
        print(f)
        main <- readRDS(f) |>
            as_tibble()
        duckling_file <- sub("/debates/","/duckling/", f, fixed = TRUE)
        if (!file.exists(duckling_file)) {
            main <- main |>
                dplyr::select(speaker, person, date,
                              heading, oral_heading,
                              speech_id, docid, newtext = sents) |>
                as.data.frame()
        } else { 
            duckling <- readRDS(duckling_file)
            duckling <- duckling |>
                filter(json != "[]") |>
                filter(json != "Need a 'text' parameter to parse") |>
                as_tibble() |>
                mutate(listcol = map(json, parse_json)) 

            main <- left_join(main, duckling,
                              by = join_by(speaker, person, date,
                                           heading, oral_heading,
                                           speech_id, docid))

            the_date <- sub(".*debates", "", f)
            the_date <- gsub("[^0-9]", "", the_date)
            the_date <- as.Date(the_date, format = "%Y%m%d")
            
### Map over the text and the df
            main <- main |>
                mutate(newtext = map2_chr(.x = sents,
                                          .y = listcol,
                                          .f = replace_multiple,
                                          date = the_date))
            
            main <- main |>
                dplyr::select(speaker, person, date,
                              heading, oral_heading,
                              speech_id, docid, newtext) |>
                as.data.frame()
        }

### Save the output

        saveRDS(main, outfile)
    }
}
