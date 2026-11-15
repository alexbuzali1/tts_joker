-- game/undo.lua  (Global script)
--
-- Undo (host only; the Undo button in the top-left panel, or !undo) undoes the most recent move and gives the turn
-- back to that player:
--   * every marble goes back where it was when that turn started
--   * the card(s) played go back into the player's hand (bots: into the bot's hand)
--   * a card drawn since goes back into the draw deck, which is then shuffled
--   * the stats go back to how they were (they are restored with the rest)
-- Press it during a turn that has started moving: that turn starts over. Press it again (or between turns): the
-- turn before is undone, and so on, up to UNDO_MAX turns back.
-- When the turn goes back to a bot, the game pauses there (a Resume button appears), so pressing Undo again can
-- go further back instead of the bot playing straight away.
-- A snapshot is taken at the start of every turn (turnBegin calls undoSnapshot).

UNDO = UNDO or { stack = {}, restoring = false }
UNDO_MAX = 40

local function seatColors() return PLAYER_COLORS[Global.getVar("num_players")] or {} end

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end

local function cardsInHand(color)
    local out = {}
    if botIsBot(color) then
        for _, c in ipairs(BOT_STATE.hands[color] or {}) do out[#out + 1] = c end
    else
        pcall(function()
            for _, o in ipairs(Player[color].getHandObjects() or {}) do if o.tag == "Card" then out[#out + 1] = o end end
        end)
    end
    return out
end

local function guidsOf(list)
    local g = {}
    for i, o in ipairs(list) do g[i] = o.getGUID() end
    return g
end

-- start of a turn (turnBegin, before statsTurnStart). A second call for the same turn (resume, a seat taken over)
-- replaces the snapshot instead of adding one.
function undoSnapshot(seat)
    if not GAME_STATS or UNDO.restoring then return end
    local snap = { seat = seat, turn = GAME_STATS.turn, stats = copy(GAME_STATS), marbles = {}, hands = {} }
    snap.stats.snapshot = nil
    for color, list in pairs(Global.getTable("marbles_by_player") or {}) do
        for _, m in ipairs(list) do
            local p = m.getPosition()
            snap.marbles[#snap.marbles + 1] = { obj = m, pos = { x = p.x, y = p.y, z = p.z } }
        end
    end
    for _, c in ipairs(seatColors()) do snap.hands[c] = guidsOf(cardsInHand(c)) end
    local top = UNDO.stack[#UNDO.stack]
    if top and top.seat == seat and top.turn == snap.turn then UNDO.stack[#UNDO.stack] = snap
    else UNDO.stack[#UNDO.stack + 1] = snap end
    while #UNDO.stack > UNDO_MAX do table.remove(UNDO.stack, 1) end
end

-- has anything happened since this snapshot?
local function changedSince(snap)
    if BOT_STATE.current then return true end
    if GAME_STATS and GAME_STATS.card_played then return true end
    for _, e in ipairs(snap.marbles) do
        local ok, p = pcall(function() return e.obj.getPosition() end)
        if ok and p and ((p.x - e.pos.x) ^ 2 + (p.z - e.pos.z) ^ 2) > 0.09 then return true end
    end
    for color, want in pairs(snap.hands) do
        local have = guidsOf(cardsInHand(color))
        if #have ~= #want then return true end
        local set = {}
        for _, g in ipairs(have) do set[g] = true end
        for _, g in ipairs(want) do if not set[g] then return true end end
    end
    return false
end

------------------------------------------------------------------------
-- cards
------------------------------------------------------------------------
-- a card by GUID: lying on the table, or inside a deck (a play zone's pile, or the draw deck after a reshuffle)
local function findCard(guid)
    local o = getObjectFromGUID(guid)
    if o and o.tag == "Card" then return o, nil end
    for _, d in ipairs(getAllObjects()) do
        if d.tag == "Deck" then
            local ok, list = pcall(function() return d.getObjects() end)
            for _, e in ipairs(ok and list or {}) do if e.guid == guid then return nil, d end end
        end
    end
    return nil, nil
end

local function giveCard(color, card)
    pcall(function()
        card.setVar("stat_counted_turn", nil)
        card.setVar("held_by", nil)
        card.setVar("last_player_color", color)
    end)
    if botIsBot(color) then
        table.insert(BOT_STATE.hands[color], card)
        botRelayoutHands()
        return
    end
    pcall(function()
        card.setInvisibleTo({})
        card.setLock(false)
        card.interactable = true
        local ht = Player[color].getHandTransform()
        local p = ht.position
        card.setRotation(ht.rotation)
        card.setPosition({ x = p.x, y = p.y + 0.5, z = p.z })
    end)
end

local function toDeck(card)
    local deck = findCenterDeck()
    pcall(function()
        card.setInvisibleTo({})
        card.setLock(false)
        card.interactable = true
        card.setVar("stat_counted_turn", nil)
        local p = deck and deck.getPosition() or { x = 0, y = 1, z = 0 }
        local r = deck and deck.getRotation() or { x = 0, y = 180, z = 180 }
        card.setRotation(r)
        card.setPosition({ x = p.x, y = p.y + 2, z = p.z })
    end)
end

local function restoreHands(snap)
    local returned = 0
    for color, want in pairs(snap.hands) do
        local wantSet = {}
        for _, g in ipairs(want) do wantSet[g] = true end
        local haveSet = {}
        for _, card in ipairs(cardsInHand(color)) do
            local g = card.getGUID()
            haveSet[g] = true
            if not wantSet[g] then                                    -- drawn since: back into the deck
                if botIsBot(color) then
                    for i, c in ipairs(BOT_STATE.hands[color]) do if c == card then table.remove(BOT_STATE.hands[color], i); break end end
                end
                toDeck(card)
                returned = returned + 1
            end
        end
        for _, g in ipairs(want) do
            if not haveSet[g] then                                    -- played since: back into the hand
                local card, deck = findCard(g)
                if card then giveCard(color, card)
                elseif deck then
                    local p = deck.getPosition()
                    deck.takeObject({ guid = g, position = { x = p.x, y = p.y + 3, z = p.z }, smooth = false,
                                      callback_function = function(c) giveCard(color, c) end })
                end
            end
        end
        if botIsBot(color) then botRelayoutHands() end
    end
    if returned > 0 then
        Wait.time(function() local d = findCenterDeck(); if d then pcall(function() d.shuffle() end) end end, 1.5)
    end
end

------------------------------------------------------------------------
-- undo
------------------------------------------------------------------------
local function restore(snap, who)
    UNDO.restoring = true
    if easyCancel then easyCancel() end
    botStopTurn()
    for _, e in ipairs(snap.marbles) do
        pcall(function()
            e.obj.setVar("picked_up", false)
            e.obj.setVar("rejecting", false)
            e.obj.setPosition({ x = e.pos.x, y = e.pos.y + 0.3, z = e.pos.z })
        end)
    end
    restoreHands(snap)
    GAME_STATS = copy(snap.stats)
    -- drop this snapshot and everything after it: turnBegin takes a fresh one
    while #UNDO.stack > 0 and UNDO.stack[#UNDO.stack] ~= snap do table.remove(UNDO.stack) end
    table.remove(UNDO.stack)
    local color = seatColors()[snap.seat]
    TURN_STATE.active, TURN_STATE.busy, TURN_STATE.seat = true, true, snap.seat
    TURN_STATE.paused = botIsBot(color) and true or false
    printToAll(who .. " pressed Undo: back to " .. playerLabel(color) .. "'s turn"
        .. (TURN_STATE.paused and " (paused: press Resume to let the bot play)" or ""))
    if glog then pcall(glog, "undo", { seat = snap.seat, color = color, turn = snap.turn, by = who }) end
    -- let the marbles and cards land before the turn starts again
    Wait.time(function()
        UNDO.restoring = false
        turnBegin(snap.seat)
        if refreshGameUI then refreshGameUI() end
    end, 1.5)
end

function undoClicked(player)
    if UNDO.restoring or UNDO.waiting or not (TURN_STATE and TURN_STATE.active) or not GAME_STATS or GAME_STATS.winner ~= 0 then return end
    local who = player and player.color and playerLabel(player.color) or "The host"
    local pl = player and player.color and Player[player.color]
    if pl and not pl.host then                                      -- user: Undo is for the host only
        broadcastToColor("Only the host can undo", player.color, { 1, 0.8, 0.3 })
        return
    end
    -- a bot is in the middle of its turn: let it finish (cards and marbles mid-air are not safe to put back), hold
    -- the game before the next turn, then undo the bot's turn
    if BOT_STATE.current or (TURN_STATE.busy and botIsBot(seatColors()[TURN_STATE.seat] or "")) then
        UNDO.waiting = true
        TURN_STATE.paused = true
        if refreshGameUI then refreshGameUI() end
        printToAll(who .. " pressed Undo: waiting for the bot to finish its move")
        Wait.condition(function() UNDO.waiting = false; undoClicked(player) end,
            function() return not BOT_STATE.current and not TURN_STATE.busy end, 60, function() UNDO.waiting = false end)
        return
    end
    -- an easy-play move is still being animated: undo once it has landed
    if EASY and EASY.session and EASY.session.busy then
        UNDO.waiting = true
        Wait.condition(function() UNDO.waiting = false; undoClicked(player) end,
            function() return not (EASY.session and EASY.session.busy) end, 30, function() UNDO.waiting = false end)
        return
    end
    local top = UNDO.stack[#UNDO.stack]
    if not top then
        if player and player.color then broadcastToColor("Nothing to undo", player.color, { 1, 0.8, 0.3 }) end
        return
    end
    if changedSince(top) then restore(top, who)
    elseif #UNDO.stack >= 2 then restore(UNDO.stack[#UNDO.stack - 1], who)
    elseif player and player.color then broadcastToColor("Nothing to undo", player.color, { 1, 0.8, 0.3 }) end
end

-- Pause / Resume (anyone): the game holds before the next turn starts (a move in progress finishes first)
function undoPause(player)
    if not (TURN_STATE and TURN_STATE.active) or TURN_STATE.paused then return end
    turnSetPaused(true, player and player.color and playerLabel(player.color) or nil)
    if refreshGameUI then refreshGameUI() end
end

function undoResume(player)
    if TURN_STATE and TURN_STATE.paused then
        turnSetPaused(false, player and player.color and playerLabel(player.color) or nil)
    end
    if refreshGameUI then refreshGameUI() end
end

-- A new game starts with no undo history (resetForNewGame in Global).
function undoReset()
    UNDO.stack, UNDO.restoring, UNDO.waiting = {}, false, false
end
