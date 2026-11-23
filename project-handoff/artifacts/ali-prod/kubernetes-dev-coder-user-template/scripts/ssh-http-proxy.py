#!/usr/bin/env python3
"""Relay an SSH connection through the workspace HTTP CONNECT proxy."""
import base64
import os
import select
import socket
import ssl
import sys
from urllib.parse import unquote, urlsplit


def open_tunnel(host, port, proxy):
    url = urlsplit(proxy)
    if url.scheme not in ("http", "https") or not url.hostname:
        raise ValueError("SSH proxy requires an http:// or https:// proxy URL")
    sock = socket.create_connection(
        (url.hostname, url.port or (443 if url.scheme == "https" else 80)), timeout=20
    )
    try:
        if url.scheme == "https":
            sock = ssl.create_default_context().wrap_socket(sock, server_hostname=url.hostname)
        authority = f"[{host}]:{port}" if ":" in host else f"{host}:{port}"
        headers = [f"CONNECT {authority} HTTP/1.1", f"Host: {authority}"]
        if url.username is not None:
            credentials = f"{unquote(url.username)}:{unquote(url.password or '')}"
            token = base64.b64encode(credentials.encode()).decode()
            headers.append(f"Proxy-Authorization: Basic {token}")
        sock.sendall(("\r\n".join(headers) + "\r\n\r\n").encode())
        response = bytearray()
        while not response.endswith(b"\r\n\r\n"):
            chunk = sock.recv(1)
            if not chunk:
                raise OSError("Proxy closed before completing CONNECT response")
            response.extend(chunk)
            if len(response) > 65536:
                raise OSError("Proxy CONNECT response headers are too large")
        status = bytes(response).split(b"\r\n", 1)[0].split()
        if len(status) < 2 or status[1] != b"200":
            code = status[1].decode(errors="replace") if len(status) > 1 else "unknown"
            raise OSError(f"Proxy CONNECT failed (HTTP {code})")
        sock.settimeout(None)
        return sock
    except BaseException:
        sock.close()
        raise


def relay(sock):
    stdin = sys.stdin.fileno()
    stdout = sys.stdout.fileno()
    inputs = [stdin, sock]
    while True:
        # SSLSocket may have already buffered data beyond its readable fd.
        readable = [sock] if isinstance(sock, ssl.SSLSocket) and sock.pending() else select.select(inputs, [], [sock])[0]
        for item in readable:
            if item == stdin:
                data = os.read(stdin, 65536)
                if data:
                    sock.sendall(data)
                else:
                    inputs.remove(stdin)
                    sock.shutdown(socket.SHUT_WR)
            else:
                data = sock.recv(65536)
                if not data:
                    return
                pending = memoryview(data)
                while pending:
                    pending = pending[os.write(stdout, pending):]


def main():
    if len(sys.argv) != 3:
        raise ValueError("Usage: ssh-http-proxy.py HOST PORT")
    proxy = next((os.environ[k] for k in ("https_proxy", "HTTPS_PROXY", "http_proxy", "HTTP_PROXY") if os.environ.get(k)), "")
    if not proxy:
        raise ValueError("SSH proxy requires HTTPS_PROXY or HTTP_PROXY")
    with open_tunnel(sys.argv[1], int(sys.argv[2]), proxy) as sock:
        relay(sock)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        print(f"SSH proxy: {exc}", file=sys.stderr)
        sys.exit(1)
