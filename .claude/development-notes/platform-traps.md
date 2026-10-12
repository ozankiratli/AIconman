# Platform traps

**This file is kept current.** It is appended to as traps are found, with a date on each entry, since a trap does not expire.

Each entry is something that produced a wrong result once in this project, with the symptom it showed and what to do instead.

## A zsh variable holding a list of files is one word

*Found 2026-10-11*, checking the first draft of `CLAUDE.md` and these notes. The shell here is zsh, which does not split an unquoted variable into words the way bash does. `F="CLAUDE.md SOURCES.md ..."; grep -nP '[^\x00-\x7F]' $F || echo none` passed the whole string to `grep` as one file name. `grep` warned that no such file existed and exited non-zero, so the `|| echo none` printed "none" -- a clean result from a check that had read nothing.

Use an array (`F=(a.md b.md); grep ... "${F[@]}"`), and print the exit status rather than folding a failure into a success message. To see the trap: `F="a b"; printf '<%s>\n' $F` prints one line in zsh and two in bash.

## The status after a pipe is the last command's

*Found 2026-10-11*, checking the configuration files. An ASCII check written as `grep -nP '[^\x00-\x7F]' <files> | cut -c1-70; echo "exit=$?"` printed the status of `cut`, which is 0 whether or not `grep` found anything, so the printed status could not fail. The matching lines themselves still reached the screen, so no check was misread; but the status shown was not a check.

Read a check's status from the command itself, with no pipe after it, or from zsh's `$pipestatus`, which holds every command's status; `PIPESTATUS` is bash's name and is empty in zsh. To see the trap: `printf 'x\n' | grep nomatch | cat; echo $? $pipestatus` prints `0 0 1 0`.

## A quoted literal cast in SQL fails before WHERE is looked at

*Found 2026-10-12*, when Z ran `db/create_database.sql` for the first time. The script stopped a run when a password was empty with `SELECT 'AICONMAN_DB_ADMINPW is empty or not set'::int WHERE :'admin_password' = '';`, expecting the cast to fail only when the `WHERE` held. It failed on Z's run with the password set. The agent's explanation, from how PostgreSQL types a quoted literal: the literal is converted to the cast's type when the statement is read, before any row is considered, so the error comes whatever the `WHERE` says. The script had never been run before it was handed over. The check now lives in `install/create_database.sh`, in bash, before `psql` starts.

To fail on a condition in SQL, make the error depend on a row, or decide in the calling script.

## A broken copy whose change did not land proves nothing

*Found 2026-10-12*, showing that the schema's tests can fail. Each test is run against a copy of the schema with one rule broken by `sed`, and is expected to fail. For one copy the `sed` pattern, a regular expression with escaped slashes and dots, matched nothing: the copy was the schema unchanged, its tests passed, and the pass looked like a check that could not catch the rule. It was caught only because the run printed how many lines differed, and that count was 0.

Print the `diff` between the copy and the original before reading the test's result, and treat an empty diff as a failed setup, not a result. Prefer the simplest pattern that matches the line, such as `sed '/AND path !~/d'`. To see the trap: `sed 's/no such text/x/' file | diff -q file - && echo "identical: this copy tests nothing"`. To see the trap, in any `psql` session: `SELECT 'x'::int WHERE false;` fails with *invalid input syntax for type integer*. The agent has not run this; if it returns no rows instead, the explanation above is wrong and this entry is to be corrected.
