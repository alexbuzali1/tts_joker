-- Replay a recorded bot move from a "Flag bad move" file with the current bot code.
--   lua tools/replay_flag.lua data/flags/flag_XXXX.json [move index, default = last] [level, default = recorded] [seconds, default 1]
-- Prints the position, what the bot chose in the game, and what it chooses now (with its top alternatives).
dofile("tests/load_bot.lua")
local JB, JS = JokerBot, JokerSearch

-- minimal JSON reader (objects, arrays, strings, numbers, true/false/null) for the flag files
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
                ws(); local k = str(); ws(); i = i + 1        -- skip ':'
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

local path = arg[1]
local f = assert(io.open(path, "r")); local flag = decode(f:read("a")); f:close()
local moves = flag.recent_bot_moves
local idx = tonumber(arg[2]) or #moves
local mv = moves[idx]
REPLAY_FLAG, REPLAY_MOVE = flag, mv          -- for debugging scripts that dofile this one
local level = tonumber(arg[3]) or mv.difficulty or 9
local secs = tonumber(arg[4]) or 1

local names = {}
for _, s in ipairs(flag.seats or {}) do names[s.seat] = s.name end
local S = JB.newState(flag.num_players, mv.board_before)
print(string.format("flag %s  note: %q  (flagged by %s)", path, flag.note or "", flag.by or "?"))
print(string.format("move %d of %d: %s (seat %d), game turn %d, played at level %s", idx, #moves, mv.bot, mv.seat, mv.game_turn or 0, tostring(mv.difficulty)))
print("hand: " .. table.concat(mv.hand, " "))
for i, m in ipairs(S.marbles) do
    if m.kind ~= 'S' then
        local where = m.kind == 'G' and ("finish " .. m.p) or ("ring " .. m.p .. ", " .. JB.distToEntrance(S, m.seat, m.p) .. " to its entrance")
        print(string.format("  marble %2d  %-14s %s", i, names[m.seat] or ("seat " .. m.seat), where))
    end
end
print("in the game it chose: " .. tostring(mv.chosen.text) .. "  (looked " .. tostring(mv.chosen.depth) .. " ahead)")
local act = JS.choose(S, mv.seat, mv.hand, { level = level, time_limit = secs, debug = true, rng = function() return 0.5 end })
print(string.format("now at level %d (%.1fs): %s  (looked %d ahead)", level, secs, tostring(act.text), act.depth or 0))
for i = 1, math.min(tonumber(os.getenv("TOP") or 6), #(act.all or {})) do
    local a = act.all[i]
    if os.getenv("PARTS") then
        JB.STRATEGY = JS.LEVELS[level].insight or 1
        print(string.format("   %6.1f  %-50s eval %7.1f  card %6.1f  setup %6.1f  plan %5.1f %s", a.score or 0, a.text,
            JB.evaluate(a.state, mv.seat % 2), JB.cardAdjust(S, a), a.trap or 0, a.plan or 0, a.planText and ("(next: " .. a.planText .. ")") or ""))
    else
        print(string.format("   %6.1f  %s", a.score or 0, a.text))
    end
end
