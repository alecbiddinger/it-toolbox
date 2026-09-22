#!/usr/bin/env bash
# Display DNS status and answers. dig's exit code does not guarantee records exist.
set -euo pipefail
if (( $# < 1 || $# > 3 )) || [[ -z $1 || $1 == [-@+]* ]]; then
    echo "Usage: dns-check.sh HOST [TYPE] [RESOLVER]" >&2
    exit 2
fi
host=$1
record_type=${2:-A}
if [[ ! $record_type =~ ^[A-Za-z][A-Za-z0-9]*$ ]]; then
    echo "TYPE must be a DNS record type, such as A, AAAA, MX, or TXT." >&2
    exit 2
fi
resolver=()
if (( $# == 3 )); then
    if [[ -z $3 || $3 == [-@+]* || $3 == *[[:space:]]* ]]; then
        echo "RESOLVER must be an IP address or hostname." >&2
        exit 2
    fi
    resolver=("@$3")
fi
exec dig "${resolver[@]}" -q "$host" -t "$record_type" +time=3 +tries=1 +noall +comments +answer
