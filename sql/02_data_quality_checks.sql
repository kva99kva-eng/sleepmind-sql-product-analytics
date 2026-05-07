-- 02_data_quality_checks.sql
-- Data quality checks for SleepMind SQL Product Analytics
-- Goal: validate table integrity before product and research analysis.

-- 1. Row counts by table
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL
SELECT 'experiment_assignments', COUNT(*) FROM experiment_assignments
UNION ALL
SELECT 'sleep_sessions', COUNT(*) FROM sleep_sessions
UNION ALL
SELECT 'app_events', COUNT(*) FROM app_events
UNION ALL
SELECT 'recommendations', COUNT(*) FROM recommendations
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscriptions;


-- 2. Duplicate primary keys
SELECT 'users.user_id duplicates' AS check_name,
       COUNT(*) - COUNT(DISTINCT user_id) AS issue_count
FROM users
UNION ALL
SELECT 'app_events.event_id duplicates',
       COUNT(*) - COUNT(DISTINCT event_id)
FROM app_events
UNION ALL
SELECT 'sleep_sessions.sleep_session_id duplicates',
       COUNT(*) - COUNT(DISTINCT sleep_session_id)
FROM sleep_sessions
UNION ALL
SELECT 'recommendations.recommendation_id duplicates',
       COUNT(*) - COUNT(DISTINCT recommendation_id)
FROM recommendations
UNION ALL
SELECT 'subscriptions.subscription_id duplicates',
       COUNT(*) - COUNT(DISTINCT subscription_id)
FROM subscriptions;


-- 3. One-row-per-user checks for user-level tables
SELECT 'experiment_assignments duplicate users' AS check_name,
       COUNT(*) - COUNT(DISTINCT user_id) AS issue_count
FROM experiment_assignments
UNION ALL
SELECT 'subscriptions duplicate users',
       COUNT(*) - COUNT(DISTINCT user_id)
FROM subscriptions;


-- 4. Missing values in key fields
SELECT 'users missing signup_date' AS check_name,
       COUNT(*) FILTER (WHERE signup_date IS NULL) AS issue_count
FROM users
UNION ALL
SELECT 'users missing country',
       COUNT(*) FILTER (WHERE country IS NULL)
FROM users
UNION ALL
SELECT 'users missing device',
       COUNT(*) FILTER (WHERE device IS NULL)
FROM users
UNION ALL
SELECT 'app_events missing event_time',
       COUNT(*) FILTER (WHERE event_time IS NULL)
FROM app_events
UNION ALL
SELECT 'sleep_sessions missing sleep_date',
       COUNT(*) FILTER (WHERE sleep_date IS NULL)
FROM sleep_sessions
UNION ALL
SELECT 'sleep_sessions missing sleep_score',
       COUNT(*) FILTER (WHERE sleep_score IS NULL)
FROM sleep_sessions
UNION ALL
SELECT 'subscriptions missing trial_start',
       COUNT(*) FILTER (WHERE trial_start IS NULL)
FROM subscriptions
UNION ALL
SELECT 'subscriptions missing trial_end',
       COUNT(*) FILTER (WHERE trial_end IS NULL)
FROM subscriptions;


-- 5. Foreign key integrity checks
SELECT 'app_events without matching user' AS check_name,
       COUNT(*) AS issue_count
FROM app_events ae
LEFT JOIN users u ON ae.user_id = u.user_id
WHERE u.user_id IS NULL

UNION ALL

SELECT 'sleep_sessions without matching user',
       COUNT(*)
FROM sleep_sessions ss
LEFT JOIN users u ON ss.user_id = u.user_id
WHERE u.user_id IS NULL

UNION ALL

SELECT 'recommendations without matching user',
       COUNT(*)
FROM recommendations r
LEFT JOIN users u ON r.user_id = u.user_id
WHERE u.user_id IS NULL

UNION ALL

SELECT 'subscriptions without matching user',
       COUNT(*)
FROM subscriptions s
LEFT JOIN users u ON s.user_id = u.user_id
WHERE u.user_id IS NULL

UNION ALL

SELECT 'experiment_assignments without matching user',
       COUNT(*)
FROM experiment_assignments ea
LEFT JOIN users u ON ea.user_id = u.user_id
WHERE u.user_id IS NULL;


-- 6. Date consistency checks
SELECT 'events before signup' AS check_name,
       COUNT(*) AS issue_count
FROM app_events ae
JOIN users u ON ae.user_id = u.user_id
WHERE ae.event_time::date < u.signup_date

UNION ALL

SELECT 'sleep sessions before signup',
       COUNT(*)
FROM sleep_sessions ss
JOIN users u ON ss.user_id = u.user_id
WHERE ss.sleep_date < u.signup_date

UNION ALL

SELECT 'experiment assigned before signup',
       COUNT(*)
FROM experiment_assignments ea
JOIN users u ON ea.user_id = u.user_id
WHERE ea.assigned_at::date < u.signup_date

UNION ALL

SELECT 'trial end before trial start',
       COUNT(*)
FROM subscriptions
WHERE trial_end < trial_start

UNION ALL

SELECT 'paid date before trial end',
       COUNT(*)
FROM subscriptions
WHERE paid_at IS NOT NULL
  AND paid_at < trial_end;


-- 7. Value range checks
SELECT 'sleep_score outside 0-100' AS check_name,
       COUNT(*) AS issue_count
FROM sleep_sessions
WHERE sleep_score < 0 OR sleep_score > 100

UNION ALL

SELECT 'sleep_duration outside 0-24 hours',
       COUNT(*)
FROM sleep_sessions
WHERE sleep_duration_hours <= 0 OR sleep_duration_hours > 24

UNION ALL

SELECT 'sleep_efficiency outside 0-100',
       COUNT(*)
FROM sleep_sessions
WHERE sleep_efficiency < 0 OR sleep_efficiency > 100

UNION ALL

SELECT 'negative awakenings',
       COUNT(*)
FROM sleep_sessions
WHERE awakenings < 0

UNION ALL

SELECT 'recommendation clicked outside 0/1',
       COUNT(*)
FROM recommendations
WHERE clicked NOT IN (0, 1);


-- 8. Event distribution
SELECT
    event_name,
    COUNT(*) AS event_count,
    COUNT(DISTINCT user_id) AS unique_users
FROM app_events
GROUP BY event_name
ORDER BY event_count DESC;


-- 9. User coverage across core product actions
SELECT
    COUNT(DISTINCT u.user_id) AS total_users,
    COUNT(DISTINCT ss.user_id) AS users_with_sleep_logs,
    COUNT(DISTINCT r.user_id) AS users_with_recommendations,
    COUNT(DISTINCT s.user_id) AS users_with_subscription_record,
    COUNT(DISTINCT ea.user_id) AS users_in_experiment
FROM users u
LEFT JOIN sleep_sessions ss ON u.user_id = ss.user_id
LEFT JOIN recommendations r ON u.user_id = r.user_id
LEFT JOIN subscriptions s ON u.user_id = s.user_id
LEFT JOIN experiment_assignments ea ON u.user_id = ea.user_id;


-- 10. Potential duplicate behavioral events
SELECT
    user_id,
    event_name,
    event_time,
    COUNT(*) AS duplicate_count
FROM app_events
GROUP BY user_id, event_name, event_time
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, user_id
LIMIT 20;