-- Compare every human turn of a logged game with what the level-9 bot would play.
--   python3 tools/log_turns.py data/logs/game_XXXX.jsonl > data/game_XXXX_turns.txt
--   lua tools/compare_humans.lua data/game_XXXX_turns.txt [seconds per move, default 1] [level, default 9]
-- Input lines (tools/log_turns.py): turn|seat|seat colour|card token|board before|board after
-- The log only knows the card each player played, not their hand, so the question per turn is: with THAT card,
-- did they make the bot's move? Turns where the card had only one possible outcome (forced) don't count; burns and
-- turns whose board change doesn't match any legal move with that card (fixed by hand, undone...) are listed apart.
-- Output: one line per counted turn, then per seat: agreement %, how often the human move was the bot's 2nd/3rd
-- choice, and the average score gap (bot's best minus the human move; 0 when they agree).
dofile("tests/load_bot.lua")
local JB, JS = JokerBot, JokerSearch

local file = assert(arg[1], "usage: lua tools/compare_humans.lua data/game_XXXX_turns.txt [seconds] [level]")
local secs = tonumber(arg[2]) or 1
local level = tonumber(arg[3]) or 9

local function board(str, N)
    local list, i = {}, 0
    for t in str:gmatch("%S+") do
        i = i + 1
        list[i] = { seat = (i - 1) // 5 + 1, kind = t:sub(1, 1), p = tonumber(t:sub(2)) }
    end
    return list
end
-- where every seat's marbles are (as a set: which of a seat's marbles is which doesn't matter, e.g. leaving start)
local function key(marbles)
    local per = {}
    for _, m in ipairs(marbles) do
        per[m.seat] = per[m.seat] or {}
        table.insert(per[m.seat], m.kind .. (m.kind == 'S' and 0 or m.p))
    end
    local out = {}
    for seat = 1, #per do table.sort(per[seat]); out[seat] = table.concat(per[seat], ",") end
    return table.concat(out, "|")
end

local per = {}
local N = 8                                          -- seats: worked out per line (5 marbles per seat)
local function stat(seat)
    per[seat] = per[seat] or { counted = 0, agree = 0, second = 0, third = 0, gap = 0, forced = 0, burn = 0, odd = 0, color = "" }
    return per[seat]
end

io.stdout:setvbuf("line")
for line in io.lines(file) do
    local turn, seat, color, tok, b1, b2 = line:match("^(%d+)|(%d+)|(%a+)|([^|]+)|([^|]+)|([^|]+)$")
    seat = tonumber(seat)
    N = select(2, b1:gsub("%S+", "")) // 5
    local st = stat(seat); st.color = color
    local S = JB.newState(N, board(b1, N))
    local afterKey = key(board(b2, N))
    local acts = JB.legalActions(S, seat, { tok })
    local outcomes, match = {}, nil
    for _, a in ipairs(acts) do
        local k = key(a.state.marbles)
        outcomes[k] = true
        if k == afterKey then match = a end
    end
    local distinct = 0
    for _ in pairs(outcomes) do distinct = distinct + 1 end
    if #acts == 0 then
        st.burn = st.burn + 1
    elseif not match then
        st.odd = st.odd + 1
        print(string.format("turn %s seat %d %s card %s: board change matches no legal move (fixed by hand / undo?)", turn, seat, color, tok))
    elseif distinct == 1 then
        st.forced = st.forced + 1
    else
        local best = JS.choose(S, seat, { tok }, { level = level, time_limit = secs, debug = true, rng = function() return 0.5 end })
        local rank, humanScore, topScore = nil, nil, nil
        local seen, r = {}, 0
        for _, a in ipairs(best.all or {}) do
            local k = key(a.state.marbles)
            if not seen[k] then
                seen[k] = true
                r = r + 1
                topScore = topScore or a.score
                if k == afterKey then rank, humanScore = r, a.score end
            end
        end
        st.counted = st.counted + 1
        local gap = (topScore and humanScore) and (topScore - humanScore) or 0
        if rank == 1 then st.agree = st.agree + 1
        elseif rank == 2 then st.second = st.second + 1
        elseif rank == 3 then st.third = st.third + 1 end
        st.gap = st.gap + gap
        print(string.format("turn %s seat %d %s card %-2s options %2d  human = bot's #%s  gap %6.1f  | bot: %s | human: %s",
            turn, seat, color, tok, distinct, tostring(rank or "?"), gap, best.text, match.text))
    end
end

print("\n== per seat (level " .. level .. ", " .. secs .. " s per move)")
print("seat colour   counted  same-as-bot  bot's 2nd  bot's 3rd  avg gap   forced burns odd")
for seat = 1, N do
    local st = per[seat]
    if st then
        local c = math.max(1, st.counted)
        print(string.format("%4d %-8s %7d    %5.1f%%     %5.1f%%    %5.1f%%   %7.1f   %5d %5d %3d", seat, st.color, st.counted,
            100 * st.agree / c, 100 * st.second / c, 100 * st.third / c, st.gap / c, st.forced, st.burn, st.odd))
    end
end
