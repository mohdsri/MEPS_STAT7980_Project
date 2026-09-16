# How to explain each step to your advisor

1. **Choose the longitudinal file.** Use HC-217 because the same individuals are followed across 2018 and 2019. Predictors are taken from Year 1 and the outcome is Year-2 expenditure. This makes the temporal direction clear.
2. **Respect MEPS design.** Use LONGWT for population-representative weighting and VARSTR/VARPSU for design-based descriptive standard errors.
3. **Clean MEPS missing codes.** Negative numeric values are not real measurements; convert them to NA before modeling.
4. **Pre-specify predictors.** Choose clinically and policy-relevant domains from the syllabus rather than searching thousands of variables until performance looks good.
5. **Describe the outcome first.** Quantify zero spending, skewness, concentration, and persistence. This motivates two-part/Gamma/Tweedie/log-scale models.
6. **Separate train, calibration, and test.** Training estimates models; calibration constructs conformal intervals; test gives final unbiased evaluation.
7. **Fit classical models.** Two-part Gamma, Tweedie, and log-OLS are standard methods for healthcare costs and are interpretable to a statistics committee.
8. **Fit flexible models.** Quantile regression models conditional quantiles; XGBoost captures nonlinearities and interactions.
9. **Evaluate with survey weights.** Report RMSE, MAE, R2, calibration, AUC, and PPV at a fixed 5% budget.
10. **Interpret feature importance cautiously.** XGBoost gain measures predictive importance, not causality.
11. **Add conformal prediction.** Use a held-out calibration sample to transform point or quantile predictions into intervals with a distribution-free marginal coverage target.
12. **Audit subgroup coverage.** Compare coverage across age, race/ethnicity, insurance, income, and chronic-condition groups.
13. **Use Mondrian conformal if needed.** Calibrate residual cutoffs within groups and quantify the price paid in wider intervals.
14. **Test the value of history.** Remove prior-year spending/utilization and check how much the interval widens.
15. **Replicate.** Evaluate the structure in Panel 24 to see whether results are stable in another longitudinal panel.
