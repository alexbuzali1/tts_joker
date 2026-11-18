-- Tests for bot_engine.lua (level 10). lua test_engine.lua
dofile("tests/load_bot.lua")
local JB, JE = JokerBot, JokerEngine
math.randomseed(11)
local passed, failed = 0, 0
local function check(c, msg) if c then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. msg) end end

local function randomState(N)
    local list, used = {}, {}
    for s = 1, N do
        local home = math.random(0, 3)
        local cells = {}
        for k = 1, home do cells[math.random(1, 5)] = true end
        local h = 0
        for j = 1, 5 do if cells[j] then list[#list + 1] = { seat = s, kind = 'G', p = j }; h = h + 1 end end
        for _ = h + 1, 5 do
            if math.random() < 0.55 then
                local p repeat p = math.random(1, 18 * N) until not used[p]
                used[p] = true
                list[#list + 1] = { seat = s, kind = 'R', p = p }
            else list[#list + 1] = { seat = s, kind = 'S', p = 0 } end
        end
    end
    return JB.newState(N, list)
end
local function keyS(S) local t = {} for i, m in ipairs(S.marbles) do t[i] = m.kind .. m.p end return table.concat(t, ",") end
local function keyE(E)
    local t = {}
    for i = 1, E.M do local p = E.pos[i]; t[i] = (p == 0) and 'S0' or (p <= E.R and ('R' .. p) or ('G' .. (p - E.R))) end
    return table.concat(t, ",")
end

local cards = { 'a', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'j', 'q', 'k', '$' }
-- full = false: Tabletop Simulator search (7 as a plain 7, no Joker); full = true: deep mode (every legal move)
for _, full in ipairs({ false, true }) do
    print("== engine moves = JokerBot moves, random positions, " .. (full and "deep mode (Jokers, 7 splits)" or "TTS mode (plain 7, no Joker)"))
    local bad = 0
    for trial = 1, 300 do
        local N = ({ 4, 6, 8 })[math.random(3)]
        local S = randomState(N)
        local seat = math.random(N)
        local E = JE.load(S)
        for _, c in ipairs(cards) do
            local want = {}
            if full or c ~= '$' then
                for _, a in ipairs(JB.legalActions(S, seat, { c }, { simple7 = not full })) do want[keyS(a.state)] = true end
            end
            local got, buf = {}, {}
            local n = JE._options(E, seat, c, buf, full)
            for k = 1, n, 4 do
                local mark = E.uTop
                if JE._play(E, buf, k) then got[keyE(E)] = true end
                JE._undoTo(E, mark)
            end
            local same = true
            for k in pairs(want) do if not got[k] then same = false end end
            for k in pairs(got) do if not want[k] then same = false end end
            if not same then
                bad = bad + 1
                if bad <= 3 then print("  mismatch", N, "seat", seat, "card", c, keyS(S)) end
            end
            check(keyE(E) == keyS(S), "undo restores the position")
        end
    end
    check(bad == 0, "engine and JokerBot agree on every card (" .. bad .. " mismatches)")
end

print("== it returns a legal move fast, and searches a full round")
for _, N in ipairs({ 4, 6 }) do
    local S = randomState(N)
    local a = JE.choose(S, 1, { 'a', '5', '7', 'k', '9', '$' }, { time_limit = 0.5 })
    check(a.burn or a.state ~= nil, "legal result")
    print(string.format("   %dp: %s, depth %s, %d nodes, %.2fs", N, tostring(a.text), tostring(a.depth), a.nodes or 0, a.elapsed or 0))
    local d = JE.choose(S, 1, { 'a', '5', '7', 'k', '9', '$' }, { time_limit = 0.5, deep = true })
    check(d.burn or d.state ~= nil, "legal result (deep)")
    print(string.format("   %dp deep: %s, depth %s, %d nodes, %.2fs", N, tostring(d.text), tostring(d.depth), d.nodes or 0, d.elapsed or 0))
end
print(string.format("\npassed %d, failed %d", passed, failed))
os.exit(failed == 0 and 0 or 1)
