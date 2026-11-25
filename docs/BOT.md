# The bot

Empty seats are played by a bot. A bot gets real cards, which stay hidden off the table, plays a card on its own
play zone, and moves its marbles with an animation. It only makes legal moves. The host sets it up with chat
commands ([HOST_COMMANDS.md](HOST_COMMANDS.md)): `!level`, `!think`, `!speed`, `!allbots`, `!botseat`.

## How it chooses a move

1. **Read the board** (`bot/players.lua botReadState`): every marble is matched to the nearest board point. The
   result is a logical state; [ARCHITECTURE.md](ARCHITECTURE.md) describes the board model.
2. **List every legal move** for its hand (`bot/rules.lua JB.legalActions`). That covers each card, each marble,
   entering the finish or running past it, every 7 split in both orders, and Joker jumps. Bonks, including friendly
   bonk chains, are worked out the same way as on the table (`JB.land`).
3. **Score each move** (`bot/search.lua`). The score has four parts:
   - **the board after the move**, for its team (`bot/evaluate.lua`): progress of every marble, risk of being
     bonked, a defender near each finish, a tidy finish, marbles parked on a teammate's exit (that teammate's next
     exit card catapults them home);
   - **the card spent and how the move lands** (`bot/move_costs.lua`): keep exit cards and Jokers, don't land in
     front of an enemy, don't nudge a defender, close gaps in a finish, defend when an enemy is close to home…;
   - **setups for later turns** (`bot/setups.lua`): 7 traps, ambushes on an enemy's exit, chains of bonks;
   - **the rest of the hand** (`bot/hand.lua`): tie-breakers between cards, holding a Joker unless the payoff is
     big, a small credit for what the hand can do next turn.
4. **Look ahead** (levels 4 and up): it plays the next seats' turns, guessing their cards, and keeps the move that
   holds up best. The search runs in a TTS coroutine, so the game keeps running while a bot thinks (`!think` sets
   the time).
5. **Burn:** if nothing is legal, it discards the card it needs least (`JB.burnPick`).

## Difficulty levels (`!level`, saved with the game)

| Level | Looks ahead | Notes |
|---|---|---|
| 1–3 | its own move only | random noise and occasional blunders; plain rules (no strategy terms) |
| 4–6 | 2–3 turns | strategy terms phase in |
| 7–8 | 4–6 turns | plus a "game plan" for its own next turns, and its teammate's reply |
| **9** | as deep as time allows | every rule at full strength. **The default, and the one tuned in playtests** |
| 10 | deep, card counting | experimental engine (`bot/engine.lua`): one general cost function instead of hand-made rules. Slower, less tuned |

The exact numbers are in `JS.LEVELS` at the top of `bot/search.lua`.

## Tuning it: from a bad move to a fix

The bot is tuned from real games, not bot-vs-bot simulations: a playtester flags a bad move, the rule behind it
gets fixed, and the position becomes a test.

1. **Run the flag server** while you play: `python3 tools/flag_server.py`. It saves flags to `data/flags/` and
   game logs to `data/logs/`. Without it, flags are kept in the game save until it's running again.
2. **Flag it.** The host types `!flag what was wrong` right after a bot's bad move. Notes help.
3. **Replay it** with the current code: `lua tools/replay_flag.lua data/flags/flag_XXXX.json`. This shows the
   position, what the bot played and the alternatives with scores. `PARTS=1` splits each score into evaluation /
   card / setup / plan.
4. **Fix the rule.** Each rule is a named constant and function in `src/bot/`, with a comment naming the flag it
   came from. The written rules are in [BOT_STRATEGY.md](BOT_STRATEGY.md), the history in
   [BOT_TUNING_LOG.md](BOT_TUNING_LOG.md).
5. **Make it a test** in `tests/test_bot_search.lua`: the board, the hand and the move it should now make. Then run
   `./tests/run_all.sh`. The other flag tests make sure the fix doesn't undo an earlier one.

Two more tools work on game logs:
- `lua tools/analyze_log.lua data/logs/game_XXXX.jsonl` checks a game's bot moves against the rules it can test
  automatically.
- `python3 tools/log_turns.py data/logs/game_XXXX.jsonl > data/turns.txt`, then
  `lua tools/compare_humans.lua data/turns.txt` compares every person's move with the move level 9 would make with
  the same card. It reports, per player, how often they agreed and how far apart they were. Use it to find
  positions where strong players disagree with the bot.

Keep the bot **conservative**: a teammate players trust, with no game-losing gambles. When unsure, prefer the
safer rule.
