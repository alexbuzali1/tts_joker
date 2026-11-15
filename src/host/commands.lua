-- host/commands.lua  (Global script)
-- The host's chat commands. They start with "!" and only work for the host: the command line is hidden from
-- everyone and the reply goes to the host only (a guest's "!..." is just chat). !help lists them all; docs/
-- HOST_COMMANDS.md explains each one. Global onChat hands every message to hostChatCommand first.

local function hostReply(text) botHostMsg(text, { 1, 0.85, 0.3 }) end
local function botSettingsLine()
    return string.format("level %d, think %.1f s, speed %s%s%s", BOT_DIFFICULTY, BOT_THINK_TIME, botSpeed().name,
        BOT_ALL_SEATS and ", all-bot mode ON" or "", BOT_DEBUG_SHOW_HANDS and ", bot hands SHOWN" or "")
        .. (TURN_FREE_MOVE and ", free movement ON" or "")
end
HOST_COMMANDS = {
    help = function()
        hostReply("HOST COMMANDS (only you see these; your command lines are hidden from everyone)\n" ..
            "Bots:\n" ..
            "  !level <1-10>        bot difficulty (9 = best, the default)\n" ..
            "  !think <secs>        bot think time per move (0.5-60)\n" ..
            "  !speed slow|normal|fast|instant   bot moves, and easy play's card flight\n" ..
            "  !allbots on|off      every seat is a bot from the next Start Game\n" ..
            "  !botseat [seat]      list empty seats / a bot takes that seat (e.g. !botseat red)\n" ..
            "Hybrid (some players at a real board):\n" ..
            "  !hybrid on|off       empty seats are played in person from the next Start Game\n" ..
            "  !hybridseat <seat> [name]   a bot's (or empty) seat is played in person from now on (e.g. !hybridseat 1 Kim)\n" ..
            "  !hybridname <seat> <name>   name an in-person seat (e.g. !hybridname 3 Pat)\n" ..
            "  !picker on|off       show the colour pickers (your picker also colours/names in-person seats)\n" ..
            "Table:\n" ..
            "  !freemove on|off     anyone can move marbles at any time (default off)\n" ..
            "Fixing problems:\n" ..
            "  !turn <seat>         give the turn to that seat now (stops a bot mid-move)\n" ..
            "  !next                end the current turn (a bot's is skipped)\n" ..
            "  !pause on|off        hold the game before the next turn (same as Pause / Resume)\n" ..
            "  !resync              re-send marble colours + whose turn it is (also runs after a reconnect)\n" ..
            "  !undo                undo the last move (same as the Undo button)\n" ..
            "  !stats               open the stats screen mid-game\n" ..
            "Bot reports:\n" ..
            "  !flag [note]         flag the last bot move as bad, with a note\n" ..
            "Testing (everyone sees the effect):\n" ..
            "  !give <card>         a card into your hand: !give a / 7 / 10 / k / joker\n" ..
            "  !hands on|off        show the bots' cards on the table\n" ..
            "  !dev on|off          settings + Flag panel in the bot panel\n" ..
            "  !help (or !bot)      this list\n" ..
            "<seat> = seat number (your seat is 0, then 1, 2... clockwise), marble colour, TTS seat colour, or name\n" ..
            "Now: " .. botSettingsLine() .. ((IRL and IRL.mode) and ", hybrid mode ON" or ""))
    end,
    level = function(a)
        local n = tonumber(a)
        if not n then return hostReply("!level <1-10>  (now " .. BOT_DIFFICULTY .. ")") end
        botSetDifficulty(math.floor(n))
    end,
    think = function(a)
        local n = tonumber(a)
        if not n then return hostReply(string.format("!think <seconds>  (now %.1f)", BOT_THINK_TIME)) end
        botSetThink(n)
    end,
    speed = function(a)
        for i, sp in ipairs(BOT_SPEEDS) do
            if sp.name:lower() == (a or "") then
                BOT_STATE.speed_index = i
                if BOT_DEV_UI then pcall(function() UI.setAttribute("botSpeedBtn", "text", "Bot speed: " .. sp.name) end) end
                return hostReply("Bot speed: " .. sp.name)
            end
        end
        hostReply("!speed slow|normal|fast|instant  (now " .. botSpeed().name .. ")")
    end,
    flag = function(a, player)
        FLAG_NOTES[player.color] = a or ""
        flagBadMove(player)
    end,
    hands = function(a)
        BOT_DEBUG_SHOW_HANDS = (a == "on") or (a ~= "off" and not BOT_DEBUG_SHOW_HANDS)
        botRelayoutHands()
        hostReply("Bot hands " .. (BOT_DEBUG_SHOW_HANDS and "SHOWN on the table (everyone can see them)" or "hidden"))
    end,
    dev = function(a)
        BOT_DEV_UI = (a == "on") or (a ~= "off" and not BOT_DEV_UI)
        refreshGameUI()
        hostReply("Settings panel " .. (BOT_DEV_UI and "shown" or "hidden"))
    end,
    botseat = function(a)
        if not a then
            local empty = {}
            for _, c in ipairs(PLAYER_COLORS[Global.getVar("num_players")] or {}) do
                if not botIsBot(c) and not Player[c].seated then empty[#empty + 1] = marbleColorName(c) end
            end
            return hostReply("!botseat <colour>  empty seats: " .. (#empty > 0 and table.concat(empty, ", ") or "none"))
        end
        local color = botSeatFromName(a)
        if not color then return hostReply("No seat with " .. a .. " marbles") end
        local ok, why = botSeatFromHuman(color)
        if not ok then hostReply("Can't: " .. why) end
    end,
    freemove = function(a)
        TURN_FREE_MOVE = (a == "on") or (a ~= "off" and not TURN_FREE_MOVE)
        printToAll(TURN_FREE_MOVE and "Free movement ON: anyone can move marbles at any time"
                                   or "Free movement OFF: you can only move marbles on your turn")
    end,
    turn = function(a, player)
        if not (TURN_STATE and TURN_STATE.active) then return hostReply("No game running") end
        local color = turnSeatFromText(a)
        if not color then return hostReply("!turn <marble colour | seat colour | player name>") end
        turnForce(color)
    end,
    next = function(a, player)
        if not (TURN_STATE and TURN_STATE.active) then return hostReply("No game running") end
        if BOT_STATE.current then botSkipTurn() else endTurnClicked(nil, player.color, false) end
    end,
    pause = function(a)
        if not (TURN_STATE and TURN_STATE.active) then return hostReply("No game running") end
        turnSetPaused((a == "on") or (a ~= "off" and not TURN_STATE.paused))
    end,
    undo = function(a, player) undoClicked(player) end,
    stats = function() statsOpen() end,
    hybrid = function(a)
        if a == "on" then IRL.mode = true elseif a == "off" then IRL.mode = false else IRL.mode = not IRL.mode end
        local seats = {}
        for c in pairs(IRL.seats or {}) do seats[#seats + 1] = irlLabel(c) end
        hostReply(IRL.mode and "Hybrid mode ON: from the next Start Game, empty seats are played in person (you enter their moves)"
            or "Hybrid mode OFF: bots fill empty seats from the next Start Game")
        if #seats > 0 then hostReply("Playing in person now: " .. table.concat(seats, ", ")) end
    end,
    hybridseat = function(a)
        if not a then return hostReply("!hybridseat <seat> [name]   seat = number (you are 0, then clockwise), marble colour or name") end
        local seatText, name = tostring(a):match("^(%S+)%s+(.+)$")
        seatText = seatText or a
        local color = botSeatFromName(seatText)
        if not color then return hostReply("No seat " .. seatText) end
        if name then IRL.names[color] = name end                     -- e.g. !hybridseat 1 Kim
        if irlIsSeat(color) then                                      -- already in person: just (re)named
            if name then
                hostReply(marbleColorName(color) .. " is " .. irlLabel(color))
                turnRefreshNames()
                refreshGameUI()
            else
                hostReply("That seat is already played in person")
            end
            return
        end
        local ok, why = irlSeatFromBot(color)
        if not ok then hostReply("Can't: " .. why) end
    end,
    picker = function(a)
        UI_STATE.picker = (a == "on") or (a ~= "off" and not UI_STATE.picker)
        refreshGameUI()
        hostReply("Colour picker " .. (UI_STATE.picker and "shown (everyone gets theirs; yours also does the in-person seats)" or "hidden"))
    end,
    hybridname = function(a)
        local col, name = tostring(a or ""):match("^(%S+)%s+(.+)$")
        local color = col and botSeatFromName(col)
        if not color then return hostReply("!hybridname <seat> <name>   e.g. !hybridname red Pat  or  !hybridname 3 Pat") end
        IRL.names[color] = name
        hostReply(marbleColorName(color) .. " is " .. irlLabel(color))
        turnRefreshNames()
        refreshGameUI()
    end,
    give = function(a, player)
        local token = giveToken(a)
        if not token then return hostReply("!give <card>   e.g. !give a, !give 7, !give 10, !give k, !give joker") end
        local name = giveCardTo(player.color, token)
        if name then
            hostReply("Gave you the " .. name)
            pcall(glog, "give", { color = player.color, card = name })
        else
            hostReply("No free " .. token:upper() .. " to give (not in the deck, a play pile or on the table)")
        end
    end,
    resync = function()
        turnResync()
        hostReply("Marble colours and whose turn it is re-sent to everyone")
    end,
    allbots = function(a)
        if a == "on" then BOT_ALL_SEATS = true elseif a == "off" then BOT_ALL_SEATS = false
        else BOT_ALL_SEATS = not BOT_ALL_SEATS end
        hostReply("All-bot mode " .. (BOT_ALL_SEATS and "ON: every seat is a bot from the next Start Game"
            or "OFF: bots only fill empty seats"))
    end,
}
HOST_COMMANDS.bot = HOST_COMMANDS.help
HOST_COMMANDS.async = HOST_COMMANDS.hybrid            -- old names still work
HOST_COMMANDS.irlname = HOST_COMMANDS.hybridname

-- !give: "a" / "ace" / "1", "2".."10", "j"/"jack", "q"/"queen", "k"/"king", "joker"/"$" -> a card token
function giveToken(a)
    a = tostring(a or ""):lower()
    if a == "" then return nil end
    local ALIAS = { ace = "a", ["1"] = "a", jack = "j", queen = "q", king = "k", joker = "$", jo = "$", jkr = "$", x = "$" }
    a = ALIAS[a] or a
    if a == "a" or a == "j" or a == "q" or a == "k" or a == "$" then return a end
    local n = tonumber(a)
    if n and n >= 2 and n <= 10 and n == math.floor(n) then return tostring(n) end
    return nil
end

-- Take a card of that rank from the draw deck (first choice), a play pile, or loose on the table (never from
-- anyone's hand, bots' included) and drop it into the player's hand. Returns the card's name, or nil.
function giveCardTo(color, token)
    local function toHand(card)
        pcall(function()
            card.setInvisibleTo({})
            card.setLock(false)
            card.setVar("stat_counted_turn", nil)
            card.setVar("last_player_color", color)
            local ht = Player[color].getHandTransform()
            local p = ht.position
            card.setRotation(ht.rotation)
            card.setPosition({ x = p.x, y = p.y + 0.5, z = p.z })
        end)
    end
    local function fromDeck(deck)
        if not deck then return nil end
        local ok, list = pcall(function() return deck.getObjects() end)
        for _, e in ipairs(ok and list or {}) do
            local nm = e.name or e.nickname
            if botCardToken(nm) == token then
                local p = deck.getPosition()
                deck.takeObject({ guid = e.guid, position = { x = p.x, y = p.y + 3, z = p.z }, smooth = false,
                                  callback_function = function(c) toHand(c) end })
                return nm
            end
        end
        return nil
    end
    local center = findCenterDeck()
    local got = fromDeck(center)
    if got then return got end
    -- cards in someone's hand are off limits
    local held = {}
    for _, list in pairs(BOT_STATE and BOT_STATE.hands or {}) do for _, c in ipairs(list) do held[c] = true end end
    for _, c in ipairs(BOT_ALL_COLORS or {}) do
        pcall(function() for _, o in ipairs(Player[c].getHandObjects() or {}) do held[o] = true end end)
    end
    for _, o in ipairs(getAllObjects()) do
        if o ~= center and o.tag == "Deck" then
            got = fromDeck(o)
            if got then return got end
        end
    end
    for _, o in ipairs(getAllObjects()) do
        if o.tag == "Card" and not held[o] and botCardToken(o.getName()) == token then
            local nm = o.getName()
            toHand(o)
            return nm
        end
    end
    return nil
end

-- No Lua patterns over the whole message: TTS's MoonSharp gives "pattern too complex" on long lines
-- (e.g. "(.-)%s*$" on a flag note), and an error here would show the host's command to everyone.
local function isSpace(b) return b == 32 or (b >= 9 and b <= 13) end
local function trim(str)
    local i, j = 1, #str
    while i <= j and isSpace(str:byte(i)) do i = i + 1 end
    while j >= i and isSpace(str:byte(j)) do j = j - 1 end
    return str:sub(i, j)
end
local function parseCommand(m)          -- "!flag  some note " -> "flag", "some note"
    m = trim(m)
    if m:byte(1) ~= 33 then return nil end                     -- "!"
    local k = 2
    while k <= #m do
        local b = m:byte(k)
        if not ((b >= 65 and b <= 90) or (b >= 97 and b <= 122)) then break end
        k = k + 1
    end
    if k == 2 then return nil end
    return m:sub(2, k - 1), trim(m:sub(k))
end

-- A chat message (Global onChat). Returns true when it was a host command (then it isn't shown in chat).
function hostChatCommand(message, player)
    local m = tostring(message or "")
    if player and player.host then
        local ok, cmd, rest = pcall(parseCommand, m)
        if ok and cmd and HOST_COMMANDS[cmd:lower()] then
            local name = cmd:lower()
            local arg = rest ~= "" and rest or nil
            if name ~= "flag" and name ~= "hybridname" and name ~= "irlname" and name ~= "hybridseat" and arg then arg = arg:lower() end
            local fine, err = pcall(HOST_COMMANDS[name], arg, player)
            if not fine then hostReply("!" .. name .. " failed: " .. tostring(err)) end
            return true                                    -- hidden from everyone
        end
        if not ok then hostReply("chat command error: " .. tostring(cmd)); return true end
    end
    return false
end

