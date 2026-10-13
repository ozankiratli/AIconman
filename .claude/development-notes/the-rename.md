# The rename to LMconman

**Written 2026-10-13, against the tree at `4915cd3`.** Nothing is renamed yet; this note is the preparation Z asked for.

Z, 2026-10-13: *"Before we continue. We're changing the name of the project from AIconman to LMconman (and LMcm for short). The logo design will change to "man" part becoming (very dark gray for light theme and a very light gray for dark theme). Make preparations, and let me know when we're ready. I'll change the name of the project on GitHub, then we will update the links etc."*

## Where the name is

In the tracked files and the new ones, in five forms: the name itself, `AIconman`, with its expansion *AI Connection Manager*; the Python package, `aiconman`, with its paths, imports, the cookie's default name and the example addresses; the environment variables, `AICONMAN_*`; the short form, `aicm_`, in the database's and its roles' names; and the refusal code `AI001`, the name's initials. To list them:

    git grep -c -i -E "aiconman|aicm|ai connection manager|AI001"

Outside the repository: Z's `config/.env` names six variables `AICONMAN_*`, and Z's `config/config.yml` holds the name in seven values (`public_url`, `dbname`, `adminuser`, `user`, `root_path`, `cookie_name`, `redirect_uri`); the scratch configuration in `.tmp/scratch/config/` the same. These were counted by key, without printing a value. The git remote is `git@github.com:ozankiratli/AIconman.git`; nothing tracked links to the repository on GitHub. No crontab line names it. Both virtual environments, `.venv` and `dev/.venv`, hold the folder's absolute path, and so does the folder of the agent's memory, which Claude Code names after the project's path.

## What changes, and what stays

**What is current changes**: the code, the scripts, the tests, the templates, the manual, the README, `CLAUDE.md`, `SOURCES.md`, and the notes kept current (`README.md`, `planned.md`, and the project log's header).

**What is history stays as it was written**: the dated notes, which are never rewritten to follow the code (`README.md` of these notes); the project log's rows, which are never rewritten once committed; the reading log's entries; the finding in `platform-traps.md`, which quotes a command as it then was; the commit messages; and every quotation of Z. A line in the notes' index will say that notes written before the rename call the project AIconman.

**One line of code stays too.** `aiconman/keys.py` derives the encryption of the connections' stored keys from the text `aiconman connection key`, used both as HKDF's `info` and as AES-GCM's associated data. Changed, it would make every key already stored unreadable, each refused as `key_undecryptable` until the admin entered it again. The agent proposes keeping it, with a comment on the line saying that changing it makes stored keys unreadable, so that a later rename does not "fix" it.

**The mapping the agent proposes**, for Z to change: the package `lmconman`; the variables `LMCONMAN_*`; the short form `lmcm_` for the databases and their roles; the cookie's default name `lmconman_session`; the refusal code `LM001`; the example address `lmconman.example.lan`, and the storage path `/var/lib/lmconman/storage`. A cookie of the old name is no longer read, so every session ends once; there are no users yet.

**Prepared, not run:** a script in the agent's scratchpad that makes the mechanical part of the rename over the tracked files, skipping the history above, any occurrence inside a quotation of Z, and the line in `keys.py`. Its dry run, on 2026-10-13, changed nothing and counted 282 replacements in 43 files: `AIconman` 95, `aiconman` 58, `AICONMAN_` 120, *AI Connection Manager* 4, `AI001` 5. It found no occurrence inside a quotation, and left the 16 project-log rows that name it. The database names are a further option of the script, for Z's answer below. Run, it is the announced mechanical rename `CLAUDE.md` allows, together with `git mv aiconman lmconman`.

## The brand

The brand is the name in Source Serif Pro Bold Italic, in two tones until now: "AI" in the brand blue and "conman" in Z's summer-green, each fitted to the theme (`the-palette.md`). Renamed, it is three tones: "LM" in the blue, "con" in the green, and "man" in the gray Z asked for.

**The agent's proposal:** "man" in each theme's own text color: `#252a34` in light, `#eaeaea` in dark, `#0f1115` in light HC, and `#ffffff` in dark HC. These are the very dark and very light grays the themes already have, they meet the text target by construction, and they follow any change to the themes. The light themes' text is a slightly blue gray; a neutral gray of the same lightness, `#2a2a2a` and `#111111`, was rendered beside it, and the two are hard to tell apart. In the high-contrast themes the text color is white and near black, which is the strongest gray there is; Z may prefer the dark theme's `#eaeaea` in dark HC as well.

Rendered on 2026-10-13 in the agent's scratchpad, with the palette scripts' values and the title font, at the sidebar title's size and at a large one, on all four backgrounds: the three parts read as three, at both sizes, in every theme. `dev/palette/` draws the two-tone brand today, and changes with the rename.

## The order, once Z has renamed the repository

1. Z renames the repository on GitHub; the remote is then pointed at the new name with `git remote set-url`, a local change.
2. The mechanical rename, by the script, and `git mv aiconman lmconman`; then by hand: the comment on the line in `keys.py`, the brand in `dev/palette/` with a dated finding in `the-palette.md`, and the line in the notes' index.
3. The configurations, in step with the code, since the code reads the variables by their new names and finds nothing under the old ones: in `.tmp/scratch/config/.env`, the six variables' names, by a command that changes names only and prints nothing; in Z's `config/.env`, the same, by Z or by that command at Z's word; the values in Z's `config/config.yml` are Z's.
4. If the databases are renamed: Z renames them and their roles as PostgreSQL's superuser, with no session open on them, and the configurations take the new names. Z's database also still needs the rebuild the context meter asked for.
5. Every test, ShellCheck, and a search for what remains outside history.
6. If the folder is renamed: both virtual environments recreated from their requirements, since each holds the old path, and the agent's memory moved to the folder named after the new path.

## Asked of Z

1. **The long name:** *LMconman, the Language Model Connection Manager*?
2. **The databases:** rename `aicm_db`, `aicm_scratch_db` and their four roles to `lmcm_`, or keep the names, which are configuration and work as they are? The agent proposes renaming, so the short form means one thing.
3. **The gray:** each theme's text color, as proposed, or another value?
4. **The folder:** is the local folder to be renamed too?

## Added later on 2026-10-13, against `50e7558`: the rename, done in the working tree

Z committed the preparation as `50e7558`, *"llama-serve work prep, project name change prep"*, pushed it, and renamed the repository: *"OK. Pushed. Changed the name of the repo. It is now LMconman.git"*. While the work ran: *"Don't create commits."* None was made; everything below is in the working tree.

The agent read *"OK."* as accepting its proposals for questions 1 and 3: the long name is *LMconman, the Language Model Connection Manager*, and "man" takes each theme's text color (`the-palette.md`). Questions 2 and 4 ask for Z's own actions, and wait.

**Done, on 2026-10-13:**

- The remote points at `git@github.com:ozankiratli/LMconman.git`, set locally; nothing was fetched or pushed.
- The script made its 282 replacements in 43 files, as its dry run had counted, leaving the history, Z's quotations and the line in `keys.py`; the package moved by `git mv aiconman lmconman`, which stages the move and nothing else. Outside the history, the old name is left only on that line, which now carries a comment saying that changing it leaves every stored key unreadable.
- The one line the longer name made overlong, in `lmconman/__init__.py`, was wrapped again by hand.
- The brand is drawn in three tones in `dev/palette/` (`the-palette.md`).
- The index of these notes says the notes before the rename keep the old name.
- The six variables' names in `.tmp/scratch/config/.env` were renamed by a command that changed names only; a hash of the values, the same before and after, showed the values untouched, without printing them.

**Checked:** the schema's 270 checks, both install tests, the backend's 95 tests, and ShellCheck pass, run with `LMCONMAN_CONFIG_DIR`. With only the old `AICONMAN_CONFIG_DIR` set, the schema's tests and the backend's both refuse to run, so nothing reads the old name. To find what is left:

    git grep -n -i -E "aiconman|AI001|AI Connection Manager"

which, outside the history listed above, finds only the line in `keys.py` and the index's sentence naming the old name.

**Left:**

- **Z's `config/.env`:** its six variables still have the old names, so Z's configuration gives the renamed code no secrets until they are renamed, by Z or by the same command at Z's word.
- **Z's `config/config.yml`:** seven values hold the old name, among them the cookie's name and the address; they are Z's, and the code works with them as they are.
- **The databases** (question 2) and **the folder** (question 4).
- The comments of the scratch configuration's `config.yml` still say AIconman; its values work as they are.

## Added later on 2026-10-13, against `50e7558`: the databases and the folder

Z: *"1. Done. 2. Prepare SQL. give me the command, I'll run it. 3. Let's do the renaming"*. Z renamed the six variables in `config/.env`; the file on disk still had the old names when the agent looked, and Z: *"Forgot to save it."* Saved, it has the six new names, read by name only.

**The databases.** The SQL that renames `aicm_db`, `aicm_scratch_db` and their four roles to `lmcm_` is in the agent's scratchpad, for Z to run as PostgreSQL's superuser. It runs in one transaction, and first stops if any of the four roles is missing or its password is not stored as SCRAM: a role's password follows it through a rename unless it is stored as MD5, which a rename clears. That is the agent's knowledge of PostgreSQL, not something read for this project. Ownership and grants follow a renamed role or database. Run against the scratch database as its admin, which may not read `pg_authid`, the check was refused there, psql stopped, and nothing was renamed: its block parses, and an error stops the script before any rename. The renames themselves were not run; they need the superuser. Once they are, the three database settings in Z's `config/config.yml` and in the scratch configuration take the new names.

In the current files, the database names changed by the same script, `aicm_` to `lmcm_` only: 19 replacements in six files, `CLAUDE.md`, `planned.md`, the configuration template, the manual and two tests. `CLAUDE.md` and `planned.md` name `lmcm_db` and `lmcm_scratch_db` from now on, which holds once Z's SQL has run.

**A near miss, caught by the dry run.** The script kept the line in `keys.py` by its path, `aiconman/keys.py`; after `git mv` the file is `lmconman/keys.py`, and a second run with every rule would have changed the line, and with it every stored key. The dry run before this run showed it, together with the index's sentence naming the old name, which it would also have rewritten. The script now keeps the line by its content wherever it is, and this run applied only `aicm_` to `lmcm_`. Nothing was changed before the dry run showed it.

**The folder.** A script in the agent's scratchpad, for Z to run from outside the folder with VS Code closed: it renames `AIconman` to `LMconman`, points the scratch configuration's storage path, which lies inside the folder, at the new one, makes both virtual environments again from their pinned requirements with the Python that made them and compares their packages with the old ones, and copies the folder in which Claude Code keeps the agent's memory and sessions to the one named after the new path. It stops before changing anything if the old folder is missing, the new one exists, or it is run from inside the old one. ShellCheck passes it. Rehearsed in a sandbox, a copy pointing at a made-up folder with real but empty environments: run from inside, it refused and moved nothing; run from outside, every step ran, the storage path moved, the packages matched, and the memory was copied.

**Added later on 2026-10-13:** Z: *"I did 1 and 2."* Z ran the SQL and renamed the three database settings in `config/config.yml`; read by their first letters only, all three begin with `lmcm_`. The agent renamed the same three in the scratch configuration, by a command that changed only `aicm_scratch_db` to `lmcm_scratch_db`, on three lines. The server's catalogs, which any role may read, now name `lmcm_db`, `lmcm_scratch_db` and their four roles, and nothing beginning with `aicm`. Against the renamed scratch database, signing in under the new names with the passwords it had before, the schema's 270 checks, both install tests, the backend's 95 tests and ShellCheck pass. Left: the folder.

**Added later on 2026-10-13:** Z ran the folder's script at 16:54, by the times of the package lists it wrote, and: *"Everything complete. Confirm."* What the agent checked, from the new folder: the old folder is gone; both virtual environments were made again at the new path, by `/usr/bin/python3`, and `pip freeze` lists the same packages at the same versions as before the rename, 24 in `.venv`; the scratch configuration's storage path is under the new folder, and no line of either configuration names the old one; the agent's memory in the folder named after the new path is identical to the old one; no tracked file names the old path; the remote names `LMconman.git`. The schema's 270 checks, both install tests, the backend's 95 tests and ShellCheck pass. The rename is complete, and uncommitted.
