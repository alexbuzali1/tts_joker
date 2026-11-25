# How the bot plays Joker

These are the playtesters' rules, collected from "Flag bad move" reports (flag numbers in brackets; the history is in
[BOT_TUNING_LOG.md](BOT_TUNING_LOG.md)). Each rule is in the code in `src/bot/` (mostly evaluate.lua, move_costs.lua
and hand.lua); `tools/analyze_log.lua` checks game logs against the ones it can test automatically.

## Priorities
1. **Win.** A position where your team finishes is worth everything (58).
2. **Game-saving defence.** Bonking an enemy's last marble when it is close to home trumps everything else (47). The
   same marble far from home matters much less (79).
3. **Finishing a player.** Bringing a player's last marble home ranks just below that (79).
4. **Run when you're ahead.** With one marble left and the enemy further behind, push for the finish instead of
   ordinary defence (54, 56, 57, 58).

## Cards
- **Joker:** save it. Play it only for a big payoff, a defensive bonk on a player with 3 or more home, or when
  nothing else is legal (25, 26, 48).
  - Only the last Joker is that precious. Spare Jokers (beyond the ones still needed to bring marbles out of start)
    are cheaper to play once 3 or more are spare: then play one for any clearly good move rather than burning an Ace (45).
- **7:** play it only to:
  - bonk a high-quality target (it has travelled far, is close to its finish, or is that player's last marble);
  - catapult a teammate a long way;
  - enter the finish without leaving a gap, or tidy the finish (18, 19);
  - leave a marble right at its entrance, ready to go in (64).

  Any bonk is not a good bonk (19, 26, 67, 75). Teammate 7 combos, where your teammate's part bonks your marble onto
  your entrance and your part carries it in, are top value (29, 60, 79).
- **8:** an 8 back that bonks and lands you on your own entrance is great (2026-11-11). Play it only if it bonks or sets up a finish. Never land somewhere unsafe with it, especially with only one
  8 in hand (3, 5, 8, 37, 45, 62, 70).
- **K:** it is the defence card, so don't use it to leave start when you hold a J or Q (23, 24, 59).
- **A:** hold it for niche situations (exact finishes) and come out with face cards instead (44, 55).
  Don't spend it on a low-impact move such as a 1-step setup when another card does nearly as well (2026-11-12 flag
  41). It's still worth spending to keep a valuable marble out of danger when every other move lands in danger.
- **10:** worth more than a J or Q for plain movement (user note after flag 41).
- **Duplicates:** when in doubt, play the card you hold several of (23).
- **Stacked hand:** with lots of face cards, use them to fly around, help teammates and play defence (39, user note).
  With few, stay thrifty so you don't burn (4).
- **Burn order:** anything else first, then 10s, then 7s, then 8s (72).

## Safety
- An enemy 1-6 or 9-13 behind you is dangerous; 7 or 8 behind is safe. An enemy exactly 8 ahead is dangerous (it can
  play the 8 backwards) (3, 8). Look for the safe spots, e.g. 3 behind an enemy, a J lands 8 in front (user note).
- Never land on an enemy's exit cell while it has marbles in start (21, 28). Bonking the marble sitting there doesn't make it
  OK: that only adds one to its start, and it comes straight out onto you, especially when it moves next (2026-11-12
  flag 42).
- Don't stop 2-7 behind the next player's marble: its 8 back lands just behind you and its teammate bonks you
  before you can move (2026-11-11). Wait 1-6 behind its -8 spot instead.
- A marble under threat right at its entrance goes in, even with gaps (2026-11-11).
- Never land on an enemy's finish entrance (its teammate can bonk it onto you) or on its -8 spot. Wait behind them
  (41, 67, 68, 71).
- Don't over-protect a marble just because many cards were spent on it: no sunk cost (41).
- An empty enemy start is not a reason to crawl; run past it (77).

- Bonk a marble about to go in (6 or fewer from its finish) when that player has 2+ home (2026-11-11).

## Formation and setups
- Keep one defender near your start; the others run. Don't clump (12, 16). Push the furthest marble (39, 41, 42).
- Don't leave the defender 2 or 3 past your exit, because it can't reach the next player's -8 spot from there (31).
- Have a marble out at the start of the game, just in case (63).
- Park on a teammate's exit, and stay there: their next exit card catapults you to your entrance (46, 66).
- Get within 1-6 behind an urgent enemy (close to its finish, 3+ home) so you or a teammate can bonk it (76).
- Bonk an enemy sitting on your exit as you come out: it's a sure bonk (38).
- Bonking a marble on its own exit is cheap (it comes straight back out) unless that player has been burning (26, 78).

## Finish
- Keep the finish clean: fill it from the deep end before lining up more marbles (5, 18, 19, 50, 51).
- Wait on your finish entrance as long as possible; take the bonk rather than run past (43, 73). Never run past it
  from anywhere within 13 to dodge a bonk: that's a whole lap.
- Check whether one card, or any two cards in a row, finish a marble cleanly. If they do, don't enter with a gap.
  A gap is fine only if a kept card closes it next turn (user, 2v2 game: "it should always be checking if a distance
  it wants to travel can be made with a combination of cards in its hand").

- **Face card or small cards to finish:** if a J/Q/K would finish cleanly but small cards in hand (one, or two in a
  row) could too, and no enemy marble is in range behind, bring a marble out with the face card instead. With a
  defender in range, finish with the face card.
- Near a defender, land 7 or 8 in front of it with a small card when you can (park spots too: a park 1-6 in front of
  an enemy earns nothing).

## Teamwork
- Think about what your teammate can do next turn: don't move their marble out of reach of its finish, and leave
  them chances (user: "at 2 turns ahead it never sees a teammate move is bad").
- A finished player stops thinking about its own marbles: it runs its teammate's marbles with big cards, keeps small
  cards for exact finishes, and stays out of the way (52, 53, 56, 57, 58).
