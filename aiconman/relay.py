"""Relaying a chat to a model server, and its reply back as it streams.

The OpenAI-compatible protocol streams a chat completion as server-sent events,
each a chunk whose choices carry a piece of the reply, and its reasoning as
llama.cpp's reasoning_content, and ends with "data: [DONE]"; usage is asked
for, and comes in a chunk of its own. Ollama's own protocol streams one JSON
object per line, the last with "done" and the counts. Either can report an
error before the stream starts or within it.

A failure is RelayFailed, with a key, such as unreachable, and, when the server
said why, its words: an error's "message" where it has one, its text as the
server sent it otherwise.
"""

import json
from collections.abc import AsyncIterator
from dataclasses import dataclass
from typing import Any

import httpx

from aiconman import servers

DETAIL_LENGTH = 1000


@dataclass(frozen=True)
class Piece:
    """A piece of a reply as it streams: its text, and the model's reasoning."""

    content: str = ""
    reasoning: str = ""


@dataclass(frozen=True)
class Usage:
    """The tokens of the prompt and of the reply, as the server counted them."""

    prompt_tokens: int | None
    completion_tokens: int | None


class RelayFailed(Exception):
    """A reply that could not be had; KEY says why, and DETAIL is the server's
    own words, when it gave any."""

    def __init__(self, key: str, detail: str | None = None):
        super().__init__(key)
        self.key = key
        self.detail = detail

    @property
    def text(self) -> str:
        """The failure as a reply records it: the key, then the server's words
        after a colon, when there are any."""
        return f"{self.key}: {self.detail}" if self.detail else self.key


async def stream(http: httpx.AsyncClient, access: dict, api_key: str | None, messages: list[dict],
                 output_limit: int | None) -> AsyncIterator[Piece | Usage]:
    """The reply of the model ACCESS describes, a row of model_access, to
    MESSAGES, as pieces and then its usage, sending API_KEY, its connection's
    key decrypted, as a bearer token when there is one. OUTPUT_LIMIT, when
    given, limits the reply's length in tokens."""
    timeout = servers.timeouts(access["connect_timeout"], access["answer_timeout"])
    base = access["base_url"].rstrip("/")
    if access["protocol"] == "ollama":
        body = _ollama_body(access, messages, output_limit)
        lines = _lines(http, f"{base}/api/chat", body, _headers(api_key), timeout)
        async for event in _ollama_events(lines):
            yield event
    else:
        body = _openai_body(access, messages, output_limit)
        lines = _lines(http, f"{base}/chat/completions", body, _headers(api_key), timeout)
        async for event in _openai_events(lines):
            yield event


async def count(http: httpx.AsyncClient, access: dict, api_key: str | None, messages: list[dict],
                output_limit: int | None) -> int:
    """The tokens of the request stream() would send to an OpenAI-compatible
    server, as llama.cpp's input_tokens counts them; raises RelayFailed when
    the server gives no count."""
    url = f"{access['base_url'].rstrip('/')}{servers.INPUT_TOKENS_PATH}"
    try:
        response = await http.post(url, json=_openai_body(access, messages, output_limit),
                                   headers=_headers(api_key),
                                   timeout=servers.timeouts(access["connect_timeout"], access["answer_timeout"]))
    except httpx.TimeoutException as e:
        raise RelayFailed("timed_out") from e
    except httpx.HTTPError as e:
        raise RelayFailed("unreachable") from e
    if response.status_code >= 400:
        raise RelayFailed(f"http_{response.status_code}", _detail(response.text))
    try:
        tokens = servers.input_tokens(response.json())
    except ValueError:
        tokens = None
    if tokens is None:
        raise RelayFailed("unexpected_answer")
    return tokens


def _headers(api_key: str | None) -> dict:
    """API_KEY as a bearer token, when there is one."""
    return {"Authorization": f"Bearer {api_key}"} if api_key else {}


def _openai_body(access: dict, messages: list[dict], output_limit: int | None) -> dict:
    """A streamed chat completion request, asking for usage at the end."""
    body: dict[str, Any] = {"model": access["model_name"], "messages": messages, "stream": True,
                            "stream_options": {"include_usage": True}}
    if output_limit:
        body["max_completion_tokens"] = output_limit
    return body


def _ollama_body(access: dict, messages: list[dict], output_limit: int | None) -> dict:
    """A streamed Ollama chat request. The window is sent as num_ctx only when
    the model has one, and the output limit as num_predict."""
    body: dict[str, Any] = {"model": access["model_name"], "messages": messages, "stream": True}
    options = {}
    if access["context"]:
        options["num_ctx"] = access["context"]
    if output_limit:
        options["num_predict"] = output_limit
    if options:
        body["options"] = options
    return body


async def _lines(http: httpx.AsyncClient, url: str, body: dict, headers: dict,
                 timeout: httpx.Timeout) -> AsyncIterator[str]:
    """The lines of the server's answer to BODY, posted to URL, as they come;
    raises RelayFailed for no answer, or for an error status, with the error
    the server gave."""
    try:
        async with http.stream("POST", url, json=body, headers=headers, timeout=timeout) as response:
            if response.status_code >= 400:
                text = (await response.aread()).decode(errors="replace")
                raise RelayFailed(f"http_{response.status_code}", _detail(text))
            async for line in response.aiter_lines():
                yield line
    except httpx.TimeoutException as e:
        raise RelayFailed("timed_out") from e
    except httpx.HTTPError as e:
        raise RelayFailed("unreachable") from e


async def _openai_events(lines: AsyncIterator[str]) -> AsyncIterator[Piece | Usage]:
    """The pieces and the usage in a chat completion's server-sent events; a
    piece's reasoning is its delta's reasoning_content."""
    async for line in lines:
        if not line.startswith("data:"):
            continue
        data = line[len("data:"):].strip()
        if data == "[DONE]":
            return
        chunk = _object(data)
        if "error" in chunk:
            raise RelayFailed("server_error", _detail(json.dumps(chunk)))
        for choice in chunk.get("choices") or []:
            delta = choice.get("delta") if isinstance(choice, dict) else None
            if not isinstance(delta, dict):
                continue
            content, reasoning = delta.get("content"), delta.get("reasoning_content")
            piece = Piece(content=content if isinstance(content, str) else "",
                          reasoning=reasoning if isinstance(reasoning, str) else "")
            if piece.content or piece.reasoning:
                yield piece
        usage = chunk.get("usage")
        if isinstance(usage, dict):
            yield Usage(_count(usage.get("prompt_tokens")), _count(usage.get("completion_tokens")))


async def _ollama_events(lines: AsyncIterator[str]) -> AsyncIterator[Piece | Usage]:
    """The pieces and the usage in Ollama's lines of JSON."""
    async for line in lines:
        if not line.strip():
            continue
        chunk = _object(line)
        if "error" in chunk:
            raise RelayFailed("server_error", _detail(json.dumps(chunk)))
        message = chunk.get("message") if isinstance(chunk.get("message"), dict) else {}
        content, thinking = message.get("content"), message.get("thinking")
        piece = Piece(content=content if isinstance(content, str) else "",
                      reasoning=thinking if isinstance(thinking, str) else "")
        if piece.content or piece.reasoning:
            yield piece
        if chunk.get("done") is True:
            yield Usage(_count(chunk.get("prompt_eval_count")), _count(chunk.get("eval_count")))
            return


def _object(text: str) -> dict:
    """TEXT as a JSON object, raising RelayFailed as unexpected_answer when it
    is not one."""
    try:
        value = json.loads(text)
    except ValueError as e:
        raise RelayFailed("unexpected_answer") from e
    if not isinstance(value, dict):
        raise RelayFailed("unexpected_answer")
    return value


def _detail(text: str) -> str | None:
    """The server's words in an error's TEXT: its "error"'s "message", or its
    "error" when that is text, or else the text itself; at most
    DETAIL_LENGTH characters, and None when there are none."""
    try:
        body = json.loads(text)
    except ValueError:
        body = None
    if isinstance(body, dict):
        error = body.get("error")
        if isinstance(error, dict) and isinstance(error.get("message"), str):
            text = error["message"]
        elif isinstance(error, str):
            text = error
    text = text.strip()
    return text[:DETAIL_LENGTH] or None


def _count(value: Any) -> int | None:
    """VALUE when it is a count of tokens, None otherwise."""
    return value if isinstance(value, int) and not isinstance(value, bool) and value >= 0 else None
