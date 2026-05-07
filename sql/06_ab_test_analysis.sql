-- 06_ab_test_analysis.sql
-- A/B test analysis for SleepMind SQL Product Analytics
-- Experiment: personalized_sleep_recommendations
--
-- Control: generic sleep recommendations
-- Treatment: personalized sleep recommendations
--
-- Goal: compare product and sleep-related outcomes between groups.


-- 1. Experiment sample size

SELECT
    experiment_group,
    COUNT(*) AS users_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS users_percent
FROM experiment_assignments
GROUP BY experiment_group
ORDER BY experiment_group;


-- 2. Randomization balance check by device

SELECT
    ea.experiment_group,
    u.device,
    COUNT(*) AS users_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (
            PARTITION BY ea.experiment_group
        ),
        2
    ) AS group_percent
FROM experiment_assignments ea
JOIN users u
    ON ea.user_id = u.user_id
GROUP BY
    ea.experiment_group,
    u.device
ORDER BY
    ea.experiment_group,
    u.device;


-- 3. Randomization balance check by acquisition channel

SELECT
    ea.experiment_group,
    u.acquisition_channel,
    COUNT(*) AS users_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (
            PARTITION BY ea.experiment_group
        ),
        2
    ) AS group_percent
FROM experiment_assignments ea
JOIN users u
    ON ea.user_id = u.user_id
GROUP BY
    ea.experiment_group,
    u.acquisition_channel
ORDER BY
    ea.experiment_group,
    u.acquisition_channel;


-- 4. User-level experiment metrics

WITH user_metrics AS (
    SELECT
        u.user_id,
        ea.experiment_group,
        u.signup_date,

        MAX(
            CASE
                WHEN ae.event_time::date = u.signup_date + 7 THEN 1
                ELSE 0
            END
        ) AS d7_retained,

        MAX(
            CASE
                WHEN ae.event_time::date = u.signup_date + 30 THEN 1
                ELSE 0
            END
        ) AS d30_retained,

        COUNT(DISTINCT ae.event_id) FILTER (
            WHERE ae.event_name = 'app_open'
              AND ae.event_time::date BETWEEN u.signup_date AND u.signup_date + 30
        ) AS app_opens_30d,

        COUNT(DISTINCT ae.event_id) FILTER (
            WHERE ae.event_name = 'sleep_log_added'
              AND ae.event_time::date BETWEEN u.signup_date AND u.signup_date + 30
        ) AS sleep_logs_30d,

        COUNT(DISTINCT r.recommendation_id) FILTER (
            WHERE r.shown_at::date BETWEEN u.signup_date AND u.signup_date + 14
        ) AS recommendations_shown_14d,

        COUNT(DISTINCT r.recommendation_id) FILTER (
            WHERE r.shown_at::date BETWEEN u.signup_date AND u.signup_date + 14
              AND r.clicked = 1
        ) AS recommendations_clicked_14d,

        MAX(
            CASE
                WHEN s.subscription_status = 'paid' THEN 1
                ELSE 0
            END
        ) AS converted_to_paid

    FROM users u
    JOIN experiment_assignments ea
        ON u.user_id = ea.user_id
    LEFT JOIN app_events ae
        ON u.user_id = ae.user_id
    LEFT JOIN recommendations r
        ON u.user_id = r.user_id
    LEFT JOIN subscriptions s
        ON u.user_id = s.user_id
    GROUP BY
        u.user_id,
        ea.experiment_group,
        u.signup_date
)

SELECT
    experiment_group,
    COUNT(*) AS users_count,

    ROUND(100.0 * AVG(d7_retained)::numeric, 2) AS d7_retention_percent,
    ROUND(100.0 * AVG(d30_retained)::numeric, 2) AS d30_retention_percent,

    ROUND(AVG(app_opens_30d)::numeric, 2) AS avg_app_opens_30d,
    ROUND(AVG(sleep_logs_30d)::numeric, 2) AS avg_sleep_logs_30d,

    ROUND(AVG(recommendations_shown_14d)::numeric, 2) AS avg_recommendations_shown_14d,
    ROUND(AVG(recommendations_clicked_14d)::numeric, 2) AS avg_recommendations_clicked_14d,

    ROUND(
        100.0 * SUM(recommendations_clicked_14d)::numeric
        / NULLIF(SUM(recommendations_shown_14d), 0),
        2
    ) AS recommendation_ctr_percent,

    ROUND(100.0 * AVG(converted_to_paid)::numeric, 2) AS paid_conversion_percent

FROM user_metrics
GROUP BY experiment_group
ORDER BY experiment_group;


-- 5. Sleep score delta by experiment group

WITH user_sleep_periods AS (
    SELECT
        u.user_id,
        ea.experiment_group,

        COUNT(*) FILTER (
            WHERE ss.sleep_date BETWEEN u.signup_date AND u.signup_date + 6
        ) AS baseline_sleep_logs,

        COUNT(*) FILTER (
            WHERE ss.sleep_date BETWEEN u.signup_date + 14 AND u.signup_date + 30
        ) AS followup_sleep_logs,

        AVG(ss.sleep_score) FILTER (
            WHERE ss.sleep_date BETWEEN u.signup_date AND u.signup_date + 6
        ) AS baseline_avg_sleep_score,

        AVG(ss.sleep_score) FILTER (
            WHERE ss.sleep_date BETWEEN u.signup_date + 14 AND u.signup_date + 30
        ) AS followup_avg_sleep_score

    FROM users u
    JOIN experiment_assignments ea
        ON u.user_id = ea.user_id
    JOIN sleep_sessions ss
        ON u.user_id = ss.user_id
    GROUP BY
        u.user_id,
        ea.experiment_group
),

user_sleep_delta AS (
    SELECT
        user_id,
        experiment_group,
        baseline_avg_sleep_score,
        followup_avg_sleep_score,
        followup_avg_sleep_score - baseline_avg_sleep_score AS sleep_score_delta
    FROM user_sleep_periods
    WHERE baseline_sleep_logs >= 2
      AND followup_sleep_logs >= 2
)

SELECT
    experiment_group,
    COUNT(*) AS users_analyzed,
    ROUND(AVG(baseline_avg_sleep_score)::numeric, 2) AS baseline_avg_sleep_score,
    ROUND(AVG(followup_avg_sleep_score)::numeric, 2) AS followup_avg_sleep_score,
    ROUND(AVG(sleep_score_delta)::numeric, 2) AS avg_sleep_score_delta,
    ROUND(STDDEV(sleep_score_delta)::numeric, 2) AS stddev_sleep_score_delta

FROM user_sleep_delta
GROUP BY experiment_group
ORDER BY experiment_group;


-- 6. Treatment effect summary

WITH user_metrics AS (
    SELECT
        u.user_id,
        ea.experiment_group,
        u.signup_date,

        MAX(
            CASE
                WHEN ae.event_time::date = u.signup_date + 7 THEN 1
                ELSE 0
            END
        ) AS d7_retained,

        MAX(
            CASE
                WHEN ae.event_time::date = u.signup_date + 30 THEN 1
                ELSE 0
            END
        ) AS d30_retained,

        COUNT(DISTINCT ae.event_id) FILTER (
            WHERE ae.event_name = 'sleep_log_added'
              AND ae.event_time::date BETWEEN u.signup_date AND u.signup_date + 30
        ) AS sleep_logs_30d,

        COUNT(DISTINCT r.recommendation_id) FILTER (
            WHERE r.shown_at::date BETWEEN u.signup_date AND u.signup_date + 14
        ) AS recommendations_shown_14d,

        COUNT(DISTINCT r.recommendation_id) FILTER (
            WHERE r.shown_at::date BETWEEN u.signup_date AND u.signup_date + 14
              AND r.clicked = 1
        ) AS recommendations_clicked_14d,

        MAX(
            CASE
                WHEN s.subscription_status = 'paid' THEN 1
                ELSE 0
            END
        ) AS converted_to_paid

    FROM users u
    JOIN experiment_assignments ea
        ON u.user_id = ea.user_id
    LEFT JOIN app_events ae
        ON u.user_id = ae.user_id
    LEFT JOIN recommendations r
        ON u.user_id = r.user_id
    LEFT JOIN subscriptions s
        ON u.user_id = s.user_id
    GROUP BY
        u.user_id,
        ea.experiment_group,
        u.signup_date
),

group_metrics AS (
    SELECT
        experiment_group,
        COUNT(*) AS users_count,
        AVG(d7_retained)::numeric AS d7_retention,
        AVG(d30_retained)::numeric AS d30_retention,
        AVG(sleep_logs_30d)::numeric AS avg_sleep_logs_30d,
        AVG(converted_to_paid)::numeric AS paid_conversion,

        SUM(recommendations_clicked_14d)::numeric
        / NULLIF(SUM(recommendations_shown_14d), 0) AS recommendation_ctr

    FROM user_metrics
    GROUP BY experiment_group
),

wide AS (
    SELECT
        MAX(users_count) FILTER (WHERE experiment_group = 'control') AS control_users,
        MAX(users_count) FILTER (WHERE experiment_group = 'treatment') AS treatment_users,

        MAX(d7_retention) FILTER (WHERE experiment_group = 'control') AS control_d7_retention,
        MAX(d7_retention) FILTER (WHERE experiment_group = 'treatment') AS treatment_d7_retention,

        MAX(d30_retention) FILTER (WHERE experiment_group = 'control') AS control_d30_retention,
        MAX(d30_retention) FILTER (WHERE experiment_group = 'treatment') AS treatment_d30_retention,

        MAX(avg_sleep_logs_30d) FILTER (WHERE experiment_group = 'control') AS control_sleep_logs_30d,
        MAX(avg_sleep_logs_30d) FILTER (WHERE experiment_group = 'treatment') AS treatment_sleep_logs_30d,

        MAX(recommendation_ctr) FILTER (WHERE experiment_group = 'control') AS control_recommendation_ctr,
        MAX(recommendation_ctr) FILTER (WHERE experiment_group = 'treatment') AS treatment_recommendation_ctr,

        MAX(paid_conversion) FILTER (WHERE experiment_group = 'control') AS control_paid_conversion,
        MAX(paid_conversion) FILTER (WHERE experiment_group = 'treatment') AS treatment_paid_conversion

    FROM group_metrics
)

SELECT
    control_users,
    treatment_users,

    ROUND(100.0 * control_d7_retention, 2) AS control_d7_retention_percent,
    ROUND(100.0 * treatment_d7_retention, 2) AS treatment_d7_retention_percent,
    ROUND(100.0 * (treatment_d7_retention - control_d7_retention), 2) AS d7_retention_lift_pp,

    ROUND(100.0 * control_d30_retention, 2) AS control_d30_retention_percent,
    ROUND(100.0 * treatment_d30_retention, 2) AS treatment_d30_retention_percent,
    ROUND(100.0 * (treatment_d30_retention - control_d30_retention), 2) AS d30_retention_lift_pp,

    ROUND(control_sleep_logs_30d, 2) AS control_avg_sleep_logs_30d,
    ROUND(treatment_sleep_logs_30d, 2) AS treatment_avg_sleep_logs_30d,
    ROUND(treatment_sleep_logs_30d - control_sleep_logs_30d, 2) AS sleep_logs_30d_lift,

    ROUND(100.0 * control_recommendation_ctr, 2) AS control_recommendation_ctr_percent,
    ROUND(100.0 * treatment_recommendation_ctr, 2) AS treatment_recommendation_ctr_percent,
    ROUND(100.0 * (treatment_recommendation_ctr - control_recommendation_ctr), 2) AS recommendation_ctr_lift_pp,

    ROUND(100.0 * control_paid_conversion, 2) AS control_paid_conversion_percent,
    ROUND(100.0 * treatment_paid_conversion, 2) AS treatment_paid_conversion_percent,
    ROUND(100.0 * (treatment_paid_conversion - control_paid_conversion), 2) AS paid_conversion_lift_pp

FROM wide;


-- 7. Approximate z-test for D30 retention difference
-- This is a lightweight SQL approximation. A stricter statistical test
-- can be added in Python later.

WITH group_retention AS (
    SELECT
        ea.experiment_group,
        COUNT(DISTINCT u.user_id) AS n_users,
        COUNT(DISTINCT u.user_id) FILTER (
            WHERE EXISTS (
                SELECT 1
                FROM app_events ae
                WHERE ae.user_id = u.user_id
                  AND ae.event_time::date = u.signup_date + 30
            )
        ) AS retained_users
    FROM users u
    JOIN experiment_assignments ea
        ON u.user_id = ea.user_id
    GROUP BY ea.experiment_group
),

wide AS (
    SELECT
        MAX(n_users) FILTER (WHERE experiment_group = 'control')::numeric AS n_control,
        MAX(n_users) FILTER (WHERE experiment_group = 'treatment')::numeric AS n_treatment,

        MAX(retained_users) FILTER (WHERE experiment_group = 'control')::numeric AS retained_control,
        MAX(retained_users) FILTER (WHERE experiment_group = 'treatment')::numeric AS retained_treatment
    FROM group_retention
),

stats AS (
    SELECT
        n_control,
        n_treatment,
        retained_control,
        retained_treatment,

        retained_control / n_control AS p_control,
        retained_treatment / n_treatment AS p_treatment,

        (retained_control + retained_treatment)
        / (n_control + n_treatment) AS pooled_p

    FROM wide
)

SELECT
    n_control,
    n_treatment,

    retained_control,
    retained_treatment,

    ROUND(100.0 * p_control, 2) AS control_d30_retention_percent,
    ROUND(100.0 * p_treatment, 2) AS treatment_d30_retention_percent,
    ROUND(100.0 * (p_treatment - p_control), 2) AS d30_retention_lift_pp,

    ROUND(
        (
            (p_treatment - p_control)
            / NULLIF(
                SQRT(
                    pooled_p * (1 - pooled_p)
                    * (1 / n_control + 1 / n_treatment)
                ),
                0
            )
        )::numeric,
        3
    ) AS approximate_z_score

FROM stats;