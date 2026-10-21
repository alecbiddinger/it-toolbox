#!/usr/bin/env bash
# Run inside the image; all diagnostic traffic stays on container loopback.
set -euo pipefail
tests_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
missing=()
for tool in bash curl dig nslookup ip ss ping jq nc nmap openssl python3 pip3 tcpdump traceroute tree whois timeout dns-check.sh port-check.sh web-check.sh; do
    command -v "$tool" >/dev/null || missing+=("$tool")
done
if (( ${#missing[@]} )); then
    echo "Missing commands: ${missing[*]}" >&2
    exit 1
fi
for script in /usr/local/bin/*-check.sh; do bash -n "$script"; done
test -s /etc/ssl/certs/ca-certificates.crt
test -s /usr/share/doc/it-toolbox/LICENSE

temp_dir=$(mktemp -d)
fixture_pid=''
failures=0
cleanup() {
    if [[ -n $fixture_pid ]]; then
        kill "$fixture_pid" 2>/dev/null || true
        wait "$fixture_pid" 2>/dev/null || true
    fi
    rm -rf -- "$temp_dir"
}
trap cleanup EXIT

# expect STATUS COMMAND...: run COMMAND and require exactly that exit status.
expect() {
    local want=$1 got=0
    shift
    "$@" >"$temp_dir/out" 2>&1 || got=$?
    if (( got != want )); then
        printf 'FAIL: expected exit %s, got %s: %s\n' "$want" "$got" "$*" >&2
        sed 's/^/    /' "$temp_dir/out" >&2
        failures=$((failures + 1))
    fi
}

# expect_output REGEX: require the previous expect's output to match REGEX.
expect_output() {
    if ! grep -Eq -- "$1" "$temp_dir/out"; then
        printf 'FAIL: output does not match /%s/\n' "$1" >&2
        sed 's/^/    /' "$temp_dir/out" >&2
        failures=$((failures + 1))
    fi
}

# within SECONDS STATUS COMMAND...: like expect, and require it to finish in time.
within() {
    local limit=$1 start=${EPOCHREALTIME//[!0-9]/} elapsed
    shift
    expect "$@"
    elapsed=$(( (${EPOCHREALTIME//[!0-9]/} - start) / 1000000 ))
    if (( elapsed >= limit )); then
        printf 'FAIL: took %ss, limit %ss: %s\n' "$elapsed" "$limit" "${*:2}" >&2
        failures=$((failures + 1))
    fi
}

mkdir -p "$temp_dir/www/dir" "$temp_dir/home"
printf 'toolbox smoke test\n' > "$temp_dir/www/index.html"
printf 'insecure\n' > "$temp_dir/home/.curlrc"
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 1 \
    -subj /CN=127.0.0.1 -addext subjectAltName=IP:127.0.0.1 \
    -keyout "$temp_dir/key.pem" -out "$temp_dir/cert.pem" 2>/dev/null
python3 "$tests_dir/fixtures.py" "$temp_dir/www" "$temp_dir/cert.pem" "$temp_dir/key.pem" \
    "$temp_dir/ready" 2>"$temp_dir/fixtures.log" &
fixture_pid=$!
for ((attempt=0; attempt<50; attempt++)); do
    [[ -e $temp_dir/ready ]] && break
    sleep 0.1
done
[[ -e $temp_dir/ready ]] || { cat "$temp_dir/fixtures.log" >&2; exit 1; }

# Invalid arguments exit 2 before any tool runs.
expect 2 dns-check.sh
expect 2 dns-check.sh ''
expect 2 dns-check.sh -f /etc/passwd
expect 2 dns-check.sh +short
expect 2 dns-check.sh 'lab test'
expect 2 dns-check.sh lab..test
expect 2 dns-check.sh lab.test MXX
expect 2 dns-check.sh lab.test 'A;'
expect 2 dns-check.sh lab.test A ''
expect 2 dns-check.sh lab.test A @127.0.0.1
expect 2 dns-check.sh lab.test A '127.0.0.1 x'
expect 2 dns-check.sh a b c d
expect 2 port-check.sh
expect 2 port-check.sh 127.0.0.1
expect 2 port-check.sh -h 80
expect 2 port-check.sh 127.0.0.1 0
expect 2 port-check.sh 127.0.0.1 65536
expect 2 port-check.sh 127.0.0.1 http
expect 2 web-check.sh
expect 2 web-check.sh file:///etc/passwd
expect 2 web-check.sh 'http://a b'
expect 2 web-check.sh http://x http://y

# DNS against the loopback stub resolver.
expect 0 dns-check.sh lab.test A 127.0.0.1
expect_output 'status: NOERROR'
expect_output 'IN[[:space:]]+A[[:space:]]+192\.0\.2\.1'
expect 0 dns-check.sh lab.test aaaa 127.0.0.1
expect_output 'ANSWER: 0,'
expect 0 dns-check.sh missing.test A 127.0.0.1
expect_output 'status: NXDOMAIN'
expect 0 dns-check.sh 192.0.2.1 PTR 127.0.0.1
expect_output 'PTR[[:space:]]+lab\.test\.'
within 5 9 timeout 10 dns-check.sh lab.test A 127.0.0.2

# TCP: open, leading-zero decimal port, refused, and unanswered connections.
expect 0 port-check.sh 127.0.0.1 8765
expect 0 port-check.sh 127.0.0.1 08765
expect 1 port-check.sh 127.0.0.1 8766
within 5 1 timeout 10 port-check.sh 127.0.0.1 8999
nmap -sT -Pn -n -p 8765 127.0.0.1 | grep -q '8765/tcp open'

# HTTP: success, HTTP errors, unfollowed redirects, and connection failures.
expect 0 web-check.sh http://127.0.0.1:8765/
expect_output '^HTTP=200 '
expect 22 web-check.sh http://127.0.0.1:8765/missing
expect_output '^HTTP=404 '
expect 0 web-check.sh http://127.0.0.1:8765/dir
expect_output '^HTTP=301 '
expect 7 web-check.sh http://127.0.0.1:8766/
within 8 28 timeout 10 web-check.sh http://127.0.0.1:8999/

# TLS: verification is enforced, even when ~/.curlrc asks for --insecure.
expect 60 web-check.sh https://127.0.0.1:8443/
expect 0 env CURL_CA_BUNDLE="$temp_dir/cert.pem" web-check.sh https://127.0.0.1:8443/
expect_output '^HTTP=200 '
expect 60 env HOME="$temp_dir/home" web-check.sh https://127.0.0.1:8443/

printf '{"ok":true}\n' | jq -e '.ok == true' >/dev/null
python3 -m venv "$temp_dir/venv"
"$temp_dir/venv/bin/python" -m pip --version >/dev/null

if (( failures )); then
    echo "$failures smoke check(s) failed." >&2
    exit 1
fi
echo 'Smoke checks passed.'
