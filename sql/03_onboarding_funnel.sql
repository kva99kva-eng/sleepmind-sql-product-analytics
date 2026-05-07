-- 03_onboarding_funnel.sql
-- Onboarding funnel analysis for SleepMind SQL Product Analytics
-- Goal: understand where users drop off during the early product journey.

-- Funnel definition:
-- 1. registration
-- 2. first_app_open
-- 3. first_sleep_log
-- 4. first_recommendation_viewed
-- 5. second_sleep_log
-- 6. day_7_retained


-- 1. Overall onboarding funnel

WITH sleep_log_ranked AS (
    SELECT
        user_id,
        event_time,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY event_time
        ) AS sleep_log_number
    FROM app_events
    WHERE event_name = 'sleep_log_added'
),

user_event_dates AS (
    SELECT
        u.user_id,
        u.signup_date,
        u.acquisition_channel,
        u.device,

        MIN(ae.event_time) FILTER (
            WHERE ae.event_name = 'registration'
        ) AS registration_at,

        MIN(ae.event_time) FILTER (
            WHERE ae.event_name = 'first_app_open'
        ) AS first_app_open_at,

        MIN(sl.event_time) FILTER (
            WHERE sl.sleep_log_number = 1
        ) AS first_sleep_log_at,

        MIN(sl.event_time) FILTER (
            WHERE sl.sleep_log_number = 2
        ) AS second_sleep_log_at,

        MIN(ae.event_time) FILTER (
            WHERE ae.event_name = 'recommendation_viewed'
        ) AS first_recommendation_viewed_at,

        MAX(
            CASE
                WHEN ae.event_time::date = u.signup_date + 7 THEN 1
                ELSE 0
            END
        ) AS is_day_7_retained

    FROM users u
    LEFT JOIN app_events ae
        ON u.user_id = ae.user_id
    LEFT JOIN sleep_log_ranked sl
        ON u.user_id = sl.user_id
    GROUP BY
        u.user_id,
        u.signup_date,
        u.acquisition_channel,
        u.device
),

user_funnel_flags AS (
    SELECT
        user_id,
        acquisition_channel,
        device,

        1 AS registration,

        CASE
            WHEN first_app_open_at IS NOT NULL THEN 1
            ELSE 0
        END AS first_app_open,

        CASE
            WHEN first_app_open_at IS NOT NULL
             AND first_sleep_log_at IS NOT NULL
            THEN 1
            ELSE 0
        END AS first_sleep_log,

        CASE
            WHEN first_app_open_at IS NOT NULL
             AND first_sleep_log_at IS NOT NULL
             AND first_recommendation_viewed_at IS NOT NULL
            THEN 1
            ELSE 0
        END AS first_recommendation_viewed,

        CASE
            WHEN first_app_open_at IS NOT NULL
             AND first_sleep_log_at IS NOT NULL
             AND first_recommendation_viewed_at IS NOT NULL
             AND second_sleep_log_at IS NOT NULL
            THEN 1
            ELSE 0
        END AS second_sleep_log,

        CASE
            WHEN first_app_open_at IS NOT NULL
             AND first_sleep_log_at IS NOT NULL
             AND first_recommendation_viewed_at IS NOT NULL
             AND second_sleep_log_at IS NOT NULL
             AND is_day_7_retained = 1
            THEN 1
            ELSE 0
        END AS day_7_retained

    FROM user_event_dates
),

funnel_steps AS (
    SELECT 1 AS step_order, 'registration' AS step_name, COUNT(*) AS users_count
    FROM user_funnel_flags
    WHERE registration = 1

    UNION ALL

    SELECT 2, 'first_app_open', COUNT(*)
    FROM user_funnel_flags
    WHERE first_app_open = 1

    UNION ALL

    SELECT 3, 'first_sleep_log', COUNT(*)
    FROM user_funnel_flags
    WHERE first_sleep_log = 1

    UNION ALL

    SELECT 4, 'first_recommendation_viewed', COUNT(*)
    FROM user_funnel_flags
    WHERE first_recommendation_viewed = 1

    UNION ALL

    SELECT 5, 'second_sleep_log', COUNT(*)
    FROM user_funnel_flags
    WHERE second_sleep_log = 1

    UNION ALL

    SELECT 6, 'day_7_retained', COUNT(*)
    FROM user_funnel_flags
    WHERE day_7_retained = 1
),

funnel_with_previous AS (
    SELECT
        step_order,
        step_name,
        users_count,
        LAG(users_count) OVER (ORDER BY step_order) AS previous_step_users,
        FIRST_VALUE(users_count) OVER (ORDER BY step_order) AS registered_users
    FROM funnel_steps
)

SELECT
    step_order,
    step_name,
    users_count,
    previous_step_users,
    users_count - COALESCE(previous_step_users, users_count) AS user_change_from_previous,

    ROUND(
        100.0 * users_count / NULLIF(previous_step_users, 0),
        2
    ) AS conversion_from_previous_percent,

    ROUND(
        100.0 * users_count / NULLIF(registered_users, 0),
        2
    ) AS conversion_from_registration_percent

FROM funnel_with_previous
ORDER BY step_order;


-- 2. Funnel by acquisition channel

WITH sleep_log_ranked AS (
    SELECT
        user_id,
        event_time,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY event_time
        ) AS sleep_log_number
    FROM app_events
    WHERE event_name = 'sleep_log_added'
),

user_event_dates AS (
    SELECT
        u.user_id,
        u.signup_date,
        u.acquisition_channel,

        MIN(ae.event_time) FILTER (
            WHERE ae.event_name = 'first_app_open'
        ) AS first_app_open_at,

        MIN(sl.event_time) FILTER (
            WHERE sl.sleep_log_number = 1
        ) AS first_sleep_log_at,

        MIN(sl.event_time) FILTER (
            WHERE sl.sleep_log_number = 2
        ) AS second_sleep_log_at,

        MIN(ae.event_time) FILTER (
            WHERE ae.event_name = 'recommendation_viewed'
        ) AS first_recommendation_viewed_at,

        MAX(
            CASE
                WHEN ae.event_time::date = u.signup_date + 7 THEN 1
                ELSE 0
            END
        ) AS is_day_7_retained

    FROM users u
    LEFT JOIN app_events ae
        ON u.user_id = ae.user_id
    LEFT JOIN sleep_log_ranked sl
        ON u.user_id = sl.user_id
    GROUP BY
        u.user_id,
        u.signup_date,
        u.acquisition_channel
)

SELECT
    acquisition_channel,
    COUNT(*) AS registered_users,

    COUNT(*) FILTER (
        WHERE first_app_open_at IS NOT NULL
    ) AS first_app_open_users,

    COUNT(*) FILTER (
        WHERE first_app_open_at IS NOT NULL
          AND first_sleep_log_at IS NOT NULL
    ) AS first_sleep_log_users,

    COUNT(*) FILTER (
        WHERE first_app_open_at IS NOT NULL
          AND first_sleep_log_at IS NOT NULL
          AND first_recommendation_viewed_at IS NOT NULL
    ) AS recommendation_viewed_users,

    COUNT(*) FILTER (
        WHERE first_app_open_at IS NOT NULL
          AND first_sleep_log_at IS NOT NULL
          AND first_recommendation_viewed_at IS NOT NULL
          AND second_sleep_log_at IS NOT NULL
    ) AS second_sleep_log_users,

    COUNT(*) FILTER (
        WHERE first_app_open_at IS NOT NULL
          AND first_sleep_log_at IS NOT NULL
          AND first_recommendation_viewed_at IS NOT NULL
          AND second_sleep_log_at IS NOT NULL
          AND is_day_7_retained = 1
    ) AS day_7_retained_users,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE first_app_open_at IS NOT NULL
              AND first_sleep_log_at IS NOT NULL
              AND first_recommendation_viewed_at IS NOT NULL
              AND second_sleep_log_at IS NOT NULL
              AND is_day_7_retained = 1
        ) / COUNT(*),
        2
    ) AS full_funnel_conversion_percent

FROM user_event_dates
GROUP BY acquisition_channel
ORDER BY full_funnel_conversion_percent DESC;


-- 3. Funnel by device

WITH sleep_log_ranked AS (
    SELECT
        user_id,
        event_time,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY event_time
        ) AS sleep_log_number
    FROM app_events
    WHERE event_name = 'sleep_log_added'
),

user_event_dates AS (
    SELECT
        u.user_id,
        u.signup_date,
        u.device,

        MIN(ae.event_time) FILTER (
            WHERE ae.event_name = 'first_app_open'
        ) AS first_app_open_at,

        MIN(sl.event_time) FILTER (
            WHERE sl.sleep_log_number = 1
        ) AS first_sleep_log_at,

        MIN(sl.event_time) FILTER (
            WHERE sl.sleep_log_number = 2
        ) AS second_sleep_log_at,

        MIN(ae.event_time) FILTER (
            WHERE ae.event_name = 'recommendation_viewed'
        ) AS first_recommendation_viewed_at,

        MAX(
            CASE
                WHEN ae.event_time::date = u.signup_date + 7 THEN 1
                ELSE 0
            END
        ) AS is_day_7_retained

    FROM users u
    LEFT JOIN app_events ae
        ON u.user_id = ae.user_id
    LEFT JOIN sleep_log_ranked sl
        ON u.user_id = sl.user_id
    GROUP BY
        u.user_id,
        u.signup_date,
        u.device
)

SELECT
    device,
    COUNT(*) AS registered_users,

    COUNT(*) FILTER (
        WHERE first_app_open_at IS NOT NULL
    ) AS first_app_open_users,

    COUNT(*) FILTER (
        WHERE first_app_open_at IS NOT NULL
          AND first_sleep_log_at IS NOT NULL
    ) AS first_sleep_log_users,

    COUNT(*) FILTER (
        WHERE first_app_open_at IS NOT NULL
          AND first_sleep_log_at IS NOT NULL
          AND first_recommendation_viewed_at IS NOT NULL
    ) AS recommendation_viewed_users,

    COUNT(*) FILTER (
        WHERE first_app_open_at IS NOT NULL
          AND first_sleep_log_at IS NOT NULL
          AND first_recommendation_viewed_at IS NOT NULL
          AND second_sleep_log_at IS NOT NULL
    ) AS second_sleep_log_users,

    COUNT(*) FILTER (
        WHERE first_app_open_at IS NOT NULL
          AND first_sleep_log_at IS NOT NULL
          AND first_recommendation_viewed_at IS NOT NULL
          AND second_sleep_log_at IS NOT NULL
          AND is_day_7_retained = 1
    ) AS day_7_retained_users,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE first_app_open_at IS NOT NULL
              AND first_sleep_log_at IS NOT NULL
              AND first_recommendation_viewed_at IS NOT NULL
              AND second_sleep_log_at IS NOT NULL
              AND is_day_7_retained = 1
        ) / COUNT(*),
        2
    ) AS full_funnel_conversion_percent

FROM user_event_dates
GROUP BY device
ORDER BY full_funnel_conversion_percent DESC;


-- 4. Time from signup to first sleep log

WITH first_sleep_log AS (
    SELECT
        u.user_id,
        u.signup_date,
        MIN(ae.event_time) AS first_sleep_log_at
    FROM users u
    JOIN app_events ae
        ON u.user_id = ae.user_id
    WHERE ae.event_name = 'sleep_log_added'
    GROUP BY
        u.user_id,
        u.signup_date
)

SELECT
    COUNT(*) AS users_with_first_sleep_log,

    ROUND(
        AVG(
            EXTRACT(EPOCH FROM (first_sleep_log_at - signup_date::timestamp)) / 3600
        )::numeric,
        2
    ) AS avg_hours_to_first_sleep_log,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM (first_sleep_log_at - signup_date::timestamp)) / 3600
        )::numeric,
        2
    ) AS median_hours_to_first_sleep_log

FROM first_sleep_log;


-- 5. Users who registered but did not open the app

SELECT
    u.acquisition_channel,
    u.device,
    COUNT(*) AS users_without_first_app_open
FROM users u
LEFT JOIN app_events ae
    ON u.user_id = ae.user_id
   AND ae.event_name = 'first_app_open'
WHERE ae.user_id IS NULL
GROUP BY
    u.acquisition_channel,
    u.device
ORDER BY users_without_first_app_open DESC;