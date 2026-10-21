"""Loopback servers for smoke.sh: HTTP, HTTPS, DNS, and endpoints that never answer."""
import http.server
import pathlib
import socket
import ssl
import struct
import sys
import threading
import time

web_root, cert, key, ready = sys.argv[1:5]


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=web_root, **kwargs)

    def log_message(self, *args):
        pass


def serve_http(port, tls=False):
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), QuietHandler)
    if tls:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(cert, key)
        server.socket = context.wrap_socket(server.socket, server_side=True)
    threading.Thread(target=server.serve_forever, daemon=True).start()


def encode_name(name):
    return b"".join(bytes([len(label)]) + label.encode() for label in name.split(".")) + b"\0"


# Name -> {query type: RDATA}. Unlisted names are NXDOMAIN; listed names without
# the requested type return NOERROR with no answer.
ZONE = {
    "lab.test": {1: bytes([192, 0, 2, 1])},
    "1.2.0.192.in-addr.arpa": {12: encode_name("lab.test")},
}


def serve_dns(sock):
    while True:
        query, peer = sock.recvfrom(512)
        end, labels = 12, []
        while query[end]:
            labels.append(query[end + 1:end + 1 + query[end]].decode().lower())
            end += query[end] + 1
        qtype = struct.unpack("!H", query[end + 1:end + 3])[0]
        records = ZONE.get(".".join(labels))
        rdata = (records or {}).get(qtype)
        answer = b""
        if rdata:
            answer = b"\xc0\x0c" + struct.pack("!HHIH", qtype, 1, 60, len(rdata)) + rdata
        flags = 0x8180 if records is not None else 0x8183
        header = query[:2] + struct.pack("!HHHHH", flags, 1, 1 if rdata else 0, 0, 0)
        sock.sendto(header + query[12:end + 5] + answer, peer)


serve_http(8765)
serve_http(8443, tls=True)
dns = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
dns.bind(("127.0.0.1", 53))
threading.Thread(target=serve_dns, args=(dns,), daemon=True).start()

# A resolver that never replies, and a TCP listener whose full accept queue drops
# new SYNs, so connection attempts wait for the helper's own timeout.
silent = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
silent.bind(("127.0.0.2", 53))
blackhole = socket.socket()
blackhole.bind(("127.0.0.1", 8999))
blackhole.listen(0)
fillers = []
for _ in range(3):
    filler = socket.socket()
    filler.setblocking(False)
    filler.connect_ex(("127.0.0.1", 8999))
    fillers.append(filler)
time.sleep(0.2)

pathlib.Path(ready).touch()
threading.Event().wait()
