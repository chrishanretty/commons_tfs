### PURPOSE OF THIS CODE: to take in the XML from the ParlParse
### project, and turn this into R data frames which include
### information on the speaker, the member, the date, the heading, and
### what they actually said

### Load libraries
library(tidyverse)
library(tidytext)
library(rvest)
library(parallel)
library(xml2)
library(furrr)
library(jsonlite)

num_cores_to_use <- 20

here::i_am("R/02_tidy_files.R")

### Get in helper functions
source(here::here("R", "00_helpers.R"), echo = FALSE)

speakers = tribble(~speakerid, ~startdate, ~stopdate, ~name,
                   '10295', 20221231, 20191231, 'Hoyle, Lindsay',
                   '10040', 20090622, 20191031, 'Bercow, John',
                   '10348', 20131016, 20191231, 'Laing, Eleanor',
                   '10648', 20170628, 20191231, 'Winterton, Rosie',
                   '10420', 19970514, 20090621, 'Martin, Michael',
                   '10054', 19920427, 20001023, 'Boothroyd, Betty',
                   '10263', 19971514, 20101614, 'Haselhurst, Alan',
                   '10190', 20100608, 20130910, 'Evans, Nigel',
                   '10266', 20001023, 20100412, 'Heal, Sylvia', 
                   '11534', 20150603, 20170608, 'Engel, Natascha',
                   '10489', 20100609, 20150508, 'Primarolo, Dawn',
                   '10370', 19970514, 20100608, 'Lord, Michael')



tidy_file <- function(file, overwrite = FALSE, debug = FALSE) {
    require(tidyverse)
    require(tidytext)
    require(stringr)
    require(rvest)
    require(xml2)

    outfile <- sub("scrapedxml", "working", file)
    outfile <- sub(".xml", ".rds", outfile, fixed = TRUE)

### if overwrite is false, and the file exists
    if (!overwrite) { 
        if (file.exists(outfile)) return(TRUE)
    }
    
    x <- read_xml(file)
    
    ## Remove interjections and other procedural language
    xml_remove(xml_find_all(x, "//p[@class = 'italic']"))
    
    ## Get all speeches
    y <- x |> xml_find_all("//speech")

### Find their parent major heading
    heading <- sapply(y, get_major_heading)
### This might be a list with no entries
    heading <- unlist(lapply(heading, fill_charlist))
    
    oral_heading <- sapply(y, get_oral_heading)
    oral_heading <- unlist(lapply(oral_heading, fill_charlist))

    speech_id <- handle_speech_id(y)
    date <- handle_date(file)
    speaker <- handle_speaker(y)
    speaker_flag <- check_whether_speaker(y)
    person <- handle_person(y)
    words <- handle_words(y)

    if (length(oral_heading) != length(y)) {
        stop("Problem with oral headings")
    }
    if (length(heading) != length(y)) {
        stop("Problem with heading")
    }
        
    dat <- data.frame(speaker = speaker,
                      heading = heading,
                      oral_heading = oral_heading,
                      speech_id = speech_id,
                      is_speaker = speaker_flag,
                      date = date,
                      person = person,
                      words = words,
                      row.names = NULL) |>
        filter(!is_speaker) |>
    filter(!is.na(speaker) | !is.na(person)) |>
    dplyr::select(-is_speaker)

### Tokenize on sentence
    dat <- dat |>
        unnest_tokens(sents, words,
                      "sentences",
                      to_lower = FALSE,
                      drop = TRUE)

    ### Remove sentences without letters (i.e., purely numeric or punctuation)
    dat <- dat |>
        filter(grepl("[A-Za-z]", sents))

### Omit sentences which begin and end with square brackets
    dat <- dat |>
        filter(!(grepl("^\\[", sents) & grepl("\\[$", sents)))
    
### Replace references to Act [YYYY] with Act_[YYYY]
    dat <- dat |>
        mutate(sents = stringi::stri_replace_all_regex(sents,
                                                       "Act [0-9]{4}",
                                                       replacement = "Act"))

    dat <- dat |>
        mutate(sents = stringi::stri_replace_all_regex(sents,
                                                       "esolution [0-9]{4}",
                                                       replacement = "esolution"))

### We want sentences that have at least four words.
    ## four words => three boundaries
    dat <- dat |>
        mutate(nboundaries = str_count(sents, boundary("word"))) |>
        filter(nboundaries >= 3)    

### select the columns we want
    dat <- dat |>
        dplyr::select(speaker, person, date,
                      heading, oral_heading, speech_id,
                      sents) |>
        as.data.frame()
    
    if (nrow(dat) == 0) {
        warning(paste0("No speeches in file ", file))
        return(FALSE)
    }
    
    if (debug) {
        print(dat |>
              sample_n(10) |>
              pull(sents))
    } else { 
        dat <- dat |>
            mutate(docid = seq_len(n()))
        saveRDS(dat, outfile)
    }
    return(TRUE)
}


infiles <- sort(list.files(here::here("scrapedxml/debates/"),
                           full.names = TRUE))
length(infiles)

### ParlParse will occasionally store duplicates of date entries
### Pick the last of each date (i.e., if we have a, b, and c, pick c
date <- sub("scrapedxml/debates//debates", "", infiles, fixed = TRUE)
date <- gsub("[a-z]", "", date)

infiles <- by(infiles, list(date = date), FUN = tail, n = 1)
infiles <- unlist(unique(infiles))
length(infiles)

### Shuffle the files
infiles <- sample(infiles, length(infiles), replace = TRUE)

            
## ## # Initiate cluster
cl <- makeCluster(num_cores_to_use)
clusterEvalQ(cl, library(jsonlite))
clusterEvalQ(cl, source("R/00_helpers.R"))

Sys.time()
res <- parLapply(cl,
                 X = infiles,
                 fun = tidy_file,
                 overwrite = FALSE,
                 debug = FALSE)
Sys.time()

stopCluster(cl)
