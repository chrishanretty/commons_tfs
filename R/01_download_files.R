### Script to download parlparse data
### Just calling rsync from the command line
### This should be called from the project directory
if (grepl("/R$", getwd())) {
    setwd("..")
}

for (y in 1946:2023) {
    rel <- paste0("data.theyworkforyou.com::parldata/scrapedxml/debates/debates", y, "-*")
    cmd <- paste0("rsync -az --progress --exclude '.svn' --exclude 'tmp/' --relative ",
                  rel,
                  " . ")
    system(cmd)
}

