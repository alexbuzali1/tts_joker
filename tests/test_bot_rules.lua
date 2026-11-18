dofile("tests/load_bot.lua")
local JB = JokerBot
local fails, passes = 0, 0
local function check(name, cond) if cond then passes = passes + 1 else fails = fails + 1; print("FAIL: " .. name) end end

-- helper: 4 seats, everyone in start unless overridden
local function mk(N, over)
    local list = {}
    for s = 1, N do for k = 1, 5 do list[#list + 1] = { seat = s, kind = 'S', p = 0 } end end
    local function idx(s, k) return (s - 1) * 5 + k end
    for _, o in ipairs(over or {}) do list[idx(o[1], o[2])] = { seat = o[1], kind = o[3], p = o[4] } end
    return JB.newState(N, list), idx
end

-- geometry
check("entrance seat1", JB.entrance(1) == 3)
check("exit seat1", JB.exitCell(1) == 8)
check("exit = entrance+5", JB.exitCell(3) == JB.entrance(3) + 5)
for idx = 1, 23 * 4 do
    local k, p, s = JB.indexToCell(idx)
    check("roundtrip " .. idx, JB.cellToIndex(k, p, s) == idx)
end
check("idx 4 is goal1 of seat1", select(1, JB.indexToCell(4)) == 'G' and select(2, JB.indexToCell(4)) == 1)
check("idx 9 is ring 4", select(2, JB.indexToCell(9)) == 4)
check("idx 24 is ring 19 (seat2 i=1)", select(2, JB.indexToCell(24)) == 19)

-- leaving start
do
    local S, id = mk(4)
    local acts = JB.legalActions(S, 1, { 'a', '5', 'k', '$' })
    local cards = {}
    for _, a in ipairs(acts) do cards[a.card] = (cards[a.card] or 0) + 1 end
    check("ace exits", cards.a == 1)
    check("king exits", cards.k == 1)
    check("5 can't exit", cards['5'] == nil)
    check("joker w/o targets can't", cards['$'] == nil)
    local a = acts[1]
    check("exit lands on exit cell", a.steps[1].p == JB.exitCell(1))
end

-- forward move and goal entry
do
    local S, id = mk(4, { { 1, 1, 'R', 1 } })   -- seat 1 marble at cell 1, entrance at 3
    local acts = JB.legalActions(S, 1, { '4' })
    local enter, around = false, false
    for _, a in ipairs(acts) do
        if a.steps[1].kind == 'G' then enter = (a.steps[1].p == 2) end   -- 2 to entrance, 4-2=2 -> goal 2
        if a.steps[1].kind == 'R' then around = (a.steps[1].p == 5) end
    end
    check("4 from cell1 can enter goal 2", enter)
    check("4 from cell1 can pass entrance to cell 5", around)
    -- exact landing on entrance stays on ring
    local acts2 = JB.legalActions(S, 1, { '2' })
    check("2 from cell 1 lands on entrance ring", #acts2 == 1 and acts2[1].steps[1].kind == 'R' and acts2[1].steps[1].p == 3)
    -- overshoot finish: 8 steps -> j = 6 illegal to enter but can pass
    local S3 = select(1, mk(4, { { 1, 1, 'R', 1 } }))
    local acts3 = JB.legalActions(S3, 1, { '9' })
    local onlyRing = true
    for _, a in ipairs(acts3) do if a.steps[1].kind == 'G' then onlyRing = false end end
    check("9 from cell1 cannot enter (j=7)", onlyRing and #acts3 == 1)
end

-- cannot hop own marble / land on own
do
    local S = mk(4, { { 1, 1, 'R', 10 }, { 1, 2, 'R', 12 } })
    local acts = JB.legalActions(S, 1, { '3' })
    local moved = {}
    for _, a in ipairs(acts) do moved[a.steps[1].mi] = a.steps[1].p end
    check("marble1 +3 would pass own marble at 12", moved[1] == nil)
    check("marble2 +3 fine", moved[2] == 15)
    local acts2 = JB.legalActions(S, 1, { '2' })
    local ok1 = false
    for _, a in ipairs(acts2) do if a.steps[1].mi == 1 then ok1 = true end end
    check("marble1 +2 lands on own marble: illegal", not ok1)
end

-- backwards 8 and finish restrictions
do
    local S = mk(4, { { 1, 1, 'R', 20 }, { 1, 2, 'G', 2 } })
    local acts = JB.legalActions(S, 1, { '8' })
    check("8 moves ring marble back 8", #acts == 1 and acts[1].steps[1].p == 12)
    local acts2 = JB.legalActions(S, 1, { '2' })
    local gotGoal = false
    for _, a in ipairs(acts2) do if a.steps[1].mi == 2 then gotGoal = (a.steps[1].kind == 'G' and a.steps[1].p == 4) end end
    check("goal marble can step deeper", gotGoal)
end

-- bonking
do
    -- enemy at cell 12 -> goes to start
    local S = mk(4, { { 1, 1, 'R', 10 }, { 2, 1, 'R', 12 } })
    local acts = JB.legalActions(S, 1, { '2' })
    local a
    for _, x in ipairs(acts) do if x.steps[1].mi == 1 then a = x end end
    check("enemy bonk legal", a ~= nil and a.bumps == 1)
    check("enemy sent to start", a.state.marbles[6].kind == 'S')
    check("mover on cell", a.state.marbles[1].p == 12)
    -- teammate (seat 3) at cell 12 -> sent to entrance of seat 3 = 39
    local S2 = mk(4, { { 1, 1, 'R', 10 }, { 3, 1, 'R', 12 } })
    local acts2 = JB.legalActions(S2, 1, { '2' })
    local b
    for _, x in ipairs(acts2) do if x.steps[1].mi == 1 then b = x end end
    check("teammate bonk legal", b ~= nil)
    check("teammate sent to its entrance", b.state.marbles[11].kind == 'R' and b.state.marbles[11].p == JB.entrance(3))
    -- NEW RULE: teammate sitting on its own entrance cannot be bonked
    local S3 = mk(4, { { 1, 1, 'R', 10 }, { 3, 1, 'R', JB.entrance(3) } })  -- entrance(3)=39
    S3.marbles[1].p = 37; S3 = JB.newState(4, S3.marbles)
    local acts3 = JB.legalActions(S3, 1, { '2' })
    local found = false
    for _, x in ipairs(acts3) do if x.steps[1].mi == 1 then found = true end end
    check("bonking teammate at entrance is illegal", not found)
    local ns, why = JB.land(S3, 1, 'R', JB.entrance(3))
    check("land() reports why", ns == nil and why:find("entrance") ~= nil)
    -- chain: teammate bonked onto an enemy sitting at the teammate's entrance -> enemy to start
    local S4 = mk(4, { { 1, 1, 'R', 10 }, { 3, 1, 'R', 12 }, { 2, 1, 'R', JB.entrance(3) } })
    local ns4 = JB.land(S4, 1, 'R', 12)
    check("chain bonk legal", ns4 ~= nil and ns4.marbles[11].p == JB.entrance(3) and ns4.marbles[6].kind == 'S')
    -- friendly bonk onto teammate's entrance occupied by that teammate's own other marble = illegal
    local S5 = mk(4, { { 1, 1, 'R', 10 }, { 3, 1, 'R', 12 }, { 3, 2, 'R', JB.entrance(3) } })
    check("friendly bonk onto own marble illegal", JB.land(S5, 1, 'R', 12) == nil)
    -- cannot land on own marble
    local S6 = mk(4, { { 1, 1, 'R', 10 }, { 1, 2, 'R', 12 } })
    check("own landing illegal", JB.land(S6, 1, 'R', 12) == nil)
end

-- exiting start bonks whoever sits on the exit cell
do
    local S = mk(4, { { 2, 1, 'R', JB.exitCell(1) } })
    local acts = JB.legalActions(S, 1, { 'k' })
    check("exit bonks enemy on exit cell", #acts == 1 and acts[1].bumps == 1)
end

-- finished player plays teammate's marbles
do
    local over = {}
    for k = 1, 5 do over[#over + 1] = { 1, k, 'G', k } end
    over[#over + 1] = { 3, 1, 'R', 20 }
    local S = mk(4, over)
    check("finished", JB.isFinished(S, 1))
    local acts = JB.legalActions(S, 1, { '5' })
    check("moves teammate marble", #acts == 1 and S.marbles[acts[1].steps[1].mi].seat == 3)
end

-- 7s (house rule)
do
    local S = mk(4, { { 1, 1, 'R', 10 }, { 3, 1, 'R', 30 }, { 3, 2, 'R', 40 } })
    check("must split with teammate on ring", JB.sevenMustSplit(S, 1))
    local acts = JB.legalActions(S, 1, { '7' })
    check("7 split generated", #acts > 0)
    for _, a in ipairs(acts) do
        check("7 uses two marbles", #a.steps == 2)
        local s1, s2 = S.marbles[a.steps[1].mi].seat, S.marbles[a.steps[2].mi].seat
        check("7 pair is mine + teammate (either order)", (s1 == 1 and s2 == 3) or (s1 == 3 and s2 == 1))
    end
    local S2 = mk(4, { { 1, 1, 'R', 10 } })
    check("teammate all in start -> straight 7", not JB.sevenMustSplit(S2, 1))
    local a2 = JB.legalActions(S2, 1, { '7' })
    check("straight 7 is a single move", #a2 == 1 and #a2[1].steps == 1 and a2[1].steps[1].p == 17)
    local over = { { 1, 1, 'R', 10 } }
    for k = 1, 5 do over[#over + 1] = { 3, k, 'G', k } end
    check("teammate packed in finish -> straight 7", not JB.sevenMustSplit(mk(4, over), 1))
    check("teammate marble with room in finish is eligible", JB.sevenMustSplit(mk(4, { { 1, 1, 'R', 10 }, { 3, 1, 'G', 1 } }), 1))
    check("teammate marble stuck at G5 not eligible", not JB.sevenMustSplit(mk(4, { { 1, 1, 'R', 10 }, { 3, 1, 'G', 5 } }), 1))
    -- finished player, 6 players (team of 3)
    local function mk6(over6)
        local list = {}
        for s = 1, 6 do for k = 1, 5 do list[#list + 1] = { seat = s, kind = 'S', p = 0 } end end
        for _, o in ipairs(over6) do list[(o[1] - 1) * 5 + o[2]] = { seat = o[1], kind = o[3], p = o[4] } end
        return JB.newState(6, list)
    end
    local base = {}
    for k = 1, 5 do base[#base + 1] = { 1, k, 'G', k } end
    local two = { table.unpack and table.unpack(base) }
    local o6 = {}
    for _, o in ipairs(base) do o6[#o6 + 1] = o end
    o6[#o6 + 1] = { 3, 1, 'R', 20 }; o6[#o6 + 1] = { 3, 2, 'R', 25 }; o6[#o6 + 1] = { 5, 1, 'R', 50 }
    local F = mk6(o6)
    check("finished + two eligible teammates -> must split", JB.sevenMustSplit(F, 1))
    local fa = JB.legalActions(F, 1, { '7' })
    check("finished split generated", #fa > 0)
    local differentOwners = true
    for _, a in ipairs(fa) do
        if F.marbles[a.steps[1].mi].seat == F.marbles[a.steps[2].mi].seat then differentOwners = false end
    end
    check("finished split always uses two different teammates", differentOwners)
    local o6b = {}
    for _, o in ipairs(base) do o6b[#o6b + 1] = o end
    o6b[#o6b + 1] = { 3, 1, 'R', 20 }; o6b[#o6b + 1] = { 3, 2, 'R', 25 }     -- two marbles but only ONE teammate
    local F2 = mk6(o6b)
    check("finished + one eligible teammate -> straight 7", not JB.sevenMustSplit(F2, 1))
    local fa2 = JB.legalActions(F2, 1, { '7' })
    local allTeammateSingles = #fa2 > 0
    for _, a in ipairs(fa2) do
        if #a.steps ~= 1 or F2.marbles[a.steps[1].mi].seat ~= 3 then allTeammateSingles = false end
    end
    check("finished straight 7 moves a teammate marble", allTeammateSingles)
    local o4 = {}
    for k = 1, 5 do o4[#o4 + 1] = { 1, k, 'G', k } end
    o4[#o4 + 1] = { 3, 1, 'R', 20 }
    check("4 players, finished: only one teammate -> straight 7", not JB.sevenMustSplit(mk(4, o4), 1))
    -- simple7 option (used by the search) still forces a plain move
    local sp = JB.legalActions(S, 1, { '7' }, { simple7 = true })
    local plain = #sp > 0
    for _, a in ipairs(sp) do if #a.steps ~= 1 then plain = false end end
    check("simple7 gives plain moves", plain)
end

-- 8 never enters the finish: backwards moves only travel the ring
do
    local E = JB.entrance(1)                       -- seat 1 entrance = cell 3
    -- 3 cells before the entrance (cell 72 on a 4-player ring is 3 behind cell 3) and 3 cells past it
    for _, start in ipairs({ JB.wrap(mk(4), E - 3), E + 3 }) do
        local S = mk(4, { { 1, 1, 'R', start } })
        local acts = JB.legalActions(S, 1, { '8' })
        check("8 from cell " .. start .. " is a single ring move", #acts == 1 and acts[1].steps[1].kind == 'R')
        check("8 from cell " .. start .. " goes back 8 cells", acts[1].steps[1].p == JB.wrap(S, start - 8))
    end
    local G = mk(4, { { 1, 1, 'G', 3 } })
    check("8 can't move a marble that is already in the finish", #JB.legalActions(G, 1, { '8' }) == 0)
end

-- joker
do
    local S = mk(4, { { 1, 1, 'R', 10 }, { 2, 1, 'R', 30 }, { 1, 2, 'R', 50 } })
    local acts = JB.legalActions(S, 1, { '$' })
    local ok, ownTarget = false, false
    for _, a in ipairs(acts) do
        local tgt = a.steps[1].p
        if a.steps[1].mi == 1 and tgt == 30 then ok = true end
        if tgt == 50 then ownTarget = true end
    end
    check("joker onto enemy", ok)
    check("joker never onto own marble", not ownTarget)
end

-- AI sanity: prefers bonking an enemy over a quiet move, avoids hanging marbles
do
    local S = mk(4, { { 1, 1, 'R', 20 }, { 2, 1, 'R', 25 }, { 3, 1, 'R', 60 } })
    local best = JB.choose(S, 1, { '5', '3' }, function() return 0 end)
    check("AI bonks enemy with 5", best.card == '5' and best.bumps == 1)
    local none = JB.choose(mk(4), 1, { '5', '3', '2' }, function() return 0 end)
    check("burns when nothing legal", none.burn == true)
    check("burns cheapest card", true)
    local e = JB.choose(mk(4), 1, { 'k', '4' }, function() return 0 end)
    check("exits start with king", e.card == 'k')
end

-- burn order (user, flag 72): anything, then 10s, then 7s, then 8s; duplicates first
check("burn: 9 before 8", JB.burnPick({ '8', '9', '7' }) == '9')
check("burn: 10 before 7 and 8", JB.burnPick({ '8', '7', '10' }) == '10')
check("burn: 7 before 8", JB.burnPick({ '8', '7' }) == '7')
check("burn: duplicates of 'anything' first", JB.burnPick({ '9', '3', '3', '8' }) == '3')
check("burn: two 10s before one 7", JB.burnPick({ '7', '10', '10', '8' }) == '10')
print(("passed %d, failed %d"):format(passes, fails))
