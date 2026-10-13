# Planned

**This file is kept current.** It holds where the work stands, what Z has decided on and is not built yet, and what was raised and not taken up, so that nothing decided in conversation is lost between sessions or when the agent's context is compacted. An item leaves this file when it is built or settled, and what it becomes is written in the note it belongs to.

Nothing here is a commitment to build. Each item is what Z decided, with the note that holds the detail.

## Where the work stands

*As of 2026-10-12.*

- **The design is done**: the backbone, the interface and the palette (`the-backbone.md`, `the-interface.md`, `the-palette.md`). Z committed it as *"Design is done"* (`85b56d4`).
- **The database is built**, in four stages (`the-database.md`, 2026-10-12): the rebuild, accounts, connections and models, and conversations, messages and files. Both databases exist: `aicm_db`, Z's, and `aicm_scratch_db`, the agent's for tests, configured in `.tmp/scratch/config/`.
- **What exists**: `config.yml.template` and `.env.template` at the root; `config/config.yml` and `config/.env`, Z's, which the agent does not open; `install/common.sh`, shared by the install scripts; `install/create_database.sh`, which runs `db/create_database.sql`; `install/build_schema.sh`, which rebuilds the schema from `db/build_schema.sql` after a dump, and seeds it from `db/seed.sql`; the schema's three parts, `db/accounts.sql`, `db/connections.sql` and `db/conversations.sql`; `tests/install/`, the tests of both scripts, and `tests/db/`, the schema's; `.venv`, with PyYAML and the backend's libraries, from `install/requirements.txt`; `dev/.venv`, with ShellCheck, from `dev/requirements.txt`; `docs/manual.md`, covering setup so far; and `dev/palette/`, the palette's scripts.
- **The backend's groundwork, password accounts, connections, chat and context meter are built** (`the-backend.md`): `aiconman/`, with the configuration's only reader, the database access, refusals as HTTP answers, a health check, the account endpoints, the connection endpoints with checking and the scheduled refresh, the conversations with streamed replies, and the count of a conversation and its draft against the model's window; `install/refresh_models.sh`; and `tests/backend/`. Z committed everything up to the chat and the meter (`4915cd3`). The meter changed the schema, which `aicm_db` takes through a rebuild that is Z's to run.
- **Nothing else of the application is built**: no files, speech or Nextcloud sign-in in the backend, and no frontend. Building goes only as far as Z names (`CLAUDE.md`, and the agent's memory).

## Next, on Z's word

0. **The rename to LMconman** (`the-rename.md`, 2026-10-13), before anything else (Z: *"Before we continue."*): prepared; it waits on Z's rename of the repository on GitHub, and on Z's four answers in the note.
1. **llama-serve** (`llama-serve.md`, 2026-10-12): the framework that runs a new llama.cpp instance of Z's as a service for the network, built in `.tmp/llama-serve` like the one around Z's Hailo gateway, before AIconman continues (Z: *"That will be the next thing we will be building, before we can continue here."*). Its smoke test is where gaps 1 and 2 of R-022 get settled. It waits on R-023 and on Z's two answers in `llama-serve.md`.
2. **Finishing the chat** (`the-backend.md`, 2026-10-12): checking a browser going away under Uvicorn, on port 8644 (`CLAUDE.md`), which the chat's tests could not. Z allowed it on 2026-10-12; the agent takes it to come after llama-serve.
3. **The rest of the backend**, in the stages the agent proposed to Z on 2026-10-12 (`the-backend.md`): speech and files, images in a message among them; then Nextcloud sign-in after the interface works; then export and import once designed. Its libraries are in `install/requirements.txt` and `.venv`, added at Z's word and under Z's review (`SOURCES.md`).
4. **Serving streamed replies behind a reverse proxy**: the manual's part on deployment will need to say how the proxy passes a stream on as it comes, rather than holding it back.

## Deferred by Z to the polishing

- Choosing several messages to export.
- Text sizes and spacing.

(`the-interface.md`.) Z: *"We should defer last two for after everything is done when we are polishing the app."*

## Decided, and not built yet

- **The gaps in what the servers' documents say** (`the-backbone.md`, 2026-10-12), after R-018 to R-021: Ollama's window is the admin's, or 4096 assumed (decided); llama.cpp's window is its slot's `n_ctx` (answered); Ollama's streams and errors (answered); the values of Ollama's `capabilities` (three known, the rest open); the OpenAI protocol's errors (fields known, shown as `error.message` or as sent, decided); and vLLM, whose documentation could not be read (open). After R-022 (`the-backbone.md`, 2026-10-12), three more are open: whether llama.cpp takes `max_completion_tokens`; where its `reasoning_content` sits in a streamed chunk, which the chat reads from each choice's `delta`; and how it reports an error. One request to a llama.cpp server could settle the first two: Z allowed it on 2026-10-12, and it waits for llama-serve's instance and its smoke test. Z decides where a fact comes from when the work needs it.
- **HTTPS on a local network**: the manual names the ways to get a certificate the household's devices trust (`the-backbone.md`), when deployment is written.
- **Registering AIconman in Nextcloud**: the manual's step, when Nextcloud sign-in is built.
- **A part of the manual on setting up and serving a model**, secondary to AIconman itself, possibly around a Raspberry Pi 5 with the AI HAT+ 2 (`product-brief.md`).
- **The manual's website**, built from `docs/manual.md`, served on port 8643 while it is written.
- **Two gists, linked from the manual**: llama-serve, and Z's Hailo gateway with its manual rewritten (Z, 2026-10-12, `llama-serve.md`).
- **A screen for each person's files**, where they manage their attachments, recordings, transcripts and exports. Z: *"we'll give the user a way to manage their files."* Not designed.
- **Choosing an earlier version of a message**, which the database keeps as a tree, and supports with `choose_version()` and each message's version and count (`the-database.md`, 2026-10-12). How the conversation shows it is not designed.
- **Export and import**: the format of an exported conversation, and how an import comes in, including whether it keeps the original times. The database takes an imported reply's model name without a model (`the-database.md`, 2026-10-12).
- **The approved assets enter the repository when the frontend is built**: Tabler Icons whole; Font Awesome's Nextcloud icon cropped to the mark by its frame, with a comment beside Font Awesome's saying so and an entry in `SOURCES.md`; and Source Serif Pro Bold Italic unmodified, whose file needs a source of its own through the reading log.
- **No mobile app of any kind** for now (`product-brief.md`).
- **The Refresh button** on the admin panel's *Connections* tab, which calls `POST /api/admin/connections/check-all`; the scheduled refresh itself is built, with the cron line in the manual (`the-interface.md`, `the-backend.md`, 2026-10-12).

## Raised by the agent, and not taken up

Under Z's rule these are not pending. They are listed so that when the work reaches them, the agent asks again rather than assuming either way. Twice, on Ollama's window and on port 8644, Z said afterwards that silence had meant the proposal was plainly right; so when the work reaches one of these, the agent asks again plainly, rather than taking silence either way.

- **A line under the field of *Delete my account*** saying what enables the button, so that its disabled state does not rest on color in dark HC (`the-interface.md`). Raised 2026-10-11.
