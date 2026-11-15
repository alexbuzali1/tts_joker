#!/usr/bin/env python3
"""Receives "Flag bad move" reports from the Joker bot in Tabletop Simulator and saves them.

TTS posts each flag (JSON) to http://127.0.0.1:8765/flag. Each one is written to
data/flags/flag_<time>_<n>.json and appended to data/flags/flags.jsonl (data/ is in the repository root and is
not committed: flags and logs contain player names). Game logs (http://127.0.0.1:8765/log) go to
data/logs/game_<start time>.jsonl. It only listens on 127.0.0.1, so nothing outside this computer can reach it.

Run (from anywhere):  python3 tools/flag_server.py      (Ctrl+C to stop)
"""
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs

HOST, PORT = "127.0.0.1", 8765
DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
FLAG_DIR = os.path.join(DATA_DIR, "flags")
LOG_DIR = os.path.join(DATA_DIR, "logs")
os.makedirs(FLAG_DIR, exist_ok=True)
os.makedirs(LOG_DIR, exist_ok=True)
counter = 0


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        global counter
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length).decode("utf-8", errors="replace")
        if self.path.startswith("/log"):
            self.save_log(body)
            return
        # TTS may send raw JSON or a form field "flag=<json>"
        if "application/x-www-form-urlencoded" in (self.headers.get("Content-Type") or ""):
            body = (parse_qs(body).get("flag") or [""])[0]
        try:
            flag = json.loads(body)
        except ValueError:
            flag = {"unparsed": body}
        counter += 1
        stamp = time.strftime("%Y%m%d_%H%M%S")
        path = os.path.join(FLAG_DIR, "flag_%s_%d.json" % (stamp, counter))
        with open(path, "w") as f:
            json.dump(flag, f, indent=2)
        with open(os.path.join(FLAG_DIR, "flags.jsonl"), "a") as f:
            f.write(json.dumps(flag) + "\n")
        last = (flag.get("recent_bot_moves") or [{}])[-1] if isinstance(flag, dict) else {}
        print("FLAG saved: %s | last bot move: %s %s | note: %s" % (
            os.path.basename(path), last.get("bot", "?"), (last.get("chosen") or {}).get("text", "?"),
            flag.get("note", "") if isinstance(flag, dict) else ""), flush=True)
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"saved")

    def save_log(self, body):
        """Game log batch from host/game_log.lua: {"game": "<start time>", "events": [...]} -> logs/game_<game>.jsonl"""
        try:
            batch = json.loads(body)
        except ValueError:
            batch = {"game": "unparsed", "events": [{"kind": "unparsed", "text": body[:2000]}]}
        game = "".join(ch for ch in str(batch.get("game") or "nogame") if ch.isalnum() or ch in "_-")
        path = os.path.join(LOG_DIR, "game_%s.jsonl" % game)
        events = batch.get("events") or []
        with open(path, "a") as f:
            for ev in events:
                f.write(json.dumps(ev) + "\n")
        for ev in events:
            kind = ev.get("kind") if isinstance(ev, dict) else None
            if kind == "error":
                print("LOG ERROR [%s turn %s]: %s" % (game, ev.get("turn"), ev.get("text")), flush=True)
            elif kind == "mismatch":
                print("LOG MISMATCH [%s turn %s]: %s %s" % (game, ev.get("turn"), ev.get("move"), ev.get("diffs")), flush=True)
            elif kind == "game_start":
                print("LOG game %s started (%s players, all bots: %s)" % (game, ev.get("num_players"), ev.get("all_bots")), flush=True)
            elif kind == "game_over":
                print("LOG game %s over: team %s wins (turn %s)" % (game, ev.get("team"), ev.get("turn")), flush=True)
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"logged")

    def do_GET(self):  # health check: curl http://127.0.0.1:8765/
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"joker flag server running")

    def log_message(self, *args):  # keep the output to one line per flag
        pass


if __name__ == "__main__":
    print("Joker flag server listening on http://%s:%d, saving to %s" % (HOST, PORT, FLAG_DIR), flush=True)
    try:
        HTTPServer((HOST, PORT), Handler).serve_forever()
    except KeyboardInterrupt:
        sys.exit(0)
