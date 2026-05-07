-- 04_cohort_retention.sql
-- Cohort retention analysis for SleepMind SQL Product Analytics
-- Goal: measure user retention by signup week and activity day.

-- 1. Retention by signup week and exact lifecycle day

WITH user_activity AS (
    SELECT DISTINCT
        u.user_id,
        DATE_TRUNC('week', u.signup_date)::date AS signup_week,
        u.signup_date,
        ae.event_time::date AS activity_date,
        ae.event_time::date - u.signup_date AS days_since_signup
    FROM users u
    JOIN app_events ae
        ON u.user_id = ae.user_id
    WHERE ae.event_name IN (
        'app_open',
        'sleep_log_added',
        'recommendation_viewed',
        'sleep_diary_opened'
    )
      AND ae.event_time::date >= u.signup_date
),

cohort_sizes AS (
    SELECT
        DATE_TRUNC('week', signup_date)::date AS signup_week,
        COUNT(*) AS cohort_size
    FROM users
    GROUP BY DATE_TRUNC('week', signup_date)::date
),

retention_counts AS (
    SELECT
        signup_week,

        COUNT(DISTINCT user_id) FILTER (
            WHERE days_since_signup = 1
        ) AS d1_retained,

        COUNT(DISTINCT user_id) FILTER (
            WHERE days_since_signup = 7
        ) AS d7_retained,

        COUNT(DISTINCT user_id) FILTER (
            WHERE days_since_signup = 14
        ) AS d14_retained,

        COUNT(DISTINCT user_id) FILTER (
            WHERE days_since_signup = 30
        ) AS d30_retained

    FROM user_activity
    GROUP BY signup_week
)

SELECT
    cs.signup_week,
    cs.cohort_size,

    COALESCE(rc.d1_retained, 0) AS d1_retained,
    ROUND(
        100.0 * COALESCE(rc.d1_retained, 0) / cs.cohort_size,
        2
    ) AS d1_retention_percent,

    COALESCE(rc.d7_retained, 0) AS d7_retained,
    ROUND(
        100.0 * COALESCE(rc.d7_retained, 0) / cs.cohort_size,
        2
    ) AS d7_retention_percent,

    COALESCE(rc.d14_retained, 0) AS d14_retained,
    ROUND(
        100.0 * COALESCE(rc.d14_retained, 0) / cs.cohort_size,
        2
    ) AS d14_retention_percent,

    COALESCE(rc.d30_retained, 0) AS d30_retained,
    ROUND(
        100.0 * COALESCE(rc.d30_retained, 0) / cs.cohort_size,
        2
    ) AS d30_retention_percent

FROM cohort_sizes cs
LEFT JOIN retention_counts rc
    ON cs.signup_week = rc.signup_week
ORDER BY cs.signup_week;


-- 2. Average retention across all cohorts

WITH user_activity AS (
    SELECT DISTINCT
        u.user_id,
        u.signup_date,
        ae.event_time::date - u.signup_date AS days_since_signup
    FROM users u
    JOIN app_events ae
        ON u.user_id = ae.user_id
    WHERE ae.event_name IN (
        'app_open',
        'sleep_log_added',
        'recommendation_viewed',
        'sleep_diary_opened'
    )
      AND ae.event_time::date >= u.signup_date
),

retention_flags AS (
    SELECT
        u.user_id,

        MAX(CASE WHEN ua.days_since_signup = 1 THEN 1 ELSE 0 END) AS d1_retained,
        MAX(CASE WHEN ua.days_since_signup = 7 THEN 1 ELSE 0 END) AS d7_retained,
        MAX(CASE WHEN ua.days_since_signup = 14 THEN 1 ELSE 0 END) AS d14_retained,
        MAX(CASE WHEN ua.days_since_signup = 30 THEN 1 ELSE 0 END) AS d30_retained

    FROM users u
    LEFT JOIN user_activity ua
        ON u.user_id = ua.user_id
    GROUP BY u.user_id
)

SELECT
    COUNT(*) AS total_users,

    ROUND(100.0 * AVG(d1_retained), 2) AS avg_d1_retention_percent,
    ROUND(100.0 * AVG(d7_retained), 2) AS avg_d7_retention_percent,
    ROUND(100.0 * AVG(d14_retained), 2) AS avg_d14_retention_percent,
    ROUND(100.0 * AVG(d30_retained), 2) AS avg_d30_retention_percent

FROM retention_flags;


-- 3. Retention by acquisition channel

WITH user_activity AS (
    SELECT DISTINCT
        u.user_id,
        u.acquisition_channel,
        u.signup_date,
        ae.event_time::date - u.signup_date AS days_since_signup
    FROM users u
    JOIN app_events ae
        ON u.user_id = ae.user_id
    WHERE ae.event_name IN (
        'app_open',
        'sleep_log_added',
        'recommendation_viewed',
        'sleep_diary_opened'
    )
      AND ae.event_time::date >= u.signup_date
),

retention_flags AS (
    SELECT
        u.user_id,
        u.acquisition_channel,

        MAX(CASE WHEN ua.days_since_signup = 1 THEN 1 ELSE 0 END) AS d1_retained,
        MAX(CASE WHEN ua.days_since_signup = 7 THEN 1 ELSE 0 END) AS d7_retained,
        MAX(CASE WHEN ua.days_since_signup = 14 THEN 1 ELSE 0 END) AS d14_retained,
        MAX(CASE WHEN ua.days_since_signup = 30 THEN 1 ELSE 0 END) AS d30_retained

    FROM users u
    LEFT JOIN user_activity ua
        ON u.user_id = ua.user_id
    GROUP BY
        u.user_id,
        u.acquisition_channel
)

SELECT
    acquisition_channel,
    COUNT(*) AS users_count,

    ROUND(100.0 * AVG(d1_retained), 2) AS d1_retention_percent,
    ROUND(100.0 * AVG(d7_retained), 2) AS d7_retention_percent,
    ROUND(100.0 * AVG(d14_retained), 2) AS d14_retention_percent,
    ROUND(100.0 * AVG(d30_retained), 2) AS d30_retention_percent

FROM retention_flags
GROUP BY acquisition_channel
ORDER BY d30_retention_percent DESC;


-- 4. Retention by device

WITH user_activity AS (
    SELECT DISTINCT
        u.user_id,
        u.device,
        u.signup_date,
        ae.event_time::date - u.signup_date AS days_since_signup
    FROM users u
    JOIN app_events ae
        ON u.user_id = ae.user_id
    WHERE ae.event_name IN (
        'app_open',
        'sleep_log_added',
        'recommendation_viewed',
        'sleep_diary_opened'
    )
      AND ae.event_time::date >= u.signup_date
),

retention_flags AS (
    SELECT
        u.user_id,
        u.device,

        MAX(CASE WHEN ua.days_since_signup = 1 THEN 1 ELSE 0 END) AS d1_retained,
        MAX(CASE WHEN ua.days_since_signup = 7 THEN 1 ELSE 0 END) AS d7_retained,
        MAX(CASE WHEN ua.days_since_signup = 14 THEN 1 ELSE 0 END) AS d14_retained,
        MAX(CASE WHEN ua.days_since_signup = 30 THEN 1 ELSE 0 END) AS d30_retained

    FROM users u
    LEFT JOIN user_activity ua
        ON u.user_id = ua.user_id
    GROUP BY
        u.user_id,
        u.device
)

SELECT
    device,
    COUNT(*) AS users_count,

    ROUND(100.0 * AVG(d1_retained), 2) AS d1_retention_percent,
    ROUND(100.0 * AVG(d7_retained), 2) AS d7_retention_percent,
    ROUND(100.0 * AVG(d14_retained), 2) AS d14_retention_percent,
    ROUND(100.0 * AVG(d30_retained), 2) AS d30_retention_percent

FROM retention_flags
GROUP BY device
ORDER BY d30_retention_percent DESC;


-- 5. Retention curve for lifecycle days 0-30

WITH user_activity AS (
    SELECT DISTINCT
        u.user_id,
        ae.event_time::date - u.signup_date AS days_since_signup
    FROM users u
    JOIN app_events ae
        ON u.user_id = ae.user_id
    WHERE ae.event_name IN (
        'app_open',
        'sleep_log_added',
        'recommendation_viewed',
        'sleep_diary_opened'
    )
      AND ae.event_time::date >= u.signup_date
      AND ae.event_time::date - u.signup_date BETWEEN 0 AND 30
),

cohort_size AS (
    SELECT COUNT(*) AS total_users
    FROM users
)

SELECT
    ua.days_since_signup,
    COUNT(DISTINCT ua.user_id) AS active_users,
    ROUND(
        100.0 * COUNT(DISTINCT ua.user_id) / cs.total_users,
        2
    ) AS retention_percent

FROM user_activity ua
CROSS JOIN cohort_size cs
GROUP BY
    ua.days_since_signup,
    cs.total_users
ORDER BY ua.days_since_signup;
