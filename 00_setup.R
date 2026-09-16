# =============================================================================
# 00_setup.R - package installation and reproducibility settings
# =============================================================================

required_packages <- c(
  "tidyverse", "survey", "srvyr", "rsample", "yardstick", "pROC",
  "quantreg", "statmod", "xgboost", "Matrix", "broom", "scales",
  "gt", "patchwork", "rmarkdown", "knitr", "here"
)

installed <- rownames(installed.packages())
to_install <- setdiff(required_packages, installed)
if (length(to_install) > 0) {
  install.packages(to_install, repos = "https://cloud.r-project.org", dependencies = TRUE)
}

invisible(lapply(required_packages, library, character.only = TRUE))

set.seed(7980)
options(survey.lonely.psu = "adjust")
options(stringsAsFactors = FALSE)

# Create folders if missing
folders <- c("data_raw", "data_processed", "results/tables", "results/figures", "report")
invisible(lapply(folders, dir.create, recursive = TRUE, showWarnings = FALSE))

message("Setup complete. R version: ", R.version.string)
