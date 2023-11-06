# commons_tfs

This repository contains code to calculate the temporal focus of
speeches in the United Kingdom House of Commons.

The speeches come from the [ParlParse
project](https://github.com/mysociety/parlparse/tree/master), which
powers [TheyWorkForYou](https://theyworkforyou.com/). 

The code trains a distillBERT model on gold-standard human-coded sentences.

These human-coded sentences, and the Commons speeches, have been
pre-processed using [Duckling](https://github.com/facebook/duckling)
to turn absolute references (e.g., a reference to 1950, made in 2023)
into relative references ("73 years ago").

## Folder structure

 - `scrapedxml/` contains the debates from ParlParse
 - `R/` contains any R source code
 - `python/` contains any Python code
 - `working/` contains intermediate files
 - `outputs/` contains CSV files at sentence level and daily aggregates
