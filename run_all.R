# Run the entire project from raw public-use data to tables/figures/report inputs.
source("00_setup.R")
source("R/01_download_prepare.R")
source("R/02_descriptive.R")
source("R/03_models.R")
source("R/04_conformal.R")
source("R/05_history_replication.R")
message("Analysis complete. See results/tables and results/figures.")
message("Next: rmarkdown::render('report/STAT7980_Final_Report.Rmd', output_format='word_document')")
