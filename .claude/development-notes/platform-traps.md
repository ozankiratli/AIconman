# Platform traps

**This file is kept current.** It is appended to as traps are found, with a date on each entry, since a trap does not expire.

Each entry is something that produced a wrong result once in this project, with the symptom it showed and what to do instead.

## A zsh variable holding a list of files is one word

*Found 2026-10-11*, checking the first draft of `CLAUDE.md` and these notes. The shell here is zsh, which does not split an unquoted variable into words the way bash does. `F="CLAUDE.md SOURCES.md ..."; grep -nP '[^\x00-\x7F]' $F || echo none` passed the whole string to `grep` as one file name. `grep` warned that no such file existed and exited non-zero, so the `|| echo none` printed "none" -- a clean result from a check that had read nothing.

Use an array (`F=(a.md b.md); grep ... "${F[@]}"`), and print the exit status rather than folding a failure into a success message. To see the trap: `F="a b"; printf '<%s>\n' $F` prints one line in zsh and two in bash.
