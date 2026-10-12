#!/usr/bin/env bash
# Tests install/create_database.sh without PostgreSQL. Each case writes a
# configuration into a temporary folder, runs the script on it through
# AICONMAN_CONFIG_DIR with a stand-in psql that records its arguments and the
# two password variables, and checks what reached psql or why the script
# stopped. Every password is made up.
#
#   tests/install/test_create_database.sh

set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin"
cat > "$work/bin/psql" <<'EOF'
#!/usr/bin/env bash
{
  printf 'ARG %s\n' "$@"
  printf 'ADMINPW %s\n' "${AICONMAN_DB_ADMINPW-UNSET}"
  printf 'APPPW %s\n' "${AICONMAN_DB_PASSWORD-UNSET}"
} > "$PSQL_RECORD"
EOF
chmod +x "$work/bin/psql"

failures=0
status=
record=
stderr=

# config NAME DBNAME ADMINPW PASSWORD: writes a config.yml for case NAME, each
# value as YAML text.
config() {
  mkdir -p "$work/$1"
  cat > "$work/$1/config.yml" <<EOF
db:
  host: 127.0.0.1
  port: 5432
  dbname: $2
  adminuser: test_admin
  adminpw: $3
  user: test_app
  password: $4
EOF
}

# run NAME: runs the script on case NAME's folder.
run() {
  rm -f "$work/record"
  PATH="$work/bin:$PATH" PSQL_RECORD="$work/record" AICONMAN_CONFIG_DIR="$work/$1" \
    "$root/install/create_database.sh" -U postgres 2> "$work/stderr" > /dev/null
  status=$?
  record=$(cat "$work/record" 2> /dev/null || true)
  stderr=$(cat "$work/stderr")
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

has_line() { grep -qxF -- "$2" <<< "$1"; }
has_text() { grep -qF -- "$2" <<< "$1"; }
called() { [[ $status == 0 && -n $record ]]; }
stopped() { [[ $status != 0 && -z $record ]]; }

config yml_full test_db "'made-up \"admin\" \$x \\ y'" made-up-app
run yml_full
check "passwords from config.yml reach psql intact" called
# shellcheck disable=SC2016  # the dollar sign is part of the password
check "  admin password intact" has_line "$record" 'ADMINPW made-up "admin" $x \ y'
check "  app password" has_line "$record" 'APPPW made-up-app'
check "  names passed" has_line "$record" 'ARG admin_user=test_admin'
check "  psql's own options passed on" has_line "$record" 'ARG postgres'

config env_fill test_db '""' '""'
printf 'AICONMAN_DB_ADMINPW=env-admin\nAICONMAN_DB_PASSWORD=env-app\n' > "$work/env_fill/.env"
run env_fill
check "passwords from .env" called
check "  both from .env" has_line "$record" 'ADMINPW env-admin'

config mixed test_db yml-admin '""'
printf 'AICONMAN_DB_ADMINPW=env-admin\nAICONMAN_DB_PASSWORD=env-app\n' > "$work/mixed/.env"
run mixed
check "a password set in config.yml wins over .env" has_line "$record" 'ADMINPW yml-admin'
check "  the empty one comes from .env" has_line "$record" 'APPPW env-app'

config missing test_db '""' '""'
run missing
check "both passwords empty, no .env: stops" stopped
check "  names the admin password" has_text "$stderr" 'db.adminpw'
check "  names the app password" has_text "$stderr" 'db.password'

config partial test_db '""' '""'
printf 'AICONMAN_DB_ADMINPW=env-admin\nAICONMAN_DB_PASSWORD=\n' > "$work/partial/.env"
run partial
check ".env lacks one password: stops" stopped
only_app_password_named() { ! has_text "$stderr" db.adminpw && has_text "$stderr" db.password; }
check "  names only that one" only_app_password_named

config noname '""' a b
run noname
check "empty dbname: stops" stopped
check "  names it" has_text "$stderr" 'db.dbname'

mkdir -p "$work/noconfig"
run noconfig
check "no config.yml: stops" stopped
check "  says it cannot read it" has_text "$stderr" 'cannot read'

mkdir -p "$work/badyaml"
printf 'db: [unclosed\n' > "$work/badyaml/config.yml"
run badyaml
check "config.yml that is not YAML: stops" stopped

config shellenv test_db '""' '""'
AICONMAN_DB_ADMINPW=shell-admin AICONMAN_DB_PASSWORD=shell-app run shellenv
check "passwords only in the calling shell: stops" stopped

mkdir -p "$work/template"
cp "$root/config.yml.template" "$work/template/config.yml"
sed -e 's/^AICONMAN_DB_ADMINPW=$/AICONMAN_DB_ADMINPW=tpl-admin/' \
  -e 's/^AICONMAN_DB_PASSWORD=$/AICONMAN_DB_PASSWORD=tpl-app/' \
  "$root/.env.template" > "$work/template/.env"
run template
check "the templates, filled: psql is called" called
check "  with the default names" has_line "$record" 'ARG db_name=aicm_db'
check "  and the passwords from .env" has_line "$record" 'ADMINPW tpl-admin'

printf '%d failed\n' "$failures"
(( failures == 0 ))
