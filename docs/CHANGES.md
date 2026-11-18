# What changed since "Massive Update 2"

Everything below was added or changed on top of `main` as of "Massive Update 2". All of it has been played in real
games, from solo tests to an 8-player game with some players at a real table. The code was then reorganised:
see the last section, and [ARCHITECTURE.md](ARCHITECTURE.md) for the new layout.

## For players

### Bots
- **Empty seats are played by bots.** They get real cards (hidden off the table), play them face up on their own
  play zone, and move their marbles with an animation. Bots only make legal moves. A bot is named after its marble
  colour, e.g. "BOT (Blue)".
- **Difficulty 1–10.** Level 9 is the default and the one tuned in playtests. Level 10 is an experimental engine.
  The bot's rules come from about 80 playtest reports; see [BOT.md](BOT.md) and [BOT_STRATEGY.md](BOT_STRATEGY.md).
- **Seat changes mid-game:**
  - someone sitting down in a bot's seat takes it over, with its cards;
  - `!botseat` hands an empty seat to a bot;
  - a bot short of cards is dealt back up to 6.
- **Top-left panel:** shows who the bots are and what they're doing.

### Turns
- **The game runs its own turns.** The turn moves on when the player clicks END TURN (on screen) or the Turn
  Button; they draw one card and the next seat plays. The old version relied on TTS's own turn passing, which
  doesn't fire reliably (for example, when playing alone).
- **Whose turn it is:**
  - a banner at the top;
  - a "YOUR TURN!" / "<name>'s turn" splash at every change;
  - the seat's board and play zone glow;
  - play zones are named after who plays there.
- **Off your turn you can't move marbles.** The host can switch this with `!freemove`. You can still hover marbles
  to see distances, and the host can always move marbles to fix mistakes.
- **Illegal friendly bonks are refused.** The whole bonk chain is checked first: a teammate on their own finish
  entrance, or a marble landing on its own marble, can't be bonked. The marble you dropped flies back to where you
  picked it up, with an "ILLEGAL MOVE" message.

### Hover distances
- **Any marble:** hover any marble, not just your own, to see the numbers 1–13 along its route.
- **The -8 spot:** a red marker shows where an 8 played backwards would take it.
- **Readable:** the numbers are bigger, lifted above marbles that would hide them, and turned toward your seat.
- **While carrying:** the numbers stay put while you carry a marble.

### Easy play and click to play (per player, toggles at the bottom right)
- **Easy play:**
  - play a card, and the marbles (or spots) you can choose glow with a pulsing ring;
  - click one to move it with the bots' animation;
  - a 7 is two picks (each marble and its spot), and a Joker is the mover then the target;
  - whenever only one choice is possible it plays by itself, and the winning move always plays by itself;
  - your turn then ends on its own, and a burn ends it too.
- **Click to play:** a quick click on a card in your hand plays it. A drag still rearranges your hand, and clicking
  and holding (while you think) puts the card back.

### Colour picker (rebuilt)
- **Panel:** each player gets their own panel with a colour square, a hue slider and a white-to-black row.
- **Styles:** solid or see-through (with an outline), and Pulse or Twinkle effects that keep running during the
  game.
- **Fix:** the old picker never went away for some players.

### After the game
- **Post-game stats:**
  - per player: cards played by type, burns, bonks given and taken (teammates and enemies), distance travelled,
    the turn they finished, time spent on their turns, and awards ("Sniper", "Marathon Runner", …);
  - team totals and the time of play;
  - it opens a few seconds after the win.

### The host
- **Undo** (host only): undoes the last move. Marbles, cards (back into hands; a card drawn since is shuffled back
  into the deck) and stats all go back. It goes up to 40 turns back, and holds on a bot's turn so you can keep going
  back.
- **Pause / Resume** (anyone): holds the game before the next turn.
- **Hidden chat commands** (`!help`): bot settings, seat changes, failsafes for a game in a bad state (`!turn`,
  `!next`, `!pause`, `!resync`; the resync also runs after any reconnect), and testing helpers (`!give <card>`,
  `!hands`, `!dev`). See [HOST_COMMANDS.md](HOST_COMMANDS.md).
- **Hybrid mode** (`!hybrid on`): for a game where some players sit at a real board.
  - Empty seats are played in person: the host picks the card they played on a card bar and copies their move with
    easy play.
  - The stats count their moves too, and they never touch the TTS deck.
  - `!hybridseat` / `!hybridname` change and name seats mid-game.

### Table and deck
- **Shuffle before dealing:** the deck is shuffled again right before the deal. The setup shuffle could catch the
  deck while it was still being rebuilt, which dealt straight flushes.
- **Automatic reshuffle:** the deck reshuffles by itself when it runs low.
- **Deal to 6:** a button tops every hand up to 6.
- **Reloads:** a game in progress survives a reload. Stats, bot settings, marble styles and in-person seats are
  saved.

## Added after the pull request was opened (2026-11-17)

- **Settings menu:** a gear at the top right (host only) for bot level, animation speed, hybrid mode, what new
  players start with (easy play, click to play) and the turn timer. Saved with the game.
- **How to play:** a **?** button for everyone, with pages on easy play, click to play and the hover numbers. Room for
  screenshots (`assets/tutorial/`).
- **Turn timer:** the player's screen edge glows in their colour on their turn, flashes after 25 s, ticks after
  40 s and goes all out after 55 s. Clicks go through it; it stops when a card is played.
- **Your own name:** a name field in the colour picker; used everywhere instead of the Steam name.
- **Hands off:** only the host can pick up a card from another player's hand or play zone.
- **Chat log:** moves are described by owner and distance ("Blue marble 2 into the finish + Alice's marble 5 (7
  split 2 + 5)") instead of marble numbers that read like the card played.
- **Easy play:** click a picked marble again to un-pick it.
- **Hover numbers:** a marble all the way in shows none (they used to appear on the ring); near its finish, light-blue
  numbers also show where it lands running past the entrance.
- **Drawing:** a drawn card stays face down until it's in the hand (TTS's deal flipped it on the way).
- **Click to play:** a card that bounces off the play zone, or a non-host player's card that jumps back into the hand,
  is put back on the zone.
- **Bot:** tidying a teammate's finish counts for less than entering its own (playtest flag); once the next player
  has nothing left in start, a forward marble guarding another enemy's exit earns a small bonus. A flag waiting in
  the save no longer collects later bot moves.

## For developers

### Layout
`src/` is organised by area: `bot/`, `game/`, `play/`, `ui/` and `host/`, plus the table setup files at the top level
(your originals, commented). [ARCHITECTURE.md](ARCHITECTURE.md) has the file map, the game flow and the conventions.

### The Global script
- **`src/Global.-1.lua` is the table of contents:** every module is included in order, and each TTS event handler
  is defined once there and handed to the modules.
- **No overrides:** an earlier version of these features was pasted onto the end of the scripts and replaced your
  functions. Now each function exists once, where it belongs.

### Your files
- **`marbles.lua`:** spawning and position queries. The collision and bonk rules moved to `game/bonks.lua`.
- **`hover_numbers.lua`:** spawning only. Placing the numbers moved to `game/hover.lua`.
- **`setup.lua`:** the current Start Game flow (bots, stats reset, the turn cycle). It opens the colour pickers in
  the Global script.
- **`color_picker.lua`:** replaced by `ui/color_picker.lua`.
- **Small fixes:**
  - accidental globals (`deck`, `pos`, `board`, `start_game_chip`) are now locals;
  - `CARD_NAMES` is global, because the build wraps each file in its own block;
  - the marble flag set at spawn is now `picked_up`, the name the rest of the code reads (it was `pickedUp`);
  - `changeMatShape` uses `MAT_GUID`.
- **Removed:** `onPlayerTurn` (the game runs its own turns now), `noop`, the empty `onUpdate`, and
  `COLOR_PICKER_GRID_SIZE`.

### Build, test, push
- **Build:** `lua build.lua` no longer needs LuaFileSystem. It only builds the entry scripts (one per scripted
  object), and wraps each include in `do ... end`. `build/` is generated and now in `.gitignore`.
- **Test:** `./tests/run_all.sh` builds everything and runs about 9,100 checks:
  - the built Global script in a mock of the TTS API;
  - the bot's rules and search;
  - every fixed playtest report as a test;
  - a check that every name TTS calls by string exists.
- **Push:** `./tools/push_to_tts.sh` builds and sends the scripts straight to the open game, so you don't need
  VS Code's Save And Play, which truncates scripts this big. `build_and_push.sh` (with a hard-coded path) is gone.
- **Bot tools** (`tools/`): a flag server for "Flag bad move" reports and game logs (written to `data/`, which isn't
  committed), a flag replayer, a game-log checker, and a human-vs-bot move comparison.
