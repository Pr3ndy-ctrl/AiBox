#!/usr/bin/env python3
"""
aibox network allow-list proxy (HTTP CONNECT + HTTP proxy).

Cooperative: clients must honour HTTP_PROXY / HTTPS_PROXY.
Used when aibox is started with --allow-net host1,host2,...

Usage:
  aibox-proxy.py --port 0 --allow api.openai.com,api.anthropic.com --log /path/to.log
  (prints the bound port on stdout, then serves)

Exit codes:
  0 = clean shutdown
  1 = configuration / bind error
"""

from __future__ import annotations

import argparse
import json
import select
import socket
import socketserver
import sys
import threading
import time
from datetime import datetime, timezone
from typing import Set
from urllib.parse import urlparse


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


class AllowListProxy(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, server_address, RequestHandlerClass, allow_hosts: Set[str], log_path: str | None):
        self.allow_hosts = {h.lower().rstrip(".") for h in allow_hosts}
        self.log_path = log_path
        self.lock = threading.Lock()
        super().__init__(server_address, RequestHandlerClass)

    def log_event(self, event: dict) -> None:
        event["ts"] = utc_now()
        line = json.dumps(event, separators=(",", ":"))
        with self.lock:
            if self.log_path:
                try:
                    with open(self.log_path, "a", encoding="utf-8") as f:
                        f.write(line + "\n")
                except OSError:
                    pass
            # Always emit to stderr for aibox parent to capture if desired
            print(line, file=sys.stderr, flush=True)


class ProxyHandler(socketserver.StreamRequestHandler):
    def handle(self) -> None:
        server: AllowListProxy = self.server  # type: ignore
        try:
            first = self.rfile.readline(65536)
            if not first:
                return
            line = first.decode("utf-8", errors="replace").strip()
            parts = line.split()
            if len(parts) < 2:
                self._reply(400, b"Bad Request")
                return

            method, target = parts[0].upper(), parts[1]

            # Consume headers
            headers: list[bytes] = []
            while True:
                h = self.rfile.readline(65536)
                if not h or h in (b"\r\n", b"\n"):
                    break
                headers.append(h)

            if method == "CONNECT":
                host_port = target
                if ":" in host_port:
                    host, port_s = host_port.rsplit(":", 1)
                    try:
                        port = int(port_s)
                    except ValueError:
                        self._reply(400, b"Bad Request")
                        return
                else:
                    host, port = host_port, 443
                self._handle_connect(server, host, port)
            else:
                # Plain HTTP proxy
                parsed = urlparse(target)
                host = parsed.hostname or ""
                port = parsed.port or 80
                path = parsed.path or "/"
                if parsed.query:
                    path += "?" + parsed.query
                self._handle_http(server, method, host, port, path, headers)
        except Exception as e:
            server.log_event({"event": "proxy_error", "error": str(e)})

    def _allowed(self, server: AllowListProxy, host: str) -> bool:
        h = host.lower().rstrip(".")
        if h in server.allow_hosts:
            return True
        # simple suffix match for *.example.com style if user listed example.com
        for allowed in server.allow_hosts:
            if h == allowed or h.endswith("." + allowed):
                return True
        return False

    def _handle_connect(self, server: AllowListProxy, host: str, port: int) -> None:
        if not self._allowed(server, host):
            server.log_event({"event": "denied", "method": "CONNECT", "host": host, "port": port})
            self._reply(403, b"Forbidden by aibox allow-list")
            return

        try:
            remote = socket.create_connection((host, port), timeout=15)
        except OSError as e:
            server.log_event({"event": "connect_fail", "host": host, "port": port, "error": str(e)})
            self._reply(502, b"Bad Gateway")
            return

        server.log_event({"event": "allowed", "method": "CONNECT", "host": host, "port": port})
        self.wfile.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        self.wfile.flush()
        self._tunnel(self.request, remote)

    def _handle_http(
        self,
        server: AllowListProxy,
        method: str,
        host: str,
        port: int,
        path: str,
        headers: list[bytes],
    ) -> None:
        if not host or not self._allowed(server, host):
            server.log_event({"event": "denied", "method": method, "host": host, "port": port})
            self._reply(403, b"Forbidden by aibox allow-list")
            return

        try:
            remote = socket.create_connection((host, port), timeout=15)
        except OSError as e:
            server.log_event({"event": "connect_fail", "host": host, "port": port, "error": str(e)})
            self._reply(502, b"Bad Gateway")
            return

        server.log_event({"event": "allowed", "method": method, "host": host, "port": port})
        req = f"{method} {path} HTTP/1.1\r\n".encode()
        remote.sendall(req)
        for h in headers:
            # strip Proxy-Connection etc.
            if h.lower().startswith(b"proxy-"):
                continue
            remote.sendall(h)
        remote.sendall(b"\r\n")
        self._tunnel(self.request, remote)

    def _tunnel(self, client: socket.socket, remote: socket.socket) -> None:
        client.setblocking(False)
        remote.setblocking(False)
        try:
            while True:
                r, _, _ = select.select([client, remote], [], [], 60)
                if not r:
                    break
                if client in r:
                    data = client.recv(65536)
                    if not data:
                        break
                    remote.sendall(data)
                if remote in r:
                    data = remote.recv(65536)
                    if not data:
                        break
                    client.sendall(data)
        except OSError:
            pass
        finally:
            try:
                remote.close()
            except OSError:
                pass

    def _reply(self, code: int, msg: bytes) -> None:
        body = msg + b"\n"
        self.wfile.write(
            f"HTTP/1.1 {code} {msg.decode()}\r\n"
            f"Content-Length: {len(body)}\r\n"
            f"Connection: close\r\n\r\n".encode()
            + body
        )
        self.wfile.flush()


def main() -> int:
    ap = argparse.ArgumentParser(description="aibox allow-list HTTP proxy")
    ap.add_argument("--port", type=int, default=0, help="Listen port (0 = ephemeral)")
    ap.add_argument("--allow", required=True, help="Comma-separated host allow-list")
    ap.add_argument("--log", default=None, help="Append JSON events to this file")
    ap.add_argument("--bind", default="127.0.0.1", help="Bind address")
    args = ap.parse_args()

    hosts = {h.strip() for h in args.allow.split(",") if h.strip()}
    if not hosts:
        print("empty allow-list", file=sys.stderr)
        return 1

    server = AllowListProxy((args.bind, args.port), ProxyHandler, hosts, args.log)
    bound_port = server.server_address[1]
    # Parent reads the first line as the port
    print(bound_port, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.shutdown()
    return 0


if __name__ == "__main__":
    sys.exit(main())
