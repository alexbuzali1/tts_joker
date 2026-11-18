-- Check every bot move in a game log (data/logs/game_*.jsonl, written by host/game_log.lua) against the user's rules
-- (STRATEGY_RULES.md). Static checks only: no search, so it runs in seconds.
--   lua tools/analyze_log.lua data/logs/game_XXXX.jsonl [max listed per rule, default 8]
dofile("tests/load_bot.lua")
local JB = JokerBot
JB.STRATEGY = 1

-- minimal JSON reader (same as replay_flag.lua)
local function decode(s)
    local i = 1
    local function ws() i = s:find("[^ \t\r\n]", i) or #s + 1 end
    local value
    local function str()
        local out = {}
        i = i + 1
        while true do
            local c = s:sub(i, i)
            if c == '"' then i = i + 1; return table.concat(out) end
            if c == "\\" then
                local n = s:sub(i + 1, i + 1)
                local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f" }
                if n == "u" then out[#out + 1] = utf8.char(tonumber(s:sub(i + 2, i + 5), 16)); i = i + 6
                else out[#out + 1] = map[n] or n; i = i + 2 end
            else out[#out + 1] = c; i = i + 1 end
        end
    end
    function value()
        ws()
        local c = s:sub(i, i)
        if c == "{" then
            local t = {}; i = i + 1; ws()
            if s:sub(i, i) == "}" then i = i + 1; return t end
            while true do
                ws(); local k = str(); ws(); i = i + 1
                t[k] = value(); ws()
                local d = s:sub(i, i); i = i + 1
                if d == "}" then return t end
            end
        elseif c == "[" then
            local t = {}; i = i + 1; ws()
            if s:sub(i, i) == "]" then i = i + 1; return t end
            while true do
                t[#t + 1] = value(); ws()
                local d = s:sub(i, i); i = i + 1
                if d == "]" then return t end
            end
        elseif c == '"' then return str()
        elseif s:sub(i, i + 3) == "true" then i = i + 4; return true
        elseif s:sub(i, i + 4) == "false" then i = i + 5; return false
        elseif s:sub(i, i + 3) == "null" then i = i + 4; return nil
        else
            local num = s:match("^-?[%d%.eE+-]+", i); i = i + #num; return tonumber(num)
        end
    end
    return value()
end

local path = assert(arg[1], "usage: lua tools/analyze_log.lua data/logs/game_XXXX.jsonl")
local LIST = tonumber(arg[2]) or 8
local events, N = {}, nil
for line in io.lines(path) do
    local ok, ev = pcall(decode, line)
    if ok and ev then
        events[#events + 1] = ev
        if ev.kind == "game_start" then N = ev.num_players end
    end
end
assert(N, "no game_start event in the log")

-- the move's landing risk for the marbles it moved (real threats only)
local function landingRisk(S, act)
    if not act.state or not act.steps then return 0 end
    local worst = 0
    for _, st in ipairs(act.steps) do
        if st.kind == 'R' then
            local m = act.state.marbles[st.mi]
            local par = m.seat % 2
            local ex = JB.exitThreats(act.state, par)
            local t = JB.threatsAt(act.state, st.p, par, ex, true)
            if ex[st.p] then t = t + 3 end
            if t > worst then worst = t end
        end
    end
    return worst
end

local issues, counts, moves, burns = {}, {}, 0, 0
local function flag(rule, ev, text)
    counts[rule] = (counts[rule] or 0) + 1
    issues[rule] = issues[rule] or {}
    local list = issues[rule]
    if #list < LIST then
        list[#list + 1] = string.format("turn %s %-7s %-55s %s", tostring(ev.turn), tostring(ev.color),
            tostring(ev.chosen and ev.chosen.text), text or "")
    end
end

for _, ev in ipairs(events) do
    if ev.kind == "bot_move" and ev.board_before and ev.chosen then
        moves = moves + 1
        local seat = ev.seat
        local S = JB.newState(N, ev.board_before)
        local hand = ev.hand or {}
        if ev.chosen.burn then
            burns = burns + 1
            local want = JB.burnPick(hand)
            if want ~= ev.chosen.card and (JB.BURN_KEEP[want] or 1) ~= (JB.BURN_KEEP[ev.chosen.card] or 1) then
                flag("burn order", ev, "burned " .. tostring(ev.chosen.card) .. ", should burn " .. tostring(want))
            end
        else
            local acts = JB.legalActions(S, seat, hand)
            local chosen
            for _, a in ipairs(acts) do if a.text == ev.chosen.text then chosen = a; break end end
            if not chosen then
                flag("could not rebuild", ev, "(move not found among the legal moves)")
            else
                local c = chosen.card
                -- cards
                if c == '$' then
                    local other = false
                    for _, a in ipairs(acts) do if a.card ~= '$' then other = true; break end end
                    if other and JB.defensiveBonus(S, chosen) <= 0 then flag("Joker (unforced, not defensive)", ev) end
                end
                if c == '7' and JB.qualityBumps(S, chosen) == 0 and not JB.goodFinishEntry(S, chosen) and not JB.readiesEntry(S, chosen) then
                    flag("7 without a purpose", ev)
                end
                if c == '8' and JB.worthyBumps(S, chosen) == 0 and not JB.readiesForFinish(S, chosen) then
                    flag("8 without a purpose", ev)
                end
                local mover = S.marbles[chosen.steps[1].mi]
                if mover.kind == 'S' and (c == 'k' or c == 'a') then
                    for _, h in ipairs(hand) do
                        if h == 'j' or h == 'q' then flag("left start with " .. c:upper() .. " holding J/Q", ev); break end
                    end
                end
                -- safety
                local risk = landingRisk(S, chosen)
                if risk > 0 and (chosen.bumps or 0) == 0 and mover.kind ~= 'S' then   -- coming out is often forced
                    local safeAlt
                    for _, a in ipairs(acts) do
                        if landingRisk(S, a) == 0 and a.card ~= '$' then safeAlt = a; break end
                    end
                    if safeAlt then flag("landed in danger (safe move existed)", ev, "e.g. " .. safeAlt.text) end
                end
                if JB.spotLandingPenalty(S, chosen) > 0 then flag("landed on enemy entrance / -8 spot", ev) end
                if JB.passEntrancePenalty(S, chosen) > 0 then flag("ran past own finish entrance", ev) end
                if JB.avoidableGapPenalty(S, chosen, hand) > 0 then flag("left a gap in the finish (clean cards in hand)", ev) end
                if JB.parkLeavePenalty(S, chosen) > 0 then flag("left a park on a teammate's exit", ev) end
                if JB.deadDefenderPenalty(S, chosen) > 0 then flag("defender to a dead spot (2-3 past exit)", ev) end
                if JB.crowdExitPenalty(S, chosen) > 0 then flag("clumping near start", ev) end
                if c == '7' then
                    local before, gap = 0, false
                    for _, st in ipairs(chosen.steps) do
                        local seatM = S.marbles[st.mi].seat
                        if st.kind == 'G' and JB.untidyCells(chosen.state, seatM) > JB.untidyCells(S, seatM) then gap = true end
                    end
                    if gap then flag("7 left a gap in the finish", ev) end
                end
                -- missed chances
                local function best(fn)
                    for _, a in ipairs(acts) do if fn(a) then return a end end
                end
                if JB.playerDoneBonus(S, chosen) == 0 then
                    local a = best(function(a) return JB.playerDoneBonus(S, a) > 0 end)
                    if a then flag("missed finishing a player", ev, "could: " .. a.text) end
                end
                local function bigDefence(a)
                    for _, b in ipairs(a.bumpList or {}) do
                        local z = S.marbles[b.idx]
                        if not b.friendly and z.kind == 'R' and JB.goalCount(S, z.seat) >= JB.GOAL_SIZE - 1
                           and JB.distToEntrance(S, z.seat, z.p) <= JB.THREAT_RANGE then return true end
                    end
                    return false
                end
                if not bigDefence(chosen) then
                    local a = best(bigDefence)
                    if a then flag("missed bonking a last marble near home", ev, "could: " .. a.text) end
                end
                if not JB.entersFinish(S, chosen) and (chosen.bumps or 0) == 0 then
                    local a = best(function(a) return a.card ~= '$' and JB.entersFinish(S, a) and JB.tidyEntry(S, a) end)
                    if a then flag("skipped a clean finish entry", ev, "could: " .. a.text) end
                end
            end
        end
    end
end

local errors, mismatches, chats = {}, {}, 0
for _, ev in ipairs(events) do
    if ev.kind == "error" then errors[#errors + 1] = ev end
    if ev.kind == "mismatch" then mismatches[#mismatches + 1] = ev end
end
local over
for _, ev in ipairs(events) do if ev.kind == "game_over" then over = ev end end

print(string.format("%s: %d players, %d bot moves (%d burns), %d errors, %d mismatches, %s",
    path, N, moves, burns, #errors, #mismatches, over and ("team " .. tostring(over.team) .. " won at turn " .. tostring(over.turn)) or "no game_over yet"))
for _, e in ipairs(errors) do print("  ERROR turn " .. tostring(e.turn) .. ": " .. tostring(e.text)) end
for _, e in ipairs(mismatches) do print("  MISMATCH turn " .. tostring(e.turn) .. ": " .. tostring(e.move)) end
local rules = {}
for r in pairs(counts) do rules[#rules + 1] = r end
table.sort(rules, function(a, b) return counts[a] > counts[b] end)
for _, r in ipairs(rules) do
    print(string.format("\n%s: %d", r, counts[r]))
    for _, l in ipairs(issues[r]) do print("  " .. l) end
end
