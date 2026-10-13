"""Tests of the conversations and their replies, against the database the
configuration in LMCONMAN_CONFIG_DIR names, rebuilt before each test, and the
made-up model servers of fake_servers.py, in the test's own process; no request
leaves it.

    LMCONMAN_CONFIG_DIR=.tmp/scratch/config .venv/bin/python -m unittest discover -s tests/backend -p 'test_chat.py'
"""

import asyncio
import json
import unittest
from types import SimpleNamespace
from unittest import mock
from urllib.parse import urlsplit

import httpx

import scratch
from lmconman import config as configuration
from lmconman import conversations, passwords, sessions
from lmconman.app import create_app
from lmconman.db import call, connect
from fake_servers import KEY, FakeServers

STRONG = "Correct-Horse-42-Battery!"


def setUpModule():
    scratch.require()


def events(response: httpx.Response) -> list[tuple[str, dict]]:
    """The server-sent events of RESPONSE, as names and data."""
    found = []
    for block in response.text.split("\n\n"):
        lines = dict(line.split(": ", 1) for line in block.splitlines() if ": " in line)
        if "event" in lines:
            found.append((lines["event"], json.loads(lines["data"])))
    return found


class ChatTest(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        scratch.rebuild()
        patcher = mock.patch.object(passwords, "N", 2**10)
        patcher.start()
        self.addCleanup(patcher.stop)

    async def asyncSetUp(self):
        self.config = configuration.load()
        self.fakes = FakeServers()
        self.app = create_app(self.config)
        self.app.state.server_transport = self.fakes.transport()
        public = urlsplit(self.config.server.public_url)
        self.origin = f"{public.scheme}://{public.netloc}"
        self.alex = await self.signed_up("alex")
        self.sam = await self.signed_up("sam")
        self.connections = {}
        for name, base_url in (("pi", "http://llama.example.lan:8080/v1"), ("box", "http://ollama.example.lan:11434"),
                               ("crash", "http://crash.example.lan/v1"), ("slow", "http://trickle.example.lan/v1")):
            response = await self.alex.post("/api/admin/connections", json={"name": name, "base_url": base_url})
            self.connections[name] = response.json()["connection_id"]
        await self.alex.post("/api/admin/connections/check-all")
        self.models = {m["name"]: m["model_id"] for m in (await self.alex.get("/api/models")).json()}
        self.qwen = self.models["../models/qwen3-4b-Q4_K_M.gguf"]

    def browser(self) -> httpx.AsyncClient:
        client = httpx.AsyncClient(transport=httpx.ASGITransport(app=self.app),
                                   base_url=self.config.server.public_url, headers={"Origin": self.origin})
        self.addAsyncCleanup(client.aclose)
        return client

    async def signed_up(self, username: str) -> httpx.AsyncClient:
        client = self.browser()
        response = await client.post("/api/auth/sign-up", json={"username": username, "password": STRONG})
        self.assertEqual(response.status_code, 200, response.text)
        return client

    async def conversation(self, model_id: int | None, title: str = "") -> int:
        response = await self.alex.post("/api/conversations", json={"title": title, "model_id": model_id})
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["conversation_id"]

    async def send(self, conversation_id: int, content: str, parent_id: int | None = None) -> list:
        response = await self.alex.post(f"/api/conversations/{conversation_id}/messages",
                                        json={"content": content, "parent_id": parent_id})
        self.assertEqual(response.status_code, 200, response.text)
        return events(response)

    async def path(self, conversation_id: int) -> list[dict]:
        return (await self.alex.get(f"/api/conversations/{conversation_id}/messages")).json()

    def assertRefused(self, response: httpx.Response, status: int, key: str):
        self.assertEqual((response.status_code, response.json().get("error")), (status, key), response.text)

    async def test_a_conversation_and_its_settings(self):
        chat = await self.conversation(self.qwen, "Trip")
        self.assertEqual([c["conversation_id"] for c in (await self.alex.get("/api/conversations")).json()], [chat])
        renamed = await self.alex.put(f"/api/conversations/{chat}/title", json={"title": "Trip to Lisbon"})
        self.assertEqual(renamed.json()["title"], "Trip to Lisbon")
        settings = await self.alex.put(f"/api/conversations/{chat}/settings",
                                       json={"system_prompt": "Answer briefly.", "output_limit": 256})
        self.assertEqual((settings.json()["system_prompt"], settings.json()["output_limit"]),
                         ("Answer briefly.", 256))
        switched = await self.alex.put(f"/api/conversations/{chat}/model", json={"model_id": self.models["gemma4"]})
        self.assertEqual((switched.json()["model_name"], switched.json()["connection_name"]), ("gemma4", "box"))
        self.assertRefused(await self.sam.get(f"/api/conversations/{chat}"), 404, "no_such_conversation")
        self.assertEqual((await self.alex.delete(f"/api/conversations/{chat}")).json(), {"deleted": chat})
        self.assertEqual((await self.alex.get("/api/conversations")).json(), [])

    async def test_sending_a_message_streams_the_reply_and_stores_it(self):
        chat = await self.conversation(self.qwen)
        streamed = await self.send(chat, "Plan a trip\nto Lisbon, please")
        names = [name for name, _ in streamed]
        self.assertEqual(names, ["user", "delta", "delta", "done"])
        self.assertEqual("".join(data["content"] for name, data in streamed if name == "delta"), "Hello")
        done = streamed[-1][1]
        self.assertEqual((done["state"], done["prompt_tokens"], done["completion_tokens"]), ("complete", 12, 2))
        user, answer = await self.path(chat)
        self.assertEqual((user["message_id"], user["content"]), (streamed[0][1]["message_id"], "Plan a trip\nto Lisbon, please"))
        self.assertEqual((answer["message_id"], answer["content"], answer["model_name"], answer["connection_name"]),
                         (done["message_id"], "Hello", "../models/qwen3-4b-Q4_K_M.gguf", "pi"))
        self.assertEqual((await self.alex.get(f"/api/conversations/{chat}")).json()["title"], "Plan a trip")
        sent = self.fakes.bodies("/v1/chat/completions")[0]
        self.assertEqual(sent, {"model": "../models/qwen3-4b-Q4_K_M.gguf", "stream": True,
                                "stream_options": {"include_usage": True},
                                "messages": [{"role": "user", "content": "Plan a trip\nto Lisbon, please"}]})

    async def test_the_system_prompt_the_history_and_the_output_limit_are_sent(self):
        chat = await self.conversation(self.qwen, "Kept")
        await self.alex.put(f"/api/conversations/{chat}/settings",
                            json={"system_prompt": "Answer briefly.", "output_limit": 256})
        first = await self.send(chat, "One")
        await self.send(chat, "Two", parent_id=first[-1][1]["message_id"])
        sent = self.fakes.bodies("/v1/chat/completions")[1]
        self.assertEqual(sent["messages"], [{"role": "system", "content": "Answer briefly."},
                                            {"role": "user", "content": "One"},
                                            {"role": "assistant", "content": "Hello"},
                                            {"role": "user", "content": "Two"}])
        self.assertEqual(sent["max_completion_tokens"], 256)
        self.assertEqual((await self.alex.get(f"/api/conversations/{chat}")).json()["title"], "Kept")

    async def test_ollamas_reasoning_and_the_window_the_admin_sets(self):
        chat = await self.conversation(self.models["gemma4"])
        streamed = await self.send(chat, "Hello")
        self.assertEqual(streamed[1], ("delta", {"content": "", "reasoning": "Thinking."}))
        answer = (await self.path(chat))[-1]
        self.assertEqual((answer["content"], answer["reasoning"], answer["prompt_tokens"], answer["completion_tokens"]),
                         ("Hi there", "Thinking.", 20, 3))
        self.assertNotIn("options", self.fakes.bodies("/api/chat")[0])
        await self.alex.put(f"/api/admin/models/{self.models['gemma4']}", json={"context": 8192})
        await self.alex.put(f"/api/conversations/{chat}/settings", json={"system_prompt": "", "output_limit": 100})
        await self.send(chat, "Again", parent_id=answer["message_id"])
        self.assertEqual(self.fakes.bodies("/api/chat")[1]["options"], {"num_ctx": 8192, "num_predict": 100})

    async def test_a_server_error_is_a_failed_reply_left_out_of_what_follows(self):
        chat = await self.conversation(self.models["broken-model"])
        streamed = await self.send(chat, "Hello")
        self.assertEqual(streamed[-1][0], "failed")
        self.assertEqual(streamed[-1][1]["error"], "http_500: model crashed")
        failed = (await self.path(chat))[-1]
        self.assertEqual((failed["state"], failed["error"], failed["content"]), ("failed", "http_500: model crashed", ""))
        await self.alex.put(f"/api/conversations/{chat}/model", json={"model_id": self.qwen})
        await self.send(chat, "Try again", parent_id=failed["message_id"])
        self.assertEqual(self.fakes.bodies("/v1/chat/completions")[-1]["messages"],
                         [{"role": "user", "content": "Hello"}, {"role": "user", "content": "Try again"}])

    async def test_an_error_partway_keeps_what_arrived(self):
        chat = await self.conversation(self.models["old-model"])
        streamed = await self.send(chat, "Hello")
        self.assertEqual([name for name, _ in streamed], ["user", "delta", "failed"])
        failed = (await self.path(chat))[-1]
        self.assertEqual((failed["state"], failed["content"], failed["error"]),
                         ("failed", "Par", "server_error: an error was encountered while running the model"))

    async def test_a_server_that_does_not_answer(self):
        chat = await self.conversation(self.qwen)
        await self.alex.put(f"/api/admin/connections/{self.connections['pi']}",
                            json={"name": "pi", "base_url": "http://down.example.lan:8080/v1",
                                  "connect_timeout": 60, "answer_timeout": 300})
        streamed = await self.send(chat, "Hello")
        self.assertEqual(streamed[-1][1]["error"], "unreachable")

    async def test_regenerating_keeps_the_earlier_reply(self):
        chat = await self.conversation(self.qwen)
        first = await self.send(chat, "Hello")
        user_id, reply_id = first[0][1]["message_id"], first[-1][1]["message_id"]
        response = await self.alex.post(f"/api/conversations/{chat}/regenerate", json={"parent_id": user_id})
        again = events(response)
        self.assertEqual([name for name, _ in again], ["delta", "delta", "done"])
        path = await self.path(chat)
        self.assertEqual([m["message_id"] for m in path], [user_id, again[-1][1]["message_id"]])
        self.assertEqual((path[-1]["version"], path[-1]["versions"]), (2, 2))
        self.assertEqual(self.fakes.bodies("/v1/chat/completions")[-1]["messages"],
                         [{"role": "user", "content": "Hello"}])
        self.assertRefused(await self.alex.post(f"/api/conversations/{chat}/regenerate", json={"parent_id": reply_id}),
                           400, "parent_invalid")
        chosen = await self.alex.post(f"/api/messages/{reply_id}/choose")
        self.assertEqual(chosen.json(), {"leaf_id": reply_id})
        self.assertEqual([m["message_id"] for m in await self.path(chat)], [user_id, reply_id])

    async def test_editing_a_message_sends_another_in_its_place(self):
        chat = await self.conversation(self.qwen)
        first = await self.send(chat, "One")
        second = await self.send(chat, "Two", parent_id=first[-1][1]["message_id"])
        edited = await self.send(chat, "Two, edited", parent_id=first[-1][1]["message_id"])
        path = await self.path(chat)
        self.assertEqual([m["content"] for m in path], ["One", "Hello", "Two, edited", "Hello"])
        self.assertEqual((path[2]["version"], path[2]["versions"]), (2, 2))
        self.assertNotEqual(edited[0][1]["message_id"], second[0][1]["message_id"])
        self.assertEqual(self.fakes.bodies("/v1/chat/completions")[-1]["messages"][-1],
                         {"role": "user", "content": "Two, edited"})

    async def test_nothing_is_added_without_a_usable_model(self):
        chat = await self.conversation(None)
        self.assertRefused(await self.alex.post(f"/api/conversations/{chat}/messages", json={"content": "Hi"}),
                           400, "no_model")
        gone = await self.conversation(self.models["gemma4"])
        await self.alex.put(f"/api/admin/connections/{self.connections['box']}",
                            json={"name": "box", "base_url": "http://openai.example.lan/v1",
                                  "connect_timeout": 60, "answer_timeout": 300})
        checked = await self.alex.post(f"/api/admin/connections/{self.connections['box']}/check")
        self.assertIsNone(checked.json()["connection"]["check_error"])
        self.assertRefused(await self.alex.post(f"/api/conversations/{gone}/messages", json={"content": "Hi"}),
                           400, "model_unavailable")
        self.assertEqual((await self.path(chat), await self.path(gone)), ([], []))

    async def test_another_person_cannot_send_to_a_conversation(self):
        chat = await self.conversation(self.qwen)
        self.assertRefused(await self.sam.post(f"/api/conversations/{chat}/messages", json={"content": "Hi"}),
                           404, "no_such_conversation")
        self.assertRefused(await self.sam.post(f"/api/conversations/{chat}/regenerate", json={"parent_id": 1}),
                           404, "no_such_conversation")

    async def test_an_openai_compatible_servers_reasoning(self):
        think = await self.alex.post("/api/admin/connections",
                                     json={"name": "think", "base_url": "http://thinker.example.lan/v1"})
        await self.alex.post(f"/api/admin/connections/{think.json()['connection_id']}/check")
        models = {m["name"]: m["model_id"] for m in (await self.alex.get("/api/models")).json()}
        chat = await self.conversation(models["thinking-model"])
        streamed = await self.send(chat, "Hello")
        self.assertEqual([data for name, data in streamed if name == "delta"],
                         [{"content": "", "reasoning": "Plan"}, {"content": "", "reasoning": " it."},
                          {"content": "Done", "reasoning": ""}])
        answer = (await self.path(chat))[-1]
        self.assertEqual((answer["content"], answer["reasoning"]), ("Done", "Plan it."))

    # The context meter ------------------------------------------------------------

    async def count(self, conversation_id: int, content: str, parent_id: int | None = None) -> dict:
        response = await self.alex.post(f"/api/conversations/{conversation_id}/count",
                                        json={"content": content, "parent_id": parent_id})
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    async def test_the_meter_counts_exactly_where_the_server_counts(self):
        await self.alex.put(f"/api/admin/connections/{self.connections['pi']}/key", json={"api_key": KEY})
        chat = await self.conversation(self.qwen)
        await self.alex.put(f"/api/conversations/{chat}/settings",
                            json={"system_prompt": "Answer briefly.", "output_limit": 256})
        reply_id = (await self.send(chat, "One"))[-1][1]["message_id"]
        self.assertEqual(await self.count(chat, "Two", reply_id),
                         {"tokens": 140, "exact": True, "window": 8192, "window_assumed": False})
        self.assertEqual(self.fakes.requests[-1].headers["authorization"], f"Bearer {KEY}")
        await self.send(chat, "Two", parent_id=reply_id)
        self.assertEqual(self.fakes.bodies("/v1/chat/completions/input_tokens")[-1],
                         self.fakes.bodies("/v1/chat/completions")[-1])

    async def test_the_meter_counts_what_the_draft_would_follow(self):
        chat = await self.conversation(self.qwen)
        first = await self.send(chat, "One")
        user_id, reply_id = first[0][1]["message_id"], first[-1][1]["message_id"]
        self.assertEqual((await self.count(chat, "", reply_id))["tokens"], 120)
        self.assertEqual((await self.count(chat, "Other", None))["tokens"], 110)
        self.assertEqual(self.fakes.bodies("/v1/chat/completions/input_tokens")[-1]["messages"],
                         [{"role": "user", "content": "Other"}])
        self.assertRefused(await self.alex.post(f"/api/conversations/{chat}/count",
                                                json={"content": "Two", "parent_id": user_id}), 400, "parent_invalid")
        self.assertRefused(await self.sam.post(f"/api/conversations/{chat}/count", json={"content": "Hi"}),
                           404, "no_such_conversation")
        self.assertRefused(await self.alex.post(f"/api/conversations/{await self.conversation(None)}/count",
                                                json={"content": "Hi"}), 400, "no_model")
        asked = len(self.fakes.requests)
        empty = await self.count(await self.conversation(self.qwen), "")
        self.assertEqual((empty["tokens"], empty["exact"]), (0, True))
        self.assertEqual(len(self.fakes.requests), asked)

    async def test_the_meter_estimates_elsewhere(self):
        chat = await self.conversation(self.models["gemma4"])
        draft = chr(0xE7) * 3 + "abcdefg"
        self.assertEqual((len(draft), len(draft.encode())), (10, 13))
        self.assertEqual(await self.count(chat, draft),
                         {"tokens": 4, "exact": False, "window": 4096, "window_assumed": True})
        await self.alex.put(f"/api/admin/models/{self.models['gemma4']}", json={"context": 8192})
        self.assertEqual(await self.count(chat, draft),
                         {"tokens": 4, "exact": False, "window": 8192, "window_assumed": False})
        plain = await self.conversation(self.models["broken-model"])
        asked = self.fakes.paths("crash")
        self.assertEqual(await self.count(plain, "Hello"),
                         {"tokens": 2, "exact": False, "window": None, "window_assumed": False})
        self.assertEqual(self.fakes.paths("crash"), asked)

    async def test_the_meter_estimates_when_the_server_gives_no_count(self):
        chat = await self.conversation(self.qwen)
        await self.alex.put(f"/api/admin/connections/{self.connections['pi']}",
                            json={"name": "pi", "base_url": "http://down.example.lan:8080/v1",
                                  "connect_timeout": 60, "answer_timeout": 300})
        self.assertEqual(await self.count(chat, "Hello"),
                         {"tokens": 2, "exact": False, "window": 8192, "window_assumed": False})
        self.assertEqual(self.fakes.paths("down"), ["/v1/chat/completions/input_tokens"])


class StopTest(ChatTest):
    """A reply the browser stops, by going away while it streams."""

    async def started(self):
        """A conversation with the slow model, a person's message in it, and
        the reply's events as a generator, as the endpoint streams them."""
        chat = await self.conversation(self.models["slow-model"])
        token_hash = sessions.token_hash(self.alex.cookies[self.config.auth.cookie_name])
        async with connect(self.config.db) as conn:
            user_id = (await call(conn, "add_user_message", token_hash, chat, None, "Hello", None))[0]["add_user_message"]
            access = (await call(conn, "model_access", token_hash, self.models["slow-model"]))[0]
        request = SimpleNamespace(app=self.app)
        replies = conversations.reply(request, token_hash, chat, user_id, self.models["slow-model"], access,
                                      [{"role": "user", "content": "Hello"}], None, None)
        return chat, replies

    async def test_a_reply_stopped_while_streaming_is_kept_as_stopped(self):
        chat, replies = await self.started()
        first = asyncio.Event()

        async def listen():
            async for item in replies:
                if item.startswith("event: delta"):
                    first.set()

        listener = asyncio.create_task(listen())
        await asyncio.wait_for(first.wait(), 5)
        listener.cancel()
        with self.assertRaises(asyncio.CancelledError):
            await listener
        stopped = (await self.path(chat))[-1]
        self.assertEqual((stopped["role"], stopped["state"], stopped["content"]), ("assistant", "stopped", "Half"))

    async def test_a_reply_closed_after_its_first_piece_is_kept_as_stopped(self):
        chat, replies = await self.started()
        async for item in replies:
            if item.startswith("event: delta"):
                break
        await replies.aclose()
        stopped = (await self.path(chat))[-1]
        self.assertEqual((stopped["state"], stopped["content"]), ("stopped", "Half"))


def load_tests(loader, tests, pattern):
    """ChatTest's tests, and StopTest's own, which would otherwise run
    ChatTest's again."""
    suite = unittest.TestSuite()
    suite.addTests(loader.loadTestsFromTestCase(ChatTest))
    for name in ("test_a_reply_stopped_while_streaming_is_kept_as_stopped",
                 "test_a_reply_closed_after_its_first_piece_is_kept_as_stopped"):
        suite.addTest(StopTest(name))
    return suite


if __name__ == "__main__":
    unittest.main()
