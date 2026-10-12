# Development notes

**This file is kept current.** It is the index, and an exception to the dating rule below.

These notes record why AIconman is built the way it is: decisions and who made them, what was tried and dropped, what a choice was measured against, and the traps that produced a wrong answer once already. They are not user documentation, and they do not explain what the code does -- that stays in the code. They are the reasoning a person needs before they *change* something.

They are public, and so is `CLAUDE.md` at the repository root, the file the agent reads at the start of every session. Z, 2026-10-11: *"I want to be transparent about the development process. It is one of the core values all my projects share."* How AIconman is built should be as readable as what it does.

## These notes are dated

**Every note records the tree as it stood when it was written, and says so in its first line:**

```
**Written <date>, against the tree at <hash>.**
```

A note is never rewritten to follow the code. It may gain a new finding at the end, dated; an old description is never corrected to match today's code, because a note that has been kept in step can no longer be dated. So a present-tense sentence inside a note describes the code at that note's date. Where a note and the user documentation disagree, the documentation is right and the note is history.

**A file that is kept current says so in its first line**, and the table below marks it. That is the only exception to the dating rule.

**A note hands its reader the command that would falsify it**, rather than asserting a count or a mechanism in prose.

## What never goes in a note

**Nothing private.** No secret, nothing about Z's own network, and no conversation with a real model. The rule is in `CLAUDE.md`, under *What stays out of the agent's context and the repository*.

**Nothing a source file points to.** No source file references these notes: a note is dated, so a pointer to one imports a description of the code as it used to be. A note names the source it applies to; the source does not point back.

## The three destinations

The rule lives in `CLAUDE.md`, which loads into every session; this file does not. In short:

| Where | What |
|---|---|
| **the source** | what the code below does, what it returns, a coupling or constraint invisible from where it is read |
| **the user documentation** | what a person setting up or using AIconman needs |
| **here** | how it got here: design churn, alternatives tried and dropped, measurements, who decided what and when |

## Layout

One file per subject, not per source file: the reasoning crosses file boundaries far more than the code does.

| File | Subject |
|---|---|
| `00-initialization-of-the-project.md` | where the working rules came from: the request, what was read from Z's other projects, what came across and what was left behind, and Z's review of the first draft. The only note that names another of Z's projects |
| `01-project-log.md` | **kept current**: one row for every important step, in the order it happened |
| `planned.md` | **kept current**: where the work stands, what is next on Z's word, what Z deferred, what is decided and not built, and what the agent raised that was not taken up |
| `ground-rules.md` | what each ground rule in `CLAUDE.md` is for, in Z's words where there are any, and which parts were the agent's proposals |
| `product-brief.md` | the brief as Z first gave it, what the agent raised about it, and what Z settled the same day: the defaults for the stack, speech models, the context window calculator, and the palette |
| `the-backbone.md` | the first part of the design: what talks to what, what a connection is, how a protocol is detected and models are found, Z's answers, and the reads the rest waits on |
| `the-interface.md` | the second part of the design: the screens, the layout, what holds across them, the defaults Z accepted, the high-contrast themes, and what the accounts change |
| `the-palette.md` | the third part of the design: how the four themes are derived from Z's colors, the first proposal, Z's changes, the values, and what was measured for Z to decide |
| `the-database.md` | the fourth part of the design: what the database holds and the rules it enforces, Z's answers, what was read of Z's other project's accounts schema, and the draft |
| `platform-traps.md` | **kept current**: the shell and tooling traps that produced a wrong result once |
