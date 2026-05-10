from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_required_project_files_exist():
    required_files = [
        "README.md",
        "requirements.txt",
        "docker-compose.yml",
        "schema.sql",
        "seed_data.py",
        "load_to_postgres.py",
        "make_charts.py",
    ]

    for file_path in required_files:
        assert (PROJECT_ROOT / file_path).exists(), f"Missing required file: {file_path}"


def test_required_directories_exist():
    required_dirs = [
        "sql",
        "images",
        "reports",
        "notebooks",
    ]

    for dir_path in required_dirs:
        assert (PROJECT_ROOT / dir_path).exists(), f"Missing required directory: {dir_path}"


def test_expected_sql_modules_exist():
    expected_sql_files = [
        "02_data_quality_checks.sql",
        "03_onboarding_funnel.sql",
        "04_cohort_retention.sql",
        "05_sleep_improvement.sql",
        "06_ab_test_analysis.sql",
        "07_churn_risk.sql",
    ]

    for sql_file in expected_sql_files:
        path = PROJECT_ROOT / "sql" / sql_file
        assert path.exists(), f"Missing SQL module: {sql_file}"
        assert path.stat().st_size > 0, f"SQL module is empty: {sql_file}"
