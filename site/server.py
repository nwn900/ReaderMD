#!/usr/bin/env python3
"""Serve the PreviewMD landing page and store newsletter signups in SQLite."""

from __future__ import annotations

import json
import os
import re
import sqlite3
from datetime import datetime, timezone
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


SITE_DIR = Path(__file__).resolve().parent
DEFAULT_DB_PATH = SITE_DIR.parent / ".previewmd-data" / "subscribers.sqlite3"
DB_PATH = Path(
    os.environ.get("PREVIEWMD_SUBSCRIBERS_DB", str(DEFAULT_DB_PATH))
).expanduser().resolve()
HOST = os.environ.get("PREVIEWMD_SITE_HOST", "127.0.0.1")
PORT = int(os.environ.get("PORT", "4173"))

MAX_BODY_BYTES = 4096
EMAIL_PATTERN = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def initialize_database() -> None:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with sqlite3.connect(DB_PATH) as connection:
        connection.execute("PRAGMA journal_mode = WAL")
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS subscribers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email TEXT NOT NULL COLLATE NOCASE UNIQUE,
                created_at TEXT NOT NULL
            )
            """
        )
        connection.commit()


def store_email(email: str) -> bool:
    """Store an email and return True when it was newly inserted."""
    created_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
    with sqlite3.connect(DB_PATH, timeout=5) as connection:
        cursor = connection.execute(
            "INSERT OR IGNORE INTO subscribers (email, created_at) VALUES (?, ?)",
            (email, created_at),
        )
        connection.commit()
        return cursor.rowcount == 1


class PreviewMDRequestHandler(SimpleHTTPRequestHandler):
    server_version = "PreviewMDLanding/1.0"

    def end_headers(self) -> None:
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "strict-origin-when-cross-origin")
        super().end_headers()

    def do_POST(self) -> None:
        if urlsplit(self.path).path != "/api/subscribe":
            self.send_json(404, {"ok": False, "error": "not_found"})
            return

        content_type = self.headers.get("Content-Type", "")
        if not content_type.lower().startswith("application/json"):
            self.send_json(415, {"ok": False, "error": "json_required"})
            return

        try:
            content_length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_json(400, {"ok": False, "error": "invalid_length"})
            return

        if content_length <= 0 or content_length > MAX_BODY_BYTES:
            self.send_json(413, {"ok": False, "error": "invalid_body_size"})
            return

        try:
            payload = json.loads(self.rfile.read(content_length))
        except (json.JSONDecodeError, UnicodeDecodeError):
            self.send_json(400, {"ok": False, "error": "invalid_json"})
            return

        email_value = payload.get("email") if isinstance(payload, dict) else None
        email = email_value.strip().lower() if isinstance(email_value, str) else ""
        if len(email) > 254 or not EMAIL_PATTERN.fullmatch(email):
            self.send_json(422, {"ok": False, "error": "invalid_email"})
            return

        try:
            created = store_email(email)
        except sqlite3.Error:
            self.log_error("Could not store newsletter signup")
            self.send_json(500, {"ok": False, "error": "storage_failed"})
            return

        # Returning success for existing addresses avoids disclosing list membership.
        self.send_json(
            201 if created else 200,
            {"ok": True, "status": "subscribed"},
        )

    def send_json(self, status: int, payload: dict[str, object]) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    os.umask(0o077)
    initialize_database()
    handler = partial(PreviewMDRequestHandler, directory=str(SITE_DIR))
    server = ThreadingHTTPServer((HOST, PORT), handler)
    print(f"PreviewMD landing: http://{HOST}:{PORT}")
    print(f"Subscriber database: {DB_PATH}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
