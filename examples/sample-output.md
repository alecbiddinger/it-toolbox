# Local troubleshooting walkthrough

These outputs are **illustrative**, not captured test results. This lab only
contacts a server in the same container. Versions, timing, and formatting vary.
Start the named mounted session from README.md first.

## 1. Start the server

In its container Bash shell:

```bash
mkdir -p /tmp/toolbox-demo
printf 'Toolbox HTTP test\n' > /tmp/toolbox-demo/index.html
python3 -m http.server 8000 --bind 127.0.0.1 --directory /tmp/toolbox-demo
```

Leave it running. In another host PowerShell terminal:

```powershell
docker exec -it it-toolbox-session bash
```

## 2. Check each layer

In the second container Bash shell:

```bash
ss -lnt
port-check.sh 127.0.0.1 8000
nmap -sT -Pn -n -p 8000 127.0.0.1
web-check.sh http://127.0.0.1:8000/
curl --fail --max-time 5 http://127.0.0.1:8000/
```

Expected highlights:

```text
Connection to 127.0.0.1 8000 port [tcp/*] succeeded!
8000/tcp open ...
HTTP/1.0 200 OK
HTTP=200 DNS=...s Connect=...s Total=...s
Toolbox HTTP test
```

The socket list shows a listener, netcat confirms TCP, Nmap reports an open
port, the helper checks HTTP, and curl retrieves the expected body. Nmap's
service-name column without `-sV` is a port-name guess, not identified software.

## 3. Save a report and observe a failure

```bash
web-check.sh http://127.0.0.1:8000/ > /work/local-web-check.txt
web-check.sh http://127.0.0.1:8000/missing
echo $?  # Expected: 22 (curl HTTP error)
```

The missing path returns HTTP 404 even though TCP connectivity still works.
Stop the server with Ctrl+C in its original terminal, then exit both shells.
The report remains in the host `work/` directory.

## 4. Try DNS separately

Start a one-shot DNS check from host PowerShell:

```powershell
docker run --rm it-toolbox:1.0.0 dns-check.sh example.com A
```

This uses external DNS, unlike the loopback lab. Inspect `status: NOERROR` and
an answer rather than relying on a particular address. `NXDOMAIN`, an empty
answer, and a timeout are different outcomes. Do not paste real lab inventories
or packet captures into public examples.
