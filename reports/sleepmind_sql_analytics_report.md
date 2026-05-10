# SleepMind SQL Product Analytics Report

## Executive Summary

SleepMind SQL Product Analytics is a portfolio case study for a synthetic sleep-tracking healthtech app.

The project simulates a realistic product analytics workflow: designing a PostgreSQL analytics database, generating event-level data, validating data quality, analyzing onboarding, retention, sleep improvement, A/B test results and churn risk.

The main analytical value of the project is not only the SQL implementation, but the interpretation of product behavior:

- activation loss happens early, between registration and first app open;
- acquisition channel quality matters more than device differences;
- personalized recommendations strongly increase engagement, but do not yet prove D30 retention impact;
- churn-risk segmentation can be used for targeted lifecycle campaigns;
- A/B test results should not be overstated when engagement improves but retention does not.

## Business Question

Which user behaviors are associated with better retention, stronger engagement and sleep improvement?

The analysis focuses on five product areas:

1. onboarding funnel;
2. cohort retention;
3. sleep-score improvement;
4. A/B test performance;
5. churn-risk segmentation.

## Data Model

The synthetic PostgreSQL database contains six core tables:

| Table | Description |
|---|---|
| `users` | User signup date, country, device and acquisition channel |
| `app_events` | Product events such as app opens, sleep logs, recommendation views and diary opens |
| `sleep_sessions` | Sleep duration, sleep efficiency, awakenings and sleep score |
| `recommendations` | Recommendation type, mode and click behavior |
| `subscriptions` | Trial, paid and cancellation status |
| `experiment_assignments` | A/B test group assignment |

## Analysis Workflow

The project follows a typical product analytics workflow:

1. Validate database quality.
2. Build onboarding funnel.
3. Calculate cohort retention.
4. Measure sleep-score improvement.
5. Analyze A/B test results.
6. Build churn-risk segments.
7. Translate findings into product recommendations.

## 1. Data Quality Checks

Before analysis, the dataset was checked for:

- duplicate primary keys;
- missing values in key fields;
- foreign key integrity issues;
- invalid date sequences;
- out-of-range sleep metrics;
- duplicate behavioral events.

No critical data quality issues were found. All six tables were successfully loaded into PostgreSQL and could be used for downstream analysis.

## 2. Onboarding Funnel

The onboarding funnel included the following steps:

1. registration;
2. first app open;
3. first sleep log;
4. first recommendation viewed;
5. second sleep log;
6. D7 retained.

| Funnel step | Users | Conversion from registration |
|---|---:|---:|
| Registration | 1,200 | 100.00% |
| First app open | 1,095 | 91.25% |
| First sleep log | 1,095 | 91.25% |
| First recommendation viewed | 1,095 | 91.25% |
| Second sleep log | 1,095 | 91.25% |
| D7 retained | 855 | 71.25% |

### Interpretation

The largest early drop-off happens between registration and first app open.

Users who open the app for the first time usually continue to complete core onboarding actions such as logging sleep and viewing recommendations.

### Product implication

The first-session experience is likely more important than later onboarding steps. Product work should focus on activation reminders, first-open motivation and reducing friction immediately after registration.

## 3. Cohort Retention

Retention was calculated by signup cohort and lifecycle day.

| Metric | Retention |
|---|---:|
| D1 retention | 76.92% |
| D7 retention | 78.33% |
| D14 retention | 76.58% |
| D30 retention | 76.58% |

Retention by device was almost identical, while acquisition channel showed stronger differences.

Best D30 retention:

| Acquisition channel | D30 retention |
|---|---:|
| paid_ads | 79.87% |
| organic | 78.65% |

Weakest D30 retention:

| Acquisition channel | D30 retention |
|---|---:|
| content | 68.14% |

### Interpretation

Retention differences are more visible by acquisition channel than by device.

### Product implication

Marketing quality should be evaluated not only by acquisition volume, but also by downstream retention. The `content` channel requires further investigation because it brings users with weaker D30 retention.

## 4. Sleep Improvement

Sleep improvement was measured as the difference between:

- baseline period: days 0-6 after signup;
- follow-up period: days 14-30 after signup.

| Metric | Value |
|---|---:|
| Users analyzed | 990 |
| Baseline average sleep score | 67.82 |
| Follow-up average sleep score | 69.31 |
| Average sleep score delta | +1.49 |

Sleep change segments:

| Segment | Users | Share | Average sleep score delta |
|---|---:|---:|---:|
| Improved | 452 | 45.66% | +4.80 |
| Stable | 365 | 36.87% | +0.15 |
| Worsened | 173 | 17.47% | -4.35 |

### Interpretation

Average sleep score improved slightly. Users with higher early sleep logging frequency showed somewhat stronger sleep-score improvement.

### Product implication

Early logging habit may be an important behavioral signal. The product should encourage sleep logging during the first week, but the result should not be interpreted as a causal medical effect.

## 5. A/B Test Analysis

The experiment compared two recommendation modes:

- control: generic sleep recommendations;
- treatment: personalized sleep recommendations.

| Metric | Control | Treatment | Lift |
|---|---:|---:|---:|
| D7 retention | 77.46% | 79.20% | +1.74 pp |
| D30 retention | 76.46% | 76.71% | +0.24 pp |
| Recommendation CTR | 38.11% | 55.32% | +17.21 pp |
| Paid conversion | 21.87% | 20.80% | -1.07 pp |
| Sleep score delta | +1.32 | +1.65 | +0.33 |

Additional D30 retention check:

| Metric | Value |
|---|---:|
| D30 lift | +0.24 pp |
| Approximate z-score | 0.100 |

### Interpretation

Personalized recommendations substantially increased recommendation CTR.

However, the D30 retention lift was very small. The experiment does not provide convincing evidence of meaningful D30 retention improvement.

### Product implication

Personalization can be treated as an engagement win, but not yet as a retention win. A mature analyst should not recommend a full rollout based only on CTR unless the product goal is explicitly engagement.

## 6. Churn-Risk Segmentation

A churn-risk score was built using behavioral and subscription signals:

- inactivity during days 24-30;
- low number of sleep logs;
- worsening sleep score;
- no recommendation clicks;
- trial expiration or cancellation;
- no D30 retention.

| Risk segment | Users | Share | Average risk score | D30 retention |
|---|---:|---:|---:|---:|
| High risk | 88 | 7.33% | 7.53 | 0.00% |
| Medium risk | 356 | 29.67% | 4.75 | 52.81% |
| Low risk | 756 | 63.00% | 1.95 | 96.69% |

### Interpretation

The churn-risk score clearly separates users by retention outcome.

### Product implication

High-risk users should receive earlier lifecycle interventions. Medium-risk users are likely the best target for recovery experiments because they still have meaningful retention potential.

## Business Recommendations

Based on the analysis, the strongest product opportunities are:

1. Improve activation after registration.
2. Monitor D7 and D30 retention by acquisition channel.
3. Investigate why the `content` channel has weaker D30 retention.
4. Encourage early sleep logging during the first week.
5. Keep personalized recommendations as an engagement feature.
6. Do not claim retention improvement from personalization without additional evidence.
7. Use churn-risk segments for targeted lifecycle campaigns.
8. Run a larger follow-up experiment focused on retention and paid conversion.

## Limitations

This project uses synthetic data and is intended for portfolio demonstration.

Main limitations:

- synthetic data does not fully represent real user behavior;
- A/B test interpretation is simplified;
- confidence intervals and formal uncertainty estimates can be expanded;
- sleep-score improvement should not be interpreted as a medical effect;
- churn-risk segmentation is rule-based and not a validated predictive model;
- the project demonstrates analytics workflow rather than production decision automation.

## Next Steps

Recommended next analytical improvements:

- add confidence intervals for key product metrics;
- add Bayesian or bootstrap uncertainty estimates for A/B testing;
- compare churn-risk rules with a supervised churn model;
- add dashboard-ready aggregate tables;
- build a short executive dashboard;
- test lifecycle interventions for medium-risk users;
- expand the report with SQL query references for each result.

## Skills Demonstrated

This case study demonstrates:

- SQL analytics;
- PostgreSQL data modeling;
- product funnel analysis;
- cohort retention analysis;
- A/B test interpretation;
- churn-risk segmentation;
- synthetic data generation;
- business recommendation writing;
- careful communication of limitations.

## Conclusion

The project shows a complete product analytics workflow for a sleep-tracking app.

The strongest conclusion is that personalization improves recommendation engagement, while retention impact remains unproven. The best near-term product opportunities are activation improvement, acquisition quality monitoring and targeted lifecycle campaigns for churn-risk segments.
