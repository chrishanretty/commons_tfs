handle_date <- function(x) {
    x <- sub("scrapedxml/debates//debates", "", x, fixed = TRUE)
    x <- sub(".xml", "", x, fixed = TRUE)
    x <- substr(x, 0, 10)
    as.Date(x, format = "%Y-%m-%d")
}

handle_speech_id <- function(ns) {
    retval <- xml_attr(ns, "id")
    if (length(retval) == 0) {
        retval <- NA_character_
    }
    retval
}

check_whether_speaker <- function(ns) {
    retval <- xml_attr(ns, "speakername")
    if (length(retval) == 0) {
        retval <- FALSE
    } else {
        retval <- grepl("Speaker$", retval)
    }
    retval
    
}

handle_speaker <- function(ns) {
### This changes after 2015, when we need person_id instead
    retval <- xml_attr(ns, "speakerid")
    if (length(retval) == 0) {
        retval <- NA_character_
    }
    retval
}

handle_person <- function(ns) {
    retval <- xml_attr(ns, "person_id")
    if (length(retval) == 0) {
        retval <- NA_character_
    }
    retval
}

handle_words <- function(ns) {
    spoken_words <- lapply(ns, function(n) {
        xml_find_all(n, "./p") |>
            xml_text() |>
            paste(collapse = " ")
    })
    ## Replace zero length entries
    spoken_words[which(sapply(spoken_words, length) == 0)] <- ""
    spoken_words <- unlist(spoken_words)
    
    if (is.null(spoken_words)) {
        spoken_words <- NA_character_
    }
    
### Remove content between square brackets
    spoken_words <- gsub("\\[.*?)\\]", "", spoken_words)
    
    spoken_words <- gsub("hon.", "Honourable", spoken_words, fixed = TRUE)
    spoken_words <- gsub("Hon.", "Honourable", spoken_words, fixed = TRUE)
    spoken_words <- gsub("HON.", "HONOURABLE", spoken_words, fixed = TRUE)
    spoken_words <- gsub("Prof.", "Professor ", spoken_words, fixed = TRUE)
    spoken_words <- gsub("Dr.", "Doctor ", spoken_words, fixed = TRUE)
    spoken_words <- gsub("Mr.", "Mr", spoken_words, fixed = TRUE)
    spoken_words <- gsub("Ms.", "Ms", spoken_words, fixed = TRUE)
    spoken_words <- gsub("Mrs.", "Mrs", spoken_words, fixed = TRUE)
    ## Remove initial punctuation in these spoken_words
    spoken_words <- sub("^[[:punct::]+", "", spoken_words)
    spoken_words <- str_trim(spoken_words)
    spoken_words <- sub("^[[:punct::]+", "", spoken_words)        
    spoken_words <- str_trim(spoken_words)
    spoken_words <- str_squish(spoken_words)
    ## Handle honourable
    
    spoken_words
}

verbs <- function(json) {
    x <- jsonlite:::parse_string(json, bigint_as_char=F)
    sentences <- x$sentences[[1]]
    tokens <- sentences$tokens
    pos <- lapply(tokens, function(x)x$pos)
    ### for parts-of-speech, punctuation is returned as-is
    verbs <- sum(sapply(pos, function(x)substr(x, 0, 2) == "VB"))
    return(verbs)
}

extract_timex <- function(response) {
    x <- jsonlite:::parse_string(response, bigint_as_char=F)
    ## x <- parse_json(response, simplifyVector = FALSE)
    sentences <- x$sentences[[1]]
    entities <- sentences[["entitymentions"]]
    entities <- lapply(entities, as.data.frame)
    entities <- bind_rows(entities)
    if ("timex.type" %in% names(entities)) {
### return just those entries
        entities <- entities |>
            filter(!is.na(timex.type))
### and those entities which are dates
        entities <- entities |>
            filter(timex.type == "DATE")
        if ("timex.value" %in% names(entities)) {
            return(entities |>
            dplyr::select(pattern = text,
                          timex.value))
        } else {
            return(NULL)
        }
    } else {
### return null data frame
        return(NULL)
    }  
}

timex2date <- function(x) {
    case_when(nchar(x) == 4 ~ as.Date(paste0(x, "-01-01"),
                                      format = "%Y-%m-%d"),
              nchar(x) == 7 ~ as.Date(paste0(x, "-01"),
                                      format = "%Y-%m-%d"),
              nchar(x) == 10 ~ as.Date(x,
                                       format = "%Y-%m-%d"))
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
                       years > 1 & months == 1 ~ paste0(years, " year and one month "),
                       years > 1 & months > 1 ~ paste0(years, " years and ",
                                                       months, " months "))
    }
    r <- paste0(r, ifelse(sign_x == 1, "from now", "ago"))
    return(r)
}




    get_major_heading <- function(ns) {
        all <- ns |> xml_find_all(xpath = "./preceding-sibling::major-heading")
        return(all[length(all)] |> xml_text())
    }
    fill_charlist <- function(x) {
        if (length(x) == 0) {
            return("")
        } else {
            return(str_trim(x))
        }
    }
    get_oral_heading <- function(ns) {
        all <- ns |> xml_find_all(xpath = "./preceding-sibling::oral-heading")
        return(all[length(all)] |> xml_text())
    }
