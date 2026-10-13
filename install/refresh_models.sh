#!/usr/bin/env bash
# The scheduled refresh: checks every connection and records what each server
# serves, acting for no one. For cron, every 30 minutes, as the user AIconman
# runs as:
#
#   */30 * * * * /path/to/AIconman/install/refresh_models.sh
#
# The configuration is config/, or the folder AICONMAN_CONFIG_DIR names. It
# prints nothing when it finishes.

set -euo pipefail
# shellcheck source=install/common.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

cd -- "$root"
AICONMAN_CONFIG_DIR=$config_dir exec "$python" -m aiconman.refresh
