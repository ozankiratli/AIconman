"""Tests of aiconman/app.py and aiconman/db.py against a real database: the
one the configuration in AICONMAN_CONFIG_DIR names, built and seeded, as the
app role. The application runs in the test's own process; no server is
started. Refuses to run without AICONMAN_CONFIG_DIR, or with it naming config/.

    AICONMAN_CONFIG_DIR=.tmp/scratch/config .venv/bin/python -m unittest discover -s tests/backend -p 'test_app.py'
"""

import unittest

import httpx

import scratch
from aiconman import config as configuration
from aiconman.app import create_app, status_for
from aiconman.db import Refused, call, connect


def setUpModule():
    scratch.require()


class AppTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.config = configuration.load()
        self.app = create_app(self.config)
        self.client = httpx.AsyncClient(transport=httpx.ASGITransport(app=self.app), base_url="http://test")
        self.addAsyncCleanup(self.client.aclose)

    async def test_health_reaches_the_database(self):
        response = await self.client.get("/api/health")
        self.assertEqual((response.status_code, response.json()), (200, {"status": "ok"}))

    async def test_fastapis_documentation_pages_are_off(self):
        for path in ("/docs", "/redoc", "/openapi.json"):
            self.assertEqual((await self.client.get(path)).status_code, 404, path)

    async def test_a_refusal_answers_with_its_key_and_status(self):
        cases = {"session_invalid": 401, "not_admin": 403, "no_such_model": 404,
                 "name_taken": 409, "already_linked": 409, "last_admin": 400}

        async def refuse(key: str):
            raise Refused(key)

        self.app.add_api_route("/test/refuse/{key}", refuse)
        for key, status in cases.items():
            response = await self.client.get(f"/test/refuse/{key}")
            self.assertEqual((response.status_code, response.json()), (status, {"error": key}), key)
            self.assertEqual(status_for(key), status, key)


class DbTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.config = configuration.load()

    async def test_a_function_called_as_the_app_role_returns_its_rows(self):
        async with connect(self.config.db) as conn:
            rows = await call(conn, "sign_up_open")
        self.assertEqual(list(rows[0]), ["sign_up_open"])
        self.assertIsInstance(rows[0]["sign_up_open"], bool)

    async def test_a_functions_refusal_comes_back_as_refused_with_its_key(self):
        async with connect(self.config.db) as conn:
            with self.assertRaises(Refused) as caught:
                await call(conn, "session_check", bytes(32))
        self.assertEqual(caught.exception.key, "session_invalid")

    async def test_the_app_role_cannot_read_a_table(self):
        import psycopg
        async with connect(self.config.db) as conn:
            with self.assertRaises(psycopg.errors.InsufficientPrivilege):
                await conn.execute("SELECT * FROM accounts")


if __name__ == "__main__":
    unittest.main()
