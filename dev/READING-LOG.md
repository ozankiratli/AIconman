# Reading log

Every read of another person's code is made the same way: named, recorded, cleared and done, in that order. The rule, and what it covers, are in `CLAUDE.md` under *Other people's code*.

This file is where the second and third steps happen:
- An entry is written **before** anything in it is opened.
- **Z writes the *Cleared* line.** The agent never writes it.
- After the read, the agent adds a *Done* line saying what was found and where it went.

Nothing in an entry is rewritten afterwards; an entry only gains lines. The entry ID is what a fact in `dev/facts/` cites.

```
## R-<number>: <source, in a few words>

- **Named:** <date>
- **Task:** <what the read is for>
- **Source:** <file or section>, at <commit, or URL and the date it was read>
- **Facts sought:** <which facts>
- **Not read:** <what stays closed>
- **Cleared:** <written by Z>
- **Done:** <date; what was found, and where it went>
```

## R-001: the OpenAI API reference, three endpoints

- **Named:** 2026-10-11
- **Task:** design, part 1, in `.claude/development-notes/the-backbone.md`: what the OpenAI-compatible protocol says about listing models, chatting and transcribing, so that the backend can relay it and the protocol detection knows what to test for.
- **Source:** the OpenAI API reference, https://platform.openai.com/docs/api-reference, as it reads on the day of the read: the sections on listing models, creating a chat completion, and creating a transcription. If the reference has moved, the new address is reported to Z before anything is read.
- **Facts sought:**
  - listing models: the path and method, and the fields of a model entry;
  - chat: the request fields a chat needs (the model, the messages and their roles, image parts, the output limit, streaming), the response fields, the token counts a response reports, and how a streamed response is framed and ended;
  - transcription: the path, the form fields (the file, the model, the language, the response format), and the response;
  - how a key is sent, and the shape of an error.
- **Not read:** every other section of the reference, the Responses API among them, and the guides.
- **Cleared:** 2026-10-11
- **Done:**

## R-002: Ollama's API documentation

- **Named:** 2026-10-11
- **Task:** design, part 1: what Ollama's own API reports about its models, so that the backend can take capabilities and context windows from it, and what the protocol detection can test for.
- **Source:** `docs/api.md` in github.com/ollama/ollama, on `main` on the day of the read, with the commit recorded under *Done*. That file only. If it has moved, the new place is reported to Z before anything is read.
- **Facts sought:**
  - listing models: the path, and the fields of a model entry;
  - a model's details: what it can do, its context length, and where each sits in the response;
  - chat: the request and response, the token counts it reports, and how a streamed response is framed and ended;
  - an endpoint that answers without a model being named, such as a version endpoint, as a signal for the detection;
  - whether the API counts tokens for a text;
  - whether any endpoint transcribes audio;
  - how an error is reported.
- **Not read:** every other file in the repository, the source code above all.
- **Cleared:** 2026-10-11
- **Done:**

## R-003: the llama.cpp server's README

- **Named:** 2026-10-11
- **Task:** design, part 1: what an OpenAI-compatible llama.cpp server reports beyond the OpenAI protocol, about context size, token counting and images.
- **Source:** `tools/server/README.md` in github.com/ggml-org/llama.cpp, on `master` on the day of the read, with the commit recorded under *Done*. That file only. If it has moved, the new place is reported to Z before anything is read.
- **Facts sought:**
  - which OpenAI-compatible endpoints it serves;
  - what its model list returns beyond the OpenAI fields;
  - how a client learns the context size, and where it sits in the response;
  - whether it counts tokens for a text, and how;
  - whether it says if the loaded model accepts images;
  - whether it transcribes audio;
  - how a key is set on the server and sent by a client;
  - an endpoint that answers without a model being named, as a signal for the detection.
- **Not read:** every other file in the repository, the server's source above all.
- **Cleared:** 2026-10-11
- **Done:**

## R-004: vLLM's OpenAI-compatible server documentation

- **Named:** 2026-10-11
- **Task:** design, part 1: what a vLLM server reports beyond the OpenAI protocol, about context length and token counting, and whether it transcribes.
- **Source:** the vLLM documentation page on its OpenAI-compatible server, https://docs.vllm.ai/en/stable/serving/openai_compatible_server.html, as it reads on the day of the read. That page only. If it has moved, the new address is reported to Z before anything is read.
- **Facts sought:**
  - which endpoints it serves: models, chat, transcription, token counting;
  - what its model list returns beyond the OpenAI fields, the context length in particular;
  - how a key is set on the server and sent by a client.
- **Not read:** every other page of the documentation, and the source.
- **Cleared:** 2026-10-11
- **Done:**

## R-005: MDN on secure contexts and installable web apps

- **Named:** 2026-10-11
- **Task:** design, part 1, point 2: what a page served over plain HTTP on a local network cannot do, which the design gave from memory.
- **Source:** two pages of MDN Web Docs, as they read on the day of the read:
  - *Features restricted to secure contexts*, https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts/features_restricted_to_secure_contexts, with its parent page *Secure contexts* for what counts as one;
  - *Making PWAs installable*, https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable.

  If either has moved, the new address is reported to Z before anything is read.
- **Facts sought:**
  - whether microphone access and service workers are restricted to secure contexts;
  - what counts as a secure context, `localhost` and a local network address over plain HTTP in particular;
  - what a browser needs before it offers to install a web app.
- **Not read:** every other MDN page.
- **Cleared:** 2026-10-11
- **Done:**
