"""The conversation endpoints: one's own conversations and their messages,
sending a message or regenerating a reply, whose reply streams back as
server-sent events while it is written, and counting a draft with the
conversation before it is sent, for the context meter.

A reply is stored when it ends: complete, failed with its error, or stopped,
with what had arrived, when the browser goes away before it ends, as it does
when the person presses Stop.

The events a reply streams are "user", with the id of the person's message it
answers, when the request added one; "delta" for each piece, with its
"content" and "reasoning"; and at the end "done", with the reply's id, its
state and its counts, or "failed", with its id and its error; or "error" with
a refusal's key, if the reply could not be stored.
"""

import asyncio
import json
from collections.abc import AsyncIterator

import anyio
from fastapi import APIRouter, Depends, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from aiconman import keys, meter, relay, servers, sessions
from aiconman.accounts import db
from aiconman.db import Refused, call, connect

router = APIRouter(prefix="/api")

TITLE_LENGTH = 60


def title_from(content: str) -> str:
    """A title made from a first message: its first line that has text, its
    spaces run together, at most TITLE_LENGTH characters."""
    for line in content.splitlines():
        words = " ".join(line.split())
        if words:
            return words[:TITLE_LENGTH].rstrip()
    return ""


def chat_messages(system_prompt: str, path: list[dict]) -> list[dict]:
    """The messages sent to the model: the system prompt, when there is one,
    then the conversation's path, leaving out failed replies."""
    messages = [{"role": "system", "content": system_prompt}] if system_prompt.strip() else []
    for message in path:
        if message["role"] == "assistant" and message["state"] == "failed":
            continue
        messages.append({"role": message["role"], "content": message["content"]})
    return messages


def event(name: str, data: dict) -> str:
    """One server-sent event."""
    return f"event: {name}\ndata: {json.dumps(data)}\n\n"


async def reply(request: Request, token_hash: bytes, conversation_id: int, parent_id: int,
                model_id: int, access: dict, messages: list[dict], output_limit: int | None,
                user_id: int | None) -> AsyncIterator[str]:
    """Streams the model's reply to MESSAGES as events, and stores it as the
    reply to PARENT_ID when it ends. Stopped by the browser going away, it is
    stored as stopped, with what had arrived."""
    config = request.app.state.config
    content: list[str] = []
    reasoning: list[str] = []
    usage = relay.Usage(None, None)
    state, error = "complete", None

    async def store() -> int:
        async with connect(config.db) as conn:
            return (await call(conn, "add_reply", token_hash, conversation_id, parent_id, model_id, None,
                               "".join(content), "".join(reasoning) or None, state, error,
                               usage.prompt_tokens, usage.completion_tokens))[0]["add_reply"]

    if user_id is not None:
        yield event("user", {"message_id": user_id})
    try:
        api_key = keys.decrypt(config.encryption_key, access["api_key"]) if access["api_key"] else None
        async with servers.client(getattr(request.app.state, "server_transport", None)) as http:
            async for item in relay.stream(http, access, api_key, messages, output_limit):
                if isinstance(item, relay.Piece):
                    content.append(item.content)
                    reasoning.append(item.reasoning)
                    yield event("delta", {"content": item.content, "reasoning": item.reasoning})
                else:
                    usage = item
    except keys.UndecryptableKey:
        state, error = "failed", "key_undecryptable"
    except relay.RelayFailed as e:
        state, error = "failed", e.text
    except (asyncio.CancelledError, GeneratorExit):
        state = "stopped"
        with anyio.CancelScope(shield=True):
            await store()
        raise
    try:
        message_id = await store()
    except Refused as e:
        yield event("error", {"error": e.key})
        return
    if state == "failed":
        yield event("failed", {"message_id": message_id, "error": error})
    else:
        yield event("done", {"message_id": message_id, "state": state,
                             "prompt_tokens": usage.prompt_tokens, "completion_tokens": usage.completion_tokens})


async def ready_model(conn, token_hash: bytes, conversation_id: int) -> tuple[dict, dict]:
    """One's own conversation and what the backend needs to use its model,
    refusing a conversation with no model as no_model, before anything is
    added to it."""
    conversation = (await call(conn, "conversation", token_hash, conversation_id))[0]
    if conversation["model_id"] is None:
        raise Refused("no_model")
    access = (await call(conn, "model_access", token_hash, conversation["model_id"]))[0]
    return conversation, access


def streamed(events: AsyncIterator[str]) -> StreamingResponse:
    """EVENTS as a stream of server-sent events, kept from caches."""
    return StreamingResponse(events, media_type="text/event-stream", headers={"Cache-Control": "no-cache"})


# Conversations -------------------------------------------------------------------

class NewConversation(BaseModel):
    title: str = ""
    model_id: int | None = None


class Title(BaseModel):
    title: str


class ModelChoice(BaseModel):
    model_id: int | None


class ConversationSettings(BaseModel):
    system_prompt: str
    output_limit: int | None = None


@router.get("/conversations")
async def conversations(token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> list[dict]:
    """One's own conversations, the most recently changed first."""
    return await call(conn, "conversations", token_hash)


@router.post("/conversations")
async def create_conversation(body: NewConversation, token_hash: bytes = Depends(sessions.current),
                              conn=Depends(db)) -> dict:
    """Starts a conversation, with a model or none yet."""
    conversation_id = (await call(conn, "create_conversation", token_hash, body.title,
                                  body.model_id))[0]["create_conversation"]
    return {"conversation_id": conversation_id}


@router.get("/conversations/{conversation_id}")
async def conversation(conversation_id: int, token_hash: bytes = Depends(sessions.current),
                       conn=Depends(db)) -> dict:
    """One of one's own conversations, with its model and settings."""
    return (await call(conn, "conversation", token_hash, conversation_id))[0]


@router.put("/conversations/{conversation_id}/title")
async def rename_conversation(conversation_id: int, body: Title, token_hash: bytes = Depends(sessions.current),
                              conn=Depends(db)) -> dict:
    """Renames one of one's own conversations."""
    await call(conn, "rename_conversation", token_hash, conversation_id, body.title)
    return (await call(conn, "conversation", token_hash, conversation_id))[0]


@router.put("/conversations/{conversation_id}/model")
async def set_conversation_model(conversation_id: int, body: ModelChoice,
                                 token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> dict:
    """Switches the model of one of one's own conversations."""
    await call(conn, "set_conversation_model", token_hash, conversation_id, body.model_id)
    return (await call(conn, "conversation", token_hash, conversation_id))[0]


@router.put("/conversations/{conversation_id}/settings")
async def set_conversation_settings(conversation_id: int, body: ConversationSettings,
                                    token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> dict:
    """Sets the system prompt and output limit of one of one's own
    conversations; an output limit of null leaves it to the server."""
    await call(conn, "set_conversation_settings", token_hash, conversation_id, body.system_prompt,
               body.output_limit)
    return (await call(conn, "conversation", token_hash, conversation_id))[0]


@router.delete("/conversations/{conversation_id}")
async def delete_conversation(conversation_id: int, token_hash: bytes = Depends(sessions.current),
                              conn=Depends(db)) -> dict:
    """Deletes one of one's own conversations, with every version of its
    messages."""
    await call(conn, "delete_conversation", token_hash, conversation_id)
    return {"deleted": conversation_id}


# Messages ------------------------------------------------------------------------

class Send(BaseModel):
    content: str
    parent_id: int | None = None


class Regenerate(BaseModel):
    parent_id: int


@router.get("/conversations/{conversation_id}/messages")
async def messages(conversation_id: int, token_hash: bytes = Depends(sessions.current),
                   conn=Depends(db)) -> list[dict]:
    """The path the conversation shows, with each message's version."""
    return await call(conn, "messages", token_hash, conversation_id)


@router.post("/messages/{message_id}/choose")
async def choose_version(message_id: int, token_hash: bytes = Depends(sessions.current),
                         conn=Depends(db)) -> dict:
    """Shows the version MESSAGE_ID in its conversation, with the newest below
    it at each step."""
    leaf = (await call(conn, "choose_version", token_hash, message_id))[0]["choose_version"]
    return {"leaf_id": leaf}


@router.post("/conversations/{conversation_id}/messages")
async def send(conversation_id: int, body: Send, request: Request, token_hash: bytes = Depends(sessions.current),
               conn=Depends(db)) -> StreamingResponse:
    """Adds the person's message after PARENT_ID, the reply it follows, or
    opening the conversation when it is null, and streams the model's reply.
    Editing a message is sending another after the same reply. The first
    message of an untitled conversation gives it its title."""
    conversation, access = await ready_model(conn, token_hash, conversation_id)
    user_id = (await call(conn, "add_user_message", token_hash, conversation_id, body.parent_id, body.content,
                          None))[0]["add_user_message"]
    if body.parent_id is None and not conversation["title"] and title_from(body.content):
        await call(conn, "rename_conversation", token_hash, conversation_id, title_from(body.content))
    path = await call(conn, "messages", token_hash, conversation_id)
    return streamed(reply(request, token_hash, conversation_id, user_id, conversation["model_id"], access,
                          chat_messages(conversation["system_prompt"], path), conversation["output_limit"],
                          user_id))


@router.post("/conversations/{conversation_id}/regenerate")
async def regenerate(conversation_id: int, body: Regenerate, request: Request,
                     token_hash: bytes = Depends(sessions.current), conn=Depends(db)) -> StreamingResponse:
    """Streams another reply to PARENT_ID, a person's message on the path the
    conversation shows, from the conversation's model; the earlier replies
    stay."""
    conversation, access = await ready_model(conn, token_hash, conversation_id)
    path = await call(conn, "messages", token_hash, conversation_id)
    place = next((i for i, m in enumerate(path) if m["message_id"] == body.parent_id and m["role"] == "user"),
                 None)
    if place is None:
        raise Refused("parent_invalid")
    return streamed(reply(request, token_hash, conversation_id, body.parent_id, conversation["model_id"], access,
                          chat_messages(conversation["system_prompt"], path[:place + 1]),
                          conversation["output_limit"], None))


@router.post("/conversations/{conversation_id}/count")
async def count(conversation_id: int, body: Send, request: Request, token_hash: bytes = Depends(sessions.current),
                conn=Depends(db)) -> dict:
    """How much of its model's window one's own conversation takes with
    CONTENT, the draft, sent after PARENT_ID as POST .../messages would send
    it: the system prompt and the path to PARENT_ID, a reply on the path the
    conversation shows, or no path when PARENT_ID is null, then the draft,
    when it has text. Gives what meter.measure gives."""
    conversation, access = await ready_model(conn, token_hash, conversation_id)
    path = []
    if body.parent_id is not None:
        shown = await call(conn, "messages", token_hash, conversation_id)
        place = next((i for i, m in enumerate(shown) if m["message_id"] == body.parent_id
                      and m["role"] == "assistant"), None)
        if place is None:
            raise Refused("parent_invalid")
        path = shown[:place + 1]
    messages = chat_messages(conversation["system_prompt"], path)
    if body.content:
        messages.append({"role": "user", "content": body.content})
    async with servers.client(getattr(request.app.state, "server_transport", None)) as http:
        return await meter.measure(http, access, request.app.state.config.encryption_key, messages,
                                   conversation["output_limit"])
