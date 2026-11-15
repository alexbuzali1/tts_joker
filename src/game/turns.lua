-- game/turns.lua  (Global script)
-- The turn cycle. The game runs its own turns (TTS's built-in turn passing only shows the turn colour):
--   * startTurns (from Start Game) picks a random seat to go first
--   * turnBegin(seat) starts a seat's turn:
--       bot seat        -> the bot plays (bot/play.lua), draws, and the turn moves on by itself
--       person          -> the banner, splash and Turn Button say it's their turn; they play a card, move, and
--                          click END TURN (or the Turn Button); they draw one card and the turn moves on
--       in-person seat  -> (hybrid mode) the host enters their card and move (play/hybrid.lua)
--       empty seat      -> skipped (someone left)
--   * endTurnClicked ends the current turn (the host may end anyone's turn, e.g. someone AFK)
--   * the game ends when every marble of a team is home (turnWinningTeam / turnGameOver)
-- Every turn start gets a number (TURN_STATE.gen): callbacks still pending from an earlier turn (an undo, !turn)
-- see that it changed and stop.
-- Also the host's failsafes for a game that got into a bad state: !turn, !next, !pause, !resync
-- (host/commands.lua), and whose seat is whose when people sit down or reconnect.

TURN_STATE = TURN_STATE or { active = false, seat = 0, busy = false }

-- the seat colours of this game, in turn order
function turnColors() return PLAYER_COLORS[Global.getVar("num_players")] end

-- is any person playing? (with nobody seated the bots stop, unless every seat is a bot on purpose)
local function turnAnyHumanSeated()
    if BOT_ALL_SEATS then return true end          -- all-bot mode: keep playing with nobody (or only watchers) seated
    for _, color in ipairs(turnColors()) do
        if Player[color].seated and not botIsBot(color) then return true end
    end
    return false
end

-- Start the turn of the given seat (index into PLAYER_COLORS[N]).
-- first = true for the opening turn of the game: the button and a broadcast say who goes first.
function turnBegin(seat, first)
    glogTurnStart(seat, first)
    pcall(autoReshuffleCheck)
    local colors = turnColors()
    local color = colors[seat]
    TURN_STATE.seat = seat
    -- every turn start gets a number: callbacks still pending from an earlier turn (undo, !turn) see it changed
    TURN_STATE.gen = (TURN_STATE.gen or 0) + 1
    local gen = TURN_STATE.gen
    if TURN_STATE.paused then                       -- !pause: hold here until the host resumes
        TURN_STATE.busy = false
        TURN_STATE.held = true                      -- Resume starts this turn
        turnButtonLabel("Paused")
        turnShowTurn(nil, "Paused", "#FFD84D", false)
        if BOT_STATE.active then botSetStatus("Paused by the host") end
        return
    end
    TURN_STATE.held = false
    if botTopUpHands then pcall(botTopUpHands) end          -- every bot back to 6 cards
    if easyCancel then pcall(easyCancel) end
    pcall(undoSnapshot, seat)
    Turns.pass_turns = false          -- the Turn Button is the only way to end a turn
    Turns.disable_interactations = false   -- hovering marbles for distances works off-turn too (user)

    if botIsBot(color) then
        if not turnAnyHumanSeated() then
            TURN_STATE.busy = false
            turnButtonLabel("Paused\n(no players)")
            botSetStatus("Paused: nobody is seated")
            return
        end
        TURN_STATE.busy = true
        statsTurnStart(color)
        turnShowTurn(color, botName(color) .. (first and " goes first" or "'s turn"), nil, false)
        if first then
            broadcastToAll(botName(color) .. " goes first", nameColorOnDark(color))
            turnButtonLabel(botName(color) .. " starts\nDealing cards...", "The bot plays as soon as its cards are dealt.",
                nameColorOnLight(color))
            botSetStatus(botName(color) .. " goes first (dealing cards)", color)
        else
            turnButtonLabel(botName(color) .. "'s\nTurn", "", nameColorOnLight(color))
            botSetStatus(botName(color) .. " is about to play", color)
        end
        -- bot hands are dealt a few seconds after Start Game; wait for that before the first bot turn
        Wait.condition(function()
            if TURN_STATE.gen ~= gen then return end                      -- undone / moved on meanwhile
            if not botIsBot(color) then turnBegin(seat); return end      -- a player took the seat meanwhile
            botTakeTurn(color, function()
                if TURN_STATE.gen ~= gen then return end
                statsTurnEnd(color)
                Wait.time(function() if TURN_STATE.gen == gen then turnAdvance() end end, 0.8 * botSpeed().t)
            end)
        end, function() return not BOT_STATE.dealing and not (BOT_STATE.topping and BOT_STATE.topping[color]) end, 30, function()
            printToAll("BOT ERROR (turn): " .. botChatName(color) .. "'s cards were never dealt, skipping its turn")
            turnAdvance()
        end)

    elseif irlIsSeat(color) and not Player[color].seated then
        -- in person (play/hybrid.lua): the host picks their card on the card bar and copies their move
        TURN_STATE.busy = false
        if IRL then IRL.pick = nil end
        statsTurnStart(color)
        turnHighlight(color, true)
        local name = playerLabel(color)
        turnShowTurn(color, name .. (first and " goes first!" or "'s turn"), nil, true)
        if first then broadcastToAll(name .. " goes first!", { 1, 1, 1 }) end
        turnButtonLabel(name .. "'s turn\nHost: pick their card", "Pick the card they played on the bar at the bottom, then copy their move. Or move by hand and click here.")
        if BOT_STATE.active then botSetStatus("Waiting for " .. name) end
        refreshGameUI()

    elseif Player[color].seated then
        TURN_STATE.busy = false
        Turns.turn_color = color      -- keeps TTS's own turn indicator in sync (onPlayerTurn ignores it)
        statsTurnStart(color)
        turnHighlight(color, true)
        local name = playerLabel(color)
        turnShowTurn(color, name .. (first and " goes first!" or "'s turn"), nil, true)
        if first then
            broadcastToAll(name .. " goes first!", { 1, 1, 1 })
            turnButtonLabel(name .. " starts!\nClick to END TURN",
                "You go first. Play your card and move, then click here.")
        else
            turnButtonLabel(name .. "'s turn\nClick to END TURN",
                "When you've played your card and moved, click here. Your next card is dealt and the bots play.")
        end
        if BOT_STATE.active then botSetStatus("Waiting for " .. name) end

    else
        turnAdvance()                 -- empty seat that isn't a bot (a player left): skip it
    end
end

-- Team (1 or 2) whose players all have all 5 marbles home, or nil. Odd seats = Team 1, even seats = Team 2.
function turnWinningTeam()
    local ok, S = pcall(botReadState)
    if not ok or not S then return nil end
    for team = 1, 2 do
        local all = true
        for seat = 1, S.N do
            if ((seat % 2 == 1) and 1 or 2) == team and not JokerBot.isFinished(S, seat) then all = false end
        end
        if all then return team end
    end
    return nil
end

-- End of game: stop the turn cycle (no more bot turns, the button stops ending turns).
function turnGameOver(team)
    glogGameOver(team)
    TURN_STATE.active = false
    TURN_STATE.busy = false
    for _, color in ipairs(turnColors()) do turnHighlight(color, false) end
    turnShowTurn(nil, "Team " .. team .. " wins!", "#66FF66", false)
    turnButtonLabel("Game over\nTeam " .. team .. " wins!", "The game is finished. Press Stats in the top-left panel for the post-game stats.")
    if BOT_STATE.active then botSetStatus("Game over: Team " .. team .. " wins") end
end

function turnAdvance()
    if not TURN_STATE.active then return end
    statsCheckFinish()   -- announces "made it home" / the winner, opens the stats
    local team = turnWinningTeam()
    if team then turnGameOver(team); return end
    local N = Global.getVar("num_players")
    turnBegin((TURN_STATE.seat % N) + 1)
end

-- Turn Button click (function_owner = Global)
function endTurnClicked(obj, player_color, alt_click)
    if not TURN_STATE.active then
        if turnWinningTeam() then broadcastToColor("The game is over", player_color, { 1, 0.8, 0.3 }) end
        return
    end
    local cur = turnColors()[TURN_STATE.seat]

    if TURN_STATE.busy then
        -- host controls for a stuck or broken bot turn: right-click = rethink, two clicks within 3 s = skip
        local host = Player[player_color] and Player[player_color].host
        if host and botIsBot(cur) and BOT_STATE.current then
            if alt_click then
                botRethink()
            elseif TURN_STATE.skip_armed then
                TURN_STATE.skip_armed = false
                botSkipTurn()
            else
                TURN_STATE.skip_armed = true
                broadcastToColor("Click the Turn Button again within 3 s to skip " .. playerLabel(cur) .. "'s turn (right-click: make it rethink)", player_color, { 1, 0.8, 0.3 })
                Wait.time(function() TURN_STATE.skip_armed = false end, 3)
            end
            return
        end
        broadcastToColor("Wait - " .. playerLabel(cur) .. " is still playing", player_color, { 1, 0.8, 0.3 })
        return
    end
    local clicker = Player[player_color]
    if player_color ~= cur and not (clicker and clicker.host) then
        broadcastToColor("It's " .. playerLabel(cur) .. "'s turn, not yours", player_color, { 1, 0.8, 0.3 })
        return
    end

    TURN_STATE.busy = true            -- ignore double clicks until the next human's turn begins
    turnHighlight(cur, false)
    printToAll(playerLabel(cur) .. " ended their turn")
    turnDrawCard(cur)
    turnButtonLabel("Next turn...")
    -- wait for bonked marbles to land before scoring the turn and letting the next player (or bot) read the board
    local gen = TURN_STATE.gen
    botWhenBoardSettled(function()
        if TURN_STATE.gen ~= gen then return end                      -- undone meanwhile
        statsTurnEnd(cur)
        turnAdvance()
    end)
end

-- Start Game: pick a random seat to go first (bots included) and start the turn cycle.
function startTurns(params)
    local N = params.num_players
    local start = math.random(N)
    TURN_STATE.active = true
    TURN_STATE.busy = true
    TURN_STATE.seat = ((start - 2) % N) + 1
    -- give startGame() time to create the Turn Button and play zones first
    Wait.time(function()
        turnButtonLabel("Choosing who\ngoes first...")
        turnNamePlayZones()
        Wait.time(function() turnBegin(start, true) end, 1)
    end, 0.5)
end

-- Someone sat down in a seat (Global onPlayerChangeColor): a bot's seat becomes theirs (bot/players.lua
-- botSeatToHuman), once the bot finishes any move it's making.
function turnSeatTaken(color)
    if not color or not BOT_STATE or not BOT_STATE.seats[color] then return end
    Wait.time(function() pcall(botSeatToHuman, color) end, 0.5)
end


------------------------------------------------------------------------
-- failsafes for the host (user 2026-11-12: a player reconnected, TTS's own turn moved on to the wrong player
-- and his marble colours came back wrong). Host chat commands in host/commands.lua: !turn, !next, !pause, !resync.
------------------------------------------------------------------------
-- a seat's colour from what the host typed: marble colour ("red"), TTS seat colour, or the start of a player name
function turnSeatFromText(text)
    if not text or text == "" then return nil end
    local c = botSeatFromName(text)
    if c then return c end
    text = text:lower()
    for _, col in ipairs(turnColors() or {}) do
        local p = Player[col]
        local n = p and p.steam_name
        if n and n:lower():sub(1, #text) == text then return col end
    end
    return nil
end

-- re-send every marble's colour to everyone (a rejoining player can get stale tints) and line TTS's own turn
-- (who may touch things) back up with the Turn Button's
function turnResync()
    for _, list in pairs(Global.getTable("marbles_by_player") or {}) do
        for _, m in ipairs(list) do
            pcall(function()
                local c = m.getColorTint()
                local r, g, b, a = c.r, c.g, c.b, c.a or 1           -- (a: see-through marbles keep it)
                m.setColorTint({ r = 0.5, g = 0.5, b = 0.5 })
                Wait.frames(function() pcall(function() m.setColorTint({ r = r, g = g, b = b, a = a }) end) end, 30)
            end)
        end
    end
    Turns.disable_interactations = false
    if TURN_STATE.active then
        local cur = (turnColors() or {})[TURN_STATE.seat]
        if cur and not botIsBot(cur) then Turns.turn_color = cur end
    end
    refreshGameUI()
    pcall(turnNamePlayZones)
end

-- stop whatever turn is going on (a bot's move too) and start this seat's turn. No card is drawn for the turn that
-- was cut short, except that a bot is topped up to 6.
function turnForce(color)
    local seat
    for i, c in ipairs(turnColors() or {}) do if c == color then seat = i end end
    if not seat then return false end
    local cur = BOT_STATE.current
    if cur then
        BOT_STATE.token = (BOT_STATE.token or 0) + 1
        BOT_STATE.current = nil
        cur.finished = true
        botHighlight(cur.color, false)
        local missing = 6 - #(BOT_STATE.hands[cur.color] or {})
        if missing > 0 then botDrawCards(cur.color, missing) end
    end
    local prev = (turnColors() or {})[TURN_STATE.seat]
    if prev then pcall(turnHighlight, prev, false) end
    TURN_STATE.active, TURN_STATE.busy, TURN_STATE.paused = true, false, false
    printToAll("The host gave the turn to " .. playerLabel(color))
    turnBegin(seat)
    return true
end

-- Pause holds the game before the next turn starts: a turn in progress (human or bot) carries on and isn't
-- restarted (restarting it re-counted the turn's stats and moved its undo point). who = "Pat" etc. for chat.
function turnSetPaused(on, who)
    if on == TURN_STATE.paused then return end
    TURN_STATE.paused = on
    refreshGameUI()
    who = who or "the host"
    if on then
        printToAll("Game paused by " .. who .. " - it stops before the next turn. Press Resume to go on.")
    else
        printToAll("Game resumed by " .. who)
        if TURN_STATE.active and TURN_STATE.held and not BOT_STATE.current then turnBegin(TURN_STATE.seat) end
    end
end

-- someone (re)joined (Global onPlayerConnect): re-send the colours and the turn a few seconds later, when their
-- game has loaded
function turnPlayerConnected(player)
    if TURN_STATE.active then Wait.time(function() pcall(turnResync) end, 4) end
end
