import os
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text


DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://sleepmind_user:sleepmind_password@localhost:5432/sleepmind"
)

DATA_DIR = Path("data")
SCHEMA_FILE = Path("schema.sql")

TABLES = {
    "users": {
        "file": "users.csv",
        "parse_dates": ["signup_date"],
    },
    "experiment_assignments": {
        "file": "experiment_assignments.csv",
        "parse_dates": ["assigned_at"],
    },
    "sleep_sessions": {
        "file": "sleep_sessions.csv",
        "parse_dates": ["sleep_date"],
    },
    "app_events": {
        "file": "app_events.csv",
        "parse_dates": ["event_time"],
    },
    "recommendations": {
        "file": "recommendations.csv",
        "parse_dates": ["shown_at"],
    },
    "subscriptions": {
        "file": "subscriptions.csv",
        "parse_dates": ["trial_start", "trial_end", "paid_at"],
    },
}


def load_schema(engine):
    schema_sql = SCHEMA_FILE.read_text(encoding="utf-8")

    with engine.begin() as connection:
        connection.exec_driver_sql(schema_sql)

    print("Database schema created successfully.")


def load_table(engine, table_name, file_name, parse_dates):
    file_path = DATA_DIR / file_name

    if not file_path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")

    df = pd.read_csv(file_path, parse_dates=parse_dates)

    df = df.where(pd.notnull(df), None)

    df.to_sql(
        table_name,
        engine,
        if_exists="append",
        index=False,
        method="multi",
        chunksize=1000,
    )

    print(f"Loaded {len(df):,} rows into {table_name}")


def print_table_counts(engine):
    print("\nTable row counts:")

    with engine.connect() as connection:
        for table_name in TABLES.keys():
            result = connection.execute(
                text(f"SELECT COUNT(*) FROM {table_name}")
            )
            count = result.scalar()
            print(f"{table_name}: {count:,}")


def main():
    engine = create_engine(DATABASE_URL)

    load_schema(engine)

    for table_name, config in TABLES.items():
        load_table(
            engine=engine,
            table_name=table_name,
            file_name=config["file"],
            parse_dates=config["parse_dates"],
        )

    print_table_counts(engine)


if __name__ == "__main__":
    main()