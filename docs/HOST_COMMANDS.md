# Host commands

(For players and hosts. How the code is organised: [ARCHITECTURE.md](ARCHITECTURE.md).)

Chat commands for the host of a Joker game in Tabletop Simulator.

- Type them in the normal chat box.
- Only the host can use them. The command line is hidden from everyone, and the replies go to the host only.
- A guest who types one sees nothing happen, and their message shows as normal chat.
- Commands and their arguments are case-insensitive. Extra spaces are fine.
- Type `!bot` (or `!help`) in game for the short version and the current settings.

## Settings menu (gear, top right, host only)

The gear at the top right opens the host's settings, from the start screen on. The commands below still work; the
menu is the same settings without typing:

- **Bot level** 1-10 (`!level`) and **animation speed** (`!speed`).
- **Hybrid mode** (`!hybrid`): from the next Start Game, empty seats are played at a real board.
- **New players: Easy play / Click to play**: what a player starts with when they sit down or a game starts. Each
  player can still switch their own at the bottom right, and once they do, their choice sticks.
- **Turn timer** and **Timer sounds**: see "Turn timer" below.

Saved with the game. Next to the gear, **?** opens "How to play" for any player.

**Table flipping** can't be switched off from a script. In TTS: **Options → Permissions → untick "Table Flip"**.
Players you promote can still flip, and so can the host.

## Bot settings

| Command | What it does | Default |
|---|---|---|
| `!level <1-10>` | Bot difficulty. 9 is the best rules bot; 10 is the deep-search engine, which is slower and still being tuned. | 9 |
| `!think <secs>` | Think time per bot move, from 0.5 to 60 seconds. | 4 |
| `!speed slow\|normal\|fast\|instant` | How fast the bots' cards and marbles move (and easy-play moves). | normal |
| `!allbots on\|off` | From the next Start Game, every seat is a bot and humans only watch. Off: bots only fill empty seats. | off |

Level, think time, speed and all-bot mode are saved with the game and survive a reload.

## Seats

| Command | What it does |
|---|---|
| `!botseat` | Lists the empty seats by marble colour. |
| `!botseat <colour>` | A bot takes the empty seat with that marble colour, e.g. `!botseat red`. It picks up the cards left in that hand and draws up to 6. If the game was waiting on that seat, the bot plays straight away. |

A player who sits down in a bot's seat takes it over automatically. If the bot is mid-move, it finishes that move first. Then its cards move into the player's hand and the seat is theirs. Chat tells everyone who took over.

## Hybrid mode (some players at a real board)

For a game where some players sit at a real board and others join in TTS.

**Seats** in these commands can be given as:
- a seat number: your seat is 0, then 1, 2, 3... going clockwise (turn order)
- a marble colour (`red`)
- a TTS seat colour
- an in-person name (`pat`)

| Command | What it does | Default |
|---|---|---|
| `!hybrid on\|off` | From the next Start Game, every empty seat is played in person instead of by a bot. (`!async` still works.) | off |
| `!hybridseat <seat> [name]` | A bot's seat (or an empty one) is played in person from now on, e.g. `!hybridseat 1 Kim`. With a name on a seat that's already in person, it just renames it. A bot mid-move finishes it first; its cards go back into the draw deck. If it's that seat's turn, the in-person turn starts. | |
| `!hybridname <seat> <name>` | Names an in-person seat, e.g. `!hybridname 3 Pat` shows "Pat (in person)". The name keeps its capitals and shows on the stats screen. (`!irlname` still works.) | the marble colour |
| `!botseat <seat>` | Hands a seat to a bot, including an in-person one. | |
| `!picker on\|off` | Shows the colour pickers again mid-game (everyone gets theirs back). | |

**Colours and names:** your own colour picker has a tab for each in-person seat. Before Start Game with `!hybrid on`, that's every empty seat. Click a seat's tab, then:

- the colour square, See-through and effects colour that seat's marbles
- a name box names it ("Pat" shows as "Pat (in person)")

The **You** tab goes back to your own marbles. To change them mid-game, use `!picker on`, then `!picker off` when you're done.

How an in-person turn works:

1. The turn shows as theirs as normal (banner, Turn Button).
2. You (the host) get a card bar at the bottom of the screen: A, 2-10, J, Q, K, Joker. Pick the card they played. Suits don't matter.
3. The card counts in their stats as a played card. Nothing is taken from the TTS deck, and they never draw: they use the real deck.
4. Easy play starts for their seat, with you clicking: copy the move they made on the real board. Only one possible move plays by itself; no legal move is a burn.
5. The turn ends by itself once the move has played. A move that wins the game always plays by itself.

- **Wrong card:** pick another one before moving. The first pick no longer counts.
- **Moving by hand:** click Cancel, drag their marbles, then press END TURN (bottom right; only you see it on their turns) or the Turn Button.
- **Undo** works on their turns like any other.
- **Someone joins a seat online:** sitting down in an in-person seat takes it over.
- **A bot should play a seat instead:** `!botseat <colour>`.
- In-person seats are saved with the game.

## Table rules

| Command | What it does | Default |
|---|---|---|
| `!freemove on\|off` | On: anyone can move marbles at any time. Off: players can only move marbles on their own turn. Everyone gets a chat line when it changes. | off |

With free movement off:

- Off-turn players can still hover marbles to see distances, and can still handle their own cards.
- The host can always move marbles, so you can fix mistakes.
- Free movement goes back to off when the save reloads.

## Failsafes

Use these when a reconnect or a glitch leaves the game in a bad state.

| Command | What it does |
|---|---|
| `!turn <who>` | Gives the turn to that seat right now. If a bot is mid-move, it stops and gets topped up to 6 cards. `<who>` can be a marble colour (`!turn yellow`), the start of a player's name (`!turn sam`), or a TTS seat colour. Everyone is told. |
| `!next` | Ends the current turn. A human's turn ends as if they clicked END TURN, and they draw. A bot's turn is skipped. |
| `!pause on\|off` | Pauses the game before the next turn starts (the turn in progress carries on), then shows "Paused" on the banner and the Turn Button. `!pause off` starts that turn. Same as the Pause/Resume button. A pause doesn't survive a reload. |
| `!resync` | Re-sends every marble's colour to all players. Also realigns TTS's own turn (who is allowed to touch pieces) with the Turn Button. |
| `!undo` | Same as the Undo button (see below). |
| `!stats` | Opens the stats screen mid-game. During a game the panel button is Undo, not Stats. |

`!resync` also runs by itself about 4 seconds after anyone reconnects mid-game.

### Turn Button controls during a bot's turn (host only)

- **Click twice within 3 seconds:** skips the bot's turn.
- **Right-click:** the bot rethinks its move.

## Panel buttons (top-left)

During a game, the top-left panel has **Pause** (everyone) and **Undo** (host only) where Stats used to be. Stats comes back when the game ends.

### Pause / Resume (everyone)

- **Pause:** the turn in progress carries on, and the game holds before the next turn starts. Chat says who paused.
- **Resume:** starts the held turn.
- `!pause on|off` does the same.

### Undo (host only)

Only the host sees the button.

- **During a turn that has started** (a card played, a marble moved): that turn starts over. The marbles go back, the card returns to the player's hand, and the stats go back.
- **Between turns, or pressed again:** the turn before is undone, and so on, up to 40 turns back. A card drawn at the end of an undone turn goes back into the draw deck, which is then shuffled.
- **When the undo lands on a bot's turn:** the game pauses there, so you can press Undo again to go further back. Press **Resume** to let the bot play.
- **While a bot is mid-move:** Undo waits for the move to finish, then undoes that bot's turn.

## Easy play (bottom right, one per player)

Each player has their own **Easy play: ON/OFF** button, which only they can see. It is off by default and only affects that player.

With it on:

- **What glows:** the marbles (or spots) you can click get a pulsing, see-through yellow ring. Click the marble, or the spot. To pick a spot with a marble on it, click that marble.
- **The winning move:** on the move that wins the game, it plays by itself (no "run past the finish" option).
- **Only one possible choice:** it's picked for you. A card with only one possible move plays by itself, and so does any step with only one option (e.g. the second part of a 7).
- **Normal cards:** after the card is played, click a glowing marble. If it can end up in two places (a 5 that can enter the finish or run past it), the two spots glow next: click one.
- **Joker:** click the marble to move (any marble in your start), then the marble to land on.
- **7:** click the first marble, then the spot it goes to. That part plays straight away, so anything it bonks has landed before you click the second marble, then its spot. Either part can go first, yours or your teammate's; the order matters for bonks.
- **Your turn ends by itself** once the move has played. The on-screen END TURN button is hidden for you; the table's Turn Button still works.
- **No legal move:** the card is burned and your turn ends straight away.
- **Card taken back:** the glowing stops. Playing a different card starts over with that card.
- **Moving by hand:** click Cancel, then drag the marble yourself.

- **Changing your mind:** click the marble you just picked again to un-pick it (or Cancel).

## Click to play (bottom right, one per player)

A separate **Click to play: ON/OFF** button under Easy play. It's off by default and independent of easy play (it works with easy play on or off).

- Click a card in your hand (a quick click, without dragging) and it flies onto your play zone: 1.5 s on slow, 1 s normal, 0.5 s fast, straight there on instant (follows `!speed`).
- Click and hold (over half a second) while you think: letting go puts the card back in your hand, not played. A quick click after that still plays it.
- Dragging still works: onto the zone yourself, or along your hand to rearrange.
- Only on your own turn, and only your first card.

## Turn timer

On a person's turn, the edge of their screen (only theirs) glows in their marble colour until they play a card:

- **Start:** one flash with a very wide border, so you notice even if you're zoned out.
- **0-25 s:** a slow, gentle glow.
- **25 s:** it flashes. **40 s:** faster, with ticking. **55 s:** a thick border flashing between their colour and
  white, "YOUR TURN" down both sides, faster ticks.
- It never covers the table (clicks go through it), stops as soon as a card is played, and holds while paused.
- The ticks play through TTS's music player, so **everyone** hears them (TTS can't play a sound to one player). They
  replace whatever the music player was playing. Switch them off in the settings.

## Naming a seat

`!name <seat> [name]` names any seat: a bot shows as "Robo (BOT)", an in-person seat as "Pat (in person)", and a
person by that name (the same as the name field in their colour picker). Give no name to go back to the default.
`<seat>` works like `!hybridseat`, and names work as seats afterwards (`!color robo pink`). Saved with the game.

## Recolouring a seat

`!color <seat> <colour> [solid|see] [plain|pulse|twinkle]` recolours any seat's marbles, a bot's, a person's or an
in-person seat's, as if they'd used the colour picker. `<seat>` works like `!hybridseat` (a number, you are 0 then
clockwise; a marble colour; or a name). `<colour>` is a name (red, orange, yellow, green, dark green, cyan, blue, navy,
purple, magenta, pink, brown, white, grey, black) or `#RRGGBB`. Leave the colour out to change only see-through or the
effect. Examples: `!color 2 pink`, `!color blue #FF8800 see`, `!color evan pulse`. `!colour` works too.

## Marble colour picker

Before the game starts, each player gets their own picker (only they see it):

- **Colour square:** click a square to colour your marbles. Saturation runs left to right, brightness top to bottom; muddy dark and grey colours are left out.
- **Hue slider:** sets the colour family the square shows.
- **White to black:** a row of neutrals under the square.
- **Solid / See-through:** see-through marbles are 69% opaque with a black outline.
- **Effects:** Plain, Pulse (brightness breathes), Twinkle (each marble flickers). Effects keep running through the game and after a reload.

Names in chat ("Green", "Magenta"...) follow the picked colour, even while an effect animates it.

- **Your name:** a field at the top of the picker. Type the name you want to be called; blank goes back to your
  Steam name. It's used in chat, on the banner, the play zones and the stats, and only while you're the one in that
  seat. The host's picker also names in-person seats.

## Other players' cards

Only the host can pick up a card that's in another player's hand or on another player's play zone. Everyone else
gets "hands off!". Your own card dropped on the wrong zone can still be taken back.

## Flagging bad bot moves

| Command | What it does |
|---|---|
| `!flag` | Flags the last bot move for review. |
| `!flag <note>` | The same, with a note saying what was wrong, e.g. `!flag red wasted an ace`. The note keeps its capitals. |

Flags go to the flag server (`python3 tools/flag_server.py`, port 8765), which writes them to `data/flags/`. If the server isn't running, the flag is kept in the game save.

## Debug

**Everyone sees these.** Only use them when testing.

| Command | What it does |
|---|---|
| `!hands on\|off` | Shows the bots' cards face up on the table. |
| `!give <card>` | Puts a card of that rank in your hand: `!give a` (or `A`, `ace`), `!give 7`, `!give 10`, `!give k`, `!give joker`. It comes from the draw deck if possible, otherwise from a play pile or the table, never from anyone's hand. Only you see the reply. |
| `!dev on\|off` | Shows the settings and Flag panel in the top-left bot panel. |

## Quick fixes

| Problem | Fix |
|---|---|
| A rejoined player sees the wrong marble colours | `!resync`. If that doesn't work, they leave and rejoin. |
| The Turn Button names one player but someone else can move | `!resync` |
| The turn moved to the wrong player | `!turn <who>` |
| A bot is stuck | Double-click the Turn Button, or `!next`. Right-click the button to make it rethink instead. |
| A friend left mid-game | `!botseat <their marble colour>` |
| Someone made a mistake | Undo button |
| You need a break | Pause button (or `!pause on`), then Resume. |
