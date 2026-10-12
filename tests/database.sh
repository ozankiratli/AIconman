# shellcheck shell=bash
# Shared by the tests that run against a real database, which source it. Stops
# unless AICONMAN_CONFIG_DIR names a configuration folder other than config/,
# makes it absolute, and sources install/common.sh to read it.

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ -z ${AICONMAN_CONFIG_DIR:-} ]]; then
  echo "AICONMAN_CONFIG_DIR must name the configuration of the database to test against" >&2
  exit 2
fi
AICONMAN_CONFIG_DIR=$(cd -- "$AICONMAN_CONFIG_DIR" && pwd) || exit 2
if [[ $AICONMAN_CONFIG_DIR == "$root/config" ]]; then
  echo "refusing to test against config/" >&2
  exit 2
fi
export AICONMAN_CONFIG_DIR

# shellcheck source=install/common.sh
. "$root/install/common.sh"
