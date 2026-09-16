# =============================================================================
# 05_history_replication.R - RQ4 value of history + Panel 24 robustness
# =============================================================================
source("R/functions.R")
obj <- readRDS("data_processed/model_objects.rds")
train <- obj$train; cal <- obj$cal; test <- obj$test
replication <- readRDS("data_processed/replication_h225_analysis.rds")

# RQ4: compare a baseline model without prior-year spending/utilization against
# the full-history model. We use log-OLS because it is transparent and stable.
base_terms <- c("age","sex","race_eth","region","income_cat","insurance","total_income",
                "self_health","mental_health","chronic_count")
history_terms <- c(base_terms,"office_visits","er_visits","inpatient_discharges","rx_count","y1_exp")
fit_log_model <- function(terms,tr) {
  f <- as.formula(paste("log1p(y2_exp) ~",paste(terms,collapse=" + ")))
  fit <- lm(f,data=tr,weights=normalize_weights(tr$weight))
  smear <- weighted_mean(exp(residuals(fit)),tr$weight)
  list(fit=fit,smear=smear)
}
predict_log_model <- function(o,new) pmax(0,exp(predict(o$fit,new))*o$smear-1)

m_base <- fit_log_model(base_terms,train)
m_hist <- fit_log_model(history_terms,train)
for (nm in c("base","hist")) {
  m <- get(paste0("m_",nm))
  cal[[paste0("p_",nm)]] <- predict_log_model(m,cal)
  test[[paste0("p_",nm)]] <- predict_log_model(m,test)
  score <- abs(cal$y2_exp-cal[[paste0("p_",nm)]])
  q <- weighted_quantile(score,cal$weight,.90)
  test[[paste0("lo_",nm)]] <- pmax(0,test[[paste0("p_",nm)]]-q)
  test[[paste0("hi_",nm)]] <- test[[paste0("p_",nm)]]+q
}
history_value <- bind_rows(
  coverage_summary(test,"lo_base","hi_base") |> mutate(model="No prior-year utilization/spending"),
  coverage_summary(test,"lo_hist","hi_hist") |> mutate(model="With prior-year utilization/spending")
) |> mutate(interval_width_reduction = max(mean_width)-mean_width)
write_csv(history_value,"results/tables/value_of_history.csv")

# Replication: fit transparent log-OLS on full primary and evaluate directly on
# Panel 24 using the same specification. This tests temporal/panel transport.
full_primary <- bind_rows(train,cal,test)
rep_fit <- fit_log_model(history_terms,full_primary)
rep_pred <- predict_log_model(rep_fit,replication)
rep_metrics <- tibble(
  model="Primary-panel log-OLS transported to Panel 24",
  RMSE=weighted_rmse(replication$y2_exp,rep_pred,replication$weight),
  MAE=weighted_mae(replication$y2_exp,rep_pred,replication$weight),
  R2=weighted_r2(replication$y2_exp,rep_pred,replication$weight)
)
write_csv(rep_metrics,"results/tables/replication_performance.csv")
