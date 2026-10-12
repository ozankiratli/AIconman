#!/usr/bin/env bash
# Creates AIconman's database and its two roles, empty, by running
# db/create_database.sql with the names and passwords from the configuration.
#
# Run as a user who can read config/, with psql's options for connecting as a
# PostgreSQL superuser, for example:
#
#   install/create_database.sh -U postgres
#
# The names are db.dbname, db.adminuser and db.user in config/config.yml. The
# passwords are db.adminpw and db.password there; one left empty is taken from
# AICONMAN_DB_ADMINPW or AICONMAN_DB_PASSWORD in config/.env. No value is
# printed.

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
config=$root/config/config.yml
env_file=$root/config/.env
python=$root/.venv/bin/python

fail() {
  printf 'create_database.sh: %s\n' "$1" >&2
  exit 1
}

[[ -r $config ]] || fail "cannot read $config as $(id -un): it is missing, or this user cannot read it"
[[ -x $python ]] || fail "$python not found; create .venv first"

# Prints one shell assignment per db setting, each value quoted.
settings=$("$python" -I - "$config" <<'EOF'
import shlex
import sys

import yaml

with open(sys.argv[1]) as f:
    db = (yaml.safe_load(f) or {}).get("db") or {}
for name, key in (
    ("db_name", "dbname"),
    ("admin_user", "adminuser"),
    ("app_user", "user"),
    ("admin_password", "adminpw"),
    ("app_password", "password"),
):
    value = db.get(key)
    print(f"{name}={shlex.quote('' if value is None else str(value))}")
EOF
)
eval "$settings"

if [[ ( -z $admin_password || -z $app_password ) && -f $env_file ]]; then
  # shellcheck source=/dev/null
  . "$env_file"
  admin_password=${admin_password:-${AICONMAN_DB_ADMINPW:-}}
  app_password=${app_password:-${AICONMAN_DB_PASSWORD:-}}
fi

missing=()
[[ -n $db_name ]] || missing+=("db.dbname in config/config.yml")
[[ -n $admin_user ]] || missing+=("db.adminuser in config/config.yml")
[[ -n $app_user ]] || missing+=("db.user in config/config.yml")
[[ -n $admin_password ]] || missing+=("db.adminpw in config/config.yml, or AICONMAN_DB_ADMINPW in config/.env")
[[ -n $app_password ]] || missing+=("db.password in config/config.yml, or AICONMAN_DB_PASSWORD in config/.env")
if (( ${#missing[@]} )); then
  printf 'create_database.sh: empty or not set: %s\n' "${missing[@]}" >&2
  exit 1
fi

AICONMAN_DB_ADMINPW=$admin_password AICONMAN_DB_PASSWORD=$app_password \
  psql -v ON_ERROR_STOP=1 \
    -v admin_user="$admin_user" -v app_user="$app_user" -v db_name="$db_name" \
    "$@" -f "$root/db/create_database.sql"
