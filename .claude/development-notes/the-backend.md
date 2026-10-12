# The backend

**Written 2026-10-12, against the tree at `bd9f11a`**, which Z committed as *"conversations tables done, initial database stage complete"*. The database was built; nothing of the backend was.

Z: *"committed. Backend."* This note records how the backend is built: what the agent decided, what Z decided, and how each part was checked.

## What the brief already settled

- **FastAPI**, a Python backend, with a plain HTML, CSS and JavaScript frontend and no build step: the defaults Z accepted (`product-brief.md`). Its libraries are in `install/requirements.txt`, added at Z's word and under Z's review (`the-database.md`, 2026-10-12).
- **The backend talks to the model servers, and the browser talks only to the backend** (`the-backbone.md`).
- **Accounts were to be wired after the interface works** (`product-brief.md`): Z, *"We will wire it after we confirm the interface working."* Since then the database was built so that every function acting for a person takes that person's session (`the-database.md`, decision (a)), which bears on that order; the agent raised it with Z, below.

## The groundwork

Built first, since every later part needs it and none of it waits on a decision of Z's.

- **`aiconman/`**, a Python package at the repository's root, run by Uvicorn as `uvicorn --factory aiconman.app:create_app`.
- **`aiconman/config.py` is the only reader of the configuration.** It reads `config.yml` from `config/` or the folder `AICONMAN_CONFIG_DIR` names, fills each secret left empty there from `.env`, and checks that every setting the backend needs is there and of its type, naming the setting when one is not. The scripts in `install/` had read `config.yml` with code of their own and filled the secrets by sourcing `.env` in bash; two readers of one file can come to disagree, so `install/common.sh` now runs `aiconman/config.py` as a script, which prints the settings as shell assignments, and its own `.env` fallback is gone. `.env` is now read by Python, one `KEY=value` per line, with quotes around a value removed and nothing else interpreted; a line that is not `KEY=value` is refused, naming its line. As before, a secret in the calling shell's environment is not read.
- **What the backend needs from the configuration**, the agent's reading of the template: the server's address and `public_url`; the database and the app role, not the owner; the storage folder; the sign-in settings; and the connections' key. Nextcloud's settings and `auth.state_secret` are needed only while Nextcloud sign-in is on. With both ways of signing in off, password sign-in is on, as the template says. Nextcloud's addresses are made from `instance_address`, and `redirect_uri` from `public_url`, unless set.
- **`aiconman/db.py`** connects as the app role and calls the schema's functions, the only thing that role may do. A function's refusal, SQLSTATE `AI001`, becomes `Refused` with its key.
- **`aiconman/app.py`** answers a refusal with its key as JSON, `{"error": "last_admin"}`, and an HTTP status: 401 for a session that cannot be used; 403 for a person not allowed, `not_admin`, `password_change_required`, `deactivated` and `sign_up_closed`; 404 for a key naming something that does not exist; 409 for one naming something taken; 400 otherwise. `GET /api/health` says whether the backend reaches its database and finds the schema seeded.
- **FastAPI's own documentation pages are off.** Fetched from a default FastAPI application in the agent's process, `/docs` loads from `cdn.jsdelivr.net` and `fastapi.tiangolo.com`, and `/redoc` also from `fonts.googleapis.com`; the interface loads nothing from outside the household's network (`the-interface.md`).

## How it is tested

- **The standard library's `unittest`**, so no test library is added; the tests are in `tests/backend/`.
- **No server is started and no port is touched.** The application runs inside the test's own process, reached through HTTPX's transport for an application. Starlette's test client, which FastAPI offers, warned on import that using HTTPX with it is deprecated, so it is not used.
- **`tests/backend/test_config.py`**, 18 tests on configurations in temporary folders, needs no database: secrets from `config.yml`, from `.env`, and which wins; `.env`'s quotes, comments and blank lines, and a line refused; the calling shell not read; a missing file, a file that is not YAML, a setting missing, a port and a switch of the wrong type; password sign-in on when both are off; Nextcloud's settings needed only when its sign-in is on, its addresses made and overridden; the templates, filled in, loading; and the script's shell assignments, read back by bash, a quote and a dollar sign intact.
- **`tests/backend/test_app.py`**, 6 tests against the scratch database as the app role, refusing to run without `AICONMAN_CONFIG_DIR` or with it naming `config/`: the health check; the documentation pages answering 404; refusals answered with their key and status; a function's rows; a refusal coming back as `Refused` with its key; and the app role refused a table. They pass with deprecation warnings raised as errors.
- **Two copies with a rule broken** each fail the test for it: refusals not recognized as such, and every refusal answered 400.
- **The scripts' tests pass through the new reader**: `tests/install/test_create_database.sh`, with its `.env` cases, `tests/install/test_build_schema.sh`, and `tests/db/run.sh`.
