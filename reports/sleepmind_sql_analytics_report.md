\# SleepMind SQL Product Analytics Report



\## Project overview



SleepMind SQL Product Analytics is a portfolio project simulating the analytics workflow for a sleep-tracking healthtech app.



The project uses a synthetic PostgreSQL database with user-level, event-level, sleep, recommendation, subscription and A/B experiment data.



The main business question:



> Which user behaviors are associated with better retention, stronger engagement and sleep improvement?



\## Data model



The database contains six core tables:



\- `users` — user signup date, country, device and acquisition channel

\- `app\_events` — product behavior events such as app opens, sleep logs and recommendation views

\- `sleep\_sessions` — sleep duration, sleep efficiency, awakenings and sleep score

\- `recommendations` — recommendation type, mode and click behavior

\- `subscriptions` — trial and paid subscription status

\- `experiment\_assignments` — A/B test group assignment



\## 1. Data quality checks



Before analysis, the dataset was checked for:



\- duplicate primary keys

\- missing values in key fields

\- foreign key integrity issues

\- invalid date sequences

\- out-of-range sleep metrics

\- duplicate behavioral events



No critical data quality issues were found. All six tables were successfully loaded into PostgreSQL.



\## 2. Onboarding funnel



The onboarding funnel included the following steps:



1\. Registration

2\. First app open

3\. First sleep log

4\. First recommendation viewed

5\. Second sleep log

6\. D7 retained



Main results:



| Funnel step | Users | Conversion from registration |

|---|---:|---:|

| Registration | 1,200 | 100.00% |

| First app open | 1,095 | 91.25% |

| First sleep log | 1,095 | 91.25% |

| First recommendation viewed | 1,095 | 91.25% |

| Second sleep log | 1,095 | 91.25% |

| D7 retained | 855 | 71.25% |



The largest early drop-off happens between registration and first app open.



Users who open the app for the first time usually continue to complete core onboarding actions such as logging sleep and viewing recommendations.



\## 3. Cohort retention



Retention was calculated by signup week and lifecycle day.



Average retention:



| Metric | Retention |

|---|---:|

| D1 retention | 76.92% |

| D7 retention | 78.33% |

| D14 retention | 76.58% |

| D30 retention | 76.58% |



Retention by acquisition channel showed that `paid\_ads` and `organic` users had the strongest D30 retention.



| Acquisition channel | D30 retention |

|---|---:|

| paid\_ads | 79.87% |

| organic | 78.65% |

| app\_store | 74.89% |

| referral | 74.89% |

| content | 68.14% |



Retention by device was almost identical:



| Device | D30 retention |

|---|---:|

| Android | 76.66% |

| iOS | 76.47% |



This suggests that acquisition channel is more important for retention differences than device type.



\## 4. Sleep improvement analysis



Sleep improvement was measured as the difference between:



\- baseline period: days 0–6 after signup

\- follow-up period: days 14–30 after signup



Users were included only if they had at least two sleep logs in both periods.



Main results:



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



Users with higher early sleep logging frequency showed slightly stronger improvement:



| Segment | Average sleep score delta |

|---|---:|

| High logging | +1.69 |

| Medium logging | +1.49 |

| Low logging | +1.23 |



This suggests that consistent early sleep logging is associated with better sleep-score improvement.



\## 5. A/B test analysis



The experiment compared:



\- control: generic sleep recommendations

\- treatment: personalized sleep recommendations



Sample size:



| Group | Users |

|---|---:|

| Control | 599 |

| Treatment | 601 |



Main experiment metrics:



| Metric | Control | Treatment | Lift |

|---|---:|---:|---:|

| D7 retention | 77.46% | 79.20% | +1.74 pp |

| D30 retention | 76.46% | 76.71% | +0.24 pp |

| Recommendation CTR | 38.11% | 55.32% | +17.21 pp |

| Paid conversion | 21.87% | 20.80% | -1.07 pp |

| Sleep score delta | +1.32 | +1.65 | +0.33 |



The treatment group showed much higher recommendation CTR and slightly higher sleep-score improvement.



However, the D30 retention lift was very small:



| Metric | Value |

|---|---:|

| Control D30 retention | 76.46% |

| Treatment D30 retention | 76.71% |

| D30 lift | +0.24 pp |

| Approximate z-score | 0.100 |



The experiment does not provide convincing evidence of a meaningful D30 retention improvement.



\## 6. Churn risk analysis



A churn-risk score was built using:



\- inactivity during days 24–30

\- low number of sleep logs

\- worsening sleep score

\- no recommendation clicks

\- trial expiration or cancellation

\- no D30 retention



Risk segment distribution:



| Risk segment | Users | Share | Average risk score | D30 retention |

|---|---:|---:|---:|---:|

| High risk | 88 | 7.33% | 7.53 | 0.00% |

| Medium risk | 356 | 29.67% | 4.75 | 52.81% |

| Low risk | 756 | 63.00% | 1.95 | 96.69% |



The churn-risk score clearly separates users by retention outcome.



Recommended product actions:



| Segment | Recommended action |

|---|---|

| High risk | Send reactivation campaign with personalized sleep insight and sleep-log reminder |

| Medium risk | Send low-friction habit prompt and highlight one personalized recommendation |

| Low risk | Keep standard engagement flow and avoid excessive notifications |



\## Key conclusions



1\. The largest onboarding drop-off happens before the first app open.

2\. Acquisition channel is more important for retention differences than device type.

3\. Users with frequent early sleep logging show stronger sleep-score improvement.

4\. Personalized recommendations increase recommendation CTR substantially.

5\. The A/B test does not show a meaningful D30 retention lift.

6\. Churn-risk segmentation successfully identifies users with low retention probability.



\## Business recommendations



1\. Improve activation from registration to first app open.

2\. Investigate why the `content` acquisition channel has weaker D30 retention.

3\. Encourage early sleep logging during the first week.

4\. Keep personalized recommendations because they increase engagement.

5\. Do not claim retention improvement from personalization without further testing.

6\. Use churn-risk segments for targeted lifecycle campaigns.

