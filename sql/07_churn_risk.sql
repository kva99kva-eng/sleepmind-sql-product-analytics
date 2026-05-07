-- 07_churn_risk.sql
-- Churn risk analysis for SleepMind SQL Product Analytics
-- Goal: identify users at risk of churn based on inactivity,
-- reduced sleep logging, worsening sleep score, and subscription status.

-- Risk logic:
-- Higher risk if user:
-- 1. has no activity during days 24-30 after signup
-- 2. has low number of sleep logs during first 30 days
-- 3. has worsening sleep score from baseline to follow-up
-- 4. did not click recommendations
-- 5. did not convert to paid subscription
-- 6. was not active on day 30


-- 1. User-level churn risk scoring

WITH user_activity AS (
    SELECT
        u.user_id,
        u.signup_date,
        u.acquisition_channel,
        u.device,

        COUNT(DISTINCT ae.event_time::date) FILTER (
            WHERE ae.event_time::date BETWEEN u.signup_date AND u.signup_date + 30
              AND ae.event_name IN (
                  'app_open',
                  'sleep_log_added',
                  'recommendation_viewed',
                  'sleep_diary_opened'
              )
        ) AS active_days_30d,

        COUNT(DISTINCT ae.event_time::date) FILTER (
            WHERE ae.event_time::date BETWEEN u.signup_date + 24 AND u.signup_date + 30
              AND ae.event_name IN (
                  'app_open',
                  'sleep_log_added',
                  'recommendation_viewed',
                  'sleep_diary_opened'
              )
        ) AS active_days_last_7d,

        MAX(
            CASE
                WHEN ae.event_time::date = u.signup_date + 30 THEN 1
                ELSE 0
            END
        ) AS d30_retained,

        COUNT(*) FILTER (
            WHERE ae.event_name = 'sleep_log_added'
              AND ae.event_time::date BETWEEN u.signup_date AND u.signup_date + 30
        ) AS sleep_logs_30d,

        COUNT(*) FILTER (
            WHERE ae.event_name = 'recommendation_viewed'
              AND ae.event_time::date BETWEEN u.signup_date AND u.signup_date + 14
        ) AS recommendation_views_14d

    FROM users u
    LEFT JOIN app_events ae
        ON u.user_id = ae.user_id
    GROUP BY
        u.user_id,
        u.signup_date,
        u.acquisition_channel,
        u.device
),

recommendation_clicks AS (
    SELECT
        u.user_id,

        COUNT(r.recommendation_id) FILTER (
            WHERE r.shown_at::date BETWEEN u.signup_date AND u.signup_date + 14
              AND r.clicked = 1
        ) AS recommendation_clicks_14d

    FROM users u
    LEFT JOIN recommendations r
        ON u.user_id = r.user_id
    GROUP BY u.user_id
),

sleep_periods AS (
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
    LEFT JOIN sleep_sessions ss
        ON u.user_id = ss.user_id
    GROUP BY u.user_id
),

user_risk_features AS (
    SELECT
        ua.user_id,
        ua.acquisition_channel,
        ua.device,
        s.subscription_status,

        ua.active_days_30d,
        ua.active_days_last_7d,
        ua.d30_retained,
        ua.sleep_logs_30d,
        ua.recommendation_views_14d,
        rc.recommendation_clicks_14d,

        sp.baseline_sleep_logs,
        sp.followup_sleep_logs,
        ROUND(sp.baseline_avg_sleep_score::numeric, 2) AS baseline_avg_sleep_score,
        ROUND(sp.followup_avg_sleep_score::numeric, 2) AS followup_avg_sleep_score,

        ROUND(
            (sp.followup_avg_sleep_score - sp.baseline_avg_sleep_score)::numeric,
            2
        ) AS sleep_score_delta,

        CASE
            WHEN sp.baseline_sleep_logs >= 2
             AND sp.followup_sleep_logs >= 2
            THEN sp.followup_avg_sleep_score - sp.baseline_avg_sleep_score
            ELSE NULL
        END AS valid_sleep_score_delta

    FROM user_activity ua
    LEFT JOIN recommendation_clicks rc
        ON ua.user_id = rc.user_id
    LEFT JOIN sleep_periods sp
        ON ua.user_id = sp.user_id
    LEFT JOIN subscriptions s
        ON ua.user_id = s.user_id
),

risk_scoring AS (
    SELECT
        *,

        (
            CASE
                WHEN active_days_last_7d = 0 THEN 3
                WHEN active_days_last_7d BETWEEN 1 AND 2 THEN 2
                ELSE 0
            END

            +

            CASE
                WHEN sleep_logs_30d < 5 THEN 2
                WHEN sleep_logs_30d BETWEEN 5 AND 9 THEN 1
                ELSE 0
            END

            +

            CASE
                WHEN valid_sleep_score_delta < -2 THEN 2
                WHEN valid_sleep_score_delta BETWEEN -2 AND 0 THEN 1
                ELSE 0
            END

            +

            CASE
                WHEN recommendation_clicks_14d = 0 THEN 1
                ELSE 0
            END

            +

            CASE
                WHEN subscription_status IN ('trial_expired', 'cancelled') THEN 2
                ELSE 0
            END

            +

            CASE
                WHEN d30_retained = 0 THEN 3
                ELSE 0
            END
        ) AS churn_risk_score

    FROM user_risk_features
),

risk_segments AS (
    SELECT
        *,

        CASE
            WHEN churn_risk_score >= 7 THEN 'high_risk'
            WHEN churn_risk_score BETWEEN 4 AND 6 THEN 'medium_risk'
            ELSE 'low_risk'
        END AS churn_risk_segment

    FROM risk_scoring
)

SELECT
    user_id,
    acquisition_channel,
    device,
    subscription_status,
    active_days_30d,
    active_days_last_7d,
    d30_retained,
    sleep_logs_30d,
    recommendation_views_14d,
    recommendation_clicks_14d,
    baseline_avg_sleep_score,
    followup_avg_sleep_score,
    sleep_score_delta,
    churn_risk_score,
    churn_risk_segment

FROM risk_segments
ORDER BY churn_risk_score DESC, active_days_last_7d ASC
LIMIT 30;


-- 2. Churn risk segment distribution

WITH user_activity AS (
    SELECT
        u.user_id,
        u.signup_date,
        u.acquisition_channel,
        u.device,

        COUNT(DISTINCT ae.event_time::date) FILTER (
            WHERE ae.event_time::date BETWEEN u.signup_date AND u.signup_date + 30
              AND ae.event_name IN (
                  'app_open',
                  'sleep_log_added',
                  'recommendation_viewed',
                  'sleep_diary_opened'
              )
        ) AS active_days_30d,

        COUNT(DISTINCT ae.event_time::date) FILTER (
            WHERE ae.event_time::date BETWEEN u.signup_date + 24 AND u.signup_date + 30
              AND ae.event_name IN (
                  'app_open',
                  'sleep_log_added',
                  'recommendation_viewed',
                  'sleep_diary_opened'
              )
        ) AS active_days_last_7d,

        MAX(
            CASE
                WHEN ae.event_time::date = u.signup_date + 30 THEN 1
                ELSE 0
            END
        ) AS d30_retained,

        COUNT(*) FILTER (
            WHERE ae.event_name = 'sleep_log_added'
              AND ae.event_time::date BETWEEN u.signup_date AND u.signup_date + 30
        ) AS sleep_logs_30d

    FROM users u
    LEFT JOIN app_events ae
        ON u.user_id = ae.user_id
    GROUP BY
        u.user_id,
        u.signup_date,
        u.acquisition_channel,
        u.device
),

recommendation_clicks AS (
    SELECT
        u.user_id,
        COUNT(r.recommendation_id) FILTER (
            WHERE r.shown_at::date BETWEEN u.signup_date AND u.signup_date + 14
              AND r.clicked = 1
        ) AS recommendation_clicks_14d
    FROM users u
    LEFT JOIN recommendations r
        ON u.user_id = r.user_id
    GROUP BY u.user_id
),

sleep_periods AS (
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
    LEFT JOIN sleep_sessions ss
        ON u.user_id = ss.user_id
    GROUP BY u.user_id
),

risk_scoring AS (
    SELECT
        ua.user_id,
        ua.acquisition_channel,
        ua.device,
        s.subscription_status,
        ua.active_days_30d,
        ua.active_days_last_7d,
        ua.d30_retained,
        ua.sleep_logs_30d,
        rc.recommendation_clicks_14d,

        (
            CASE
                WHEN ua.active_days_last_7d = 0 THEN 3
                WHEN ua.active_days_last_7d BETWEEN 1 AND 2 THEN 2
                ELSE 0
            END

            +

            CASE
                WHEN ua.sleep_logs_30d < 5 THEN 2
                WHEN ua.sleep_logs_30d BETWEEN 5 AND 9 THEN 1
                ELSE 0
            END

            +

            CASE
                WHEN sp.baseline_sleep_logs >= 2
                 AND sp.followup_sleep_logs >= 2
                 AND sp.followup_avg_sleep_score - sp.baseline_avg_sleep_score < -2 THEN 2
                WHEN sp.baseline_sleep_logs >= 2
                 AND sp.followup_sleep_logs >= 2
                 AND sp.followup_avg_sleep_score - sp.baseline_avg_sleep_score BETWEEN -2 AND 0 THEN 1
                ELSE 0
            END

            +

            CASE
                WHEN rc.recommendation_clicks_14d = 0 THEN 1
                ELSE 0
            END

            +

            CASE
                WHEN s.subscription_status IN ('trial_expired', 'cancelled') THEN 2
                ELSE 0
            END

            +

            CASE
                WHEN ua.d30_retained = 0 THEN 3
                ELSE 0
            END
        ) AS churn_risk_score

    FROM user_activity ua
    LEFT JOIN recommendation_clicks rc
        ON ua.user_id = rc.user_id
    LEFT JOIN sleep_periods sp
        ON ua.user_id = sp.user_id
    LEFT JOIN subscriptions s
        ON ua.user_id = s.user_id
),

risk_segments AS (
    SELECT
        *,

        CASE
            WHEN churn_risk_score >= 7 THEN 'high_risk'
            WHEN churn_risk_score BETWEEN 4 AND 6 THEN 'medium_risk'
            ELSE 'low_risk'
        END AS churn_risk_segment

    FROM risk_scoring
)

SELECT
    churn_risk_segment,
    COUNT(*) AS users_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS users_percent,
    ROUND(AVG(churn_risk_score)::numeric, 2) AS avg_churn_risk_score,
    ROUND(AVG(active_days_30d)::numeric, 2) AS avg_active_days_30d,
    ROUND(AVG(active_days_last_7d)::numeric, 2) AS avg_active_days_last_7d,
    ROUND(AVG(sleep_logs_30d)::numeric, 2) AS avg_sleep_logs_30d,
    ROUND(100.0 * AVG(d30_retained)::numeric, 2) AS d30_retention_percent

FROM risk_segments
GROUP BY churn_risk_segment
ORDER BY avg_churn_risk_score DESC;


-- 3. Churn risk by acquisition channel

WITH user_activity AS (
    SELECT
        u.user_id,
        u.acquisition_channel,

        COUNT(DISTINCT ae.event_time::date) FILTER (
            WHERE ae.event_time::date BETWEEN u.signup_date + 24 AND u.signup_date + 30
              AND ae.event_name IN (
                  'app_open',
                  'sleep_log_added',
                  'recommendation_viewed',
                  'sleep_diary_opened'
              )
        ) AS active_days_last_7d,

        MAX(
            CASE
                WHEN ae.event_time::date = u.signup_date + 30 THEN 1
                ELSE 0
            END
        ) AS d30_retained,

        COUNT(*) FILTER (
            WHERE ae.event_name = 'sleep_log_added'
              AND ae.event_time::date BETWEEN u.signup_date AND u.signup_date + 30
        ) AS sleep_logs_30d

    FROM users u
    LEFT JOIN app_events ae
        ON u.user_id = ae.user_id
    GROUP BY
        u.user_id,
        u.acquisition_channel
),

risk_scoring AS (
    SELECT
        user_id,
        acquisition_channel,

        (
            CASE
                WHEN active_days_last_7d = 0 THEN 3
                WHEN active_days_last_7d BETWEEN 1 AND 2 THEN 2
                ELSE 0
            END

            +

            CASE
                WHEN sleep_logs_30d < 5 THEN 2
                WHEN sleep_logs_30d BETWEEN 5 AND 9 THEN 1
                ELSE 0
            END

            +

            CASE
                WHEN d30_retained = 0 THEN 3
                ELSE 0
            END
        ) AS simplified_churn_risk_score

    FROM user_activity
),

risk_segments AS (
    SELECT
        *,

        CASE
            WHEN simplified_churn_risk_score >= 6 THEN 'high_risk'
            WHEN simplified_churn_risk_score BETWEEN 3 AND 5 THEN 'medium_risk'
            ELSE 'low_risk'
        END AS churn_risk_segment

    FROM risk_scoring
)

SELECT
    acquisition_channel,
    COUNT(*) AS users_count,

    COUNT(*) FILTER (
        WHERE churn_risk_segment = 'high_risk'
    ) AS high_risk_users,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE churn_risk_segment = 'high_risk'
        ) / COUNT(*),
        2
    ) AS high_risk_users_percent,

    ROUND(AVG(simplified_churn_risk_score)::numeric, 2) AS avg_churn_risk_score

FROM risk_segments
GROUP BY acquisition_channel
ORDER BY high_risk_users_percent DESC;


-- 4. Churn risk by device

WITH user_activity AS (
    SELECT
        u.user_id,
        u.device,

        COUNT(DISTINCT ae.event_time::date) FILTER (
            WHERE ae.event_time::date BETWEEN u.signup_date + 24 AND u.signup_date + 30
              AND ae.event_name IN (
                  'app_open',
                  'sleep_log_added',
                  'recommendation_viewed',
                  'sleep_diary_opened'
              )
        ) AS active_days_last_7d,

        MAX(
            CASE
                WHEN ae.event_time::date = u.signup_date + 30 THEN 1
                ELSE 0
            END
        ) AS d30_retained,

        COUNT(*) FILTER (
            WHERE ae.event_name = 'sleep_log_added'
              AND ae.event_time::date BETWEEN u.signup_date AND u.signup_date + 30
        ) AS sleep_logs_30d

    FROM users u
    LEFT JOIN app_events ae
        ON u.user_id = ae.user_id
    GROUP BY
        u.user_id,
        u.device
),

risk_scoring AS (
    SELECT
        user_id,
        device,

        (
            CASE
                WHEN active_days_last_7d = 0 THEN 3
                WHEN active_days_last_7d BETWEEN 1 AND 2 THEN 2
                ELSE 0
            END

            +

            CASE
                WHEN sleep_logs_30d < 5 THEN 2
                WHEN sleep_logs_30d BETWEEN 5 AND 9 THEN 1
                ELSE 0
            END

            +

            CASE
                WHEN d30_retained = 0 THEN 3
                ELSE 0
            END
        ) AS simplified_churn_risk_score

    FROM user_activity
),

risk_segments AS (
    SELECT
        *,

        CASE
            WHEN simplified_churn_risk_score >= 6 THEN 'high_risk'
            WHEN simplified_churn_risk_score BETWEEN 3 AND 5 THEN 'medium_risk'
            ELSE 'low_risk'
        END AS churn_risk_segment

    FROM risk_scoring
)

SELECT
    device,
    COUNT(*) AS users_count,

    COUNT(*) FILTER (
        WHERE churn_risk_segment = 'high_risk'
    ) AS high_risk_users,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE churn_risk_segment = 'high_risk'
        ) / COUNT(*),
        2
    ) AS high_risk_users_percent,

    ROUND(AVG(simplified_churn_risk_score)::numeric, 2) AS avg_churn_risk_score

FROM risk_segments
GROUP BY device
ORDER BY high_risk_users_percent DESC;


-- 5. Recommended product actions by risk segment

WITH segment_actions AS (
    SELECT
        'high_risk' AS churn_risk_segment,
        'Send reactivation campaign: personalized sleep insight + reminder to log sleep today' AS recommended_action

    UNION ALL

    SELECT
        'medium_risk',
        'Nudge users with low-friction habit prompt and highlight one personalized recommendation'

    UNION ALL

    SELECT
        'low_risk',
        'Keep standard engagement flow and avoid excessive notifications'
)

SELECT *
FROM segment_actions
ORDER BY
    CASE churn_risk_segment
        WHEN 'high_risk' THEN 1
        WHEN 'medium_risk' THEN 2
        WHEN 'low_risk' THEN 3
    END;