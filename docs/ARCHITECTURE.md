# How the code is organised

Read this before changing anything. It explains where each part of the game lives, how a game flows from setup to
the last turn, and the conventions the code relies on.

## Two kinds of script

Tabletop Simulator gives every scripted object its own separate Lua environment, plus one **Global** script.

| Script | Source entry file | Runs |
|---|---|---|
| Global | `src/Global.-1.lua` | the whole game once it starts: turns, bots, stats, UI, chat commands |
| 4 / 6 / 8 Player buttons | `src/Buttons/<n> Player Button.<guid>.lua` | builds the table for that many players |
| Start Game button | `src/Buttons/Start Game Button.0132bf.lua` | deals, makes the play zones, starts the turns |
| Reshuffle button | `src/Buttons/Reshuffle Button.a18a04.lua` | gathers the play zones' cards back into the deck |
| Turn Button, Mat | `src/Buttons/Turn Button.435315.lua`, `src/Mat.b62603.lua` | just name themselves |

The button scripts can't call Global functions directly, so they use `Global.call("name", params)` and
`Global.setTable("name", value)`. `tests/check_wiring.py` checks that every such name exists.

## Building

Entry files pull other source files in with `--#include "path.lua"`. `lua build.lua` resolves the includes and writes
one file per entry into `build/` (generated, not committed). Each included file is wrapped in `do ... end`, so a
file's top-level `local`s are private to it. Lua allows at most 200 locals per chunk, and all the modules together
would go over that.

Files included by both the buttons and Global (`constants`, `helpers`, `cards`, `marbles`, `hover_numbers`) must
only use globals that exist in both environments.

## From setup to the last turn

1. **Pick a table size.** A player-count button calls `preGameSetup(n)` (`src/setup.lua`, in the button's
   script). This sets the table shape, board pieces, board points, invisible planes under the holes, marbles, hover
   number pieces, labelled and shuffled deck, and opens the colour pickers (`Global.call("showColorPickers")`).
2. **Start Game.** `startGame(n)` (`src/setup.lua`) shuffles and deals 6 to each seated player, then:
   - `Global.call("botOnGameStart")` (`bot/players.lua`) makes empty seats bots, or in-person seats in hybrid mode;
   - `Global.call("resetForNewGame")` (Global) resets stats, undo history and easy play;
   - it creates the play zones, the Reshuffle and Turn Buttons, and calls `Global.call("startTurns")`
     (`game/turns.lua`).
3. **Turns.** `turnBegin(seat)` (`game/turns.lua`) starts each turn:
   - **bot:** `botTakeTurn` (`bot/play.lua`) thinks, plays a card, moves, draws, and the turn moves on;
   - **person:** they play a card on their zone, move marbles, then click END TURN or the Turn Button
     (`endTurnClicked`), and draw;
   - **in-person seat:** the host picks the card on the card bar and copies the move (`play/hybrid.lua`);
   - **empty seat** (someone left): skipped.
4. **End.** When a team has every marble home, `turnGameOver` stops the cycle and the stats screen opens.

Every turn start increments `TURN_STATE.gen`. Delayed callbacks (`Wait.time`) remember the number they started
with and do nothing if it changed. This is how an undo or `!turn` cancels a bot halfway through its move.

## TTS events → modules

All handlers are in `src/Global.-1.lua`, each defined once:

| Event | Goes to |
|---|---|
| `onLoad` / `onSave` | `game/save.lua` (stats, flags, bot settings, marble styles, in-person seats survive a reload) |
| `onChat` | `host/commands.lua` `hostChatCommand` (host `!commands`, hidden from chat) |
| `onPlayerAction` (pick-up) | `play/click_to_play.lua`, `play/easy_play.lua` (a click picks), `game/marble_moves.lua` (off-turn block) |
| `onObjectPickedUp` / `onObjectDrop` | the same, plus `marbles.lua` `recordMarbleOrigin` and `game/stats.lua` (finish check) |
| `onObjectEnterScriptingZone` / `Leave` | `game/cards_played.lua` (a card played / taken back) |
| `onObjectCollisionEnter` | `game/bonks.lua` (a marble landing on another) |
| `onObjectHover` | `game/hover.lua` (the distance numbers) |
| `onPlayerChangeColor` | `game/turns.lua` (a bot's seat taken by a person), `play/hybrid.lua` (an in-person seat taken) |
| `onPlayerConnect` | `game/turns.lua` (re-sends marble colours and the turn after a reconnect) |

## Files

```
src/
  Global.-1.lua          table of contents + event handlers
  constants.lua          GUIDs, seat colours, geometry, meshes
  helpers.lua cards.lua board.lua discard_piles.lua buttons.lua   the table (Alex's originals, commented)
  marbles.lua            spawning marbles; where a marble is
  hover_numbers.lua      spawning the distance-number pieces
  setup.lua              preGameSetup / startGame (run in the button scripts)
  Buttons/               the button objects' scripts
  bot/
    rules.lua            board model, card moves, bonks, legal moves (pure Lua)
    evaluate.lua         how good a board is for a team
    setups.lua           bonuses for moves that pay off later
    move_costs.lua       per-move costs/bonuses (card spent, landing in danger, ...)
    hand.lua             choices that depend on the rest of the hand; JB.choose
    search.lua           lookahead search, difficulty levels 1-9
    engine.lua           experimental level-10 engine
    players.lua          bot seats, settings, hands, reading the board, seats changing hands
    play.lua             a bot's turn: think, play the card, animate the marbles, draw
    panel.lua            the top-left panel
    flags.lua            "Flag bad move"
  game/
    turns.lua            the turn cycle and the host's failsafes
    deck.lua             drawing, auto reshuffle, Deal to 6
    cards_played.lua     cards landing on / leaving play zones
    marble_moves.lua     who may pick up marbles
    bonks.lua            collisions: enemy / friendly / illegal bonks
    hover.lua            placing the distance numbers
    stats.lua            counting the post-game stats and awards
    undo.lua             snapshots and Undo / Pause / Resume
    save.lua             what's kept in the save
  play/
    easy_play.lua        glowing choices, click to move
    click_to_play.lua    click a card to play it
    hybrid.lua           in-person seats (some players at a real board)
  ui/
    ui.lua               refreshGameUI: the one XML document everyone sees
    names.lua            names and colours (follow the marble colour)
    color_picker.lua     the colour picker, marble styles and effects
    turn_ui.lua          banner, END TURN, splash, Turn Button label
    stats_panel.lua      stats screen and panel buttons
  host/
    commands.lua         host chat commands (!help lists them)
    game_log.lua         the game log sent to tools/flag_server.py
tests/                   test suites + a mock of the TTS API (run_all.sh)
tools/                   push_to_tts.sh, flag server, analysis tools
docs/                    this file, host commands, the bot's rules and tuning history, change list
```

## The board model (bots, stats, easy play, undo)

The bots, stats, easy play and undo read the board as a logical state (`botReadState` in `bot/players.lua`). Each
marble is matched to the nearest board point.

- **Seats** are numbered 1..N in turn order (`PLAYER_COLORS[N]`). Teams are odd seats against even seats.
- **The ring** has 18 cells per seat, numbered 1..18N; moving forward means a higher number, wrapping round.
  - Seat s's **finish entrance** is ring cell `(s-1)*18+3`: a marble turns into its finish from there, and a
    friendly-bonked marble lands there.
  - Its **exit** is `(s-1)*18+8`: where a marble lands when it leaves start.
- **A marble** is `{seat, kind, p}`: kind `S` (start), `R` (ring cell p) or `G` (finish hole p = 1..5).
- **Board points:** the table's `non_start_points` list stores 23 entries per seat: ring cells 1–3, the 5 finish
  holes, then ring cells 4–18. `JB.cellToIndex` / `JB.indexToCell` convert between the two numberings.

## Global state

| Table | Module | What |
|---|---|---|
| `TURN_STATE` | game/turns.lua | whose turn (`seat`), `active`, `busy` (a bot moving / turn ending), `paused`, `gen` |
| `BOT_STATE` | bot/players.lua | bot seats, their hands (card objects), speed, status line, history of moves |
| `GAME_STATS` | game/stats.lua | the stats of the game in progress (saved) |
| `UNDO` | game/undo.lua | snapshots, one per turn start |
| `EASY` | play/easy_play.lua | who has easy play / click to play on, the current choice in progress |
| `IRL` | play/hybrid.lua | hybrid mode, in-person seats and their names (saved) |
| `MARBLE_STYLE` | ui/color_picker.lua | each seat's picked colour, see-through, effect (saved) |
| `UI_STATE` | ui/ui.lua | which overlays are open (picker, stats) |
| `GLOG` | host/game_log.lua | the game log buffer |

The board itself is in Global tables set by the setup scripts: `marbles_by_player`, `non_start_points`,
`boards_by_player`, `hover_numbers_by_player`, `discard_piles`, `num_players`.

## Conventions

- **Names follow marble colour, not TTS seat colour.** The Orange seat playing blue marbles is "Blue" everywhere:
  chat, bot names, the banner and stats. The picker changes colours mid-game, so names are read live
  (`ui/names.lua`).
- **One UI document.** Everything on screen is rebuilt by `refreshGameUI()`. Parts for one player use
  `visibility="<colour>"`, parts for the host `visibility="Host"`. A part never adds itself to the document or
  hides itself.
- **Host-only things** check `Player[colour].host`. Host chat commands are hidden from the other players.
- **Comments say why.** Many say "(user, flag N)" or give a date: those come from playtest reports, and
  [BOT_TUNING_LOG.md](BOT_TUNING_LOG.md) has the story behind each one.

## Testing

`./tests/run_all.sh` builds everything and runs:
- `test_game.lua`: the built Global script in a mock of the TTS API (`tests/tts_mock.lua`). It covers turns, bots
  at the table, stats, easy play, click to play, undo, hybrid mode, colour picker and commands.
- `test_bot_rules.lua`, `test_bot_search.lua`, `test_bot_engine.lua`: the bot in plain Lua. Every fixed playtest
  report is a test in `test_bot_search.lua`.
- `check_wiring.py`: every function TTS calls by name exists.

The mock has no physics, board spawning or real rendering. Anything visual (positions, glow, button sizes) still
needs checking in TTS itself.
