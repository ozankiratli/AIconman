# shellcheck shell=bash
# Shared by the scripts in install/, which source it: finds the configuration
# and reads settings from it. Sets root, config_dir, config, env_file and python.
#
# The configuration folder is config/, or the folder AICONMAN_CONFIG_DIR names.

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
config_dir=${AICONMAN_CONFIG_DIR:-$root/config}
config=$config_dir/config.yml
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
# to "" when it is not set. A boolean reads as true or false.
read_settings() {
  local assignments
  assignments=$("$python" -I - "$config" "$@" <<'EOF'
import shlex
import sys

import yaml

with open(sys.argv[1]) as f:
    cfg = yaml.safe_load(f) or {}
for spec in sys.argv[2:]:
    name, path = spec.split("=", 1)
    value = cfg
    for key in path.split("."):
        value = value.get(key) if isinstance(value, dict) else None
    if isinstance(value, bool):
        value = "true" if value else "false"
    print(f"{name}={shlex.quote('' if value is None else str(value))}")
EOF
  ) || exit 1
  eval "$assignments"
}

# fill_from_env VAR=ENV_KEY ...: sets each VAR that is still empty to ENV_KEY's
# value in the configuration's .env, when there is one.
fill_from_env() {
  local spec var key
  [[ -f $env_file ]] || return 0
  # shellcheck source=/dev/null
  . "$env_file"
  for spec; do
    var=${spec%%=*}
    key=${spec#*=}
    [[ -n ${!var} ]] || printf -v "$var" '%s' "${!key:-}"
  done
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
