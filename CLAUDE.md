# Working on AIconman

AIconman, the AI Connection Manager, is a web interface for using language models that people run on their own machines, together with a public account of how to set those machines up and connect them. Z, 2026-10-11: *"We build something that works on my network, and build the framework for everybody. Make it accessible and private. The interface we develop should be independent of what is built on user's ends. It should work as long as it is reachable from their own network."*

**It is for a local network or a VPN, and nothing else.** Z, 2026-10-11: *"we will make it clear that this is only for LAN/VPN applications. The user should make sure that nothing is exposed to internet."*

**Each person has an account, and keeps their chats.** Z, 2026-10-11: *"there are multiple people in a household and people might want to keep their chats etc."* An account signs in with a password or through Nextcloud, and the data lives in PostgreSQL, with other databases to come.

**It is for people who already run their own models.** Z, 2026-10-11: *"The audience for this tool, already deployed one or more LLMs successfully in their network."* The interface and the documentation are written for that reader.

**A server's limits are its owner's business.** Z, 2026-10-11: *"The time is not an issue here. People running their own servers will know their own limitations. Do not raise this further."* The interface does not warn anyone about how slow or how small their server is, and the agent does not raise it in design.

The brief as Z gave it, and what was settled with it, is in `.claude/development-notes/product-brief.md`.

## Ground rules

### Transparency

Z, 2026-10-11: *"I want to be transparent about the development process. It is one of the core values all my projects share."*

- **The record is public.** This file, `.claude/development-notes/`, `dev/READING-LOG.md` and `SOURCES.md` are tracked and published with the code. Write them for a reader outside the project who arrives skeptical and checks.
- **Z drives.** Z calls the method human-in-the-steering-wheel development, as opposed to human-in-the-loop: the human drives, rather than approving what the agent drives. So the record says who decided what and when, in Z's words where there are any, and marks what the agent proposed as the agent's.
- **Every important step is logged.** Each step either of us takes -- something built or changed, a read, a check, a commit, a correction -- gets a row in `.claude/development-notes/01-project-log.md` when it happens, so that an agent months later can recover what was done. What Z says, and the writing of it into the notes, do not get rows. Once committed, a row is never rewritten or removed; only its Notes are filled in later, when the action turns out wrong, is reverted, or a decision changes.
- **Mistakes are recorded, not smoothed over.** A slip, a claim that turned out wrong, a change that was reverted: each goes into the notes with what happened and how it was found.
- **The agent never writes that Z verified, approved or cleared something.** Those lines are Z's to write, and the agent's own checks are never presented as Z's.
- **Transparency covers the process, not Z's network or anyone's conversations.** What stays out is under *What stays out of the agent's context and the repository*.

### Subagents

Z, 2026-10-11: *"You should always ask before deploying subagents. When doing that you should tell me about the extent of the work and number of agents proposed. Subagents should not start subagents themselves. All agents should run as Sonnet unless we decide something else is needed. And the hard cap for the agents is 5 at a given time."*

- **Ask first, every time.** The ask says what the work is, how far it reaches (which files, sources or questions), how many agents, and what each one does. A go-ahead covers the agents it named and nothing started after them.
- **At most five agents at a time.** It is a hard cap, and it counts every agent running, background agents included.
- **Every agent runs as Sonnet**, with the model set explicitly when the agent is started rather than left to a default. Another model is used only when Z decides it, and the decision is recorded.
- **Agents do not start agents.** Every brief says so, and where an agent type exists that has no means of starting one, that type is used.
- **The rule covers every way an agent gets started**: the Agent tool, a workflow, and a skill that runs itself in a subagent or coordinates subagents. Before invoking a skill, check whether it does either.
- **A brief carries the rules that bind the agent**, the rule on other people's code among them, together with the log entry for any outside read the agent is to make.
- **An agent's report is model output, not a finding.** Before anything from it is used, its load-bearing claims are checked against their primary sources, and what the check found wrong is recorded with the rest.

### Other people's code

Z, 2026-10-11: *"We need rules about reading code from other projects. However, this rule applies to only projects developed by other people."*

The reason is responsible use of AI agents: there is already a lot of backlash against agents because they plagiarize and their output is stolen work, and Z uses agents to show that they can be used responsibly. The nearest sources are other chat interfaces for self-hosted models, Open WebUI and LibreChat among them, and the servers AIconman talks to, Ollama, llama.cpp and vLLM among them. They do much of what AIconman does, which makes them the likeliest to become its authority without anyone deciding it.

None of what follows is relaxed for convenience, for speed, or because a fact seems small.

- **No code from another person's project goes into AIconman**, whether copied, adapted or translated into another language. A library Z has approved by name, carried whole under its own license and credited, is the only exception. Approved so far: FastAPI, as the backend framework (Z, 2026-10-11, with the defaults in `product-brief.md`); Tabler Icons, MIT license, for the icons (Z, 2026-10-11); and Source Serif Pro, SIL Open Font License 1.1, for the title, shipped unmodified (Z, 2026-10-11); and Font Awesome Free's Nextcloud icon, CC BY 4.0, for the *Sign in with Nextcloud* button, cropped to the mark by its frame alone, which its license allows with the attribution kept and the change stated (Z, 2026-10-11). The icon is one file adapted rather than a library carried whole, and is listed here because Z decided it. The last three are in `the-interface.md`. And PyYAML, MIT license, for reading `config/config.yml` (Z, 2026-10-11). And ShellCheck, GPL-3.0, as a development tool that lints the shell scripts, installed through the `shellcheck-py` package, MIT license, which carries its binary (Z, 2026-10-12). And, added for the backend at Z's word and under Z's review, Uvicorn, python-multipart, HTTPX, psycopg and cryptography, with the packages they bring (Z, 2026-10-12: *"Add libraries that are needed to requirements.txt I will review and raise questions if I have them. This should not be a blocker for the work."*); their versions and licenses are in `SOURCES.md`. Python packages AIconman needs are installed into `.venv` from `install/requirements.txt`, and development tools into `dev/.venv` from `dev/requirements.txt` (Z, 2026-10-12), each pinned to the version tested.
- **Reading another person's code is always harnessed: named, recorded, cleared and done, in that order.** This covers any file of their source: a clone, a web page that shows the code, a search result that quotes it. It binds any agent the agent starts.
  1. *Name*: the task the read serves, the source (its file or section, at a commit or a URL), and the facts it is for.
  2. *Record*: an entry in `dev/READING-LOG.md`, written before anything is opened.
  3. *Clear*: Z writes the entry's *Cleared* line. The agent never writes it.
  4. *Do*: read only what was cleared, for the facts named, then add to the entry what was found.
- **Only facts come out of it**, never the design and never the decisions.
- **No other project is an authority on AIconman.** How AIconman behaves is Z's decision. That another project does something differently is not an argument, and its way of doing it is not a default.
- **A published specification is the source wherever one exists**: the OpenAI API reference for the protocol most servers speak, and each server's own API documentation. Documentation a project publishes for its users goes through the reading log too: the agent proposes the read as an entry in `dev/READING-LOG.md`, and Z decides (Z, 2026-10-11: *"Create reading log for me to edit and clear."*; 2026-10-12: *"You can always propose the reads there and I can decide."*). It is listed in `SOURCES.md`, with what was learned from it.
- **A gap goes to Z, not to the nearest source.** When the sources already cleared leave a fact open, the agent stops and names the gap. Z decides where the fact comes from, or that it is left out.
- **Facts cross over in writing.** A fact from another person's code is written into a note under `dev/facts/` first: what it is, where it sits, in what order and in what units. The note cites its log entry and quotes no code. Code is then written from that note, in a new session whose context has never held the other implementation. A compacted session is not a new one.
- **Every source is listed in `SOURCES.md`**, with what was learned from it.
- **A project with no license is read for facts only**, and none of its text is reproduced.
- **A slip is stopped and recorded.** A slip is a read that skipped a step or went beyond what was cleared. The agent stops, tells Z exactly what was read, and records it in the log. Nothing learned from it is used until Z has ruled on it.
- **Z's own work is outside this rule.** Z's other projects, and the files Z brings into this repository, are Z's to reuse here. Reading one of Z's other projects still waits for Z to ask for it or agree, as any action does under *Ask before acting*.
- **AIconman reads as its own project, so Z's other projects are not named in it**, outside `.claude/development-notes/00-initialization-of-the-project.md` and the project log's row of the read it records. When a quotation of Z names one, the name is replaced in the quotation by a bracketed description, such as *[Z's other project]*. Before handing over a note, search it for the names.

### Ask before acting

The rule is about control over Z's machines and Z's time, not about danger, so "it was only a read" is not an exemption once Z has said it.

- **Always asked first:** starting or stopping any process, anything that touches a port Z is working on, any destructive operation, and any verification run longer than a moment. Size a run to what is actually unproven.
- **A request to one of Z's model servers is an action on Z's network**, and is asked for first. It can load a different model for everyone else using that server.
- **Never terminate a process that was not started in this session.** No `pkill` or `pgrep` by name: both match across the whole machine. Record the PID when starting something, and stop only that PID.
- **Never SSH to a host without permission.**
- **Never drive the instance Z is working in.** Verification gets its own server on its own port.
- **This project's ports on Z's machine** (Z, 2026-10-11): 8642 is AIconman itself, and 8643 serves the manual's website while it is written. 8644 is for the servers the agent starts to test with (Z, 2026-10-12: *"Of course you can use it."*); the agent records the process id of each and stops only that process. Z develops many projects on this machine, so no other port is used without asking.
- **This project's databases on Z's machine** (Z, 2026-10-11), in the PostgreSQL that runs here: `aicm_db` is Z's, and the agent runs nothing destructive against it, and nothing else without asking; `aicm_scratch_db` is where the agent tests, and may be destroyed and rebuilt. The scratch database has roles of its own, `aicm_scratch_db_admin` and `aicm_scratch_db_app`, and its configuration is in `.tmp/scratch/config/`, which is treated like `config/` (Z, 2026-10-12). Every script the agent runs against a database is given `AICONMAN_CONFIG_DIR=.tmp/scratch/config`, never left to default to `config/`, which is Z's.
- **AIconman supports PostgreSQL 16 and newer** (Z, 2026-10-12: *"We should try to make it PostgreSQL 16+ compatible at least"*). This machine runs 18, so nothing added after 16 is used, and that stays unproven until the schema has run on a 16 server.
- **Confirm before anything destructive or outward-facing**: a wipe, a deploy, a restart of a live service, a push.

### What stays out of the agent's context and the repository

**The agent's context is not local.** Reading a file sends its contents to Anthropic's servers, and the repository is public.

- **No real secret is read into the conversation**: an API key, a token, a password, or the configuration file that holds one. Development and checks use keys made up for the purpose. A check that needs a real key is run by Z.
- **`config/.env` and `config/config.yml` hold real secrets.** No value in them ever reaches the conversation: never print, show or quote them, and never open them with `Read`. A script may look inside only to report what reveals no value -- which keys are present, whether a value is empty, how long it is. A secret the agent makes is written straight into its file by a command that does not print it. Z may have either file open; change it by adding to it, never by regenerating it, unless Z agrees.
- **Z's network stays out of the repository**: host names, addresses, domain names, firewall rules, and which machine runs what. Not in code, documentation, notes, commit messages or screenshots. Examples use placeholders. `.tmp/` is ignored by git and holds Z's private material; nothing from it is copied into a tracked file without Z's approval of that item.
- **What anyone says to their models stays theirs.** No conversation with a real model, Z's included, goes into the repository, a note or a screenshot unless Z approves that item by name.

### How work is reviewed

- **Never `git push`**, or anything else outward-facing: no `gh pr create`, no release, no remote branch. Z publishes. `git stash push` reads as a push in a command line, so say beforehand that it is local, or avoid it.
- **Never `git commit` unless asked, and a commit instruction covers only the work that existed when it was given.** Do the work, leave it uncommitted, say what changed in prose, stop. The uncommitted tree is the review surface; a diff artifact or a summary page is not a substitute.
- **Use the `Edit` tool for changes to an existing file, never a script that rewrites it.** Z reviews side by side in the IDE diff view as each edit lands. An announced mechanical rename with `sed` is the one exception.
- **One change at a time.** Finish one item, say exactly what changed, what the agent checked and what is left for Z to check, then stop. Keep a list of deferred items and restate it at the end of each turn.
- **Do not overstate severity.** "Bug" is for behavior that is wrong, not behavior that is unidiomatic or different from before. Describe what was measured and let Z judge; a preference is offered as a preference.

## How decisions are made

- **Z decides.** Ask when two readings would produce materially different work. Otherwise decide, say what was decided, and carry on.
- **A suggestion Z does not take up is rejected, not pending.** Recording it as still open is how documentation rots.
- **Fail loudly, or document -- never automate away a decision.** Where the right answer depends on something the application cannot know, it says so and stops. A computed default never removes the knob.
- **Settle a design question with data rather than argument, where data can settle it.** Build the case that would distinguish the two claims, run it, and read what comes back.

## Comments: what the code does, never why we chose it

**Every comment clause is either a description of the code below it or a design decision. Descriptions stay, in one line. Decisions move to `.claude/development-notes/` and leave the source.**

The unit is the clause, not the comment. The usual failure is a comment that opens with a real description and smuggles a justification in after it. Write what the code does, stop, and check whether what you were about to add next is a decision.

**Why:** a design decision left in a comment reads to a later session as a current constraint, and gets argued from against what is actually being asked.

Not every "why" is a decision. The cut is whether the code becomes **inexplicable** without the line, or merely **unjustified**. A constraint that makes an otherwise pointless line explicable is what the code does, and stays. A constraint that defends one working choice over another is a decision, and goes.

Before calling a file done, grep for `on purpose | deliberately | rather than | because | would otherwise | so that | which is why`. Each hit is a candidate, not a verdict, and the grep is never made a pass/fail gate: a hard failure trains the next session to reword around the words instead of removing the decision.

| Where | What |
|---|---|
| the source | what the code below does, what it returns, a coupling or constraint invisible from here |
| the user documentation | what a person setting up or using AIconman needs. It is authoritative, and nothing in it is repeated in the source. It is the manual, `docs/manual.md`, which the README points to and a website is later built from. |
| `.claude/development-notes/` | how it got here: design churn, alternatives dropped, measurements, who decided what and when |

**No source file references the notes.** A note is dated and not updated to follow the code, so a pointer to one imports a description of the code as it used to be.

**The templates are not source.** `config.yml.template` and `.env.template` are copied and filled in by the person setting AIconman up, and their comments are the only help at the point of use, so the comment rule does not apply to them. Do not cut them without asking.

**Mid-feature is not the deadline, but the feature has one.** A comment may carry more than the code needs while a stage is open; every stage ends with a pass over the comments it added. Put that pass in the stage's checklist when the stage starts, or it is the thing that gets skipped.

**Development tooling follows the opposite rule: keep everything but abandoned ideas.** There the reasoning is the content. The one thing to cut is an approach that was dropped, described as though it were still how things work.

## Development notes

`.claude/development-notes/` is the record of how AIconman got here, one file per subject rather than per source file.

- **Every note opens with `**Written <date>, against the tree at <hash>.**`** and is never rewritten to follow the code. Appending a new, dated finding is allowed; correcting an old description to match today's code is not. Where a note and the user documentation disagree, the documentation is right and the note is history.
- **A file that is kept current says so in its first line**, and the index lists which ones are. The index, `README.md`, is one of them.
- **Durable knowledge goes here, not only into the agent's memory.** Memory is private to one account and nobody can review it; a note is a reviewable artifact that travels with the checkout. The memory entry is a one-line pointer to the note.
- **A note hands its reader the command that would falsify it**, rather than asserting a count or a mechanism in prose.
- **The notes are public.** Nothing from *What stays out of the agent's context and the repository* goes into one.

## How to know a change works

- **The tests are in `tests/`**: `tests/install/` for the install scripts, and `tests/db/` for the schema, in plain SQL (Z, 2026-10-12). `tests/install/test_create_database.sh` needs no database; `tests/install/test_build_schema.sh` and `tests/db/run.sh` run against the scratch database, with `AICONMAN_CONFIG_DIR=.tmp/scratch/config`, and refuse to run without it. The backend's tests are in `tests/backend/`, run with `.venv/bin/python -m unittest discover -s tests/backend` from the repository's root; `test_app.py` needs the scratch database the same way, and starts no server.
- **Render it, don't read it.** Reasoning about what code produces has repeatedly produced confident wrong answers.
- **Name the suite that would fail if the change were wrong, and run that one.** If there is none, that is the finding. If there is one and it cannot run, say so out loud rather than reporting the rest as green.
- **A check that cannot fail is not a check.** When a check passes, ask what it would have taken for it to fail.
- **Look at the output**: the screenshot, the rendered page, the actual bytes.
- **Read the whole output of anything run**, not its tail: the end of a failure summary can read as a list of passes.
- **Intermittent means timing or order.** Test that directly before editing anything.
- **Revert a change whose reason was disproved.** A change justified by a false hypothesis is worse than none, because the comment outlives the bug.
- **Two things that must agree are derived from one source**, never kept in step by hand.
- **After any move, rename or filter, ask what was pointed at the old thing**, and grep for it. A check aimed at something that moved keeps passing over nothing.
- **Say what was checked, and show the output**, separately from what is left for Z to check, and name what was not checked.

## House style

- **American English everywhere**: interface strings, comments, docstrings, documentation, commit messages.
- **ASCII only in the text we write**: `--` for a dash, `...` for an ellipsis, `->` for an arrow, straight quotes. Four things are exempt: data we did not author, a character that is the subject of the sentence, a glyph the running application renders, and a literal whose other half a text tool cannot reach.
- **No hard wrapping in markdown.** One line per paragraph and per list item.
- **Prose, not bullets, where an argument has to be followed.**
