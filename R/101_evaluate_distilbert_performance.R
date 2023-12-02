library(tidyverse)
library(here)
library(mlr3measures)
library(knitr)
here::i_am("R/101_evaluate_distilbert_performance.R")

### Read in the predictions
dat <- read.csv("working/distilbert_predictions.csv")
### Get the predicted probabilities
pr <- exp(dat[,1:3]) / rowSums(exp(dat[,1:3]))
colnames(pr) <- c("pr0", "pr1", "pr2")
dat <- cbind(dat, pr)

dat$pr_max <- apply(dat[,paste0("pr", 0:2)],1, which.max) - 1

mean(dat$pr_max == dat$Label)

### brier score
names(pr) <- c("0", "1", "2")
mbrier(factor(dat$Label), as.matrix(pr))

tab <- with(dat, table(pr_max, Label))
dimnames(tab)$pr_max <- c("DPast", "Present", "Future")
dimnames(tab)$Label <- c("Past", "Present", "Future")
kable(tab)

## What's the null performance measure?

