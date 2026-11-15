#!/bin/bash
# Builds the scripts and runs every test suite. From the repository root:  ./tests/run_all.sh
#   test_game.lua         the Global script as TTS runs it (build/Global.-1.lua) in a mock of the TTS API
#                         (tests/tts_mock.lua): turns, bots at the table, stats, easy play, undo, hybrid, commands...
#   test_bot_rules.lua    the rules: moves, bonks, the board model
#   test_bot_search.lua   the bot's choices in set positions (including every fixed "flag bad move" report)
#   test_bot_engine.lua   the level-10 engine
# Exits non-zero if anything fails.
set -e
cd "$(dirname "$0")/.."
lua build.lua > /dev/null
for f in build/*.lua; do luac -p "$f"; done
status=0
for t in test_game test_bot_rules test_bot_search test_bot_engine; do
    out=$(lua "tests/$t.lua" 2>&1) || status=1
    summary=$(echo "$out" | grep -E "^passed|FAIL|lua:" | tail -5)
    echo "$t: $summary"
    echo "$out" | grep -q "failed 0" || status=1
done
[ $status = 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $status
