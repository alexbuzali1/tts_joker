-- Tests for stats.lua (acceptance checks 1-7 from STATS_SCREEN_INSTRUCTIONS.md) and the -8 hover marker.
-- Run from this folder:  lua test_stats.lua
math.randomseed(11)
local M = dofile("tests/tts_mock.lua")
local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. msg) end
end
local function count(list, pat) local n = 0; for _, s in ipairs(list) do if s:find(pat, 1, true) then n = n + 1 end end; return n end

local function fresh(N, seated)
    M.setup(N, seated)
    GAME_STATS, BOT_STATE, TURN_STATE, UI_STATE = nil, nil, nil, nil
    M.loadGlobal()
    BOT_DEBUG_SHOW_HANDS = false
    BOT_THINK_TIME = 0.05                         -- keep the bot searches short in tests
    resetForNewGame({ num_players = N })          -- what Start Game does (Global)
end
local function col(token) for i, t in ipairs(STATS_CARDS) do if t == token then return i end end end
local function play(color, name)      -- a human drops a card on their own play zone
    local c = M.card(name, color)
    c.setPosition(M.discard[color].pos)
    return c
end

------------------------------------------------------------------------
print("== 1. cards played")
fresh(4, { White = true, Orange = true, Green = true, Purple = true })
statsTurnStart("White")
local ace = play("White", "Ace of Spades")
play("White", "7 of Hearts")
play("White", "Joker")
local W = GAME_STATS.players.White
check(W.cards[col("a")] == 1 and W.cards[col("7")] == 1 and W.cards[col("$")] == 1, "three cards counted")
ace.setPosition(M.discard.White.pos)                -- same card lands in the zone again, same turn
check(W.cards[col("a")] == 1, "same card twice counts once")
local wrong = M.card("King of Clubs", "White"); wrong.setPosition(M.discard.Orange.pos)
check(W.cards[col("k")] == 0 and GAME_STATS.players.Orange.cards[col("k")] == 0, "wrong pile not counted")
check(count(M.chat, "Wrong discard pile") == 1, "wrong pile still reported")

------------------------------------------------------------------------
print("== 2. bonks")
fresh(4, { White = true, Orange = true, Green = true, Purple = true })
-- White marble on a ring cell; an Orange marble (enemy) dropped onto it
M.place("White", 1, 23 + 12)
local orange = M.mbp.Orange[1]
orange.setPositionSmooth({ x = M.mbp.White[1].pos.x, y = M.mbp.White[1].pos.y + 1.2, z = M.mbp.White[1].pos.z })
M.pump()
local S = GAME_STATS.players
check(S.Orange.enemiesBopped == 1 and S.White.boppedByEnemy == 1, "enemy bonk counted for both")
check(S.Orange.teammatesBopped == 0 and S.White.boppedByTeammate == 0, "enemy bonk is not friendly")
-- Green (White's teammate) dropped onto a White marble on the ring -> friendly bonk
M.place("White", 2, 46 + 15)
local green = M.mbp.Green[1]
green.setPositionSmooth({ x = M.mbp.White[2].pos.x, y = M.mbp.White[2].pos.y + 1.2, z = M.mbp.White[2].pos.z })
M.pump()
check(S.Green.teammatesBopped == 1 and S.White.boppedByTeammate == 1, "friendly bonk counted for both")
-- illegal: White marble sitting on its own finish entrance, Green dropped onto it -> rejected, nothing counted
M.place("White", 3, 3)
local green2 = M.mbp.Green[2]
green2.setPositionSmooth({ x = M.mbp.White[3].pos.x, y = M.mbp.White[3].pos.y + 1.2, z = M.mbp.White[3].pos.z })
M.pump()
check(count(M.broadcasts, "ILLEGAL MOVE") == 1, "illegal bonk rejected")
check(S.Green.teammatesBopped == 1 and S.White.boppedByTeammate == 1, "illegal bonk changes nothing")
check(S.Orange.enemiesBopped == 1 and S.White.boppedByEnemy == 1, "illegal bonk changes nothing (enemy columns)")

------------------------------------------------------------------------
print("== 3. rounds burned")
fresh(4, { White = true, Orange = true, Green = true, Purple = true })
statsTurnStart("Orange"); play("Orange", "3 of Clubs"); statsTurnEnd("Orange")
check(GAME_STATS.players.Orange.burned == 1, "card played, nothing moved -> burned")
statsTurnStart("Orange"); play("Orange", "4 of Clubs"); M.place("Orange", 1, 23 + 12); statsTurnEnd("Orange")
check(GAME_STATS.players.Orange.burned == 1, "marble moved -> not burned")
statsTurnStart("Orange"); statsTurnEnd("Orange")
check(GAME_STATS.players.Orange.burned == 1, "no card played -> not burned")

------------------------------------------------------------------------
print("== 4. finish + winner")
fresh(4, { White = true, Orange = true, Green = true, Purple = true })
for k = 1, 5 do M.place("White", k, JokerBot.cellToIndex('G', k, 1)) end
statsTurnStart("White"); statsTurnEnd("White")
local t_white = GAME_STATS.players.White.turnFinished
check(t_white == 1, "White finished on turn 1 (got " .. tostring(t_white) .. ")")
check(GAME_STATS.winner == 0, "no winner while Green still out")
statsTurnStart("Orange"); statsTurnEnd("Orange"); statsCheckFinish()
check(GAME_STATS.players.White.turnFinished == 1, "finish turn recorded once")
check(count(M.chat, "has made it home") == 1, "made it home announced once")
for k = 1, 5 do M.place("Green", k, JokerBot.cellToIndex('G', k, 3)) end
statsTurnStart("Green"); statsTurnEnd("Green"); statsCheckFinish(); statsCheckFinish()
check(GAME_STATS.winner == 1, "Team 1 wins when White and Green are home")
check(count(M.broadcasts, "wins!") == 1, "winner announced once")
check(not UI_STATE.stats, "the stats wait while the \"Team 1 wins!\" pop-up shows")
M.pumpFor(STATS_OPEN_DELAY + 0.1)
check(UI_STATE.stats == true and UI.xml:find("Post Game Stats", 1, true) ~= nil, "stats screen opens on win, after the pop-up")
statsClose()
check(not UI.xml:find("Post Game Stats", 1, true), "Close hides the stats screen")

------------------------------------------------------------------------
print("== 4b. the game stops when a team wins")
fresh(4, { White = true })
botOnGameStart({ num_players = 4 }); M.pump(); statsReset({ num_players = 4 })
for k = 1, 5 do M.place("White", k, JokerBot.cellToIndex('G', k, 1)) end
for k = 1, 5 do M.place("Green", k, JokerBot.cellToIndex('G', k, 3)) end
TURN_STATE.active = true; TURN_STATE.seat = 0
turnBegin(1, true); M.pump()
local before = GAME_STATS.turn
endTurnClicked(nil, "White"); M.pump()
check(TURN_STATE.active == false, "turn cycle stopped")
check(GAME_STATS.turn == before, "no bot played after the win (turn " .. GAME_STATS.turn .. " vs " .. before .. ")")
check(M.chip.label:find("Game over", 1, true) ~= nil, "Turn Button says game over (" .. M.chip.label .. ")")
endTurnClicked(nil, "White"); M.pump()
check(GAME_STATS.turn == before, "clicking again does nothing")

print("== 4d. the next turn waits for moving marbles (e.g. a bonk still flying home)")
fresh(4, { White = true })
botOnGameStart({ num_players = 4 }); M.pump(); statsReset({ num_players = 4 })
TURN_STATE.active = true; TURN_STATE.seat = 0
turnBegin(1, true); M.pump()
local flying = true
M.mbp.Orange[2].isSmoothMoving = function() return flying end
local t0 = GAME_STATS.turn
endTurnClicked(nil, "White"); M.pump(40)
check(GAME_STATS.turn == t0, "no bot turn while a marble is still moving")
flying = false
M.pump()
check(GAME_STATS.turn > t0, "the next turn starts once everything has landed")

print("== 4c. bots are named after their marble colour")
fresh(4, { White = true })
botOnGameStart({ num_players = 4 }); M.pump()
check(botName("Orange") == "BOT (Blue)", "Orange seat (blue marbles) -> " .. botName("Orange"))
check(botName("Green") == "BOT (Green)", "Green seat (green marbles) -> " .. botName("Green"))
check(botName("Purple") == "BOT (Red)", "Purple seat (red marbles) -> " .. botName("Purple"))
TURN_STATE.active = true; TURN_STATE.seat = 0
turnNamePlayZones()
check(M.discard.Orange.getName() == "BOT (Blue)'s Play Zone", "Orange seat's play zone -> " .. M.discard.Orange.getName())
check(M.discard.White.getName() == "Human-White's Play Zone", "human play zone -> " .. M.discard.White.getName())
check(UI.xml:find(">Blue<", 1, true) ~= nil and not UI.xml:find(">Orange<", 1, true), "panel title uses marble colour names")
check(count(M.chat, "Bots are playing") == 1 and M.chat[#M.chat]:find("Blue", 1, true) ~= nil, "Bots are playing line uses marble colour names (" .. M.chat[#M.chat] .. ")")
M.mbp.Orange[1].tint = { r = 1, g = 0.5, b = 0 }
check(botName("Orange") == "BOT (Orange)", "a re-tinted marble renames the bot -> " .. botName("Orange"))

print("== 4e. a stats value that isn't a number doesn't crash the stats screen")
fresh(4, { White = true, Orange = true, Green = true, Purple = true })
GAME_STATS.players.White.turnFinished = {}           -- what a real game produced somehow
local okA = pcall(statsAwards)
local okX = pcall(statsPanelXml)
check(okA and okX, "awards and the stats screen survive a table value")
check(count(M.chat, "STATS DEBUG") == 1, "the bad value is reported once in chat")

print("== 5. awards")
fresh(4, { White = true, Orange = true, Green = true, Purple = true })
local A = statsAwards()
local any = false
for _, list in pairs(A) do if #list > 0 then any = true end end
check(not any, "all zero -> no awards (incl. no Fast Finisher)")
local P4 = GAME_STATS.players
P4.White.enemiesBopped, P4.Orange.enemiesBopped = 2, 2            -- tie for Sniper
P4.White.teammatesBopped = 1                                     -- White also Best Teammate
P4.Green.turnFinished, P4.Purple.turnFinished = 30, 25            -- Purple is the Fast Finisher
A = statsAwards()
local function has(c, name) for _, a in ipairs(A[c]) do if a == name then return true end end end
check(has("Orange", "Sniper") and not has("White", "Sniper"), "tie -> one Sniper, for the player with fewer awards (Orange; White is Best Teammate)")
check(has("White", "Best Teammate"), "White keeps Best Teammate")
P4.White.enemiesBopped = 3                                       -- now White wins Sniper outright
A = statsAwards()
check(has("White", "Best Teammate") and has("White", "Sniper") and not has("Orange", "Sniper"), "one player holds two awards")
local n = 0
for _, list in pairs(A) do for _, a in ipairs(list) do if a == "Sniper" then n = n + 1 end end end
check(n == 1, "every award has exactly one winner")
check(has("Purple", "Fast Finisher") and not has("Green", "Fast Finisher") and not has("White", "Fast Finisher"), "Fast Finisher = smallest finished turn")

------------------------------------------------------------------------
print("== 6. statsPanelXml is well formed for 4, 6, 8 players")
local function wellFormed(xml)
    local stack = {}
    for close, name, selfclose in xml:gmatch("<(/?)([%w]+)[^>]-(/?)>") do
        if close == "/" then
            if stack[#stack] ~= name then return false, "unexpected </" .. name .. ">" end
            stack[#stack] = nil
        elseif selfclose ~= "/" then
            stack[#stack + 1] = name
        end
    end
    if #stack > 0 then return false, "unclosed <" .. stack[#stack] .. ">" end
    if xml:find("&[^#%a]") then return false, "bare &" end
    return true
end
for _, N in ipairs({ 4, 6, 8 }) do
    local seated = {}
    for _, c in ipairs(PLAYER_COLORS[N]) do seated[c] = true end
    fresh(N, seated)
    GAME_STATS.players[PLAYER_COLORS[N][1]].cards[1] = 3
    Player = setmetatable({}, { __index = function(_, c) return { seated = true, steam_name = 'Tom & "Jerry" <3', color = c } end })
    local xml = statsPanelXml()
    local ok, why = wellFormed(xml)
    check(ok, N .. " players: " .. tostring(why))
    local rows = select(2, xml:gsub("<Row ", ""))
    check(rows == (N + 1) + 3, N .. " players: " .. rows .. " table rows")
    statsOpen()
    local ok2, why2 = wellFormed(UI.xml)
    check(ok2, N .. " players: full UI (bot panel + stats) " .. tostring(why2))
end

------------------------------------------------------------------------
print("== 7. bots are counted like humans (full turns through turns.lua)")
fresh(4, { White = true })                       -- Orange, Green, Purple are bots
botOnGameStart({ num_players = 4 })
M.pump()
statsReset({ num_players = 4 })
local burns = {}
local origStatus = botSetStatus
botSetStatus = function(text, color) if text:find("burns a", 1, true) then burns[color] = (burns[color] or 0) + 1 end; return origStatus(text, color) end
M.place("Orange", 1, 23 + 10); M.place("White", 1, 23 + 12); M.place("Green", 1, 46 + 12); M.place("Purple", 1, 69 + 5)
TURN_STATE.active = true; TURN_STATE.seat = 0
turnBegin(1, true); M.pump()
local rounds = 25
for _ = 1, rounds do
    play("White", "2 of Spades")                  -- the human plays a card (no move: a burn)
    endTurnClicked(nil, "White"); M.pump()
end
local errs = count(M.chat, "BOT ERROR")
check(errs == 0, "no bot errors (" .. errs .. ")")
for _, c in ipairs({ "Orange", "Green", "Purple" }) do
    local ps = GAME_STATS.players[c]
    local total = 0
    for i = 1, #STATS_CARDS do total = total + ps.cards[i] end
    check(total == rounds, c .. " played " .. total .. " cards in " .. rounds .. " turns")
    check(ps.burned == (burns[c] or 0), c .. " burned " .. ps.burned .. " = bot burns " .. tostring(burns[c] or 0))
end
check(GAME_STATS.players.White.burned == rounds, "the human's no-move turns are burns too")
local bonkChat = count(M.chat, "bonked")
local bonkStats = 0
for _, c in ipairs(PLAYER_COLORS[4]) do local ps = GAME_STATS.players[c]; bonkStats = bonkStats + ps.teammatesBopped + ps.enemiesBopped end
check(bonkStats == bonkChat, "every bonk announced in chat is counted (" .. bonkStats .. " vs " .. bonkChat .. ")")
check(GAME_STATS.turn == 1 + rounds * 4, "turn counter: " .. GAME_STATS.turn)
print(string.format("   (bots bonked %d times, burned %d times over %d turns)", bonkStats - 0, (burns.Orange or 0) + (burns.Green or 0) + (burns.Purple or 0), GAME_STATS.turn))

------------------------------------------------------------------------
print("== 7b. 6- and 8-player games: every bot card lands on its own play zone")
for _, N in ipairs({ 6, 8 }) do
    fresh(N, { White = true })
    botOnGameStart({ num_players = N }); M.pump(); statsReset({ num_players = N })
    TURN_STATE.active = true; TURN_STATE.seat = 0
    turnBegin(1, true); M.pump()
    for _ = 1, 3 do play("White", "2 of Spades"); endTurnClicked(nil, "White"); M.pump() end
    local short = {}
    for s = 2, N do
        local c = PLAYER_COLORS[N][s]
        local total = 0
        for i = 1, #STATS_CARDS do total = total + GAME_STATS.players[c].cards[i] end
        if total ~= 3 then short[#short + 1] = c .. "=" .. total end
    end
    check(#short == 0, N .. " players: bot cards counted on their own zones (" .. table.concat(short, ", ") .. ")")
    check(count(M.chat, "Wrong discard pile") == 0, N .. " players: no card on a wrong pile")
end

print("== 7c. a played card that merges into the pile (object gone) doesn't break the bot's turn")
fresh(4, { White = true })
M.merge_cards = true
botOnGameStart({ num_players = 4 }); M.pump(); statsReset({ num_players = 4 })
TURN_STATE.active = true; TURN_STATE.seat = 0
turnBegin(1, true); M.pump()
local okRun, errRun = pcall(function()
    for _ = 1, 3 do play("White", "2 of Spades"); endTurnClicked(nil, "White"); M.pump() end
end)
M.merge_cards = false
check(okRun, "no script error when played cards merge (" .. tostring(errRun) .. ")")
check(GAME_STATS.turn == 1 + 3 * 4, "all bot turns completed (turn " .. GAME_STATS.turn .. ")")

print("== 7d. a stuck bot turn: host skip (two clicks), rethink (right-click), automatic watchdog")
fresh(4, { White = true })
botOnGameStart({ num_players = 4 }); M.pump(); statsReset({ num_players = 4 })
TURN_STATE.active = true; TURN_STATE.seat = 0
turnBegin(1, true); M.pump()
local realThink = botThink
botThink = function() end                         -- the search never comes back: the bot hangs
play("White", "2 of Spades"); endTurnClicked(nil, "White"); M.pumpFor(10)
check(BOT_STATE.current and BOT_STATE.current.color == "Orange", "Orange is stuck mid-turn")
endTurnClicked(nil, "White", false); endTurnClicked(nil, "White", false); M.pumpFor(10)
check(count(M.chat, "skipped by the host") == 1, "two host clicks skip the stuck turn")
check(BOT_STATE.current and BOT_STATE.current.color == "Green", "play moved on to the next bot (Green)")
check(#BOT_STATE.hands.Orange == 6, "the skipped bot still has 6 cards")
botThink = realThink                              -- the search works again: right-click = rethink
endTurnClicked(nil, "White", true); M.pump()
check(count(M.chat, "rethinking its move") == 1, "right-click makes the bot rethink")
check(TURN_STATE.seat == 1 and not TURN_STATE.busy, "after the rethink the round finishes and it is White's turn again")
-- watchdog: hang again and leave it alone
botThink = function() end
play("White", "2 of Spades"); endTurnClicked(nil, "White"); M.pump()
check(count(M.chat, "seems stuck") >= 1 and count(M.chat, "still stuck") >= 1, "watchdog rethinks, then skips")
check(TURN_STATE.seat == 1 and not TURN_STATE.busy, "the watchdog gets play back to White")
botThink = realThink

print("== 7e. Flag bad move: bot moves are recorded and sent to the flag server")
fresh(4, { White = true })
BOT_STATE.history = {}; BOT_FLAGS = {}
botOnGameStart({ num_players = 4 }); M.pump(); statsReset({ num_players = 4 })
TURN_STATE.active = true; TURN_STATE.seat = 0
turnBegin(1, true); M.pump()
for _ = 1, 3 do play("White", "2 of Spades"); endTurnClicked(nil, "White"); M.pump() end
local h = BOT_STATE.history
check(#h == BOT_HISTORY_SIZE, "the last " .. BOT_HISTORY_SIZE .. " bot moves are kept (" .. #h .. ")")
local last = h[#h]
check(last and #last.board_before == 20 and #last.hand >= 1 and last.chosen and last.chosen.card, "a record has the board before, the hand and the chosen move")
check(last and #last.alternatives >= 1, "a record lists the alternatives it considered")
M.posts = {}
flagNoteChanged({ color = "White" }, "moved off the -8 spot")
flagBadMove({ color = "White" })
local flagPosts = {}
for _, p in ipairs(M.posts) do if p.url == FLAG_SERVER_URL then flagPosts[#flagPosts + 1] = p end end
check(#flagPosts == 1 and flagPosts[1].method == "POST", "the flag is posted to the flag server")
check(count(M.broadcasts, "Bad move flagged") == 1, "the player is told it was saved")
M.web_ok = false
flagBadMove({ color = "White" })
M.web_ok = true
check(#BOT_FLAGS == 1 and count(M.broadcasts, "Flag kept in the game save") == 1, "server down: the flag is kept for the save")

print("== -8 hover marker")
fresh(4, { White = true })
local total = #M.nsp
local bad = 0
for idx = 1, total do
    local kind, p, s = JokerBot.indexToCell(idx)
    local got = hoverMinus8Index(idx, total)
    if kind == 'G' then
        if got ~= nil then bad = bad + 1 end
    else
        local back = ((p - 8 - 1) % (18 * 4)) + 1
        if got ~= JokerBot.cellToIndex('R', back) then bad = bad + 1; print("   idx " .. idx .. " -> " .. tostring(got)) end
    end
end
check(bad == 0, "-8 lands 8 ring cells back from every ring cell, none from a finish")

print("== a friendly bonk is checked down the whole chain")
do
    fresh(4, { White = true, Green = true })
    local mbp = Global.getTable("marbles_by_player")
    local ent = function(seat) return (seat - 1) * 23 + 3 end
    M.place("Green", 1, 40)                                       -- G: bonked by White
    M.place("White", 2, ent(3))                                   -- a White marble on Green's entrance
    local G = mbp.Green[1]
    check(illegalFriendlyBonk(G) == nil, "chain: Green flies to its entrance and bonks White on to White's entrance (legal)")
    M.place("White", 3, ent(1))                                   -- ...but White's entrance holds a White marble
    local why = illegalFriendlyBonk(G)
    check(why ~= nil, "the chain ends on a marble's own marble: the whole move is illegal (" .. tostring(why) .. ")")
    M.place("White", 3, 20)
    M.place("Orange", 1, ent(1))                                  -- an enemy on White's entrance: sent home, fine
    check(illegalFriendlyBonk(G) == nil, "a chain that ends on an enemy is legal")
    M.place("White", 2, 50)
    M.place("Green", 2, ent(3))                                   -- Green's own marble on Green's entrance
    check(illegalFriendlyBonk(G) ~= nil, "a bonked marble can't land on its own marble")
    -- the move is turned back before anything is bonked: the dropped marble goes back where it was picked up
    M.place("Green", 2, 30)
    M.place("White", 2, ent(3))
    M.place("Orange", 1, 60)
    M.place("White", 3, ent(1))
    local W1 = mbp.White[1]
    M.place("White", 1, 35)
    onObjectPickedUp("White", W1)
    local gpos = { x = G.pos.x, y = G.pos.y, z = G.pos.z }
    W1.pos = { x = G.pos.x, y = G.pos.y + 0.5, z = G.pos.z }      -- dropped on Green
    W1.vars.picked_up = false
    marbleCollisionDetection(G, { collision_object = W1 })
    M.pump(200)
    check(G.pos.x == gpos.x and G.pos.z == gpos.z, "Green isn't bonked")
    check(M.broadcasts[#M.broadcasts]:find("ILLEGAL MOVE", 1, true) ~= nil, "the move is called illegal")
end

print("== hover numbers jump above a marble in their hole")
do
    fresh(4, { White = true })
    local nums = {}
    for k = 1, 13 do nums[k] = M.newObj({ pos = { x = 0, y = 0, z = 0 }, tag = "Tile" }) end
    local gt, hide, m8 = Global.getTable, hideHoverNumbers, hoverPlaceMinus8
    Global.getTable = function(k) if k == "hover_numbers_by_player" then return { White = nums } end return gt(k) end
    hideHoverNumbers = function() end
    hoverPlaceMinus8 = function() end
    M.place("White", 1, 10)
    M.place("Orange", 1, 13)                                      -- 3 in front
    local mo = Global.getTable("marbles_by_player").Orange[1]
    mo.pos.y = 2.2
    arrangeHoverNumbers("White", 10, 1, { r = 0, g = 0, b = 0 }, 1)
    local nsp = Global.getTable("non_start_points")
    check(math.abs(nums[3].pos.y - (2.2 + HOVER_LIFT)) < 1e-9, "the number on a marble's hole sits above that marble")
    check(math.abs(nums[2].pos.y - (nsp[12].position.y + HOVER_BASE_LIFT)) < 1e-9, "the others sit just above the board")
    check(nums[1].scale and nums[1].scale.x == HOVER_NUMBER_SCALE and HOVER_NUMBER_SCALE > 0.75, "the numbers are bigger than spawned (0.75)")
    -- each number turns toward the hovering player's seat (hand at 0, -90): one off to the side turns a little
    local base = 0
    local mid = hoverYaw("White", { x = 0, z = 0 }, base, nsp)
    local right = hoverYaw("White", { x = 20, z = 0 }, base, nsp)
    local d = ((right - base + 180) % 360) - 180
    check(math.abs(((mid - base + 180) % 360) - 180) < 3, "a number in the middle keeps the seat's angle")
    check(math.abs(d) > 5 and math.abs(d) < 30, string.format("a number off to the side turns toward the seat (%.1f degrees)", d))
    check(math.abs(((hoverYaw("White", { x = -20, z = 0 }, base, nsp) - base + 180) % 360) - 180 + d) < 1e-6, "... the other side the other way")
    Global.getTable, hideHoverNumbers, hoverPlaceMinus8 = gt, hide, m8
end

print("== hover numbers stay on the carried marble")
do
    local calls = { arrange = 0, hide = 0 }
    local saved = { arrangeHoverNumbers, hideHoverNumbers, Global.getTable, hoverSeatOf, Player }
    arrangeHoverNumbers = function() calls.arrange = calls.arrange + 1 end
    hideHoverNumbers = function() calls.hide = calls.hide + 1 end
    local gt = Global.getTable
    Global.getTable = function(k) if k == "hover_numbers_by_player" then return { White = {} } end return gt(k) end
    hoverSeatOf = function() return 1 end
    local holding = {}
    Player = setmetatable({}, { __index = function() return { getHoldingObjects = function() return holding end } end })
    local other = M.mbp.Green[1]
    holding = { M.mbp.White[1] }                               -- White is carrying a marble
    onObjectHover("White", other)
    onObjectHover("White", nil)
    check(calls.arrange == 0 and calls.hide == 0, "while carrying, hovering other marbles (or nothing) leaves the numbers alone")
    holding = {}
    onObjectHover("White", nil)
    check(calls.hide == 1, "with empty hands, hovering nothing hides the numbers")
    arrangeHoverNumbers, hideHoverNumbers, Global.getTable, hoverSeatOf, Player = saved[1], saved[2], saved[3], saved[4], saved[5]
end

print("== QoL: automatic reshuffle and Deal to 6")
do
    fresh(4, { White = true })
    RESHUFFLE_BUTTON_GUID = RESHUFFLE_BUTTON_GUID or "a18a04"
    M.deck_count = 20; M.reshuffled = 0
    autoReshuffleCheck()
    check(M.reshuffled == 0, "20 cards left: no reshuffle")
    M.deck_count = 3
    autoReshuffleCheck()
    check(M.reshuffled == 1, "3 cards left (4 players): reshuffle")
    autoReshuffleCheck()
    check(M.reshuffled == 1, "no second reshuffle while one is running")
    M.pumpFor(4)
    check(AUTO_RESHUFFLE_BUSY == false, "reshuffle finishes")
    M.deck_count = nil
    botOnGameStart({ num_players = 4 })
    M.pumpFor(10)
    -- a bot short of cards is topped up to 6
    local bot
    for c, _ in pairs(BOT_STATE.seats) do bot = c; break end
    check(bot ~= nil, "bots seated for the deal test")
    if bot then
        while #BOT_STATE.hands[bot] > 3 do table.remove(BOT_STATE.hands[bot]) end
        dealToSix()
        M.pumpFor(8)
        check(#BOT_STATE.hands[bot] == 6, "Deal to 6 tops a bot up to 6 (" .. #BOT_STATE.hands[bot] .. ")")
    end
end

print("== all-bot mode and the game log")
do
    fresh(4, { White = true })
    onChat("!allbots on", { color = "White", host = true })
    check(BOT_ALL_SEATS == true, "!allbots on switches all-bot mode on")
    local events = {}
    local origGlog = glog
    local badMismatch = 0
    glog = function(kind, data)
        events[#events + 1] = kind
        -- the mock doesn't fly bonked marbles home (TTS physics does), so only non-bonk moves must match exactly
        if kind == "mismatch" and not tostring(data.move):find("bonks") then badMismatch = badMismatch + 1 end
        return origGlog(kind, data)
    end
    botOnGameStart({ num_players = 4 }); M.pumpFor(10)
    local nb = 0
    for _ in pairs(BOT_STATE.seats) do nb = nb + 1 end
    check(nb == 4, "every seat is a bot, the seated human too (" .. nb .. ")")
    statsReset({ num_players = 4 })
    TURN_STATE.active = true; TURN_STATE.seat = 0
    turnBegin(1, true)
    M.pumpFor(240)
    local seen = {}
    for _, k in ipairs(events) do seen[k] = (seen[k] or 0) + 1 end
    for _, k in ipairs({ "game_start", "turn_start", "bot_move", "draw", "move_result" }) do
        check((seen[k] or 0) > 0, "log has '" .. k .. "' events (" .. tostring(seen[k]) .. ")")
    end
    check((seen.turn_start or 0) >= 8, "the bots keep playing on their own (" .. tostring(seen.turn_start) .. " turns)")
    check(badMismatch == 0 and (seen.error or 0) == 0, "no mismatches (moves without bonks) and no errors (" .. badMismatch .. ", " .. tostring(seen.error) .. ")")
    glog = origGlog
    onChat("!allbots off", { color = "White", host = true })
    check(BOT_ALL_SEATS == false, "!allbots off switches it off")
end

print("== distance travelled")
do
    local JB = JokerBot
    local function st(list) return JB.newState(4, list) end
    local S = st({ { seat = 1, kind = 'R', p = 15 } })
    check(statsTurnDistance({ "R:10" }, S) == 5, "a 5 forward counts 5")
    check(statsTurnDistance({ "R:23" }, S) == 8, "an 8 backwards counts 8")
    check(statsTurnDistance({ "R:15" }, S) == 0, "no move counts 0")
    check(statsTurnDistance({ "R:60" }, S) == 0, "a catapult (friendly bonk jump) doesn't count")
    local G = st({ { seat = 1, kind = 'G', p = 3 } })
    check(statsTurnDistance({ "R:" .. JB.entrance(1) - 2 }, G) == 5, "2 to the entrance + 3 into the finish counts 5")
    check(statsTurnDistance({ "G:1" }, G) == 2, "moving inside the finish counts")
    local B = st({ { seat = 1, kind = 'S', p = 0 } })
    check(statsTurnDistance({ "R:30" }, B) == 0, "being bonked doesn't count")
end

print("== fun superlatives")
do
    fresh(4, { White = true })
    local JB = JokerBot
    local ps = GAME_STATS.players.White
    -- seat 1 (White) catapulted 30 cells, seat 2's marble 20 past its exit sent back to start
    local S = JB.newState(4, { { seat = 1, kind = 'R', p = 40 }, { seat = 2, kind = 'S', p = 0 } })
    statsTurnExtras({ "R:10", "R:" .. ((JB.exitCell(2) + 20 - 1) % 72 + 1) }, S, ps)
    check(ps.freeRide == 30, "a catapult counts as a free ride for the marble's owner (" .. tostring(ps.freeRide) .. ")")
    check(ps.biggestBonk == 20, "the biggest bonk is the cells the bonked marble had travelled (" .. tostring(ps.biggestBonk) .. ")")
    local aw = statsAwards()
    local names = table.concat(aw.White, ",")
    check(names:find("Hitchhiker") and names:find("Heartbreaker"), "White gets Hitchhiker and Heartbreaker (" .. names .. ")")
end

print("== at most 2 awards shown per player, picked once")
do
    fresh(4, { White = true })
    local list = { "Sniper", "Most Hated", "Speed Demon", "Hitchhiker" }
    local a = statsPickAwards("White", list)
    local b = statsPickAwards("White", list)
    check(#a == 2 and table.concat(a, ",") == table.concat(b, ","), "2 awards picked, the same each time the screen opens")
    check(#statsPickAwards("Green", { "Sniper" }) == 1, "a single award is shown as is")
end

print("== 9. party mode: baked-in settings, hidden host chat commands")
fresh(4, { White = true })
BOT_THINK_TIME = 4.0
check(BOT_DIFFICULTY == 9 and botSpeed().name == "Normal" and BOT_DEBUG_SHOW_HANDS == false and BOT_DEV_UI == false,
      "defaults: level 9, Normal speed, hands hidden, no settings panel")
local host, guest = { color = "White", host = true }, { color = "Red", host = false }
local before = #M.chat
check(onChat("!level 7", host) == false and BOT_DIFFICULTY == 7, "!level 7 (host): hidden, sets level 7")
check(onChat("!think 2.5", host) == false and BOT_THINK_TIME == 2.5, "!think 2.5 (host)")
check(onChat("!speed fast", host) == false and botSpeed().name == "Fast", "!speed fast (host)")
check(onChat("!level 1", guest) ~= false and BOT_DIFFICULTY == 7, "a guest's !level does nothing and shows normally")
local leaked = 0
for i = before + 1, #M.chat do if not M.chat[i]:find("[host]", 1, true) then leaked = leaked + 1 end end
check(leaked == 0, "every reply went to the host only (" .. leaked .. " public lines)")
check(onChat("!bot", host) == false and M.chat[#M.chat]:find("!level", 1, true) ~= nil, "!bot lists the commands to the host")
onChat("!help", host)
do
    local missing = {}
    local alias = { bot = true, async = true, irlname = true }       -- old / second names
    for name in pairs(HOST_COMMANDS) do
        if not alias[name] and not M.chat[#M.chat]:find("!" .. name, 1, true) then missing[#missing + 1] = name end
    end
    check(#missing == 0, "!help lists every host command (missing: " .. table.concat(missing, ", ") .. ")")
end
check(onChat("!help", { color = "Orange" }) ~= false, "guests' !help is just chat")
BOT_STATE.active, BOT_STATE.seats = true, { Red = true, Green = true }
refreshGameUI()
check(UI.xml:find("botStatus", 1, true) ~= nil and not UI.xml:find("botDifficultyText", 1, true), "the bot panel has no settings controls")
onChat("!dev on", host)
check(UI.xml:find("botDifficultyText", 1, true) ~= nil and UI.xml:find("flagBtn", 1, true) ~= nil, "!dev on shows the settings + Flag panel")
onChat("!dev off", host)
check(not UI.xml:find("flagBtn", 1, true), "!dev off hides it again")


print("== !flag with a long note")
do
    fresh(4, { White = true })
    local host = { color = "White", host = true }
    local sent
    local orig = flagBadMove
    flagBadMove = function(p) sent = FLAG_NOTES[p.color] end
    local note = "haven' started playing with friends yet, curious if cyans joker was a force. " .. string.rep("more words ", 30)
    check(onChat("!flag " .. note .. "  ", host) == false, "a long !flag note is hidden")
    check(sent == note:gsub("%s+$", ""), "the note is passed on with its case kept")
    check(onChat("  !LEVEL   5 ", host) == false and BOT_DIFFICULTY == 5, "spacing and case are tolerated")
    check(onChat("!nope", host) ~= false, "an unknown !word is a normal chat line")
    flagBadMove = orig
end

print("== names follow the marble colour")
do
    fresh(4, { White = true })
    BOT_STATE.active, BOT_STATE.seats = true, { Orange = true }
    local function tint(color, c) for _, m in ipairs(Global.getTable("marbles_by_player")[color]) do m.setColorTint(c) end end
    tint("Orange", { r = 1, g = 1, b = 0 })                      -- the Orange seat's marbles turn yellow
    check(botName("Orange") == "BOT (Yellow)", "a bot is renamed when its marbles change colour (" .. botName("Orange") .. ")")
    tint("Green", { r = 1, g = 0, b = 1 })                       -- empty human seat with magenta marbles
    check(playerLabel("Green") == "Magenta", "an empty seat shows its marble colour, not the TTS seat name (" .. playerLabel("Green") .. ")")
    turnRefreshNames(); turnRefreshNames()
    check(TURN_RENAME_PENDING == true, "picker renames are batched")
    M.pump()
    check(TURN_RENAME_PENDING == false, "the batched rename ran")
    check(UI.xml:find("Yellow", 1, true) ~= nil, "the bot panel shows the new marble colour")
end

print("== colour picker: hue slider, colour square, see-through, effects")
do
    fresh(4, { White = true, Orange = true })
    BOT_STATE.seats = { Green = true }
    showColorPickers()
    check(UI.xml:find('id="pick_White" visibility="White"', 1, true) and UI.xml:find('id="pick_Orange" visibility="Orange"', 1, true),
          "each player gets their own picker")
    check(not UI.xml:find('id="pick_Green"', 1, true), "... bots don't")
    local _, cells = UI.xml:gsub('id="sv_White_', "")
    check(cells == PICK_COLS * PICK_ROWS and UI.xml:find('id="hue_White"', 1, true), "a colour square (" .. cells .. " squares) and a hue slider")
    local W = Global.getTable("marbles_by_player").White
    pickerHue({ color = "White" }, "120", "hue_White")
    M.pumpFor(0.2)
    check(UI.attrs and UI.attrs["sv_White_7_0"] and UI.attrs["sv_White_7_0"].color == "#00FF00", "moving the hue slider recolours the square (green)")
    check(W[1].tint.r ~= 0 or W[1].tint.g ~= 1, "... without changing the marbles yet")
    colorChosen({ color = "White" }, "-1", "sv_White_7_0")
    check(W[1].tint.g == 1 and W[1].tint.r == 0 and W[5].tint.g == 1, "clicking a square colours the marbles")
    check(marbleColorName("White") == "Green", "... and the name follows (" .. marbleColorName("White") .. ")")
    colorChosen({ color = "Orange" }, "-1", "sv_White_0_5")
    check(W[1].tint.g == 1, "someone else can't use your picker")
    colorChosen({ color = "White" }, "-1", "sv_White_0_5")
    local t = W[1].tint
    check(math.max(t.r, t.g, t.b) >= PICK_VAL_MIN - 0.01 and (math.max(t.r, t.g, t.b) - math.min(t.r, t.g, t.b)) > 0.05,
          "the square's darkest, greyest corner is still a usable colour")
    colorChosen({ color = "White" }, "-1", "nv_White_" .. (PICK_NEUTRALS - 1))
    check(W[1].tint.r == 0 and W[1].tint.g == 0 and W[1].tint.b == 0, "the neutral row has black")
    colorChosen({ color = "White" }, "-1", "nv_White_0")
    check(W[1].tint.r == 1 and W[1].tint.g == 1 and W[1].tint.b == 1, "... and white")
    colorChosen({ color = "White" }, "-1", "sv_White_" .. (PICK_COLS - 1) .. "_0")
    pickerSee({ color = "White" }, "-1", "pickSee_White")
    check(W[1].tint.a == PICK_TRANSLUCENT and PICK_TRANSLUCENT == 0.69, "See-through: 69% opaque")
    check(W[1].hl == true and W[5].hl == true and W[1].hlc.r == 0 and W[1].hlc.g == 0, "... with a black outline")
    W[1].highlightOn({ r = 1, g = 1, b = 0 }); marbleRestoreOutline(W[1])
    check(W[1].hl == true and W[1].hlc.g == 0, "the outline comes back after another highlight (easy play's glow)")
    pickerSee({ color = "White" }, "-1", "pickSolid_White")
    check(W[1].tint.a == 1 and W[1].hl == false, "Solid: no outline")
    check(not UI.xml:find("pickFx_White_rainbow", 1, true), "no Rainbow effect")
    pickerFx({ color = "White" }, "-1", "pickFx_White_twinkle")
    local seen = {}
    for _ = 1, 8 do M.pumpFor(0.3); seen[W[1].tint.g] = true end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    check(n > 1 and W[1].tint.r == 0, "Twinkle: the marble's brightness flickers")
    check(marbleColorName("White") == "Green", "... the name stays the picked colour")
    check(UI.xml:find('id="pickFx_White_twinkle" onClick="pickerFx" fontSize="16" color="#E8C547"', 1, true), "the chosen effect is lit")
    pickerFx({ color = "White" }, "-1", "pickFx_White_pulse")
    M.pumpFor(0.6)
    local v1 = W[1].tint.g
    M.pumpFor(0.5)
    check(v1 ~= W[1].tint.g and W[1].tint.r == 0, "Pulse: brightness changes, the hue doesn't")
    local enc = JSON.encode
    JSON.encode = function(t) return t end
    local saved = onSave()
    JSON.encode = enc
    check(saved.styles and saved.styles.White and saved.styles.White.fx == "pulse", "styles are saved with the game")
    pickerFx({ color = "White" }, "-1", "pickFx_White_plain")
    M.pumpFor(1)
    check(PICK_FX_RUNNING == false, "no effects left: the loop stops")
    showColorPickers()
    check(next(MARBLE_STYLE) == nil, "a new setup starts with no styles")
end

print("== seats change hands mid-game")
do
    local seated = { White = true }
    fresh(4, seated)
    BOT_STATE.active, BOT_STATE.seats = true, { Orange = true, Green = true, Purple = true }
    BOT_STATE.hands.Orange = { M.card("Ace of Spades"), M.card("5 of Hearts") }
    seated.Orange = true                                           -- a friend sits down in the Orange bot's seat
    onPlayerChangeColor("Orange")
    M.pump()
    check(not botIsBot("Orange") and #(BOT_STATE.hands.Orange or {}) == 0, "the bot hands the seat and its cards over")
    local said = false
    for _, l in ipairs(M.chat) do if l:find("took over", 1, true) then said = true end end
    check(said, "everyone is told who took over")

    BOT_STATE.hands.Green = { M.card("King of Spades") }
    BOT_STATE.current = { color = "Green", finished = false }      -- the Green bot is mid-move
    seated.Green = true
    onPlayerChangeColor("Green")
    M.pumpFor(2)
    check(botIsBot("Green"), "a bot mid-move finishes its move first")
    BOT_STATE.current.finished = true
    M.pump()
    check(not botIsBot("Green"), "... then hands the seat over")
    BOT_STATE.current = nil

    seated.Green = nil                                             -- the friend leaves again
    local host = { color = "White", host = true }
    check(onChat("!botseat", host) == false and M.chat[#M.chat]:find("Green", 1, true) ~= nil, "!botseat lists the empty seats by marble colour")
    onChat("!botseat green", host)
    M.pump()
    check(botIsBot("Green"), "!botseat green: a bot takes the empty seat")
    check(#BOT_STATE.hands.Green == 6, "... and draws up to 6 cards (" .. #BOT_STATE.hands.Green .. ")")
    onChat("!botseat white", host)
    check(not botIsBot("White") and M.chat[#M.chat]:find("Can't", 1, true) ~= nil, "a seat with someone in it is refused")
end

print("== whose turn: banner, END TURN button, splash")
do
    fresh(4, { White = true })
    BOT_STATE.active, BOT_STATE.seats = true, { Orange = true, Green = true, Purple = true }
    turnShowTurn("White", "Human-White's turn", nil, true)
    check(UI.xml:find('id="turnBanner"', 1, true) and UI.xml:find("Human-White's turn", 1, true), "the banner names whose turn it is")
    check(UI.xml:find('id="turnEndBtn" visibility="White"', 1, true) ~= nil, "END TURN is shown to the player whose turn it is only")
    check(UI.xml:find("YOUR TURN!", 1, true) ~= nil, "they get a YOUR TURN! splash")
    M.pumpFor(0.5)
    check(UI.shown == "turnSplash", "the splash pops up")
    M.pumpFor(2)
    check(UI.hidden == "turnSplash", "... and fades out")
    turnShowTurn("Orange", "BOT (Blue)'s turn", nil, false)
    check(not UI.xml:find("turnEndBtn", 1, true) and not UI.xml:find("YOUR TURN!", 1, true), "no END TURN button or YOUR TURN on a bot's turn")
    turnShowTurn(nil, "<b>&", nil, false)
    check(UI.xml:find("&lt;b&gt;&amp;", 1, true) ~= nil, "names are escaped in the UI xml")
    M.pump()
end

print("== moving marbles off-turn: blocked by default, !freemove toggles")
do
    local seated = { White = true, Orange = true }
    fresh(4, seated)
    BOT_STATE.active, BOT_STATE.seats = true, { Green = true, Purple = true }
    TURN_STATE.active, TURN_STATE.seat = true, 1                  -- White's turn
    local marble = Global.getTable("marbles_by_player").White[1]
    local guest = { color = "Orange", host = false }
    local host = { color = "White", host = true }
    check(onPlayerAction(guest, Player.Action.PickUp, { marble }) == false, "a guest can't pick up a marble on someone else's turn")
    check(M.broadcasts[#M.broadcasts]:find("Not your turn", 1, true) ~= nil, "... and is told why")
    check(onPlayerAction(guest, Player.Action.PickUp, { M.card("Ace of Spades") }) ~= false, "cards can still be picked up (sorting your hand)")
    check(onPlayerAction(guest, Player.Action.Select, { marble }) ~= false, "other actions are not blocked")
    TURN_STATE.seat = 2
    check(onPlayerAction(guest, Player.Action.PickUp, { marble }) ~= false, "on your own turn you can move marbles")
    TURN_STATE.seat = 3                                           -- a bot's turn
    check(onPlayerAction(host, Player.Action.PickUp, { marble }) ~= false, "the host can always move marbles (fixes)")
    check(onPlayerAction(guest, Player.Action.PickUp, { marble }) == false, "nobody else can during a bot's turn")
    check(onChat("!freemove on", host) == false and TURN_FREE_MOVE == true, "!freemove on (hidden command)")
    check(onPlayerAction(guest, Player.Action.PickUp, { marble }) ~= false, "free movement: anyone can move marbles")
    check(M.chat[#M.chat]:find("Free movement ON", 1, true) ~= nil and not M.chat[#M.chat]:find("[host]", 1, true), "everyone is told the rule changed")
    onChat("!freemove off", host)
    check(TURN_FREE_MOVE == false and onPlayerAction(guest, Player.Action.PickUp, { marble }) == false, "!freemove off blocks it again")
    TURN_STATE.active = false
    check(onPlayerAction(guest, Player.Action.PickUp, { marble }) ~= false, "before the game starts anything goes")
end

print("== time of play")
do
    fresh(4, { White = true })
    check(statsClock(3725) == "1:02:05" and statsClock(125) == "2:05" and statsClock(0) == "0:00", "clock format")
    GAME_STATS.started = os.time() - 3725
    statsTurnStart("White")
    GAME_STATS.turn_t0 = os.time() - 90                           -- a 90 s turn
    statsTurnEnd("White")
    local ps = GAME_STATS.players.White
    check(ps.time >= 90 and ps.time <= 91 and ps.turns == 1, "a turn's time is added to the player (" .. ps.time .. ")")
    statsOpen()
    check(UI.xml:find("time of play 1:02:0", 1, true) ~= nil, "the stats screen shows the time of play")
    check(UI.xml:find(">Time<", 1, true) and UI.xml:find(">1:3[01]<") , "... and each player's time on their turns")
    statsClose()
end

print("== host failsafes: !turn, !next, !pause, !resync")
do
    local seated = { White = true, Orange = true }
    fresh(4, seated)
    BOT_STATE.active, BOT_STATE.seats = true, { Green = true, Purple = true }
    for _, c in ipairs({ "Green", "Purple" }) do BOT_STATE.hands[c] = {} end
    TURN_STATE.active, TURN_STATE.seat, TURN_STATE.busy = true, 2, false        -- Orange's turn
    Turns.turn_color = "Orange"
    local host = { color = "White", host = true }
    check(turnSeatFromText("human-wh") == "White", "a seat by the start of a player's name")
    check(turnSeatFromText("purple") == "Purple", "a seat by its TTS colour when no marbles have that colour")
    check(onChat("!turn human-white", host) == false and TURN_STATE.seat == 1 and Turns.turn_color == "White", "!turn gives the turn to that seat")
    local told = false
    for _, l in ipairs(M.chat) do if l:find("gave the turn", 1, true) then told = true end end
    check(told, "everyone is told")
    local gen0 = TURN_STATE.gen
    onChat("!pause on", host)
    check(TURN_STATE.paused and TURN_STATE.gen == gen0 and TURN_STATE.seat == 1, "!pause on: the turn in progress carries on (not restarted)")
    onChat("!next", host)
    M.pump()
    check(TURN_STATE.paused and TURN_STATE.seat == 2 and not TURN_STATE.busy, "!next ends the turn, the game holds at the next seat while paused")
    check(M.chip.label:find("Paused", 1, true) ~= nil, "... and the Turn Button says Paused")
    onChat("!pause off", host)
    check(not TURN_STATE.paused and Turns.turn_color == "Orange", "!pause off starts that seat's turn")
    Turns.turn_color = "Green"                                                     -- TTS's turn drifted (reconnect)
    onChat("!resync", host)
    check(Turns.turn_color == "Orange" and Turns.disable_interactations == false, "!resync lines TTS's turn back up with the Turn Button")
    M.pump()
    onPlayerConnect({ color = "Orange" })
    Turns.turn_color = "Green"
    M.pumpFor(5)
    check(Turns.turn_color == "Orange", "a reconnect re-syncs by itself")
end

print("== !give <card> (host, for testing)")
do
    fresh(4, { White = true, Orange = true })
    local host = { color = "White", host = true }
    check(giveToken("A") == "a" and giveToken("ace") == "a" and giveToken("7") == "7" and giveToken("10") == "10"
          and giveToken("K") == "k" and giveToken("joker") == "$" and giveToken("11") == nil and giveToken("zz") == nil,
          "card names: a / A / ace, 2-10, j q k, joker")
    local before = #getAllObjects()
    check(onChat("!give A", host) == false, "!give is hidden from chat")
    local got
    for _, o in ipairs(getAllObjects()) do if o.tag == "Card" and o.pos.z == -90 then got = o end end
    check(got and botCardToken(got.getName()) == "a", "an Ace lands in the host's hand (" .. tostring(got and got.getName()) .. ")")
    check(M.chat[#M.chat]:find("Gave you the", 1, true) ~= nil, "the host is told which card (" .. tostring(M.chat[#M.chat]) .. ")")
    onChat("!give joker", host)
    local j
    for _, o in ipairs(getAllObjects()) do if o.tag == "Card" and o.pos.z == -90 and o.getName() == "Joker" then j = o end end
    check(j ~= nil, "!give joker")
    onChat("!give 13", host)
    check(M.chat[#M.chat]:find("!give <card>", 1, true) ~= nil, "a bad card name shows the usage")
    check(onChat("!give a", { color = "Orange" }) ~= false, "guests can't use it")
end

print("== easy play: click a glowing marble")
do
    local JB = JokerBot
    local function put(color, k, kind, p, seat) M.place(color, k, JB.cellToIndex(kind, p, seat)) end
    local function cell(m, seat) return botClassify(m, seat, Global.getTable("non_start_points")) end
    local function startTurn(seat)
        fresh(4, { White = true, Orange = true, Green = true, Purple = true })
        BOT_STATE.active = false
        TURN_STATE.active, TURN_STATE.seat, TURN_STATE.busy = true, seat, false
        EASY_TEST_GEN = (EASY_TEST_GEN or 0) + 1000
        TURN_STATE.gen = EASY_TEST_GEN                -- like turnBegin: timers left from an earlier test see a new turn
        statsTurnStart(PLAYER_COLORS[4][seat])
    end
    local W = function() return Global.getTable("marbles_by_player").White end
    local white = { color = "White" }
    local function markers()
        local n, spots = 0, 0
        for _, o in ipairs(getAllObjects()) do
            local e = EASY.markers[o.getGUID()]
            if e then n = n + 1; if e.v:sub(1, 1) == "c" then spots = spots + 1 end end
        end
        return n, spots
    end
    local function markerFor(v)
        for _, o in ipairs(getAllObjects()) do
            local e = EASY.markers[o.getGUID()]
            if e and e.v == v then return o end
        end
    end
    local function spot(kind, p, seat) return "c" .. JB.cellToIndex(kind, p, seat) end
    local function ended()
        for _, l in ipairs(M.chat) do if l:find("ended their turn", 1, true) then return true end end
        return false
    end

    -- toggle
    startTurn(1)
    turnShowTurn("White", "Human-White's turn", nil, true)
    check(UI.xml:find('id="turnEndBtn"', 1, true) ~= nil, "(the on-screen END TURN button is there)")
    easyToggle(white)
    check(EASY.on.White == true and UI.xml:find('id="easyToggle_White" visibility="White"', 1, true) ~= nil, "each player has their own Easy play toggle")
    check(UI.xml:find("Easy play: ON", 1, true) ~= nil, "the toggle shows ON")
    check(not UI.xml:find('id="turnEndBtn"', 1, true), "with easy play on, the on-screen END TURN button is hidden")
    check(EASY.on.Orange == nil, "... it's only on for that player")

    -- only one possible move: it plays by itself
    put("White", 1, 'R', 10, 1)
    play("White", "5 of Hearts")
    M.pump(5000)
    check(select(2, cell(W()[1], 1)) == 15 and ended(), "only one possible move: it plays by itself and the turn ends")

    -- a 5 with two marbles out: the marbles glow, a click moves one, then the turn ends by itself
    startTurn(1)
    EASY.on.White = true
    turnShowTurn("White", "Human-White's turn", nil, true)
    put("White", 1, 'R', 10, 1)
    put("White", 2, 'R', 30, 1)
    play("White", "5 of Hearts")
    M.pumpFor(0.1)
    local s = EASY.session
    check(s and s.next and s.next.m1, "after playing a 5 the ring marble is a choice")
    check(W()[1].hl == true and #(M.lines or {}) == 2 and markers() == 0, "they glow, with a ring around each (no click target needed)")
    check(M.lines[1].color[4] and M.lines[1].color[4] < 1, "... the ring is see-through")
    check(UI.xml:find('offsetXY="0 40"', 1, true) ~= nil, "the prompt sits lower on the screen")
    M.pumpFor(EASY_PULSE + 0.05)
    check(W()[1].hl == true and W()[1].tint ~= nil, "... pulsing")
    check(onPlayerAction(white, Player.Action.PickUp, { W()[3] }) == false, "a marble that can't move isn't picked up")
    check(onPlayerAction(white, Player.Action.PickUp, { W()[1] }) == false, "clicking the glowing marble doesn't pick it up")
    check(markers() == 0 and #(M.lines or {}) == 0, "the rings go away once it moves")
    M.pump(5000)
    local k, p = cell(W()[1], 1)
    check(k == 'R' and p == 15, "... it moves 5 (" .. tostring(k) .. tostring(p) .. ")")
    check(EASY.session == nil and ended(), "... and the turn ends by itself")

    -- a card that can go to two places: the spots glow
    startTurn(1)
    EASY.on.White = true
    local ent = JB.entrance(1)
    put("White", 1, 'R', ent - 2, 1)
    play("White", "5 of Hearts")
    M.pumpFor(0.1)
    onPlayerAction(white, Player.Action.PickUp, { W()[1] })
    local _, spots = markers()
    check(EASY.session and spots == 2, "a 5 that can enter the finish or run past: both spots glow (" .. spots .. ")")
    local past = markerFor(spot('R', ent + 3, 1))
    check(past ~= nil and past.locked and past.buttons and past.buttons[1].click_function == "easySpotClicked"
          and past.buttons[1].color[4] == 0, "(the run-past spot: a transparent button on a locked block)")
    check(past.pos.y < Global.getTable("non_start_points")[1].position.y - 1, "... the block is sunk out of sight")
    check(past.pos.y + past.buttons[1].position[2] > Global.getTable("non_start_points")[1].position.y,
          "... the button lies above the board (the holes' tops are just under a marble's centre)")
    check(onPlayerAction({ color = "Orange" }, Player.Action.PickUp, { past }) == false, "nobody can pick up the block")
    easySpotClicked(past, "Orange")
    check(EASY.session and #EASY.session.picks == 1, "someone else clicking it does nothing")
    if past then easySpotClicked(past, "White") end
    M.pump(5000)
    local k5, p5 = cell(W()[1], 1)
    check(k5 == 'R' and p5 == ent + 3, "clicking a spot moves it there (" .. tostring(k5) .. tostring(p5) .. ")")

    -- leftovers from an earlier version are cleared when a card is played
    startTurn(1)
    local stray = M.newObj({ pos = { x = 1, y = 3, z = 1 }, tag = "Block", name = "Easy play: click" })
    EASY.on.White = true
    put("White", 1, 'R', 10, 1)
    play("White", "5 of Hearts")
    M.pumpFor(0.1)
    check(stray.destroyed == true, "leftover markers are removed")
    easyCancel()

    -- click a card in the hand to play it; a drag doesn't
    startTurn(1)
    EASY.on.White = true
    clickToggle(white)
    check(EASY.click.White == true and UI.xml:find('id="clickToggle_White" visibility="White"', 1, true)
          and UI.xml:find("Click to play: ON", 1, true), "Click to play has its own toggle")
    put("White", 1, 'R', 10, 1)
    put("White", 2, 'R', 30, 1)                               -- two choices, so nothing plays by itself
    local h5, h3 = M.card("5 of Hearts", "White"), M.card("3 of Hearts", "White")
    h5.pos = { x = 0, y = 3, z = -90 }; h3.pos = { x = 2, y = 3, z = -90 }
    M.hands.White = { h5, h3 }
    onPlayerAction(white, Player.Action.PickUp, { h3 })
    h3.pos = { x = 6, y = 3, z = -90 }                        -- dragged along the hand
    onObjectDrop("White", h3)
    M.pumpFor(1.5)
    check(EASY.session == nil and h3.pos.z == -90, "dragging a card in the hand only rearranges it")
    onPlayerAction(white, Player.Action.PickUp, { h5 })
    M.pumpFor(1.0)                                            -- held while thinking
    onObjectDrop("White", h5)
    M.pumpFor(1.5)
    check(EASY.session == nil and h5.pos.z == -90 and not GAME_STATS.card_played, "click and hold: the card isn't played")
    onPlayerAction(white, Player.Action.PickUp, { h5 })
    h5.pos = { x = 0.2, y = 3, z = -90 }                      -- a click: let go where it was
    onObjectDrop("White", h5)
    M.pumpFor(1.5)
    check(EASY.session and EASY.session.card == "5", "clicking a card in the hand plays it onto the zone")
    check((h5.moves or 0) == 0 and h5.locked == false, "... it flew there step by step and was let go on the zone")
    local sp0 = BOT_STATE.speed_index
    local times = {}
    for i, sp in ipairs(BOT_SPEEDS) do BOT_STATE.speed_index = i; times[sp.name] = easyFlightTime() end
    BOT_STATE.speed_index = sp0
    check(times.Slow == 1.5 and times.Normal == 1 and times.Fast == 0.5 and times.Instant == 0,
          "the card's flight follows the bot speed: slow 1.5 s, normal 1 s, fast 0.5 s, instant")
    check(GAME_STATS.card_played == true, "... it counts as played")
    -- it bounced off the zone after landing (user, 11-17): put back on it
    local zone = Global.getTable("discard_piles").White
    local zp = zone.getPosition()
    M.hands.White = { h3 }                                    -- (it left the hand)
    h5.pos = { x = zp.x + 4, y = zp.y, z = zp.z + 1 }
    M.pumpFor(3)
    check(isNear(h5.pos.x, h5.pos.z, zp.x, zp.z, 0.5), "a clicked card that bounces off the zone is put back on it")
    h5.pos = { x = 0, y = 3, z = -90 }                        -- jumped back into the hand, nobody picked it up
    M.hands.White = { h5, h3 }
    M.pumpFor(5)
    check(isNear(h5.pos.x, h5.pos.z, zp.x, zp.z, 0.5), "... even when it jumps back into the hand on its own (a player who isn't the host)")
    M.hands.White = { h3 }
    onPlayerAction(white, Player.Action.PickUp, { h3 })
    onObjectDrop("White", h3)
    M.pumpFor(1.5)
    check(EASY.session.card == "5" and h3.pos.z == -90, "a second click doesn't play another card")
    easyCancel()
    -- TTS only reports the pick-up afterwards, and the held card isn't in the hand list any more
    startTurn(1)
    EASY.on.White = true
    put("White", 1, 'R', 10, 1)
    put("White", 2, 'R', 30, 1)                               -- two choices, so nothing plays by itself
    local h4 = M.card("4 of Hearts", "White")
    h4.pos = { x = 1, y = 3, z = -90 }
    M.hands.White = {}
    onObjectPickedUp("White", h4)
    onObjectDrop("White", h4)
    M.pumpFor(1.5)
    check(EASY.session and EASY.session.card == "4", "click-to-play also works from onObjectPickedUp + the hand area")
    onObjectPickedUp("White", h4)                              -- taken back into the hand right after it landed
    h4.pos = { x = 1, y = 3, z = -90 }
    onObjectDrop("White", h4)
    M.pumpFor(3)
    check(h4.pos.z == -90, "a clicked card taken back into the hand stays there")
    easyCancel()
    -- independent of easy play: on without it (the card is played, no glowing), off with it
    EASY.on.White = false
    startTurn(1)
    put("White", 1, 'R', 10, 1)
    local h6 = M.card("6 of Hearts", "White")
    h6.pos = { x = 0, y = 3, z = -90 }
    M.hands.White = { h6 }
    onPlayerAction(white, Player.Action.PickUp, { h6 })
    onObjectDrop("White", h6)
    M.pumpFor(1.5)
    check(GAME_STATS.card_played == true and EASY.session == nil and select(2, cell(W()[1], 1)) == 10,
          "Click to play works with easy play off (the card is played, you move by hand)")
    EASY.on.White, EASY.click.White = true, false
    startTurn(1)
    M.hands.White = { h5 }
    h5.pos = { x = 0, y = 3, z = -90 }
    onPlayerAction(white, Player.Action.PickUp, { h5 })
    onObjectDrop("White", h5)
    M.pumpFor(1.5)
    check(h5.pos.z == -90, "Click to play off: clicking a card does nothing, even with easy play on")
    EASY.on.White = false

    -- the card is taken back: no glow, not counted; another card starts over
    startTurn(1)
    EASY.on.White = true
    put("White", 1, 'R', 10, 1)
    put("White", 2, 'R', 30, 1)
    local c5 = play("White", "5 of Hearts")
    M.pumpFor(0.1)
    local col5
    for i, t in ipairs(STATS_CARDS) do if t == "5" then col5 = i end end
    check(GAME_STATS.players.White.cards[col5] == 1, "the 5 counts once played")
    onObjectPickedUp("White", c5)
    c5.pos = { x = 0, y = 3, z = -90 }                          -- back in the hand
    onObjectLeaveScriptingZone(M.zones.White, c5)
    M.pumpFor(0.4)
    check(EASY.session == nil and W()[1].hl == false and #(M.lines or {}) == 0, "taking the card back stops the glow")
    check(GAME_STATS.players.White.cards[col5] == 0 and GAME_STATS.card_played == false, "... and it no longer counts")
    play("White", "3 of Hearts")
    M.pumpFor(0.1)
    check(EASY.session and EASY.session.card == "3", "playing another card starts over with that card")
    easyCancel()

    -- Joker: any marble in the start, then the marble to land on
    startTurn(1)
    EASY.on.White = true
    put("White", 1, 'R', 10, 1)
    put("Orange", 1, 'R', 40, 1)
    put("Orange", 2, 'R', 50, 1)                               -- two targets to choose from
    play("White", "Joker")
    M.pumpFor(0.1)
    check(EASY.session.next.m1 and EASY.session.next.S1, "Joker: the ring marble and the start marbles can move")
    check(W()[2].hl and W()[3].hl and W()[5].hl, "... every marble in the start glows")
    onPlayerAction(white, Player.Action.PickUp, { W()[4] })     -- not the first start marble
    local orange = Global.getTable("marbles_by_player").Orange[1]
    check(EASY.session and EASY.session.next and EASY.session.next.m6, "then Orange's marble glows as the target")
    check(orange.hl == true, "... it glows")
    onPlayerAction(white, Player.Action.PickUp, { orange })
    M.pump(5000)
    local k2, p2 = cell(W()[4], 1)
    check(k2 == 'R' and p2 == 40, "the clicked start marble jumps onto it (" .. tostring(k2) .. tostring(p2) .. ")")
    check(cell(W()[2], 1) == 'S', "... the other start marbles stay")
    check(cell(orange, 2) == 'S', "... and Orange goes back to start")

    -- 7: first marble, its spot, second marble, its spot
    startTurn(1)
    EASY.on.White = true
    put("White", 1, 'R', 10, 1)
    put("Green", 1, 'R', 30, 3)
    put("Green", 2, 'R', 45, 3)                                -- two teammate marbles: a choice after part 1
    local green = Global.getTable("marbles_by_player").Green[1]
    play("White", "7 of Hearts")
    M.pumpFor(0.1)
    check(EASY.session.next.m1 and EASY.session.next.m11, "7: either your marble or your teammate's can go first")
    onPlayerAction(white, Player.Action.PickUp, { W()[1] })
    local n7, s7 = markers()
    check(s7 >= 2 and n7 == s7, "after the first marble, the spots it can reach glow (" .. s7 .. ")")
    easySpotClicked(markerFor(spot('R', 12, 1)), "White")
    M.pump(5000)
    check(select(2, cell(W()[1], 1)) == 12, "the first part plays as soon as its spot is clicked")
    check(EASY.session.next and EASY.session.next.m11 and not EASY.session.next.m1, "then the teammate's marble glows")
    onPlayerAction(white, Player.Action.PickUp, { green })
    M.pump(5000)
    check(select(2, cell(W()[1], 1)) == 12 and select(2, cell(green, 3)) == 35, "its only spot is picked for you: the 7 is played, +2 and +5")
    check(ended(), "... and the turn ends by itself")
    -- a spot with a marble on it: clicking that marble picks the spot
    startTurn(1)
    EASY.on.White = true
    put("White", 1, 'R', 10, 1)
    put("Green", 1, 'R', 30, 3)
    put("Green", 2, 'R', 45, 3)                                -- two teammate marbles: a choice after part 1
    put("Orange", 1, 'R', 12, 2)
    play("White", "7 of Hearts")
    M.pumpFor(0.1)
    onPlayerAction(white, Player.Action.PickUp, { W()[1] })
    local orange7 = Global.getTable("marbles_by_player").Orange[1]
    check(markerFor(spot('R', 12, 1)) == nil, "(no click target under a marble)")
    orange7.pos.y = 2.3                                          -- resting a bit higher than the hole's point
    easyNextStep()
    local ringed = false
    for _, l in ipairs(M.lines or {}) do
        local pt = l.points[1]
        if math.abs(pt[3] - orange7.pos.z) < 1 and math.abs(pt[2] - (2.3 + EASY_RING_LIFT)) < 0.01 then ringed = true end
    end
    check(ringed, "a glowing spot with a marble on it is ringed at that marble's height")
    onPlayerAction(white, Player.Action.PickUp, { orange7 })
    check(EASY.session and EASY.session.picks[2] == spot('R', 12, 1), "clicking the marble on a glowing spot picks that spot")
    M.pump(5000)
    check(select(2, cell(W()[1], 1)) == 12 and cell(orange7, 2) == 'S', "... part 1 plays: Orange is bonked home before the second pick")
    check(EASY.session and EASY.session.next and EASY.session.next.m11, "... then the teammate's marble glows")
    easyCancel()
    -- the teammate's part first
    startTurn(1)
    EASY.on.White = true
    put("White", 1, 'R', 10, 1)
    put("Green", 1, 'R', 30, 3)
    green = Global.getTable("marbles_by_player").Green[1]
    play("White", "7 of Hearts")
    M.pumpFor(0.1)
    onPlayerAction(white, Player.Action.PickUp, { green })
    easySpotClicked(markerFor(spot('R', 31, 3)), "White")
    M.pump(5000)
    check(select(2, cell(W()[1], 1)) == 16 and select(2, cell(green, 3)) == 31, "... +1 and +6")

    -- the winning move: a 5 that can enter the finish (and win) or run past it plays the win by itself
    startTurn(1)
    EASY.on.White = true
    local entW = JB.entrance(1)
    for k = 1, 4 do put("White", k + 1, 'G', k + 1, 1) end        -- White: 4 home, at the back of the finish
    for k = 1, 5 do put("Green", k, 'G', k, 3) end                -- teammate Green: all 5 home
    put("White", 1, 'R', ((entW - 5) % 72) + 1, 1)               -- last marble 4 before its entrance: a 5 lands on G1 (or runs past)
    play("White", "5 of Hearts")
    M.pump(5000)
    check(cell(W()[1], 1) == 'G', "the game-winning move plays by itself (no run-past option)")

    -- a card with no legal move: burned, the turn ends by itself (unless the card is taken back)
    startTurn(1)
    EASY.on.White = true
    local cb = play("White", "5 of Hearts")
    M.pumpFor(0.1)
    check(EASY.session == nil and M.broadcasts[#M.broadcasts]:find("burned", 1, true) ~= nil, "no legal move: told it's a burn")
    M.pumpFor(EASY_BURN_WAIT + 0.1)
    M.pump(5000)
    check(ended() and EASY_BURN_WAIT <= 0.5, "a burn ends the turn by itself, straight away")
    -- off by default, and only on your own turn
    startTurn(2)
    put("White", 1, 'R', 10, 1)
    EASY.on.White = true
    play("White", "5 of Hearts")
    M.pumpFor(0.1)
    check(EASY.session == nil, "not on someone else's turn")
    EASY.on = {}
end

print("== a bot short of cards is dealt back up to 6")
do
    fresh(4, { White = true, Orange = true })
    BOT_STATE.active, BOT_STATE.seats = true, { Green = true, Purple = true }
    for _, c in ipairs({ "Green", "Purple" }) do
        BOT_STATE.hands[c] = {}
        for _, n in ipairs({ "5 of Hearts", "6 of Hearts", "9 of Clubs", "10 of Clubs", "2 of Spades", "3 of Spades" }) do
            table.insert(BOT_STATE.hands[c], M.card(n))
        end
    end
    table.remove(BOT_STATE.hands.Green); table.remove(BOT_STATE.hands.Green)      -- Green is down to 4
    TURN_STATE.active = true
    turnBegin(1)                                                   -- White's turn
    M.pumpFor(3)
    check(#BOT_STATE.hands.Green == 6 and #BOT_STATE.hands.Purple == 6, "at the next turn start the bot draws back to 6 (" .. #BOT_STATE.hands.Green .. ")")
    table.remove(BOT_STATE.hands.Purple)
    turnBegin(4)                                                   -- Purple's own turn: topped up before it plays
    check(BOT_STATE.topping.Purple == true or #BOT_STATE.hands.Purple == 6, "(Purple is topping up)")
    M.pump(20000)
    check(#BOT_STATE.hands.Purple == 6, "a bot short at its own turn plays, then still ends on 6 (" .. #BOT_STATE.hands.Purple .. ")")
end

print("== in-person seats (!async)")
do
    local JB = JokerBot
    local function put(color, k, kind, p, seat) M.place(color, k, JB.cellToIndex(kind, p, seat)) end
    local function cell(m, seat) return botClassify(m, seat, Global.getTable("non_start_points")) end
    fresh(4, { White = true })
    local host = { color = "White", host = true }
    onChat("!hybrid on", host)
    check(IRL.mode == true and M.chat[#M.chat]:find("Hybrid mode ON", 1, true) ~= nil, "!hybrid on")
    onChat("!hybridname " .. marbleColorName("Green") .. " Pat", host)
    botOnGameStart({ num_players = 4 })
    check(irlIsSeat("Orange") and irlIsSeat("Green") and irlIsSeat("Purple") and not irlIsSeat("White"), "empty seats are played in person")
    check(not BOT_STATE.active and next(BOT_STATE.seats) == nil, "... no bots")
    check(playerLabel("Green") == "Pat (in person)" and playerLabel("Orange"):find("(in person)", 1, true), "named: " .. playerLabel("Green"))
    local O = Global.getTable("marbles_by_player").Orange
    put("Orange", 1, 'R', 30, 2)
    TURN_STATE.active = true
    local dealt = M.dealt or 0
    turnBegin(2)                                                    -- Orange: in person
    check(TURN_STATE.seat == 2 and not TURN_STATE.busy, "their turn waits for the host")
    check(UI.xml:find('id="irlBar" visibility="Host"', 1, true) and UI.xml:find('id="irlCard_joker"', 1, true), "the host gets the card bar")
    check(UI.xml:find('id="turnEndBtn" visibility="Host"', 1, true) ~= nil, "... and END TURN")
    irlPick({ color = "Orange" }, nil, "irlCard_5")
    check(EASY.session == nil and not GAME_STATS.card_played, "only the host can pick")
    -- one possible move: it plays, the turn ends, nobody draws
    irlPick(host, nil, "irlCard_5")
    local col5
    for i, t in ipairs(STATS_CARDS) do if t == "5" then col5 = i end end
    check(GAME_STATS.players.Orange.cards[col5] == 1, "the picked card counts in their stats")
    M.pump(5000)
    check(select(2, cell(O[1], 2)) == 35, "the move is played")
    check(TURN_STATE.seat == 3 and (M.dealt or 0) == dealt, "the turn moves on and no card is dealt to them")
    -- two choices: the host clicks; picking another card first replaces the pick
    put("Green", 1, 'R', 40, 3)
    put("Green", 2, 'R', 50, 3)
    local G = Global.getTable("marbles_by_player").Green
    check(TURN_STATE.seat == 3, "(Pat's turn)")
    irlPick(host, nil, "irlCard_5")
    irlPick(host, nil, "irlCard_3")
    check(GAME_STATS.players.Green.cards[col5] == 0, "a re-pick: the first card no longer counts")
    check(EASY.session and EASY.session.card == "3" and EASY.session.ctrl == "White", "easy play runs for their seat, the host clicking")
    check(UI.xml:find('id="easyPrompt" visibility="White"', 1, true) ~= nil, "... the prompt is the host's")
    check(onPlayerAction({ color = "Green" }, Player.Action.PickUp, { G[1] }) ~= false or EASY.session.picks[1] == nil, "(nobody else picks)")
    onPlayerAction(host, Player.Action.PickUp, { G[2] })
    M.pump(5000)
    check(select(2, cell(G[2], 3)) == 53 and TURN_STATE.seat == 4, "the host's click plays their move and the turn moves on")
    -- !botseat hands an in-person seat to a bot
    local ok = botSeatFromHuman("Purple")
    check(ok and BOT_STATE.seats.Purple and not irlIsSeat("Purple"), "!botseat: a bot takes an in-person seat")
    M.pump(20000)
    -- seats by number (the host is 0, then clockwise = turn order) and by in-person name
    check(botSeatFromName("0") == "White" and botSeatFromName("2") == "Green" and botSeatFromName("3") == "Purple", "seat numbers: host 0, then clockwise")
    check(botSeatFromName("pat") == "Green", "a seat by its in-person name")
    -- the stats screen uses the in-person names
    statsOpen()
    check(UI.xml:find(">Pat<", 1, true) ~= nil, "the stats screen shows the in-person name")
    statsClose()
    -- !hybridseat: a bot's seat is played in person from now on (its cards go back to the deck)
    check(BOT_STATE.seats.Purple and #BOT_STATE.hands.Purple == 6, "(Purple is a bot with 6 cards)")
    local purpleCards = BOT_STATE.hands.Purple
    onChat("!hybridseat 3", host)
    check(irlIsSeat("Purple") and not BOT_STATE.seats.Purple, "!hybridseat 3: the bot's seat is played in person")
    check(purpleCards[1].pos.x == M.deck.pos.x and purpleCards[1].pos.z == M.deck.pos.z, "... its cards go back onto the deck")
    check(M.chat[#M.chat]:find("played in person", 1, true) ~= nil, "... everyone is told")
    onChat("!hybridseat pat", host)
    check(M.chat[#M.chat]:find("already played in person", 1, true) ~= nil, "a seat that's already in person: told so")
    onChat("!hybridseat 3 Kim", host)
    check(IRL.names.Purple == "Kim" and playerLabel("Purple") == "Kim (in person)", "!hybridseat <seat> <name> names it (capitals kept): " .. playerLabel("Purple"))
    onChat("!botseat pat", host)
    check(BOT_STATE.seats.Green and not irlIsSeat("Green"), "!botseat works with an in-person name")
    M.pump(20000)
    onChat("!async off", host)
    check(IRL.mode == false, "the old !async still works")
    IRL.seats = {}

    -- the host colours and names the in-person seats in their own picker
    fresh(4, { White = true, Orange = true })
    IRL.mode, IRL.names = true, {}
    showColorPickers()
    check(UI.xml:find('id="pickTo_White_Green"', 1, true) and UI.xml:find('id="pickTo_White_Purple"', 1, true), "the host's picker has a tab per in-person seat")
    check(not UI.xml:find('id="pickTo_White_Orange"', 1, true), "... not for a seated player")
    check(not UI.xml:find('id="pickTo_Orange_', 1, true), "other players only colour their own")
    pickerTarget(host, "-1", "pickTo_White_Green")
    check(UI.xml:find('id="pickName_White"', 1, true) ~= nil, "a name box for that seat")
    local Gm = Global.getTable("marbles_by_player").Green
    local Wm = Global.getTable("marbles_by_player").White
    local wBefore = Wm[1].tint.r
    pickerHue(host, "300", "hue_White")
    M.pumpFor(0.2)
    colorChosen(host, "-1", "sv_White_7_0")
    check(Gm[1].tint.r == 1 and Gm[1].tint.b == 1 and Gm[1].tint.g == 0 and Wm[1].tint.r == wBefore, "colouring that seat: its marbles turn magenta, the host's don't")
    pickerFx(host, "-1", "pickFx_White_pulse")
    check(MARBLE_STYLE.Green.fx == "pulse" and not (MARBLE_STYLE.White and MARBLE_STYLE.White.fx == "pulse"), "effects too")
    pickerName(host, "  Pat ", "pickName_White")
    check(IRL.names.Green == "Pat", "the name box names it")
    pickerName({ color = "Orange" }, "Hacker", "pickName_White")
    check(IRL.names.Green == "Pat", "nobody else can")
    botOnGameStart({ num_players = 4 })
    check(playerLabel("Green") == "Pat (in person)", "in the game: " .. playerLabel("Green"))
    pickerTarget(host, "-1", "pickTo_White_White")
    colorChosen(host, "-1", "sv_White_0_0")
    check(Wm[1].tint.r ~= wBefore or Wm[1].tint.g ~= 0, "the You tab colours the host's own marbles again")
    IRL.mode, IRL.seats, IRL.names = false, {}, {}
end

print("== undo")
do
    local JB = JokerBot
    local function put(color, k, kind, p, seat) M.place(color, k, JB.cellToIndex(kind, p, seat)) end
    local function cell(m, seat) return botClassify(m, seat, Global.getTable("non_start_points")) end
    fresh(4, { White = true, Orange = true })
    BOT_STATE.active, BOT_STATE.seats = true, { Green = true, Purple = true }
    for _, c in ipairs({ "Green", "Purple" }) do
        BOT_STATE.hands[c] = {}
        for _, n in ipairs({ "5 of Hearts", "6 of Hearts", "9 of Clubs", "10 of Clubs", "2 of Spades", "3 of Spades" }) do
            local card = M.card(n); table.insert(BOT_STATE.hands[c], card)
        end
    end
    local a1, a2 = M.card("5 of Clubs", "White"), M.card("King of Clubs", "White")
    M.hands.White = { a1, a2 }
    put("White", 1, 'R', 10, 1)
    TURN_STATE.active = true
    turnBegin(1)                                                  -- White's turn: snapshot
    check(#UNDO.stack == 1, "a snapshot at the start of the turn")
    check(UI.xml:find('id="undoBtn"', 1, true) and not UI.xml:find('id="statsBtn"', 1, true), "the panel has Undo instead of Stats during the game")

    -- White plays the 5 and moves, then presses Undo before ending the turn
    M.hands.White = { a2 }
    a1.setPosition(M.discard.White.pos)                         -- played
    local W1 = Global.getTable("marbles_by_player").White[1]
    put("White", 1, 'R', 15, 1)
    check(GAME_STATS.players.White.cards[5] == 1, "the 5 counted")
    undoClicked({ color = "Orange" })
    check(select(2, cell(W1, 1)) == 15 and M.broadcasts[#M.broadcasts]:find("Only the host", 1, true) ~= nil, "only the host can undo")
    check(UI.xml:find('id="undoBtn" visibility="Host"', 1, true) ~= nil, "... the Undo button is only shown to the host")
    check(UI.xml:find('id="pauseBtn"', 1, true) ~= nil, "everyone has a Pause button")
    undoClicked({ color = "White" })
    M.pumpFor(2)
    local k, p = cell(W1, 1)
    check(k == 'R' and p == 10, "Undo puts the marble back (" .. tostring(k) .. tostring(p) .. ")")
    check(a1.pos.z == -90, "... the card goes back into White's hand")
    check(GAME_STATS.players.White.cards[5] == 0, "... and the stats go back")
    check(TURN_STATE.seat == 1 and not TURN_STATE.paused, "it is still White's turn")
    check(#UNDO.stack == 1, "one snapshot again (the turn started over)")
    local told = false
    for _, l in ipairs(M.chat) do if l:find("pressed Undo", 1, true) then told = true end end
    check(told, "everyone is told")

    -- nothing has happened this turn: Undo goes to the turn before (a bot's), which then pauses there
    turnBegin(3)                                                  -- pretend White ended: Green and Purple (bots) play
    M.pump(20000)
    check(TURN_STATE.seat == 1 and #UNDO.stack >= 3, "each turn adds a snapshot (back to White: " .. TURN_STATE.seat .. ")")
    local snapP
    for _, sn in ipairs(UNDO.stack) do if sn.seat == 4 then snapP = sn end end
    local shuffles = M.shuffles or 0
    undoClicked({ color = "White" })
    M.pumpFor(2)
    check(TURN_STATE.seat == 4 and TURN_STATE.paused, "Undo goes back to Purple's (bot) turn and pauses there")
    local want = {}
    for _, g in ipairs(snapP.hands.Purple) do want[g] = true end
    local same = #BOT_STATE.hands.Purple == #snapP.hands.Purple
    for _, c in ipairs(BOT_STATE.hands.Purple) do if not want[c.getGUID()] then same = false end end
    check(same, "the bot has its hand back (played card back, drawn card out)")
    check((M.shuffles or 0) > shuffles, "the drawn card goes back into the deck, which is shuffled")
    check(UI.xml:find('id="resumeBtn"', 1, true) ~= nil, "a Resume button while paused")
    undoResume({ color = "Orange" })
    check(not TURN_STATE.paused and not UI.xml:find('id="resumeBtn"', 1, true), "Resume lets the bot play")
    M.pump(20000)

    -- Undo pressed while a bot is mid-move: it finishes, then its turn is undone and the game holds there
    TURN_STATE.paused = false
    turnBegin(3)
    local snapG = UNDO.stack[#UNDO.stack]
    M.pumpFor(1.2)
    check(BOT_STATE.current ~= nil or TURN_STATE.busy, "(the bot is mid-turn)")
    undoClicked({ color = "White" })
    check(TURN_STATE.paused and UNDO.waiting, "Undo waits for the bot to finish")
    M.pump(20000)
    check(TURN_STATE.seat == 3 and TURN_STATE.paused and not UNDO.waiting, "... then goes back to the start of the bot's turn")
    local wantG, sameG = {}, #BOT_STATE.hands.Green == #snapG.hands.Green
    for _, g in ipairs(snapG.hands.Green) do wantG[g] = true end
    for _, c in ipairs(BOT_STATE.hands.Green) do if not wantG[c.getGUID()] then sameG = false end end
    check(sameG, "... with the bot's hand as it was")
    TURN_STATE.paused = false

    -- Pause from anyone: the turn in progress carries on, the game holds before the next one
    M.pump(20000)
    local seatP, genP = TURN_STATE.seat, TURN_STATE.gen
    undoPause({ color = "Orange" })
    check(TURN_STATE.paused and TURN_STATE.gen == genP and UI.xml:find('id="resumeBtn"', 1, true), "Pause: Resume shows, the turn isn't restarted")
    endTurnClicked(nil, PLAYER_COLORS[4][seatP], false)
    M.pump(20000)
    check(TURN_STATE.paused and TURN_STATE.held and TURN_STATE.seat == (seatP % 4) + 1, "... the next turn holds")
    undoResume({ color = "Orange" })
    check(not TURN_STATE.paused and not TURN_STATE.held, "Resume starts it")
    M.pump(20000)

    -- game over: Stats instead of Undo
    GAME_STATS.winner = 1
    refreshGameUI()
    check(UI.xml:find('id="statsBtn"', 1, true) and not UI.xml:find('id="undoBtn"', 1, true), "after the game the button is Stats again")
    undoClicked({ color = "White" })
    check(GAME_STATS.winner == 1, "Undo does nothing once the game is over")
end

------------------------------------------------------------------------
print("== 11-17 list: settings, tutorial, names, turn timer, chat, hands off, un-pick, hover, face-down draw")
do
    local JB = JokerBot
    local function put(color, k, kind, p, seat) M.place(color, k, JB.cellToIndex(kind, p, seat)) end
    local white, orange = { color = "White", steam_name = "Human-White" }, { color = "Orange", steam_name = "Human-Orange" }
    local function startTurn(seat)
        fresh(4, { White = true, Orange = true, Green = true, Purple = true })
        BOT_STATE.active = false
        TURN_STATE.active, TURN_STATE.seat, TURN_STATE.busy = true, seat, false
        EASY_TEST_GEN = (EASY_TEST_GEN or 0) + 1000
        TURN_STATE.gen = EASY_TEST_GEN
        statsTurnStart(PLAYER_COLORS[4][seat])
    end

    -- settings (host only)
    fresh(4, { White = true, Orange = true, Green = true, Purple = true })
    refreshGameUI()
    check(UI.xml:find('id="settingsGear" visibility="Host"', 1, true) and UI.xml:find('id="tutorialBtn"', 1, true), "the gear (host) and ? (everyone) are on screen")
    settingsToggle(orange)
    check(not UI.xml:find('id="settingsPanel"', 1, true), "only the host opens the settings")
    settingsToggle(white)
    check(UI.xml:find('id="settingsPanel"', 1, true) and wellFormed(UI.xml), "the host's gear opens the settings menu (well formed)")
    local lv, sp = BOT_DIFFICULTY, BOT_STATE.speed_index
    settingsClick(white, nil, "set_level_5")
    settingsClick(white, nil, "set_speed_3")
    settingsClick(white, nil, "set_hybrid_on")
    check(BOT_DIFFICULTY == 5 and BOT_STATE.speed_index == 3 and IRL.mode == true, "level, speed and hybrid from the menu")
    settingsClick(orange, nil, "set_level_2")
    check(BOT_DIFFICULTY == 5, "... not by anyone else")
    settingsClick(white, nil, "set_hybrid_off"); botSetDifficulty(lv); BOT_STATE.speed_index = sp
    EASY.chosen = {}; EASY.on.Orange = nil
    settingsClick(white, nil, "set_easy_on")
    check(EASY.on.Orange == true and SETTINGS.easy == true, "default easy play ON reaches players who haven't chosen")
    easyToggle(orange)                                    -- Orange switches it off themselves
    settingsClick(white, nil, "set_easy_off"); settingsClick(white, nil, "set_easy_on")
    check(EASY.on.Orange == nil or EASY.on.Orange == false, "... a player's own choice sticks")
    settingsClick(white, nil, "set_easy_off")
    local function rawSave() local enc = JSON.encode; JSON.encode = function(t) return t end; local r = saveGameState(); JSON.encode = enc; return r end
    local saved = rawSave()
    check(saved.settings and saved.settings.easy == false and saved.settings.timer ~= nil, "the settings are saved with the game")
    settingsClick(white, nil, "set_close")
    check(not UI.xml:find('id="settingsPanel"', 1, true), "Close closes it")

    -- tutorial (per player)
    tutorialToggle(orange)
    check(UI.xml:find('id="tut_Orange" visibility="Orange"', 1, true) and UI.xml:find("Easy play", 1, true) and wellFormed(UI.xml), "? opens how-to-play for that player only")
    tutorialPage(orange, nil, "tutNext_Orange")
    check(TUTORIAL.Orange == 2 and UI.xml:find("Click to play  (2 / ", 1, true), "Next goes to page 2")
    tutorialPage(white, nil, "tutClose_Orange")
    check(TUTORIAL.Orange == 2, "someone else can't close it")
    tutorialPage(orange, nil, "tutClose_Orange")
    check(TUTORIAL.Orange == nil and not UI.xml:find('id="tut_Orange"', 1, true), "Close closes it")

    -- a name of your own, in the colour picker
    showColorPickers()
    check(UI.xml:find('id="pickName_Orange"', 1, true) ~= nil, "everyone's colour picker has a name field")
    pickerName(orange, "  Henry ", "pickName_Orange")
    M.pumpFor(0.5)
    check(playerLabel("Orange") == "Henry", "the picked name is used (" .. tostring(playerLabel("Orange")) .. ")")
    PLAYER_NAMES.Orange.steam = "someone else"
    check(playerLabel("Orange") == "Human-Orange", "... not for somebody else sitting there later")
    pickerName(orange, "Henry", "pickName_Orange")
    check(rawSave().names.Orange.name == "Henry", "names are saved with the game")
    pickerName(orange, "", "pickName_Orange")
    check(playerLabel("Orange") == "Human-Orange", "a blank name goes back to the Steam name")
    hideColorPickers()

    -- the turn timer
    startTurn(1)
    SETTINGS.timer, SETTINGS.sound = true, true
    local plays = 0
    MusicPlayer = { play = function() plays = plays + 1 end, pause = function() end, setCurrentAudioclip = function(t) MusicPlayer.url = t.url end }
    turnTimerStart("White", TURN_STATE.gen)
    check(TURN_TIMER and UI.xml:find('id="turnFlash" visibility="White"', 1, true) and UI.xml:find('raycastTarget="false"', 1, true)
          and wellFormed(UI.xml), "a person's turn: their screen edge glows (clicks go through)")
    M.pumpFor(23)
    check(TURN_TIMER.stage == 1, "still the slow glow at 23 s")
    M.pumpFor(3)
    check(TURN_TIMER.stage == 2 and plays == 0, "flashing after 25 s, no sound yet")
    M.pumpFor(12)
    check(TURN_TIMER.stage == 2, "still flashing (no ticks) at 38 s")
    M.pumpFor(3)
    check(TURN_TIMER.stage == 3 and plays == 1 and tostring(MusicPlayer.url):find("tick", 1, true), "faster with ticks after 40 s")
    M.pumpFor(15)
    check(TURN_TIMER.stage == 4 and UI.xml:find("Y&#10;O&#10;U", 1, true) and tostring(MusicPlayer.url):find("alarm", 1, true), "all out after 55 s")
    GAME_STATS.card_played = true
    M.pumpFor(1)
    check(TURN_TIMER == nil, "a card played stops it")
    startTurn(1)
    SETTINGS.timer = false
    turnTimerStart("White", TURN_STATE.gen)
    check(TURN_TIMER == nil, "the host can switch it off")
    SETTINGS.timer = true

    -- a flag keeps the bot moves up to when it was made
    BOT_STATE.history = { { game_turn = 1 }, { game_turn = 2 } }
    BOT_FLAGS = {}
    WebRequest = { custom = function(url, m, a, body, h, cb) cb({ is_error = true, error = "offline" }) end }
    flagBadMove({ color = "White" })
    BOT_STATE.history[3] = { game_turn = 3 }
    local fl = BOT_FLAGS[#BOT_FLAGS]
    check(fl and #fl.recent_bot_moves == 2, "a waiting flag keeps the bot moves up to when it was made (" .. tostring(fl and #fl.recent_bot_moves) .. ")")

    -- !color: the host recolours any seat
    startTurn(1)
    local hostP = { color = "White", host = true }
    check(onChat("!color 2 pink", hostP) == false and marbleColorName("Green") == "Pink", "!color 2 pink recolours seat 2 (Green, a bot here): " .. marbleColorName("Green"))
    onChat("!color pink #00FFFF see", hostP)
    check(marbleColorName("Green") == "Cyan" and MARBLE_STYLE.Green.see == true, "... by its marble colour, with #RRGGBB and see-through")
    onChat("!color 2 pulse", hostP)
    check(MARBLE_STYLE.Green.fx == "pulse" and marbleColorName("Green") == "Cyan", "... just the effect")
    onChat("!color 2 plaid", hostP)
    check(M.chat[#M.chat]:find("Unknown colour", 1, true) ~= nil, "an unknown colour lists the names")
    check(onChat("!color 2 red", { color = "Orange", host = false }) ~= false and marbleColorName("Green") == "Cyan", "not for a guest")

    -- the chat log: a 7 split in words
    startTurn(1)
    put("White", 1, 'R', 10, 1)
    put("Green", 1, 'R', 50, 3)                       -- a 7 splits with a teammate's marble
    local S = botReadState()
    local seven
    for _, a in ipairs(JB.legalActions(S, 1, { '7' })) do if #a.steps == 2 then seven = a; break end end
    local okd, said = pcall(moveDescription, S, seven, false)
    said = okd and said or ""
    check(said:find("7 split", 1, true) and said:find("Human-White's marble", 1, true) and said:find("Human-Green's marble", 1, true) and not said:find("#", 1, true), "a 7 split in words: " .. said)

    -- hands off other players' cards
    startTurn(1)
    local oc = M.card("9 of Clubs", "Orange")
    M.hands.Orange = { oc }
    check(onPlayerAction(white, Player.Action.PickUp, { oc }) == true, "the host can still pick up anyone's card")
    local purple = { color = "Purple" }
    check(onPlayerAction(purple, Player.Action.PickUp, { oc }) == false and M.broadcasts[#M.broadcasts]:find("hands off", 1, true),
          "someone else can't take a card from your hand")
    local zc = M.card("3 of Clubs", "White")
    zc.setPosition(M.discard.White.pos)
    check(onPlayerAction(purple, Player.Action.PickUp, { zc }) == false, "... or off your play zone")
    M.hands.Orange = {}

    -- easy play: click the picked marble again to un-pick it
    startTurn(1)
    EASY.on.White = true
    put("White", 1, 'R', 10, 1)
    put("White", 2, 'R', 30, 1)
    put("Orange", 1, 'R', 40, 2)
    put("Orange", 2, 'R', 50, 2)
    play("White", "Joker")
    M.pumpFor(0.1)
    local W = Global.getTable("marbles_by_player").White
    onPlayerAction(white, Player.Action.PickUp, { W[1] })
    check(EASY.session and #EASY.session.picks == 1, "(a marble picked)")
    onPlayerAction(white, Player.Action.PickUp, { W[1] })
    check(EASY.session and #EASY.session.picks == 0 and EASY.session.next and EASY.session.next.m1, "clicking it again un-picks it")
    easyCancel()

    -- hover: a marble all the way in shows no numbers; near its finish, numbers for running past it too
    startTurn(1)
    M.hover = { White = {} }
    for n = 1, 13 do M.hover.White[n] = M.newObj({ pos = { x = 4 + 0.5 * n, y = 10, z = 0 } }) end
    HOVER_PASS.White = {}
    for n = 1, 13 do HOVER_PASS.White[n] = M.newObj({ pos = { x = 0, y = 14, z = 0 }, name = "HoverPass_White_" .. n }) end
    HOVER_MINUS8.White = M.newObj({ pos = { x = 4, y = 12, z = 0 } })
    local hn = M.hover.White
    local up = function(o) return o.pos.y < 9 end
    arrangeHoverNumbers("White", JB.cellToIndex('G', 5, 1), 1, { r = 1, g = 1, b = 1 }, 1)
    local any = false
    for n = 1, 13 do if up(hn[n]) or up(HOVER_PASS.White[n]) then any = true end end
    check(not any, "a marble in the last finish hole shows no numbers")
    arrangeHoverNumbers("White", JB.cellToIndex('G', 2, 1), 1, { r = 1, g = 1, b = 1 }, 1)
    check(up(hn[3]) and not up(hn[4]) and not up(HOVER_PASS.White[1]), "in the finish: just the holes left")
    arrangeHoverNumbers("White", JB.cellToIndex('R', 1, 1), 1, { r = 1, g = 1, b = 1 }, 1)   -- 2 before its entrance
    check(up(hn[7]) and not up(hn[8]) and up(HOVER_PASS.White[3]) and up(HOVER_PASS.White[13]) and not up(HOVER_PASS.White[2]),
          "near its finish: 1-7 into it, and light-blue 3-13 for running past it")
    local nsp = Global.getTable("non_start_points")
    local p3 = HOVER_PASS.White[3].pos
    local cell4 = nsp[JB.cellToIndex('R', 4, 1)].position
    check(math.abs(p3.x - cell4.x) < 0.01 and math.abs(p3.z - cell4.z) < 0.01, "... the 3 past it is on the ring cell after the entrance")

    -- drawing: face down into the hand
    startTurn(1)
    M.hands.White = {}
    drawCardsFaceDown("White", 1)
    M.pumpFor(3)
    local got
    for _, o in ipairs(getAllObjects()) do if o.tag == "Card" and o.pos and o.pos.z == -90 and math.abs(o.pos.y - 3.2) < 0.01 then got = o end end
    check(got and got.flipped, "a drawn card goes to the hand face down, then is flipped in the hand")
end

print(string.format("\npassed %d, failed %d", passed, failed))
os.exit(failed == 0 and 0 or 1)
