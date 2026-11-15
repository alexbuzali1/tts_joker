-- bot/flags.lua  (Global script)
-- "Flag bad move": every bot move is recorded (board before, hand, chosen move, the best alternatives with their
-- scores). !flag (or the Flag button with !dev on) sends the last few to the flag server (tools/flag_server.py,
-- http://127.0.0.1:8765), which saves them for review with tools/replay_flag.lua. If the server isn't running, the
-- flags are kept in the game's save (game/save.lua) and sent next time.

BOT_HISTORY_SIZE = 6                 -- how many recent bot moves a flag sends
FLAG_SERVER_URL = "http://127.0.0.1:8765/flag"
BOT_STATE.history = BOT_STATE.history or {}
BOT_FLAGS = BOT_FLAGS or {}          -- flags that couldn't be sent (saved with the game)
FLAG_NOTES = FLAG_NOTES or {}        -- note text per player colour

local function boardList(S)
    local out = {}
    for i, m in ipairs(S.marbles) do out[i] = { seat = m.seat, kind = m.kind, p = m.p } end
    return out
end

function botRecordMove(color, seat, S, tokens, act)
    local alts = {}
    for i = 1, math.min(6, #(act.all or {})) do
        local a = act.all[i]
        alts[i] = { card = a.card, text = a.text, score = a.score and math.floor(a.score * 10 + 0.5) / 10 }
    end
    local steps = {}
    for i, st in ipairs(act.steps or {}) do steps[i] = { mi = st.mi, kind = st.kind, p = st.p } end
    local h = BOT_STATE.history
    h[#h + 1] = {
        bot = botName(color), marbles = marbleColorName(color), seat_color = color, seat = seat,
        game_turn = GAME_STATS and GAME_STATS.turn or 0,
        difficulty = BOT_DIFFICULTY, think_time = BOT_THINK_TIME,
        hand = tokens, board_before = boardList(S),
        chosen = { card = act.card, text = act.text or "", burn = act.burn or false, steps = steps,
                   depth = act.depth, elapsed = act.elapsed and math.floor(act.elapsed * 100 + 0.5) / 100 },
        alternatives = alts,
    }
    while #h > BOT_HISTORY_SIZE do table.remove(h, 1) end
end

function flagNoteChanged(player, value) FLAG_NOTES[player.color] = value end

function flagBadMove(player)
    local N = Global.getVar("num_players")
    local seats = {}
    for i, c in ipairs(PLAYER_COLORS[N] or {}) do
        seats[i] = { seat = i, seat_color = c, marbles = marbleColorName(c), name = botIsBot(c) and botName(c) or playerLabel(c) }
    end
    local now = {}
    pcall(function() now = boardList(botReadState()) end)
    local flag = {
        flagged_at = os.date and os.date("%Y-%m-%d %H:%M:%S") or "",
        by = player.color, note = FLAG_NOTES[player.color] or "",
        num_players = N, game_turn = GAME_STATS and GAME_STATS.turn or 0,
        seats = seats, board_now = now,
        recent_bot_moves = BOT_STATE.history,       -- oldest first; the last one is the most recent bot move
    }
    local body = JSON.encode(flag)
    FLAG_NOTES[player.color] = ""
    if BOT_DEV_UI then UI.setAttribute("flagNote", "text", "") end
    WebRequest.custom(FLAG_SERVER_URL, "POST", true, body, { ["Content-Type"] = "application/json" }, function(req)
        if req.is_error or (req.text or "") ~= "saved" then
            table.insert(BOT_FLAGS, flag)
            broadcastToColor("Flag kept in the game save (flag server not reachable: " .. tostring(req.error) .. ")", player.color, { 1, 0.8, 0.3 })
        else
            broadcastToColor("Bad move flagged, thanks!", player.color, { 0.5, 1, 0.5 })
        end
    end)
end
