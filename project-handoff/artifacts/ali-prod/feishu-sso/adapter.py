"""Adapt Feishu OAuth responses for Dex. Only listens on pod loopback."""
import base64
import hmac
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from pinyin_table import PINYIN

CLIENT_ID = os.environ.get("FEISHU_CLIENT_ID", "")
CLIENT_SECRET = os.environ.get("FEISHU_CLIENT_SECRET", "")
CALLBACK = "https://coder.magikcloud.cn/sso/callback"

# Surname readings for characters whose surname reading differs from their
# most common reading. Applied only to the first character of a name, so
# 单(shan)伟 gets "shanwei" while 明单 keeps the common reading "dan".
SURNAMES = {
    "曾": "zeng", "单": "shan", "查": "zha", "仇": "qiu", "重": "chong",
    "都": "du", "繁": "po", "句": "gou", "乐": "yue", "缪": "miao",
    "朴": "piao", "区": "ou", "覃": "qin", "折": "she", "解": "xie",
    "员": "yun",
}


def pinyin_username(name, fallback):
    """Best-effort ASCII username from a display name.

    CJK characters become toneless pinyin, ASCII alphanumerics pass through
    lowercased, and everything else (spaces, dots, unknown characters) is
    dropped. Caller usernames come from the stable open_id when this yields
    nothing.
    """
    parts = []
    for index, char in enumerate(name):
        if index == 0 and char in SURNAMES:
            parts.append(SURNAMES[char])
        elif char in PINYIN:
            parts.append(PINYIN[char])
        elif char.isascii() and char.isalnum():
            parts.append(char.lower())
    return "".join(parts)[:32] or fallback


def upstream(path, token=None, payload=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    request = urllib.request.Request(
        "https://open.feishu.cn/open-apis/" + path,
        data=json.dumps(payload).encode() if payload is not None else None,
        headers=headers,
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        result = json.load(response)
    if str(result.get("code", 0)) != "0":
        raise ValueError("Feishu rejected request")
    return result


def identity(result):
    data = result.get("data", {})
    subject = data.get("open_id", "")
    if not re.fullmatch(r"ou_[A-Za-z0-9_-]+", subject):
        raise ValueError("Missing Feishu identity")
    # Stable account identifier, not a deliverable or verified mailbox.
    # preferred_username becomes the Coder username for new signups; existing
    # accounts are matched by id and never renamed by later logins.
    return {
        "id": subject,
        "user_name": data.get("name") or subject,
        "preferred_username": pinyin_username(data.get("name") or "", subject),
        "email": subject + "@feishu.invalid",
        "email_verified": False,
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass  # Never log authorization codes, tokens or user data.

    def reply(self, status, body):
        encoded = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def do_POST(self):
        if self.path != "/token":
            return self.reply(404, {"error": "invalid_request"})
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length < 16384:
                raise ValueError("Invalid request length")
            fields = urllib.parse.parse_qs(self.rfile.read(length).decode())
            client_id = fields.get("client_id", [""])[0]
            secret = fields.get("client_secret", [""])[0]
            authorization = self.headers.get("Authorization", "")
            if authorization.startswith("Basic "):
                client_id, secret = base64.b64decode(authorization[6:], validate=True).decode().split(":", 1)
                client_id, secret = urllib.parse.unquote(client_id), urllib.parse.unquote(secret)
            if not hmac.compare_digest(client_id, CLIENT_ID) or not hmac.compare_digest(secret, CLIENT_SECRET):
                return self.reply(401, {"error": "invalid_client"})
            grant = fields.get("grant_type", [""])[0]
            code = fields.get("code", [""])[0]
            redirect = fields.get("redirect_uri", [""])[0]
            if grant != "authorization_code" or not code or redirect != CALLBACK:
                return self.reply(400, {"error": "invalid_request"})
            result = upstream("authen/v2/oauth/token", payload={
                "grant_type": grant, "client_id": CLIENT_ID, "client_secret": CLIENT_SECRET,
                "code": code, "redirect_uri": CALLBACK,
            })
            if not result.get("access_token"):
                raise ValueError("Missing token")
            self.reply(200, {
                "access_token": result["access_token"], "token_type": "Bearer",
                "expires_in": result.get("expires_in", 7200),
            })
        except (ValueError, KeyError, UnicodeError):
            self.reply(400, {"error": "invalid_grant"})
        except (urllib.error.URLError, TimeoutError, OSError):
            self.reply(502, {"error": "temporarily_unavailable"})

    def do_GET(self):
        if self.path == "/healthz":
            return self.reply(200, {"status": "ok"})
        if self.path != "/userinfo":
            return self.reply(404, {"error": "invalid_request"})
        authorization = self.headers.get("Authorization", "")
        if not authorization.startswith("Bearer ") or len(authorization) > 8192:
            return self.reply(401, {"error": "invalid_token"})
        try:
            self.reply(200, identity(upstream("authen/v1/user_info", token=authorization[7:])))
        except (ValueError, KeyError):
            self.reply(401, {"error": "invalid_token"})
        except (urllib.error.URLError, TimeoutError, OSError):
            self.reply(502, {"error": "temporarily_unavailable"})


if __name__ == "__main__":
    if not CLIENT_ID or not CLIENT_SECRET:
        raise SystemExit("Feishu credentials are required")
    ThreadingHTTPServer(("127.0.0.1", 8081), Handler).serve_forever()
