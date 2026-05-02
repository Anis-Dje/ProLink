#!/usr/bin/env bash
# Starts the Pro-Link PHP dev server with the bundled php.ini, which
# bumps upload_max_filesize / post_max_size / memory_limit so file
# uploads larger than the stock 2M / 8M defaults work.
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
echo "[pro-link] using php.ini: $DIR/php.ini"
exec php -c "$DIR/php.ini" -S 0.0.0.0:8081 -t "$DIR" "$DIR/router.php"
