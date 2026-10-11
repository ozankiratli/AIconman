# The backbone

**Written 2026-10-11, against the tree at `f94a72f`**, which added the working rules and the first notes. Nothing had been built.

This is the first part of the design: what talks to what, what a connection is, and how models are found. The agent proposed it in nine points, with four questions; this note records the proposal as the agent's and Z's answers in Z's words. The interface and the palette are later parts of the design.

## The proposal

These are the agent's points as proposed. Points 2, 5 and 6 rest on facts the agent gave from memory; those wait on the reads under *Waiting on reads*.

1. **What talks to what.** The browser talks to the AIconman backend, and the backend talks to the model servers. The browser keeps chat history, as agreed in `product-brief.md`. The backend keeps the connections and their keys, forwards every request, and streams replies back as they arrive. Only the backend has to reach the model servers, and Apache or another reverse proxy may stand in front of it.
2. **HTTPS.** Browsers allow microphone access and installing a web app only on a secure page, so a phone opening the interface over plain HTTP on a local address gets neither; uploading a recording still works. The documentation explains TLS, and the interface says why the microphone is unavailable rather than hiding the button.
3. **A connection** is a name, a base URL, an optional key and a protocol, with any number of connections on one machine. A saved key is never sent back to the browser: it can be replaced, not read.
4. **The protocol** starts empty, on no protocol. Left empty, the backend tries each protocol it knows against the URL, uses the one that answers, and shows what it found. The first version knows the OpenAI-compatible protocol and Ollama's own API; others are added when someone needs one.
5. **Models and what they can do.** The backend merges every connection's models into one list, each marked with its connection. What a model can do (chat, images, speech-to-text) and its context window come from the server where the server reports them; where it does not, the user sets them per model.
6. **The context window calculator** shows how much of the model's window the conversation and the draft use. The count is exact where the server can count tokens, and an estimate, labeled as one, where it cannot.
7. **Speech** comes in two ways. A microphone button in the chat box puts the transcript in the input, to be edited before it is sent. A file upload shows the transcript, which can then be sent into a chat.
8. **Login.** A screen with one button that lets the user in, as Z asked (`product-brief.md`). The backend has a single place where an access check goes, open for now, so that the options Z will choose from later go there without touching the rest.
9. **Storage.** The connections live in one JSON file in a data folder that only the service user can read.

The agent also proposed an optional machine label for grouping connections. Z declined it, below.

## Z's answers

**Detection, and a choice.** Asked whether an empty protocol should be detected or the user should always pick one: *"auto-detect would be the best. user can select the protocol too, I don't think it is an issue for a user to choose protocol for the server they set up."* So the protocol is detected when it is left empty, and the user can set it.

**Two protocols first.** Asked whether the OpenAI-compatible protocol and Ollama's own API are enough for the first version: *"I think so."*

**No machine label.** *"No"*.

**The reads go through the log.** Asked for a go-ahead to read four servers' published API documentation, which the rule as drafted would have let the agent read without a log entry: *"Create reading log for me to edit and clear."* The agent wrote R-001 to R-004 in `dev/READING-LOG.md`, and R-005 for the HTTPS point, which it had also given from memory.

## Waiting on reads

| Point | Rests on | Read |
|---|---|---|
| 2, HTTPS | what a page over plain HTTP cannot do | R-005 |
| 4, detection | what each protocol answers without a model being named | R-001, R-002, R-003 |
| 5, capabilities and context windows | what each server reports about its models | R-001 to R-004 |
| 6, the calculator | which servers count tokens | R-002, R-003, R-004 |
| 7, speech | which servers transcribe, and the transcription endpoint | R-001 to R-004 |

Until a read is cleared and done, its facts are the agent's recollection and nothing is built on them. What each read found is appended here, dated, when it is done.

## Added later on 2026-10-11, against `e1866f4`: what R-002 and R-003 found

Z cleared R-001 to R-005 and committed `e1866f4`: *"I like this. Committed. You can go ahead, we are ready to start."* Two reads were done: R-002, Ollama's API document, and R-003, the llama.cpp server's README. Three were not. The sources of R-001, R-004 and R-005 had moved, and each entry says a move is reported to Z before anything is read. R-006 to R-008 name the new addresses, for Z to clear.

### Ollama's own API (R-002)

- **Models:** `GET /api/tags` returns `models`, each with `name`, `model`, `modified_at`, `size`, `digest` and `details` (`format`, `family`, `families`, `parameter_size`, `quantization_level`, `parent_model`). Nothing in it says what a model can do or how long its window is.
- **One model's details:** `POST /api/show` with `model` returns `capabilities`, a list (`["completion", "vision"]` in the example); `model_info`, where the example holds `llama.context_length` next to `general.architecture: "llama"`; and `parameters` and `modelfile`, where the example sets `num_ctx 4096` while `llama.context_length` is 8192. It takes one request per model.
- **Chat:** `POST /api/chat` with `model`, `messages` (`role` is `system`, `user`, `assistant` or `tool`; `content`; `images` as a list of base64 strings), `options` (model parameters such as `num_ctx`) and `stream`. Replies stream unless `stream` is `false`. A stream is a series of JSON objects, each holding a piece of `message.content` with `done: false`. The last has `done: true`, the counts `prompt_eval_count` and `eval_count`, and durations, which are in nanoseconds.
- **Without a model:** `GET /api/version` returns `{"version": ...}`.
- **Not offered:** no endpoint counts the tokens of a text, and none transcribes audio. Audio appears only as an input to embeddings.
- **Not described:** how an error is reported, and how the objects of a stream are separated. The file says nothing about a key.

### llama.cpp's server (R-003)

- **Endpoints:** the OpenAI-compatible `/v1/models`, `/v1/completions`, `/v1/chat/completions`, `/v1/responses` and `/v1/embeddings`, and two token counters of its own. There is no transcription endpoint. Audio is accepted only as part of a chat message (`input_audio`), by a model that reads audio; images as `image_url` parts, base64 data URLs among them.
- **Model list:** `GET /v1/models` has one element on a server started with a model. Beyond the OpenAI fields it carries `architecture.input_modalities`, which always includes `text` plus each media type the model reads (`image` in an example), and `output_modalities`; and `meta`, with `n_ctx_train` among its fields, which is `null` while the model loads. The README does not explain the `meta` fields. The `id` is the model's file path unless the server sets an alias.
- **Many models:** a server started without a model is a router. It loads models on demand, routes a POST by its `model` field and a GET by a `?model=` parameter, and lists every model it has at `GET /models`, each with a `status` (`loaded`, `unloaded`) and the same `architecture`.
- **Context:** `GET /props` returns `default_generation_settings`, which includes `n_ctx` (1024 in the example), together with `total_slots` and `modalities` (`{"vision": false}` in the example). The README describes `default_generation_settings` as the defaults for its `/completion` endpoint, and says nothing more about `n_ctx`.
- **Counting tokens:** `POST /tokenize` with `content` returns `tokens`, a list whose length is the count. `POST /v1/chat/completions/input_tokens` takes a whole chat request and returns `input_tokens`.
- **Key and health:** the server takes `--api-key` (several, comma-separated) or `--api-key-file`, and the README's examples send `Authorization: Bearer`. `GET /health`, also at `/v1/health`, needs no key: it answers 200 with `{"status": "ok"}` when ready, and 503 while the model loads.

### What this means for the proposal

- **Point 4, detection:** Ollama answers `GET /api/version` without a model, and llama.cpp answers `GET /health` without a key. The signal for a plain OpenAI-compatible server waits on R-006.
- **Point 5, what a model can do:** both servers report it, in different places: Ollama per model in `capabilities`, llama.cpp in `architecture.input_modalities`. The plain OpenAI list waits on R-006.
- **Point 6, the calculator:** llama.cpp counts a whole chat request exactly before it is sent. Ollama counts only after a reply, in `prompt_eval_count` and `eval_count`, so before sending, the count for an Ollama model is an estimate.
- **Point 7, speech:** neither server transcribes. Transcription comes from servers with the OpenAI transcription endpoint, Z's own gateway among them. Which others offer it waits on R-006 and R-007.

### Gaps for Z

Each is a fact these two documents leave open. Under the rule in `CLAUDE.md`, Z decides where it comes from, or that it is left out.

1. **Ollama's window when `num_ctx` is not set.** `model_info` gives a context length, and `num_ctx` appears only when it is set. The file does not say which window Ollama uses otherwise, and the calculator needs the window in use.
2. **What llama.cpp's `n_ctx` is.** The README gives `n_ctx` and `total_slots` side by side, but says neither whether `n_ctx` is the window one request gets nor how the slots share it.
3. **How Ollama separates the objects of a stream, and how it reports an error.**
4. **The values Ollama's `capabilities` can take.** The file shows only `completion` and `vision`.

The places these could come from that are already in sight: Ollama's newer documentation at docs.ollama.com/api, which `docs/api.md` itself points to, and a running server. A request to one of Z's servers needs Z's go-ahead under *Ask before acting*.

## Added later on 2026-10-11, against `e1866f4`: what R-006 and R-008 found

Z cleared R-006 to R-008 and said to go ahead. R-006 and R-008 were read. R-007 was not: vLLM's documentation site answered every request with a bot check (HTTP 429), so nothing about vLLM is known from a source.

### The OpenAI-compatible protocol (R-006)

- **Key:** `Authorization: Bearer <key>`.
- **Models:** `GET /models`, under `/v1` in the examples, returns `object: "list"` and `data`, each entry with `id`, `created`, `object: "model"`, `owned_by` and an optional `shutdown_date`. Nothing in it says what a model can do or how long its window is.
- **Chat:** `POST /chat/completions`, with `messages` whose roles are `developer`, `system`, `user`, `assistant` and `tool` (and a deprecated `function`). A user message's `content` is a string or a list of parts: text; `image_url`, whose `url` is a link or base64 image data, with a `detail`; `input_audio`, base64 `data` in `wav` or `mp3`; and a file. The output limit is `max_completion_tokens`, and `max_tokens` is deprecated. `stream: true` sends server-sent events, and `stream_options.include_usage` adds a chunk carrying the counts.
- **Reply:** `choices`, each with a `message` (role `assistant`, `content`) and a `finish_reason` (`stop`, `length`, `tool_calls`, `content_filter`, `function_call`), and `usage` with `prompt_tokens`, `completion_tokens` and `total_tokens`.
- **Stream:** `chat.completion.chunk` objects, each with a piece of the content in `choices[].delta`. With `include_usage`, a last chunk with empty `choices` and the counts comes before `data: [DONE]`, which ends the stream.
- **Transcription:** `POST /audio/transcriptions` with form data: `file` (flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav or webm), `model`, and optionally `language` (ISO-639-1), `prompt`, `response_format` (`json`, `text`, `srt`, `verbose_json`, `vtt`, `diarized_json`), `stream` and `temperature`. It returns an object with `text`.
- **Not in these sections:** the format of an error response, and any way to count tokens before a request is sent.

### The browser (R-008)

- **Microphone and service workers:** `getUserMedia()`, which the microphone needs, requires a secure context, and service workers are available only in one.
- **What is secure:** a page served over HTTPS, from `localhost`, a `.localhost` name or a loopback address (127.0.0.0/8, ::1), or from a file. Plain HTTP to any other host is not, so a local network address over HTTP is not a secure context.
- **Installing:** a browser promotes installing a web app when the app has a manifest and is served over HTTPS or from `localhost` or `127.0.0.1`. Chromium-based browsers require the manifest to have `name` or `short_name`, a 192 and a 512 pixel icon, `start_url`, and `display` or `display_override`. A service worker is not required.
- **Installing by hand:** Chrome on desktop and Android, Safari on desktop and Edge on desktop also let a user install any website as an app, without the manifest criteria. The page does not say whether that works over plain HTTP.

### What this changes in the proposal

- **Point 2, HTTPS:** the microphone part holds. The install part was stated too strongly. Over plain HTTP the browser does not offer to install the app, but some browsers let the user install a site by hand, and whether that works over HTTP is open.
- **Point 4, detection:** a plain OpenAI-compatible server is recognized by `GET /v1/models` answering a list of this shape. Ollama's `/api/version` and llama.cpp's `/health` identify those two more specifically.
- **Point 5, what a model can do:** a plain OpenAI-compatible model list says nothing about what a model can do or its window, so for such a server the user sets both, as point 5 proposed. llama.cpp adds both to the same list.
- **Point 6, the calculator:** the OpenAI protocol counts tokens only after a reply, in `usage`, and in a stream only when `include_usage` is asked for. Of the servers read, only llama.cpp counts exactly before a request is sent.
- **Point 7, speech:** transcription is `POST /v1/audio/transcriptions` with the file as form data. Z's own gateway serves that endpoint.

### Gaps for Z, added to the four above

5. **The OpenAI protocol's error format.** These sections do not give it, and the error-codes guide was not cleared.
6. **vLLM.** Nothing is known from a source, since its documentation could not be read. Its markdown source in the vLLM repository would be a different source, needing its own entry.
7. **Installing by hand over plain HTTP.** Whether a browser lets a user install the site that way.

## Added later on 2026-10-11, against `e1866f4`: Z on HTTPS, and what "installing" meant

**HTTPS comes from the user's reverse proxy.** Z, on point 2: *"I believe the best way to handle this is through reverse proxy. I think without https my nextcloud instance was working fine with everything in the background. The whiteboard are local but they don't require https to connect and run. The HTTPS point is well taken. I believe we can find a solution."* So AIconman is served behind the user's reverse proxy, which provides HTTPS. Over plain HTTP, everything that does not need a secure context works, as it did for Z's Nextcloud; under R-008 that leaves out the microphone and installing the interface as an app. How a reverse proxy on a local network gets a certificate the user's devices trust is the solution Z expects to find.

**What "installing" meant.** Z: *"I have no idea when you say installing by hand. The user will have to install this and serve it in their own network to reach it. Like their Nextcloud. They can technically do it on their local machine. But the idea is to serve it properly so the user can have access to their LLMs."* The agent's word was ambiguous. In point 2, in R-008 and in gap 7, installing means adding the web interface to a phone's home screen or a computer's app list, so that it opens in a window of its own like an app: the installable web app of the defaults in `product-brief.md`. It does not mean installing AIconman on a server, which the user does on their own network, like their Nextcloud.

**Z's own servers are llama.cpp**, not Ollama (`product-brief.md`). Of the servers read, llama.cpp reports the most: what a model can do and its context in the model list, and an exact token count before a request is sent. That makes gap 2, what its `n_ctx` is, the gap that matters most for Z's own setup.

## Added later on 2026-10-11, against `e1866f4`: accounts

Z added accounts after the second part of the design (`product-brief.md`). Three points change. Point 1: the backend stores conversations, per account, and the browser no longer keeps them. Point 8: accounts with a password or a Nextcloud login replace the open access check, wired after the interface is confirmed. Point 9: the backend's data lives in PostgreSQL rather than a JSON file, with other databases later. Open: whether connections and their keys belong to the household or to each account.
