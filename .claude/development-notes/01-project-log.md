# Project log

**This file is kept current.** A row is appended for every action, so it is an exception to the dating rule in `README.md`.

Z, 2026-10-11: *"Let's add also a 01-project-log.md. to log whole development. A very long table. Everything goes there."*

Every action on AIconman gets a row, in the order it happened: what Z decided or did, and what the agent did. An action is anything a reviewer would want to find again: a decision, a file created or changed, a read, a check, a commit, a correction. The row says what was done in a few words; the reasons and the detail are in the other notes, `dev/READING-LOG.md` and the commit messages.

- **No** is four hexadecimal digits, uppercase, from `0001`, and is never reused. Z: *"No field should be 5 digits numeric or 4 digits hexadecimal value (I'm leaning on hexadecimal) from 00001 or 0001."*
- **Date** and **Time** are Z's local time when the action was taken, with the zone.
- **Tree hash** is the commit the working tree stood at when the action was taken. A commit's own row carries the commit it made.
- **Action** starts with who took it: Z or Agent.
- **Notes** is empty when a row is written, and it is the only cell that changes afterwards. Z: *"Notes can be filled later if we discover something was incorrect, we revert an action, decision etc."* A note names the row that corrected or reverted the action. No other cell is rewritten, and no row is removed.

Rows `0001` to `0016` were written on 2026-10-11, after the fact, from `git log`, the times of the agent's session record, and the time the reading log was last saved.

| No | Date | Time | Tree hash | Action | Notes |
|---|---|---|---|---|---|
| 0001 | 2026-10-10 | 14:37 EDT | b8de0d5 | Z: initial commit -- README, GPL-3.0 license, Python `.gitignore` | |
| 0002 | 2026-10-11 | 09:02 EDT | b8de0d5 | Z: gives the brief; puts the Hailo gateway, its manual and the website theme in `.tmp/` | |
| 0003 | 2026-10-11 | 09:02 EDT | b8de0d5 | Agent: reads the files in `.tmp/` | |
| 0004 | 2026-10-11 | 09:03 EDT | b8de0d5 | Agent: measures the five new colors' contrast; proposes a backend relay, base URLs and four defaults | |
| 0005 | 2026-10-11 | 09:36 EDT | b8de0d5 | Z: asks about a reverse proxy; several servers per machine; speech models in; key optional; server limits not raised; context calculator; agrees the four defaults | |
| 0006 | 2026-10-11 | 09:36 EDT | b8de0d5 | Z: asks for `CLAUDE.md` and development notes, ground rules first: subagents, reading other people's code, transparency | |
| 0007 | 2026-10-11 | 09:37 EDT | b8de0d5 | Agent: reads PoolSeqFlow's and PAPvault's rules and notes, at Z's request | |
| 0008 | 2026-10-11 | 09:42 EDT | b8de0d5 | Agent: writes `CLAUDE.md`, the notes index, `ground-rules.md`, `product-brief.md`, `dev/READING-LOG.md`, `SOURCES.md`; ignores `.claude/settings.local.json` | |
| 0009 | 2026-10-11 | 09:43 EDT | b8de0d5 | Agent: saves a memory entry pointing at the server-limits ruling | |
| 000A | 2026-10-11 | 09:43 EDT | b8de0d5 | Agent: first ASCII and private-name check reads no files (zsh trap); reruns it with a control, clean | |
| 000B | 2026-10-11 | 09:43 EDT | b8de0d5 | Agent: records the trap in `platform-traps.md` | |
| 000C | 2026-10-11 | 10:24 EDT | b8de0d5 | Z: asks for other projects' names to move out of the rules and notes | |
| 000D | 2026-10-11 | 10:26 EDT | b8de0d5 | Agent: creates `00-initialization-of-the-project.md`; removes other projects' names from `ground-rules.md`, `CLAUDE.md`, the index and `platform-traps.md` | |
| 000E | 2026-10-11 | 10:29 EDT | f94a72f | Z: commits the rules and notes | |
| 000F | 2026-10-11 | 10:36 EDT | f94a72f | Z: no default protocol; a login screen that lets everyone in, access options last; gateway manual to be rewritten; asks for the design | |
| 0010 | 2026-10-11 | 10:37 EDT | f94a72f | Agent: appends Z's answers to `product-brief.md`; proposes the backbone in nine points | |
| 0011 | 2026-10-11 | 10:43 EDT | f94a72f | Z: protocol detected or chosen; two protocols first; no machine label; documentation reads through the log | |
| 0012 | 2026-10-11 | 10:44 EDT | f94a72f | Agent: writes R-001 to R-005 and `the-backbone.md` | |
| 0013 | 2026-10-11 | 10:45 EDT | f94a72f | Agent: corrects the tree hash in two notes from b8de0d5 to f94a72f | |
| 0014 | 2026-10-11 | 10:47 EDT | f94a72f | Z: clears R-001 to R-005 | |
| 0015 | 2026-10-11 | 10:56 EDT | f94a72f | Z: asks for `01-project-log.md` | |
| 0016 | 2026-10-11 | 10:59 EDT | f94a72f | Agent: creates `01-project-log.md` with rows 0001 to 0016; adds it to `CLAUDE.md` and the index | |
