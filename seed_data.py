import os
import numpy as np
import pandas as pd
from datetime import datetime, timedelta

np.random.seed(42)

DATA_DIR = "data"
os.makedirs(DATA_DIR, exist_ok=True)

N_USERS = 1200
START_DATE = pd.to_datetime("2025-01-01")
END_DATE = pd.to_datetime("2025-04-30")


def random_dates(start, end, n):
    days = (end - start).days
    return [start + timedelta(days=int(x)) for x in np.random.randint(0, days, n)]


# -------------------------
# 1. Users
# -------------------------

user_ids = np.arange(1, N_USERS + 1)

signup_dates = random_dates(START_DATE, END_DATE, N_USERS)

countries = np.random.choice(
    ["Russia", "Kazakhstan", "Armenia", "Georgia", "Serbia"],
    size=N_USERS,
    p=[0.55, 0.15, 0.10, 0.10, 0.10],
)

devices = np.random.choice(
    ["iOS", "Android"],
    size=N_USERS,
    p=[0.42, 0.58],
)

acquisition_channels = np.random.choice(
    ["organic", "paid_ads", "referral", "app_store", "content"],
    size=N_USERS,
    p=[0.30, 0.25, 0.18, 0.17, 0.10],
)

age_groups = np.random.choice(
    ["18-24", "25-34", "35-44", "45-54", "55+"],
    size=N_USERS,
    p=[0.18, 0.34, 0.25, 0.15, 0.08],
)

users = pd.DataFrame({
    "user_id": user_ids,
    "signup_date": signup_dates,
    "country": countries,
    "device": devices,
    "acquisition_channel": acquisition_channels,
    "age_group": age_groups,
})

users.to_csv(f"{DATA_DIR}/users.csv", index=False)


# -------------------------
# 2. Experiment assignments
# -------------------------

experiment_assignments = pd.DataFrame({
    "user_id": user_ids,
    "experiment_name": "personalized_sleep_recommendations",
    "experiment_group": np.random.choice(
        ["control", "treatment"],
        size=N_USERS,
        p=[0.5, 0.5],
    ),
    "assigned_at": signup_dates,
})

experiment_assignments.to_csv(f"{DATA_DIR}/experiment_assignments.csv", index=False)


# -------------------------
# 3. Sleep sessions
# -------------------------

sleep_rows = []

for _, user in users.iterrows():
    user_id = user["user_id"]
    signup_date = user["signup_date"]

    group = experiment_assignments.loc[
        experiment_assignments["user_id"] == user_id,
        "experiment_group"
    ].values[0]

    base_sleep_score = np.random.normal(68, 10)
    engagement_level = np.random.choice(
        ["low", "medium", "high"],
        p=[0.35, 0.45, 0.20],
    )

    if engagement_level == "low":
        log_probability = 0.25
    elif engagement_level == "medium":
        log_probability = 0.55
    else:
        log_probability = 0.78

    for day in range(0, 45):
        current_date = signup_date + timedelta(days=day)

        if np.random.rand() < log_probability:
            improvement = day * 0.05

            if group == "treatment":
                improvement += day * 0.035

            if engagement_level == "high":
                improvement += day * 0.025

            sleep_score = np.clip(
                base_sleep_score + improvement + np.random.normal(0, 6),
                20,
                100,
            )

            sleep_duration_hours = np.clip(
                np.random.normal(7.1, 1.1) + (sleep_score - 70) / 40,
                3.5,
                10.5,
            )

            sleep_efficiency = np.clip(
                np.random.normal(82, 7) + (sleep_score - 70) / 5,
                50,
                98,
            )

            awakenings = max(
                0,
                int(np.random.normal(3.2, 1.5) - (sleep_score - 70) / 18)
            )

            sleep_rows.append({
                "sleep_session_id": len(sleep_rows) + 1,
                "user_id": user_id,
                "sleep_date": current_date.date(),
                "sleep_duration_hours": round(sleep_duration_hours, 2),
                "sleep_efficiency": round(sleep_efficiency, 2),
                "awakenings": awakenings,
                "sleep_score": round(sleep_score, 2),
            })

sleep_sessions = pd.DataFrame(sleep_rows)
sleep_sessions.to_csv(f"{DATA_DIR}/sleep_sessions.csv", index=False)


# -------------------------
# 4. App events
# -------------------------

event_rows = []
event_id = 1

for _, user in users.iterrows():
    user_id = user["user_id"]
    signup_date = user["signup_date"]

    user_sleep = sleep_sessions[sleep_sessions["user_id"] == user_id]
    sleep_log_dates = set(pd.to_datetime(user_sleep["sleep_date"]).dt.date)

    # mandatory onboarding events for most users
    event_rows.append({
        "event_id": event_id,
        "user_id": user_id,
        "event_name": "registration",
        "event_time": signup_date,
    })
    event_id += 1

    if np.random.rand() < 0.92:
        event_rows.append({
            "event_id": event_id,
            "user_id": user_id,
            "event_name": "first_app_open",
            "event_time": signup_date + timedelta(minutes=np.random.randint(1, 180)),
        })
        event_id += 1

    for day in range(0, 45):
        current_date = signup_date + timedelta(days=day)

        if np.random.rand() < 0.45:
            event_rows.append({
                "event_id": event_id,
                "user_id": user_id,
                "event_name": "app_open",
                "event_time": current_date + timedelta(hours=np.random.randint(7, 23)),
            })
            event_id += 1

        if current_date.date() in sleep_log_dates:
            event_rows.append({
                "event_id": event_id,
                "user_id": user_id,
                "event_name": "sleep_log_added",
                "event_time": current_date + timedelta(hours=np.random.randint(6, 11)),
            })
            event_id += 1

            if np.random.rand() < 0.55:
                event_rows.append({
                    "event_id": event_id,
                    "user_id": user_id,
                    "event_name": "recommendation_viewed",
                    "event_time": current_date + timedelta(hours=np.random.randint(9, 23)),
                })
                event_id += 1

        if np.random.rand() < 0.18:
            event_rows.append({
                "event_id": event_id,
                "user_id": user_id,
                "event_name": "sleep_diary_opened",
                "event_time": current_date + timedelta(hours=np.random.randint(8, 23)),
            })
            event_id += 1

app_events = pd.DataFrame(event_rows)
app_events.to_csv(f"{DATA_DIR}/app_events.csv", index=False)


# -------------------------
# 5. Recommendations
# -------------------------

recommendation_rows = []
recommendation_types = [
    "consistent_bedtime",
    "reduce_screen_time",
    "morning_light",
    "breathing_exercise",
    "caffeine_limit",
]

viewed_events = app_events[app_events["event_name"] == "recommendation_viewed"]

for _, event in viewed_events.iterrows():
    user_id = event["user_id"]

    group = experiment_assignments.loc[
        experiment_assignments["user_id"] == user_id,
        "experiment_group"
    ].values[0]

    recommendation_rows.append({
        "recommendation_id": len(recommendation_rows) + 1,
        "user_id": user_id,
        "recommendation_type": np.random.choice(recommendation_types),
        "recommendation_mode": "personalized" if group == "treatment" else "generic",
        "shown_at": event["event_time"],
        "clicked": np.random.choice(
            [0, 1],
            p=[0.45, 0.55] if group == "treatment" else [0.62, 0.38],
        ),
    })

recommendations = pd.DataFrame(recommendation_rows)
recommendations.to_csv(f"{DATA_DIR}/recommendations.csv", index=False)


# -------------------------
# 6. Subscriptions
# -------------------------

subscription_rows = []

for _, user in users.iterrows():
    user_id = user["user_id"]
    signup_date = user["signup_date"]

    user_events = app_events[app_events["user_id"] == user_id]
    sleep_logs_count = (user_events["event_name"] == "sleep_log_added").sum()
    recommendation_views = (user_events["event_name"] == "recommendation_viewed").sum()

    conversion_probability = 0.05 + min(sleep_logs_count, 10) * 0.015 + min(recommendation_views, 10) * 0.01
    converted = np.random.rand() < conversion_probability

    trial_start = signup_date
    trial_end = signup_date + timedelta(days=14)

    if converted:
        status = np.random.choice(["paid", "cancelled"], p=[0.82, 0.18])
        paid_at = trial_end + timedelta(days=np.random.randint(0, 5))
    else:
        status = "trial_expired"
        paid_at = pd.NaT

    subscription_rows.append({
        "subscription_id": len(subscription_rows) + 1,
        "user_id": user_id,
        "trial_start": trial_start.date(),
        "trial_end": trial_end.date(),
        "paid_at": paid_at.date() if pd.notna(paid_at) else "",
        "subscription_status": status,
    })

subscriptions = pd.DataFrame(subscription_rows)
subscriptions.to_csv(f"{DATA_DIR}/subscriptions.csv", index=False)


print("Synthetic data generated successfully.")
print(f"Users: {len(users)}")
print(f"Experiment assignments: {len(experiment_assignments)}")
print(f"Sleep sessions: {len(sleep_sessions)}")
print(f"App events: {len(app_events)}")
print(f"Recommendations: {len(recommendations)}")
print(f"Subscriptions: {len(subscriptions)}")