# Bot tuning log

How the bot got to where it is: every rule change and the playtest report ("Flag bad move", numbered) or game that
prompted it, oldest first. "The user" is the playtester whose flags these were. Early entries name the files as they were then: `bot.lua`
is now bot/players.lua + bot/play.lua, and `paste/` was the old copy-into-the-script files (gone: the build does it).
Flags and game logs themselves aren't in the repository (they contain player names).

For the rules as they stand, see [BOT_STRATEGY.md](BOT_STRATEGY.md); for how to keep tuning, [BOT.md](BOT.md).

## Rules the bot follows (same as the Google Sheets game)
* Leave start with an Ace / J / Q / K / Joker, landing on the exit cell (5 past your entrance).
* A, 2-6, 9, 10, J(11), Q(12), K(13) move forward; 8 moves 8 backwards (not out of the finish).
* You can turn into your finish after passing your entrance (1-5 cells deep), can't overshoot it, can't hop or land on your own marbles.
* 7 = split between one of your marbles and a teammate's (both in play). If your teammates are all "clean" (sheet's *Home Cleanliness* rule) the 7 is a plain move.
* Joker = one of your marbles jumps onto any other player's marble on the ring.
* Landing on a marble bonks it: enemy back to its start, teammate to the entrance of *their* finish. **Illegal: bonking a teammate who is standing on the entrance of their finish** (bot never does it; for humans see below).
* Once all 5 marbles are in the finish the bot plays its teammates' marbles.
* No legal move = it burns its cheapest card (an unusable 2-6 before a face card/Joker).

## Illegal bonks for humans
When you drop a marble on a teammate who is at the entrance of their finish, or on a teammate whose entrance is already held by one of their own marbles, a red **ILLEGAL MOVE** message pops up for everyone, nothing is bonked, and your marble is carried back to where you picked it up. (Only bonking is checked for humans for now.)

## What I couldn't test
I can't launch Tabletop Simulator from here. The rules engine has unit tests (159 checks) and the glue was run against a mock of the TTS API, but these are the things to watch on first run:
1. **Hidden hands:** bot cards are taken from the centre deck and locked face-down at x = 150 (far off the table). If you ever see them, change `BOT_STASH_X` in `bot.lua`.
2. **Turn flow:** when the human before a bot passes, TTS hands the turn to the next human immediately and the bot plays "in the gap". Wait for the bot to finish (status shows in the panel). If TTS doesn't fire `onPlayerTurn` the way I expect, the bot won't move: check the chat for `BOT ERROR`.
3. **Animation:** marbles lift, fly over and drop on the target; bonks are done by your existing collision code. Timing is in `botMoveMarble` / `botRunSteps`.
4. **Speed:** the 7-split search is the heaviest part (a couple of thousand candidate positions). If it ever hitches, tell me and I'll prune it.
5. If the bot's marbles are ever read onto the wrong cell (e.g. a marble that was left between points), it will say nothing but play from a wrong picture of the board; marbles should always be left snapped.

## Update: Turn Button ends your turn (`game/turns.lua`)
Turns no longer depend on TTS's own "pass turn" / `onPlayerTurn` (it never fired reliably when playing alone, so bots never moved).

* The Turn Button shows `<name>'s turn / Click to END TURN`. The player whose turn it is clicks it when done: they draw 1 card, then every bot seat after them plays in order (`BOT (Colour)'s Turn` on the button), then the next human's turn starts.
* Clicks are ignored (with a private message) while a bot is playing, or from anyone who isn't the current player. The **host** can end anyone's turn.
* TTS's built-in turn passing is switched off (`Turns.pass_turns = false`); `Turns.turn_color` is still set on human turns so the TTS indicator matches.
* The starting seat is random, bots included (if a bot starts, it plays first).

Code changes
| file | change |
|---|---|
| `game/turns.lua` | NEW (Global only, after `bot.lua`). `turnBegin`, `turnAdvance`, `endTurnClicked`; overrides `botChooseStart` (starts the cycle, returns nil) and `onPlayerTurn` (now empty). `botHandleTurnChange` / `botRunQueue` in `bot.lua` are no longer called. |
| `paste/1_GLOBAL_paste_at_end.lua` | `game/turns.lua` appended at the end. |
| `paste/3_start_game_button_paste_at_end.lua` | Turn Button click function `"noop"` → `"endTurnClicked"`; removed the `Turns.disable_interactations` line (TTS refuses to set `Turns.disable_interactions` from a script: "cannot access field"; it defaults to off anyway). |
| `bot.lua`, `paste/1` | `botRunQueue`: return early on an empty queue (TTS's Lua errors on `table.remove` of an empty table). |
| `apply_to_tts.sh` | NEW. After loading the dev save, puts the current paste files at the end of the scripts in the VS Code TTS folder, first cutting off any older bot code the save already carries (Save And Play stores scripts in the save, so a reload brings back whatever version was last saved). Then run *Save And Play* from VS Code. |

Known gaps: a human who sits in a bot's seat mid-game is not handed the bot's (hidden) cards; if the centre pile is down to one loose card, the player ending their turn doesn't draw (message says to press Reshuffle).

## Update: bot name colours, clear first turn, build step
* **Bot names in their marble colour**: chat lines (`BOT (Green) moves ...`, plays, bonks, "Bots are playing"), the bot panel (title + status line) and the Turn Button on a bot's turn. The colour is read live from the bot's marbles. Very dark marbles are lightened for the dark chat/panel and very light ones darkened for the Turn Button so they stay readable (`nameColorOnDark` / `nameColorOnLight` in `bot.lua`). `playerLabel()` now returns the bot name with a chat colour code (`[RRGGBB]BOT (Green)[-]`), so it must only be used in chat/broadcast text, never in a button label or XML attribute.
* **Who goes first is obvious**: right after Start Game the Turn Button says "Choosing who goes first...", then a broadcast and the button say who starts. If a bot starts, the button reads "BOT (X) starts / Dealing cards..." until the bot has its hand and plays (previously the button was blank for those few seconds, which looked like it was waiting for the human).
* **Build step**: `paste/1_GLOBAL_paste_at_end.lua` is now generated by `build_paste.sh` from `bot/rules.lua (+ evaluate / setups / move_costs / hand)`, `color_picker.lua`, `marbles.lua`, `bot.lua`, `Global.-1.lua` (NEW: the replacement Global event handlers that used to exist only inside paste/1) and `game/turns.lua`. Edit the modules, not paste/1. `apply_to_tts.sh` runs the build first.
* Not verified in TTS yet: the `<textcolor>` rich-text tag in the bot panel title. If the title shows the raw tag text, swap it for one `<Text>` per bot.

## DEBUG: visible bot hands (temporary)
`BOT_DEBUG_SHOW_HANDS = true` at the top of `bot.lua`: each bot's hand is laid out face up in a row floating just above its play zone (3 units up, above the play-zone trigger so it never counts as a play), locked and not grabbable. The hand is re-laid out whenever the bot draws or plays (`botLayoutHand`), which also fixes cards overlapping in the hidden stash after a play. **Set it back to `false` before real games**; the cards then go back to the hidden stash at `BOT_STASH_X`.

## Update: hover numbers on every marble
Hovering over ANY marble that is on the board (not in start, not being carried) now shows the 1..13 step numbers, so you can judge distances to other players' marbles. The numbers follow the hovered marble's route (they turn into that marble's owner's finish), are visible only to the player hovering, and face the hovering player. Code: `Global.-1.lua` overrides `onObjectHover` (no own-marble check; skips spectators and marbles that aren't on a point instead of erroring) and `arrangeHoverNumbers` (adds an optional `view_team` argument for the rotation; otherwise unchanged from `hover_numbers.lua`).

## Update: -8 on the hover numbers
Hovering a marble on the ring now also shows a **red 8** on the cell an 8 would send it to (8 ring cells backwards, skipping finish cells). Nothing is shown for a marble already in a finish (an 8 can't take it out). It is one extra piece per player (the existing "8" mesh tinted red), created from Global the first time that player hovers, named `HoverMinus8_<Colour>` so a reload reuses it. Code: `Global.-1.lua` (`hoverMinus8Index`, `hoverPlaceMinus8`, and `hideHoverNumbers` overridden to also hide it). The 1..13 pieces and the player-count button scripts are unchanged.

## Update: post-game stats (`game/stats.lua`, from STATS_SCREEN_INSTRUCTIONS.md)
Tracks, per player: cards played (A..K, $), rounds burned, teammates/enemies bopped, bopped by teammate/enemy, turn finished; per team: totals, last turn finished, WINNER/LOSER; awards (Best Teammate, Sniper, Most Hated, Fast Finisher, Wealthiest Player, Poorest Player, Teammates' Favorite: only for values > 0, ties all win, several per player). Opens by itself when a team wins (= every player of that team has all 5 marbles home, first); a **Stats** button in the top-left panel opens/closes it any time (the panel now also appears in games without bots, holding just that button). Stats survive a save/reload (`onSave`/`onLoad`), but note the bot/turn state does not.

Differences from the instructions (and why)
* Double counting of cards is prevented by remembering the turn number a card was counted on (`stat_counted_turn`) rather than a flag cleared on pick-up: bot cards are never "picked up", so a recycled card would otherwise never be counted again after a reshuffle.
* Turns no longer go through `onPlayerTurn` (it's a no-op since `game/turns.lua`), so the turn counter and the burn snapshot hook into `turnBegin` / the end of each turn instead. Bots and humans use the same snapshot comparison for burns (no separate `act.burn` path), which keeps them identical.
* `botCheckFinish` now just calls `statsCheckFinish`, so "has made it home" is announced once per player (humans too) and "Team N wins!" once (before, bots re-announced every turn after finishing).

Hooks added to existing functions (each is one guarded line)
| file:line | hook |
|---|---|
| `paste/3_start_game_button_paste_at_end.lua:20` | `Global.call("statsReset", {num_players = num_players})` after the bots' hands |
| `Global.-1.lua:42` (`onObjectEnterScriptingZone`) | `statsCardPlayed(player_color, obj)` on a legit play |
| `Global.-1.lua:218` (`onObjectDrop`, now overridden) | `statsScheduleFinishCheck()` after a marble is dropped |
| `marbles.lua:122` / `:133` (`marbleCollisionDetection`) | `statsBonk(bonker, bonkee, friendly, bonked)` right after the enemy / legal friendly bonk animation (illegal bonks return earlier) |
| `game/turns.lua:81` / `:105` (`turnBegin`, bot / human) | `statsTurnStart(color)` |
| `game/turns.lua:94` (bot turn done) / `:144` (`endTurnClicked`) | `statsTurnEnd(color)` |
| `bot.lua:434` (`botCheckFinish`) | `statsCheckFinish()` (replaces its old body) |
| `bot.lua:488` (`botPanelXml`) | `statsButtonXml()` adds the Stats button |
| `color_picker.lua:50` (`refreshGameUI`) | appends `statsPanelXml()` when `UI_STATE.stats` |

Tests (Lua 5.5 via Homebrew; MoonSharp is 5.2-style, nothing version-specific is used)
* `tests/test_game.lua`: the 7 acceptance checks (cards incl. same card twice; enemy/friendly/illegal bonks; burns; finish + winner once + screen opens/closes; awards zero/tie/multiple; XML well-formed for 4/6/8 players with a nasty steam name; 25 full rounds with 3 bots through `game/turns.lua` where bot cards, burns and bonks are counted like the human's) plus the -8 index for every board cell. **45 passed, 0 failed.**
* `tts_mock.lua` (NEW): shared TTS mock with a bit of "physics" (a card landing on a play zone fires the zone event; a marble dropped on another fires the bonk handler).
* `test_bot_glue.lua`: mock objects gained `getColorTint`/`setColorTint` (needed since the name colours); passes. `test_bot/rules.lua (+ evaluate / setups / move_costs / hand)`: 159 passed.
* Not testable outside TTS: the stats overlay's actual look (`TableLayout` sizes), the red -8 piece's spawn.

## Update: difficulty 1-9 and timed lookahead search (`bot/search.lua`)
* **Search**: iterative deepening, one ply = one seat's turn in seat order. Depth 1 = the old bot (static evaluation of every legal move). Each deeper level adds the next seat's turn, until the time limit (`BOT_THINK_TIME`, default **2 s**) or the level's maximum depth; the deepest *completed* depth is used.
* **Hidden hands**: for every other seat the search tries each card type they might hold (A..K, Joker; a 7 counts as a plain move deeper in the tree), assumes they make their best move for their own team with it, and combines the outcomes: opponents = `pess` x worst case for us + (1 - `pess`) x deck-frequency-weighted average; teammates = the same with best case. On the bot's own later turns it uses the cards it really holds.
* **Difficulty** (`BOT_DIFFICULTY`, default 5; table `JokerSearch.LEVELS`): max depth (1,1,1,2,2,3,4,6, then two full rounds for 9), how many root moves are searched deeper, beam on the bot's own later turns, pessimism, random noise and blunder chance (level 1: big noise, 35% blunders; level 9: none).
* **In TTS**: runs in a coroutine (`startLuaCoroutine`), yielding every ~25 ms so the table keeps drawing. A watchdog (think time + 6 s) falls back to the quick one-move choice if the search dies, with a `BOT ERROR (search)` chat line. Timing uses `os.clock` (falls back to `os.time`).
* **Panel**: `-` / `+` for difficulty (1-9) and think time (0.5-10 s, 0.5 s steps). The status line shows the search progress ("thinking... 3 turns ahead") and how far it looked for the move it played.
* `bot/rules.lua (+ evaluate / setups / move_costs / hand)`: `legalActions(S, seat, hand, opts)` takes `opts.simple7` (7 as a plain move, used by the search). Otherwise unchanged.

Performance: native Lua 5.5 on this Mac reaches depth 3 (about 97k positions) in 2 s on a busy 4-player board. TTS's MoonSharp is several times slower, so expect depth 2 there; raise the think time to go deeper.

Tests: `test_bot/search.lua` (legal moves at every level on random 4/6/8-player boards, the time limit holds, it yields, depth caps per level, a small position goes deep). `lua test_bot/search.lua match [games]` plays simulated games, level 9 (team 1) vs level 1 (team 2). `tests/test_game.lua` and `test_bot_glue.lua` now drive bot turns through the search, using a mocked `startLuaCoroutine`.

## Update: Joker value, defensive Jokers, multi-bonks, end of game
* **Joker cost 16 -> 160** (`JB.CARD_COST` in `bot/rules.lua (+ evaluate / setups / move_costs / hand)`). With 16 the bot played its Joker on 93% of the turns it held one (a Joker jump typically scores ~130 above the best other move). At 160 that drops to ~30%, when the jump is clearly better. Simulated games (60 per pairing, both seat orders): Joker 160 vs 16 won 32-28; 200 vs 16 lost 26-34, so 160.
* **Defensive Joker** (`JB.defensiveBonus`): a Joker that sends home an enemy marble within 13 cells of its finish entrance, when that enemy already has >= 2 marbles home, gets +150 (+60 per extra marble home, +6 per cell closer).
* **Multi-bonks** (`JB.chainBonus`): every bonk beyond the first in one play gets +80, and +150 more with a Joker. For example: your marble sits on your teammate's finish entrance and another of yours Jokers onto that teammate, who is sent to their entrance and bonks you to yours.
* Both bonuses and the card cost go through `JB.cardAdjust(S, act)`, used by the old chooser (`JB.choose`) and the search's root moves (`bot/search.lua`). Joker actions now carry `bumpList` (which marbles they bonk).
* **End of game** (`game/turns.lua`): `turnAdvance` checks `turnWinningTeam()` (every player of a team has 5 marbles home). If there is a winner, `turnGameOver` stops the cycle: no more bot turns, the Turn Button shows "Game over / Team N wins!", and clicking it again does nothing. The stats screen still opens by itself (game/stats.lua).
* Tests: `test_bot/search.lua` (defensive Joker used / Joker kept when no threat / two-bonk Joker, for both the old chooser and the search) and `tests/test_game.lua` (the game stops after a win). All suites pass: logic 174, glue OK, stats 49, search 25.

## Update: debug hands moved outside the board
With `BOT_DEBUG_SHOW_HANDS = true`, each bot's cards now lie face up on the table in a row just past the outer edge of that bot's side of the board, centred on its play zone (`botHandSlot` in `bot.lua`; it uses the same geometry as `createDiscardPiles`). The row sits `BOT_HAND_OUTSET` (1.8) past the board edge, with cards `BOT_HAND_SPACING` (1.25) apart. Raise or lower the outset if the cards overlap the board or hang off the table, which may differ on the 6- and 8-player tables.

## Update: bots are named after their marble colour
Bots were named after their seat (`BOT (Orange)`), but marble colours are assigned by seat number (`MARBLE_COLORS[i]`), so the Orange seat plays blue marbles. Now `botName()` uses `marbleColorName(color)`: the nearest name in `BOT_COLOR_NAMES` to the marbles' current tint. With the default 4-player colours the bots are `BOT (Blue)`, `BOT (Green)` and `BOT (Red)`. This covers chat, panel title, status line, Turn Button and stats. Move descriptions say `Blue marble 1` for a bot's marble and `Alice's marble 1` for a human's, in the marble colour (`marbleOwnerText`). Before the marbles exist, the seat name is used.

## Update: bot cards land on their play zone in 6/8-player games, panel title grows
* `botPlayCard` used to create the played card 7 units outward from the bot's play zone and glide it in. On the 6- and 8-player tables that point is past the table edge; the glide didn't happen and the card fell off the table (it was never counted as played). Now the card appears right above the bot's own play zone (or is lifted from its place in the debug-hands row), glides down one frame later, and after 1.4 s any card that isn't over the zone is put straight above it to drop in.
* The bot panel's "Bots: ..." title gets taller with more bots (about 22 characters per line), so 5-7 bot names no longer overlap the status line.
* Joker rule confirmed by the user: a Joker may move any of your marbles (start or ring) onto another player's marble, but not one in the finish. This is what `legalActions` already does.
* Tests: `tests/test_game.lua` 7b runs bot turns in 6- and 8-player games and checks every bot card reaches its own zone (59 passed).

## Update: 7 trap, parking on a teammate's exit, face cards / K / 10, waiting for animations
* **7 trap** (`JB.sevenTrapBonus`, weighted by the level's `trap`: 0 for levels 1-3, rising to 1 at level 9). Holding a 7, a marble k = 2..6 cells behind a teammate's exit cell (teammate has a marble in start, finish cells 1..7-k empty) gets +140/90/60/35/20. When the teammate comes out, the 7 splits k + (7-k): bonk them to their finish entrance, then carry them 7-k into the finish (k = 2 -> the deepest cell). The search now uses real 7 splits on the bot's own later turns (`topMoves(..., full7)`), so it can also see the spring; other players' 7s stay plain moves for speed. The bonus was doubled from 70 after debugging showed the search underrates the setup: it models other players as holding one card, so it thinks the teammate comes out about 1 time in 3 (a real 6-card hand has an exit card ~90% of the time).
* **7 value unchanged (4).** Simulated games: valuing the 7 at 40 lost 23-37 and at 60 lost 25-35 against 4, so holding 7s back in general hurts. The trap bonus still saves a 7 when it has a job.
* **Parked on a teammate's exit cell** (`parkBonus` in `JB.evaluate`, all teams). While the teammate has marbles in start, the marble is worth `PARK_BASE` (20) + `PARK_WEIGHT` (0.7) x the jump it gets when the teammate comes out and friendly-bonks it to its own finish entrance. Nothing if that entrance holds one of its own marbles.
* **Face cards / K / 10** (`JB.cardCost`). J/Q/K as a plain board move cost 45/45/60 (they are the exit cards), except for defence (bonking an enemy within 13 of its finish entrance) or late game (the mover has no marbles in start). Leaving start with them stays cheap (J/Q 7, K 20). K and 10 are the defence cards (from your exit, a K reaches the next enemy's finish entrance and a 10 the spot an enemy reaches by coming out and playing an 8 back). Base cost: K 20 (was 7), 10 15 (was 1); they cost nothing when used for defence. Every action now carries `bumpList`.
* **Wait for animations** (`botWhenBoardSettled` in bot.lua). Ending a turn waits until no marble is moving (smooth move, bonk flight, settling) or held before scoring the turn and starting the next one. A bot also waits for that before reading the board, so a bonk still in flight can't be read as a marble on the wrong cell. Gives up after 10 s.
* Tests: search 35 (trap set up and sprung, parking, face card not spent on the board, Q for defence, K/10 costs), stats 61 (the next turn waits while a marble is moving; the mock's `Wait.condition` now polls like TTS).

## Update: crash fix, host skip / rethink, ambush, strategy by level, retuning
* **Crash fix**: "Object reference not set to an instance of an object" after a bot played a card. When the card lands on cards already on the zone, TTS merges them and the card object is destroyed; the 1.4 s safety check then read its position. The check now treats a merged (destroyed) card as arrived (`botPlayCard`).
* **Host controls for a broken bot turn** (Turn Button while a bot plays; tooltip explains). Every bot turn has a token and each step checks it, so a cancelled turn can't carry on later.
  * **Skip**: click twice within 3 s. The bot's turn ends as it is (move its marble by hand first if a move was left half done); its hand is topped up to 6 and play moves on (`botSkipTurn`).
  * **Rethink**: right-click. The bot re-reads the board and picks a new move; if it already played its card this turn it moves with that same card instead of playing another (`botRethink`, `botTakeTurn(color, done, { replay = card })`).
  * **Watchdog**: a bot turn not finished `BOT_TURN_WATCHDOG` (25 s) after the think time is rethought once, then skipped.
* **Ambush** (`JB.ambushBonus`, root of the search): don't stand on the next enemy's "-8 spot" (its exit - 8, where an enemy lands by coming out and playing an 8 back); `JB.evaluate` now counts an enemy 8 cells AHEAD as a threat. Instead stand d cells before it while keeping a card worth d (e.g. play a 4, keep the 6): +45. Same for an enemy's finish entrance (the K spot): +25.
* **Strategy rules scale with the level** (`JokerBot.STRATEGY`, set from each level's `insight`: 0 for levels 1-3, 0.3 ... 1 at level 9, restored after each search): parking, the 8-ahead threat, face-card thrift, K/10 defence, defensive and multi-bonk Joker bonuses, 7 trap and ambush. Low levels play plainly. The Joker's base value (160) applies at every level.
* **Retuned from simulated games** (level 9 vs level 9, 60 games per pairing, the full rule set against the same with one rule off):
  * K/10 thrift (K 20, 10 15 as plain costs) lost 23-37: reverted to K 7, 10 1. Their defensive value now comes from the ambush rule (a held K/10 that can reach an enemy's -8 spot or finish entrance) and from costing nothing when used to defend.
  * 7 trap at 140 lost 22-38: back to 70 for 2 behind (45/30/18/10 further back). Caveat: in these games the teammates are bots, which don't come out of start on purpose to spring the trap the way a human partner does.
  * Parking on a teammate's exit +4 (32-28) and face-card thrift +2 (31-29): kept.
* Tests: search 43 (ambush, strategy restored after a search, level 3 plays plainly), stats 71 (merged card doesn't break a turn; stuck bot: two host clicks skip, right-click rethinks, the watchdog rethinks then skips). The mock gained `M.pumpFor(seconds)` and can merge played cards (`M.merge_cards`).

## Update: play zone names
The play zones were named after the seat colour (`Orange's Play Zone`, from `singleDiscardPile`). Half a second after Start Game, `turnNamePlayZones()` (game/turns.lua) renames them after who plays there: `BOT (Blue)'s Play Zone` for a bot (its marble colour, like everywhere else), the steam name for a human. Only the hover name changes; the `<Seat>_DiscardPile` scripting zones that recognise plays keep their names. Test in `tests/test_game.lua` 4c (73 passed).

## Update: 7s and 8s must earn their play
* **Hard 7 rule** (user, levels 4-9, i.e. `JB.STRATEGY > 0`): a 7 is only played if it bonks someone or brings a marble into a finish, even when an idle 7 looks like the best move. `JB.dropIdleSevens` removes idle 7 moves at the search root, in `JB.choose`, and on the bot's own later turns inside the search. Exception: when idle 7s are the only legal moves, one is played (burning is only allowed with no legal move).
* **Idle 7 / idle 8 costs** (`JB.cardCost`): an idle 7 costs `SEVEN_IDLE_COST` (60) and an 8 that neither bonks nor leaves the moved marble within 13 of its own finish entrance (`JB.readiesForFinish`; coming out and playing the 8 back lands 3 short of the entrance) costs `EIGHT_IDLE_COST` (40). Both are scaled by the level. The 7 cost only matters when idle 7s are the only moves.
* Tests: search 50 (idle 7 kept, 7 used to bonk, only-idle-7s still plays one, nothing dropped at level 3, the 8 back from the exit readies the marble, an idle 8 costs more than a 5).

## Update: formation, danger distances, safe Jokers/8s, combo-7 setup
All are strategy rules (scaled by `JB.STRATEGY`: off at levels 1-3, full at 9).
* **Formation** (`JB.evaluate`): the home stretch is your exit cell to 10 past it (covering the next enemy's -8 spot). Its rearmost marble is the **defender** and gets no credit for progress (valued as if on the exit cell), so nudging it is worth nothing and the marble ahead of it is sent round instead (user example: one on the exit cell, one 4 past it, an Ace moves the front one). Having a defender there is worth +25 (`DEFENDER_BONUS`); each marble beyond 2 in the stretch costs 30 (`CROWD_PENALTY`).
* **Danger distances** (`JB.threatsAt`, used by `evaluate` and the landing check): an enemy d cells behind is dangerous for d = 1..6 and 9..13, safe for d = 7 (a 7 split never moves one marble 7), 8 (an 8 goes backwards) and 14+. An enemy exactly 8 ahead is dangerous, as is an enemy's exit cell while it has marbles in start. At strategy 0 the plain rule (1..13 behind) applies.
* **Safe landings for Jokers and 8s** (`JB.landingPenalty`): a Joker or 8 that lands the moved marble somewhere dangerous costs 30 + 35% of that marble's value per threat (up to all of it).
* **Combo-7 setup** (`JB.comboSevenBonus`, search root, +60): holding a 7 after the move, a 7 split is available that both bonks and brings a marble into a finish (e.g. 2 behind a teammate on the ring). Generalises the teammate-exit trap to marbles on the board and to enemy bonks; when the combo is already available the bot just plays it.
* Simulated games: idle-7 cost 30 vs 4 = 30-30; 60 vs 4 = 22-38. The hard 7 rule stays because the user prefers it even at some cost.
* Tests: search 62 (danger distances 1..16 and 8-ahead, the Joker avoids an unsafe landing, the 8 landing check, combo 7 set up with another card and kept, Ace moves the front marble, no nudging the defender, crowding).

## Flag bad move (replaces the bot-vs-bot simulations as the way to tune the bot)
The simulated games were too noisy (60 games is about +-7 wins) and too unlike real play (bot partners, shallow search) to trust, and they slowed the machine. Instead:
* **In TTS**: the bot panel has a note box and a **Flag bad move** button. Every bot move is recorded (`botRecordMove` in bot.lua): board before (logical cells), hand, chosen move with search depth and time, and the top 6 alternatives with their scores. The last 6 bot moves are kept. Flag sends them, plus the current board, the note and who flagged, as JSON to `tools/flag_server.py`.
* **`tools/flag_server.py`** (`python3 tools/flag_server.py`, Python 3 only, listens on 127.0.0.1:8765 so only this Mac can reach it) saves each flag to `flags/flag_<time>_<n>.json` and appends it to `flags/flags.jsonl`.
* If the server isn't running, the flag is kept in the game's save (`onSave` in game/stats.lua, under `flags`) and the player is told.
* Each flag gets turned into a position test (like the ones in test_bot/search.lua) and a fix.
* Tests: stats 79 (moves recorded, alternatives listed, flag posted, server down -> kept for the save).

## Update: first flags
* `tools/replay_flag.lua`: `lua tools/replay_flag.lua flags/<file>.json [move] [level] [seconds]` replays a recorded bot move with the current code and prints the position, the move made in the game and the move chosen now with its top alternatives.
* Flags 1-2 (BOT (Red) played its 8 back from its exit into the spot 6 in front of enemy BOT (Green), who held a 6 and a 7): the game was at **difficulty 5**, where the danger rules work at half strength. At level 9 the bot plays the 3 instead. **Default difficulty is now 9**, and difficulty and think time are saved with the game (`onSave`), so a reload no longer resets them. Regression test "from flags".
* **Defender nudge rule** (`JB.nudgePenalty`, 40, strategy-scaled): moving the defender (rearmost marble in its home stretch) forward inside the stretch, while another of that player's marbles is on the board, is penalised unless it bonks. The formation preference in `evaluate` alone was only ~2 points and flipped with search depth (the "Ace moves the front marble" test was flaky); it now holds at every depth.
* **Burn risk** (flag 4: BOT (Green), its only marble on the board and no exit card in hand, played a 10 onto BOT (Red)'s exit cell, where Red was sure to come out and bonk it, leaving Green burning turns). `JB.burnRisk` (search root, strategy-scaled) for the position after a move and the cards still held: no legal move next turn -60; every marble on the board in danger with no exit card (A/J/Q/K/Joker) held and marbles still in start -80. Replay at level 9: now the 6 to a safe cell. Regression test "from flags".
* **Clean finish** (flag 5: BOT (Red) played its 8 back to line up another marble while its finish was untidy, a marble on cell 3 with 4-5 empty, and landed 10 in front of enemy Green). In `JB.evaluate` (strategy-scaled): each empty finish cell deeper than a marble already in it costs 15 (`UNTIDY_PENALTY`); while a finish is untidy, each of that player's marbles within 13 of its entrance costs 25 more (`DIRTY_APPROACH_PENALTY`). Regression tests: flag 5 position (no 8), a lone 2 tidies the finish (3 -> 5).
* Flags 1, 2, 5 and 6 were played at difficulty 5 (the game ran from before the default changed to 9).
* Flag 6 (BOT (Blue)'s 7 sent Red's marble into Red's finish behind the marble on cell 3, instead of cleaning house; the user: "right idea, not super important"). The hard 7 rule (`JB.entersFinish`) now also counts moving a marble deeper inside its finish, so a house-cleaning 7 is considered at all. Scoring left as is.
* Flag 8 (another unsafe 8, played at level 5): level 9 plays the 3 instead. Regression test.
* Flag 10 (BOT (Blue) 8 back from its exit to 10 in front of White, level 5): level 9 plays the 9 instead. Regression test.
* Flag 11 (BOT (Red) nudged the marble on its exit cell with a 3 while another sat 5 past it, level 5): level 9 moves the front marble with the 5. Regression test.
* Flags 12-13 (clumping at level 5): the ambush bonus now only counts the defender (rearmost marble) in the home stretch, and bringing a marble out while 2+ are already in the home stretch costs 50 (`JB.crowdExitPenalty`). Flag 12 replay at level 9: moves the front marble with the 9.
* Stats crash ("attempt to compare number with table" in statsAwards at game end and on the Stats button, seen in a real game, cause not found yet): game/stats.lua now treats any non-number stats value as 0 and prints one 'STATS DEBUG' chat line naming it, to find the cause. Test 4e.

## Update: Joker waits, K kept, smoother card play (flags 23-25, 3v3 game)
- **Joker waits for a big payoff** (`JB.holdJoker`, `JB.JOKER_MIN_MARGIN = 150`): after the search, a Joker move is
  only played if it beats the best non-Joker move by 150 points on top of its 160 card cost. Exceptions: defensive
  Jokers (`JB.defensiveBonus`) and turns where nothing else is legal. Scaled by the level's insight, so it doesn't apply below level 4.
  Applied in `JS.choose` and `JB.choose`. Flag 25 (a Joker onto a teammate on turn 8) now plays a 2 instead.
- **K costs more than J and Q** (`CARD_COST k = 10`, plain 9): the K is the defence card. Flag 24 (K K J) now leaves start with the J.
- **Multiples first** (`JB.handAdjust`, `JB.DUP_DISCOUNT = 2`): each extra copy of the played card in hand makes it
  2 cheaper (up to 2 copies). Tie-breaker only; flag 23 (K Q Q Q) now leaves start with a Q.
- **Card animation** (`botPlayCard` in `bot.lua`): the card no longer teleports up and flips instantly. It stays
  locked and glides from the hand to above the play zone while turning face up, then sinks onto the zone and is
  unlocked. The pcall safety net is kept.
- Tests: `test_bot/search.lua` covers flags 23-25 (75 pass). Mocks gained `setRotationSmooth`.

## Update: game plan, cheap bonks, enemy exits, clean house, held-marble HUD (flags 18-26)
- **Game plan** (levels 7-9, `JB.planValue`, `JS.LEVELS[].plan` = 0.25 / 0.35 / 0.45): for the 12 best moves after
  depth 1 (`JS.PLAN_ROOTS`), score what the cards the bot keeps can do next turn from the new position (best follow-up
  plus half the best with a different card, card costs and 7/8 rules included, no Joker, cap 250). Only NEW chances
  count: the value minus what the same cards could already do now, floored at 0, so "keep the good card for later"
  never beats playing it. Uses at most 40% of the think time (`JS.PLAN_TIME_SHARE`); if that runs out, no move gets
  a plan. With the plan on, the combo-7 bonus is off (it counted the same thing twice).
- **Clean house** (`JB.cleanHouseBonus`, 100 per finish gap closed, flags 18/19): a 7 tidying the finish now beats
  bonking a far-away marble.
- **Enemy exit cells** (`JB.marbleRisk`, `JB.EXIT_CELL_RISK = 0.85`, flags 21/26): standing on the exit cell of an
  enemy with marbles in start is ~85% likely to get you bonked (was 20%). The cells 1-6 and 9-13 past such an exit
  count as threatened too ("in front of my start").
- **Cheap bonks don't justify a 7 or 8** (`JB.worthyBumps`, `JB.CHEAP_BONK_RANGE = 3`, flag 26): knocking an enemy
  marble that has only just come out (0-2 past its exit) doesn't count for the 7/8 rules.
- Combo-7 setup bonus is scaled down by the danger to the marble that would play it; the 7 trap no longer counts
  when the teammate's own marble blocks its exit.
- **Hover HUD locked while carrying** (`Global.-1.lua` `onObjectHover`): while you hold anything, hovering other
  marbles doesn't change or hide the numbers.
- `tools/replay_flag.lua`: `PARTS=1` prints eval / card / setup / plan per move (with the planned follow-up), and `TOP=n`
  sets how many moves to show.
- Tests: search 79, logic 174, stats 83, glue pass.
- K cost raised to 12 (same as A; plain 10) after flag 30, so a J or Q beats a K out of start by a clear margin, not 3 points.
- **No overthinking** (`JS.choose`): when every legal move leads to the same position (one move only, or e.g. J/Q/K
  that all just bring a marble out), the bot skips the search, picks the cheapest card and plays at once.

## Update: 8-player game flags 30-43
- **Progress per cell is the same on every table size** (`JB.CELL_VALUE = 120/67`; finish = full lap + 55). Before,
  a cell on an 8-player table was worth half a 4-player cell, so fixed costs/bonuses beat moving fast ("no need to be
  slow"). Joker cost and margin scale with the table (`JB.boardScale`) so Joker behaviour is unchanged.
- **Less sunk cost** (`JB.atStake`, `JB.STAKE_SHARE = 0.4`): danger costs 25 + 40% of the value a marble gained by
  travelling, so far runners keep being pushed instead of hidden (flag 41).
- **Face cards free with a stacked hand** (`JB.handAdjust`): for board moves, keeping 2+ other exit cards waives the
  face-card board-move cost; keeping 3+ (`JB.STACKED_EXIT_CARDS`) makes a face card or ace cost nothing. Leaving start
  still picks the cheapest card (J/Q before K). Few exit cards: still thrifty (flag 39, user's stacked-hand note).
- **Dead defender spot** (`JB.deadDefenderPenalty`, 35, flag 31): don't leave the defender 2 or 3 past the exit
  (the next player's -8 spot is then 8 or 7 ahead, out of reach).
- **7 into the finish must be worth it** (`JB.goodFinishEntry`, flag 36): the finish is left with no gaps (or fewer),
  or the entering marble was really threatened (not the two-turns-away "enemy may come out" danger).
- **Sure exit bonk** (`JB.exitBonkBonus`, 60, flag 38): coming out onto an enemy sitting on your exit cell.
- **Plan fixes**: follow-ups discounted by the danger to the marble they move (flag 37), untidy finish entries are not
  plans (flag 5, `JB.tidyEntry`), cap 120 instead of 250 (flag 43: a plan beat going home).
- K cost 12 (= A). No search when every legal move leads to the same position.
- Tests: logic 174, search 82, stats 83, glue pass.
- **`tts_scripts/`**: a full copy of every script in TTS (Global, buttons, XML), refreshed by `snapshot_tts.sh` at
  the end of every `apply_to_tts.sh`, so the mod's whole structure can be read here. Generated; don't edit it.
- **Spots and card values** (user, after flag 41): never land on an enemy's -8 spot (it has marbles in start) or
  finish entrance (it has a marble out: its teammate can bonk it there and it bonks you), `JB.SPOT_LANDING_PENALTY`
  50 plus 2 threats in the evaluation; waiting behind them is still rewarded. 10 costs 12 and A 14 (both kept; a
  defending 10 is free). J/Q as plain board moves cost 20 (was 45), so 10 10 J 9 moves with the J or 9.
- Flag 44 (2v2): A costs 20 (more than J/Q), and the "parked on a teammate's exit" credit is 50% of the jump
  (was 70%), so a sure friendly bonk with a J/Q now beats an Ace bonk that leaves the marble on an enemy's exit.
- **Safe spots in front of enemies** (user): every card now gets the landing check (half strength; full for Joker and
  8; 7 excluded), and each threat counts 30% (was 20%) of 25 + 60% of the marble's travel value (was 40%). E.g. 3
  behind an enemy with J 4 5: the J lands 8 in front (safe), not the 4 (1 in front).
- Flag 45: the landing check counts real threats only (not "an enemy may come out and then hit it", two turns
  away), so the classic 8 back from the exit isn't penalised for that.
- Flag 46: **park on a teammate's exit** as a move rule (`JB.parkMoveBonus`): +40 for parking there (teammate has
  marbles in start, own entrance free), +40 more when keeping the exact card (A-5) from the own entrance into the
  deepest free finish cell. Root setup bonuses like the ambush aren't checked by the search, while parking (in the
  evaluation) was; this evens it out.
- Flag 47: **defence beats offence** (`JB.defenceBonus`, any card): bonking an enemy's LAST marble (4 home) is +300
  wherever it is; an enemy with 3+ home within 13 of its entrance is +40 per marble home.
- Flag 48: defensive Jokers (and the defence bonus) need the enemy to have 3+ marbles home (was 2).
- Flag 49: a defender (the rearmost marble near the exit, which gets no credit for moving) is kept only while the
  next player still has marbles in start (`JB.needsDefender`); the entrance ambush only counts if that enemy has a
  marble on the ring. Once Green finished, Blue runs with the 9.
- Flags 50/51: making a gap in your own finish costs `JB.GAP_PENALTY` 45 per gap (max 2), and the "stuck burning if
  bonked" penalty (80) is scaled by how likely the bonk is (full at 60% risk). Blue's 7 now goes +3 to the deepest
  free cell and the other 4 sends its own far marble to its entrance (friendly bonk).
- Flag 52: a finished player whose teammates have nothing left in start plays A/J/Q/K/10 at no card cost (they're
  just movement now). In flag 52 itself the deeper search still rates "2 now, J next turn" about equal to "J now".
- Flags 54-58 (endgame): a team with every marble home has WON (`JB.WIN_VALUE`; the search stops there). A team's
  last marble on the ring is worth double (2 left: x1.5, `JB.RACE_LAST`); when your team has fewer marbles left than
  the enemy team, ordinary defence counts a quarter (`JB.RACE_DEFENCE_SHARE`). A finished player pays to spend A-6
  (and a little for 9s) on anything but entering a finish (`JB.SMALL_CARDS`): small cards are for exact finishes.
- Stats crash ("attempt to compare number with table" in statsAwards, on the guarded line, with all-number saved
  stats): statsAwards no longer compares outside values directly (tonumber into fresh locals, math.min/max) and runs
  in pcall; on failure the screen shows no awards and chat prints one "STATS DEBUG: awards failed ..." line.
- **Shuffle fix** (`paste/3`, startGame): the deck is shuffled again right before dealing. The player-count button's
  labelDeck restacks every card and the original shuffle runs 2 s later, possibly on a half-rebuilt deck, leaving
  sorted cards on top (the user got straight flushes 3 times). Chat shows "Deck shuffled (N cards)".
- Flag 60: **7 splits in both orders** (`JB.sevenActions`): the teammate's part can go first. E.g. teammate +2 lands
  on your marble (friendly bonk: it jumps to your entrance), then your marble +5 goes straight into finish cell 5.
  Before, your own marble always moved first, so that combo was never considered.
- Flag 61 (animation): between the two parts of a 7 (and any multi-step move) the bot waits a beat and then until
  every marble has stopped (`botWhenBoardSettled`), so a marble bonked to its entrance lands (and bonks whoever is
  there) before it is moved on.
- Flag 62: a risky 8 (lands threatened) with no other 8 in hand costs 50% more (`JB.SINGLE_EIGHT_EXTRA`): with a
  spare 8 you can try again if bonked, with one you can't.
- Flags 63-68: leaving a park (a marble on a teammate's exit while they have marbles in start) costs 80
  (`JB.parkLeavePenalty`); an enemy's finish entrance is a no-landing spot whenever that enemy still has any marble not
  home (flag 68: a marble that just came out was friendly-bonked onto its entrance and bonked Green there); the spot
  exemption only applies when the marble landing there is the one bonking.
- **7s need a purpose** (user: "it favors any bonk with a 7 too much"): `JB.qualityBumps`: an enemy marble that has
  travelled 25+, is within 13 of its finish, or whose player has 3+ home; or a friendly bonk that jumps a teammate 15+.
  Also valid: a tidy finish entry, or leaving a marble 0-2 from its entrance (`JB.readiesEntry`, flag 64). Clean house
  bonus 130 (was 100).
- Flag 70: an idle 8 (no worthy bonk, doesn't ready a finish) is dropped like an idle 7 when other moves exist.
- **Burn order** (flag 72, `JB.burnPick`): anything else first, then 10s, then 7s, then 8s, Joker last; among equals
  the card held most often goes first.
- Flag 73: passing your own finish entrance (marble within 3 of it moves on along the ring) costs 60
  (`JB.passEntrancePenalty`): wait on the entrance, take the bonk if it comes.
- Flag 74: ambush bonus cut to 25 (-8 spot) / 15 (entrance), from 45 / 25. It is a root-only maybe that the search
  never checks, and it kept beating sure moves (flags 38, 46, 70, 74).
- Flag 75: for the 7 rule, "3+ home" alone no longer makes a bonk high-quality (only a player's LAST marble does);
  being within 13 of its finish or having travelled 25+ still counts.
- Flag 76: getting a marble 1-6 behind an urgent enemy marble (within 13 of its finish, its player 3+ home) from
  outside that range earns +50 (`JB.defenceSetupBonus`): it lets you or a teammate (7 split, small card) bonk it.
- Flag 77: "an enemy may come out of start and then hit you" counts as half a threat (two turns away) and no longer
  triggers the "stuck burning if bonked" penalty (that one uses real threats only). Runners keep running.
- Flag 78: no defence bonus (not even the last-marble +300) for bonking a marble on or just past its own exit: it
  comes straight back out and bonks you there. (The user notes it IS good when that player has been burning; the
  bot doesn't track burns yet.)
- Flag 79: the last-marble defence bonus (+300) is full only within 13 of the marble's finish; farther away it
  shrinks (to 25% at 50+ cells), so finishing a teammate's last marble beats bonking a far-off enemy last marble.
- Flag 79 follow-up: completing a player (bringing its last marble home) earns +250 (`JB.playerDoneBonus`), just
  under the full last-marble defence (+300), so only a game-saving defensive play beats it.
- **QoL** (`game/turns.lua`): automatic reshuffle at the start of every turn when fewer than (players + 2) cards are left
  in the middle (uses the Reshuffle button's code, then shuffles again after 3.5 s); a "Deal to 6" button next to
  Stats tops every seat (humans and bots) up to 6 cards. Tests in tests/test_game.lua.
- Stats awards column: 330 wide, wraps to two lines and shrinks text to fit (rows 34 high).

## Update: all-bot mode and the game log (`host/game_log.lua`)
- **All-bot mode**: type `!allbots` in chat (toggle; `!allbots on` / `!allbots off`) BEFORE Start Game. Every seat
  is played by a bot (humans get no cards and watch; the "nobody seated" pause is off).
- **Game log**: every event goes to `tools/flag_server.py` at `/log` and is appended to `logs/game_<start time>.jsonl`:
  `game_start` (seats, settings), `turn_start` (seat, bot hand, board), `bot_move` (hand, board before, chosen move
  with steps and bonks, alternatives, search depth/time), `draw` (cards drawn), `card_played`, `move_result` /
  `mismatch` (board after a bot move vs what it planned: a mismatch means an animation/physics problem), `chat` and
  `error` (every chat line; "ERROR" lines as errors), `game_over` (winner + stats). Batches are sent every 5 s and
  at once for errors/mismatches/game end. The server prints `LOG ERROR` / `LOG MISMATCH` / game start/over lines.
- Bot turns now check the board after each move (`botVerifyMove`) before drawing.
- Stats: player table height fixed for the taller (wrapping) award rows; awards column 260.
- **Instant bot speed** (4th option on the "Bot speed" button): marbles and cards jump straight to their spot
  (dropped from a little height so bonks still trigger), bot pauses cut to 5%. Think time is separate (panel - / +).
- Game log: a bot's multi-card draw is logged once (botDrawCards calls itself per card).
- **STRATEGY_RULES.md**: the user's playing rules distilled from the 79 flags of 2026-11-10 (with flag numbers).
- **tools/analyze_log.lua** (`lua tools/analyze_log.lua logs/game_X.jsonl [n]`): rebuilds every bot move from a game log and
  checks it against those rules (idle 7/8, unforced Joker, K/A out of start with J/Q in hand, landing in danger when
  a safe move existed, enemy entrance / -8 spot, running past own entrance, leaving a park, dead defender spot,
  clumping, gaps from 7s, burn order, and missed chances: finishing a player, bonking a last marble near home, a
  clean finish entry). Lists errors and mismatches too. Static checks only (no search), so it takes about a second.
- Finish gaps (all-bot game): gap penalty 45 per gap in the evaluation (was 15) and 45 per gap made by ANY card (was 7s only).
- **Stats**: a Distance column (cells moved by each player per turn: forward moves up to 13, 8s backwards, moves into
  and inside the finish; bonks and catapults don't count) and new awards: Marathon Runner / Couch Potato (most / least
  distance), Speed Demon (biggest turn), Hitchhiker (most cells from catapults), Heartbreaker (bonked the marble that
  had come furthest), Wild Card / Lucky Sevens / Moonwalker (most Jokers / 7s / 8s), Cold Streak (most burns in a
  row). A key under the table explains them.
- **Finish gaps, very high priority** (user): 70 per gap on the board score, 100 per gap made by any move, +220 per
  gap cleared by any card. The FIRST gap a move makes costs only 40 (user, flag 43: enter with the 3 and fix the gap
  later rather than back off); more gaps cost 100 each.
- All-bot mode and bot speed are saved with the game (survive Save And Play / reloads).
- 2v2 all-bot game (Red, A and 3 in hand, finish cell 5 filled): a finish entry that leaves ONE gap is free (gap
  costs refunded, +30) when the bot keeps the exact card that closes it next turn (`JB.fixableGapRefund`). Red now
  plays the 3 in and plans the A.
- Stats: at most 2 awards per player are shown, picked at random once (saved, so reopening doesn't reshuffle).
- **2v2 all-bot review** (every move replayed at TTS-like depth):
  - In TTS the search mostly reaches only 2 turns ahead (145 of 187 moves), so in a 4-player game it never sees its
    teammate's next turn.
  - A player's LAST marble is kept within one card of its finish (`JB.finishReachBonus`: +-60, +-150 for the team's
    last marble). Turn 177: Black moved Green's winning marble 8 back out of reach instead of 2 into reach.
  - 8s that land in danger cost 1.6x (`JB.EIGHT_LANDING_MULT`), and both halves of a 7 get the landing check.
- **Teammate term** (`JS.teamReply`, levels 6-9, weight 0.3-0.5): once the 2-ply search is done, the best 12 moves
  also get "what can my next teammate do from here" (hidden hand: per card type its best move, combined as the
  expected best reply from a 5-card hand; no Joker; one gain capped at 600). Used only when the search doesn't reach
  the teammate's turn itself (depth < 3), so nothing is counted twice. It runs after depth 2, so it never costs the
  bot its look at the opponents' reply. On its own it fixes turn 177.
- **Two-card finishes, any cards** (`JB.cleanPathInHand`, `JB.avoidableGapPenalty` 80): entering with a gap costs 80
  more when one card or any two cards in a row from the hand would bring that marble in cleanly. A gap a kept card
  closes next turn is still free (`JB.fixableGapRefund`, A-5). Stress test: random safe positions with a two-card
  finish in hand; the remaining misses are the bot spending the face card of the pair to bring its last marble out
  of start (a judgment call).
- Running past your own entrance costs 60 from anywhere within 13 (was within 3): a 9 ran a marble 6 out past its
  entrance (a whole lap) to dodge an enemy 2 behind.
- Tests: `opts.max_depth` caps the search (TTS-like depth in tests).
- **Face card vs small cards** (user): a clean J/Q/K finish costs 130 (`JB.spareFaceFinishPenalty`) when the small
  cards in hand (2-10, one or two in a row) could finish that marble too, no real enemy marble is in range behind it,
  and a marble is in start with the exit free, so the face card brings a marble out instead. With a defender in range
  it finishes. The park bonus no longer applies to a park spot 1-6 in front of an enemy, so near a defender the bot
  lands 7 or 8 in front of it.
- **2v2 all-bot game 2026-11-11 (game_20261111_111410, flags 1-6 of that day)**, all regression-tested at TTS depth:
  - `JB.eightBackPenalty` (30): don't stop 2-7 behind the NEXT enemy's marble: its 8 back lands 1-6 behind you and
    its teammate moves before you (turn 10).
  - `JB.readiesEntry` needs the marble to come from more than 6 out (`JB.READY_FROM`): a 7 taking a marble from 3 out
    to 1 out is wasteful (turn 18).
  - Escaping into the finish: a marble under a real threat that enters with gaps pays no move gap penalty and gets
    part of the gap cost forgiven: 75% with one real threat (1-6 or 9-13 behind, 8 ahead), all of it with two or more, the board penalty for at most 2 gaps (user: "judgement based but 10-13 is def still a threat"). A clean entry still wins (turns 28, 85).
  - `JB.fixableGapRefund` only for your own finish (or a teammate's once you're finished): Blue's A "closed" Red's gap
    (turn 50).
  - The 1.6x 8 landing cost only for 8s that don't bonk (turn 54: 8 back onto Black on Blue's own entrance).
  - `JB.IMMINENT_DEFENCE_BONUS` (40): bonking an enemy marble 6 or fewer from its finish whose player has 2+ home (not
    with a Joker); with 2 home it also counts the per-home defence bonus (turn 93: K bonk on Blue's entrance).
  - Finish reach bonus only on a safe spot (turn 122); landing on an enemy -8 spot/entrance with a bonk now costs
    half the spot penalty instead of nothing (turn 118, forced Joker).
  - Ambush reach no longer counts a 7 (flag 31: 7 behind the -8 spot can't defend).
- **Stats**: every award has one winner. Ties go to the tied player with the fewest awards (seat order after that).
  The key text and Close button sit centred in the space at the bottom of the panel.
- **2v2 all-bot game 2026-11-11 #2 (game_20261111_114408, 239 turns, no flags)**: reviewed every move; 0 errors,
  0 mismatches. One tuning change: the landing penalty's fixed part `JB.LANDING_BASE` is 50 (was 30): a bonk costs an
  exit card and a turn however little the marble had travelled, and cheap early marbles kept landing 1-6 in front of
  enemies when a safe move was within ~10 points (danger landings by the current code: 7 -> 4 and 7 -> 5 in the two
  games of the day; all flags unchanged except two ties).
- **Second, deeper review of game #2** (user: "dont assume no flags means no bad moves"): every move replayed at TTS
  depth and at 1.5 s, the deep search scoring the TTS pick; extra checks for missed defensive bonks, exit bonks,
  clean entries, teammate catapults, and every Joker in context. Found: teammates parked on an exit were not
  catapulted when the exit card came out (turns 62, 63 of game #1; 122, 126, 132 of game #2). Added
  `JB.catapultBonus` (+50, not the Joker - flag 25): coming out of start onto a teammate parked on your exit, 13+
  from its entrance. All Jokers in game #2 were forced or defensive bonks on 3-home players near their finish.
- **Game 3 (2026-11-11, 4 s think, game_20261111_131859, flags 7-25)** and the user's direction "play as a good
  teammate and conservatively with fewer mistakes" (no game-altering blunders):
  - Jokers: margin 250 (was 150); a defensive Joker only on a player's LAST marble (`JB.JOKER_DEFENCE_HOME` 4, was 3:
    three Jokers on 3-home players were "terrible"); a Joker that leaves its own marble further from home is only
    played when forced; idle 7s/8s are no longer dropped when only Jokers would be left (Blue held 8 8 8 8 8 $ and
    had to Joker); multi-bonk Jokers still count as a big payoff; forced Jokers can earn the catapult bonus.
  - Two cards into the finish: the closing-card refund (`JB.fixableGapRefund`) covers any number of gaps when one
    kept card then moves that marble to the deepest free cell, so the safe card goes first (Green 3 out: 6 in, then
    2). Gap charges live in `JB.gapMoveCharge` (shared with cleanHouseBonus).
  - Running past the entrance follows friendly bonks inside a 7 (Red bonked Blue onto its entrance, then carried it
    past), and costs double from 3 or less out.
  - `JB.clumpPenalty` (50): moving a non-front marble around on its own side while another is there; push the runner.
  - An enemy -8 spot is fine to land on when that enemy has nobody in start or is burning (user). `JB.BURNING` (set by bot.lua from the stats burn streak before each bot move): a burning player's start is no threat, and bonking its marble on its own exit is not "cheap".
- Game plan term now runs after the depth-2 search (`JS.PLAN_FIRST = false`), like the teammate term. Before, it
  could use 40% of the think time first, and in TTS 34 of 193 moves of game 4 only reached depth 1 (Red's K bonk on
  turn 67 instead of a 7 that put teammate Blue's marble home cleanly). Replayed at TTS speed: depth-1 moves 32 -> 6.
- **Game 4 review with the user's verdicts (2026-11-11):**
  - `JB.cleanEntryBonus` (+60): a move that brings an own or teammate marble into the finish with no gap ("clean
    finish entrance outweighs bonk unless the bonk was defending"). Turn 67 (K bonk instead of a 7 putting teammate
    Blue home) now right even at depth 1; turns 62, 86 too. `JB.SPARE_FACE_FINISH_PENALTY` 130 -> 190 to keep the
    face-card rule above it.
  - Landing in danger: a threat from the very next player (it moves first) counts twice (turn 143, 4 in front of
    Black sitting on its exit). `JB.CLUMP_PENALTY` 50 -> 35 so safety beats formation.
  - User OK'd: 42, 74 (multi-bonk Joker), 37 (3 gaps can be fine: easier to close than 1-2), 7 (3 past the exit with
    an 8 planned). 18 fine when building toward the enemy -8 spot (it was: 1 behind Red's).
- **Game 5 (2026-11-11), user: "priority should almost always be to clear up finish, besides game saving defense or
  any defense that prevents an enemy from entering its finish without a joker; if that defense needs an ace, roughly a
  draw":** `JB.finishPackBonus` (+100 per cell a marble moves deeper inside its own finish), `JB.entryDefenceBonus`
  (non-Joker bonk of an enemy within 13 of its finish: 50 + 25 per marble that player has home), Ace cost 35 (was 20)
  and free when used inside / into the finish. Clean entry bonus now 60 + 20 per marble home after it. Turn 195:
  Green, jammed (cells 1-3 and 5) with its last marble 3 out, plays the A (cell 3 -> 4) instead of a 3.
- Game 5 review: `JB.passEntrancePenalty` no longer fires on 8s (an 8 goes backwards; it was charging the rescue move
  as a lap thrown away); running past the entrance from 3 or less out costs `JB.PASS_ENTRANCE_NEAR_PENALTY` 250 ("take
  the bonk rather than run past"); the 1.6x unsafe-8 cost is waived for an 8 that takes a marble back from its
  entrance to 8-11 out (turn 93: Black on its entrance, no card to go in, played a 9 past it instead of 8 back with a
  10 to follow). `JB.KING_EXIT_PENALTY` 25: K out of start while holding a J or Q (turn 99).
- **Flags 27-40 (games 5-6, 2026-11-11):**
  - Finish tidiness (`JB.untidyCells`) is now the number of single steps to pack the finish from the deep end (the
    Aces you'd need): entering cell 1 behind a jam (2, 3, 5 full) is seen as needing a 3rd Ace (flag 30). Making an
    already-untidy finish worse costs the full gap rate (100), not the cheap first-gap 40.
  - Gap closing next turn: a kept 7 counts too (1-6 steps; flag 32: "go in with 5 and clean with 7"), but only if
    the way to the deepest free cell is clear (no jumping in the finish).
  - 7 costs 20 (was 4; flag 33: a 7 spent where the 4 alone did the same), refunded to 4 when only the 7 can make
    that finish entry (`JB.sevenOnlyEntryRefund`, keeps game 4 turn 67 right).
  - Clumping checks each part of a 7, for whichever player's marble it moves; only the part that bonks is exempt
    (flags 34, 36: a 7 moved a rear marble off its exit instead of the runner).
  - Jokers: the 3-home defence bonus no longer applies to Jokers (flag 40: a forced Joker bonked a 3-home player
    instead of catapulting a teammate 62 cells). Defensive Jokers are for last marbles only.
  - `JB.catapultBonus` for any friendly bonk that sends a teammate 13+ cells to its entrance, not only from start.
  - `JB.passEntrancePenalty` follows the parts of a 7 in order (a bonk after a part doesn't make that part "run past").
  - Flags 27/29 (marbles landing just behind their own exit): Joker chains that catapult teammates; flag 28 (8
    friendly bonk) and 37 (Joker from start) already right.
- **sim.lua / run_sims.sh**: headless 2v2, level 9 at varying think times vs level 5 at 2 s (TTS seconds, scaled to
  plain Lua by 0.03), seats swapped every other game, the same deals at every think time.
- **Set-piece benchmark** (`setpieces.lua`, `bench.lua`): 54 positions where the bots went wrong or that test a rule the
  user taught (from the 2v2 game logs plus constructed ones), each with a check for acceptable moves.
  `lua bench.lua 1-9 0.5,1,2,4,8 3` runs every level x think time (TTS seconds) and lists failures; add new flags to
  setpieces.lua as they come. Results 2026-11-11 (sims/bench_full.txt), % of set pieces passed:
  level 1-4: 43-73% at any think time; 5: ~81%; 6: 81-85%; 7: 91-96%; 8 and 9: 100% at 0.5-4 s, 98% at 8 s.
  At 8 s (4-ply search) levels 8-9 choose a 9 that lands Blue's last marble 1 in front of Black (only an A or a 7
  part hits it): the deep search accepts a low-probability risk the user flags as bad. Note the pieces are the ones the
  rules were tuned on, so this is a regression check, not an independent strength test.
- **Generated edge cases** (`setpieces2.lua`, 22 scenarios x 4/6/8 players x seat rotations x with/without extra
  marbles = 440 pieces; `PIECES=setpieces2.lua BYSCEN=1 lua bench.lua 9 2 1`). First run, level 9 @ 2 s: 73% (several
  were scenario mistakes), then 86%, exposing real gaps, now fixed (100%):
  - a 7 that packs the finish (moves a marble deeper inside it) counted as an idle 7 and was dropped;
  - entering behind a jam still won at 6/8 players: making an untidy finish worse now costs `JB.JAM_PENALTY` 80 more;
  - escaping into the finish under attack with 3 gaps lost by 0.1: `JB.ESCAPE_RELIEF` 1.0 (was 0.75), up to 3 gaps;
  - stopping 1-6 past the next enemy's -8 spot while it has marbles in start: `JB.PAST_SPOT_PENALTY` 20 (wait behind);
  - house rule check: a kept 7 only counts as closing a finish gap when it can be split (a teammate has a marble that
    can move) - a 7 is never split between two of your own marbles.
- **Level 10: the engine** (`bot/engine.lua`, `JokerEngine.choose`; difficulty 10 on the bot panel). No hand-made
  strategy rules: one cost function in cells (distance still to travel + START_COST per marble in start + PACK_COST
  per single step needed to pack the finish + expected bonk loss from real card odds, with RISK_AVERSION on our own
  side), our team minus theirs, plus a small value for the cards held (Joker 150, K 20, A / 7 15, 8 8, 10 6). Search:
  expectimax round the table on flat arrays with make/unmake (no tables per node); other seats play their best move
  for the card they most likely hold, weighted by hypergeometric odds from the unseen cards (card counting:
  bot.lua counts every card played since the last reshuffle via game/stats.lua), the likeliest CHANCE_K = 4 outcomes
  searched deeper; own later turns use the real hand (beam 3). Root moves from JokerBot.legalActions (exact rules,
  every 7 split); deeper a 7 is a plain 7 and Jokers are left out. Depth at TTS-equivalent think time (0.03 scale):
  2 s -> 4-5 turns, 4 s -> 5 (a full round + its own next turn in 2v2), 8 s -> 5-6. Level 9 reaches 2.
  Tests: `lua test_engine.lua` (engine moves = JokerBot moves on 300 random 4/6/8-player positions, 3,903 checks);
  `BOT10=1 lua test_bot_glue.lua`. Weights tuned with `lua tune_engine.lua` against the set pieces (78% agreement:
  many pieces encode the user's style - save the Joker, clean entries first - which a general cost function trades
  off differently). It found one wrong set piece (a Joker "stopping" a marble whose finish was jammed shut).
