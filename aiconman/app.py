"""The AIconman web application.

Run with Uvicorn, which calls create_app:

    .venv/bin/uvicorn --factory aiconman.app:create_app --host 127.0.0.1 --port 8642
"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from aiconman import config as configuration
from aiconman.db import Refused, call, connect

# The HTTP status of a refusal, by its key; any other key is 400. A key naming
# something that does not exist is 404, and one naming something already taken
# is 409.
STATUS = {
    "session_invalid": 401,
    "not_admin": 403,
    "password_change_required": 403,
    "deactivated": 403,
    "sign_up_closed": 403,
    "no_account": 404,
    "already_linked": 409,
}


def status_for(key: str) -> int:
    """The HTTP status that answers the refusal KEY."""
    if key in STATUS:
        return STATUS[key]
    if key.startswith("no_such_"):
        return 404
    if key.endswith("_taken"):
        return 409
    return 400


def create_app(config: configuration.Config | None = None) -> FastAPI:
    """The application, run with CONFIG, or with the configuration
    configuration.load() reads. FastAPI's own documentation pages are off:
    they load their scripts from outside the household's network."""
    config = config or configuration.load()
    app = FastAPI(title="AIconman", docs_url=None, redoc_url=None, openapi_url=None)
    app.state.config = config

    @app.exception_handler(Refused)
    async def refused(request: Request, exc: Refused) -> JSONResponse:
        return JSONResponse({"error": exc.key}, status_code=status_for(exc.key))

    @app.get("/api/health")
    async def health() -> dict:
        """Whether the backend reaches its database and finds the schema
        seeded."""
        async with connect(config.db) as conn:
            await call(conn, "sign_up_open")
        return {"status": "ok"}

    return app
