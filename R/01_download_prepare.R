# =============================================================================
# 01_download_prepare.R
# Download official MEPS longitudinal files, import them using AHRQ's own R
# programming statements, and create a common analysis data set.
# =============================================================================

source("R/functions.R")

load_meps_panel <- function(puf = c("h217", "h225")) {
  puf <- match.arg(puf)
  data_url <- sprintf(
    "https://meps.ahrq.gov/mepsweb/data_files/pufs/%s/%sdat.zip",
    puf, puf
  )
  r_url <- sprintf("https://meps.ahrq.gov/mepsweb/data_stats/download_data/pufs/%s/%sru.txt", puf, puf)

  zip_path <- file.path("data_raw", paste0(puf, "dat.zip"))
  if (!file.exists(zip_path)) {
    message("Downloading ", puf, " from AHRQ MEPS...")
    download.file(data_url, zip_path, mode = "wb")
  }
  exdir <- file.path("data_raw", puf)
  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
  dat_candidates <- unzip(zip_path, exdir = exdir)
  dat_path <- dat_candidates[grepl("\\.dat$", dat_candidates, ignore.case = TRUE)][1]
  if (is.na(dat_path)) stop("Could not find .dat file after unzipping ", puf)

  # AHRQ's official import script expects an object named meps_path.
  meps_path <- dat_path
  env <- new.env(parent = globalenv())
  env$meps_path <- meps_path
  source(r_url, local = env)
  obj_name <- puf
  get(obj_name, envir = env)
}

choose_existing <- function(dat, candidates, required = TRUE) {
  hit <- candidates[candidates %in% names(dat)]
  if (!length(hit)) {
    if (required) stop("None of these variables found: ", paste(candidates, collapse = ", "))
    return(NULL)
  }
  hit[1]
}

prepare_panel <- function(raw, panel_label) {
  # The longitudinal PUFs use Y1/Y2 harmonized names, which makes Panels 23 and
  # 24 directly reusable in this function.
  needed <- c("DUPERSID","ALL5RDS","LONGWT","VARSTR","VARPSU",
              "TOTEXPY1","TOTEXPY2","AGEY1X","SEX","RACETHX","REGIONY1",
              "POVCATY1","INSCOVY1","TTLPY1X","OBTOTVY1","ERTOTY1",
              "IPDISY1","RXTOTY1")
  missing_needed <- setdiff(needed, names(raw))
  if (length(missing_needed)) stop("Required variables missing: ", paste(missing_needed, collapse = ", "))

  # Chronic-condition candidates verified in the Panel 23 longitudinal naming
  # convention. Only variables present in a panel are used.
  chronic_candidates <- c("HIBPDXY1","CHDDXY1","ANGIDXY1","MIDXY1","OHRTDXY1",
                          "STRKDXY1","EMPHDXY1","CHOLDXY1","CANCERY1")
  chronic_vars <- intersect(chronic_candidates, names(raw))

  # Self-rated health at Round 3 is used as the end-of-Year-1 health-status
  # snapshot in the two-year panel. It is a predictor known before Year-2 cost.
  health_var <- choose_existing(raw, c("RTHLTH3","RTHLTH2","RTHLTH1"), required = FALSE)
  mental_var <- choose_existing(raw, c("MNHLTH3","MNHLTH2","MNHLTH1"), required = FALSE)

  keep <- unique(c(needed, chronic_vars, health_var, mental_var))
  d <- raw |> select(all_of(keep))

  # Convert key variables and remove MEPS negative missing-value codes.
  continuous <- intersect(c("TOTEXPY1","TOTEXPY2","AGEY1X","OBTOTVY1",
                            "ERTOTY1","IPDISY1","RXTOTY1", health_var, mental_var), names(d))
  d <- d |> mutate(across(all_of(continuous), clean_meps_numeric))
  # Personal total income can legitimately be negative. MEPS special missing codes
  # are small negative integers; preserve substantive negative income values.
  d$TTLPY1X <- as.numeric(d$TTLPY1X)
  d$TTLPY1X[d$TTLPY1X %in% c(-1,-7,-8,-9)] <- NA_real_

  for (v in chronic_vars) d[[v]] <- binary_yes(d[[v]])

  d <- d |>
    mutate(
      panel_source = panel_label,
      weight = clean_meps_numeric(LONGWT),
      y1_exp = TOTEXPY1,
      y2_exp = TOTEXPY2,
      age = AGEY1X,
      sex = factor(SEX),
      race_eth = factor(RACETHX),
      region = factor(REGIONY1),
      income_cat = factor(POVCATY1),
      insurance = factor(INSCOVY1),
      total_income = TTLPY1X,
      office_visits = OBTOTVY1,
      er_visits = ERTOTY1,
      inpatient_discharges = IPDISY1,
      rx_count = RXTOTY1,
      self_health = if (!is.null(health_var)) .data[[health_var]] else NA_real_,
      mental_health = if (!is.null(mental_var)) .data[[mental_var]] else NA_real_,
      chronic_count = if (length(chronic_vars)) rowSums(across(all_of(chronic_vars)), na.rm = TRUE) else 0,
      age_group = make_age_group(age),
      chronic_group = make_chronic_group(chronic_count)
    ) |>
    filter(ALL5RDS == 1, is.finite(weight), weight > 0,
           is.finite(y1_exp), y1_exp >= 0, is.finite(y2_exp), y2_exp >= 0)

  # Keep model variables and simple complete-case predictors. For a master's
  # project, this transparent strategy is easier to defend than hidden automated
  # imputation. Missingness is reported separately before rows are removed.
  model_vars <- c("DUPERSID","panel_source","LONGWT","VARSTR","VARPSU","weight",
                  "y1_exp","y2_exp","age","sex","race_eth","region","income_cat",
                  "insurance","total_income","office_visits","er_visits",
                  "inpatient_discharges","rx_count","self_health","mental_health",
                  "chronic_count","age_group","chronic_group")
  d |> select(any_of(model_vars))
}

message("Importing primary panel HC-217...")
h217_raw <- load_meps_panel("h217")
primary_pre_cc <- prepare_panel(h217_raw, "Panel 23: 2018-2019")

message("Importing replication panel HC-225...")
h225_raw <- load_meps_panel("h225")
replication_pre_cc <- prepare_panel(h225_raw, "Panel 24: 2019-2020")

# Missingness tables before modeling complete cases
missing_table <- primary_pre_cc |>
  summarise(across(everything(), ~mean(is.na(.)))) |>
  pivot_longer(everything(), names_to = "variable", values_to = "missing_fraction") |>
  arrange(desc(missing_fraction))
write_csv(missing_table, "results/tables/missingness_primary.csv")

predictors <- c("age","sex","race_eth","region","income_cat","insurance","total_income",
                "self_health","mental_health","chronic_count","office_visits","er_visits",
                "inpatient_discharges","rx_count","y1_exp")

primary <- primary_pre_cc |> drop_na(any_of(predictors))
replication <- replication_pre_cc |> drop_na(any_of(predictors))

saveRDS(primary, "data_processed/primary_h217_analysis.rds")
saveRDS(replication, "data_processed/replication_h225_analysis.rds")
write_csv(primary, "data_processed/primary_h217_analysis.csv")

message("Primary analytic n = ", nrow(primary))
message("Replication analytic n = ", nrow(replication))
