# =============================================================================
# 04_conformal.R - prediction intervals and subgroup coverage
# =============================================================================
source("R/functions.R")
obj <- readRDS("data_processed/model_objects.rds")
cal <- obj$cal; test <- obj$test
alpha <- .10

# Pick the point model with the smallest survey-weighted calibration RMSE.
perf <- read_csv("results/tables/model_performance.csv", show_col_types=FALSE)
best_name <- perf$model[which.min(perf$RMSE)]
pcol <- paste0("pred_",best_name)
message("Conformal base model: ", best_name)

# ----- A. Standard split conformal, absolute residual score ------------------
cal$score_abs <- abs(cal$y2_exp - cal[[pcol]])
q_abs <- weighted_quantile(cal$score_abs, cal$weight, 1-alpha)
test <- test |> mutate(pi_abs_lo=pmax(0,.data[[pcol]]-q_abs), pi_abs_hi=.data[[pcol]]+q_abs)

# ----- B. Scaled-residual split conformal ------------------------------------
# Scaling lets intervals widen for people predicted to spend more.
cal$scale <- sqrt(cal[[pcol]] + 1)
cal$score_scaled <- abs(cal$y2_exp-cal[[pcol]]) / cal$scale
q_scaled <- weighted_quantile(cal$score_scaled,cal$weight,1-alpha)
test <- test |> mutate(scale=sqrt(.data[[pcol]]+1),
                       pi_scaled_lo=pmax(0,.data[[pcol]]-q_scaled*scale),
                       pi_scaled_hi=.data[[pcol]]+q_scaled*scale)

# ----- C. Conformalized quantile regression (CQR) ----------------------------
cal$cqr_score <- pmax(cal$pred_q05-cal$y2_exp, cal$y2_exp-cal$pred_q95)
q_cqr <- weighted_quantile(cal$cqr_score,cal$weight,1-alpha)
test <- test |> mutate(pi_cqr_lo=pmax(0,pred_q05-q_cqr), pi_cqr_hi=pred_q95+q_cqr)

# ----- D. Approximate parametric interval for two-part gamma model ------------
# Simulate from Bernoulli occurrence + Gamma positive spending distribution.
# This provides the syllabus comparison against model-based intervals.
two_logit <- obj$models$two_logit; two_gamma <- obj$models$two_gamma
p_pos <- predict(two_logit,test,type="response")
mu_pos <- predict(two_gamma,test,type="response")
phi <- summary(two_gamma)$dispersion
shape <- 1/phi
scale <- mu_pos/shape
set.seed(7980)
B <- 1000
sim_quant <- function(i) {
  z <- rbinom(B,1,p_pos[i])
  vals <- ifelse(z==1, rgamma(B,shape=shape,scale=scale[i]),0)
  quantile(vals,c(.05,.95),na.rm=TRUE,names=FALSE)
}
qsim <- t(vapply(seq_len(nrow(test)),sim_quant,numeric(2)))
test$pi_param_lo <- qsim[,1]; test$pi_param_hi <- qsim[,2]

# Overall interval comparison
intervals <- tribble(
  ~method,~lo,~hi,
  "Split conformal absolute","pi_abs_lo","pi_abs_hi",
  "Split conformal scaled","pi_scaled_lo","pi_scaled_hi",
  "CQR","pi_cqr_lo","pi_cqr_hi",
  "Two-part gamma parametric","pi_param_lo","pi_param_hi"
)
interval_results <- pmap_dfr(intervals,function(method,lo,hi) coverage_summary(test,lo,hi) |> mutate(method=method))
write_csv(interval_results,"results/tables/interval_performance.csv")

# Predictability index = interval width / predicted mean (stabilized by +1)
test <- test |> mutate(cqr_width=pi_cqr_hi-pi_cqr_lo,
                       predictability_index=cqr_width/(.data[[pcol]]+1))

# Coverage by required syllabus groups
subgroups <- c("age_group","race_eth","insurance","income_cat","chronic_group")
subgroup_results <- map_dfr(subgroups,function(g) {
  coverage_summary(test,"pi_cqr_lo","pi_cqr_hi",g) |> mutate(grouping_variable=g, level=as.character(.data[[g]])) |>
    select(grouping_variable,level,everything(),-all_of(g))
})
write_csv(subgroup_results,"results/tables/subgroup_cqr_coverage.csv")

# ----- E. Mondrian/group-conditional conformal -------------------------------
# Build group-specific residual quantiles on calibration data. Use age group as
# the primary demonstration; the same function can be used for any subgroup.
mondrian_apply <- function(cal,test,group,pred_col,alpha=.10,min_cal=40) {
  global_q <- weighted_quantile(abs(cal$y2_exp-cal[[pred_col]]),cal$weight,1-alpha)
  qs <- cal |> mutate(score=abs(y2_exp-.data[[pred_col]])) |>
    group_by(.data[[group]]) |>
    summarise(n=n(), q=if(n()>=min_cal) weighted_quantile(score,weight,1-alpha) else global_q,
              .groups="drop")
  out <- test |> left_join(qs,by=group) |>
    mutate(q=replace_na(q,global_q), mondrian_lo=pmax(0,.data[[pred_col]]-q), mondrian_hi=.data[[pred_col]]+q)
  list(data=out,quantiles=qs)
}
mond_age <- mondrian_apply(cal,test,"age_group",pcol,alpha)
test_m <- mond_age$data
mond_cov <- coverage_summary(test_m,"mondrian_lo","mondrian_hi","age_group")
write_csv(mond_cov,"results/tables/mondrian_age_coverage.csv")

# Width cost: compare group-conditional interval width with global split conformal.
width_cost <- test_m |> mutate(global_width=pi_abs_hi-pi_abs_lo, mondrian_width=mondrian_hi-mondrian_lo) |>
  group_by(age_group) |>
  summarise(global_width=weighted_mean(global_width,weight),
            mondrian_width=weighted_mean(mondrian_width,weight),
            width_cost=mondrian_width-global_width,.groups="drop")
write_csv(width_cost,"results/tables/mondrian_width_cost.csv")

# Coverage figure
pcov <- subgroup_results |>
  ggplot(aes(x=level,y=coverage)) + geom_hline(yintercept=.90,linetype=2) + geom_point() +
  facet_wrap(~grouping_variable,scales="free_x") + coord_cartesian(ylim=c(0,1)) +
  labs(title="CQR coverage by subgroup",x=NULL,y="Survey-weighted coverage") + theme_minimal() +
  theme(axis.text.x=element_text(angle=45,hjust=1))
ggsave("results/figures/subgroup_coverage.png",pcov,width=11,height=8,dpi=300)

saveRDS(test_m,"data_processed/test_with_intervals.rds")
write_csv(test_m,"data_processed/test_with_intervals.csv")
