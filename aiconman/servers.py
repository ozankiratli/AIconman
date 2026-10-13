"""Checking a model server: detecting its protocol, and listing the models it
serves with what it reports about each.

A connection's base URL is what the protocol's paths are added to: for the
OpenAI-compatible protocol, the address its API is under, which usually ends in
/v1; for Ollama's own API, the server's address. A failed check is reported by
a key, such as unreachable, which the database records as the check's error.
"""

from dataclasses import dataclass
from typing import Any
from urllib.parse import urlsplit

import httpx

# A new connection's timeouts, in seconds, when the admin gives none: how long
# to wait for its server to accept a connection, and how long for each answer.
CONNECT_TIMEOUT = 60
ANSWER_TIMEOUT = 300


@dataclass(frozen=True)
class Check:
    """What a check found: the protocol detected, or None when the protocol was
    given or none was found; the error's key, or None when it succeeded; and
    the models, as dictionaries with "name", and "chat", "images", "speech" and
    "context", each None when the server did not say."""

    detected: str | None
    error: str | None
    models: list[dict] | None


class CheckFailed(Exception):
    """A check that could not finish; KEY says why."""

    def __init__(self, key: str):
        super().__init__(key)
        self.key = key


def client(transport: httpx.AsyncBaseTransport | None = None) -> httpx.AsyncClient:
    """An HTTP client for the model servers, through TRANSPORT when given.
    Each request carries its connection's own timeouts."""
    return httpx.AsyncClient(transport=transport, timeout=None, follow_redirects=False)


def timeouts(connect: int, answer: int) -> httpx.Timeout:
    """The timeouts of a request: CONNECT seconds to connect, and ANSWER
    seconds for each answer."""
    return httpx.Timeout(float(answer), connect=float(connect))


async def check(http: httpx.AsyncClient, base_url: str, protocol: str | None, api_key: str | None,
                connect_timeout: int, answer_timeout: int) -> Check:
    """Checks the server at BASE_URL: detects its protocol when PROTOCOL is
    None, and lists its models, sending API_KEY as a bearer token when there
    is one, and waiting as long as the timeouts allow. A base URL that is not
    an http or https address with a host fails the check as base_url_invalid,
    before any request."""
    base = base_url.rstrip("/")
    parts = urlsplit(base)
    if parts.scheme not in ("http", "https") or not parts.hostname or any(c.isspace() for c in base):
        return Check(None, "base_url_invalid", None)
    request = _Request(http, {"Authorization": f"Bearer {api_key}"} if api_key else {},
                       timeouts(connect_timeout, answer_timeout))
    try:
        detected = None
        if protocol is None:
            protocol = detected = await detect(request, base)
        listing = list_ollama if protocol == "ollama" else list_openai
        return Check(detected, None, await listing(request, base))
    except CheckFailed as e:
        return Check(None, e.key, None)


@dataclass(frozen=True)
class _Request:
    """What every request of one check shares: the client, the headers and
    the timeouts."""

    http: httpx.AsyncClient
    headers: dict
    timeout: httpx.Timeout

    async def send(self, method: str, url: str, body: Any = None) -> httpx.Response:
        """The server's response, raising CheckFailed as timed_out or
        unreachable when there is none."""
        try:
            return await self.http.request(method, url, headers=self.headers, json=body, timeout=self.timeout)
        except httpx.TimeoutException as e:
            raise CheckFailed("timed_out") from e
        except httpx.HTTPError as e:
            raise CheckFailed("unreachable") from e


async def detect(request: _Request, base: str) -> str:
    """"ollama" when GET <base>/api/version answers with a version; otherwise
    "openai" when GET <base>/models answers with a list of models. An Ollama
    server given with /v1 at the end of its address answers as the second."""
    response = await request.send("GET", f"{base}/api/version")
    if response.status_code == 200:
        body = _parse(response)
        if isinstance(body, dict) and isinstance(body.get("version"), str):
            return "ollama"
    response = await request.send("GET", f"{base}/models")
    if response.status_code == 404:
        raise CheckFailed("not_recognized")
    if _is_model_list(_json(response)):
        return "openai"
    raise CheckFailed("not_recognized")


async def list_openai(request: _Request, base: str) -> list[dict]:
    """The models GET <base>/models lists. Whether a model reads images comes
    from llama.cpp's architecture.input_modalities, where the server gives it.
    On a server that lists exactly one model, the context window is the one
    llama.cpp's GET /props gives for a slot, where it answers; a server that
    lists several may be a router, which a request can make load a model."""
    body = _json(await request.send("GET", f"{base}/models"))
    if not _is_model_list(body):
        raise CheckFailed("unexpected_answer")
    models = []
    for entry in body["data"]:
        if not isinstance(entry, dict) or not isinstance(entry.get("id"), str) or not entry["id"]:
            raise CheckFailed("unexpected_answer")
        architecture = entry.get("architecture")
        modalities = architecture.get("input_modalities") if isinstance(architecture, dict) else None
        images = "image" in modalities if isinstance(modalities, list) else None
        models.append({"name": entry["id"], "chat": None, "images": images, "speech": None, "context": None})
    if len(models) == 1:
        root = base[: -len("/v1")] if base.endswith("/v1") else base
        models[0]["context"] = await _slot_context(request, root)
    return models


async def list_ollama(request: _Request, base: str) -> list[dict]:
    """The models GET <base>/api/tags lists, each with what POST
    <base>/api/show reports: it chats when its capabilities include
    "completion", and reads images when they include "vision"; with no
    capabilities reported, both are unknown. Speech is false, Ollama having no
    endpoint for transcription, and the window is left unknown."""
    body = _json(await request.send("GET", f"{base}/api/tags"))
    if not isinstance(body, dict) or not isinstance(body.get("models"), list):
        raise CheckFailed("unexpected_answer")
    models = []
    for entry in body["models"]:
        if not isinstance(entry, dict) or not isinstance(entry.get("name"), str) or not entry["name"]:
            raise CheckFailed("unexpected_answer")
        details = _json(await request.send("POST", f"{base}/api/show", {"model": entry["name"]}))
        capabilities = details.get("capabilities") if isinstance(details, dict) else None
        if isinstance(capabilities, list):
            chat, images = "completion" in capabilities, "vision" in capabilities
        else:
            chat = images = None
        models.append({"name": entry["name"], "chat": chat, "images": images, "speech": False, "context": None})
    return models


async def _slot_context(request: _Request, root: str) -> int | None:
    """The n_ctx of default_generation_settings in GET <root>/props, or None
    when the server does not answer with one."""
    try:
        response = await request.send("GET", f"{root}/props")
    except CheckFailed:
        return None
    body = _parse(response) if response.status_code == 200 else None
    settings = body.get("default_generation_settings") if isinstance(body, dict) else None
    n_ctx = settings.get("n_ctx") if isinstance(settings, dict) else None
    return n_ctx if isinstance(n_ctx, int) and not isinstance(n_ctx, bool) and n_ctx > 0 else None


def _parse(response: httpx.Response) -> Any:
    """The response's JSON, or None when it is not JSON."""
    try:
        return response.json()
    except ValueError:
        return None


def _json(response: httpx.Response) -> Any:
    """The JSON of a successful response, raising CheckFailed as unauthorized
    for 401 and 403, as http_<status> for any other error, and as
    unexpected_answer when the body is not JSON."""
    if response.status_code in (401, 403):
        raise CheckFailed("unauthorized")
    if response.status_code >= 400:
        raise CheckFailed(f"http_{response.status_code}")
    body = _parse(response)
    if body is None:
        raise CheckFailed("unexpected_answer")
    return body


def _is_model_list(body: Any) -> bool:
    """Whether BODY has the shape of an OpenAI-compatible list of models."""
    return isinstance(body, dict) and body.get("object") == "list" and isinstance(body.get("data"), list)
