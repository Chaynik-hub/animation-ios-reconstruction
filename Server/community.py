"""AnimationIOS community API. Run behind an HTTPS reverse proxy."""
import hashlib
import io
import json
import os
import re
import sqlite3
import uuid
import zipfile
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

LIMIT = 16 * 1024 * 1024
DATABASE = Path(os.environ.get("ANIMATION_DB", "community.sqlite3"))


def connect():
    db = sqlite3.connect(DATABASE)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys = ON")
    return db


def text(value, maximum):
    if isinstance(value, str) and 0 < len(value.strip()) <= maximum:
        return value.strip()
    raise ValueError("Invalid text")


class API(BaseHTTPRequestHandler):
    def answer(self, value, status=200, content_type="application/json"):
        body = value if isinstance(value, bytes) else json.dumps(value, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self.dispatch(False)

    def do_POST(self):
        self.dispatch(True)

    def dispatch(self, post):
        path = urlsplit(self.path).path
        try:
            with closing(connect()) as db, db:
                if not post and path == "/projects":
                    rows = db.execute("""
                        SELECT p.id, p.title, p.author, AVG(r.stars) AS average, COUNT(r.stars) AS votes
                        FROM projects p LEFT JOIN ratings r ON r.project = p.id
                        GROUP BY p.id ORDER BY p.rowid DESC LIMIT 100
                    """)
                    return self.answer([dict(row) for row in rows])
                if post and path == "/projects":
                    return self.publish(db)
                match = re.fullmatch(r"/projects/([a-f0-9]{32})/(archive|comments|rating)", path)
                if not match:
                    return self.answer({"error": "Not found"}, 404)
                project, action = match.groups()
                if not db.execute("SELECT 1 FROM projects WHERE id = ?", (project,)).fetchone():
                    return self.answer({"error": "Project not found"}, 404)
                if not post and action == "archive":
                    data = db.execute("SELECT archive FROM projects WHERE id = ?", (project,)).fetchone()[0]
                    return self.answer(data, content_type="application/zip")
                if not post and action == "comments":
                    rows = db.execute(
                        "SELECT author, body FROM comments WHERE project = ? ORDER BY rowid DESC LIMIT 100",
                        (project,),
                    )
                    return self.answer([dict(row) for row in rows])
                if post and action in {"comments", "rating"}:
                    return self.react(db, project, action)
                return self.answer({"error": "Method not allowed"}, 405)
        except (ValueError, TypeError, zipfile.BadZipFile):
            self.answer({"error": "Invalid request"}, 400)
        except sqlite3.Error:
            self.answer({"error": "Database unavailable"}, 503)

    def read_body(self, limit):
        size = int(self.headers.get("Content-Length", "0"))
        if not 0 < size <= limit:
            raise ValueError("Invalid size")
        data = self.rfile.read(size)
        if len(data) != size:
            raise ValueError("Incomplete body")
        return data

    def publish(self, db):
        data = self.read_body(LIMIT)
        from urllib.parse import unquote
        title = text(unquote(self.headers.get("X-Project-Title", "")), 80)
        author = text(unquote(self.headers.get("X-Project-Author", "")), 32)
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            entries = archive.infolist()
            if (
                len(entries) > 4096
                or "model.xml" not in archive.namelist()
                or sum(entry.file_size for entry in entries) > 64 * 1024 * 1024
            ):
                raise ValueError("Invalid archive")
        identifier = uuid.uuid4().hex
        db.execute("INSERT INTO projects VALUES (?, ?, ?, ?)", (identifier, title, author, data))
        db.commit()
        return self.answer({"id": identifier}, 201)

    def react(self, db, project, action):
        value = json.loads(self.read_body(4096))
        if not isinstance(value, dict):
            raise ValueError("Invalid reaction")
        token = self.headers.get("Authorization", "").removeprefix("Bearer ")
        if not re.fullmatch(r"[a-fA-F0-9-]{36}", token):
            raise ValueError("Invalid device token")
        voter = hashlib.sha256(token.encode()).hexdigest()
        if action == "rating":
            stars = value.get("stars")
            if type(stars) is not int or not 1 <= stars <= 5:
                raise ValueError("Invalid rating")
            db.execute("INSERT OR REPLACE INTO ratings VALUES (?, ?, ?)", (project, voter, stars))
        else:
            author = text(value.get("author"), 32)
            body = text(value.get("body"), 500)
            db.execute("INSERT INTO comments VALUES (?, ?, ?)", (project, author, body))
        db.commit()
        return self.answer({"ok": True})


if __name__ == "__main__":
    DATABASE.parent.mkdir(parents=True, exist_ok=True)
    with closing(connect()) as db, db:
        db.executescript("""
            PRAGMA journal_mode = WAL;
            CREATE TABLE IF NOT EXISTS projects (
                id TEXT PRIMARY KEY, title TEXT NOT NULL, author TEXT NOT NULL, archive BLOB NOT NULL
            );
            CREATE TABLE IF NOT EXISTS ratings (
                project TEXT REFERENCES projects(id), voter TEXT, stars INTEGER NOT NULL,
                PRIMARY KEY (project, voter)
            );
            CREATE TABLE IF NOT EXISTS comments (
                project TEXT REFERENCES projects(id), author TEXT NOT NULL, body TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS comments_by_project ON comments(project);
        """)
    host = os.environ.get("ANIMATION_HOST", "127.0.0.1")
    port = int(os.environ.get("PORT", "8080"))
    ThreadingHTTPServer((host, port), API).serve_forever()
