#!/usr/bin/env bash
# Starts the Pro-Link PHP dev server with bumped upload limits.
#
# We use `-d key=value` flags rather than `-c <ini-file>` because `-c`
# tells PHP to ignore the system php.ini entirely, which can drop
# `extension_dir` and loaded extensions (notably `pdo_pgsql`). `-d` is
# additive: it preserves every system value and just overrides the
# upload-related ones we care about.
#
# Usage:
#   export DATABASE_URL="postgresql://..."
#   ./start.sh
#
# (Run this from the `server/` folder.)

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${DATABASE_URL:-}" ]; then
    echo "[pro-link] WARNING: DATABASE_URL is not set. The API will fail"
    echo "           with 'server_misconfigured' until you set it."
fi

echo "[pro-link] starting dev server on http://0.0.0.0:8081"
echo "[pro-link] upload limits: 50M (file) / 55M (request)"
exec php \
  -d upload_max_filesize=50M \
  -d post_max_size=55M \
  -d memory_limit=256M \
  -d max_execution_time=60 \
  -d max_input_time=60 \
  -S 0.0.0.0:8081 -t "$DIR" "$DIR/router.php"
