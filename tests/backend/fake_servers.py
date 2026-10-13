"""Made-up model servers for the backend's tests, answering in the test's own
process through HTTPX's MockTransport; no request leaves it. Each answers as
the reads in dev/READING-LOG.md describe its kind: Ollama (R-002, R-018,
R-021), llama.cpp (R-003, R-019, R-022), and a plain OpenAI-compatible server
(R-006).

A server is chosen by the first part of the request's host name, such as
ollama in http://ollama.example.lan:11434.
"""

import asyncio
import json

import httpx

KEY = "made-up-server-key"


def sse(*chunks: dict) -> bytes:
    """CHUNKS as server-sent events, ending with data: [DONE]."""
    return b"".join(f"data: {json.dumps(c)}\n\n".encode() for c in chunks) + b"data: [DONE]\n\n"


def ndjson(*objects: dict) -> bytes:
    """OBJECTS as lines of JSON."""
    return b"".join(json.dumps(o).encode() + b"\n" for o in objects)


class Trickle(httpx.AsyncByteStream):
    """A streamed reply that sends one piece and then waits until GATE is set,
    which a test of stopping never does."""

    def __init__(self, gate: asyncio.Event):
        self.gate = gate

    async def __aiter__(self):
        yield b'data: {"choices": [{"delta": {"content": "Half"}}]}\n\n'
        await self.gate.wait()
        yield b"data: [DONE]\n\n"


class FakeServers:
    """The servers, and every request they received, in order."""

    def __init__(self):
        self.requests: list[httpx.Request] = []
        self.gate = asyncio.Event()

    def bodies(self, path: str) -> list[dict]:
        """The JSON bodies of the requests to PATH, in order."""
        return [json.loads(r.content) for r in self.requests if r.url.path == path]

    def transport(self) -> httpx.MockTransport:
        return httpx.MockTransport(self.handle)

    def handle(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        return getattr(self, request.url.host.split(".")[0])(request)

    def paths(self, host: str) -> list[str]:
        """The paths requested of the server on HOST, in order."""
        return [r.url.path for r in self.requests if r.url.host.startswith(host + ".")]

    # Ollama, with three models: one that chats and reads images, one that only
    # embeds, and one whose details carry no capabilities. It also serves the
    # OpenAI-compatible model list under /v1.
    def ollama(self, request: httpx.Request) -> httpx.Response:
        path = request.url.path
        if path == "/v1/models":
            return httpx.Response(200, json={"object": "list", "data": [
                {"id": name, "object": "model", "owned_by": "library"}
                for name in ("gemma4", "nomic-embed-text", "old-model")]})
        if path == "/api/version":
            return httpx.Response(200, json={"version": "0.12.6"})
        if path == "/api/tags":
            return httpx.Response(200, json={"models": [
                {"name": "gemma4", "model": "gemma4", "details": {"family": "gemma4"}},
                {"name": "nomic-embed-text", "model": "nomic-embed-text", "details": {}},
                {"name": "old-model", "model": "old-model", "details": {}},
            ]})
        if path == "/api/chat" and request.method == "POST":
            if json.loads(request.content)["model"] == "old-model":
                return httpx.Response(200, content=ndjson(
                    {"model": "old-model", "message": {"role": "assistant", "content": "Par"}, "done": False},
                    {"error": "an error was encountered while running the model"}))
            return httpx.Response(200, content=ndjson(
                {"model": "gemma4", "message": {"role": "assistant", "content": "", "thinking": "Thinking."},
                 "done": False},
                {"model": "gemma4", "message": {"role": "assistant", "content": "Hi"}, "done": False},
                {"model": "gemma4", "message": {"role": "assistant", "content": " there"}, "done": False},
                {"model": "gemma4", "message": {"role": "assistant", "content": ""}, "done": True,
                 "done_reason": "stop", "prompt_eval_count": 20, "eval_count": 3}))
        if path == "/api/show" and request.method == "POST":
            name = json.loads(request.content)["model"]
            capabilities = {"gemma4": ["completion", "thinking", "vision"],
                            "nomic-embed-text": ["embedding"]}.get(name)
            body = {"model_info": {"general.architecture": "gemma4", "gemma4.context_length": 131072}}
            if capabilities is not None:
                body["capabilities"] = capabilities
            return httpx.Response(200, json=body)
        return httpx.Response(404, json={"error": "not found"})

    # llama.cpp started with one model, which reads images, under /v1. It counts
    # a chat request as 100 tokens and 10 for each message, which no estimate
    # gives for the tests' messages.
    def llama(self, request: httpx.Request) -> httpx.Response:
        path = request.url.path
        if path == "/v1/chat/completions/input_tokens" and request.method == "POST":
            messages = json.loads(request.content)["messages"]
            return httpx.Response(200, json={"object": "response.input_tokens", "input_tokens": 100 + 10 * len(messages)})
        if path == "/v1/models":
            return httpx.Response(200, json={"object": "list", "data": [{
                "id": "../models/qwen3-4b-Q4_K_M.gguf", "object": "model", "owned_by": "llamacpp",
                "architecture": {"input_modalities": ["text", "image"], "output_modalities": ["text"]},
                "meta": {"n_ctx_train": 131072},
            }]})
        if path == "/props":
            return httpx.Response(200, json={"default_generation_settings": {"id": 0, "n_ctx": 8192},
                                             "total_slots": 1})
        if path == "/v1/chat/completions" and request.method == "POST":
            return httpx.Response(200, headers={"content-type": "text/event-stream"}, content=sse(
                {"object": "chat.completion.chunk", "choices": [{"index": 0, "delta": {"role": "assistant"}}]},
                {"object": "chat.completion.chunk", "choices": [{"index": 0, "delta": {"content": "Hel"}}]},
                {"object": "chat.completion.chunk", "choices": [{"index": 0, "delta": {"content": "lo"},
                                                                 "finish_reason": "stop"}]},
                {"object": "chat.completion.chunk", "choices": [],
                 "usage": {"prompt_tokens": 12, "completion_tokens": 2, "total_tokens": 14}}))
        return httpx.Response(404, text="File Not Found")

    # llama.cpp with one model whose replies carry its reasoning first, in
    # reasoning_content (R-022).
    def thinker(self, request: httpx.Request) -> httpx.Response:
        if request.url.path == "/v1/models":
            return httpx.Response(200, json={"object": "list", "data": [{"id": "thinking-model", "object": "model"}]})
        if request.url.path == "/v1/chat/completions":
            return httpx.Response(200, headers={"content-type": "text/event-stream"}, content=sse(
                {"object": "chat.completion.chunk", "choices": [{"index": 0, "delta": {"reasoning_content": "Plan"}}]},
                {"object": "chat.completion.chunk", "choices": [{"index": 0, "delta": {"reasoning_content": " it."}}]},
                {"object": "chat.completion.chunk", "choices": [{"index": 0, "delta": {"content": "Done"},
                                                                 "finish_reason": "stop"}]}))
        return httpx.Response(404, text="File Not Found")

    # An OpenAI-compatible server whose one model fails every chat.
    def crash(self, request: httpx.Request) -> httpx.Response:
        if request.url.path == "/v1/models":
            return httpx.Response(200, json={"object": "list", "data": [{"id": "broken-model", "object": "model"}]})
        if request.url.path == "/v1/chat/completions":
            return httpx.Response(500, json={"error": {"message": "model crashed", "type": "server_error"}})
        return httpx.Response(404)

    # An OpenAI-compatible server whose replies send one piece and then wait.
    def trickle(self, request: httpx.Request) -> httpx.Response:
        if request.url.path == "/v1/models":
            return httpx.Response(200, json={"object": "list", "data": [{"id": "slow-model", "object": "model"}]})
        if request.url.path == "/v1/chat/completions":
            return httpx.Response(200, headers={"content-type": "text/event-stream"}, stream=Trickle(self.gate))
        return httpx.Response(404)

    # llama.cpp started as a router, listing two models; /props must not be asked.
    def router(self, request: httpx.Request) -> httpx.Response:
        if request.url.path == "/v1/models":
            return httpx.Response(200, json={"object": "list", "data": [
                {"id": "a", "object": "model", "architecture": {"input_modalities": ["text"]}},
                {"id": "b", "object": "model", "architecture": {"input_modalities": ["text", "image"]}},
            ]})
        if request.url.path == "/props":
            return httpx.Response(200, json={"default_generation_settings": {"n_ctx": 4096}})
        return httpx.Response(404)

    # A plain OpenAI-compatible server, saying nothing of what its models do.
    def openai(self, request: httpx.Request) -> httpx.Response:
        if request.url.path == "/v1/models":
            return httpx.Response(200, json={"object": "list", "data": [
                {"id": "whisper-1", "object": "model", "owned_by": "gateway"},
                {"id": "qwen3-4b", "object": "model", "owned_by": "gateway"},
            ]})
        return httpx.Response(404, json={"error": {"message": "not found", "type": "invalid_request_error"}})

    # An OpenAI-compatible server that answers only with the bearer token KEY.
    def locked(self, request: httpx.Request) -> httpx.Response:
        if request.headers.get("authorization") != f"Bearer {KEY}":
            return httpx.Response(401, json={"error": {"message": "Incorrect API key provided"}})
        return self.openai(request)

    def down(self, request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("connection refused", request=request)

    def slow(self, request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("timed out", request=request)

    # A web server that is not a model server.
    def web(self, request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, text="<html><body>It works</body></html>",
                              headers={"content-type": "text/html"})

    # A server whose model list has an entry with no id.
    def broken(self, request: httpx.Request) -> httpx.Response:
        if request.url.path == "/v1/models":
            return httpx.Response(200, json={"object": "list", "data": [{"object": "model"}]})
        return httpx.Response(404)
