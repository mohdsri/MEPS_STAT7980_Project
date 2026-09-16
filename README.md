# STAT 7980 MEPS Capstone Project

**Title:** Statistical Analysis of Healthcare Expenditures Using MEPS: Calibrated Uncertainty for Individual-Level Cost Prediction

This repository implements the STAT 7980 syllabus as a reproducible R analysis.

## Primary and replication samples
- Primary: MEPS HC-217, Panel 23, 2018-2019. Year 1 predictors -> Year 2 total expenditure.
- Replication: MEPS HC-225, Panel 24, 2019-2020.
- Survey design: LONGWT, VARSTR, VARPSU.

## Run order
1. Open this folder as an RStudio project (optional).
2. Run `source("00_setup.R")` once to install/load packages.
3. Run `source("run_all.R")` to reproduce the complete analysis.
4. Render `report/STAT7980_Final_Report.Rmd` to Word or HTML.

## What the pipeline produces
- analysis-ready longitudinal MEPS data
- survey-weighted descriptive tables and concentration statistics
- train/calibration/test splits
- two-part logit + gamma GLM
- Tweedie GLM
- log-OLS with Duan smearing
- median/quantile regression
- XGBoost on raw and log spending
- weighted RMSE, MAE, R2, calibration, AUC, PPV@top-5%
- XGBoost feature importance
- split conformal intervals
- scaled-residual conformal intervals
- conformalized quantile regression (CQR)
- subgroup coverage audits
- Mondrian/group-conditional conformal intervals
- value-of-history comparison
- replication on Panel 24

## Important reproducibility note
The code downloads public-use data from AHRQ MEPS when run. Numerical results are intentionally not hard-coded.

# STAT 7980 MEPS Project

## Project Overview

This project analyzes longitudinal healthcare expenditures using the **Medical Expenditure Panel Survey (MEPS)**.

The workflow uses:

- **MEPS HC-217, Panel 23 (2018–2019)** as the primary analysis dataset.
- **MEPS HC-225, Panel 24 (2019–2020)** as the replication dataset.
- Year-1 demographic, socioeconomic, insurance, health, expenditure, and utilization variables to predict Year-2 healthcare expenditures.
- Survey weights and MEPS survey design variables.
- Classical statistical models and machine-learning models.
- Prediction intervals using conformal prediction.
- Subgroup coverage analysis.
- Prior-year healthcare-history analysis.
- Replication on a second MEPS longitudinal panel.

The entire project is designed to be reproducible from the raw official MEPS files.

---

# 1. Project Folder Structure

The main project folder should contain:

```text
MEPS_STAT7980_Project/
│
├── 00_setup.R
├── run_all.R
├── README.md
├── PROJECT_STEPS.md
├── STAT7980_MEPS_Report_Draft.docx
│
├── R/
│   ├── functions.R
│   ├── 01_download_prepare.R
│   ├── 02_descriptive.R
│   ├── 03_models.R
│   ├── 04_conformal.R
│   └── 05_history_replication.R
│
├── data_raw/
├── data_processed/
├── results/
│   ├── tables/
│   └── figures/
│
└── report/
    └── STAT7980_Final_Report.Rmd
```

---

# 2. Software Requirements

The project requires:

- macOS, Windows, or Linux
- R
- Internet connection for the initial MEPS download
- R packages installed by `00_setup.R`

The project was successfully run using:

```text
R version 4.5.3
Apple Silicon Mac
```

To check that R is installed, open Terminal and run:

```bash
R --version
```

If R is installed correctly, the Terminal will display the R version.

---

# 3. Open the Project Folder in Terminal

If the project is stored in the Downloads folder:

```bash
cd ~/Downloads/MEPS_STAT7980_Project
```

Check that you are in the correct folder:

```bash
pwd
```

Then list the files:

```bash
ls
```

You should see files such as:

```text
00_setup.R
run_all.R
R
report
results
data_raw
data_processed
README.md
```

---

# 4. First-Time Setup

The first time the project is used, install the required R packages by running:

```bash
Rscript 00_setup.R
```

This script installs and loads the packages required for the project.

Examples include packages for:

- data manipulation
- survey analysis
- regression
- machine learning
- XGBoost
- quantile regression
- model evaluation
- graphics
- R Markdown reporting

The first installation may download many R packages.

After the setup finishes successfully, you should see a message similar to:

```text
Setup complete.
```

You normally do not need to run `00_setup.R` every time.

---

# 5. Run the Complete Analysis

After the packages are installed, run:

```bash
Rscript run_all.R
```

This is the main command for the project.

`run_all.R` executes the analysis scripts in the correct order.

---

# 6. Workflow Performed by `run_all.R`

## Step 1 — Download and Prepare MEPS Data

Script:

```text
R/01_download_prepare.R
```

This script:

1. Downloads the official MEPS HC-217 longitudinal file.
2. Downloads the official MEPS HC-225 longitudinal file.
3. Extracts the raw `.dat` files.
4. Uses the official AHRQ R import scripts.
5. Selects the required variables.
6. Cleans MEPS missing-value codes.
7. Creates harmonized analysis variables.
8. Creates chronic-condition counts.
9. Creates demographic and healthcare-use predictors.
10. Applies eligibility and valid-weight restrictions.
11. Removes incomplete model rows.
12. Saves prepared analysis datasets.

Expected successful output includes something similar to:

```text
Importing primary panel HC-217...
Importing replication panel HC-225...

Primary analytic n = 13036
Replication analytic n = 9112
```

The exact sample size may change only if the project code or eligibility rules are changed.

Prepared datasets are saved in:

```text
data_processed/
```

Examples:

```text
primary_h217_analysis.rds
primary_h217_analysis.csv
replication_h225_analysis.rds
```

---

## Step 2 — Descriptive Analysis

Script:

```text
R/02_descriptive.R
```

This script produces descriptive results for the primary MEPS sample.

Examples include:

- healthcare expenditure distribution
- zero expenditure
- weighted expenditure summaries
- high-cost concentration
- top 1%, 5%, and 10% spending concentration
- persistence of high healthcare spending
- demographic and health summaries

Tables are stored in:

```text
results/tables/
```

Figures are stored in:

```text
results/figures/
```

---

## Step 3 — Prediction Models

Script:

```text
R/03_models.R
```

This script creates the model-development samples and fits the prediction models.

The project includes models such as:

- Two-part model
  - Logistic model for positive expenditure
  - Gamma GLM for positive expenditures
- Tweedie GLM
- Log-OLS with Duan smearing
- Quantile regression
- XGBoost using raw expenditure
- XGBoost using log expenditure

The data are divided into model-development subsets such as:

```text
Training
Calibration
Test
```

The models predict:

```text
Year-2 healthcare expenditure
```

using information available from:

```text
Year 1
```

---

# 7. Model Evaluation

The project evaluates prediction performance using metrics such as:

- RMSE
- MAE
- R-squared
- calibration
- high-cost classification performance
- AUC
- positive predictive value
- top-risk selection performance

The model comparison results are saved in:

```text
results/tables/
```

Model-related figures are saved in:

```text
results/figures/
```

---

# 8. Feature Importance

For machine-learning models, especially XGBoost, the project evaluates predictor importance.

Examples of predictors include:

- age
- sex
- race/ethnicity
- region
- income
- insurance
- self-rated health
- mental health
- chronic-condition count
- prior-year expenditure
- office visits
- emergency-room visits
- inpatient use
- prescription utilization

Feature-importance tables and figures are saved under:

```text
results/tables/
results/figures/
```

---

# 9. Conformal Prediction Analysis

Script:

```text
R/04_conformal.R
```

This script creates prediction intervals for Year-2 healthcare expenditures.

Methods include:

- absolute-residual split conformal prediction
- scaled conformal prediction
- conformalized quantile regression
- comparison with parametric prediction intervals

The project targets approximately:

```text
90% prediction coverage
```

The script evaluates:

- overall coverage
- interval width
- lower-tail misses
- upper-tail misses

When the analysis runs, the Terminal may display a line similar to:

```text
Conformal base model: xgboost_raw
```

This identifies the prediction model used as the base model for the conformal analysis.

---

# 10. Subgroup Coverage Analysis

Prediction-interval performance is evaluated separately for important subgroups.

Examples include:

- age groups
- race/ethnicity groups
- insurance groups
- income groups
- chronic-condition groups

The purpose is to determine whether prediction intervals maintain appropriate coverage across different groups.

Subgroup coverage tables are stored in:

```text
results/tables/
```

and related figures are stored in:

```text
results/figures/
```

---

# 11. Prior-Year History Analysis

Script:

```text
R/05_history_replication.R
```

This part evaluates the value of prior healthcare history.

Two model settings are compared.

### Model without prior healthcare history

Uses variables such as:

- demographics
- socioeconomic information
- insurance
- health status
- chronic conditions

### Model with prior healthcare history

Adds variables such as:

- Year-1 healthcare expenditures
- office visits
- emergency-room visits
- inpatient utilization
- prescription utilization

The analysis evaluates whether prior healthcare history improves:

- RMSE
- MAE
- prediction accuracy
- prediction-interval width

---

# 12. Replication Analysis

The primary results use:

```text
MEPS HC-217
Panel 23
2018–2019
```

The analysis is then replicated using:

```text
MEPS HC-225
Panel 24
2019–2020
```

The replication checks whether the main findings are similar in another MEPS longitudinal panel.

Replication results are written to:

```text
results/tables/
results/figures/
```

---

# 13. Successful Completion

When the complete workflow finishes successfully, Terminal should display:

```text
Analysis complete. See results/tables and results/figures.
```

For the current project run, the analysis successfully produced:

```text
Primary analytic n = 13036
Replication analytic n = 9112
```

The run also selected:

```text
Conformal base model: xgboost_raw
```

Warnings may appear during analysis.

Examples include:

```text
log-10 transformation introduced infinite values
```

This can occur when plotting expenditure because some individuals have zero healthcare expenditures.

Another possible warning is:

```text
non-integer #successes in a binomial glm
```

This may occur when fitting weighted logistic regression models.

Warnings do not necessarily mean that the analysis failed.

The important confirmation is:

```text
Analysis complete.
```

---

# 14. Check Results

To list all result tables:

```bash
ls results/tables
```

To list all figures:

```bash
ls results/figures
```

To open the results folder on macOS:

```bash
open results
```

To open only the figures:

```bash
open results/figures
```

To open only the tables:

```bash
open results/tables
```

---

# 15. Generate the Final Word Report

After `run_all.R` completes successfully, generate the final report.

Run:

```bash
Rscript -e 'rmarkdown::render("report/STAT7980_Final_Report.Rmd", output_format="word_document")'
```

The R Markdown file reads the real tables and results generated by the analysis and inserts them into the report.

The output Word document should be created in:

```text
report/
```

Check the folder:

```bash
ls report
```

Expected files include:

```text
STAT7980_Final_Report.Rmd
STAT7980_Final_Report.docx
```

Open the report on macOS with:

```bash
open report/STAT7980_Final_Report.docx
```

---

# 16. Complete Workflow From the Beginning

For a new computer or completely fresh project installation:

```bash
cd ~/Downloads/MEPS_STAT7980_Project

R --version

Rscript 00_setup.R

Rscript run_all.R

Rscript -e 'rmarkdown::render("report/STAT7980_Final_Report.Rmd", output_format="word_document")'

open report/STAT7980_Final_Report.docx
```

---

# 17. Normal Workflow After Setup

After the required packages have already been installed, normally only two commands are required:

```bash
Rscript run_all.R
```

followed by:

```bash
Rscript -e 'rmarkdown::render("report/STAT7980_Final_Report.Rmd", output_format="word_document")'
```

---

# 18. Reproducing the Analysis

To reproduce the complete project:

1. Start from the main project directory.
2. Run `00_setup.R` if the packages have not been installed.
3. Run `run_all.R`.
4. Verify that the analysis finishes successfully.
5. Inspect `results/tables/`.
6. Inspect `results/figures/`.
7. Render the final R Markdown report.
8. Review the final Word report before submission.

The raw and processed datasets should not be manually edited.

Any changes to the statistical analysis should be made in the R scripts.

---

# 19. Important Files

| File | Purpose |
|---|---|
| `00_setup.R` | Installs and loads required R packages |
| `run_all.R` | Runs the complete analysis workflow |
| `R/functions.R` | Common helper functions |
| `R/01_download_prepare.R` | Downloads, imports, cleans, and prepares MEPS data |
| `R/02_descriptive.R` | Produces descriptive statistics and figures |
| `R/03_models.R` | Fits and evaluates prediction models |
| `R/04_conformal.R` | Performs conformal prediction and subgroup coverage |
| `R/05_history_replication.R` | Evaluates prior history and replicates results |
| `PROJECT_STEPS.md` | Simple explanation of the analysis workflow |
| `report/STAT7980_Final_Report.Rmd` | Automatically generates the final numerical report |
| `STAT7980_MEPS_Report_Draft.docx` | Initial report draft and project explanation |

---

# 20. Important Output Folders

| Folder | Contents |
|---|---|
| `data_raw/` | Downloaded official MEPS files |
| `data_processed/` | Cleaned analysis datasets |
| `results/tables/` | Statistical and model result tables |
| `results/figures/` | Generated figures |
| `report/` | Final report source and Word report |

---

# 21. If an Error Occurs

If the project stops with an error, read the last lines displayed in Terminal.

The most useful information is usually the final error message.

Do not rerun the package installation unless the error specifically indicates that a required package is missing.

For data-download problems, verify that the computer has an internet connection.

For report-generation problems, first verify that:

```bash
Rscript run_all.R
```

completed successfully.

The final report depends on the tables and figures generated by the analysis.

---

# 22. Recommended Order for STAT 7980 Work

A practical workflow for the semester is:

```text
1. Run and verify the data pipeline
        ↓
2. Review the descriptive results
        ↓
3. Review the prediction-model results
        ↓
4. Review calibration and feature importance
        ↓
5. Review conformal prediction results
        ↓
6. Review subgroup coverage
        ↓
7. Review prior-history comparison
        ↓
8. Review replication results
        ↓
9. Generate the final report
        ↓
10. Interpret results and write the discussion
```

---

# 23. Main Commands Summary

### Enter the project

```bash
cd ~/Downloads/MEPS_STAT7980_Project
```

### First-time setup

```bash
Rscript 00_setup.R
```

### Run complete analysis

```bash
Rscript run_all.R
```

### Generate final Word report

```bash
Rscript -e 'rmarkdown::render("report/STAT7980_Final_Report.Rmd", output_format="word_document")'
```

### Open final report

```bash
open report/STAT7980_Final_Report.docx
```

### View results

```bash
open results
```

---

# STAT 7980

**Project:** Longitudinal Prediction of Healthcare Expenditures Using MEPS

**Primary dataset:** MEPS HC-217, Panel 23, 2018–2019

**Replication dataset:** MEPS HC-225, Panel 24, 2019–2020

**Software:** R

**Main execution file:** `run_all.R`


# MEPS_STAT7980_Project
