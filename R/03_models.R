# =============================================================================
# 03_models.R - train/calibration/test split and predictive models
# =============================================================================
source("R/functions.R")
primary <- readRDS("data_processed/primary_h217_analysis.rds")
set.seed(7980)

# Split 60% train / 20% calibration / 20% test. Calibration is kept separate
# because conformal prediction must not use the same observations used to fit.
sp1 <- initial_split(primary, prop = 0.60)
train <- training(sp1)
tmp <- testing(sp1)
sp2 <- initial_split(tmp, prop = 0.50)
cal <- training(sp2)
test <- testing(sp2)

# High-cost threshold defined from training data only, avoiding test leakage.
high_cost_cut <- weighted_quantile(train$y2_exp, train$weight, .95)
train <- train |> mutate(high_cost = y2_exp >= high_cost_cut)
cal <- cal |> mutate(high_cost = y2_exp >= high_cost_cut)
test <- test |> mutate(high_cost = y2_exp >= high_cost_cut)

predictor_terms <- c("age","sex","race_eth","region","income_cat","insurance","total_income",
                     "self_health","mental_health","chronic_count","office_visits","er_visits",
                     "inpatient_discharges","rx_count","y1_exp")
form <- as.formula(paste("y2_exp ~", paste(predictor_terms, collapse=" + ")))
form_pos <- form
wtrain <- normalize_weights(train$weight)

# ----- 1. Two-part model: logistic P(Y>0) + Gamma(log) among positive ----------
two_logit <- glm(update(form, I(y2_exp > 0) ~ .), data=train,
                 family=binomial(), weights=wtrain)
pos <- train$y2_exp > 0
two_gamma <- glm(form_pos, data=train[pos,], family=Gamma(link="log"),
                 weights=wtrain[pos])

pred_two_part <- function(newdata) {
  ppos <- predict(two_logit, newdata, type="response")
  mu_pos <- predict(two_gamma, newdata, type="response")
  pmax(0, ppos * mu_pos)
}

# ----- 2. Tweedie GLM ---------------------------------------------------------
# p=1.5 permits a point mass at zero plus a continuous positive right tail.
tweedie_fit <- glm(form, data=train, family=statmod::tweedie(var.power=1.5, link.power=0),
                   weights=wtrain)
pred_tweedie <- function(newdata) pmax(0, predict(tweedie_fit, newdata, type="response"))

# ----- 3. log-OLS + Duan smearing --------------------------------------------
logols <- lm(update(form, log1p(y2_exp) ~ .), data=train, weights=wtrain)
res_log <- residuals(logols)
smear <- weighted_mean(exp(res_log), train$weight)
pred_logols <- function(newdata) pmax(0, exp(predict(logols, newdata)) * smear - 1)

# ----- 4. Quantile regression -------------------------------------------------
# Median for point prediction, plus 5th and 95th quantiles for CQR.
rq50 <- quantreg::rq(form, data=train, tau=.50, weights=wtrain, method="fn")
rq05 <- quantreg::rq(form, data=train, tau=.05, weights=wtrain, method="fn")
rq95 <- quantreg::rq(form, data=train, tau=.95, weights=wtrain, method="fn")
pred_rq50 <- function(newdata) pmax(0, as.numeric(predict(rq50, newdata)))
pred_rq05 <- function(newdata) pmax(0, as.numeric(predict(rq05, newdata)))
pred_rq95 <- function(newdata) pmax(0, as.numeric(predict(rq95, newdata)))

# ----- 5. XGBoost -------------------------------------------------------------
# model.matrix supplies one-hot encoding for categorical predictors.
x_formula <- as.formula(paste("~", paste(predictor_terms, collapse=" + "), "- 1"))
x_train <- model.matrix(x_formula, train)
feature_names <- colnames(x_train)
mm <- function(d) {
  x <- model.matrix(x_formula, d)
  missing_cols <- setdiff(feature_names, colnames(x))
  if (length(missing_cols)) x <- cbind(x, matrix(0, nrow(x), length(missing_cols), dimnames=list(NULL,missing_cols)))
  x[, feature_names, drop=FALSE]
}

dtrain_raw <- xgb.DMatrix(x_train, label=train$y2_exp, weight=normalize_weights(train$weight))
dtrain_log <- xgb.DMatrix(x_train, label=log1p(train$y2_exp), weight=normalize_weights(train$weight))
params <- list(objective="reg:squarederror", eta=.03, max_depth=3,
               min_child_weight=20, subsample=.8, colsample_bytree=.8)
set.seed(7980)
xgb_raw <- xgb.train(params=params, data=dtrain_raw, nrounds=600, verbose=0)
set.seed(7980)
xgb_log <- xgb.train(params=params, data=dtrain_log, nrounds=600, verbose=0)
pred_xgb_raw <- function(newdata) pmax(0, predict(xgb_raw, mm(newdata)))
pred_xgb_log <- function(newdata) pmax(0, expm1(predict(xgb_log, mm(newdata))))

# Generate all predictions
model_predictors <- list(
  two_part = pred_two_part,
  tweedie = pred_tweedie,
  log_ols = pred_logols,
  quantile_median = pred_rq50,
  xgboost_raw = pred_xgb_raw,
  xgboost_log = pred_xgb_log
)
for (nm in names(model_predictors)) {
  cal[[paste0("pred_",nm)]] <- model_predictors[[nm]](cal)
  test[[paste0("pred_",nm)]] <- model_predictors[[nm]](test)
}
cal$pred_q05 <- pred_rq05(cal); cal$pred_q95 <- pred_rq95(cal)
test$pred_q05 <- pred_rq05(test); test$pred_q95 <- pred_rq95(test)

# Evaluate point prediction and high-cost identification using model score.
metrics <- map_dfr(names(model_predictors), function(nm) {
  p <- test[[paste0("pred_",nm)]]
  tibble(model=nm,
         RMSE=weighted_rmse(test$y2_exp,p,test$weight),
         MAE=weighted_mae(test$y2_exp,p,test$weight),
         R2=weighted_r2(test$y2_exp,p,test$weight),
         AUC_top5=w_auc(test$high_cost,p,test$weight),
         PPV_at_5pct=ppv_at_budget(test$high_cost,p,test$weight,.05))
}) |> arrange(RMSE)
write_csv(metrics,"results/tables/model_performance.csv")

# Calibration table and figure for each model
calibration_all <- map_dfr(names(model_predictors), function(nm) {
  weighted_calibration_table(test, paste0("pred_",nm)) |> mutate(model=nm)
})
write_csv(calibration_all,"results/tables/calibration_by_decile.csv")
pcal <- ggplot(calibration_all, aes(predicted, observed, group=model)) +
  geom_abline(slope=1, intercept=0, linetype=2) + geom_line() + geom_point() +
  facet_wrap(~model, scales="free") + scale_x_continuous(labels=dollar) +
  scale_y_continuous(labels=dollar) + labs(title="Survey-weighted calibration by predicted-spending decile") + theme_minimal()
ggsave("results/figures/model_calibration.png", pcal, width=11, height=8, dpi=300)

# Feature importance from XGBoost; gain = contribution to loss reduction.
importance <- xgb.importance(model=xgb_raw) |> as_tibble()
write_csv(importance,"results/tables/xgboost_feature_importance.csv")
pimp <- importance |> slice_head(n=20) |>
  ggplot(aes(x=reorder(Feature, Gain), y=Gain)) + geom_col() + coord_flip() +
  labs(title="Top 20 XGBoost features", x=NULL, y="Gain importance") + theme_minimal()
ggsave("results/figures/xgboost_feature_importance.png", pimp, width=8, height=7, dpi=300)

saveRDS(list(train=train,cal=cal,test=test,high_cost_cut=high_cost_cut,
             models=list(two_logit=two_logit,two_gamma=two_gamma,tweedie=tweedie_fit,
                         logols=logols,rq50=rq50,rq05=rq05,rq95=rq95,
                         xgb_raw=xgb_raw,xgb_log=xgb_log),
             x_formula=x_formula,feature_names=feature_names),
        "data_processed/model_objects.rds")
