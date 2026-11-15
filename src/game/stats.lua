-- game/stats.lua  (Global script)
-- Post-game stats, mirroring the "Post Game Stats" sheet of the Google Sheets version of Joker:
--   per player: cards played (A..K, Joker), turns burned, teammates/enemies bonked, bonked by teammates/enemies,
--               distance travelled, the turn they finished, time spent on their turns, awards
--   per team:   the same totals, the turn the team finished, WINNER / LOSER
-- People, bots and in-person seats are counted the same way. Who calls what:
--   Start Game (setup.lua)               -> statsReset
--   a card lands on its play zone        -> statsCardPlayed     (game/cards_played.lua; play/hybrid.lua)
--   ... and is taken back                -> statsCardUnplayed
--   a bonk                               -> statsBonk           (game/bonks.lua)
--   a marble is dropped                  -> statsScheduleFinishCheck (Global onObjectDrop)
--   turn start / end                     -> statsTurnStart / statsTurnEnd (game/turns.lua)
--   a bot's move is done                 -> statsCheckFinish    (bot/play.lua)
-- The screen is ui/stats_panel.lua.

STATS_CARDS = { "a", "2", "3", "4", "5", "6", "7", "8", "9", "10", "j", "q", "k", "$" }
STATS_CARD_LABELS = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "$" }
STATS_WEALTH = { a = true, ["7"] = true, ["8"] = true, j = true, q = true, k = true, ["$"] = true }

CARD_COL = {}
for i, t in ipairs(STATS_CARDS) do CARD_COL[t] = i end

-- GAME_STATS: nil until a game starts (statsReset), then { num_players, turn, winner, players = {[colour] = ...}, ... }

------------------------------------------------------------------------
-- state
------------------------------------------------------------------------
local function newPlayerStats()
    local cards = {}
    for i = 1, #STATS_CARDS do cards[i] = 0 end     -- array (JSON-safe), index = position in STATS_CARDS
    return { cards = cards, burned = 0, teammatesBopped = 0, enemiesBopped = 0,
             boppedByTeammate = 0, boppedByEnemy = 0, turnFinished = 0,    -- turnFinished 0 = not finished
             distance = 0,                                                   -- cells moved (statsTurnEnd)
             bestTurn = 0, freeRide = 0, biggestBonk = 0,                    -- fun superlatives (statsTurnEnd)
             burnStreak = 0, maxBurnStreak = 0,
             time = 0, turns = 0 }                                           -- seconds spent on own turns, turns taken
end

function statsReset(params)
    local N = params.num_players
    GAME_STATS = { num_players = N, turn = 0, winner = 0, players = {}, current = "", card_played = false, snapshot = nil,
                   started = os.time(), ended = nil, turn_t0 = nil }      -- wall-clock seconds (time of play)
    for _, color in ipairs(PLAYER_COLORS[N]) do GAME_STATS.players[color] = newPlayerStats() end
    UI_STATE.stats = false
    refreshGameUI()                 -- adds the Stats button to the top-left panel
end

function statsPlayer(color) return GAME_STATS and GAME_STATS.players[color] end

local function seatOf(color)
    for i, c in ipairs(PLAYER_COLORS[GAME_STATS.num_players]) do if c == color then return i end end
end

local function teamOfSeat(seat) return (seat % 2 == 1) and 1 or 2 end   -- odd seats = Team 1, even = Team 2

------------------------------------------------------------------------
-- tracking
------------------------------------------------------------------------
-- A card landed legitimately on its owner's play zone. Counted once per card per turn
-- (a card jiggling out of the zone and back in during the same turn is not counted twice).
function statsCardPlayed(color, card)
    glogCardPlayed(color, card)
    local ps = statsPlayer(color)
    if not ps then return end
    local token = botCardToken(card.getName())
    local col = token and CARD_COL[token]
    if not col then return end
    if card.getVar("stat_counted_turn") == GAME_STATS.turn then return end
    card.setVar("stat_counted_turn", GAME_STATS.turn)
    if botCardsSeen then botCardsSeen(token) end            -- level 10 card counting (bot.lua)
    ps.cards[col] = ps.cards[col] + 1
    if color == GAME_STATS.current then
        GAME_STATS.card_played = true
        GAME_STATS.cards_this_turn = (GAME_STATS.cards_this_turn or 0) + 1
    end
end

-- the card was taken back off the play zone this turn (user: "puts it back in their hand and then plays a different
-- card"): it no longer counts
function statsCardUnplayed(color, card)
    local ps = statsPlayer(color)
    if not ps or card.getVar("stat_counted_turn") ~= GAME_STATS.turn or color ~= GAME_STATS.current then return false end
    local token = botCardToken(card.getName())
    local col = token and CARD_COL[token]
    if not col then return false end
    card.setVar("stat_counted_turn", nil)
    ps.cards[col] = math.max(0, ps.cards[col] - 1)
    GAME_STATS.cards_this_turn = math.max(0, (GAME_STATS.cards_this_turn or 1) - 1)
    if GAME_STATS.cards_this_turn == 0 then GAME_STATS.card_played = false end
    return true
end

-- A bonk that really happened (called after the illegal-move check). The collision can fire more than once
-- for one landing, so each bonked marble is counted at most once per 1.5 s.
function statsBonk(bonker, bonkee, friendly, bonked_obj)
    local a, b = statsPlayer(bonker), statsPlayer(bonkee)
    if not a or not b then return end
    if bonked_obj then
        if bonked_obj.getVar("stat_bonk_lock") then return end
        bonked_obj.setVar("stat_bonk_lock", true)
        Wait.time(function() bonked_obj.setVar("stat_bonk_lock", false) end, 1.5)
    end
    if friendly then
        a.teammatesBopped = a.teammatesBopped + 1
        b.boppedByTeammate = b.boppedByTeammate + 1
    else
        a.enemiesBopped = a.enemiesBopped + 1
        b.boppedByEnemy = b.boppedByEnemy + 1
    end
end

local function boardSnapshot()
    local S = botReadState()
    local snap = {}
    for i, m in ipairs(S.marbles) do snap[i] = m.kind .. ":" .. tostring(m.p) end
    return snap
end

local function sameSnapshot(a, b)
    if not a or not b or #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

-- A seat's turn starts (human or bot): count the turn and remember where every marble is.
function statsTurnStart(color)
    if not GAME_STATS then return end
    GAME_STATS.turn = GAME_STATS.turn + 1
    GAME_STATS.current = color
    GAME_STATS.card_played = false
    GAME_STATS.cards_this_turn = 0
    GAME_STATS.turn_t0 = os.time()
    local ok, snap = pcall(boardSnapshot)
    GAME_STATS.snapshot = ok and snap or nil
end

-- A seat's turn ends. Burned = a card was played but no marble on the board ended up on a different cell.
-- Cells moved this turn (user: "the actual distance traveled by each player"), from the board at the start and end
-- of the turn: forward moves of up to 13, an 8 backwards, moves into and inside the finish. Bonks (sent to start) and
-- catapults (friendly-bonk jumps, Joker jumps over 13) are not anyone's travel.
function statsTurnDistance(before, S)
    local total = 0
    for i, m in ipairs(S.marbles) do
        local k1, p1 = tostring(before[i] or ""):match("^(%a):(%-?%d+)$")
        p1 = tonumber(p1)
        if k1 and p1 then
            local d = 0
            if k1 == 'R' and m.kind == 'R' then
                local fwd = (m.p - p1) % S.R
                if fwd >= 1 and fwd <= 13 then d = fwd elseif (p1 - m.p) % S.R == 8 then d = 8 end
            elseif k1 == 'R' and m.kind == 'G' then
                local t = JokerBot.distToEntrance(S, m.seat, p1) + m.p
                if t <= 13 then d = t end
            elseif k1 == 'G' and m.kind == 'G' and m.p > p1 then
                d = m.p - p1
            end
            total = total + d
        end
    end
    return total
end

-- Catapults and bonks this turn: a marble that jumped forward more than 13 (friendly bonk / Joker on a teammate) is
-- a free ride for its owner ("Hitchhiker"); a marble sent back to start lost the cells it had travelled, and the
-- player whose turn it is gets the credit for the biggest such bonk ("Heartbreaker").
function statsTurnExtras(before, S, ps)
    local colors = PLAYER_COLORS[GAME_STATS.num_players]
    for i, m in ipairs(S.marbles) do
        local k1, p1 = tostring(before[i] or ""):match("^(%a):(%-?%d+)$")
        p1 = tonumber(p1)
        if k1 == 'R' and p1 then
            if m.kind == 'R' then
                local fwd = (m.p - p1) % S.R
                if fwd > 13 and (p1 - m.p) % S.R ~= 8 then
                    local owner = statsPlayer(colors[m.seat])
                    if owner then owner.freeRide = (tonumber(owner.freeRide) or 0) + fwd end
                end
            elseif m.kind == 'S' then
                local lost = (p1 - JokerBot.exitCell(m.seat)) % S.R
                ps.biggestBonk = math.max(tonumber(ps.biggestBonk) or 0, lost)
            end
        end
    end
end

function statsTurnEnd(color)
    if not GAME_STATS or color ~= GAME_STATS.current then return end
    local ps = statsPlayer(color)
    if ps and GAME_STATS.turn_t0 then
        ps.time = (tonumber(ps.time) or 0) + math.max(0, os.time() - GAME_STATS.turn_t0)
        ps.turns = (tonumber(ps.turns) or 0) + 1
        GAME_STATS.turn_t0 = nil
    end
    if ps and GAME_STATS.card_played and GAME_STATS.snapshot then
        local ok, now = pcall(boardSnapshot)
        if ok and sameSnapshot(GAME_STATS.snapshot, now) then ps.burned = ps.burned + 1 end
    end
    if ps and GAME_STATS.card_played then
        local burned = false
        local ok, now = pcall(boardSnapshot)
        if ok and GAME_STATS.snapshot and sameSnapshot(GAME_STATS.snapshot, now) then burned = true end
        ps.burnStreak = burned and (tonumber(ps.burnStreak) or 0) + 1 or 0
        ps.maxBurnStreak = math.max(tonumber(ps.maxBurnStreak) or 0, ps.burnStreak)
    end
    if ps and GAME_STATS.snapshot then
        local ok, S = pcall(botReadState)
        if ok and S then
            local d = statsTurnDistance(GAME_STATS.snapshot, S)
            ps.distance = (tonumber(ps.distance) or 0) + d
            ps.bestTurn = math.max(tonumber(ps.bestTurn) or 0, d)
            pcall(statsTurnExtras, GAME_STATS.snapshot, S, ps)
        end
    end
    GAME_STATS.snapshot = nil
    statsCheckFinish()
end

-- Records the turn each seat got all 5 marbles home (first time only) and declares the winner:
-- the first team whose players are ALL home.
function statsCheckFinish()
    if not GAME_STATS then return end
    local ok, S = pcall(botReadState)
    if not ok then return end
    local colors = PLAYER_COLORS[GAME_STATS.num_players]
    for seat, color in ipairs(colors) do
        local ps = statsPlayer(color)
        if ps and ps.turnFinished == 0 and JokerBot.isFinished(S, seat) then
            ps.turnFinished = math.max(GAME_STATS.turn, 1)
            printToAll(playerLabel(color) .. " has made it home!")
        end
    end
    if GAME_STATS.winner ~= 0 then return end
    for team = 1, 2 do
        local all = true
        for seat, color in ipairs(colors) do
            if teamOfSeat(seat) == team and statsPlayer(color).turnFinished == 0 then all = false end
        end
        if all then
            GAME_STATS.winner = team
            GAME_STATS.ended = os.time()
            broadcastToAll("Team " .. team .. " wins!", { 0.3, 1, 0.3 })
            -- the stats come up once the "Team X wins!" broadcast and splash have gone (user)
            Wait.time(function() if GAME_STATS and GAME_STATS.winner == team then statsOpen() end end, STATS_OPEN_DELAY)
            return
        end
    end
end

-- after a human drops a marble, wait for it to settle on its point before checking
function statsScheduleFinishCheck()
    if GAME_STATS then Wait.time(statsCheckFinish, 1) end
end

------------------------------------------------------------------------
-- derived numbers
------------------------------------------------------------------------
-- Stats values should always be numbers; one turned out to be a table in a real game ("attempt to compare number
-- with table" in statsAwards, at game end and on the Stats button). Until that is found, anything that isn't a
-- number counts as 0, and the first such value is reported in chat with its name.
local statsBadReported = false
function statsNum(x, what)
    if type(x) == "number" then return x end
    if not statsBadReported then
        statsBadReported = true
        local shown = type(x) == "table" and JSON and JSON.encode and JSON.encode(x) or tostring(x)
        local say = botHostMsg or printToAll
        say("STATS DEBUG: " .. tostring(what) .. " is a " .. type(x) .. " (" .. tostring(shown) .. "), counted as 0. Please tell Claude.")
    end
    return 0
end

function statsWealth(ps)
    local w = 0
    for i, t in ipairs(STATS_CARDS) do if STATS_WEALTH[t] then w = w + statsNum(ps.cards[i], "card " .. t) end end
    return w
end

-- award name -> function(player stats) returning the value; best = highest unless lowest = true.
STATS_AWARDS = {
    { name = "Best Teammate",       value = function(ps) return ps.teammatesBopped end },
    { name = "Sniper",              value = function(ps) return ps.enemiesBopped end },
    { name = "Most Hated",          value = function(ps) return ps.boppedByEnemy end },
    { name = "Fast Finisher",       value = function(ps) return ps.turnFinished end, lowest = true },
    { name = "Wealthiest Player",   value = function(ps) return statsWealth(ps) end },
    { name = "Poorest Player",      value = function(ps) return ps.burned end },
    { name = "Teammates' Favorite", value = function(ps) return ps.boppedByTeammate end },
    { name = "Marathon Runner",     value = function(ps) return tonumber(ps.distance) or 0 end },
    { name = "Couch Potato",        value = function(ps) return tonumber(ps.distance) or 0 end, lowest = true },
    { name = "Speed Demon",         value = function(ps) return tonumber(ps.bestTurn) or 0 end },        -- biggest turn
    { name = "Hitchhiker",          value = function(ps) return tonumber(ps.freeRide) or 0 end },        -- catapulted most
    { name = "Heartbreaker",        value = function(ps) return tonumber(ps.biggestBonk) or 0 end },     -- cruelest bonk
    { name = "Wild Card",           value = function(ps) return ps.cards[CARD_COL['$']] or 0 end },     -- most Jokers
    { name = "Lucky Sevens",        value = function(ps) return ps.cards[CARD_COL['7']] or 0 end },     -- most 7s
    { name = "Moonwalker",          value = function(ps) return ps.cards[CARD_COL['8']] or 0 end },     -- most 8s
    { name = "Cold Streak",         value = function(ps) return tonumber(ps.maxBurnStreak) or 0 end }, -- burns in a row
}

-- returns [color] = { award names } ; only values > 0 qualify, ties all win, several awards per player allowed
-- In TTS this crashed with "attempt to compare number with table" on the comparison line even though every saved
-- stat was a plain number (and it never happens in standard Lua), so it is written without any < or > on values
-- that came from elsewhere: each value is forced through tonumber() into a fresh local, and the whole thing runs in
-- pcall. If it still fails, the stats screen shows no awards and chat gets one "STATS DEBUG" line with the details.
local function awardsUnsafe()
    local out = {}
    local colors = PLAYER_COLORS[GAME_STATS.num_players]
    for _, c in ipairs(colors) do out[c] = {} end
    local ties = {}
    for _, aw in ipairs(STATS_AWARDS) do
        local vals = {}
        for i, c in ipairs(colors) do
            local raw = aw.value(statsPlayer(c))
            local v = tonumber(statsNum(raw, aw.name .. " for " .. c)) or 0
            vals[i] = v + 0
        end
        local best = nil
        for i = 1, #colors do
            local v = vals[i]
            if v > 0 then
                if best == nil then best = v
                elseif aw.lowest then best = math.min(best, v)
                else best = math.max(best, v) end
            end
        end
        if best ~= nil then
            local tied = {}
            for i, c in ipairs(colors) do if vals[i] == best then tied[#tied + 1] = c end end
            ties[#ties + 1] = { name = aw.name, tied = tied }
        end
    end
    -- one winner per award (user: "if its a tie just give the award to whoever has fewer awards so theres only 1 best
    -- teammate"): clear winners first, then each tied award goes to the tied player with the fewest awards so far
    -- (seat order breaks a tie in that too)
    local final = {}
    for k, t in ipairs(ties) do if #t.tied == 1 then final[k] = t.tied[1]; table.insert(out[t.tied[1]], t.name) end end
    for k, t in ipairs(ties) do
        if #t.tied > 1 then
            local pick = t.tied[1]
            for _, c in ipairs(t.tied) do if #out[c] < #out[pick] then pick = c end end
            final[k] = pick
        end
        if #t.tied > 1 then table.insert(out[final[k]], t.name) end
    end
    -- keep each player's awards in the STATS_AWARDS order
    local rank = {}
    for i, aw in ipairs(STATS_AWARDS) do rank[aw.name] = i end
    for _, c in ipairs(colors) do table.sort(out[c], function(a, b) return rank[a] < rank[b] end) end
    return out
end

-- At most STATS_AWARDS_SHOWN awards per player on the screen (user: "pick one or two of the awarded awards per
-- player, chosen at random, it's a little crowded"). The pick is remembered (GAME_STATS.award_pick, saved with the
-- game) so reopening the screen doesn't reshuffle it; it is redrawn only when that player's set of awards changes.
STATS_AWARDS_SHOWN = 2
function statsPickAwards(color, list)
    list = list or {}
    if #list <= STATS_AWARDS_SHOWN then return list end
    GAME_STATS.award_pick = GAME_STATS.award_pick or {}
    local key = table.concat(list, "|")
    local saved = GAME_STATS.award_pick[color]
    if saved and saved.key == key then return saved.shown end
    local pool = {}
    for i, a in ipairs(list) do pool[i] = a end
    local shown = {}
    for _ = 1, STATS_AWARDS_SHOWN do shown[#shown + 1] = table.remove(pool, math.random(#pool)) end
    GAME_STATS.award_pick[color] = { key = key, shown = shown }
    return shown
end

local statsAwardsReported = false
function statsAwards()
    local ok, res = pcall(awardsUnsafe)
    if ok then return res end
    if not statsAwardsReported then
        statsAwardsReported = true
        local info = {}
        for _, c in ipairs(PLAYER_COLORS[GAME_STATS.num_players] or {}) do
            local ps = statsPlayer(c)
            if type(ps) ~= "table" then info[#info + 1] = c .. "=" .. type(ps)
            else
                for k, v in pairs(ps) do
                    if type(v) ~= "number" and k ~= "cards" then info[#info + 1] = c .. "." .. tostring(k) .. "=" .. type(v) end
                end
            end
        end
        local say = botHostMsg or printToAll
        say("STATS DEBUG: awards failed (" .. tostring(res) .. ") odd values: " .. (#info > 0 and table.concat(info, ", ") or "none") .. ". Please tell Claude.")
    end
    local out = {}
    for _, c in ipairs(PLAYER_COLORS[GAME_STATS.num_players] or {}) do out[c] = {} end
    return out
end

-- team totals: { cards = {..}, burned, teammatesBopped, enemiesBopped, lastFinished (0 unless every player finished) }
function statsTeamTotals(team)
    local t = newPlayerStats()
    t.lastFinished = 0
    local allDone = true
    for seat, color in ipairs(PLAYER_COLORS[GAME_STATS.num_players]) do
        if teamOfSeat(seat) == team then
            local ps = statsPlayer(color)
            for i = 1, #STATS_CARDS do t.cards[i] = t.cards[i] + statsNum(ps.cards[i], "card " .. i .. " for " .. color) end
            t.burned = t.burned + statsNum(ps.burned, "burned for " .. color)
            t.teammatesBopped = t.teammatesBopped + statsNum(ps.teammatesBopped, "teammatesBopped for " .. color)
            t.enemiesBopped = t.enemiesBopped + statsNum(ps.enemiesBopped, "enemiesBopped for " .. color)
            t.distance = (t.distance or 0) + (tonumber(ps.distance) or 0)
            local tf = statsNum(ps.turnFinished, "turnFinished for " .. color)
            if tf == 0 then allDone = false
            elseif tf > t.lastFinished then t.lastFinished = tf end
        end
    end
    if not allDone then t.lastFinished = 0 end
    return t
end

------------------------------------------------------------------------
-- UI
