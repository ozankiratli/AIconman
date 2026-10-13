#!/usr/bin/env bash
# shellcheck disable=SC2154  # the settings' variables are set by read_settings
# Tests install/build_schema.sh against a real database: the one named by the
# configuration in LMCONMAN_CONFIG_DIR, whose schema it destroys. It refuses to
# run without LMCONMAN_CONFIG_DIR, or with it naming config/.
#
#   LMCONMAN_CONFIG_DIR=.tmp/scratch/config tests/install/test_build_schema.sh
#
# A marker table, made as the owner role, shows whether a case changed the
# schema. The dumps the cases make stay in the backups folder.

set -uo pipefail

# shellcheck source=tests/database.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/../database.sh"
read_settings db_host=db.host db_port=db.port db_name=db.dbname \
  admin_user=db.adminuser app_user=db.user admin_password=db.adminpw \
  storage_root=storage.root_path allow_auto_signup=auth.allow_auto_signup
backups=$storage_root/db/backups
work=$(mktemp -d)
trap 'chmod -R u+w -- "$work"; rm -rf -- "$work"; [[ -d $backups ]] && chmod 700 -- "$backups"' EXIT

failures=0
status=
out=

# sql QUERY: runs QUERY as the owner role and prints the result unaligned.
sql() {
  PGPASSWORD=$admin_password psql -X -w -At -h "$db_host" -p "$db_port" \
    -U "$admin_user" -d "$db_name" -c "$1"
}

# run SCRIPT ARGS...: runs SCRIPT with no terminal on its input, keeping its
# status and everything it printed.
run() {
  out=$("$@" < /dev/null 2>&1)
  status=$?
}

# check NAME CONDITION...: reports CONDITION, a test command, as passed or failed.
check() {
  local name=$1
  shift
  if "$@"; then
    printf 'ok    %s\n' "$name"
  else
    printf 'FAIL  %s\n' "$name"
    failures=$((failures + 1))
  fi
}

dumps() { find "$backups" -maxdepth 1 -name '*.dump' 2> /dev/null | wc -l; }
marker() { [[ $(sql "SELECT to_regclass('public.test_marker') IS NOT NULL") == t ]]; }
no_marker() { ! marker; }
says() { grep -qF -- "$1" <<< "$out"; }
is() { [[ $1 == "$2" ]]; }

sql "CREATE TABLE IF NOT EXISTS public.test_marker (x int)" > /dev/null || exit 1
check "the marker table exists before the cases" marker

before=$(dumps)
run "$root/install/build_schema.sh"
check "no option: usage, status 2" is "$status" 2
check "  no dump made" is "$(dumps)" "$before"

run "$root/install/build_schema.sh" --rebuild --nonsense
check "an unknown option: usage, status 2" is "$status" 2

run "$root/install/build_schema.sh" --rebuild --seed
check "--rebuild with --seed: usage, status 2" is "$status" 2

before=$(dumps)
run "$root/install/build_schema.sh" --rebuild
check "no terminal and no --confirm-db: stops" is "$status" 1
check "  asks for --confirm-db" says "--confirm-db"
check "  the dump was made first" is "$(dumps)" "$((before + 1))"
check "  the schema is untouched" marker

run "$root/install/build_schema.sh" --rebuild --confirm-db "not-$db_name"
check "the wrong name: stops" is "$status" 1
check "  says nothing was changed" says "nothing was changed"
check "  the schema is untouched" marker

before=$(dumps)
chmod 500 -- "$backups"
run "$root/install/build_schema.sh" --rebuild --confirm-db "$db_name"
chmod 700 -- "$backups"
check "the dump fails: stops" is "$status" 1
check "  says the dump failed" says "the dump failed"
check "  leaves no partial dump" is "$(dumps)" "$before"
check "  the schema is untouched" marker

mkdir -p "$work/tree"
cp -r "$root/install" "$root/db" "$work/tree/"
ln -s "$root/.venv" "$work/tree/.venv"
printf '%s\n' 'DROP SCHEMA IF EXISTS public CASCADE;' 'CREATE SCHEMA public;' \
  'SELECT no_such_function();' > "$work/tree/db/build_schema.sql"
run "$work/tree/install/build_schema.sh" --rebuild --confirm-db "$db_name"
failed() { (( status != 0 )); }
check "a build that fails partway: stops" failed
check "  the drop is rolled back, the schema is untouched" marker

before=$(dumps)
tables=$(sql "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'")
run "$root/install/build_schema.sh" --rebuild --confirm-db "$db_name"
check "the right name: rebuilds" is "$status" 0
check "  said what it would destroy" says "Tables there now: $tables."
check "  the marker table is gone" no_marker
newest=$(find "$backups" -maxdepth 1 -name '*.dump' -newer "$work" -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
check "  one dump made" is "$(dumps)" "$((before + 1))"
dump_has_marker() { pg_restore -l -- "$newest" | grep -q 'TABLE public test_marker'; }
check "  the dump holds the schema as it was" dump_has_marker
check "  the dump is readable by its owner only" is "$(stat -c %a -- "$newest")" 600
check "  the backups folder too" is "$(stat -c %a -- "$backups")" 700
check "  public is the owner role's" is "$(sql "SELECT nspowner::regrole FROM pg_namespace WHERE nspname = 'public'")" "$admin_user"
check "  the app role may use it" is "$(sql "SELECT has_schema_privilege('$app_user', 'public', 'USAGE')")" t
check "  the app role may not create in it" is "$(sql "SELECT has_schema_privilege('$app_user', 'public', 'CREATE')")" f
check "  PUBLIC has nothing on it" is "$(sql "SELECT count(*) FROM pg_namespace, aclexplode(nspacl) a WHERE nspname = 'public' AND a.grantee = 0")" 0
check "  self sign-up is seeded from the configuration" \
  is "$(sql "SELECT value FROM settings WHERE key = 'allow_auto_signup'")" "$allow_auto_signup"
check "  Nextcloud is seeded as a provider" is "$(sql "SELECT count(*) FROM providers WHERE provider = 'nextcloud'")" 1

sql "UPDATE settings SET value = to_jsonb(NOT value::boolean) WHERE key = 'allow_auto_signup'; DELETE FROM providers" > /dev/null
changed=$(sql "SELECT value FROM settings WHERE key = 'allow_auto_signup'")
before=$(dumps)
run "$root/install/build_schema.sh" --seed
check "--seed: seeds" is "$status" 0
check "  keeps a setting already there" is "$(sql "SELECT value FROM settings WHERE key = 'allow_auto_signup'")" "$changed"
check "  adds a row that is missing" is "$(sql "SELECT count(*) FROM providers WHERE provider = 'nextcloud'")" 1
check "  makes no dump" is "$(dumps)" "$before"
run "$root/install/build_schema.sh" --seed
check "  and can run again" is "$status" 0

printf '%d failed\n' "$failures"
(( failures == 0 ))
