#!/usr/bin/bash
R CMD BATCH R/01_download_files.R
R CMD BATCH R/02_tidy_files.R
R CMD BATCH R/03_get_duckling.R
R CMD BATCH R/04_parse_duckling.R
python python/05_train_distilbert.py
python python/06_predict_distilbert.py
R CMD BATCH R/07_aggregate.R
