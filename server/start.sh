#!/usr/bin/env bash
# Starts the Pro-Link PHP dev server.
#
# We deliberately do NOT use `-c <our php.ini>` because that fully
# replaces the system php.ini and drops critical settings the host PHP
# relies on — most importantly `extension_dir`. Instead we layer our
# overrides on top of the system php.ini via `-d` flags so whatever
# the host already has configured (extension_dir, openssl, curl,
# pdo_pgsql, fileinfo, etc.) keeps working while we still bump the
# upload / execution limits.
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
exec php \
    -d upload_max_filesize=50M \
    -d post_max_size=55M \
    -d memory_limit=256M \
    -d max_execution_time=60 \
    -d max_input_time=60 \
    -S 0.0.0.0:8081 -t "$DIR" "$DIR/router.php"
# NOTE: pdo_pgsql / fileinfo aren't passed with -d extension= because
# the host php.ini already loads them on every supported setup
# (XAMPP, Debian/Ubuntu, macOS Homebrew). A duplicate -d extension=
# load triggers a noisy "Module is already loaded" warning on every
# process boot. If you're on a stripped-down PHP that does NOT
# auto-load them, enable the corresponding `extension=` line in the
# host's php.ini once and re-run this script.
