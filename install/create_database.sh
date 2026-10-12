#!/usr/bin/env bash
# shellcheck disable=SC2154  # the settings' variables are set by read_settings
# Creates AIconman's database and its two roles, empty, by running
# db/create_database.sql with the names and passwords from the configuration.
#
# Run as a user who can read the configuration, with psql's options for
# connecting as a PostgreSQL superuser, for example:
#
#   install/create_database.sh -U postgres
#
# The configuration is config/, or the folder AICONMAN_CONFIG_DIR names. The
# names are db.dbname, db.adminuser and db.user in its config.yml. The
# passwords are db.adminpw and db.password there; one left empty is taken from
# AICONMAN_DB_ADMINPW or AICONMAN_DB_PASSWORD in its .env. No value is printed.

set -euo pipefail
# shellcheck source=install/common.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

read_settings db_name=db.dbname admin_user=db.adminuser app_user=db.user \
  admin_password=db.adminpw app_password=db.password
require \
  "db_name=db.dbname in $config" \
  "admin_user=db.adminuser in $config" \
  "app_user=db.user in $config" \
  "admin_password=db.adminpw in $config, or AICONMAN_DB_ADMINPW in $env_file" \
  "app_password=db.password in $config, or AICONMAN_DB_PASSWORD in $env_file"

AICONMAN_DB_ADMINPW=$admin_password AICONMAN_DB_PASSWORD=$app_password \
  psql -v ON_ERROR_STOP=1 \
    -v admin_user="$admin_user" -v app_user="$app_user" -v db_name="$db_name" \
    "$@" -f "$root/db/create_database.sql"
