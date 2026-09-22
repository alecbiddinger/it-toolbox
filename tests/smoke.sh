#!/usr/bin/env bash
# Run inside the image; all diagnostic traffic stays on container loopback.
set -euo pipefail
for tool in bash curl dig nslookup ip ss ping jq nc nmap openssl python3 pip3 tcpdump traceroute tree whois timeout dns-check.sh port-check.sh web-check.sh; do
    command -v "$tool" >/dev/null
done
for script in /usr/local/bin/*-check.sh; do bash -n "$script"; done
test -s /etc/ssl/certs/ca-certificates.crt
temp_dir=$(mktemp -d)
server_pid=''
cleanup() {
    if [[ -n $server_pid ]]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    rm -rf -- "$temp_dir"
}
trap cleanup EXIT
printf 'toolbox smoke test\n' > "$temp_dir/index.html"
python3 -m http.server 18765 --bind 127.0.0.1 --directory "$temp_dir" >"$temp_dir/server.log" 2>&1 &
server_pid=$!
ready=false
for ((attempt=0; attempt<50; attempt++)); do
    if curl --silent --fail --max-time 1 http://127.0.0.1:18765/ >"$temp_dir/body"; then
        ready=true
        break
    fi
    sleep 0.1
done
$ready || { cat "$temp_dir/server.log" >&2; exit 1; }
grep -qx 'toolbox smoke test' "$temp_dir/body"
port-check.sh 127.0.0.1 18765
web-check.sh http://127.0.0.1:18765/
if web-check.sh http://127.0.0.1:18765/missing; then
    echo 'HTTP 404 should fail.' >&2
    exit 1
fi
if port-check.sh 127.0.0.1 65536; then
    echo 'Invalid port should fail.' >&2
    exit 1
fi
if dns-check.sh; then
    echo 'Missing DNS target should fail.' >&2
    exit 1
fi
if web-check.sh file:///etc/passwd; then
    echo 'Non-HTTP URL should fail.' >&2
    exit 1
fi
nmap -sT -Pn -n -p 18765 127.0.0.1 | grep -q '18765/tcp open'
printf '{"ok":true}\n' | jq -e '.ok == true' >/dev/null
python3 -m venv "$temp_dir/venv"
"$temp_dir/venv/bin/python" -m pip --version
echo 'Smoke checks passed.'
