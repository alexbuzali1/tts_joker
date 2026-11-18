#!/usr/bin/env python3
"""Turns a game log into one line per turn, for tools/compare_humans.lua.

    python3 tools/log_turns.py data/logs/game_XXXX.jsonl > data/game_XXXX_turns.txt

Each line: turn|seat|seat colour|card token|board before|board after   (boards: one token per marble, seat by seat,
e.g. "R12 G3 S0"). Only turns where exactly one card was played are written (the card a player played early, during
the turn before theirs, counts for their own turn). The seat -> player names are printed to stderr.
"""
import collections
import json
import re
import sys

rows = [json.loads(line) for line in open(sys.argv[1])]
start = next(r for r in rows if r["kind"] == "game_start")
seat_colors = [s["color"] for s in start["seats"]]


def token(name):
    if name == "Joker":
        return "$"
    m = re.match(r"^(\w+) of", name or "")
    if not m:
        return None
    return {"Ace": "a", "Jack": "j", "Queen": "q", "King": "k"}.get(m.group(1), m.group(1))


pending, turns, cur = {}, [], None
names = collections.defaultdict(collections.Counter)
for r in rows:
    if r["kind"] == "turn_start":
        if cur is not None:
            turns.append((cur, r, pending.pop(cur["color"], [])))
        cur = r
    elif r["kind"] == "card_played":
        pending.setdefault(r["color"], []).append(r["card"])
    elif r["kind"] == "chat" and cur is not None:
        m = re.match(r"^(.*?) (played a|ended their turn)", r.get("text", ""))
        if m:
            names[cur["color"]][m.group(1)] += 1

for before, after, cards in turns:
    if len(cards) != 1 or not token(cards[0]) or not before.get("board") or not after.get("board"):
        continue
    seat = seat_colors.index(before["color"]) + 1
    print("%s|%d|%s|%s|%s|%s" % (before["turn"], seat, before["color"], token(cards[0]),
                                 " ".join(before["board"]), " ".join(after["board"])))
for i, c in enumerate(seat_colors, 1):
    who = names[c].most_common(1)
    print("seat %d %s: %s" % (i, c, who[0][0] if who else "?"), file=sys.stderr)
