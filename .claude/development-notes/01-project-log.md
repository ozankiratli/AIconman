# Project log

**This file is kept current.** A row is appended for every action, so it is an exception to the dating rule in `README.md`.

Z, 2026-10-11: *"Let's add also a 01-project-log.md. to log whole development. A very long table. Everything goes there."*

The log records actions, in the order they happened, so that an agent months later can recover the important steps that were taken: something built or changed, a read, a check, a commit, a correction, a revert. It does not record conversation. What Z says does not get a row, and neither does writing what was said or decided into the notes, which are its record. Z, 2026-10-11: *"Not everything I say needs to go into the log [...] Log should demonstrate only actions. So a few months in the future another agent cen recover important steps that were taken."* A row is one task, not each step of it, and says what was done, not what came of it. Z, 2026-10-11, collapsing five rows about the first reads into one: *"Results are not important here."* The results and the reasons are in the other notes, `dev/READING-LOG.md` and the commit messages.

- **No** is four hexadecimal digits, uppercase, from `0001`, and is never reused. Z: *"No field should be 5 digits numeric or 4 digits hexadecimal value (I'm leaning on hexadecimal) from 00001 or 0001."*
- **Date** and **Time** are Z's local time when the action was taken, with the zone.
- **Tree hash** is the commit the working tree stood at when the action was taken. A commit's own row carries the commit it made. Commits are Z's, and they mark the points where Z decides a task is complete, so many rows share one hash. Z, 2026-10-11: *"Commits do not align with every step. They only occur at the times when I decide we completed a task that needs committing. That's one reason I make the commits."*
- **Action** starts with who took it: Z or Agent.
- **Notes** is empty when a row is written, and it is the only cell that changes afterwards. Z: *"Notes can be filled later if we discover something was incorrect, we revert an action, decision etc."* A note names the row that corrected or reverted the action. Once a row is committed, no other cell is rewritten and the row is not removed.

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
| 0017 | 2026-10-11 | 11:04 EDT | e1866f4 | Z: commits the project log, the backbone note, R-001 to R-005 cleared, and the product-brief addition | |
| 0018 | 2026-10-11 | 11:05 EDT | e1866f4 | Z: go-ahead to start | |
| 0019 | 2026-10-11 | 11:05 EDT | e1866f4 | Agent: performs R-001 to R-005 | |
| 001A | 2026-10-11 | 11:36 EDT | e1866f4 | Z: clears R-006 to R-008 | |
| 001B | 2026-10-11 | 11:39 EDT | e1866f4 | Agent: merges the rows for the reads into 0019, at Z's request | |
| 001C | 2026-10-11 | 11:43 EDT | e1866f4 | Z: go-ahead for R-006 to R-008 | |
| 001D | 2026-10-11 | 11:43 EDT | e1866f4 | Agent: performs R-006 to R-008 | |
| 001E | 2026-10-11 | 15:36 EDT | e1866f4 | Agent: adds `dev/palette/` (`derive.py`, `render.py`) with the palette as Z settled it | |
| 001F | 2026-10-11 | 16:47 EDT | e1866f4 | Agent: performs R-010 | |
| 0020 | 2026-10-11 | 17:28 EDT | e1866f4 | Agent: changes the brand in `dev/palette/` to two tones in Source Serif Pro Bold Italic, without the glow | |
| 0021 | 2026-10-11 | 17:36 EDT | 440ca41 | Z: commits the design decisions so far | |
| 0022 | 2026-10-11 | 17:38 EDT | 440ca41 | Agent: reads the sign-in and sign-up screens of Z's accounts project, at Z's go-ahead | |
| 0023 | 2026-10-11 | 18:00 EDT | 440ca41 | Agent: performs R-013 | |
| 0024 | 2026-10-11 | 18:32 EDT | 440ca41 | Agent: performs R-014 and R-015 | |
| 0025 | 2026-10-11 | 18:57 EDT | 440ca41 | Agent: adds the disabled-control colors to `dev/palette/` | |
