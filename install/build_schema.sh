#!/usr/bin/env bash
# shellcheck disable=SC2154  # the settings' variables are set by read_settings
# Builds AIconman's schema and seeds it, as the owner role.
#
#   install/build_schema.sh --rebuild [--confirm-db NAME]
#       Drops everything in the schema public of AIconman's database, builds it
#       again from db/build_schema.sql, and seeds it from db/seed.sql.
#   install/build_schema.sh --seed
#       Seeds the schema from db/seed.sql, leaving every row already there as it
#       is; safe to run any number of times.
#
# A rebuild first says what it is about to destroy, and dumps the database into
# <storage.root_path>/db/backups/; if the dump fails, it stops. Then it asks for
# the database's name, or takes it from --confirm-db, and stops unless the name
# matches. The build and the seeding run in one transaction, so a failure leaves
# the schema as it was.
#
# The configuration is config/, or the folder AICONMAN_CONFIG_DIR names. It
# connects to db.host and db.port, to db.dbname, as db.adminuser, whose password
# is db.adminpw, or AICONMAN_DB_ADMINPW in the configuration's .env. Seeding
# takes the starting value of self sign-up from auth.allow_auto_signup.

set -euo pipefail
umask 077
# shellcheck source=install/common.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

usage() {
  printf 'usage: %s --rebuild [--confirm-db NAME] | --seed\n' "$(basename -- "$0")" >&2
  exit 2
}

mode=
confirm=
while (( $# )); do
  case $1 in
    --rebuild|--seed) [[ -z $mode ]] || usage; mode=${1#--} ;;
    --confirm-db) (( $# >= 2 )) || usage; confirm=$2; shift ;;
    --confirm-db=*) confirm=${1#*=} ;;
    *) usage ;;
  esac
  shift
done
[[ -n $mode ]] || usage

read_settings db_host=db.host db_port=db.port db_name=db.dbname \
  admin_user=db.adminuser app_user=db.user admin_password=db.adminpw \
  storage_root=storage.root_path allow_auto_signup=auth.allow_auto_signup
require \
  "db_host=db.host in $config" \
  "db_port=db.port in $config" \
  "db_name=db.dbname in $config" \
  "admin_user=db.adminuser in $config" \
  "app_user=db.user in $config" \
  "admin_password=db.adminpw in $config, or AICONMAN_DB_ADMINPW in $env_file" \
  "storage_root=storage.root_path in $config" \
  "allow_auto_signup=auth.allow_auto_signup in $config"
[[ $allow_auto_signup == true || $allow_auto_signup == false ]] ||
  fail "auth.allow_auto_signup in $config must be true or false"

connection=(-h "$db_host" -p "$db_port" -U "$admin_user" -d "$db_name")

# as_owner COMMAND ARGS...: runs a PostgreSQL client with the owner's password.
as_owner() {
  PGPASSWORD=$admin_password "$@"
}

# run_sql FILE...: runs the files in one transaction, stopping at the first
# error.
run_sql() {
  local -a files=()
  local file
  for file; do
    files+=(-f "$root/db/$file")
  done
  as_owner psql -X -w -q -1 -v ON_ERROR_STOP=1 -v app_user="$app_user" \
    -v allow_auto_signup="$allow_auto_signup" "${connection[@]}" \
    -c 'SET client_min_messages = warning' "${files[@]}"
}

if [[ $mode == seed ]]; then
  run_sql seed.sql
  printf 'Seeded %s.\n' "$db_name"
  exit 0
fi

tables=$(as_owner psql -X -w -At "${connection[@]}" \
  -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'") ||
  fail "cannot connect to $db_name on $db_host:$db_port as $admin_user"
printf 'This destroys everything in the schema public of %s on %s:%s and builds it again. Tables there now: %s.\n' \
  "$db_name" "$db_host" "$db_port" "$tables"

backups=$storage_root/db/backups
mkdir -p -- "$backups" || fail "cannot make $backups"
dump=$(mktemp --suffix=.dump "$backups/$db_name-$(date +%Y%m%d-%H%M%S)-XXXXXX") ||
  fail "the dump failed: cannot write into $backups, so nothing was changed"
if ! as_owner pg_dump -w -Fc -f "$dump" "${connection[@]}"; then
  rm -f -- "$dump"
  fail "the dump failed, so nothing was changed"
fi
printf 'Dumped %s to %s\n' "$db_name" "$dump"

if [[ -z $confirm ]]; then
  [[ -t 0 ]] || fail "not run from a terminal, so give the database's name with --confirm-db; nothing was changed"
  read -r -p "Type the database's name, $db_name, to go on: " confirm
fi
[[ $confirm == "$db_name" ]] || fail "'$confirm' is not $db_name, so nothing was changed"

run_sql build_schema.sql seed.sql
printf 'Rebuilt and seeded the schema of %s.\n' "$db_name"
