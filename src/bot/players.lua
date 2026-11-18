-- bot/players.lua  (Global script)
-- The bots as players at the table: which seats are bots, their settings, their hands of cards, reading the board
-- for them, and seats changing hands mid-game (a person sitting down in a bot's seat, !botseat).
--
-- A seat is a BOT when nobody sits there at Start Game (or every seat in all-bot mode, host command !allbots; in
-- hybrid mode empty seats are played in person instead, play/hybrid.lua). A bot:
--   * is dealt real cards from the centre deck, kept locked, face down and hidden far off the table
--   * takes its turn when the turn cycle reaches its seat (game/turns.lua -> bot/play.lua botTakeTurn)
--   * reads the board by matching every marble to the nearest board point (botReadState)
--   * plays its card face up on its own play zone and carries its marbles over with an animation; the normal
--     collision code does the bonking (game/bonks.lua), and it only ever makes legal moves (bot/rules.lua)


BOT_STATE = BOT_STATE or {
    active = false,
    seats = {},       -- [colour] = true for bot seats
    hands = {},       -- [colour] = { card objects }
    speed_index = 2,  -- Normal (user 2026-11-13; was Slow)
    status = ""
}
BOT_SPEEDS = { { name = "Slow", t = 1.6, fast = false }, { name = "Normal", t = 1.0, fast = false }, { name = "Fast", t = 0.5, fast = true },
               -- Instant (user: "an almost instant animation setting", for watching all-bot games): marbles and cards
               -- jump straight to their spot (still dropped from a little height so the collision code bonks), and
               -- every bot pause is cut to 5%. The bonk flight itself and the think time are not affected.
               { name = "Instant", t = 0.05, fast = true, instant = true } }
BOT_STASH_X = 150          -- where hidden bot cards live (far off the table, locked)
BOT_DEBUG_SHOW_HANDS = false  -- DEBUG: show each bot's hand face up next to its play zone (host chat: !hands on)
BOT_DIFFICULTY = BOT_DIFFICULTY or 9    -- 1 (easiest) .. 9 (hardest), 10 = engine (bot/engine.lua), saved with the game. See JokerSearch.LEVELS in bot/search.lua
BOT_THINK_TIME = BOT_THINK_TIME or 4.0  -- seconds of search per bot move
-- Party mode: the bot panel only shows the bots, what they are doing and the Stats button. The settings (speed,
-- difficulty, think time) and "Flag bad move" are the host's, through hidden chat commands (host/commands.lua, !help),
-- or shown again with !dev on.
BOT_DEV_UI = false


-- every TTS player colour, for hiding the bots' cards from all of them
BOT_ALL_COLORS = { "White", "Brown", "Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Purple", "Pink", "Grey", "Black" }

-- the current animation speed (one of BOT_SPEEDS)
function botSpeed() return BOT_SPEEDS[BOT_STATE.speed_index] end

function botIsBot(color) return BOT_STATE.seats[color] == true end

-- status line in the bot panel; pass the bot's colour to show the line in its marble colour
function botSetStatus(text, color)
    BOT_STATE.status = text
    BOT_STATE.status_color = color and ("#" .. colorHex(nameColorOnDark(color))) or "#FFFFFF"
    if UI and BOT_STATE.active then
        UI.setAttribute("botStatus", "text", text)
        UI.setAttribute("botStatus", "color", BOT_STATE.status_color)
    end
end

-- run fn, and report an error to the host (and call onFail) instead of letting it stop the game
function botSafe(label, fn, onFail)
    local ok, err = pcall(fn)
    if not ok then
        botHostMsg("BOT ERROR (" .. label .. "): " .. tostring(err), { 1, 0.4, 0.4 })
        if onFail then onFail() end
    end
end

-- wait `seconds` scaled by the animation speed, then run fn
function botAfter(seconds, fn) Wait.time(fn, seconds * botSpeed().t) end

------------------------------------------------------------------------
-- game start (setup.lua startGame -> Global.call("botOnGameStart")): who plays which seat
------------------------------------------------------------------------
-- Empty seats become bots (every seat in all-bot mode). In hybrid mode they become in-person seats first
-- (play/hybrid.lua), which are not bots. Then the bots are dealt their hands and the game log starts.
function botOnGameStart(params)
    local N = params.num_players
    hybridAssignSeats(N)
    -- cards still held from an earlier game: visible again (they were hidden from everyone while a bot held them)
    for _, cards in pairs(BOT_STATE.hands or {}) do
        for _, c in ipairs(cards) do pcall(function() if c ~= nil and not c.isDestroyed() then c.setInvisibleTo({}) end end) end
    end
    BOT_STATE.seats, BOT_STATE.hands = {}, {}
    BOT_SEEN, BOT_DECK_LAST = {}, nil                        -- level 10 card counting starts over
    local names = {}
    for _, color in ipairs(PLAYER_COLORS[N]) do
        if BOT_ALL_SEATS or (not Player[color].seated and not irlIsSeat(color)) then
            BOT_STATE.seats[color] = true
            BOT_STATE.hands[color] = {}
            table.insert(names, color)
        end
    end
    BOT_STATE.active = #names > 0
    BOT_STATE.dealing = BOT_STATE.active
    if BOT_STATE.active then
        local colored = {}
        for i, color in ipairs(names) do colored[i] = "[" .. colorHex(nameColorOnDark(color)) .. "]" .. marbleColorName(color) .. "[-]" end
        printToAll("Bots are playing: " .. table.concat(colored, ", "))
        refreshGameUI()
        Wait.time(function() botDealInitialHands(N) end, 2.5)
    end
    glogGameStart(N)
end


function botDealInitialHands(N)
    local colors = {}
    for _, color in ipairs(PLAYER_COLORS[N]) do if botIsBot(color) then table.insert(colors, color) end end
    local function nextBot(i)
        if i > #colors then BOT_STATE.dealing = false; return end
        botDrawCards(colors[i], 6, function() nextBot(i + 1) end)
    end
    nextBot(1)
end

-- reading the board
------------------------------------------------------------------------
local function sqdist(a, b) local dx, dz = a.x - b.x, a.z - b.z; return dx * dx + dz * dz end

-- Which logical cell is this marble sitting on?
function botClassify(obj, seat, nsp)
    local pos = obj.getPosition()
    local best, bestd = nil, 1e12
    for i, pt in ipairs(nsp) do
        local d = sqdist(pos, pt.position)
        if d < bestd then best, bestd = i, d end
    end
    local startd = 1e12
    for _, pt in ipairs(obj.getTable("start_points") or {}) do
        local d = sqdist(pos, pt.position)
        if d < startd then startd = d end
    end
    if startd <= bestd then return 'S', 0 end
    local kind, p, s = JokerBot.indexToCell(best)
    if kind == 'G' and s ~= seat then return 'R', JokerBot.entrance(s) end   -- foreign finish: shouldn't happen
    return kind, p
end

-- returns logical state + objs[marbleIndex] = marble object
function botReadState()
    local N = Global.getVar("num_players")
    local colors = PLAYER_COLORS[N]
    local nsp = Global.getTable("non_start_points")
    local mbp = Global.getTable("marbles_by_player")
    local list, objs = {}, {}
    for seat = 1, N do
        local team = mbp[colors[seat]]
        for k = 1, #team do
            local kind, p = botClassify(team[k], seat, nsp)
            list[#list + 1] = { seat = seat, kind = kind, p = p }
            objs[#list] = team[k]
        end
    end
    return JokerBot.newState(N, list), objs
end

------------------------------------------------------------------------
-- cards
------------------------------------------------------------------------
function botCardToken(name)
    if type(name) ~= "string" then return nil end
    if name == "Joker" then return "$" end
    local rank = name:match("^(%w+) of")
    if rank == "Ace" then return "a" elseif rank == "Jack" then return "j"
    elseif rank == "Queen" then return "q" elseif rank == "King" then return "k" end
    return rank
end

local function botStashPosition(color, n)
    return { x = BOT_STASH_X + n * 3, y = 2, z = (botSeatIndex(color) or 1) * 8 }
end

local function botFindDeck()
    local deck = findCenterDeck()
    if deck then return deck end
    for _, obj in ipairs(getAllObjects()) do          -- a lone last card is not a Deck any more
        if obj.tag == "Card" then
            local p = obj.getPosition()
            if isNear(p.x, p.z, 0, 0, 1) then return obj end
        end
    end
    return nil
end

-- Where the n-th card (0-based) of a bot's hand sits. Returns position, rotation (rotation nil = leave as is).
-- Normally: hidden far off the table. With BOT_DEBUG_SHOW_HANDS: a face-up row on the table just outside the
-- outer edge of the bot's part of the board, centred on its play zone (far from any play-zone trigger).
BOT_HAND_OUTSET = 1.8      -- debug hands: distance of the card row's centre past the board's outer edge
BOT_HAND_SPACING = 1.25    -- debug hands: distance between neighbouring cards in the row

local function botHandSlot(color, n)
    if BOT_DEBUG_SHOW_HANDS then
        local N = Global.getVar("num_players")
        local seat = botSeatIndex(color)
        local piles = Global.getTable("discard_piles")
        local pile = piles and piles[color]
        if seat and pile and DEFAULT_BOARD_LENGTH then
            -- same geometry as createDiscardPiles: seat i's side is rotated by theta = -alpha*(i-1);
            -- r = outward direction of that side, t = along the side
            local l = DEFAULT_BOARD_LENGTH * BOARD_SCALES[N]
            local w = DEFAULT_BOARD_WIDTH * BOARD_SCALES[N]
            local a = w / WIDTH_LEG_RATIO
            local out = .5 * ((l / math.tan(math.pi / N)) + a - w)
            local over = a * math.sin(2 * math.pi / N) / 2
            local d = (l - a) / 17
            local theta = -(2 * math.pi / N) * (seat - 1)
            local rx, rz = math.sin(theta), -math.cos(theta)
            local tx, tz = math.cos(theta), math.sin(theta)
            local radial = out + w / 2 + BOT_HAND_OUTSET                     -- just outside the board
            local along = -(over + 2.5 * d) + (n - 2.5) * BOT_HAND_SPACING  -- centred on the bot's play zone
            return { x = rx * radial + tx * along, y = pile.getPosition().y + 0.1 + n * 0.02, z = rz * radial + tz * along },
                   { 0, pile.getRotation().y, 0 }
        end
    end
    return botStashPosition(color, n), nil
end

-- Put every card of a bot's hand in its slot (called whenever the hand changes, so there are no gaps/overlaps)
function botLayoutHand(color)
    for i, card in ipairs(BOT_STATE.hands[color] or {}) do
        local pos, rot = botHandSlot(color, i - 1)
        card.setPosition(pos)
        if rot then card.setRotation(rot) end
        card.setLock(true)
        card.interactable = false
        -- nobody sees a bot's cards (they are face down far off the table as well), unless !hands on
        pcall(function() card.setInvisibleTo(BOT_DEBUG_SHOW_HANDS and {} or BOT_ALL_COLORS) end)
    end
end
function botRelayoutHands()
    for color, _ in pairs(BOT_STATE.hands or {}) do botLayoutHand(color) end
end

local function botStashCard(color, card)
    table.insert(BOT_STATE.hands[color], card)
    botLayoutHand(color)
end

-- one card at a time, n times, then done()
local function drawCards(color, n, done)
    if n <= 0 then if done then done() end return end
    local deck = botFindDeck()
    if not deck then
        printToAll(botChatName(color) .. " cannot draw: no deck in the middle (reshuffle!)")
        if done then done() end
        return
    end
    local function after() Wait.time(function() drawCards(color, n - 1, done) end, 0.15) end
    if deck.tag == "Deck" then
        deck.takeObject({
            position = botStashPosition(color, #BOT_STATE.hands[color]),
            smooth = false,
            callback_function = function(card) botStashCard(color, card); after() end
        })
    else
        botStashCard(color, deck)
        after()
    end
end

-- A bot draws n cards from the deck (hidden in its hand), then done(). Logged as one "draw" event.
function botDrawCards(color, n, done)
    local before = #(BOT_STATE.hands[color] or {})
    drawCards(color, n, function()
        glogDraw(color, n, before)
        if done then done() end
    end)
end

-- Every bot holds 6 cards (user): at the start of every turn, a bot short of cards (an empty deck at its draw,
-- an undo, a seat handed over...) that isn't in the middle of a move draws back up to 6.
BOT_HAND_SIZE = 6
BOT_STATE.topping = BOT_STATE.topping or {}
function botTopUpHands()
    if not BOT_STATE.active or BOT_STATE.dealing then return end
    BOT_STATE.topping = BOT_STATE.topping or {}
    for color, on in pairs(BOT_STATE.seats or {}) do
        local hand = BOT_STATE.hands[color]
        local busy = BOT_STATE.current and BOT_STATE.current.color == color and not BOT_STATE.current.finished
        if on and hand and not busy and not BOT_STATE.topping[color] and #hand < BOT_HAND_SIZE then
            local missing = BOT_HAND_SIZE - #hand
            BOT_STATE.topping[color] = true
            pcall(glog, "topup", { color = color, cards = missing })
            botDrawCards(color, missing, function()
                BOT_STATE.topping[color] = nil
                if botRelayoutHands then pcall(botRelayoutHands) end
            end)
        end
    end
end

------------------------------------------------------------------------
-- seats changing hands mid-game (user 2026-11-12: "is it possible for someone to take a bot's seat halfway through")
------------------------------------------------------------------------
local function botBusyWith(color)
    local cur = BOT_STATE.current
    return cur and cur.color == color and not cur.finished
end

-- A player sat down in a bot's seat: the bot finishes the move it is making, then its cards go into the player's
-- hand and the seat is human from then on (if it is that seat's turn, the new player plays it).
function botSeatToHuman(color)
    if not (BOT_STATE.seats[color] and Player[color] and Player[color].seated) or BOT_ALL_SEATS then return end
    if botBusyWith(color) then
        Wait.condition(function() botSeatToHuman(color) end, function() return not botBusyWith(color) end, 60)
        return
    end
    local label = botChatName(color)
    BOT_STATE.seats[color] = nil
    local cards = BOT_STATE.hands[color] or {}
    BOT_STATE.hands[color] = {}
    local ok, ht = pcall(function() return Player[color].getHandTransform() end)
    for i, card in ipairs(cards) do
        pcall(function()
            card.setInvisibleTo({})
            card.setLock(false)
            card.interactable = true
            if ok and ht then
                local p = ht.position
                card.setPosition({ x = p.x, y = p.y + 0.3 * i, z = p.z })
                card.setRotation(ht.rotation)
            end
        end)
    end
    local name = personName(color) or "A player"
    printToAll(name .. " took over " .. label .. "'s seat")
    if turnNamePlayZones then pcall(turnNamePlayZones) end
    refreshGameUI()
    -- a bot turn for this seat that hasn't started yet becomes a human turn by itself (turnBegin checks botIsBot)
end

-- Host: a player left, give their seat to a bot (!botseat <colour>). It takes the cards left in their hand and
-- draws up to 6. Returns true, or false and a reason.
function botSeatFromHuman(color)
    if BOT_STATE.seats[color] then return false, "that seat is already a bot" end
    if Player[color] and Player[color].seated then return false, "someone is sitting there" end
    IRL.seats[color] = nil                               -- an in-person seat handed to a bot (hybrid mode)
    local cards = {}
    pcall(function()
        for _, obj in ipairs(Player[color].getHandObjects() or {}) do if obj.tag == "Card" then cards[#cards + 1] = obj end end
    end)
    BOT_STATE.seats[color] = true
    BOT_STATE.hands[color] = cards
    BOT_STATE.active = true
    botLayoutHand(color)
    if #cards < 6 then
        BOT_STATE.dealing = true                         -- its first turn waits for the cards (turnBegin)
        botDrawCards(color, 6 - #cards, function() BOT_STATE.dealing = false end)
    end
    printToAll(botChatName(color) .. " takes over the empty seat")
    if turnNamePlayZones then pcall(turnNamePlayZones) end
    refreshGameUI()
    -- it is that seat's turn (the game was waiting for the player who left): the bot plays it now
    if TURN_STATE and TURN_STATE.active and turnBegin and botSeatIndex(color) == TURN_STATE.seat and not BOT_STATE.current then
        Wait.time(function() turnBegin(TURN_STATE.seat) end, 1.5)
    end
    return true
end

-- a seat colour from what the host typed: the marble colour ("red") first, else the TTS seat colour
-- A seat from what the host typed: a seat number (the host's seat is 0, then 1, 2... going clockwise, the turn
-- order), a marble colour, a TTS seat colour, or an in-person seat's name (hybrid mode, play/hybrid.lua).
function botSeatFromName(text)
    local N = Global.getVar("num_players")
    text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local n = tonumber(text)
    if n and n == math.floor(n) and n >= 0 and n < (N or 0) then
        local colors, base = PLAYER_COLORS[N] or {}, 1
        pcall(function()
            for _, p in ipairs(Player.getPlayers() or {}) do
                if p.host then for i, c in ipairs(colors) do if c == p.color then base = i end end end
            end
        end)
        return colors[((base - 1 + n) % N) + 1]
    end
    if IRL and IRL.names then
        for c, name in pairs(IRL.names) do if tostring(name):lower() == text then return c end end
    end
    for _, c in ipairs(PLAYER_COLORS[N] or {}) do if marbleColorName(c):lower() == text then return c end end
    for _, c in ipairs(PLAYER_COLORS[N] or {}) do if c:lower() == text then return c end end
    return nil
end

