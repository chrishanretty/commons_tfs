library(tidyverse)
library(here)

here::i_am("R/101_evaluate_distilbert_performance.R")

### Read in the predictions
dat <- read.csv("working/distilbert_predictions.csv")
### Get the predicted probabilities
pr <- exp(dat[,1:3]) / rowSums(exp(dat[,1:3]))
colnames(pr) <- c("pr0", "pr1", "pr2")
dat <- cbind(dat, pr)

dat$pr_max <- apply(dat[,paste0("pr", 0:2)],1, which.max) - 1

mean(dat$pr_max == dat$Label)

### 
