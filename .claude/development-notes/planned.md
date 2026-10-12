# Planned

**This file is kept current.** It holds where the work stands, what Z has decided on and is not built yet, and what was raised and not taken up, so that nothing decided in conversation is lost between sessions or when the agent's context is compacted. An item leaves this file when it is built or settled, and what it becomes is written in the note it belongs to.

Nothing here is a commitment to build. Each item is what Z decided, with the note that holds the detail.

## Where the work stands

*As of 2026-10-12.*

- **The design is done**: the backbone, the interface and the palette (`the-backbone.md`, `the-interface.md`, `the-palette.md`). Z committed it as *"Design is done"* (`85b56d4`).
- **The database is built**, in four stages (`the-database.md`, 2026-10-12): the rebuild, accounts, connections and models, and conversations, messages and files. Both databases exist: `aicm_db`, Z's, and `aicm_scratch_db`, the agent's for tests, configured in `.tmp/scratch/config/`.
- **What exists**: `config.yml.template` and `.env.template` at the root; `config/config.yml` and `config/.env`, Z's, which the agent does not open; `install/common.sh`, shared by the install scripts; `install/create_database.sh`, which runs `db/create_database.sql`; `install/build_schema.sh`, which rebuilds the schema from `db/build_schema.sql` after a dump, and seeds it from `db/seed.sql`; the schema's three parts, `db/accounts.sql`, `db/connections.sql` and `db/conversations.sql`; `tests/install/`, the tests of both scripts, and `tests/db/`, the schema's; `.venv`, with PyYAML and the backend's libraries, from `install/requirements.txt`; `dev/.venv`, with ShellCheck, from `dev/requirements.txt`; `docs/manual.md`, covering setup so far; and `dev/palette/`, the palette's scripts.
- **The backend's groundwork is built** (`the-backend.md`): `aiconman/`, with the configuration's only reader, the database access, refusals as HTTP answers and a health check; and `tests/backend/`.
- **Nothing else of the application is built**: no endpoints beyond the health check, no frontend. Building goes only as far as Z names (`CLAUDE.md`, and the agent's memory).

## Next, on Z's word

1. **The rest of the backend**, on FastAPI, in stages the agent proposed to Z on 2026-10-12, with the order of accounts to settle. Its libraries are in `install/requirements.txt` and `.venv`, added at Z's word and under Z's review (`SOURCES.md`, `the-database.md`, 2026-10-12).

## Deferred by Z to the polishing

- Choosing several messages to export.
- Text sizes and spacing.

(`the-interface.md`.) Z: *"We should defer last two for after everything is done when we are polishing the app."*

## Decided, and not built yet

- **Six gaps in what the servers' documents say** (`the-backbone.md`): Ollama's window when `num_ctx` is not set; what llama.cpp's `n_ctx` is per request; how Ollama separates a stream's objects and reports errors; the values Ollama's capabilities take; the OpenAI protocol's error format; and vLLM, whose documentation could not be read. Z decides where each fact comes from when the work needs it.
- **HTTPS on a local network**: the manual names the ways to get a certificate the household's devices trust (`the-backbone.md`), when deployment is written.
- **Registering AIconman in Nextcloud**: the manual's step, when Nextcloud sign-in is built.
- **A part of the manual on setting up and serving a model**, secondary to AIconman itself, possibly around a Raspberry Pi 5 with the AI HAT+ 2 (`product-brief.md`).
- **The manual's website**, built from `docs/manual.md`, served on port 8643 while it is written.
- **A screen for each person's files**, where they manage their attachments, recordings, transcripts and exports. Z: *"we'll give the user a way to manage their files."* Not designed.
- **Choosing an earlier version of a message**, which the database keeps as a tree, and supports with `choose_version()` and each message's version and count (`the-database.md`, 2026-10-12). How the conversation shows it is not designed.
- **Export and import**: the format of an exported conversation, and how an import comes in, including whether it keeps the original times. The database takes an imported reply's model name without a model (`the-database.md`, 2026-10-12).
- **The approved assets enter the repository when the frontend is built**: Tabler Icons whole; Font Awesome's Nextcloud icon cropped to the mark by its frame, with a comment beside Font Awesome's saying so and an entry in `SOURCES.md`; and Source Serif Pro Bold Italic unmodified, whose file needs a source of its own through the reading log.
- **No mobile app of any kind** for now (`product-brief.md`).
- **The scheduled refresh**: a job cron runs every 30 minutes, checking every connection through `refresh_targets()` and `refresh_record_check()`, which exist; and a button on the admin panel's *Connections* tab that refreshes every connection at once. The manual gives the cron line when the job exists (`the-interface.md`, `the-database.md`, 2026-10-12).

## Raised by the agent, and not taken up

Under Z's rule these are not pending. They are listed so that when the work reaches them, the agent asks again rather than assuming either way.

- **A port for the agent's own test server**, 8644 proposed, since the agent may not drive Z's instance on 8642. Until Z answers, the agent starts no server without asking. Raised 2026-10-11.
- **A line under the field of *Delete my account*** saying what enables the button, so that its disabled state does not rest on color in dark HC (`the-interface.md`). Raised 2026-10-11.
