# =============================================================================
# Helper functions used throughout the analysis
# =============================================================================

weighted_mean <- function(x, w) {
  ok <- is.finite(x) & is.finite(w) & w > 0
  sum(x[ok] * w[ok]) / sum(w[ok])
}

weighted_quantile <- function(x, w, probs = 0.5) {
  ok <- is.finite(x) & is.finite(w) & w > 0
  x <- x[ok]; w <- w[ok]
  if (!length(x)) return(rep(NA_real_, length(probs)))
  o <- order(x)
  x <- x[o]; w <- w[o]
  cw <- cumsum(w) / sum(w)
  vapply(probs, function(p) x[which(cw >= p)[1]], numeric(1))
}

weighted_rmse <- function(y, p, w) {
  sqrt(weighted_mean((y - p)^2, w))
}
weighted_mae <- function(y, p, w) {
  weighted_mean(abs(y - p), w)
}
weighted_r2 <- function(y, p, w) {
  mu <- weighted_mean(y, w)
  1 - weighted_mean((y - p)^2, w) / weighted_mean((y - mu)^2, w)
}

w_auc <- function(y, score, w) {
  # pROC supports case weights only indirectly; duplicate-free weighted AUC
  pos <- which(y == 1 & w > 0 & is.finite(score))
  neg <- which(y == 0 & w > 0 & is.finite(score))
  if (!length(pos) || !length(neg)) return(NA_real_)
  # Efficient weighted rank-style calculation
  d <- tibble(score = score[c(pos, neg)], y = y[c(pos, neg)], w = w[c(pos, neg)]) |>
    arrange(score)
  # Group ties and give half credit within ties
  g <- d |>
    group_by(score) |>
    summarise(w_pos = sum(w[y == 1]), w_neg = sum(w[y == 0]), .groups = "drop") |>
    mutate(cum_neg_before = lag(cumsum(w_neg), default = 0))
  num <- sum(g$w_pos * (g$cum_neg_before + 0.5 * g$w_neg))
  den <- sum(g$w_pos) * sum(g$w_neg)
  num / den
}

ppv_at_budget <- function(y, score, w, budget_fraction = 0.05) {
  d <- tibble(y = y, score = score, w = w) |>
    filter(is.finite(score), is.finite(w), w > 0) |>
    arrange(desc(score)) |>
    mutate(cw = cumsum(w) / sum(w), selected = cw <= budget_fraction)
  if (!any(d$selected)) d$selected[1] <- TRUE
  weighted_mean(d$y[d$selected], d$w[d$selected])
}

normalize_weights <- function(w) w / mean(w[w > 0], na.rm = TRUE)

clean_meps_numeric <- function(x) {
  # MEPS negative values are typically inapplicable / not ascertained / refused / don't know.
  x <- as.numeric(x)
  x[x < 0] <- NA_real_
  x
}

binary_yes <- function(x) {
  # Many MEPS diagnosis indicators use 1=Yes, 2=No, negative=missing.
  case_when(as.numeric(x) == 1 ~ 1, as.numeric(x) == 2 ~ 0, TRUE ~ NA_real_)
}

make_age_group <- function(age) cut(age, breaks = c(-Inf,17,34,49,64,Inf),
                                    labels = c("0-17","18-34","35-49","50-64","65+"))

make_chronic_group <- function(n) cut(n, breaks = c(-Inf,0,1,2,Inf),
                                      labels = c("0","1","2","3+"))

weighted_calibration_table <- function(dat, pred_col, outcome_col = "y2_exp", n_bins = 10) {
  pred <- dat[[pred_col]]
  qs <- weighted_quantile(pred, dat$weight, probs = seq(0, 1, length.out = n_bins + 1))
  qs <- unique(qs)
  dat |>
    mutate(bin = cut(.data[[pred_col]], breaks = qs, include.lowest = TRUE, labels = FALSE)) |>
    filter(!is.na(bin)) |>
    group_by(bin) |>
    summarise(
      n = n(),
      weighted_n = sum(weight),
      predicted = weighted_mean(.data[[pred_col]], weight),
      observed = weighted_mean(.data[[outcome_col]], weight),
      .groups = "drop"
    )
}

coverage_summary <- function(dat, lo, hi, group = NULL) {
  x <- dat |>
    mutate(covered = y2_exp >= .data[[lo]] & y2_exp <= .data[[hi]],
           width = .data[[hi]] - .data[[lo]],
           low_miss = y2_exp < .data[[lo]],
           high_miss = y2_exp > .data[[hi]])
  if (is.null(group)) {
    x |>
      summarise(n = n(), coverage = weighted_mean(covered, weight),
                mean_width = weighted_mean(width, weight),
                lower_miscoverage = weighted_mean(low_miss, weight),
                upper_miscoverage = weighted_mean(high_miss, weight))
  } else {
    x |>
      group_by(.data[[group]]) |>
      summarise(n = n(), coverage = weighted_mean(covered, weight),
                mean_width = weighted_mean(width, weight),
                lower_miscoverage = weighted_mean(low_miss, weight),
                upper_miscoverage = weighted_mean(high_miss, weight), .groups = "drop")
  }
}
