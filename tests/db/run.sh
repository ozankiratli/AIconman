#!/usr/bin/env bash
# shellcheck disable=SC2154  # the settings' variables are set by read_settings
# Runs the schema's tests, the .sql files beside this script, against a real
# database: the one named by the configuration in AICONMAN_CONFIG_DIR, whose
# schema it first rebuilds and seeds, with no dump. It refuses to run without
# AICONMAN_CONFIG_DIR, or with it naming config/.
#
#   AICONMAN_CONFIG_DIR=.tmp/scratch/config tests/db/run.sh
#
# A file whose name starts with app_ runs as the app role, every other file as
# the owner role; helpers.sql is included by the files, not run. Each check
# prints a notice starting "ok", and a failing check raises an error, which
# stops its file.

set -uo pipefail

# shellcheck source=tests/database.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/../database.sh"
read_settings db_host=db.host db_port=db.port db_name=db.dbname \
  admin_user=db.adminuser app_user=db.user \
  admin_password=db.adminpw app_password=db.password
fill_from_env admin_password=AICONMAN_DB_ADMINPW app_password=AICONMAN_DB_PASSWORD

# as ROLE ARGS...: runs psql on the database as the owner or the app role.
as() {
  local user=$admin_user password=$admin_password
  if [[ $1 == app ]]; then
    user=$app_user
    password=$app_password
  fi
  shift
  PGPASSWORD=$password psql -X -w -q -h "$db_host" -p "$db_port" -U "$user" -d "$db_name" \
    -v ON_ERROR_STOP=1 -v app_user="$app_user" "$@"
}

if ! as owner -1 -v allow_auto_signup=true -c 'SET client_min_messages = warning' \
     -f "$root/db/build_schema.sql" -f "$root/db/seed.sql" > /dev/null; then
  echo "the schema did not build" >&2
  exit 1
fi

failures=0
for file in "$(dirname -- "${BASH_SOURCE[0]}")"/*.sql; do
  name=$(basename -- "$file")
  [[ $name == helpers.sql ]] && continue
  role=owner
  [[ $name == app_* ]] && role=app
  printf '%s, as the %s role\n' "$name" "$role"
  output=$(as "$role" -f "$file" 2>&1 > /dev/null)
  status=$?
  oks=$(grep -c 'NOTICE:  ok' <<< "$output")
  sed -n 's/.*NOTICE:  \(ok .*\)/  \1/p' <<< "$output"
  if (( status != 0 )); then
    grep -E 'ERROR:' <<< "$output" | sed -E 's/.*ERROR:  (FAIL  )?/  FAIL  /'
    failures=$((failures + 1))
  elif (( oks == 0 )); then
    echo "  FAIL  ran no checks"
    failures=$((failures + 1))
  fi
done

printf '%d files failed\n' "$failures"
(( failures == 0 ))
