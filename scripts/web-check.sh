#!/usr/bin/env bash
# GET headers and timing; HTTP 4xx/5xx return nonzero. Do not follow redirects.
set -euo pipefail
if (( $# != 1 )) || [[ ! $1 =~ ^https?://[^[:space:]]+$ ]]; then
    echo "Usage: web-check.sh http://HOST[:PORT]/PATH or https://HOST/PATH" >&2
    exit 2
fi
exec curl --proto '=http,https' --connect-timeout 5 --max-time 15 \
    --silent --show-error --fail --dump-header - --output /dev/null \
    --write-out '\nHTTP=%{http_code} DNS=%{time_namelookup}s Connect=%{time_connect}s Total=%{time_total}s\n' \
    -- "$1"
