# ML methods reference

Defaults to start from. The baseline always runs first and the model
must beat it on the test split by more than the noise floor.

## By task

| Task | Baseline | Default model | Metric | Watch for |
| --- | --- | --- | --- | --- |
| classify (churn, fraud, lead score) | a rule on recency or a threshold on one feature | LightGBM or XGBoost, class weights for imbalance | AUC plus precision at the top k the action can handle | label window leakage, imbalance hiding in accuracy |
| regress (price, duration, value) | the median per segment | gradient-boosted trees | MAE and error by segment | outliers dominating RMSE |
| forecast (demand, load) | same period last week or last year | a seasonal model (ETS, Prophet-style) or trees on lag features | MAE or MAPE per series, by horizon | holidays, festivals, promotions as features |
| anomaly (metrics, transactions) | rolling mean and standard deviation band | seasonal decomposition (STL) residuals with a robust band, or an isolation forest on features | recall on planted incidents, false alarms per week, time to detect | seasonality, repeated alerts on one incident |
| rank (recommendation, next best action) | popularity | trees on user and item features, then learning to rank | NDCG or hit rate at k on a later period | popularity bias, feedback loops |

## Splits

- Time split for anything a person will act on in the future.
- Group split when one unit (user, account, device, store) has many rows.
- Keep a final test period untouched until the gate runs once.

## Calibration and explanation

- Brier score and a calibration curve; isotonic regression on the
  validation split when the curve bends.
- SHAP values for tree models: global summary for the team, the top
  three reasons per prediction in plain words for the people who act.

## Serving and monitoring

- Batch scoring into a table by default; a service only when a user
  waits on the answer. ONNX export when the caller is not Python.
- Population stability index per feature, alert above 0.2; the realised
  metric recomputed when labels arrive; retrain on a schedule and on a
  drift alert, never automatically promoted without the gate.

## Uplift and experiments

A churn score says who will leave, not who a nudge will keep. Keep a
random holdout in every campaign built on a score and measure the lift
with `ab-experiment`; move to uplift models only after a holdout shows
the nudge works for some segments and not others.
