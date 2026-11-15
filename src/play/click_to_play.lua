-- play/click_to_play.lua  (Global script)
-- Click to play (a per-player toggle under Easy play, independent of it; off by default): a quick click on a card
-- in your hand plays it - it flies onto your play zone (1.5 s on slow, 1 s normal, 0.5 s fast, straight there on
-- instant, following the bots' !speed). Dragging still works (onto the zone, or along the hand to rearrange), and
-- clicking and holding over half a second (thinking) puts the card back. Only on your own turn, first card only.
-- How a click is told apart: Global onPlayerAction / onObjectPickedUp report the pick-up (easyCardLifted), and
-- onObjectDrop the drop (easyCardDropped); a click is let go where it was picked up, within EASY_CLICK_HOLD seconds.

local function seatColors() return PLAYER_COLORS[Global.getVar("num_players")] or {} end

------------------------------------------------------------------------
-- click a card in your hand to play it (user): a card picked up from the hand and let go about where it was
-- (a click, not a drag) goes onto your play zone. Dragging it somewhere else (rearranging the hand, or onto the
-- zone yourself) works as before. Only on your own turn, before you've played a card.
------------------------------------------------------------------------
EASY_CLICK_DIST = 0.8
EASY_CLICK_HOLD = 0.5            -- held longer than this (thinking, user) = not a click: it goes back in the hand
local function now()
    local ok, t = pcall(function() return Time.time end)
    if ok and type(t) == "number" then return t end
    return os.clock()
end
-- seconds for a clicked card to fly to the play zone, by the bots' speed setting (user); 0 = straight there
EASY_PLAY_FLIGHT = { Slow = 1.5, Normal = 1.0, Fast = 0.5, Instant = 0 }
function easyFlightTime()
    local sp = botSpeed()
    local t = sp and EASY_PLAY_FLIGHT[sp.name]
    return t or 1.0
end
EASY_PLAY_STEP = 0.03
EASY_HAND_HOP = 3.5               -- first hop out of the hand zone, toward the play zone
EASY.lift = EASY.lift or {}

local function canClickPlay(color)
    if not EASY.click[color] or not (TURN_STATE and TURN_STATE.active) or TURN_STATE.paused or TURN_STATE.busy then return false end
    if seatColors()[TURN_STATE.seat] ~= color or botIsBot(color) then return false end
    if GAME_STATS and GAME_STATS.card_played then return false end
    if EASY.session and EASY.session.busy then return false end
    return true
end

EASY_CLICK_DEBUG = false         -- true: tell the host what click-to-play saw for every click (for debugging)
local function clickDebug(msg)
    if EASY_CLICK_DEBUG and botHostMsg then botHostMsg("[click-to-play] " .. msg, { 0.7, 0.85, 1 }) end
end

-- in that player's hand: TTS's hand list, or lying inside the hand area
local function inHandArea(color, card)
    local yes = false
    pcall(function()
        for _, o in ipairs(Player[color].getHandObjects() or {}) do if o == card then yes = true end end
    end)
    if yes then return true, "hand list" end
    local ok, inside = pcall(function()
        local ht = Player[color].getHandTransform()
        local p, c = card.getPosition(), ht.position
        local a = math.rad(-(ht.rotation and ht.rotation.y or 0))
        local dx, dz = p.x - c.x, p.z - c.z
        local lx, lz = dx * math.cos(a) - dz * math.sin(a), dx * math.sin(a) + dz * math.cos(a)
        local sc = ht.scale or { x = 12, z = 4 }
        return math.abs(lx) <= (sc.x or 12) / 2 + 1 and math.abs(lz) <= (sc.z or 4) / 2 + 2
    end)
    return ok and inside, "hand area"
end

-- called from onPlayerAction (before the pick-up) and onObjectPickedUp (after): the first one counts
function easyCardLifted(color, card)
    if not EASY.click[color] then return end
    local g = card.getGUID()
    if EASY.lift[g] and EASY.lift[g].color == color then return end
    EASY.lift = {}
    if not canClickPlay(color) then clickDebug("picked up, but you can't click-play right now"); return end
    local inHand, how = inHandArea(color, card)
    if not inHand then clickDebug("picked up a card that isn't in your hand"); return end
    local p = card.getPosition()
    EASY.lift[g] = { x = p.x, z = p.z, color = color, t = now() }
    clickDebug("picked up " .. tostring(card.getName()) .. " from your hand (" .. how .. ")")
end

function easyCardDropped(color, card)
    local e = EASY.lift[card.getGUID()]
    EASY.lift = {}
    if not EASY.click[color] then return end
    if not e then clickDebug("dropped " .. tostring(card.getName()) .. ", but no pick-up from the hand was seen"); return end
    if not canClickPlay(color) or not botCardToken(card.getName()) then clickDebug("dropped, but can't play it now"); return end
    local p = card.getPosition()
    local d = math.sqrt((p.x - e.x) ^ 2 + (p.z - e.z) ^ 2)
    if d > EASY_CLICK_DIST then clickDebug(string.format("moved %.1f: a drag, not a click", d)); return end
    local held = now() - (e.t or now())
    if held > EASY_CLICK_HOLD then clickDebug(string.format("held %.1f s: not played", held)); return end
    clickDebug(string.format("click (moved %.1f): playing it", d))
    local pile = (Global.getTable("discard_piles") or {})[color]
    if not pile then return end
    -- TTS's hand zone pulls back a card that glides out of it, so the card first hops just outside the hand (a
    -- teleport), then flies to the play zone in EASY_PLAY_FLIGHT seconds (moved step by step, locked so physics
    -- leaves it alone), turning face up, and drops onto the zone
    local function land()
        pcall(function()
            local pp, rot = pile.getPosition(), pile.getRotation()
            card.setLock(false)
            card.setVar("last_player_color", color)
            card.setRotation({ 0, rot.y, 0 })
            card.setPosition({ pp.x, pp.y + 1, pp.z })
        end)
    end
    local flight = easyFlightTime()
    local function fly()
        if flight <= 0 then land(); return end               -- Instant
        local ok, from = pcall(function()
            local pp, p0 = pile.getPosition(), card.getPosition()
            -- out of the hand: toward the zone and up
            local dx, dz = pp.x - p0.x, pp.z - p0.z
            local len = math.sqrt(dx * dx + dz * dz)
            if len < 0.01 then len = 1 end
            local hop = math.min(EASY_HAND_HOP, len * 0.5)
            local start = { x = p0.x + dx / len * hop, y = p0.y + 2, z = p0.z + dz / len * hop }
            card.setVar("last_player_color", color)
            card.setLock(true)
            card.setPosition(start)
            card.setRotationSmooth({ 0, pile.getRotation().y, 0 }, false, false)
            return start
        end)
        if not ok or not from then land(); return end
        local steps = math.max(1, math.floor(flight / EASY_PLAY_STEP + 0.5))
        local k = 0
        local function step()
            k = k + 1
            local ok2 = pcall(function()
                if card.isDestroyed() then return end
                local pp = pile.getPosition()
                local t = k / steps
                local e = t * t * (3 - 2 * t)                       -- ease in and out
                local to = { x = pp.x, y = pp.y + 1, z = pp.z }
                local arc = 2.5 * math.sin(math.pi * t)             -- a little arc over the table
                card.setPosition({ from.x + (to.x - from.x) * e, from.y + (to.y - from.y) * e + arc, from.z + (to.z - from.z) * e })
            end)
            if not ok2 or k >= steps then land(); return end
            Wait.time(step, EASY_PLAY_STEP)
        end
        Wait.time(step, EASY_PLAY_STEP)
    end
    Wait.frames(function()
        fly()
        Wait.time(function()                              -- back in the hand anyway: send it straight there
            local ok, back = pcall(function()
                if card.isDestroyed() then return false end
                local q, pp = card.getPosition(), pile.getPosition()
                return not isNear(q.x, q.z, pp.x, pp.z, 1.5)
            end)
            if ok and back and canClickPlay(color) then clickDebug("the card didn't arrive: sending it straight there"); land() end
        end, flight + 0.6)
    end, 2)
end


function clickToggle(player)
    if not player or not player.color then return end
    EASY.click[player.color] = not EASY.click[player.color]
    broadcastToColor(EASY.click[player.color] and "Click to play ON: click a card in your hand to play it (drag to rearrange)"
                     or "Click to play OFF: drag cards onto your play zone", player.color, { 0.6, 1, 0.6 })
    refreshGameUI()
end
