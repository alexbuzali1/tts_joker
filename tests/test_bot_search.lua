-- Tests for bot_search.lua.   lua test_bot_search.lua          (quick checks, ~30 s)
--                              lua test_bot_search.lua match    (also: simulated games, level 9 vs level 1)
dofile("tests/load_bot.lua")
local JB, JS = JokerBot, JokerSearch
math.randomseed(5)
local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. msg) end
end

-- a random but legal-looking mid-game position: per seat, some marbles in start, some on the ring, some home
local function randomState(N)
    local list, used = {}, {}
    for s = 1, N do
        local home = math.random(0, 2)
        for k = 1, 5 do
            if k <= home then
                list[#list + 1] = { seat = s, kind = 'G', p = 6 - k }
            elseif math.random() < 0.55 then
                local p
                repeat p = math.random(1, 18 * N) until not used[p]
                used[p] = true
                list[#list + 1] = { seat = s, kind = 'R', p = p }
            else
                list[#list + 1] = { seat = s, kind = 'S', p = 0 }
            end
        end
    end
    return JB.newState(N, list)
end

local DECK = {}
for _, c in ipairs(JS.CARDS) do for _ = 1, JS.CARD_WEIGHT[c] do DECK[#DECK + 1] = c end end
local function randomHand(n) local h = {}; for i = 1, n do h[i] = DECK[math.random(#DECK)] end; return h end

local function isLegal(S, seat, hand, act)
    if act.burn then return #JB.legalActions(S, seat, hand) == 0 end
    for _, a in ipairs(JB.legalActions(S, seat, hand)) do
        if a.card == act.card and #a.steps == #act.steps then
            local same = true
            for i, st in ipairs(a.steps) do
                local o = act.steps[i]
                if st.mi ~= o.mi or st.kind ~= o.kind or st.p ~= o.p then same = false end
            end
            if same then return true end
        end
    end
    return false
end

------------------------------------------------------------------------
print("== every level returns a legal move (random positions, 4/6/8 players)")
for level = 1, 9 do
    local bad = 0
    for _ = 1, 6 do
        local N = ({ 4, 6, 8 })[math.random(3)]
        local S = randomState(N)
        local seat, hand = math.random(N), randomHand(6)
        local act = JS.choose(S, seat, hand, { level = level, time_limit = 0.15 })
        if not isLegal(S, seat, hand, act) then bad = bad + 1 end
    end
    check(bad == 0, "level " .. level .. ": " .. bad .. " illegal choices")
end

------------------------------------------------------------------------
print("== time limit, iterative deepening, yielding (level 9, 2 s)")
local S = randomState(4)
local hand = { '7', 'a', '5', 'k', '8', '$' }
local yields = 0
local depths = {}
local t0 = os.clock()
local act = JS.choose(S, 1, hand, { level = 9, time_limit = 2.0, yield = function() yields = yields + 1 end,
                                    progress = function(d) depths[#depths + 1] = d end })
local el = os.clock() - t0
print(string.format("   depth %d, %d nodes, %.2f s, %d yields, depths completed: %s",
    act.depth, act.nodes, el, yields, table.concat(depths, ",")))
check(el < 2.0 + 0.4, "stays within the time limit (" .. el .. " s)")
check(act.depth >= 2, "reaches at least depth 2 in 2 s (got " .. act.depth .. ")")
check(yields >= 20, "yields regularly so TTS can draw frames (" .. yields .. ")")
check(isLegal(S, 1, hand, act), "deep choice is legal")

print("== shorter limit -> shallower or equal depth, still within time")
local t1 = os.clock()
local quick = JS.choose(S, 1, hand, { level = 9, time_limit = 0.2 })
local el2 = os.clock() - t1
check(el2 < 0.2 + 0.3, "0.2 s limit respected (" .. el2 .. ")")
check(quick.depth <= act.depth, "less time, no deeper (" .. quick.depth .. " vs " .. act.depth .. ")")

print("== level caps depth; level 1-3 are depth 1")
local l3 = JS.choose(S, 1, hand, { level = 3, time_limit = 2 })
local l5 = JS.choose(S, 1, hand, { level = 5, time_limit = 2 })
check(l3.depth == 1 and l5.depth <= 2, "depth caps (l3 " .. l3.depth .. ", l5 " .. l5.depth .. ")")

print("== a small position (one card, few marbles) is searched deep within the limit")
do
    local list = {
        { seat = 1, kind = 'R', p = 20 }, { seat = 1, kind = 'R', p = 60 },
        { seat = 2, kind = 'R', p = 24 },
    }
    for s = 1, 4 do for _ = 1, (s <= 2 and 4 or 5) do list[#list + 1] = { seat = s, kind = 'S', p = 0 } end end
    local S2 = JB.newState(4, list)
    local deep = JS.choose(S2, 1, { '5' }, { level = 9, time_limit = 1 })
    check(isLegal(S2, 1, { '5' }, deep), "deep choice legal in the small position")
    check(deep.depth >= 4, "small position reaches depth >= 4 (got " .. deep.depth .. ")")
    print("   chose: " .. tostring(deep.text) .. " (depth " .. deep.depth .. ")")
end

print("== defensive Joker: hit an enemy about to enter its finish when it already has marbles home")
do
    -- seat 2 (enemy) has 3 marbles home and one 4 cells before its entrance; seat 1 holds a Joker and a 5
    local function position(enemyHome, enemyDist)
        -- seat 1: one marble on the ring, the other four already home (so no Joker move out of start)
        local list = { { seat = 1, kind = 'R', p = 40 } }
        for k = 1, 4 do list[#list + 1] = { seat = 1, kind = 'G', p = 6 - k } end
        local e = JB.entrance(2)
        list[#list + 1] = { seat = 2, kind = 'R', p = ((e - enemyDist - 1) % 72) + 1 }
        for k = 1, enemyHome do list[#list + 1] = { seat = 2, kind = 'G', p = 6 - k } end
        for _ = 1, 4 - enemyHome do list[#list + 1] = { seat = 2, kind = 'S', p = 0 } end
        for s = 3, 4 do for _ = 1, 5 do list[#list + 1] = { seat = s, kind = 'S', p = 0 } end end
        return JB.newState(4, list)
    end
    local hand = { '$', '5' }
    local Sd = position(4, 4)     -- its LAST marble (user 2026-11-11: defensive Jokers only on a last marble)
    local g = JB.choose(Sd, 1, hand, function() return 0.5 end)
    local d = JS.choose(Sd, 1, hand, { level = 9, time_limit = 0.5 })
    check(g.card == '$' and g.bumps == 1, "greedy uses the Joker on the near-finish enemy (" .. tostring(g.text) .. ")")
    check(d.card == '$' and d.bumps == 1, "search uses the Joker on the near-finish enemy (" .. tostring(d.text) .. ")")
    -- 3 home and other marbles still out: keep the Joker (user 2026-11-11, three such Jokers were "terrible")
    local S3 = position(3, 4)
    local d3 = JS.choose(S3, 1, hand, { level = 9, time_limit = 0.5 })
    check(d3.card ~= '$', "search keeps the Joker against a player with 3 home (" .. tostring(d3.text) .. ")")
    -- same enemy marble far from its finish, nobody home: keep the Joker, play the 5
    local Sf = position(0, 40)
    local g2 = JB.choose(Sf, 1, hand, function() return 0.5 end)
    local d2 = JS.choose(Sf, 1, hand, { level = 9, time_limit = 0.5 })
    check(g2.card == '5', "greedy keeps the Joker when there is no threat (" .. tostring(g2.text) .. ")")
    check(d2.card == '5', "search keeps the Joker when there is no threat (" .. tostring(d2.text) .. ")")
end

print("== multi-bonk Joker: two bonks for one Joker")
do
    -- seat 1: marble A on seat 3's (teammate) finish entrance, marble B on the ring; seat 3: a marble at 50.
    -- Joker: B jumps onto seat 3's marble -> it goes to seat 3's entrance -> bonks A -> A goes to seat 1's entrance.
    local list = { { seat = 1, kind = 'R', p = JB.entrance(3) }, { seat = 1, kind = 'R', p = 10 } }
    for _ = 1, 3 do list[#list + 1] = { seat = 1, kind = 'S', p = 0 } end
    list[#list + 1] = { seat = 3, kind = 'R', p = 50 }
    for _ = 1, 4 do list[#list + 1] = { seat = 3, kind = 'S', p = 0 } end
    for _, s in ipairs({ 2, 4 }) do for _ = 1, 5 do list[#list + 1] = { seat = s, kind = 'S', p = 0 } end end
    local Sm = JB.newState(4, list)
    local hand = { '$', '5', '3' }
    local g = JB.choose(Sm, 1, hand, function() return 0.5 end)
    local d = JS.choose(Sm, 1, hand, { level = 9, time_limit = 0.5 })
    check(g.card == '$' and g.bumps == 2, "greedy plays the 2-bonk Joker (" .. tostring(g.text) .. ")")
    check(d.card == '$' and d.bumps == 2, "search plays the 2-bonk Joker (" .. tostring(d.text) .. ")")
    if g.card == '$' then
        local A = g.state.marbles[1]
        check(A.kind == 'R' and A.p == JB.entrance(1), "marble A ends on its own finish entrance")
    end
end

print("== 7 trap: set it up with another card, then spring it")
do
    local trapCell = ((JB.exitCell(3) - 2 - 1) % 72) + 1          -- 2 behind seat 3's (teammate) exit cell
    local function base(myP, mateOut)
        local list = { { seat = 1, kind = 'R', p = myP }, { seat = 1, kind = 'R', p = 60 } }
        for _ = 1, 3 do list[#list + 1] = { seat = 1, kind = 'S', p = 0 } end
        if mateOut then list[#list + 1] = { seat = 3, kind = 'R', p = JB.exitCell(3) } end
        for _ = 1, (mateOut and 4 or 5) do list[#list + 1] = { seat = 3, kind = 'S', p = 0 } end
        for _, s in ipairs({ 2, 4 }) do for _ = 1, 5 do list[#list + 1] = { seat = s, kind = 'S', p = 0 } end end
        return JB.newState(4, list)
    end
    -- setup: a 5 takes marble 1 onto the trap cell; level 9 should do that and keep the 7
    local Ss = base(((trapCell - 5 - 1) % 72) + 1, false)
    local d = JS.choose(Ss, 1, { '7', '5', '5' }, { level = 9, time_limit = 0.5 })
    check(d.card == '5' and d.state.marbles[1].p == trapCell, "level 9 sets the trap with a 5 and keeps the 7 (" .. tostring(d.text) .. ")")
    -- spring: teammate just came out onto its exit cell, our marble waits 2 behind it
    local Sp = base(trapCell, true)
    local g = JS.choose(Sp, 1, { '7', '3' }, { level = 9, time_limit = 0.5 })
    local mate = g.state and g.state.marbles[6]
    check(g.card == '7' and mate and mate.kind == 'G' and mate.p == 5,
        "level 9 springs it: +2 bonks the teammate, +5 puts them in finish cell 5 (" .. tostring(g.text) .. ")")
end

print("== parking, face cards, K and 10")
do
    local function st(extra, myStart)
        local list = {}
        for _, m in ipairs(extra) do list[#list + 1] = m end
        local count = {}
        for _, m in ipairs(list) do count[m.seat] = (count[m.seat] or 0) + 1 end
        for s = 1, 4 do for _ = 1, 5 - (count[s] or 0) do list[#list + 1] = { seat = s, kind = 'S', p = 0 } end end
        return JB.newState(4, list)
    end
    local rng = function() return 0.5 end
    -- parked on the teammate's (seat 3) exit cell: bring another marble out with the K instead of moving on
    local Sp = st({ { seat = 1, kind = 'R', p = JB.exitCell(3) } })
    for _, pick in ipairs({ JB.choose(Sp, 1, { 'k', '5' }, rng), JS.choose(Sp, 1, { 'k', '5' }, { level = 9, time_limit = 0.5 }) }) do
        local moved = pick.steps and pick.steps[1] and Sp.marbles[pick.steps[1].mi]
        check(moved and moved.kind == 'S', "parked marble stays; the K brings a new marble out (" .. tostring(pick.text) .. ")")
    end
    -- a face card is not spent as a plain board move while marbles are still in start
    local Sf = st({ { seat = 1, kind = 'R', p = 20 } })
    local f = JB.choose(Sf, 1, { 'q', '4' }, rng)
    local fm = Sf.marbles[f.steps[1].mi]
    check(not (f.card == 'q' and fm.kind == 'R'), "Q not used as a board move (" .. tostring(f.text) .. ")")
    -- defence: the Q bonks an enemy 3 cells from its finish entrance
    local e = JB.entrance(2)
    local Sd = st({ { seat = 1, kind = 'R', p = e - 3 - 12 }, { seat = 2, kind = 'R', p = e - 3 } })
    local dq = JB.choose(Sd, 1, { 'q', '4' }, rng)
    check(dq.card == 'q' and dq.bumps == 1, "Q used to bonk an enemy about to enter its finish (" .. tostring(dq.text) .. ")")
    -- costs: K and 10 cost more than Q and 9 on a plain move, nothing when they defend
    local plainK = { card = 'k', steps = { { mi = 1 } }, bumpList = {} }
    local plainQ = { card = 'q', steps = { { mi = 1 } }, bumpList = {} }
    check(JB.cardCost(Sf, plainK) > JB.cardCost(Sf, plainQ), "K costs more than Q as a board move")
    -- a held 10 covers the next enemy's -8 spot from our exit cell (ambush), a 9 doesn't
    local Sx = st({ { seat = 1, kind = 'R', p = JB.exitCell(1) } })
    check(JB.ambushBonus(Sx, 1, { '10' }) > 0 and JB.ambushBonus(Sx, 1, { '9' }) == 0, "holding a 10 at the exit covers the -8 spot, a 9 doesn't")
    local defK = { card = 'k', steps = { { mi = 1 } }, bumpList = { { idx = 2, friendly = false } } }
    check(JB.cardCost(Sd, defK) == 0, "K used for defence costs nothing")
    -- late game (no marbles left in start): the Q is just a 12
    local Sl = JB.newState(4, { { seat = 1, kind = 'R', p = 20 }, { seat = 1, kind = 'G', p = 5 }, { seat = 1, kind = 'G', p = 4 },
        { seat = 1, kind = 'G', p = 3 }, { seat = 1, kind = 'G', p = 2 } })
    check(JB.cardCost(Sl, plainQ) == JB.CARD_COST.q, "late game: Q as a board move costs its normal value")
end

print("== ambush: don't stand on the next enemy's -8 spot, cover it")
do
    local minus8 = JB.exitCell(2) - 8                             -- = our exit cell + 10
    local list = { { seat = 1, kind = 'R', p = JB.exitCell(1) }, { seat = 2, kind = 'R', p = JB.exitCell(2) } }
    for s = 1, 4 do for _ = 1, (s <= 2 and 4 or 5) do list[#list + 1] = { seat = s, kind = 'S', p = 0 } end end
    local S = JB.newState(4, list)
    check(JB.exitCell(1) + 10 == minus8, "our exit + 10 is the next enemy's -8 spot")
    local hand = { '10', '4', '6', '2' }
    for _, lvl in ipairs({ 7, 9 }) do
        local d = JS.choose(S, 1, hand, { level = lvl, time_limit = 0.5 })
        local p = d.state and d.state.marbles[1].p
        check(p ~= minus8, "level " .. lvl .. " doesn't move onto the -8 spot (" .. tostring(d.text) .. ")")
        local covered = p and ((minus8 - p) % 72)
        local rest = {}
        local removed = false
        for _, c in ipairs(hand) do if c == d.card and not removed then removed = true else rest[#rest + 1] = c end end
        check(JB.ambushBonus(d.state, 1, rest) > 0, "level " .. lvl .. " keeps a card that reaches it next turn (" .. tostring(d.text) .. ", " .. tostring(covered) .. " short)")
    end
end

print("== strategy rules are for the higher levels")
do
    local list = { { seat = 1, kind = 'R', p = 20 } }
    for s = 1, 4 do for _ = 1, (s == 1 and 4 or 5) do list[#list + 1] = { seat = s, kind = 'S', p = 0 } end end
    local S = JB.newState(4, list)
    local plainQ = { card = 'q', steps = { { mi = 1 } }, bumpList = {} }
    local before = JB.STRATEGY
    JS.choose(S, 1, { 'q', '4' }, { level = 3, time_limit = 0.2 })
    check(JB.STRATEGY == before, "JokerBot.STRATEGY is restored after a search")
    JB.STRATEGY = JS.LEVELS[3].insight
    check(JB.cardCost(S, plainQ) == JB.CARD_COST.q, "level 3: a Q board move costs its plain value")
    JB.STRATEGY = JS.LEVELS[9].insight
    check(JB.cardCost(S, plainQ) == JB.FACE_BOARD_COST.q, "level 9: a Q board move costs the thrift value")
    JB.STRATEGY = before
end

print("== a 7 should bonk or reach the finish, otherwise keep it")
do
    local function st(extra)
        local list = {}
        for _, m in ipairs(extra) do list[#list + 1] = m end
        local count = {}
        for _, m in ipairs(list) do count[m.seat] = (count[m.seat] or 0) + 1 end
        for s = 1, 4 do for _ = 1, 5 - (count[s] or 0) do list[#list + 1] = { seat = s, kind = 'S', p = 0 } end end
        return JB.newState(4, list)
    end
    -- our marble at 20, a teammate marble at 50: every split is idle -> play the 5
    local Si = st({ { seat = 1, kind = 'R', p = 20 }, { seat = 3, kind = 'R', p = 50 } })
    local i9 = JS.choose(Si, 1, { '7', '5' }, { level = 9, time_limit = 0.5 })
    check(i9.card == '5', "level 9 keeps an idle 7 (" .. tostring(i9.text) .. ")")
    -- an enemy 3 ahead: 3 of the 7 bonks it, 4 for the teammate -> play the 7
    local Sb = st({ { seat = 1, kind = 'R', p = 20 }, { seat = 3, kind = 'R', p = 50 }, { seat = 2, kind = 'R', p = 23 } })
    local b9 = JS.choose(Sb, 1, { '7', '5' }, { level = 9, time_limit = 0.5 })
    check(b9.card == '7' and b9.bumps >= 1, "level 9 uses the 7 to bonk (" .. tostring(b9.text) .. ")")
    -- only idle 7s are legal: one must be played (no burning with a legal move)
    local o9 = JS.choose(Si, 1, { '7' }, { level = 9, time_limit = 0.3 })
    check(o9.card == '7' and not o9.burn, "with only idle 7s possible it still plays one (" .. tostring(o9.text) .. ")")
    -- the rule never drops every move, and is off at level 3 (strategy 0)
    local saved = JB.STRATEGY
    JB.STRATEGY = 1
    local all = JB.legalActions(Si, 1, { '7', '5' })
    local kept = JB.dropIdleSevens(Si, all)
    local sevens = 0
    for _, a in ipairs(kept) do if a.card == '7' then sevens = sevens + 1 end end
    check(#kept > 0 and sevens == 0, "idle 7s are dropped when another move exists")
    JB.STRATEGY = 0
    check(#JB.dropIdleSevens(Si, all) == #all, "level 3 (strategy 0): nothing dropped")
    JB.STRATEGY = saved
end

print("== an 8 should bonk or get a marble ready to enter its finish")
do
    local function st(extra)
        local list = {}
        for _, m in ipairs(extra) do list[#list + 1] = m end
        local count = {}
        for _, m in ipairs(list) do count[m.seat] = (count[m.seat] or 0) + 1 end
        for s = 1, 4 do for _ = 1, 5 - (count[s] or 0) do list[#list + 1] = { seat = s, kind = 'S', p = 0 } end end
        return JB.newState(4, list)
    end
    -- just out on our exit cell: the 8 back puts us 3 short of our entrance -> qualifies
    local Se = st({ { seat = 1, kind = 'R', p = JB.exitCell(1) } })
    local r = JB.legalActions(Se, 1, { '8' })[1]
    check(r and JB.readiesForFinish(Se, r), "8 back from the exit cell readies the marble for its finish")
    -- far from home: an 8 back there is idle and costs more than a 5
    local Sf = st({ { seat = 1, kind = 'R', p = 40 } })
    local idle = JB.legalActions(Sf, 1, { '8' })[1]
    local five = JB.legalActions(Sf, 1, { '5' })[1]
    check(JB.cardCost(Sf, idle) > JB.cardCost(Sf, five), "an idle 8 costs more than a 5")
end

print("== formation: one defender near the start, the others run")
do
    local function st(extra)
        local list = {}
        for _, m in ipairs(extra) do list[#list + 1] = m end
        local count = {}
        for _, m in ipairs(list) do count[m.seat] = (count[m.seat] or 0) + 1 end
        for s = 1, 4 do for _ = 1, 5 - (count[s] or 0) do list[#list + 1] = { seat = s, kind = 'S', p = 0 } end end
        return JB.newState(4, list)
    end
    local ex = JB.exitCell(1)
    -- defender on the exit cell, runner 14 past it: a 5 moves the runner
    local S1 = st({ { seat = 1, kind = 'R', p = ex }, { seat = 1, kind = 'R', p = ex + 14 } })
    for _, lvl in ipairs({ 7, 9 }) do
        local d = JS.choose(S1, 1, { '5' }, { level = lvl, time_limit = 0.4 })
        check(d.steps[1].mi == 2, "level " .. lvl .. ": the runner moves, the defender stays (" .. tostring(d.text) .. ")")
    end
    -- user's example: one on the exit cell, one 4 past it, an ace: move the front one, not the defender
    local S3 = st({ { seat = 1, kind = 'R', p = ex }, { seat = 1, kind = 'R', p = ex + 4 } })
    local d3 = JS.choose(S3, 1, { 'a' }, { level = 9, time_limit = 0.4 })
    check(d3.steps[1].mi == 2, "ace moves the front marble, not the one on the exit cell (" .. tostring(d3.text) .. ")")
    -- only a defender out (2 past the exit, so the exit cell is free): don't nudge it 3, bring a marble out with the K
    local S2 = st({ { seat = 1, kind = 'R', p = ex + 2 } })
    local d2 = JS.choose(S2, 1, { '3', 'k' }, { level = 9, time_limit = 0.4 })
    check(d2.card == 'k' and S2.marbles[d2.steps[1].mi].kind == 'S', "no nudging the defender: the K brings a marble out (" .. tostring(d2.text) .. ")")
    -- crowding: a third marble in the home stretch scores worse than two
    local saved = JB.STRATEGY
    JB.STRATEGY = 1
    local two = JB.evaluate(st({ { seat = 1, kind = 'R', p = ex }, { seat = 1, kind = 'R', p = ex + 4 } }), 1)
    local three = JB.evaluate(st({ { seat = 1, kind = 'R', p = ex }, { seat = 1, kind = 'R', p = ex + 4 }, { seat = 1, kind = 'R', p = ex + 8 } }), 1)
    check(three - two < 25, "a third marble near the start adds little (" .. string.format("%.0f", three - two) .. ")")
    JB.STRATEGY = saved
end

print("== danger distances, safe Jokers, combo-7 setup")
do
    local saved = JB.STRATEGY
    JB.STRATEGY = 1
    local function st(extra)
        local list = {}
        for _, m in ipairs(extra) do list[#list + 1] = m end
        local count = {}
        for _, m in ipairs(list) do count[m.seat] = (count[m.seat] or 0) + 1 end
        for s = 1, 4 do for _ = 1, 5 - (count[s] or 0) do list[#list + 1] = { seat = s, kind = 'S', p = 0 } end end
        return JB.newState(4, list)
    end
    local function threatsWithEnemyBehind(d)
        local S = st({ { seat = 1, kind = 'R', p = 40 }, { seat = 2, kind = 'R', p = 40 - d } })
        return JB.threatsAt(S, 40, 1, {})
    end
    local bad = {}
    for d = 1, 16 do
        local want = (d <= 13 and d ~= 7 and d ~= 8) and 1 or 0
        if threatsWithEnemyBehind(d) ~= want then bad[#bad + 1] = d end
    end
    check(#bad == 0, "enemy behind: 1-6 and 9-13 dangerous, 7, 8 and 14+ safe (wrong at: " .. table.concat(bad, ",") .. ")")
    local Sa = st({ { seat = 1, kind = 'R', p = 40 }, { seat = 2, kind = 'R', p = 48 } })
    check(JB.threatsAt(Sa, 40, 1, {}) == 1, "enemy 8 ahead is dangerous")
    -- two Joker targets: an enemy at 30 with another enemy 3 behind it (unsafe), or an enemy at 52 with one 7 behind
    local Sj = st({ { seat = 1, kind = 'R', p = 10 }, { seat = 2, kind = 'R', p = 30 }, { seat = 4, kind = 'R', p = 27 },
                    { seat = 2, kind = 'R', p = 52 }, { seat = 4, kind = 'R', p = 45 } })
    local j = JB.choose(Sj, 1, { '$' }, function() return 0.5 end)
    check(j.card == '$' and j.steps[1].p ~= 30, "the Joker avoids the unsafe landing (" .. tostring(j.text) .. ")")
    -- an 8 that lands 3 in front of an enemy is penalised, one that lands 7 in front isn't
    local S8a = st({ { seat = 1, kind = 'R', p = 48 }, { seat = 2, kind = 'R', p = 37 } })
    local S8b = st({ { seat = 1, kind = 'R', p = 48 }, { seat = 2, kind = 'R', p = 33 } })
    local a8 = JB.legalActions(S8a, 1, { '8' })[1]
    local b8 = JB.legalActions(S8b, 1, { '8' })[1]
    check(JB.landingPenalty(a8) > 0 and JB.landingPenalty(b8) == 0, "8 landing 3 ahead of an enemy is unsafe, 7 ahead is safe")
    JB.STRATEGY = saved
    -- combo 7: marble 4 behind a teammate on the ring (teammate 3 short of its entrance... bonk + finish next turn)
    local mateP = JB.entrance(3) - 10
    local Sc = st({ { seat = 1, kind = 'R', p = mateP - 2 - 9 }, { seat = 3, kind = 'R', p = mateP }, { seat = 1, kind = 'R', p = 60 } })
    check(JB.comboSevenBonus(Sc, 1, true) == 0, "no combo 7 from 11 behind")
    local c = JS.choose(Sc, 1, { '7', '9' }, { level = 9, time_limit = 0.5 })
    check(c.card == '9' and c.state.marbles[1].p == mateP - 2, "level 9 moves 2 behind the teammate and keeps the 7 (" .. tostring(c.text) .. ")")
    local after = c.state
    check(JB.comboSevenBonus(after, 1, true) > 0, "from there a 7 bonks and finishes")
end

print("== from flags")
do
    -- flag 1 (BOT (Red), seat 4, game turn 7): the 8 back from its exit would land 6 in front of enemy BOT (Green)
    local list = { { seat = 1, kind = 'R', p = 8 } }
    for _ = 1, 4 do list[#list + 1] = { seat = 1, kind = 'S', p = 0 } end
    list[#list + 1] = { seat = 2, kind = 'R', p = 29 }; for _ = 1, 4 do list[#list + 1] = { seat = 2, kind = 'S', p = 0 } end
    list[#list + 1] = { seat = 3, kind = 'R', p = 48 }; for _ = 1, 4 do list[#list + 1] = { seat = 3, kind = 'S', p = 0 } end
    list[#list + 1] = { seat = 4, kind = 'R', p = 62 }; for _ = 1, 4 do list[#list + 1] = { seat = 4, kind = 'S', p = 0 } end
    local S = JB.newState(4, list)
    local a = JS.choose(S, 4, { '3', '8', '8', '9', 'k', '2' }, { level = 9, time_limit = 0.5 })
    check(a.card ~= '8', "flag 1: no 8 back into the spot 6 in front of an enemy (" .. tostring(a.text) .. ")")
    -- flag 4 (BOT (Green), seat 3, game turn 18): its only marble on the board, no exit card in hand; the 10 bonks
    -- Red and parks on Red's exit cell, where Red (marbles in start) comes out onto it -> Green would be stuck burning
    local l4 = { { seat = 1, kind = 'R', p = 17 }, { seat = 1, kind = 'R', p = 8 } }
    for _ = 1, 3 do l4[#l4 + 1] = { seat = 1, kind = 'S', p = 0 } end
    l4[#l4 + 1] = { seat = 2, kind = 'R', p = 32 }; l4[#l4 + 1] = { seat = 2, kind = 'R', p = 44 }
    for _ = 1, 3 do l4[#l4 + 1] = { seat = 2, kind = 'S', p = 0 } end
    l4[#l4 + 1] = { seat = 3, kind = 'R', p = 52 }; for _ = 1, 4 do l4[#l4 + 1] = { seat = 3, kind = 'S', p = 0 } end
    l4[#l4 + 1] = { seat = 4, kind = 'G', p = 3 }; l4[#l4 + 1] = { seat = 4, kind = 'R', p = 62 }
    for _ = 1, 3 do l4[#l4 + 1] = { seat = 4, kind = 'S', p = 0 } end
    local S4 = JB.newState(4, l4)
    local g4 = JS.choose(S4, 3, { '6', '7', '10', '4', '2', '6' }, { level = 9, time_limit = 0.5 })
    check(not (g4.card == '10'), "flag 4: no parking the only marble on an enemy exit with no exit card (" .. tostring(g4.text) .. ")")
    -- flag 5 (BOT (Red), seat 4, game turn 23): finish untidy (a marble on cell 3, 4 and 5 empty); the 8 back from its exit
    -- would line up another marble to enter (and land 10 in front of enemy Green) -> clean finish first, no 8
    local l5 = { { seat = 1, kind = 'R', p = 29 }, { seat = 1, kind = 'R', p = 8 } }
    for _ = 1, 3 do l5[#l5 + 1] = { seat = 1, kind = 'S', p = 0 } end
    l5[#l5 + 1] = { seat = 2, kind = 'R', p = 32 }; l5[#l5 + 1] = { seat = 2, kind = 'R', p = 57 }
    for _ = 1, 3 do l5[#l5 + 1] = { seat = 2, kind = 'S', p = 0 } end
    l5[#l5 + 1] = { seat = 3, kind = 'R', p = 44 }; for _ = 1, 4 do l5[#l5 + 1] = { seat = 3, kind = 'S', p = 0 } end
    l5[#l5 + 1] = { seat = 4, kind = 'G', p = 3 }; l5[#l5 + 1] = { seat = 4, kind = 'R', p = 62 }
    for _ = 1, 3 do l5[#l5 + 1] = { seat = 4, kind = 'S', p = 0 } end
    local S5 = JB.newState(4, l5)
    local r5 = JS.choose(S5, 4, { '3', '8', '9', '3', '5', 'j' }, { level = 9, time_limit = 0.5 })
    check(r5.card ~= '8', "flag 5: no 8 back while the finish is untidy (" .. tostring(r5.text) .. ")")
    -- clean finish: a finish marble on cell 3 with 4-5 empty is untidy; moving it to 5 with a 2 is preferred
    local saved = JB.STRATEGY
    JB.STRATEGY = 1
    check(JB.untidyCells(S5, 4) == 2, "finish 3 with 4 and 5 empty = 2 untidy cells")
    JB.STRATEGY = saved
    local lt = { { seat = 1, kind = 'G', p = 3 }, { seat = 1, kind = 'R', p = 30 } }
    for _ = 1, 3 do lt[#lt + 1] = { seat = 1, kind = 'S', p = 0 } end
    for s = 2, 4 do for _ = 1, 5 do lt[#lt + 1] = { seat = s, kind = 'S', p = 0 } end end
    local St = JB.newState(4, lt)
    local t9 = JS.choose(St, 1, { '2' }, { level = 9, time_limit = 0.4 })
    -- flag 8 (BOT (Red), seat 4, game turn 31): another 8 back from the exit into danger with an untidy finish
    local l8 = { { seat = 1, kind = 'R', p = 44 }, { seat = 1, kind = 'R', p = 8 } }
    for _ = 1, 3 do l8[#l8 + 1] = { seat = 1, kind = 'S', p = 0 } end
    l8[#l8 + 1] = { seat = 2, kind = 'R', p = 61 }; for _ = 1, 4 do l8[#l8 + 1] = { seat = 2, kind = 'S', p = 0 } end
    l8[#l8 + 1] = { seat = 3, kind = 'G', p = 5 }; l8[#l8 + 1] = { seat = 3, kind = 'G', p = 1 }
    for _ = 1, 3 do l8[#l8 + 1] = { seat = 3, kind = 'S', p = 0 } end
    l8[#l8 + 1] = { seat = 4, kind = 'G', p = 3 }; l8[#l8 + 1] = { seat = 4, kind = 'G', p = 2 }; l8[#l8 + 1] = { seat = 4, kind = 'R', p = 62 }
    for _ = 1, 2 do l8[#l8 + 1] = { seat = 4, kind = 'S', p = 0 } end
    local r8 = JS.choose(JB.newState(4, l8), 4, { '3', '9', '3', '5', 'j', '8' }, { level = 9, time_limit = 0.5 })
    check(r8.card ~= '8', "flag 8: no unsafe 8 (" .. tostring(r8.text) .. ")")
    -- flag 10 (BOT (Blue), seat 2, game turn 49): 8 back from its exit would land 10 in front of an enemy (White at 8)
    local l10 = { { seat = 1, kind = 'R', p = 19 }, { seat = 1, kind = 'R', p = 8 } }
    for _ = 1, 3 do l10[#l10 + 1] = { seat = 1, kind = 'S', p = 0 } end
    l10[#l10 + 1] = { seat = 2, kind = 'G', p = 5 }; l10[#l10 + 1] = { seat = 2, kind = 'R', p = 26 }
    for _ = 1, 3 do l10[#l10 + 1] = { seat = 2, kind = 'S', p = 0 } end
    l10[#l10 + 1] = { seat = 3, kind = 'G', p = 5 }; l10[#l10 + 1] = { seat = 3, kind = 'G', p = 4 }
    l10[#l10 + 1] = { seat = 3, kind = 'R', p = 50 }; l10[#l10 + 1] = { seat = 3, kind = 'R', p = 44 }; l10[#l10 + 1] = { seat = 3, kind = 'S', p = 0 }
    l10[#l10 + 1] = { seat = 4, kind = 'G', p = 3 }; l10[#l10 + 1] = { seat = 4, kind = 'G', p = 2 }
    l10[#l10 + 1] = { seat = 4, kind = 'R', p = 67 }; l10[#l10 + 1] = { seat = 4, kind = 'R', p = 62 }; l10[#l10 + 1] = { seat = 4, kind = 'S', p = 0 }
    local r10 = JS.choose(JB.newState(4, l10), 2, { '2', '8', '2', '8', '9', '8' }, { level = 9, time_limit = 0.5 })
    check(r10.card ~= '8', "flag 10: no 8 back to 10 in front of an enemy (" .. tostring(r10.text) .. ")")
    -- flag 11 (BOT (Red), seat 4, game turn 59): marbles on its exit cell (62) and 5 past it (67): don't nudge the one on the exit
    local l11 = { { seat = 1, kind = 'R', p = 31 }, { seat = 1, kind = 'R', p = 18 } }
    for _ = 1, 3 do l11[#l11 + 1] = { seat = 1, kind = 'S', p = 0 } end
    l11[#l11 + 1] = { seat = 2, kind = 'G', p = 5 }; l11[#l11 + 1] = { seat = 2, kind = 'R', p = 26 }
    for _ = 1, 3 do l11[#l11 + 1] = { seat = 2, kind = 'S', p = 0 } end
    l11[#l11 + 1] = { seat = 3, kind = 'G', p = 5 }; l11[#l11 + 1] = { seat = 3, kind = 'G', p = 4 }
    l11[#l11 + 1] = { seat = 3, kind = 'R', p = 58 }; l11[#l11 + 1] = { seat = 3, kind = 'R', p = 44 }; l11[#l11 + 1] = { seat = 3, kind = 'S', p = 0 }
    l11[#l11 + 1] = { seat = 4, kind = 'G', p = 3 }; l11[#l11 + 1] = { seat = 4, kind = 'G', p = 2 }
    l11[#l11 + 1] = { seat = 4, kind = 'R', p = 67 }; l11[#l11 + 1] = { seat = 4, kind = 'R', p = 62 }; l11[#l11 + 1] = { seat = 4, kind = 'S', p = 0 }
    local S11 = JB.newState(4, l11)
    local r11 = JS.choose(S11, 4, { '9', '3', '5', '9', '5', '5' }, { level = 9, time_limit = 0.5 })
    check(S11.marbles[r11.steps[1].mi].p ~= 62, "flag 11: the marble on the exit cell stays, the front one moves (" .. tostring(r11.text) .. ")")
    -- flag 6: a 7 that cleans house (teammate's finish marble 3 -> 5) is a legitimate 7 now
    local S6 = JB.newState(4, { { seat = 2, kind = 'R', p = 32 }, { seat = 4, kind = 'G', p = 3 } })
    local tidy = nil
    for _, a in ipairs(JB.legalActions(S6, 2, { '7' })) do
        if #a.steps == 2 and a.steps[2].kind == 'G' and a.steps[2].p == 5 then tidy = a end
    end
    check(tidy ~= nil and JB.entersFinish(S6, tidy), "flag 6: a house-cleaning 7 counts as a proper 7")
    check(t9.state.marbles[1].kind == 'G' and t9.state.marbles[1].p == 5, "a 2 tidies the finish (3 -> 5) instead of moving on the ring (" .. tostring(t9.text) .. ")")
    check(JB.burnRisk(g4.state, 3, { '7', '10', '4', '2', '6' }) == 0, "flag 4: the chosen move leaves no burn risk")
end

------------------------------------------------------------------------
-- Simulated games: Team 1 (seats 1, 3) at level A vs Team 2 (seats 2, 4) at level B, real deck and hands.
local function playGame(levelA, levelB, limit, maxTurns)
    local N = 4
    local list = {}
    for s = 1, N do for _ = 1, 5 do list[#list + 1] = { seat = s, kind = 'S', p = 0 } end end
    local S = JB.newState(N, list)
    local deck, discard = {}, {}
    for _, c in ipairs(DECK) do deck[#deck + 1] = c end
    local function shuffle(t) for i = #t, 2, -1 do local j = math.random(i); t[i], t[j] = t[j], t[i] end end
    shuffle(deck)
    local function draw()
        if #deck == 0 then deck, discard = discard, {}; shuffle(deck) end
        return table.remove(deck)
    end
    local hands = {}
    for s = 1, N do hands[s] = {}; for i = 1, 6 do hands[s][i] = draw() end end
    local seat = math.random(N)
    for turn = 1, maxTurns do
        local lvl = (seat % 2 == 1) and levelA or levelB
        local a = JS.choose(S, seat, hands[seat], { level = lvl, time_limit = limit })
        for i, c in ipairs(hands[seat]) do if c == a.card then table.remove(hands[seat], i); break end end
        discard[#discard + 1] = a.card
        hands[seat][#hands[seat] + 1] = draw()
        if not a.burn then S = a.state end
        for team = 0, 1 do
            local done = true
            for s = 1, N do if s % 2 == team and not JB.isFinished(S, s) then done = false end end
            if done then return (team == 1) and 1 or 2, turn end
        end
        seat = (seat % N) + 1
    end
    return 0, maxTurns
end

print("== flags 23-25: K kept over J/Q, multiples first, Joker waits")
do
    local function opening(onBoard)
        local l = {}
        for seat = 1, 6 do
            local n = 4
            if onBoard[seat] then l[#l + 1] = { seat = seat, kind = 'R', p = onBoard[seat] }; n = 3 end
            for _ = 0, n do l[#l + 1] = { seat = seat, kind = 'S', p = 0 } end
        end
        return JB.newState(6, l)
    end
    -- flag 23: BOT (Green), first move, hand K Q Q 10 5 Q -> leave start with a Q (holds three), keep the K
    local g = JS.choose(opening({}), 3, { 'k', 'q', 'q', '10', '5', 'q' }, { level = 9, time_limit = 0.3 })
    check(g.card == 'q', "flag 23: leaves start with a Q, not the K (" .. tostring(g.text) .. ")")
    -- flag 24: BOT (Red), hand Joker K K J 10 2 -> leave start with the J
    local r = JS.choose(opening({ [3] = 44 }), 4, { '$', 'k', 'k', 'j', '10', '2' }, { level = 9, time_limit = 0.3 })
    check(r.card == 'j', "flag 24: leaves start with the J, not a K or the Joker (" .. tostring(r.text) .. ")")
    -- flag 25: BOT (Red), turn 8, everyone has one marble on its exit; Joker onto a teammate is not worth it yet
    local S = opening({ [1] = 8, [2] = 26, [3] = 49, [4] = 62, [5] = 80, [6] = 98 })
    local j = JS.choose(S, 4, { '$', 'k', 'j', '10', '2', 'j' }, { level = 9, time_limit = 0.3 })
    check(j.card ~= '$', "flag 25: keeps the Joker for a bigger payoff (" .. tostring(j.text) .. ")")
end

print("== game plan: what the kept cards can do next turn")
do
    local function runnerAt(d)
        local p = ((JB.entrance(1) - d - 1) % 72) + 1
        local l = { { seat = 1, kind = 'R', p = p } }
        for _ = 1, 4 do l[#l + 1] = { seat = 1, kind = 'S', p = 0 } end
        for s = 2, 4 do for _ = 1, 5 do l[#l + 1] = { seat = s, kind = 'S', p = 0 } end end
        return JB.newState(4, l)
    end
    JB.STRATEGY = 1
    local near = JB.planValue(runnerAt(4), 1, { '9' })       -- the 9 takes it deep into the finish next turn
    local far = JB.planValue(runnerAt(60), 1, { '9' })       -- the 9 is just another step (safe cells both ways)
    check(near > far + 60, string.format("a kept 9 that finishes next turn is a plan (%.0f vs %.0f)", near, far))
    check(JB.planValue(runnerAt(4), 1, { '$' }) == 0, "a Joker alone is not a plan")
    -- level 9 search: plan values are attached to the best root moves
    local a = JS.choose(runnerAt(20), 1, { '9', '2', '5' }, { level = 9, time_limit = 0.5, debug = true })
    local planned = 0
    for _, x in ipairs(a.all) do if x.plan then planned = planned + 1 end end
    check(planned > 0, "level 9 scores a plan for its best moves (" .. planned .. ")")
    local b = JS.choose(runnerAt(20), 1, { '9', '2', '5' }, { level = 5, time_limit = 0.5, debug = true })
    local none = true
    for _, x in ipairs(b.all) do if x.plan then none = false end end
    check(none, "level 5 has no game plan")
end

print("== only one real choice: no search")
do
    local l = {}
    for s = 1, 4 do for _ = 1, 5 do l[#l + 1] = { seat = s, kind = 'S', p = 0 } end end
    local S = JB.newState(4, l)
    local slow = 0
    local a = JS.choose(S, 1, { 'j', '2', '5', 'q', 'k', '9' }, { level = 9, time_limit = 5, clock = function() slow = slow + 1; return os.clock() end })
    check(a.only and a.depth == 0 and a.elapsed < 0.5, "all in start, J/Q/K only bring one out: decided at once (" .. tostring(a.text) .. ")")
    check(a.card == 'j' or a.card == 'q', "and it uses a J or Q, not the K (" .. tostring(a.card) .. ")")
end

print("== flag 31: the defender doesn't stop 2 or 3 past its exit")
do
    local l = { { seat = 1, kind = 'R', p = JB.exitCell(1) } }
    for _ = 1, 4 do l[#l + 1] = { seat = 1, kind = 'S', p = 0 } end
    for s = 2, 8 do for _ = 1, 5 do l[#l + 1] = { seat = s, kind = 'S', p = 0 } end end
    local S = JB.newState(8, l)
    local a = JS.choose(S, 1, { '3', '2', '9', '5', '4', '6' }, { level = 9, time_limit = 0.4 })
    local k = (a.state.marbles[1].p - JB.exitCell(1)) % S.R
    check(k ~= 2 and k ~= 3, "second move of the game: not 2 or 3 past the exit (" .. tostring(a.text) .. ")")
end

print("== card values: 10s and aces are kept, enemy entrance / -8 spot are never landed on")
do
    local l = { { seat = 1, kind = 'R', p = JB.exitCell(1) }, { seat = 1, kind = 'R', p = JB.exitCell(1) + 30 } }
    for _ = 1, 3 do l[#l + 1] = { seat = 1, kind = 'S', p = 0 } end
    for s = 2, 4 do for _ = 1, 5 do l[#l + 1] = { seat = s, kind = 'S', p = 0 } end end
    local S = JB.newState(4, l)
    local a = JS.choose(S, 1, { '10', '10', 'j', '9' }, { level = 9, time_limit = 0.3 })
    check(a.card ~= '10', "10 10 J 9: moves with the J or 9, keeps the 10s (" .. tostring(a.text) .. ")")
    local b = JS.choose(S, 1, { 'a', '2', '6', '10' }, { level = 9, time_limit = 0.3 })
    check(b.card ~= 'a', "holds the ace for later (" .. tostring(b.text) .. ")")
    -- the landing rule itself: a plain move onto an enemy's finish entrance (enemy has a marble out) is penalised
    local l2 = { { seat = 1, kind = 'R', p = JB.entrance(2) - 3 }, { seat = 2, kind = 'R', p = 40 } }
    for s = 1, 4 do for _ = 1, (s <= 2 and 4 or 5) do l2[#l2 + 1] = { seat = s, kind = 'S', p = 0 } end end
    local S2 = JB.newState(4, l2)
    JB.STRATEGY = 1
    local onSpot, behind
    for _, x in ipairs(JB.legalActions(S2, 1, { '3', '2' })) do
        if x.steps[1].mi == 1 then
            if x.card == '3' then onSpot = JB.spotLandingPenalty(S2, x) else behind = JB.spotLandingPenalty(S2, x) end
        end
    end
    check(onSpot and onSpot > 0 and behind == 0, "landing on an enemy's finish entrance is penalised, stopping behind it is not")
end

print("== safe spot in front of an enemy: 3 behind it, the J lands 8 in front (not 1-6)")
do
    local enemyP = 50
    local l = { { seat = 1, kind = 'R', p = enemyP - 3 }, { seat = 1, kind = 'R', p = JB.exitCell(1) }, { seat = 2, kind = 'R', p = enemyP } }
    for s = 1, 4 do for _ = 1, (s == 1 and 3 or (s == 2 and 4 or 5)) do l[#l + 1] = { seat = s, kind = 'S', p = 0 } end end
    local S = JB.newState(4, l)
    local a = JS.choose(S, 1, { 'j', '4', '5' }, { level = 9, time_limit = 0.3 })
    local d = (a.state.marbles[1].p - enemyP) % S.R
    check(not (d >= 1 and d <= 6), "doesn't end 1-6 in front of the enemy (" .. tostring(a.text) .. ", " .. d .. " in front)")
end

print("== flag 60: the teammate's part of a 7 can go first (bonk my marble to my entrance, then carry it in)")
do
    -- seat 2 (me) has a marble 2 cells past teammate seat 4's marble; teammate +2 bonks mine to my entrance, mine +5
    local mine = 40
    local l = { { seat = 2, kind = 'R', p = mine }, { seat = 4, kind = 'R', p = mine - 2 } }
    for s = 1, 4 do for _ = 1, (s % 2 == 0 and 4 or 5) do l[#l + 1] = { seat = s, kind = 'S', p = 0 } end end
    local S = JB.newState(4, l)
    local found = false
    for _, a in ipairs(JB.legalActions(S, 2, { '7' })) do
        local m = a.state.marbles[1]
        if m.kind == 'G' and m.p == 5 then found = true end
    end
    check(found, "a 7 exists that bonks my marble to my entrance and then carries it to finish cell 5")
    local c = JS.choose(S, 2, { '7', '9', '3' }, { level = 9, time_limit = 0.3 })
    check(c.state.marbles[1].kind == 'G', "level 9 plays it (" .. tostring(c.text) .. ")")
end

print("== a gap you can close next turn is fine (2v2 all-bot game: 3 in, Ace next turn)")
do
    local e = JB.entrance(1)
    local l = { { seat = 1, kind = 'G', p = 5 }, { seat = 1, kind = 'R', p = e }, { seat = 1, kind = 'R', p = ((e - 3 - 1) % 72) + 1 },
                { seat = 1, kind = 'R', p = JB.exitCell(1) } }
    l[#l + 1] = { seat = 1, kind = 'S', p = 0 }
    for s = 2, 4 do for _ = 1, 5 do l[#l + 1] = { seat = s, kind = 'S', p = 0 } end end
    local S = JB.newState(4, l)
    local a = JS.choose(S, 1, { '10', '2', '3', 'a', '9' }, { level = 9, time_limit = 0.5 })
    local m = a.state.marbles[2]
    check(m.kind == 'G' and m.p == 3, "plays the 3 into finish cell 3, keeping the A to close cell 4 (" .. tostring(a.text) .. ")")
end

print("== teammate term: at TTS depth (2 plies) the bot still sees its teammate's turn (2v2 game, turn 177)")
do
    local b = { {'G',4,1},{'G',5,1},{'G',3,1},{'G',2,1},{'G',1,1},{'G',5,2},{'G',4,2},{'G',3,2},{'G',2,2},{'R',3,2},
                {'G',4,3},{'G',5,3},{'G',3,3},{'R',34,3},{'G',2,3},{'G',3,4},{'R',71,4},{'G',5,4},{'G',4,4},{'R',53,4} }
    local l = {}
    for i, x in ipairs(b) do l[i] = { kind = x[1], p = x[2], seat = x[3] } end
    local S = JB.newState(4, l)
    -- without the dedicated rule (JB.finishReachBonus) the teammate term alone must keep Green's last marble in reach
    local saved = JB.finishReachBonus
    JB.finishReachBonus = function() return 0 end
    local a = JS.choose(S, 1, { '8', '2', '8', '9', '2', 'j' }, { level = 9, time_limit = 5, max_depth = 2, debug = true })
    JB.finishReachBonus = saved
    check(a.card == '2' and a.steps[1].mi == 14, "Black plays the 2 on Green's last marble, leaving it a 4 from the win (" .. tostring(a.text) .. ")")
    check(a.team ~= nil and a.team > 0, "the move carries a teammate value (" .. tostring(a.team) .. ")")
    local after2, after8
    for _, x in ipairs(JB.legalActions(S, 1, { '2', '8' })) do
        if x.steps[1].mi == 14 then if x.card == '2' then after2 = x.state else after8 = x.state end end
    end
    local ctx = { nodes = 0 }
    check(JS.teamReply(after2, 3, 1, ctx) > JS.teamReply(after8, 3, 1, ctx), "Green's expected reply is better with its marble in reach")
end

print("== a marble near its entrance doesn't run past it to dodge a bonk (another lap)")
do
    local b = "G5,G4,G3,R69,S0,R71,S0,S0,S0,S0,R55,S0,S0,S0,S0,S0,S0,S0,S0,S0"
    local l, i = {}, 0
    for k, p in b:gmatch("(%a)(%d+)") do i = i + 1; l[i] = { seat = math.floor((i - 1) / 5) + 1, kind = k, p = tonumber(p) } end
    local S = JB.newState(4, l)
    local a = JS.choose(S, 1, { '4', '4', '3', '3', '9', '6' }, { level = 9, time_limit = 5, max_depth = 2 })
    check(a.card ~= '9', "doesn't play the 9 past its own entrance (" .. tostring(a.text) .. ")")
end

print("== any two cards that add up to a clean finish (not just 3 + A), TTS depth")
do
    local STEP = { a = 1, ['2'] = 2, ['3'] = 3, ['4'] = 4, ['5'] = 5, ['6'] = 6, ['9'] = 9, ['10'] = 10, j = 11, q = 12 }
    local e = JB.entrance(1)
    for _, case in ipairs({ { '4', '6' }, { '3', '9' }, { '2', '10' }, { '5', '5' }, { 'a', '10' }, { '3', '4' }, { '2', '6' }, { '4', '9' } }) do
        local x, y = case[1], case[2]
        local d = STEP[x] + STEP[y] - 3
        -- seat 1: finish cells 5 and 4 filled, marble d before its entrance (needs d + 3 to finish cell 3), 1 in start
        local l = { { seat = 1, kind = 'G', p = 5 }, { seat = 1, kind = 'G', p = 4 }, { seat = 1, kind = 'R', p = ((e - d - 1) % 72) + 1 },
                    { seat = 1, kind = 'R', p = JB.exitCell(1) + 20 }, { seat = 1, kind = 'S', p = 0 } }
        for s = 2, 4 do for _ = 1, 5 do l[#l + 1] = { seat = s, kind = 'S', p = 0 } end end
        local S = JB.newState(4, l)
        local hand = { x, y, '9', '9' }   -- neutral fillers (8s add a real alternative: out with the face card, then 8 back)
        local a = JS.choose(S, 1, hand, { level = 9, time_limit = 5, max_depth = 2 })
        local m = a.state.marbles[3]
        local ok = m.kind == 'G' and m.p == 3
        if not ok and m.kind == 'G' and m.p < 3 then
            -- entered leaving one gap that the kept card closes next turn (user: "play the 3 and fix it later")
            local other = (a.card == x) and y or x
            local k, p = JB.numericTarget(a.state, 3, STEP[other], true)
            ok = k == 'G' and p == 3
        end
        if not ok and m.kind == 'R' and a.steps[1].mi == 3 then
            -- started the combo: the other card finishes it next turn
            local other = (a.card == x) and y or x
            local k, p = JB.numericTarget(a.state, 3, STEP[other], true)
            ok = k == 'G' and p == 3
        end
        check(ok, string.format("%s + %s from %d out: starts the combo (%s)", x, y, d + 3, tostring(a.text)))
    end
end

print("== face card: finish with it only if a defender is near or the small cards can't (user)")
do
    local e = JB.entrance(1)
    local function pick(d, hand, enemyBehind)
        local runner = ((e - d - 1) % 72) + 1
        local l = { { seat = 1, kind = 'G', p = 5 }, { seat = 1, kind = 'G', p = 4 }, { seat = 1, kind = 'R', p = runner },
                    { seat = 1, kind = 'R', p = JB.exitCell(1) + 20 }, { seat = 1, kind = 'S', p = 0 } }
        for s = 2, 4 do for k = 1, 5 do
            if s == 2 and k == 1 and enemyBehind then l[#l + 1] = { seat = 2, kind = 'R', p = ((runner - enemyBehind - 1) % 72) + 1 }
            else l[#l + 1] = { seat = s, kind = 'S', p = 0 } end
        end end
        local a = JS.choose(JB.newState(4, l), 1, hand, { level = 9, time_limit = 5, max_depth = 2 })
        return a, a.state.marbles[5].kind ~= 'S', a.state.marbles[3].kind == 'G'
    end
    local a, out = pick(9, { 'q', '9', '3', '5' })
    check(out and a.card == 'q', "no defender, 9 + 3 can finish: the Q brings a marble out (" .. tostring(a.text) .. ")")
    a, out = pick(8, { 'j', '6', '5', '9' })
    check(out and a.card == 'j', "no defender, 6 + 5 can finish: the J brings a marble out (" .. tostring(a.text) .. ")")
    local fin
    a, out, fin = pick(10, { 'k', '6', '4', '2' })
    check(fin and a.card == 'k', "no two small cards finish it: the K finishes (" .. tostring(a.text) .. ")")
    a, out, fin = pick(9, { 'q', '9', '3', '5' }, 3)
    check(fin and a.card == 'q', "defender 3 behind: the Q finishes (" .. tostring(a.text) .. ")")
end

print("== near a defender a small card lands 7 or 8 in front of it (user), parks only out of its range")
do
    for behind = 1, 4 do
        local runner = 40     -- teammate seat 3's exit is cell 44: parking there 1-6 in front of an enemy is no good
        local l = { { seat = 1, kind = 'R', p = runner }, { seat = 1, kind = 'R', p = JB.exitCell(1) } }
        for _ = 1, 3 do l[#l + 1] = { seat = 1, kind = 'S', p = 0 } end
        for s = 2, 4 do for k = 1, 5 do
            if s == 2 and k == 1 then l[#l + 1] = { seat = 2, kind = 'R', p = runner - behind } else l[#l + 1] = { seat = s, kind = 'S', p = 0 } end
        end end
        local a = JS.choose(JB.newState(4, l), 1, { '2', '3', '4', '5', '6', '9' }, { level = 9, time_limit = 5, max_depth = 2 })
        local m = a.state.marbles[1]
        local ahead = (m.p - (runner - behind)) % 72
        check(m.kind == 'R' and (ahead == 7 or ahead == 8 or ahead > 13), string.format("enemy %d behind: lands %d in front (%s)", behind, ahead, tostring(a.text)))
    end
end

print("== 2v2 all-bot game 2026-11-11: the user's flags, at TTS depth (2 plies)")
do
    local function board(b)
        local l, i = {}, 0
        for k, p in b:gmatch("(%a)(%d+)") do i = i + 1; l[i] = { seat = math.floor((i - 1) / 5) + 1, kind = k, p = tonumber(p) } end
        return JB.newState(4, l)
    end
    local function hand(h) local t = {} for c in h:gmatch("%S+") do t[#t + 1] = c end return t end
    local function pick(b, seat, h) return JS.choose(board(b), seat, hand(h), { level = 9, time_limit = 5, max_depth = 2 }) end
    local a = pick("R14,R8,S0,S0,S0,R29,S0,S0,S0,S0,R44,S0,S0,S0,S0,R66,S0,S0,S0,S0", 2, "a 8 2 j 7 9")
    check(a.text ~= "9: seat2#6", "turn 10: Blue doesn't stop 6 behind Green on its exit (its 8 back lands behind) (" .. a.text .. ")")
    a = pick("R23,R8,S0,S0,S0,R26,S0,S0,S0,S0,G5,S0,S0,S0,S0,R66,R54,S0,S0,S0", 2, "a 8 2 7 9 6")
    check(a.card ~= '7', "turn 18: no wasteful 7 taking Red from 3 out to 1 out (" .. a.text .. ")")
    a = pick("R30,R8,S0,S0,S0,R37,R26,S0,S0,S0,G5,R50,S0,S0,S0,R70,R56,R62,S0,S0", 4, "10 3 9 10 4 k")
    check(a.state.marbles[17].kind == 'G', "turn 28: Red's marble 1 out with Green 6 behind escapes into the finish (" .. a.text .. ")")
    a = pick("R72,S0,S0,S0,S0,G5,G4,R31,R26,S0,G5,R55,G4,S0,S0,G5,R22,R3,R62,S0", 1, "$ $ 4 8 6 4")
    -- (cell 1 is fine now: the second 4 then takes it to cell 5, clean - "play the one that makes it safe first")
    local m85 = a.state.marbles[1]
    local fixable = m85.kind == 'G' and (m85.p == 5 or m85.p == 1)
    check(fixable, "turn 85: escapes into the finish with an entry the kept cards make clean (" .. a.text .. ")")
    a = pick("R44,R21,R8,S0,S0,S0,R26,S0,S0,S0,G5,R53,S0,S0,S0,R57,R62,R9,S0,S0", 2, "a 8 2 7 5 10")
    check(a.state.marbles[16].kind == 'G' and a.state.marbles[16].p == 5, "turn 50: Blue's 7 puts Red's marble in cleanly at cell 5 (" .. a.text .. ")")
    a = pick("R44,R21,R9,S0,S0,S0,R29,S0,S0,S0,G5,R59,S0,S0,S0,G5,R62,S0,S0,S0", 2, "a 8 2 5 10 8")
    check(a.card == '8' and (a.bumps or 0) > 0, "turn 54: Blue's 8 back bonks Black and lands on Blue's own entrance (" .. a.text .. ")")
    a = pick("R8,R55,S0,S0,S0,G5,G4,R31,R18,R21,G5,G3,G4,R44,S0,G5,R26,R3,R72,S0", 1, "$ 4 8 6 4 k")
    check(a.card == 'k', "turn 93: Black's K bonks Blue's marble on Blue's entrance (2 home) (" .. a.text .. ")")
    a = pick("G4,G5,G3,S0,S0,G5,G4,G2,S0,G3,G5,G3,G4,R72,R24,G5,G4,S0,S0,S0", 2, "10 10 7 9 $ 10")
    check(a.text:find("seat3#15", 1, true) ~= nil, "turn 118: the forced Joker doesn't land on Black's -8 spot (" .. a.text .. ")")
    a = pick("G4,G5,G3,R8,S0,G5,G4,G2,R72,G3,G5,G3,G4,R44,R24,G5,G4,S0,S0,S0", 2, "10 10 7 9 10 a")
    local m = a.state.marbles[9]
    local ahead = (m.p - 8) % 72
    check(not (ahead >= 1 and ahead <= 6), "turn 122: Blue's last marble doesn't land 1-6 in front of Black (" .. a.text .. ")")
end

print("== fire the park: a teammate parked on my exit gets catapulted when I come out (2v2 game #2, turn 126)")
do
    local l, i = {}, 0
    for k, p in ("G5,G4,R9,S0,S0,G5,R62,G3,G4,R51,G5,G4,R44,G3,S0,G5,G4,G3,R23,S0"):gmatch("(%a)(%d+)") do i = i + 1; l[i] = { seat = math.floor((i - 1) / 5) + 1, kind = k, p = tonumber(p) } end
    local a = JS.choose(JB.newState(4, l), 4, { '$', '3', '7', '8', 'a', '7' }, { level = 9, time_limit = 5, max_depth = 2 })
    check(a.card == 'a' and a.text:find("bonks teammate", 1, true) ~= nil, "Red's A comes out and sends Blue's parked marble to its entrance (" .. a.text .. ")")
end

print("== 2v2 all-bot game 3 (2026-11-11, 4 s think): the user's flags, at TTS depth")
do
    local function board(bs)
        local l, i = {}, 0
        for k, p in bs:gmatch("(%a)(%d+)") do i = i + 1; l[i] = { seat = math.floor((i - 1) / 5) + 1, kind = k, p = tonumber(p) } end
        return JB.newState(4, l)
    end
    local function pick(bs, seat, h) local t = {} for c in h:gmatch("%S+") do t[#t + 1] = c end
        return JS.choose(board(bs), seat, t, { level = 9, time_limit = 5, max_depth = 2 }) end
    local a = pick("R25,S0,S0,S0,S0,S0,S0,S0,S0,S0,R53,R36,S0,S0,S0,R71,R62,S0,S0,S0", 3, "3 a 2 6 2 q")
    check(a.card == '6' and a.state.marbles[12].kind == 'G', "turn 18: Green plays the 6 in first (safe), keeping the 2 to finish it (" .. a.text .. ")")
    a = pick("G5,R8,S0,S0,S0,R26,S0,S0,S0,S0,R53,G5,R46,S0,S0,R22,R62,S0,S0,S0", 4, "7 10 5 5 a q")
    check(not (a.card == '7' and a.state.marbles[6].kind == 'R' and a.state.marbles[6].p ~= 26), "turn 31: Red's 7 doesn't carry Blue past its entrance after bonking it there (" .. a.text .. ")")
    a = pick("G5,R23,R8,S0,S0,R32,R7,S0,S0,S0,R58,G5,R55,R44,S0,G5,G4,R67,S0,S0", 2, "8 8 8 8 $ 8")
    check(a.card ~= '$', "turn 49: Blue keeps the Joker when it holds plain 8s (" .. a.text .. ")")
end

print("== game 3 Jokers (user: 'terrible joker' x3, 'had the 8 to bonk blue but used the joker')")
do
    local function pick(bs, seat, h)
        local l, i = {}, 0
        for k, p in bs:gmatch("(%a)(%d+)") do i = i + 1; l[i] = { seat = math.floor((i - 1) / 5) + 1, kind = k, p = tonumber(p) } end
        local t = {} for c in h:gmatch("%S+") do t[#t + 1] = c end
        return JS.choose(JB.newState(4, l), seat, t, { level = 9, time_limit = 5, max_depth = 2 })
    end
    local a = pick("G5,R47,G4,R23,G3,R8,G3,G5,G4,R26,G4,G5,S0,R49,G3,G5,G4,G3,R2,S0", 1, "8 2 2 10 $ q")
    check(a.card ~= '$', "turn 128: no Joker jumping Black's marble past its own entrance to bonk Blue (" .. a.text .. ")")
    a = pick("G5,S0,G4,G2,G3,R12,G3,G5,G4,R35,G4,G5,R56,R49,G3,G5,G4,G3,R33,R62", 1, "8 2 4 2 9 $")
    check(a.text:find("bonks teammate", 1, true) ~= nil, "turn 156: forced Joker catapults teammate Green rather than bonk Blue (3 home) (" .. a.text .. ")")
    a = pick("G5,R29,G4,G2,G3,R21,G3,G5,G4,G2,G4,G5,G2,R44,G3,G5,G4,G3,S0,R47", 1, "8 2 8 $ 9 10")
    check(a.card == '8' and (a.bumps or 0) > 0, "turn 216: the 8 does the bonk, the Joker is kept (" .. a.text .. ")")
end

print("== an enemy's -8 spot is fine to land on when that enemy has nobody in start or is burning (user)")
do
    local spot = JB.wrap({ R = 72 }, JB.exitCell(2) - 8)
    local function pen(enemyInStart, burning)
        local l = { { seat = 1, kind = 'R', p = spot - 3 } }
        for _ = 1, 4 do l[#l + 1] = { seat = 1, kind = 'S', p = 0 } end
        l[#l + 1] = { seat = 2, kind = 'R', p = 60 }
        for k = 1, 4 do l[#l + 1] = enemyInStart and { seat = 2, kind = 'S', p = 0 } or { seat = 2, kind = 'G', p = 6 - k } end
        for s = 3, 4 do for _ = 1, 5 do l[#l + 1] = { seat = s, kind = 'S', p = 0 } end end
        local S = JB.newState(4, l)
        JB.BURNING = burning and { [2] = true } or {}
        JB.STRATEGY = 1
        local p
        for _, a in ipairs(JB.legalActions(S, 1, { '3' })) do if a.steps[1].mi == 1 then p = JB.spotLandingPenalty(S, a) end end
        JB.BURNING = {}
        return p
    end
    check(pen(true, false) > 0, "the -8 spot of an enemy with marbles in start is penalised")
    check(pen(false, false) == 0, "no penalty when that enemy has nobody in start")
    check(pen(true, true) == 0, "no penalty when that enemy is burning")
end

print("== 2v2 game 4 (2026-11-11): clean entries over bonks, next-player threats")
do
    local function pick(bs, seat, h, depth)
        local l, i = {}, 0
        for k, p in bs:gmatch("(%a)(%d+)") do i = i + 1; l[i] = { seat = math.floor((i - 1) / 5) + 1, kind = k, p = tonumber(p) } end
        local t = {} for c in h:gmatch("%S+") do t[#t + 1] = c end
        return JS.choose(JB.newState(4, l), seat, t, { level = 9, time_limit = 5, max_depth = depth or 2 })
    end
    local a = pick("G5,R3,S0,S0,S0,G3,G4,G5,R18,S0,R68,R63,R46,R36,R44,R62,R4,S0,S0,S0", 4, "8 k 4 $ 7 j")
    check(a.card == '7' and a.text:find("enters finish", 1, true) ~= nil, "turn 67: Red's 7 puts teammate Blue home cleanly instead of the K bonk (" .. a.text .. ")")
    a = pick("G5,R3,S0,S0,S0,G3,G4,G5,R18,S0,R68,R63,R46,R36,R44,R62,R4,S0,S0,S0", 4, "8 k 4 $ 7 j", 1)
    check(a.card == '7' and a.text:find("enters finish", 1, true) ~= nil, "turn 67 at depth 1 too (" .. a.text .. ")")
    a = pick("G5,R34,S0,S0,S0,G3,G4,G5,R26,S0,R68,R57,R46,R36,S0,S0,R4,R63,S0,S0", 3, "7 k k a 6 7")
    check(a.text:find("enters finish", 1, true) ~= nil, "turn 62: Green's 7 catapults and goes in clean rather than a random bonk (" .. a.text .. ")")
    a = pick("G5,G4,R18,S0,S0,G3,G4,G5,G2,S0,R39,R70,S0,R36,R44,S0,R23,R62,S0,S0", 3, "k 7 7 7 $ 6")
    check(a.text:find("enters finish", 1, true) ~= nil, "turn 86: clean entry over a non-defensive bonk (" .. a.text .. ")")
    a = pick("G5,G4,G3,R35,R8,G3,G4,G5,G2,G1,G5,R48,R44,G4,G3,S0,G5,S0,R7,R62", 4, "8 $ 8 $ 5 3")
    check(a.steps[1].mi ~= 19, "turn 143: Red doesn't land 4 in front of Black on its exit (Black moves next) (" .. a.text .. ")")
end

print("== game 5: clear up the finish first (Green jammed, A in hand)")
do
    local l, i = {}, 0
    for k, p in ("G4,G5,G3,G1,G2,G5,G4,G3,G2,G1,G2,G5,G1,R36,G3,G3,G5,R54,G4,G2"):gmatch("(%a)(%d+)") do i = i + 1; l[i] = { seat = math.floor((i - 1) / 5) + 1, kind = k, p = tonumber(p) } end
    local a = JS.choose(JB.newState(4, l), 3, { '10', '7', 'j', '7', '3', 'a' }, { level = 9, time_limit = 5, max_depth = 2 })
    check(a.card == 'a' and a.state.marbles[15].kind == 'G' and a.state.marbles[15].p == 4, "turn 195: the A moves the cell-3 marble to cell 4 (" .. a.text .. ")")
end

print("== game 5: on its entrance with no card to go in, the 8 back beats running past (a lap)")
do
    local l, i = {}, 0
    for k, p in ("G4,G5,G3,R3,S0,G5,G4,G3,R26,S0,R8,G5,R44,R43,S0,R62,S0,S0,S0,S0"):gmatch("(%a)(%d+)") do i = i + 1; l[i] = { seat = math.floor((i - 1) / 5) + 1, kind = k, p = tonumber(p) } end
    local S = JB.newState(4, l)
    local a = JS.choose(S, 1, { '4', '10', '9', '6', '9', '8' }, { level = 9, time_limit = 5, max_depth = 2 })
    check(a.card == '8', "turn 93: Black plays the 8 back (the 10 then goes in) (" .. a.text .. ")")
    JB.STRATEGY = 1
    for _, x in ipairs(JB.legalActions(S, 1, { '8' })) do
        check(JB.passEntrancePenalty(S, x) == 0, "an 8 backwards never counts as running past the entrance")
    end
end

print("== games 5-6 (2026-11-11) flags")
do
    local function pick(bs, seat, h)
        local l, i = {}, 0
        for k, p in bs:gmatch("(%a)(%d+)") do i = i + 1; l[i] = { seat = math.floor((i - 1) / 5) + 1, kind = k, p = tonumber(p) } end
        local t = {} for c in h:gmatch("%S+") do t[#t + 1] = c end
        return JS.choose(JB.newState(4, l), seat, t, { level = 9, time_limit = 5, max_depth = 2 })
    end
    local a
    a = pick("R24,G5,R8,S0,S0,R43,G5,S0,S0,S0,R61,R36,S0,S0,S0,R62,R54,S0,S0,S0", 3, "10 4 8 10 7 5")
    check((a.card == '5' or a.card == '4') and a.text:find('enters finish', 1, true) ~= nil, "game 6 flag 32: in now (5 or 4), the 7 cleans it later (" .. a.text .. ")")
    a = pick("R49,G5,R11,R8,S0,R66,G5,R26,S0,S0,R44,G5,R39,S0,S0,R57,G5,S0,S0,S0", 3, "10 4 10 7 $ a")
    check(a.card == '4', "game 6 flag 33: the 4 enters, the 7 is kept (" .. a.text .. ")")
    a = pick("R60,G5,R14,G3,S0,G4,G5,R35,R26,S0,R6,G5,G4,R44,S0,G4,G5,R5,R62,S0", 4, "a 8 7 4 4 10")
    check(a.text:find('seat2#8', 1, true) ~= nil, "game 6 flag 34: the 7 sends Blue's runner, not its exit marble (" .. a.text .. ")")
    a = pick("R69,G5,R16,G4,R8,G4,G5,R62,R32,R26,R57,G5,G4,S0,S0,G4,G5,S0,G3,S0", 3, "$ 8 $ 8 $ 7")
    check(a.text:find('seat1#1', 1, true) ~= nil, "game 6 flag 36: the 7 moves Black's marble heading home (" .. a.text .. ")")
    a = pick("R8,G5,R21,G4,G3,G4,G5,G3,S0,S0,R29,G5,G4,R48,G3,G4,G5,R30,G3,R67", 2, "$ 8 $ 4 9 3")
    check(a.text:find('bonks teammate', 1, true) ~= nil, "game 6 flag 40: forced Joker catapults teammate Red, no 3-home bonk (" .. a.text .. ")")
    a = pick("G4,G5,G3,G1,G2,G5,G4,G3,G2,G1,G2,G5,R38,R26,G3,R57,G5,R5,G4,R62", 3, "10 q 7 q 9 2")
    check(not a.text:find('enters finish', 1, true), "game 5 flag 30: no entry behind the jam (would need a third Ace) (" .. a.text .. ")")
end

if arg[1] == "match" then
    print("== match: level 9 (Team 1) vs level 1 (Team 2), 0.1 s per move")
    local wins = { [0] = 0, 0, 0 }
    local games = tonumber(arg[2]) or 6
    for g = 1, games do
        local w, turns = playGame(9, 1, 0.1, 1500)
        wins[w] = wins[w] + 1
        print(string.format("   game %d: %s in %d turns", g, w == 0 and "no result" or ("Team " .. w), turns))
    end
    print(string.format("   level 9 won %d, level 1 won %d, unfinished %d", wins[1], wins[2], wins[0]))
    check(wins[1] > wins[2], "level 9 beats level 1 more often than not")
end

print("== 6-player all-bot game 2026-11-12: flags 41 and 42")
do
    local function board(b)
        local l, i = {}, 0
        for k, p in b:gmatch("(%a)(%d+)") do i = i + 1; l[i] = { seat = math.floor((i - 1) / 5) + 1, kind = k, p = tonumber(p) } end
        return JB.newState(#l // 5, l)
    end
    local function hand(h) local t = {} for c in h:gmatch("%S+") do t[#t + 1] = c end return t end
    local function pick(b, seat, h) return JS.choose(board(b), seat, hand(h), { level = 9, time_limit = 5, max_depth = 2 }) end
    local a = pick("R8,S0,S0,S0,S0,R26,S0,S0,S0,S0,R44,S0,S0,S0,S0,R62,S0,S0,S0,S0,R84,S0,S0,S0,S0,R98,S0,S0,S0,S0", 6, "10 8 5 2 a q")
    check(a.card ~= 'a', "flag 41: Magenta keeps its Ace instead of a 1-step setup (" .. a.text .. ")")
    a = pick("R16,R8,S0,S0,S0,R37,R26,S0,S0,S0,R61,S0,S0,S0,S0,R68,R62,S0,S0,S0,R97,R80,S0,S0,S0,R104,R98,S0,S0,S0", 4, "4 3 3 a q k")
    check(a.state.marbles[16].p ~= 80, "flag 42: Red doesn't bonk Cyan on Cyan's exit (Cyan moves next, 3 in start) (" .. a.text .. ")")
    check(a.card ~= 'a', "flag 42: ... and doesn't spend the Ace on a 1-step nudge either (" .. a.text .. ")")
end

print("== flag 45 (2026-11-12): spare Jokers are cheaper")
do
    local l, i = {}, 0
    for k, p in ("G3,S0,G4,G5,G2,G3,G1,G5,R72,R26,G5,G4,R53,R44,S0,G5,G4,R46,R14,R62"):gmatch("(%a)(%d+)") do i = i + 1; l[i] = { seat = math.floor((i - 1) / 5) + 1, kind = k, p = tonumber(p) } end
    local S = JB.newState(4, l)
    local a = JS.choose(S, 4, { '$', '$', '$', '8', 'a', 'a' }, { level = 9, time_limit = 5, max_depth = 2 })
    check(a.card == '$', "flag 45: with 3 spare Jokers Red jumps (" .. a.text .. "), not a 1-step Ace nudge")
    check(JB.spareJokers(S, 4, { '$', '$', '$', '8', 'a', 'a' }) == 3, "no marbles in start: all 3 Jokers are spare")
    check(JB.spareJokers(S, 3, { '$', '$', '$', '8', '8', '7' }) == 2, "1 Green marble in start, no other exit card: 2 spare")
end

print("== flag 47 (2026-11-14, 8 players): keep the parked marble, Joker the far one")
do
    -- a playtester's Joker: seat 5 has a marble parked on seat 7's exit and another just out of start; seat 7 has a
    -- marble in start. Friendly-bonking the far one sends it to seat 5's entrance (and seat 3 on to its own) and keeps
    -- the parked one for seat 7's free jump later: "I essentially gain a bonk".
    local board = { 'G4','G3','G5','R16','R8','R32','S0','G3','G5','G4','R75','R44','G5','S0','G4','G3','G5','R78','G4','R62',
                    'G5','G4','R116','G3','R86','G5','R130','R98','S0','G4','G5','R141','S0','G4','G3','G4','R134','G5','G3','G2' }
    local list = {}
    for i, b in ipairs(board) do list[i] = { seat = (i - 1) // 5 + 1, kind = b:sub(1, 1), p = tonumber(b:sub(2)) } end
    local S = JB.newState(8, list)
    local a = JS.choose(S, 1, { '$' }, { level = 9, time_limit = 2, rng = function() return 0.5 end })
    local tgt = a.bumpList and a.bumpList[1] and a.bumpList[1].idx
    check(a.card == '$' and tgt == 25, "flag 47: the Joker lands on seat 5's far marble, keeping the parked one (" .. a.text .. ")")
end

print(string.format("\npassed %d, failed %d", passed, failed))
os.exit(failed == 0 and 0 or 1)
