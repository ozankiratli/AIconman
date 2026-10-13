# shellcheck shell=bash
# Shared by the scripts in install/, which source it: finds the configuration
# and reads settings from it through lmconman/config.py. Sets root, config_dir,
# config, env_file and python.
#
# The configuration folder is config/, or the folder LMCONMAN_CONFIG_DIR names.

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
config_dir=${LMCONMAN_CONFIG_DIR:-$root/config}
config=$config_dir/config.yml
# shellcheck disable=SC2034  # used by the scripts that source this file
env_file=$config_dir/.env
python=$root/.venv/bin/python

# fail MESSAGE: prints MESSAGE under the running script's name and exits.
fail() {
  printf '%s: %s\n' "$(basename -- "$0")" "$1" >&2
  exit 1
}

[[ -r $config ]] || fail "cannot read $config as $(id -un): it is missing, or this user cannot read it"
[[ -x $python ]] || fail "$python not found; create .venv first"

# read_settings VAR=section.key ...: sets each VAR to that setting's value, or
# to "" when it is not set, as lmconman/config.py reads it: a secret left empty
# in config.yml comes from .env. A boolean reads as true or false.
read_settings() {
  local assignments
  assignments=$(LMCONMAN_CONFIG_DIR=$config_dir "$python" -I "$root/lmconman/config.py" "$@") || exit 1
  eval "$assignments"
}

# require VAR=description ...: stops, naming every description whose VAR is
# empty.
require() {
  local spec var
  local -a missing=()
  for spec; do
    var=${spec%%=*}
    [[ -n ${!var} ]] || missing+=("${spec#*=}")
  done
  (( ${#missing[@]} == 0 )) && return 0
  printf '%s: empty or not set: %s\n' "$(basename -- "$0")" "${missing[@]}" >&2
  exit 1
}
