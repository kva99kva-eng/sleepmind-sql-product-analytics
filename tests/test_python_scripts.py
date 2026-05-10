import py_compile
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_python_scripts_compile():
    scripts = [
        "seed_data.py",
        "load_to_postgres.py",
        "make_charts.py",
    ]

    for script in scripts:
        py_compile.compile(
            str(PROJECT_ROOT / script),
            doraise=True,
        )
