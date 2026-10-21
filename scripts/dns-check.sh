#!/usr/bin/env bash
# Display DNS status and answers. dig's exit code does not guarantee records exist.
set -euo pipefail
if (( $# < 1 || $# > 3 )) || [[ -z $1 || $1 == [-@+]* ]]; then
    echo "Usage: dns-check.sh HOST [TYPE] [RESOLVER]" >&2
    exit 2
fi
host=$1
if [[ $host == *[[:space:]]* || $host == *..* ]]; then
    echo "HOST must be a hostname or IP address without spaces or empty labels." >&2
    exit 2
fi
record_type=${2:-A}
record_type=${record_type^^}
# dig silently queries A for an unknown type, so accept common types or RFC 3597 TYPEnnn.
known_types='A|AAAA|ANY|CAA|CDNSKEY|CDS|CNAME|DNAME|DNSKEY|DS|HINFO|HTTPS|LOC|MX|NAPTR|NS|NSEC|NSEC3|NSEC3PARAM|PTR|RRSIG|SOA|SRV|SSHFP|SVCB|TLSA|TXT|URI|TYPE[0-9]{1,5}'
if [[ ! $record_type =~ ^($known_types)$ ]]; then
    echo "TYPE must be a DNS record type, such as A, AAAA, MX, TXT, or TYPE65." >&2
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
query=(-q "$host" -t "$record_type")
# A PTR query for an IP address means a reverse lookup of its in-addr/ip6 name.
if [[ $record_type == PTR && ( $host =~ ^[0-9]+(\.[0-9]+){3}$ || $host == *:* ) ]]; then
    query=(-x "$host")
fi
exec dig "${resolver[@]}" "${query[@]}" +time=3 +tries=1 +noall +comments +answer
