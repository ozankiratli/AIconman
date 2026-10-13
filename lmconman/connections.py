"""The connection endpoints: the admin's connections and models, checking one
or all of them, and the models every signed-in account may use. Also the
check of one connection, which the scheduled refresh shares.

A connection's key is encrypted here before it reaches the database, and
decrypted only to be sent to its server; no endpoint returns it.
"""

import asyncio

import httpx
from fastapi import APIRouter, Depends, Request
from psycopg.types.json import Jsonb
from pydantic import BaseModel

from lmconman import keys, servers, sessions
from lmconman.accounts import db
from lmconman.config import Config
from lmconman.db import Refused, call

router = APIRouter(prefix="/api")


def stored_key(config: Config, api_key: str | None) -> bytes | None:
    """API_KEY, without whitespace at either end, encrypted for the database;
    None when there is no key, or it is empty."""
    key = (api_key or "").strip()
    return keys.encrypt(config.encryption_key, key) if key else None


async def check_connection(config: Config, http: httpx.AsyncClient, access: dict) -> servers.Check:
    """Checks the connection ACCESS describes, a row of admin_connection_access
    or refresh_targets: decrypts its key and checks its server, with its
    timeouts. A key the configured secret does not open fails the check as
    key_undecryptable."""
    api_key = None
    if access["api_key"] is not None:
        try:
            api_key = keys.decrypt(config.encryption_key, access["api_key"])
        except keys.UndecryptableKey:
            return servers.Check(None, "key_undecryptable", None)
    return await servers.check(http, access["base_url"], access["protocol"], api_key,
                               access["connect_timeout"], access["answer_timeout"])


def recorded(result: servers.Check) -> tuple:
    """RESULT as the database's record of a check takes it: the protocol
    detected, the error, and the models as JSON."""
    models = Jsonb(result.models) if result.models is not None else None
    return result.detected, result.error, models


def http_client(request: Request) -> httpx.AsyncClient:
    """An HTTP client for the model servers, through the application's
    server_transport when one is set."""
    return servers.client(getattr(request.app.state, "server_transport", None))


# Using the models -------------------------------------------------------------

@router.get("/models")
async def models(token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> list[dict]:
    """The models the last checks found, on every connection, with what each
    can do and its window."""
    return await call(conn, "models", token_hash)


# Administration ---------------------------------------------------------------

class NewConnection(BaseModel):
    name: str
    base_url: str
    protocol: str | None = None
    api_key: str | None = None
    connect_timeout: int = servers.CONNECT_TIMEOUT
    answer_timeout: int = servers.ANSWER_TIMEOUT


class ConnectionChange(BaseModel):
    name: str
    base_url: str
    protocol: str | None = None
    connect_timeout: int
    answer_timeout: int


class TryConnection(BaseModel):
    base_url: str
    protocol: str | None = None
    api_key: str | None = None
    connection_id: int | None = None
    connect_timeout: int = servers.CONNECT_TIMEOUT
    answer_timeout: int = servers.ANSWER_TIMEOUT


class KeyChange(BaseModel):
    api_key: str | None = None


class ModelSettings(BaseModel):
    chat: bool | None = None
    images: bool | None = None
    speech: bool | None = None
    context: int | None = None


@router.get("/admin/connections")
async def admin_connections(token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> list[dict]:
    """Every connection, with whether it has a key and its last check."""
    return await call(conn, "admin_connections", token_hash)


@router.get("/admin/connections/defaults")
async def admin_connection_defaults(token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> dict:
    """A new connection's timeouts, in seconds, when the admin gives none."""
    await call(conn, "admin_confirm", token_hash)
    return {"connect_timeout": servers.CONNECT_TIMEOUT, "answer_timeout": servers.ANSWER_TIMEOUT}


@router.post("/admin/connections")
async def admin_create_connection(body: NewConnection, request: Request,
                                  token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> dict:
    """Adds a connection, its key encrypted. A protocol of null is detected
    at its check; timeouts not given are the defaults."""
    key = stored_key(request.app.state.config, body.api_key)
    connection_id = (await call(conn, "admin_create_connection", token_hash, body.name, body.base_url,
                                body.protocol, key, body.connect_timeout,
                                body.answer_timeout))[0]["admin_create_connection"]
    return {"connection_id": connection_id}


@router.put("/admin/connections/{connection_id}")
async def admin_update_connection(connection_id: int, body: ConnectionChange,
                                  token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> dict:
    """Changes a connection's name, base URL, protocol and timeouts."""
    await call(conn, "admin_update_connection", token_hash, connection_id, body.name, body.base_url,
               body.protocol, body.connect_timeout, body.answer_timeout)
    return {"connection_id": connection_id}


@router.post("/admin/connections/try")
async def admin_try_connection(body: TryConnection, request: Request,
                               token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> dict:
    """Checks a connection's values before they are saved, and records
    nothing: what the editor holds, with the key typed in it, or, when none is
    typed and the connection is saved, its saved key."""
    config = request.app.state.config
    await call(conn, "admin_confirm", token_hash)
    for name in ("connect_timeout", "answer_timeout"):
        if getattr(body, name) <= 0:
            raise Refused(f"{name}_invalid")
    api_key = (body.api_key or "").strip() or None
    if api_key is None and body.connection_id is not None:
        saved = (await call(conn, "admin_connection_access", token_hash, body.connection_id))[0]["api_key"]
        if saved is not None:
            try:
                api_key = keys.decrypt(config.encryption_key, saved)
            except keys.UndecryptableKey:
                return {"detected": None, "error": "key_undecryptable", "models": None}
    async with http_client(request) as http:
        result = await servers.check(http, body.base_url, body.protocol, api_key,
                                     body.connect_timeout, body.answer_timeout)
    return {"detected": result.detected, "error": result.error, "models": result.models}


@router.put("/admin/connections/{connection_id}/key")
async def admin_set_connection_key(connection_id: int, body: KeyChange, request: Request,
                                   token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> dict:
    """Replaces a connection's key; null or an empty key removes it."""
    key = stored_key(request.app.state.config, body.api_key)
    await call(conn, "admin_set_connection_key", token_hash, connection_id, key)
    return {"connection_id": connection_id, "has_key": key is not None}


@router.delete("/admin/connections/{connection_id}")
async def admin_delete_connection(connection_id: int, token_hash: bytes = Depends(sessions.current),
                                  conn=Depends(db)) -> dict:
    """Removes a connection and its models."""
    await call(conn, "admin_delete_connection", token_hash, connection_id)
    return {"deleted": connection_id}


@router.get("/admin/connections/{connection_id}/models")
async def admin_models(connection_id: int, token_hash: bytes = Depends(sessions.current),
                       conn=Depends(db)) -> list[dict]:
    """Every model a check of the connection has found, with what the server
    reported and what the admin set."""
    return await call(conn, "admin_models", token_hash, connection_id)


@router.put("/admin/models/{model_id}")
async def admin_set_model(model_id: int, body: ModelSettings, token_hash: bytes = Depends(sessions.current),
                          conn=Depends(db)) -> dict:
    """Sets what a model can do and its window; null follows the server."""
    await call(conn, "admin_set_model", token_hash, model_id, body.chat, body.images, body.speech, body.context)
    return {"model_id": model_id, **body.model_dump()}


@router.post("/admin/connections/{connection_id}/check")
async def admin_check(connection_id: int, request: Request, token_hash: bytes = Depends(sessions.current),
                      conn=Depends(db)) -> dict:
    """Checks a connection now and records the result; returns the connection
    and its models as they then are."""
    access = (await call(conn, "admin_connection_access", token_hash, connection_id))[0]
    async with http_client(request) as http:
        result = await check_connection(request.app.state.config, http, access)
    await call(conn, "admin_record_check", token_hash, connection_id, *recorded(result))
    connection = next(c for c in await call(conn, "admin_connections", token_hash)
                      if c["connection_id"] == connection_id)
    return {"connection": connection, "models": await call(conn, "admin_models", token_hash, connection_id)}


@router.post("/admin/connections/check-all")
async def admin_check_all(request: Request, token_hash: bytes = Depends(sessions.current),
                          conn=Depends(db)) -> list[dict]:
    """Checks every connection at once and records the results; returns the
    connections as they then are. A connection removed meanwhile is skipped."""
    rows = await call(conn, "admin_connections", token_hash)
    accesses = [(await call(conn, "admin_connection_access", token_hash, row["connection_id"]))[0]
                for row in rows]
    async with http_client(request) as http:
        results = await asyncio.gather(*(check_connection(request.app.state.config, http, access)
                                         for access in accesses))
    for row, result in zip(rows, results):
        try:
            await call(conn, "admin_record_check", token_hash, row["connection_id"], *recorded(result))
        except Refused as e:
            if e.key != "no_such_connection":
                raise
    return await call(conn, "admin_connections", token_hash)
