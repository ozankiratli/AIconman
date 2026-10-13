"""The context meter: how many tokens the messages sent to a model take, and
the model's window.

The count is exact where the model's server counts a chat request before it is
sent, as llama.cpp does, and the last check found it doing; otherwise, and when
the server gives no count, it is an estimate: a token for every BYTES_PER_TOKEN
bytes of the messages' text in UTF-8. The window is the model's, as the admin
set it or the server reported it; for an Ollama model with neither,
ASSUMED_WINDOW is assumed.
"""

import httpx

from aiconman import keys, relay

BYTES_PER_TOKEN = 4
ASSUMED_WINDOW = 4096


def estimate(messages: list[dict]) -> int:
    """The tokens MESSAGES take, estimated from the length of their text."""
    size = sum(len(message["content"].encode()) for message in messages)
    return -(-size // BYTES_PER_TOKEN)


async def measure(http: httpx.AsyncClient, access: dict, encryption_key: str, messages: list[dict],
                  output_limit: int | None) -> dict:
    """The count of MESSAGES for the model ACCESS describes, a row of
    model_access, and its window: "tokens"; "exact", false for an estimate;
    "window", None when it is not known; and "window_assumed". No messages
    count 0, without asking the server."""
    window = access["context"]
    assumed = window is None and access["protocol"] == "ollama"
    tokens, exact = estimate(messages), not messages
    if messages and access["protocol"] == "openai" and access["counts_tokens"]:
        try:
            api_key = keys.decrypt(encryption_key, access["api_key"]) if access["api_key"] else None
            tokens, exact = await relay.count(http, access, api_key, messages, output_limit), True
        except (keys.UndecryptableKey, relay.RelayFailed):
            pass
    return {"tokens": tokens, "exact": exact, "window": ASSUMED_WINDOW if assumed else window,
            "window_assumed": assumed}
