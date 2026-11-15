-- host/game_log.lua  (Global script)
-- The game log: events are buffered and sent in batches to the flag server (tools/flag_server.py,
-- http://127.0.0.1:8765/log), which appends them to data/logs/game_<start time>.jsonl and prints a "LOG ERROR" /
-- "LOG MISMATCH" line for problems. Nothing happens if the server isn't running.
-- Logged: game start (seats, bots, settings), every turn start (whose turn, bot hand, board), every bot decision
-- (hand, board, chosen move, bonks, top alternatives), every card a bot draws, every card played, the board after
-- each bot move compared with what the bot meant to do (a mismatch is an animation / physics bug), every chat line
-- (errors included), the host's hidden messages, and the game result with the stats.
-- tools/analyze_log.lua and tools/compare_humans.lua read these logs.

BOT_ALL_SEATS = BOT_ALL_SEATS or false      -- all-bot mode (!allbots): every seat is a bot from the next Start Game
LOG_SERVER_URL = "http://127.0.0.1:8765/log"
GLOG = GLOG or { buf = {}, game = nil, seq = 0, sending = false, failed = 0 }


function boardNow()
    local ok, S = pcall(botReadState)
    if not ok or not S then return nil end
    local out = {}
    for i, m in ipairs(S.marbles) do out[i] = m.kind .. m.p end
    return out
end

function handNames(color)
    local out = {}
    for i, c in ipairs((BOT_STATE and BOT_STATE.hands and BOT_STATE.hands[color]) or {}) do
        local ok, n = pcall(function() return c.getName() end)
        out[i] = ok and n or "?"
    end
    return out
end

function glogFlush()
    if #GLOG.buf == 0 or not WebRequest then return end
    local events = GLOG.buf
    GLOG.buf = {}
    local ok, body = pcall(JSON.encode, { game = GLOG.game or "nogame", events = events })
    if not ok then return end
    pcall(function()
        WebRequest.custom(LOG_SERVER_URL, "POST", true, body, { ["Content-Type"] = "application/json" }, function(req)
            if req.is_error then GLOG.failed = GLOG.failed + #events end
        end)
    end)
end

-- kind: short event name; data: table (copied as is)
function glog(kind, data)
    if GLOG.inLog then return end            -- no logging from inside logging (printToAll is wrapped below)
    GLOG.inLog = true
    pcall(function()
        data = data or {}
        GLOG.seq = GLOG.seq + 1
        data.kind = kind
        data.seq = GLOG.seq
        data.t = os.time()
        data.turn = GAME_STATS and GAME_STATS.turn or nil
        GLOG.buf[#GLOG.buf + 1] = data
        if kind == "error" or kind == "mismatch" or kind == "game_over" or #GLOG.buf >= 40 then glogFlush() end
    end)
    GLOG.inLog = false
end

------------------------------------------------------------------------
-- the events (called from the code where they happen)
------------------------------------------------------------------------
-- game start (bot/players.lua botOnGameStart)
function glogGameStart(N)
    GLOG.game = os.date("%Y%m%d_%H%M%S")
    GLOG.seq = 0
    local seats = {}
    for i, c in ipairs(PLAYER_COLORS[N] or {}) do
        seats[i] = { seat = i, color = c, bot = botIsBot(c) and true or false,
                     name = botIsBot(c) and botName(c) or playerLabel(c) }
    end
    glog("game_start", { num_players = N, all_bots = BOT_ALL_SEATS, seats = seats,
                         difficulty = BOT_DIFFICULTY, think_time = BOT_THINK_TIME })
    if not GLOG.timer then GLOG.timer = true; Wait.time(glogFlush, 5, -1) end   -- send whatever is buffered every 5 s
end

-- a turn starts (game/turns.lua turnBegin)
function glogTurnStart(seat, first)
    local color = (PLAYER_COLORS[Global.getVar("num_players")] or {})[seat]
    local bot = color and botIsBot(color)
    glog("turn_start", { seat = seat, color = color, bot = bot, first = first or nil,
                         hand = bot and handNames(color) or nil, board = boardNow() })
end

-- a bot decided (bot/flags.lua botRecordMove, after recording it for flags)
function glogBotMove(color, seat, tokens, act)
    local h = BOT_STATE.history[#BOT_STATE.history]
    glog("bot_move", { color = color, seat = seat, hand = tokens, hand_cards = handNames(color),
                       board_before = h and h.board_before, chosen = h and h.chosen,
                       bumps = act.bumpList, alternatives = h and h.alternatives })
end

-- a bot drew cards (bot/players.lua botDrawCards); `before` = its hand size before drawing
function glogDraw(color, asked, before)
    local names = handNames(color)
    local drawn = {}
    for i = before + 1, #names do drawn[#drawn + 1] = names[i] end
    glog("draw", { color = color, asked = asked, drawn = drawn, hand = names })
end

-- a card was played (game/stats.lua statsCardPlayed)
function glogCardPlayed(color, card)
    local ok, name = pcall(function() return card.getName() end)
    glog("card_played", { color = color, card = ok and name or tostring(card), bot = botIsBot(color) })
end

-- the game is over (game/turns.lua turnGameOver)
function glogGameOver(team)
    glog("game_over", { team = team, board = boardNow(), stats = GAME_STATS })
end

-- called by bot.lua after a bot's move has played out and the board has settled
function botVerifyMove(color, act)
    if not act or not act.state then return end
    local ok, S = pcall(botReadState)
    if not ok or not S then glog("error", { text = "verify: could not read the board", color = color }); return end
    local diffs = {}
    for i, want in ipairs(act.state.marbles) do
        local got = S.marbles[i]
        if not got or got.kind ~= want.kind or (want.kind ~= 'S' and got.p ~= want.p) then
            diffs[#diffs + 1] = { marble = i, seat = want.seat, expected = want.kind .. want.p,
                                  actual = got and (got.kind .. got.p) or "missing" }
        end
    end
    local mv = { color = color, move = act.text, card = act.card, ok = #diffs == 0, diffs = diffs, board_after = boardNow() }
    glog(#diffs == 0 and "move_result" or "mismatch", mv)
    if #diffs > 0 then
        TTS_PRINT("BOT CHECK: " .. tostring(act.text) .. " ended differently than planned (" .. #diffs .. " marble"
            .. (#diffs == 1 and "" or "s") .. "), logged")
    end
end


------------------------------------------------------------------------
-- every chat line goes into the log too: printToAll / broadcastToAll are wrapped once, here
------------------------------------------------------------------------
TTS_PRINT = TTS_PRINT or printToAll
TTS_BROADCAST = TTS_BROADCAST or broadcastToAll
function printToAll(msg, color)
    TTS_PRINT(msg, color)
    local text = tostring(msg)
    glog(text:find("ERROR") and "error" or "chat", { text = text })
end
function broadcastToAll(msg, color)
    TTS_BROADCAST(msg, color)
    glog("chat", { text = tostring(msg), broadcast = true })
end
