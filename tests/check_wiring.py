#!/usr/bin/env python3
"""Checks the names TTS calls by string exist where TTS looks for them (a typo there only fails inside TTS).

    python3 tests/check_wiring.py        (after lua build.lua; tests/run_all.sh runs it)

  * XML onClick / onValueChanged / onEndEdit="X" in the Global script's UI   -> function X in build/Global.-1.lua
  * Global.call("X") / Global.setTable... from the button scripts              -> function X in build/Global.-1.lua
  * click_function = "X" with function_owner = Global                         -> function X in build/Global.-1.lua
  * click_function = "X" with function_owner = an object                      -> function X in that object's script
Exits non-zero when one is missing.
"""
import glob
import os
import re
import sys

build = {os.path.basename(p): open(p).read() for p in glob.glob("build/*.lua")}
glob_src = build["Global.-1.lua"]


def defined(name, code):
    return re.search(r"^\s*function\s+" + re.escape(name) + r"\s*\(", code, re.M) is not None


missing = []
# UI event handlers named in XML strings built by the Global script
for name in sorted(set(re.findall(r'on(?:Click|ValueChanged|EndEdit)="([A-Za-z_][A-Za-z0-9_]*)"', glob_src))):
    if not defined(name, glob_src):
        missing.append("Global UI handler " + name)
# Global.call from any script
for fname, code in build.items():
    for name in sorted(set(re.findall(r'Global\.call\(\s*"([A-Za-z_][A-Za-z0-9_]*)"', code))):
        if not defined(name, glob_src):
            missing.append("Global.call(\"%s\") in %s" % (name, fname))
# object buttons: click_function with its owner
for fname, code in build.items():
    for m in re.finditer(r'click_function\s*=\s*"?([A-Za-z_][A-Za-z0-9_]*)"?,?\s*\n?\s*function_owner\s*=\s*([A-Za-z_]+)', code):
        name, owner = m.groups()
        if name in ("click_function",):
            continue
        target = glob_src if owner == "Global" else code
        if re.match(r"^[a-z_]+$", name) is None and not defined(name, target):
            missing.append("button click_function %s (owner %s) in %s" % (name, owner, fname))
# button setups called with a click function name: xxxButtonSetup(obj, "name", ...)
calls = {"startGameButtonSetup": "Start Game Button.0132bf.lua", "reshuffleButtonSetup": "Reshuffle Button.a18a04.lua",
         "turnPlayerButtonSetup": "Global.-1.lua"}
for fname, code in build.items():
    for fn, owner_file in calls.items():
        for name in re.findall(fn + r'\([^,]+,\s*"([A-Za-z_][A-Za-z0-9_]*)"', code):
            if not defined(name, build[owner_file]):
                missing.append('%s(..., "%s") in %s: no %s in %s' % (fn, name, fname, name, owner_file))
    for name in re.findall(r'playerNumberButtonSetup\(self\s*,\s*"([A-Za-z_][A-Za-z0-9_]*)"', code):
        if not defined(name, code):
            missing.append('playerNumberButtonSetup(self, "%s") in %s' % (name, fname))

if missing:
    print("WIRING: missing\n  " + "\n  ".join(missing))
    sys.exit(1)
print("wiring: every name TTS calls by string exists")
