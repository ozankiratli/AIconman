"""Shared by the backend's tests that run against a real database: the one the
configuration in LMCONMAN_CONFIG_DIR names. They refuse to run without
LMCONMAN_CONFIG_DIR, or with it naming config/. They can rebuild and seed that
database's schema, with no dump, and query it as the owner role to see what was
stored."""

import os
import subprocess
from pathlib import Path

import psycopg

from lmconman import config as configuration

ROOT = Path(__file__).resolve().parent.parent.parent


def require() -> None:
    """Refuses to go on without LMCONMAN_CONFIG_DIR, or with it naming config/."""
    named = os.environ.get("LMCONMAN_CONFIG_DIR")
    if not named:
        raise RuntimeError("LMCONMAN_CONFIG_DIR must name the configuration of the database to test against")
    if Path(named).resolve() == (ROOT / "config").resolve():
        raise RuntimeError("refusing to test against config/")


def _owner() -> dict:
    raw = configuration.load_raw()
    get = lambda dotted: configuration.setting(raw, dotted)  # noqa: E731
    return {"host": get("db.host"), "port": get("db.port"), "dbname": get("db.dbname"),
            "user": get("db.adminuser"), "password": get("db.adminpw"), "app_user": get("db.user")}


def rebuild() -> None:
    """Drops and builds the schema, and seeds it with self sign-up open."""
    owner = _owner()
    subprocess.run(
        ["psql", "-X", "-w", "-q", "-1", "-v", "ON_ERROR_STOP=1",
         "-v", f"app_user={owner['app_user']}", "-v", "allow_auto_signup=true",
         "-h", owner["host"], "-p", str(owner["port"]), "-U", owner["user"], "-d", owner["dbname"],
         "-c", "SET client_min_messages = warning",
         "-f", str(ROOT / "db" / "build_schema.sql"), "-f", str(ROOT / "db" / "seed.sql")],
        env={**os.environ, "PGPASSWORD": owner["password"]}, check=True, capture_output=True,
    )


def owner_query(query: str, *params) -> list[tuple]:
    """QUERY's rows, run as the owner role."""
    owner = _owner()
    with psycopg.connect(host=owner["host"], port=owner["port"], dbname=owner["dbname"],
                         user=owner["user"], password=owner["password"]) as conn:
        return conn.execute(query, params).fetchall()
