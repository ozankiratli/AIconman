"""Made-up model servers for the backend's tests, answering in the test's own
process through HTTPX's MockTransport; no request leaves it. Each answers as
the reads in dev/READING-LOG.md describe its kind: Ollama (R-002, R-018,
R-021), llama.cpp (R-003, R-019), and a plain OpenAI-compatible server (R-006).

A server is chosen by the first part of the request's host name, such as
ollama in http://ollama.example.lan:11434.
"""

import json

import httpx

KEY = "made-up-server-key"


class FakeServers:
    """The servers, and every request they received, in order."""

    def __init__(self):
        self.requests: list[httpx.Request] = []

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
        if path == "/api/show" and request.method == "POST":
            name = json.loads(request.content)["model"]
            capabilities = {"gemma4": ["completion", "thinking", "vision"],
                            "nomic-embed-text": ["embedding"]}.get(name)
            body = {"model_info": {"general.architecture": "gemma4", "gemma4.context_length": 131072}}
            if capabilities is not None:
                body["capabilities"] = capabilities
            return httpx.Response(200, json=body)
        return httpx.Response(404, json={"error": "not found"})

    # llama.cpp started with one model, which reads images, under /v1.
    def llama(self, request: httpx.Request) -> httpx.Response:
        path = request.url.path
        if path == "/v1/models":
            return httpx.Response(200, json={"object": "list", "data": [{
                "id": "../models/qwen3-4b-Q4_K_M.gguf", "object": "model", "owned_by": "llamacpp",
                "architecture": {"input_modalities": ["text", "image"], "output_modalities": ["text"]},
                "meta": {"n_ctx_train": 131072},
            }]})
        if path == "/props":
            return httpx.Response(200, json={"default_generation_settings": {"id": 0, "n_ctx": 8192},
                                             "total_slots": 1})
        return httpx.Response(404, text="File Not Found")

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
