import re
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_schema_contains_core_tables():
    schema = (PROJECT_ROOT / "schema.sql").read_text(encoding="utf-8").lower()

    expected_tables = [
        "users",
        "app_events",
        "sleep_sessions",
        "recommendations",
        "subscriptions",
        "experiment_assignments",
    ]

    for table in expected_tables:
        pattern = rf"create\s+table\s+(if\s+not\s+exists\s+)?{table}\b"
        assert re.search(pattern, schema), f"Missing CREATE TABLE statement for: {table}"


def test_sql_modules_contain_select_statements():
    sql_dir = PROJECT_ROOT / "sql"

    for path in sql_dir.glob("*.sql"):
        content = path.read_text(encoding="utf-8").lower()
        assert "select" in content, f"No SELECT statement found in {path.name}"


def test_sql_modules_are_numbered_in_expected_order():
    sql_files = sorted(path.name for path in (PROJECT_ROOT / "sql").glob("*.sql"))

    assert sql_files == [
        "02_data_quality_checks.sql",
        "03_onboarding_funnel.sql",
        "04_cohort_retention.sql",
        "05_sleep_improvement.sql",
        "06_ab_test_analysis.sql",
        "07_churn_risk.sql",
    ]
