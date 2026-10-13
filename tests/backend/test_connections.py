"""Tests of the connections: encrypting their keys, checking servers, the
endpoints, and the scheduled refresh. The model servers are the made-up ones
of fake_servers.py, in the test's own process; no request leaves it. KeysTest
and ServersTest need no database; the rest run against the database the
configuration in AICONMAN_CONFIG_DIR names, rebuilt before each test.

    AICONMAN_CONFIG_DIR=.tmp/scratch/config .venv/bin/python -m unittest discover -s tests/backend -p 'test_connections.py'
"""

import dataclasses
import os
import subprocess
import unittest
from unittest import mock
from urllib.parse import urlsplit

import httpx

import scratch
from aiconman import config as configuration
from aiconman import keys, passwords, servers
from aiconman.app import create_app
from aiconman.refresh import refresh
from fake_servers import KEY, FakeServers

STRONG = "Correct-Horse-42-Battery!"


class KeysTest(unittest.TestCase):
    def test_a_key_comes_back_as_it_went_in(self):
        self.assertEqual(keys.decrypt("secret", keys.encrypt("secret", "sk-made-up")), "sk-made-up")

    def test_the_same_key_encrypts_differently_each_time(self):
        self.assertNotEqual(keys.encrypt("secret", "sk-made-up"), keys.encrypt("secret", "sk-made-up"))

    def test_the_stored_bytes_do_not_hold_the_key(self):
        self.assertNotIn(b"sk-made-up", keys.encrypt("secret", "sk-made-up"))

    def test_another_secret_does_not_open_it(self):
        with self.assertRaises(keys.UndecryptableKey):
            keys.decrypt("another secret", keys.encrypt("secret", "sk-made-up"))

    def test_damaged_bytes_do_not_open(self):
        stored = bytearray(keys.encrypt("secret", "sk-made-up"))
        stored[-1] ^= 1
        with self.assertRaises(keys.UndecryptableKey):
            keys.decrypt("secret", bytes(stored))
        with self.assertRaises(keys.UndecryptableKey):
            keys.decrypt("secret", b"\x02" + bytes(stored[1:]))


class ServersTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.fakes = FakeServers()
        self.http = servers.client(self.fakes.transport())
        self.addAsyncCleanup(self.http.aclose)

    async def check(self, base_url: str, protocol: str | None = None, api_key: str | None = None,
                    connect: int = 60, answer: int = 300):
        return await servers.check(self.http, base_url, protocol, api_key, connect, answer)

    def model(self, result, name: str) -> dict:
        return next(m for m in result.models if m["name"] == name)

    async def test_ollama_is_detected_and_its_capabilities_read(self):
        result = await self.check("http://ollama.example.lan:11434")
        self.assertEqual((result.detected, result.error), ("ollama", None))
        self.assertEqual(self.model(result, "gemma4"),
                         {"name": "gemma4", "chat": True, "images": True, "speech": False, "context": None,
                          "counts": False})
        self.assertEqual(self.model(result, "nomic-embed-text")["chat"], False)
        self.assertEqual((self.model(result, "old-model")["chat"], self.model(result, "old-model")["images"]),
                         (None, None))

    async def test_ollama_given_with_v1_answers_as_openai_compatible(self):
        result = await self.check("http://ollama.example.lan:11434/v1")
        self.assertEqual((result.detected, result.error), ("openai", None))
        self.assertTrue(all(m["chat"] is None for m in result.models))

    async def test_llama_cpp_is_detected_as_openai_with_its_images_and_slot_window(self):
        result = await self.check("http://llama.example.lan:8080/v1/")
        self.assertEqual((result.detected, result.error), ("openai", None))
        self.assertEqual(result.models, [{"name": "../models/qwen3-4b-Q4_K_M.gguf", "chat": None,
                                          "images": True, "speech": None, "context": 8192, "counts": True}])
        self.assertEqual(self.fakes.paths("llama"), ["/v1/api/version", "/v1/models", "/v1/models", "/props",
                                                     "/v1/chat/completions/input_tokens"])

    async def test_a_plain_openai_server_gives_names_only(self):
        result = await self.check("http://openai.example.lan/v1")
        self.assertEqual([m["name"] for m in result.models], ["whisper-1", "qwen3-4b"])
        self.assertTrue(all(m["chat"] is None and m["images"] is None and m["context"] is None
                            and m["counts"] is False for m in result.models))

    async def test_a_single_model_that_does_not_count_tokens(self):
        result = await self.check("http://crash.example.lan/v1")
        self.assertEqual([(m["name"], m["counts"]) for m in result.models], [("broken-model", False)])
        self.assertIn("/v1/chat/completions/input_tokens", self.fakes.paths("crash"))

    async def test_a_server_listing_several_models_is_not_asked_for_props_or_a_count(self):
        result = await self.check("http://router.example.lan/v1")
        self.assertEqual([m["images"] for m in result.models], [False, True])
        self.assertEqual(self.fakes.paths("router"), ["/v1/api/version", "/v1/models", "/v1/models"])

    async def test_a_protocol_given_is_not_detected(self):
        result = await self.check("http://llama.example.lan:8080/v1", protocol="openai")
        self.assertEqual((result.detected, result.error), (None, None))
        self.assertNotIn("/v1/api/version", self.fakes.paths("llama"))

    async def test_the_key_is_sent_as_a_bearer_token(self):
        self.assertEqual((await self.check("http://locked.example.lan/v1", api_key=KEY)).error, None)
        self.assertEqual((await self.check("http://locked.example.lan/v1")).error, "unauthorized")
        self.assertEqual((await self.check("http://locked.example.lan/v1", api_key="wrong")).error, "unauthorized")

    async def test_every_request_carries_the_connections_timeouts(self):
        await self.check("http://ollama.example.lan:11434", connect=5, answer=7)
        timeouts = {tuple(sorted(r.extensions["timeout"].items())) for r in self.fakes.requests}
        self.assertEqual(timeouts, {(("connect", 5.0), ("pool", 7.0), ("read", 7.0), ("write", 7.0))})
        self.assertEqual(len(self.fakes.requests), 5)

    async def test_an_address_that_is_not_one_is_refused_before_any_request(self):
        for base_url in ("ftp://box.example.lan", "box.example.lan:11434", "http://", "http://box example.lan"):
            self.assertEqual((await self.check(base_url)).error, "base_url_invalid", base_url)
        self.assertEqual(self.fakes.requests, [])

    async def test_failures_are_named(self):
        self.assertEqual((await self.check("http://down.example.lan")).error, "unreachable")
        self.assertEqual((await self.check("http://slow.example.lan")).error, "timed_out")
        self.assertEqual((await self.check("http://web.example.lan")).error, "unexpected_answer")
        self.assertEqual((await self.check("http://broken.example.lan/v1")).error, "unexpected_answer")
        self.assertEqual((await self.check("http://openai.example.lan")).error, "not_recognized")
        self.assertEqual((await self.check("http://openai.example.lan/v1", protocol="ollama")).error, "http_404")


class ConnectionsTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        scratch.rebuild()
        patcher = mock.patch.object(passwords, "N", 2**10)
        patcher.start()
        self.addCleanup(patcher.stop)

    async def asyncSetUp(self):
        self.config = configuration.load()
        self.fakes = FakeServers()
        self.app = self.make_app(self.config)
        public = urlsplit(self.config.server.public_url)
        self.origin = f"{public.scheme}://{public.netloc}"
        self.alex = await self.signed_up("alex")
        self.sam = await self.signed_up("sam")

    def make_app(self, config):
        app = create_app(config)
        app.state.server_transport = self.fakes.transport()
        return app

    def browser(self, app=None) -> httpx.AsyncClient:
        client = httpx.AsyncClient(transport=httpx.ASGITransport(app=app or self.app),
                                   base_url=self.config.server.public_url, headers={"Origin": self.origin})
        self.addAsyncCleanup(client.aclose)
        return client

    async def signed_up(self, username: str) -> httpx.AsyncClient:
        client = self.browser()
        response = await client.post("/api/auth/sign-up", json={"username": username, "password": STRONG})
        self.assertEqual(response.status_code, 200, response.text)
        return client

    async def add(self, name: str, base_url: str, api_key: str | None = None, client=None) -> int:
        response = await (client or self.alex).post("/api/admin/connections",
                                                    json={"name": name, "base_url": base_url, "api_key": api_key})
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["connection_id"]

    def assertRefused(self, response: httpx.Response, status: int, key: str):
        self.assertEqual((response.status_code, response.json().get("error")), (status, key), response.text)

    async def test_the_admin_adds_and_checks_a_connection_and_members_see_its_models(self):
        ollama = await self.add("box", "http://ollama.example.lan:11434")
        response = await self.alex.post(f"/api/admin/connections/{ollama}/check")
        self.assertEqual(response.status_code, 200, response.text)
        checked = response.json()
        self.assertEqual((checked["connection"]["detected_protocol"], checked["connection"]["check_error"],
                          checked["connection"]["models_found"]), ("ollama", None, 3))
        models = {m["name"]: m for m in (await self.sam.get("/api/models")).json()}
        self.assertEqual(sorted(models), ["gemma4", "nomic-embed-text", "old-model"])
        self.assertEqual((models["gemma4"]["chat"], models["gemma4"]["images"], models["gemma4"]["connection_name"]),
                         (True, True, "box"))
        self.assertIsNone(models["gemma4"]["context"])

    async def test_a_key_is_stored_encrypted_never_returned_and_sent_to_its_server(self):
        locked = await self.add("gateway", "http://locked.example.lan/v1", f"  {KEY}\n")
        listing = await self.alex.get("/api/admin/connections")
        self.assertTrue(listing.json()[0]["has_key"])
        checked = await self.alex.post(f"/api/admin/connections/{locked}/check")
        self.assertIsNone(checked.json()["connection"]["check_error"])
        for response in (listing, checked, await self.alex.get(f"/api/admin/connections/{locked}/models"),
                         await self.sam.get("/api/models")):
            self.assertNotIn(KEY, response.text)
        stored = bytes(scratch.owner_query("SELECT api_key FROM connections WHERE connection_id = %s", locked)[0][0])
        self.assertNotIn(KEY.encode(), stored)
        self.assertEqual(keys.decrypt(self.config.encryption_key, stored), KEY)
        await self.alex.put(f"/api/admin/connections/{locked}/key", json={"api_key": None})
        checked = await self.alex.post(f"/api/admin/connections/{locked}/check")
        self.assertEqual(checked.json()["connection"]["check_error"], "unauthorized")
        self.assertFalse(checked.json()["connection"]["has_key"])

    async def test_a_key_the_configured_secret_no_longer_opens(self):
        locked = await self.add("gateway", "http://locked.example.lan/v1", KEY)
        changed = self.browser(self.make_app(dataclasses.replace(self.config, encryption_key="another secret")))
        await changed.post("/api/auth/sign-in", json={"username": "alex", "password": STRONG})
        checked = await changed.post(f"/api/admin/connections/{locked}/check")
        self.assertEqual(checked.json()["connection"]["check_error"], "key_undecryptable")

    async def test_checking_every_connection_at_once(self):
        llama = await self.add("pi", "http://llama.example.lan:8080/v1")
        down = await self.add("old pi", "http://down.example.lan:8080/v1")
        response = await self.alex.post("/api/admin/connections/check-all")
        self.assertEqual(response.status_code, 200, response.text)
        results = {c["connection_id"]: c for c in response.json()}
        self.assertEqual((results[llama]["check_error"], results[llama]["models_found"]), (None, 1))
        self.assertEqual(results[down]["check_error"], "unreachable")
        model = (await self.sam.get("/api/models")).json()[0]
        self.assertEqual((model["images"], model["context"]), (True, 8192))

    async def test_the_admin_sets_what_a_model_can_do_and_its_window(self):
        ollama = await self.add("box", "http://ollama.example.lan:11434")
        await self.alex.post(f"/api/admin/connections/{ollama}/check")
        gemma = next(m for m in (await self.alex.get(f"/api/admin/connections/{ollama}/models")).json()
                     if m["name"] == "gemma4")
        response = await self.alex.put(f"/api/admin/models/{gemma['model_id']}", json={"context": 4096})
        self.assertEqual(response.status_code, 200, response.text)
        seen = next(m for m in (await self.sam.get("/api/models")).json() if m["name"] == "gemma4")
        self.assertEqual(seen["context"], 4096)
        self.assertRefused(await self.alex.put(f"/api/admin/models/{gemma['model_id']}", json={"context": 0}),
                           400, "context_invalid")

    async def test_changing_and_removing_a_connection(self):
        llama = await self.add("pi", "http://llama.example.lan:8080/v1")
        await self.alex.post(f"/api/admin/connections/{llama}/check")
        response = await self.alex.put(f"/api/admin/connections/{llama}",
                                       json={"name": "pi 5", "base_url": "http://llama.example.lan:8080/v1",
                                             "connect_timeout": 90, "answer_timeout": 600})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual((await self.sam.get("/api/models")).json()[0]["connection_name"], "pi 5")
        listed = (await self.alex.get("/api/admin/connections")).json()[0]
        self.assertEqual((listed["connect_timeout"], listed["answer_timeout"]), (90, 600))
        self.assertRefused(await self.alex.put(f"/api/admin/connections/{llama}",
                                               json={"name": "pi 5", "base_url": "http://x.example.lan",
                                                     "protocol": "vllm", "connect_timeout": 90,
                                                     "answer_timeout": 600}), 400, "protocol_invalid")
        response = await self.alex.put(f"/api/admin/connections/{llama}",
                                       json={"name": "pi 5", "base_url": "http://llama.example.lan:8080/v1"})
        self.assertRefused(response, 400, "request_invalid")
        self.assertEqual(response.json()["fields"], ["answer_timeout", "connect_timeout"])
        self.assertRefused(await self.alex.post("/api/admin/connections",
                                                json={"name": "pi 5", "base_url": "http://y.example.lan"}),
                           409, "name_taken")
        await self.alex.delete(f"/api/admin/connections/{llama}")
        self.assertEqual((await self.sam.get("/api/models")).json(), [])

    async def test_timeouts_default_are_set_by_the_admin_and_used_by_the_check(self):
        defaults = await self.alex.get("/api/admin/connections/defaults")
        self.assertEqual(defaults.json(), {"connect_timeout": 60, "answer_timeout": 300})
        await self.add("pi", "http://llama.example.lan:8080/v1")
        listed = (await self.alex.get("/api/admin/connections")).json()[0]
        self.assertEqual((listed["connect_timeout"], listed["answer_timeout"]), (60, 300))
        response = await self.alex.post("/api/admin/connections", json={
            "name": "slow pi", "base_url": "http://ollama.example.lan:11434",
            "connect_timeout": 120, "answer_timeout": 1800})
        slow = response.json()["connection_id"]
        await self.alex.post(f"/api/admin/connections/{slow}/check")
        sent = {r.extensions["timeout"]["connect"] for r in self.fakes.requests if r.url.host.startswith("ollama.")}
        self.assertEqual(sent, {120.0})
        self.assertRefused(await self.alex.post("/api/admin/connections", json={
            "name": "x", "base_url": "http://x.example.lan", "connect_timeout": 0}), 400, "connect_timeout_invalid")

    async def test_checking_values_not_saved_yet(self):
        response = await self.alex.post("/api/admin/connections/try",
                                        json={"base_url": "http://ollama.example.lan:11434"})
        self.assertEqual(response.status_code, 200, response.text)
        tried = response.json()
        self.assertEqual((tried["detected"], tried["error"], len(tried["models"])), ("ollama", None, 3))
        self.assertEqual((await self.alex.get("/api/admin/connections")).json(), [])
        self.assertEqual((await self.alex.post("/api/admin/connections/try",
                                               json={"base_url": "http://locked.example.lan/v1"})).json()["error"],
                         "unauthorized")
        typed = await self.alex.post("/api/admin/connections/try",
                                     json={"base_url": "http://locked.example.lan/v1", "api_key": f" {KEY} "})
        self.assertIsNone(typed.json()["error"])
        self.assertEqual((await self.alex.post("/api/admin/connections/try",
                                               json={"base_url": "nonsense"})).json()["error"], "base_url_invalid")
        self.assertRefused(await self.alex.post("/api/admin/connections/try",
                                                json={"base_url": "http://x.example.lan", "answer_timeout": 0}),
                           400, "answer_timeout_invalid")

    async def test_checking_an_edit_before_saving_it_uses_the_saved_key(self):
        locked = await self.add("gateway", "http://openai.example.lan/v1", KEY)
        response = await self.alex.post("/api/admin/connections/try", json={
            "base_url": "http://locked.example.lan/v1", "connection_id": locked})
        self.assertIsNone(response.json()["error"])
        self.assertNotIn(KEY, response.text)
        response = await self.alex.post("/api/admin/connections/try", json={
            "base_url": "http://locked.example.lan/v1", "connection_id": locked, "api_key": "a-new-key"})
        self.assertEqual(response.json()["error"], "unauthorized")
        listed = (await self.alex.get("/api/admin/connections")).json()[0]
        self.assertEqual((listed["base_url"], listed["checked_at"]), ("http://openai.example.lan/v1", None))

    async def test_a_member_cannot_administer_connections(self):
        llama = await self.add("pi", "http://llama.example.lan:8080/v1")
        self.assertRefused(await self.sam.get("/api/admin/connections"), 403, "not_admin")
        self.assertRefused(await self.sam.post("/api/admin/connections",
                                               json={"name": "x", "base_url": "http://x.example.lan"}),
                           403, "not_admin")
        self.assertRefused(await self.sam.post(f"/api/admin/connections/{llama}/check"), 403, "not_admin")
        self.assertRefused(await self.sam.post("/api/admin/connections/check-all"), 403, "not_admin")
        self.assertRefused(await self.sam.post("/api/admin/connections/try",
                                               json={"base_url": "http://llama.example.lan:8080/v1"}),
                           403, "not_admin")
        self.assertRefused(await self.sam.get("/api/admin/connections/defaults"), 403, "not_admin")
        self.assertNotIn("/v1/models", [r.url.path for r in self.fakes.requests])
        self.assertRefused(await self.browser().get("/api/models"), 401, "session_invalid")

    async def test_the_scheduled_refresh_checks_every_connection_with_no_session(self):
        llama = await self.add("pi", "http://llama.example.lan:8080/v1")
        ollama = await self.add("box", "http://ollama.example.lan:11434")
        down = await self.add("old pi", "http://down.example.lan:8080/v1")
        self.assertEqual(await refresh(self.config, self.fakes.transport()), 3)
        results = {c["connection_id"]: c for c in (await self.alex.get("/api/admin/connections")).json()}
        self.assertEqual((results[llama]["models_found"], results[ollama]["models_found"]), (1, 3))
        self.assertEqual(results[ollama]["detected_protocol"], "ollama")
        self.assertEqual(results[down]["check_error"], "unreachable")
        self.assertTrue(all(c["checked_at"] is not None for c in results.values()))


class RefreshScriptTest(unittest.TestCase):
    def test_the_script_runs_the_refresh_quietly(self):
        scratch.require()
        scratch.rebuild()
        result = subprocess.run([str(scratch.ROOT / "install" / "refresh_models.sh")], capture_output=True,
                                text=True, env={**os.environ})
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))


def setUpModule():
    scratch.require()


if __name__ == "__main__":
    unittest.main()
