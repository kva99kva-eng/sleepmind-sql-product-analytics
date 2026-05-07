-- 05_sleep_improvement.sql
-- Sleep improvement analysis for SleepMind SQL Product Analytics
-- Goal: evaluate whether users improve their sleep after using the app
-- and identify behavioral patterns associated with improvement.

-- Main definition:
-- baseline period: days 0-6 after signup
-- follow-up period: days 14-30 after signup
-- sleep_score_delta = followup_avg_sleep_score - baseline_avg_sleep_score


-- 1. Overall sleep improvement

WITH user_sleep_periods AS (
    SELECT
        u.user_id,
        u.signup_date,
        u.acquisition_channel,
        u.device,
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
        ) AS followup_avg_sleep_score,

        AVG(ss.sleep_duration_hours) FILTER (
            WHERE ss.sleep_date BETWEEN u.signup_date AND u.signup_date + 6
        ) AS baseline_avg_sleep_duration,

        AVG(ss.sleep_duration_hours) FILTER (
            WHERE ss.sleep_date BETWEEN u.signup_date + 14 AND u.signup_date + 30
        ) AS followup_avg_sleep_duration,

        AVG(ss.sleep_efficiency) FILTER (
            WHERE ss.sleep_date BETWEEN u.signup_date AND u.signup_date + 6
        ) AS baseline_avg_sleep_efficiency,

        AVG(ss.sleep_efficiency) FILTER (
            WHERE ss.sleep_date BETWEEN u.signup_date + 14 AND u.signup_date + 30
        ) AS followup_avg_sleep_efficiency,

        AVG(ss.awakenings) FILTER (
            WHERE ss.sleep_date BETWEEN u.signup_date AND u.signup_date + 6
        ) AS baseline_avg_awakenings,

        AVG(ss.awakenings) FILTER (
            WHERE ss.sleep_date BETWEEN u.signup_date + 14 AND u.signup_date + 30
        ) AS followup_avg_awakenings

    FROM users u
    JOIN sleep_sessions ss
        ON u.user_id = ss.user_id
    JOIN experiment_assignments ea
        ON u.user_id = ea.user_id
    GROUP BY
        u.user_id,
        u.signup_date,
        u.acquisition_channel,
        u.device,
        ea.experiment_group
),

user_sleep_delta AS (
    SELECT
        *,
        followup_avg_sleep_score - baseline_avg_sleep_score AS sleep_score_delta,
        followup_avg_sleep_duration - baseline_avg_sleep_duration AS sleep_duration_delta,
        followup_avg_sleep_efficiency - baseline_avg_sleep_efficiency AS sleep_efficiency_delta,
        followup_avg_awakenings - baseline_avg_awakenings AS awakenings_delta,

        CASE
            WHEN followup_avg_sleep_score - baseline_avg_sleep_score > 2 THEN 'improved'
            WHEN followup_avg_sleep_score - baseline_avg_sleep_score < -2 THEN 'worsened'
            ELSE 'stable'
        END AS sleep_change_segment

    FROM user_sleep_periods
    WHERE baseline_sleep_logs >= 2
      AND followup_sleep_logs >= 2
)

SELECT
    COUNT(*) AS users_analyzed,

    ROUND(AVG(baseline_avg_sleep_score)::numeric, 2) AS baseline_avg_sleep_score,
    ROUND(AVG(followup_avg_sleep_score)::numeric, 2) AS followup_avg_sleep_score,
    ROUND(AVG(sleep_score_delta)::numeric, 2) AS avg_sleep_score_delta,

    ROUND(AVG(baseline_avg_sleep_duration)::numeric, 2) AS baseline_avg_sleep_duration,
    ROUND(AVG(followup_avg_sleep_duration)::numeric, 2) AS followup_avg_sleep_duration,
    ROUND(AVG(sleep_duration_delta)::numeric, 2) AS avg_sleep_duration_delta,

    ROUND(AVG(baseline_avg_sleep_efficiency)::numeric, 2) AS baseline_avg_sleep_efficiency,
    ROUND(AVG(followup_avg_sleep_efficiency)::numeric, 2) AS followup_avg_sleep_efficiency,
    ROUND(AVG(sleep_efficiency_delta)::numeric, 2) AS avg_sleep_efficiency_delta,

    ROUND(AVG(baseline_avg_awakenings)::numeric, 2) AS baseline_avg_awakenings,
    ROUND(AVG(followup_avg_awakenings)::numeric, 2) AS followup_avg_awakenings,
    ROUND(AVG(awakenings_delta)::numeric, 2) AS avg_awakenings_delta

FROM user_sleep_delta;


-- 2. Sleep change segments

WITH user_sleep_periods AS (
    SELECT
        u.user_id,

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
    JOIN sleep_sessions ss
        ON u.user_id = ss.user_id
    GROUP BY u.user_id
),

user_sleep_delta AS (
    SELECT
        user_id,
        followup_avg_sleep_score - baseline_avg_sleep_score AS sleep_score_delta,

        CASE
            WHEN followup_avg_sleep_score - baseline_avg_sleep_score > 2 THEN 'improved'
            WHEN followup_avg_sleep_score - baseline_avg_sleep_score < -2 THEN 'worsened'
            ELSE 'stable'
        END AS sleep_change_segment

    FROM user_sleep_periods
    WHERE baseline_sleep_logs >= 2
      AND followup_sleep_logs >= 2
)

SELECT
    sleep_change_segment,
    COUNT(*) AS users_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS users_percent,
    ROUND(AVG(sleep_score_delta)::numeric, 2) AS avg_sleep_score_delta

FROM user_sleep_delta
GROUP BY sleep_change_segment
ORDER BY users_count DESC;


-- 3. Sleep improvement by early logging frequency

WITH early_logging AS (
    SELECT
        u.user_id,

        COUNT(ss.sleep_session_id) FILTER (
            WHERE ss.sleep_date BETWEEN u.signup_date AND u.signup_date + 6
        ) AS early_sleep_logs

    FROM users u
    LEFT JOIN sleep_sessions ss
        ON u.user_id = ss.user_id
    GROUP BY u.user_id
),

user_sleep_periods AS (
    SELECT
        u.user_id,
        el.early_sleep_logs,

        CASE
            WHEN el.early_sleep_logs <= 2 THEN 'low_logging'
            WHEN el.early_sleep_logs BETWEEN 3 AND 5 THEN 'medium_logging'
            ELSE 'high_logging'
        END AS early_logging_segment,

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
    JOIN sleep_sessions ss
        ON u.user_id = ss.user_id
    JOIN early_logging el
        ON u.user_id = el.user_id
    GROUP BY
        u.user_id,
        el.early_sleep_logs
)

SELECT
    early_logging_segment,
    COUNT(*) AS users_count,
    ROUND(AVG(early_sleep_logs)::numeric, 2) AS avg_early_sleep_logs,
    ROUND(AVG(baseline_avg_sleep_score)::numeric, 2) AS baseline_avg_sleep_score,
    ROUND(AVG(followup_avg_sleep_score)::numeric, 2) AS followup_avg_sleep_score,
    ROUND(AVG(followup_avg_sleep_score - baseline_avg_sleep_score)::numeric, 2) AS avg_sleep_score_delta

FROM user_sleep_periods
WHERE baseline_sleep_logs >= 2
  AND followup_sleep_logs >= 2
GROUP BY early_logging_segment
ORDER BY avg_sleep_score_delta DESC;


-- 4. Sleep improvement by recommendation exposure

WITH recommendation_exposure AS (
    SELECT
        u.user_id,

        COUNT(r.recommendation_id) FILTER (
            WHERE r.shown_at::date BETWEEN u.signup_date AND u.signup_date + 13
        ) AS recommendations_shown_early,

        COUNT(r.recommendation_id) FILTER (
            WHERE r.shown_at::date BETWEEN u.signup_date AND u.signup_date + 13
              AND r.clicked = 1
        ) AS recommendations_clicked_early

    FROM users u
    LEFT JOIN recommendations r
        ON u.user_id = r.user_id
    GROUP BY u.user_id
),

user_sleep_periods AS (
    SELECT
        u.user_id,
        re.recommendations_shown_early,
        re.recommendations_clicked_early,

        CASE
            WHEN re.recommendations_shown_early = 0 THEN 'no_recommendations'
            WHEN re.recommendations_shown_early BETWEEN 1 AND 5 THEN 'low_exposure'
            ELSE 'high_exposure'
        END AS recommendation_exposure_segment,

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
    JOIN sleep_sessions ss
        ON u.user_id = ss.user_id
    JOIN recommendation_exposure re
        ON u.user_id = re.user_id
    GROUP BY
        u.user_id,
        re.recommendations_shown_early,
        re.recommendations_clicked_early
)

SELECT
    recommendation_exposure_segment,
    COUNT(*) AS users_count,
    ROUND(AVG(recommendations_shown_early)::numeric, 2) AS avg_recommendations_shown_early,
    ROUND(AVG(recommendations_clicked_early)::numeric, 2) AS avg_recommendations_clicked_early,
    ROUND(AVG(baseline_avg_sleep_score)::numeric, 2) AS baseline_avg_sleep_score,
    ROUND(AVG(followup_avg_sleep_score)::numeric, 2) AS followup_avg_sleep_score,
    ROUND(AVG(followup_avg_sleep_score - baseline_avg_sleep_score)::numeric, 2) AS avg_sleep_score_delta

FROM user_sleep_periods
WHERE baseline_sleep_logs >= 2
  AND followup_sleep_logs >= 2
GROUP BY recommendation_exposure_segment
ORDER BY avg_sleep_score_delta DESC;


-- 5. Sleep improvement by experiment group

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
        ) AS followup_avg_sleep_score,

        AVG(ss.sleep_duration_hours) FILTER (
            WHERE ss.sleep_date BETWEEN u.signup_date AND u.signup_date + 6
        ) AS baseline_avg_sleep_duration,

        AVG(ss.sleep_duration_hours) FILTER (
            WHERE ss.sleep_date BETWEEN u.signup_date + 14 AND u.signup_date + 30
        ) AS followup_avg_sleep_duration

    FROM users u
    JOIN sleep_sessions ss
        ON u.user_id = ss.user_id
    JOIN experiment_assignments ea
        ON u.user_id = ea.user_id
    GROUP BY
        u.user_id,
        ea.experiment_group
)

SELECT
    experiment_group,
    COUNT(*) AS users_count,

    ROUND(AVG(baseline_avg_sleep_score)::numeric, 2) AS baseline_avg_sleep_score,
    ROUND(AVG(followup_avg_sleep_score)::numeric, 2) AS followup_avg_sleep_score,
    ROUND(AVG(followup_avg_sleep_score - baseline_avg_sleep_score)::numeric, 2) AS avg_sleep_score_delta,

    ROUND(AVG(baseline_avg_sleep_duration)::numeric, 2) AS baseline_avg_sleep_duration,
    ROUND(AVG(followup_avg_sleep_duration)::numeric, 2) AS followup_avg_sleep_duration,
    ROUND(AVG(followup_avg_sleep_duration - baseline_avg_sleep_duration)::numeric, 2) AS avg_sleep_duration_delta

FROM user_sleep_periods
WHERE baseline_sleep_logs >= 2
  AND followup_sleep_logs >= 2
GROUP BY experiment_group
ORDER BY avg_sleep_score_delta DESC;


-- 6. Users with strongest sleep improvement

WITH user_sleep_periods AS (
    SELECT
        u.user_id,
        u.acquisition_channel,
        u.device,
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
    JOIN sleep_sessions ss
        ON u.user_id = ss.user_id
    JOIN experiment_assignments ea
        ON u.user_id = ea.user_id
    GROUP BY
        u.user_id,
        u.acquisition_channel,
        u.device,
        ea.experiment_group
)

SELECT
    user_id,
    acquisition_channel,
    device,
    experiment_group,
    baseline_sleep_logs,
    followup_sleep_logs,
    ROUND(baseline_avg_sleep_score::numeric, 2) AS baseline_avg_sleep_score,
    ROUND(followup_avg_sleep_score::numeric, 2) AS followup_avg_sleep_score,
    ROUND((followup_avg_sleep_score - baseline_avg_sleep_score)::numeric, 2) AS sleep_score_delta

FROM user_sleep_periods
WHERE baseline_sleep_logs >= 2
  AND followup_sleep_logs >= 2
ORDER BY sleep_score_delta DESC
LIMIT 20;