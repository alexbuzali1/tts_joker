-- play/hybrid.lua  (Global script)
-- Hybrid mode: some players sit at a real board, others join in TTS. "!hybrid on" before Start Game: every empty
-- seat is played IN PERSON instead of by a bot.
--   * in-person seats get no cards (nothing is taken from the TTS deck: the real deck is separate) and draw none
--   * on their turn the host gets a bar with every card (A, 2-10, J, Q, K, Joker): pick the card they played. It
--     counts in the stats like a played card, and easy play starts for that seat with the host clicking
--     (play/easy_play.lua): the host copies the move they made on the real board. The turn then ends by itself.
--     A card with no legal move is a burn; picking another card before moving replaces the pick.
--   * the host can also move their marbles by hand and press END TURN (bottom right, only the host sees it then)
--   * someone sitting down in an in-person seat takes it over; "!botseat <seat>" hands it to a bot
--   * "!hybridseat <seat> [name]" turns a bot's (or an empty) seat into an in-person seat mid-game, and names it
--   * "!hybridname <seat> <name>" names a seat ("Pat (in person)"); the host's colour picker can colour and name
--     them too (ui/color_picker.lua)
--   <seat> = a seat number (the host's seat is 0, then clockwise), a marble colour, a TTS seat colour, or a name
IRL = IRL or { mode = false, seats = {}, names = {}, pick = nil }
IRL.seats = IRL.seats or {}
IRL.names = IRL.names or {}

IRL_TOKENS = { 'a', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'j', 'q', 'k', '$' }
local LABEL = { a = "A", j = "J", q = "Q", k = "K", ['$'] = "Joker" }
local WORD = { a = "Ace", j = "Jack", q = "Queen", k = "King", ['$'] = "Joker" }
local NAME = { a = "Ace of Spades", j = "Jack of Spades", q = "Queen of Spades", k = "King of Spades", ['$'] = "Joker" }

local function seatColors() return PLAYER_COLORS[Global.getVar("num_players")] or {} end

function irlIsSeat(color) return color ~= nil and IRL.seats[color] == true end

function irlLabel(color)
    return (IRL.names[color] or marbleColorName(color)) .. " (in person)"
end

-- the in-person seat whose turn it is (nil if none)
function irlCurrentSeat()
    if not (TURN_STATE and TURN_STATE.active) then return nil end
    local c = seatColors()[TURN_STATE.seat]
    if irlIsSeat(c) then return c end
    return nil
end

-- stands in for a real card in the stats (statsCardPlayed reads its name and marks it counted)
local function fakeCard(token)
    local vars = {}
    local name = NAME[token] or (token .. " of Spades")
    return { getName = function() return name end, getGUID = function() return "irl-" .. token end,
             getVar = function(k) return vars[k] end, setVar = function(k, v) vars[k] = v end }
end

-- the host picked the card an in-person player played
function irlPick(player, value, id)
    local pl = player and player.color and Player[player.color]
    if not (pl and pl.host) then return end
    local color = irlCurrentSeat()
    if not color or TURN_STATE.paused or TURN_STATE.busy then return end
    if EASY and EASY.session and EASY.session.busy then return end
    local token = tostring(id or ""):match("^irlCard_(%w+)$")
    if token == "joker" then token = '$' end
    if not token or not (LABEL[token] or tonumber(token)) then return end
    -- a different card picked before moving: the earlier pick no longer counts
    if IRL.pick and IRL.pick.gen == TURN_STATE.gen and statsCardUnplayed then statsCardUnplayed(color, IRL.pick.card) end
    local card = fakeCard(token)
    statsCardPlayed(color, card)
    IRL.pick = { gen = TURN_STATE.gen, card = card, token = token }
    printToAll(playerLabel(color) .. " played a" .. ((token == 'a' or token == '8') and "n " or " ") .. (WORD[token] or token))
    pcall(glog, "irl_card", { color = color, card = token })
    easyStart(color, token, card.getGUID(), player.color)
    refreshGameUI()
end

-- the host's card bar on an in-person turn
function irlUiXml()
    local color = irlCurrentSeat()
    if not color or TURN_STATE.busy or TURN_STATE.paused then return "" end
    if EASY and EASY.session and EASY.session.busy then return "" end
    local picked = IRL.pick and IRL.pick.gen == TURN_STATE.gen and IRL.pick.token
    local x = {}
    x[#x + 1] = '<Panel id="irlBar" visibility="Host" rectAlignment="LowerCenter" offsetXY="0 110" width="780" height="92" color="#000000D8" padding="10 10 6 6">'
        .. '<VerticalLayout spacing="4">'
    x[#x + 1] = string.format('<Text fontSize="18" fontStyle="Bold" color="#FFE066" preferredHeight="26">%s: pick the card they played%s</Text>',
        xmlEscape(playerLabel(color)),
        picked and ", then copy their move" or "")
    x[#x + 1] = '<HorizontalLayout spacing="4" preferredHeight="44">'
    for _, t in ipairs(IRL_TOKENS) do
        local id = t == '$' and "joker" or t
        x[#x + 1] = string.format('<Button id="irlCard_%s" onClick="irlPick" fontSize="18" fontStyle="Bold" color="%s"%s>%s</Button>',
            id, picked == t and "#E8C547" or "#FFFFFF", t == '$' and ' preferredWidth="90"' or "", LABEL[t] or t)
    end
    x[#x + 1] = '</HorizontalLayout></VerticalLayout></Panel>'
    return table.concat(x)
end

-- a game starts: in-person mode turns the empty seats into in-person seats (bot/players.lua skips them)
-- Game start (bot/players.lua botOnGameStart, before the bots are chosen): in hybrid mode every empty seat is
-- played in person (unless every seat is a bot on purpose).
function hybridAssignSeats(num_players)
    IRL.seats, IRL.pick = {}, nil
    if IRL.mode and not BOT_ALL_SEATS then
        local names = {}
        for _, c in ipairs(PLAYER_COLORS[num_players] or {}) do
            if not Player[c].seated then IRL.seats[c] = true; names[#names + 1] = irlLabel(c) end
        end
        if #names > 0 then printToAll("Playing in person: " .. table.concat(names, ", ") .. ". The host enters their moves.") end
    end
end

-- Someone sat down in an in-person seat (Global onPlayerChangeColor): it's theirs from now on.
function hybridSeatTaken(color)
    if not (color and IRL.seats[color] and Player[color] and Player[color].seated) then return end
    IRL.seats[color] = nil
    printToAll((personName(color) or "A player") .. " took over " .. irlLabel(color) .. "'s seat")
    if TURN_STATE.active and seatColors()[TURN_STATE.seat] == color and not TURN_STATE.busy then
        turnBegin(TURN_STATE.seat)                          -- their turn: start it for them
    end
    refreshGameUI()
end

-- "!hybridseat <seat>": a bot's seat (or an empty one) is played in person from now on. A bot in the middle of its
-- move finishes it first. Its cards go back into the draw deck (in-person players use the real deck).
local function cardsToDeck(cards)
    local deck = findCenterDeck()
    local p = deck and deck.getPosition() or { x = 0, y = 1, z = 0 }
    local r = deck and deck.getRotation() or { x = 0, y = 180, z = 180 }
    for _, card in ipairs(cards) do
        pcall(function()
            card.setInvisibleTo({})
            card.setLock(false)
            card.interactable = true
            card.setRotation(r)
            card.setPosition({ x = p.x, y = p.y + 2, z = p.z })
        end)
    end
    if #cards > 0 then
        Wait.time(function() local d = findCenterDeck(); if d then pcall(function() d.shuffle() end) end end, 1.5)
    end
end

function irlSeatFromBot(color)
    if not color then return false, "no such seat" end
    if irlIsSeat(color) then return false, "that seat is already played in person" end
    if Player[color] and Player[color].seated then return false, "someone is sitting there" end
    local function convert()
        if botIsBot(color) then
            local cards = BOT_STATE.hands[color] or {}
            BOT_STATE.seats[color], BOT_STATE.hands[color] = nil, nil
            if BOT_STATE.topping then BOT_STATE.topping[color] = nil end
            BOT_STATE.active = next(BOT_STATE.seats) ~= nil
            cardsToDeck(cards)
            if botRelayoutHands then pcall(botRelayoutHands) end
        end
        IRL.seats[color] = true
        printToAll(marbleColorName(color) .. "'s seat is now played in person" .. (IRL.names[color] and (" by " .. IRL.names[color]) or ""))
        pcall(glog, "hybridseat", { color = color })
        -- its turn now (a bot about to play, or an empty seat): start it as an in-person turn
        if TURN_STATE and TURN_STATE.active and seatColors()[TURN_STATE.seat] == color then turnBegin(TURN_STATE.seat) end
        refreshGameUI()
    end
    local cur = BOT_STATE.current
    if cur and cur.color == color and not cur.finished then
        printToAll(botChatName(color) .. " finishes its move, then the seat is played in person")
        Wait.condition(convert, function() local c = BOT_STATE.current; return not (c and c.color == color and not c.finished) end, 60, convert)
        return true
    end
    convert()
    return true
end

