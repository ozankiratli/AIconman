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
