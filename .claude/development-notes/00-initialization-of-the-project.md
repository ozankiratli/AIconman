# Initialization of the project

**Written 2026-10-11, against the tree at `b8de0d5`**, the initial commit. `CLAUDE.md`, these notes, `dev/READING-LOG.md` and `SOURCES.md` were uncommitted and under review. No code had been written.

This note records where AIconman's working rules came from. The rules themselves are in `CLAUDE.md`, and what each ground rule is for here is in `ground-rules.md`; neither refers to another project. Z, reviewing the first draft: *"This project has to read as its own project with its own rules."* So the history of where a rule came from is kept here, once, and nowhere else.

## The request

Z asked for the rules before any work on the project itself:

> I forgot one thing. Before we start the project. We need to create CLAUDE.md and .claude/development-notes/ similar to my other projects. See PoolSeqFlow, and PAPvault projects (PAPvault is health data related so some stuff might not apply here). One change I want to make for this project is to start with ground rules in CLAUDE.md. Including the use of subagents.

At Z's request the agent read, from PAPvault: `CLAUDE.md`; the notes index, `ground-rules.md`, `other-projects.md`, `product-brief.md`, `planned.md` and the head of `platform-traps.md`; the header of `dev/READING-LOG.md` and its first entries; the head of `SOURCES.md`; `README.md`, `.gitignore` and `.gitattributes`. From PoolSeqFlow it read `CLAUDE.md` and the head of the notes index. Both are Z's own projects, which the rule on other people's code does not reach.

## What came across

What came across is whatever does not depend on what is being built.

**From both projects:** the comment rule and its three destinations; the dated-notes convention; and the review loop -- never push, commit only what was reviewed, change files with `Edit`, one change at a time, and do not overstate severity.

**From PAPvault:** the account of the project written for a reader who arrives skeptical and checks; the principle that the agent's context is not local, applied here to secrets and to Z's network instead of to health data; the reading log and its entry format, and its place at `dev/READING-LOG.md`; `SOURCES.md`; the rule that an agent's report is model output and not a finding; and *How decisions are made*.

**From Z's instructions for every project**, which are private to Z's machine: *Ask before acting*, the bans on terminating processes by name and on SSH without permission, the separate server for verification, *How to know a change works*, the house style, the rule that a suggestion Z does not take up is rejected, and the general form of the rule on other people's code. They are written out in `CLAUDE.md` because a reader of this repository cannot see the private file, and a rule the reader cannot see is a rule the reader cannot hold the agent to.

## Where the first draft's quotes and examples came from

The first draft of `CLAUDE.md` named the project each of these came from. After Z's review they were taken out of `CLAUDE.md`, and the attributions are kept here.

- **Human-in-the-steering-wheel development** is Z's name for the method, first written down in PAPvault on 2026-09-18.
- **The rule on other people's code** took its present form in PAPvault on 2026-09-19. The agent read another project's reader there to fill gaps a published specification left, and Z stopped it. The account is in PAPvault's `.claude/development-notes/other-projects.md`.
- **Z's own work is outside that rule.** Z, on PAPvault, 2026-09-20: *"Copying or reading a workflow from my own repository is like using my own hammer to put a nail on the wall."*
- **The reason for the comment rule.** Z, on PoolSeqFlow, 2026-08-30: *"In multiple occasions, the previous design decisions have skewed your interpretation of my asks, we had to spend way too much time on simple tasks."*
- **Reading the whole output of anything run.** In PoolSeqFlow the tail of a failure summary was read as a list of passes.

## What was left behind

**PAPvault's rules about health data**: real device data, the synthetic data workflow, displaying without concluding, reading only night data, and the security rules built for a page served from GitHub Pages. They answer PAPvault's promise, not AIconman's.

**PoolSeqFlow's rules about its stack**: Nextflow, the table of test suites, the release procedure, and the typography of its manual.

**Everything with nothing yet to govern**: the port a verification server uses, a test suite, a checklist and a verification record, a release process, and where the user documentation lives. Each comes back, written for AIconman, when there is something for it to govern. A rule about a tool that is not in use is a rule nobody can check, and it reads to a later session as a constraint on a choice that has not been made.

**PAPvault's count of kept-current notes.** PAPvault's index says two files are exempt from the dating rule, and its `planned.md` became a third without the count changing; `planned.md` says so itself. Here a kept-current file says so in its first line and the index marks it, so there is no count to fall out of step.

## How the rules differ from where they came from

**Subagents.** PoolSeqFlow's rule was to confirm first, never more than five, always Sonnet. PAPvault's was a go-ahead, Sonnet, at most four at a time. What is new in AIconman is what the ask must say, the ban on agents starting agents, and the cap counted at a given time.

**Other people's code.** The rule is the general form from Z's instructions for every project, with PAPvault's exception for Z's own work written in. PAPvault harnessed every outside source. The first draft here harnesses only code, and leaves published documentation to `SOURCES.md`; `ground-rules.md` records that as the agent's reading.

**Transparency.** In PAPvault the value was spread through the opening of `CLAUDE.md` and the notes. Here it is a ground rule of its own, in Z's words.

## The first platform trap

The zsh trap that opens `platform-traps.md` was already recorded in PAPvault's `platform-traps.md`, found there on 2026-09-18. The agent had read that entry earlier the same session and still fell into it.

## Z's review of the first draft

Z: *"OK. This mostly good. In ground rules md there are too many references to other projects. We can get rid of other project references in that file. If you want to keep where those decisions come from we can move all those into another file 00-initialization-of-the-project.md or something that it always shows at the top of the list too. This project has to read as its own project with its own rules."*

The agent took the last sentence to cover `CLAUDE.md` and the other notes as well as `ground-rules.md`, and moved every reference to PoolSeqFlow and PAPvault into this note. To check that none is left elsewhere: `grep -rn -E 'PAPvault|PoolSeqFlow' CLAUDE.md SOURCES.md dev .claude/development-notes` should print lines from this file only.
