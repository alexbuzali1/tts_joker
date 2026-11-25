#!/bin/bash
# Builds the scripts and sends them to the game open in Tabletop Simulator, which saves and reloads it.
#   ./tools/push_to_tts.sh          (from the repository root, with TTS running and the save you want to update open)
# Uses TTS's editor API on 127.0.0.1:39999 - the same message as the VS Code extension's "Save And Play", without
# going through VS Code (its extension truncates scripts this big). Every scripted object in build/ is sent:
# the Global script (+ its XML) and the button / mat objects' scripts.
# CAREFUL: TTS reloads the open game straight away. Don't push into a game people are playing.
set -e
cd "$(dirname "$0")/.."
lua build.lua > /dev/null
for f in build/*.lua; do luac -p "$f"; done
python3 -I - <<'PY'
import json, os, re, socket
states = {}
for f in sorted(os.listdir("build")):
    m = re.match(r"^(.*)\.([^.]+)\.(lua|xml)$", f)
    if not m:
        continue
    name, guid, ext = m.groups()
    st = states.setdefault(guid, {"name": name, "guid": guid, "script": "", "ui": ""})
    st["script" if ext == "lua" else "ui"] = open(os.path.join("build", f), encoding="utf-8").read()
msg = json.dumps({"messageID": 1, "scriptStates": list(states.values())}).encode()
try:
    s = socket.create_connection(("127.0.0.1", 39999), timeout=5)
except OSError:
    raise SystemExit("TTS isn't listening on 127.0.0.1:39999 - is Tabletop Simulator running with a game open?")
s.sendall(msg)
s.close()
print("sent %d scripts (%d KB) to TTS - it saves and reloads the open game now" % (len(states), len(msg) // 1024))
PY
