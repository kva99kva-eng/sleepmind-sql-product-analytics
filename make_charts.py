from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt


DATA_DIR = Path("data")
IMAGES_DIR = Path("images")
IMAGES_DIR.mkdir(exist_ok=True)


def load_data():
    users = pd.read_csv(DATA_DIR / "users.csv", parse_dates=["signup_date"])
    app_events = pd.read_csv(DATA_DIR / "app_events.csv", parse_dates=["event_time"])
    experiment_assignments = pd.read_csv(
        DATA_DIR / "experiment_assignments.csv",
        parse_dates=["assigned_at"]
    )
    recommendations = pd.read_csv(
        DATA_DIR / "recommendations.csv",
        parse_dates=["shown_at"]
    )

    return users, app_events, experiment_assignments, recommendations


def plot_onboarding_funnel(users, app_events):
    total_users = users["user_id"].nunique()

    first_app_open_users = app_events.loc[
        app_events["event_name"] == "first_app_open",
        "user_id"
    ].nunique()

    first_sleep_log_users = app_events.loc[
        app_events["event_name"] == "sleep_log_added",
        "user_id"
    ].nunique()

    recommendation_viewed_users = app_events.loc[
        app_events["event_name"] == "recommendation_viewed",
        "user_id"
    ].nunique()

    sleep_log_counts = (
        app_events[app_events["event_name"] == "sleep_log_added"]
        .groupby("user_id")
        .size()
    )
    second_sleep_log_users = (sleep_log_counts >= 2).sum()

    merged = app_events.merge(users[["user_id", "signup_date"]], on="user_id")
    merged["event_date"] = merged["event_time"].dt.date
    merged["signup_plus_7"] = (merged["signup_date"] + pd.Timedelta(days=7)).dt.date

    d7_retained_users = merged.loc[
        merged["event_date"] == merged["signup_plus_7"],
        "user_id"
    ].nunique()

    funnel = pd.DataFrame({
        "step": [
            "Registration",
            "First app open",
            "First sleep log",
            "Recommendation viewed",
            "Second sleep log",
            "D7 retained",
        ],
        "users": [
            total_users,
            first_app_open_users,
            first_sleep_log_users,
            recommendation_viewed_users,
            second_sleep_log_users,
            d7_retained_users,
        ],
    })

    plt.figure(figsize=(10, 5))
    plt.bar(funnel["step"], funnel["users"])
    plt.title("Onboarding Funnel")
    plt.ylabel("Users")
    plt.xticks(rotation=30, ha="right")
    plt.tight_layout()
    plt.savefig(IMAGES_DIR / "onboarding_funnel.png", dpi=150)
    plt.close()


def plot_d30_retention_by_channel(users, app_events):
    active_events = [
        "app_open",
        "sleep_log_added",
        "recommendation_viewed",
        "sleep_diary_opened",
    ]

    events = app_events[app_events["event_name"].isin(active_events)].copy()
    events = events.merge(users[["user_id", "signup_date", "acquisition_channel"]], on="user_id")

    events["event_date"] = events["event_time"].dt.date
    events["signup_plus_30"] = (events["signup_date"] + pd.Timedelta(days=30)).dt.date

    retained_users = events.loc[
        events["event_date"] == events["signup_plus_30"],
        ["user_id", "acquisition_channel"]
    ].drop_duplicates()

    cohort = users.groupby("acquisition_channel")["user_id"].nunique().reset_index()
    cohort = cohort.rename(columns={"user_id": "users_count"})

    retained = retained_users.groupby("acquisition_channel")["user_id"].nunique().reset_index()
    retained = retained.rename(columns={"user_id": "d30_retained"})

    result = cohort.merge(retained, on="acquisition_channel", how="left")
    result["d30_retained"] = result["d30_retained"].fillna(0)
    result["d30_retention_percent"] = 100 * result["d30_retained"] / result["users_count"]
    result = result.sort_values("d30_retention_percent", ascending=False)

    plt.figure(figsize=(9, 5))
    plt.bar(result["acquisition_channel"], result["d30_retention_percent"])
    plt.title("D30 Retention by Acquisition Channel")
    plt.ylabel("D30 retention, %")
    plt.xlabel("Acquisition channel")
    plt.tight_layout()
    plt.savefig(IMAGES_DIR / "d30_retention_by_channel.png", dpi=150)
    plt.close()


def plot_ab_test_summary(users, app_events, experiment_assignments, recommendations):
    users_exp = users.merge(experiment_assignments[["user_id", "experiment_group"]], on="user_id")

    events = app_events.merge(users_exp[["user_id", "signup_date", "experiment_group"]], on="user_id")
    events["event_date"] = events["event_time"].dt.date
    events["signup_plus_30"] = (events["signup_date"] + pd.Timedelta(days=30)).dt.date

    d30_retained = (
        events[events["event_date"] == events["signup_plus_30"]]
        .groupby("experiment_group")["user_id"]
        .nunique()
    )

    group_sizes = users_exp.groupby("experiment_group")["user_id"].nunique()
    d30_retention = 100 * d30_retained / group_sizes

    recs = recommendations.merge(
        experiment_assignments[["user_id", "experiment_group"]],
        on="user_id"
    )

    ctr = (
        100
        * recs.groupby("experiment_group")["clicked"].sum()
        / recs.groupby("experiment_group")["recommendation_id"].count()
    )

    summary = pd.DataFrame({
        "D30 retention, %": d30_retention,
        "Recommendation CTR, %": ctr,
    }).reset_index()

    summary = summary.melt(
        id_vars="experiment_group",
        var_name="metric",
        value_name="value"
    )

    labels = summary["experiment_group"] + " / " + summary["metric"]

    plt.figure(figsize=(10, 5))
    plt.bar(labels, summary["value"])
    plt.title("A/B Test Summary")
    plt.ylabel("Percent")
    plt.xticks(rotation=30, ha="right")
    plt.tight_layout()
    plt.savefig(IMAGES_DIR / "ab_test_summary.png", dpi=150)
    plt.close()


def main():
    users, app_events, experiment_assignments, recommendations = load_data()

    plot_onboarding_funnel(users, app_events)
    plot_d30_retention_by_channel(users, app_events)
    plot_ab_test_summary(users, app_events, experiment_assignments, recommendations)

    print("Charts saved to images/")


if __name__ == "__main__":
    main()