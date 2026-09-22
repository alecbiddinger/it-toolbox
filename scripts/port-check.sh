#!/usr/bin/env bash
# Check exactly one TCP port with a bounded connection wait.
set -euo pipefail
if (( $# != 2 )) || [[ -z $1 || $1 == -* || ! $2 =~ ^[0-9]{1,5}$ ]]; then
    echo "Usage: port-check.sh HOST PORT" >&2
    exit 2
fi
port=$((10#$2))
if (( port < 1 || port > 65535 )); then
    echo "PORT must be between 1 and 65535." >&2
    exit 2
fi
exec nc -vz -w 3 -- "$1" "$port"
