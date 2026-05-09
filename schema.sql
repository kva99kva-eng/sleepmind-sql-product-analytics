DROP TABLE IF EXISTS recommendations CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS sleep_sessions CASCADE;
DROP TABLE IF EXISTS app_events CASCADE;
DROP TABLE IF EXISTS experiment_assignments CASCADE;
DROP TABLE IF EXISTS users CASCADE;

CREATE TABLE users (
    user_id INTEGER PRIMARY KEY,
    signup_date DATE NOT NULL,
    country TEXT NOT NULL,
    device TEXT NOT NULL,
    acquisition_channel TEXT NOT NULL,
    age_group TEXT NOT NULL
);

CREATE TABLE experiment_assignments (
    user_id INTEGER PRIMARY KEY REFERENCES users(user_id),
    experiment_name TEXT NOT NULL,
    experiment_group TEXT NOT NULL,
    assigned_at TIMESTAMP NOT NULL
);

CREATE TABLE sleep_sessions (
    sleep_session_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id),
    sleep_date DATE NOT NULL,
    sleep_duration_hours NUMERIC(4, 2) NOT NULL,
    sleep_efficiency NUMERIC(5, 2) NOT NULL,
    awakenings INTEGER NOT NULL,
    sleep_score NUMERIC(5, 2) NOT NULL
);

CREATE TABLE app_events (
    event_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id),
    event_name TEXT NOT NULL,
    event_time TIMESTAMP NOT NULL
);

CREATE TABLE recommendations (
    recommendation_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id),
    recommendation_type TEXT NOT NULL,
    recommendation_mode TEXT NOT NULL,
    shown_at TIMESTAMP NOT NULL,
    clicked SMALLINT NOT NULL CHECK (clicked IN (0, 1))
);

CREATE TABLE subscriptions (
    subscription_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id),
    trial_start DATE NOT NULL,
    trial_end DATE NOT NULL,
    paid_at DATE,
    subscription_status TEXT NOT NULL
);

CREATE INDEX idx_users_signup_date ON users(signup_date);
CREATE INDEX idx_app_events_user_id ON app_events(user_id);
CREATE INDEX idx_app_events_event_name ON app_events(event_name);
CREATE INDEX idx_app_events_event_time ON app_events(event_time);
CREATE INDEX idx_sleep_sessions_user_id ON sleep_sessions(user_id);
CREATE INDEX idx_sleep_sessions_sleep_date ON sleep_sessions(sleep_date);
CREATE INDEX idx_recommendations_user_id ON recommendations(user_id);
CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);
