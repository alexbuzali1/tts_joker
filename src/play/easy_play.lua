-- play/easy_play.lua  (Global script)
-- Easy play (a per-player toggle, bottom right; off by default): play a card as usual, then click instead of drag.
--   * the marbles (or spots) you can choose get a pulsing see-through yellow ring; click one and it moves with the
--     bots' animation, then your turn ends by itself
--   * normal cards: click the marble; if it can end up in two places (a 5 that can enter the finish or run past it)
--     the two spots light up next
--   * Joker: the marble to move (any marble in your start), then the marble to land on
--   * 7: the first marble, then its spot (that part plays straight away, so anything it bonks has landed), then the
--     second marble and its spot. Either part can go first; the order matters for bonks
--   * whenever there's only one thing to click it's clicked for you, and a move that wins the game always plays
--   * no legal move: the card is burned and the turn ends
--   * taking the card back stops it; playing another card starts over; Cancel lets you move by hand
-- Clicking = picking up: Global onPlayerAction asks easyOnPickUp first, and a pick-up it uses is cancelled, so
-- nothing leaves the board. Empty spots get an invisible button to click (TTS doesn't report clicks on locked or
-- hidden objects). The on-screen END TURN is hidden for players with easy play on.
-- The host also uses easy play to enter in-person players' moves (play/hybrid.lua): the session's `ctrl` is then
-- the host's colour while `color` is the in-person seat.
EASY = EASY or { on = {}, session = nil, n = 0 }
EASY.click = EASY.click or {}           -- [colour] = click a card in the hand to play it (its own toggle, user)
EASY.markers = EASY.markers or {}       -- marker GUID -> { v = pick value, mi = marble index or nil }
EASY_PULSE = 0.6                        -- seconds bright, then dim
EASY_GLOW = { r = 1, g = 0.95, b = 0.1 }
EASY_DIM = { r = 1, g = 0.45, b = 0 }
EASY_BURN_WAIT = 0.3                    -- a burned card: the turn ends right away (user: no delay; was 2.5 s)

local function seatColors() return PLAYER_COLORS[Global.getVar("num_players")] or {} end

-- Pick values (strings): "m<i>" a marble, "S<seat>" any marble in that seat's start (they're all the same move),
-- "c<i>" a board spot (index into non_start_points).
local function marbleValue(S, mi)
    local m = S.marbles[mi]
    if m and m.kind == 'S' then return "S" .. m.seat end
    return "m" .. mi
end
local function spotValue(S, st) return "c" .. JokerBot.cellToIndex(st.kind, st.p, S.marbles[st.mi].seat) end

-- the clicks an action needs, in order
local function actionPicks(S, a)
    local st = a.steps or {}
    if not st[1] then return {} end
    if a.card == '$' then
        local tgt
        for _, b in ipairs(a.bumpList or {}) do tgt = b.idx; break end
        return { marbleValue(S, st[1].mi), tgt and ("m" .. tgt) or nil }
    end
    local t = {}
    for _, x in ipairs(st) do t[#t + 1] = marbleValue(S, x.mi); t[#t + 1] = spotValue(S, x) end
    return t
end

-- where every marble ends up: actions with the same key are the same move
local function outcomeKey(a)
    local t = {}
    for i, m in ipairs(a.state.marbles) do t[i] = m.kind .. m.p end
    return table.concat(t, ",")
end

-- "7: seat1#1 +2 and seat3#4 +5 (bonks seat 2)" -> "Blue 1 +2 and Green 4 +5 (bonks Red)"
function easyDescribe(a)
    local cols = seatColors()
    local function nm(s) local c = cols[tonumber(s)]; return c and marbleColorName(c) or ("seat " .. s) end
    local t = tostring(a.text or "")
    local colon = t:find(":", 1, true)
    if colon then t = t:sub(colon + 1) end
    t = t:gsub("seat(%d+)#(%d+)", function(s, k) return nm(s) .. " " .. (((tonumber(k) - 1) % 5) + 1) end)
    t = t:gsub("teammate seat (%d+)", function(s) return "teammate " .. nm(s) end)
    t = t:gsub("seat (%d+)", nm)
    return (t:gsub("^%s+", ""))
end

local function cardWord(token)
    local W = { a = "Ace", j = "Jack", q = "Queen", k = "King", ['$'] = "Joker" }
    return W[token] or token
end

------------------------------------------------------------------------
-- glow: the marble's own highlight plus a marker floating over it (or over a spot), both pulsing
------------------------------------------------------------------------
local function holeSpacing()
    local nsp = Global.getTable("non_start_points") or {}
    local a, b = nsp[1] and nsp[1].position, nsp[2] and nsp[2].position
    if not (a and b) then return 1.5 end
    local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
    return (d > 0.2 and d < 10) and d or 1.5
end

local ALL_COLORS = { "White", "Brown", "Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Purple", "Pink", "Grey", "Black" }

-- An empty spot gets a click target: a fully transparent button lying on the hole. TTS doesn't report clicks on
-- locked objects or on hidden ones, but buttons always work. The button sits on a small locked block sunk under
-- the board (out of sight). A spot with a marble on it needs none: clicking that marble picks the spot.
EASY_TARGET_NAME = "Easy play target"
EASY_BUTTON_PER_UNIT = 500        -- button size units per world unit (roughly; a button 0.7 of a hole spacing wide)
local SINK = 1.5
local function spawnMarker(pos, v, mi)
    local d = holeSpacing()
    -- pos.y is a marble's centre, just above the board (the holes are thin blocks with their tops ~0.07 lower):
    -- the button lies a little above that so nothing covers it
    local top = pos.y + 0.08
    local ok, o = pcall(spawnObject, {
        type = "BlockSquare", position = { pos.x, top - SINK, pos.z }, rotation = { 0, 0, 0 },
        scale = { 1, 1, 1 }, sound = false })
    if not ok or not o then return nil end
    pcall(function()
        o.setLock(true)
        o.setName(EASY_TARGET_NAME)
        o.tooltip = false
        local w = math.floor(0.7 * d * EASY_BUTTON_PER_UNIT)
        o.createButton({ click_function = "easySpotClicked", function_owner = Global, label = "",
                         position = { 0, SINK, 0 }, rotation = { 0, 0, 0 }, width = w, height = w,
                         color = { 0, 0, 0, 0 }, hover_color = { 1, 0.9, 0.1, 0.25 }, press_color = { 1, 0.9, 0.1, 0.5 },
                         tooltip = "" })
    end)
    EASY.markers[o.getGUID()] = { v = v, mi = mi }
    return o
end

function easySpotClicked(obj, player_color)
    if obj and player_color then easyOnPickUp({ color = player_color }, { obj }) end
end

EASY_RING_LIFT = 0.45             -- rings drawn this far above a marble's centre height (user: they were inside the board)
-- the rings: see-through yellow circles drawn on the table (vector lines), pulsing
local function ringLines(s, on)
    local d = holeSpacing()
    local r = 0.42 * d                -- outer edge under half a hole spacing: neighbouring rings don't overlap (user)
    local col = on and { 1, 0.9, 0.1, 0.8 } or { 1, 0.6, 0, 0.5 }   -- 80% opaque at its brightest (user)
    local lines = {}
    for _, c in ipairs(s.rings or {}) do
        local pts = {}
        for k = 0, 23 do
            local a = k / 24 * 2 * math.pi
            pts[#pts + 1] = { c.x + r * math.cos(a), c.y + EASY_RING_LIFT, c.z + r * math.sin(a) }
        end
        lines[#lines + 1] = { points = pts, color = col, thickness = 0.09 * d, loop = true }
    end
    return lines
end

local function drawRings(s, on)
    local ok, err = pcall(function()
        if EASY.baseLines == nil then EASY.baseLines = Global.getVectorLines() or {} end
        local all = {}
        for _, l in ipairs(EASY.baseLines) do all[#all + 1] = l end
        for _, l in ipairs(ringLines(s, on)) do all[#all + 1] = l end
        Global.setVectorLines(all)
    end)
    if not ok and not EASY.ringErr then
        EASY.ringErr = true
        if botHostMsg then botHostMsg("Easy play: couldn't draw the rings (" .. tostring(err) .. ")", { 1, 0.5, 0.3 }) end
    end
end

-- leftover click targets (an earlier version's markers, or a reload mid-choice): remove them
function easyCleanup()
    for _, o in ipairs(getAllObjects()) do
        local ok, n = pcall(function() return o.getName() end)
        if ok and (n == EASY_TARGET_NAME or n == "Easy play: click") and not EASY.markers[o.getGUID()] then
            pcall(function() o.destruct() end)
        end
    end
end

local function clearRings()
    if EASY.baseLines == nil then return end
    local base = EASY.baseLines
    EASY.baseLines = nil
    pcall(function() Global.setVectorLines(base) end)
end

local function glowOff(s)
    for _, o in ipairs(s.glowObjs or {}) do
        if marbleRestoreOutline then marbleRestoreOutline(o) else pcall(function() o.highlightOff() end) end
    end
    for _, o in ipairs(s.markObjs or {}) do pcall(function() o.destruct() end) end
    s.glowObjs, s.markObjs, s.rings = {}, {}, {}
    EASY.markers = {}
    clearRings()
end

local function pulse(id, on)
    local s = EASY.session
    if not s or s.id ~= id or s.busy then return end
    for _, o in ipairs(s.glowObjs) do
        pcall(function() if on then o.highlightOn(EASY_GLOW) else o.highlightOn(EASY_DIM) end end)
    end
    drawRings(s, on)
    Wait.time(function() pulse(id, not on) end, EASY_PULSE)
end

-- the spot a marble is sitting on ("c<i>"), or nil in the start
local function marbleSpot(S, mi)
    local m = S.marbles[mi]
    if not m or m.kind == 'S' then return nil end
    return "c" .. JokerBot.cellToIndex(m.kind, m.p, m.seat)
end

local function glow(s, set)
    glowOff(s)
    local nsp = Global.getTable("non_start_points") or {}
    local taken = {}
    for mi, o in pairs(s.objs) do local c = marbleSpot(s.S, mi); if c then taken[c] = o end end
    for v in pairs(set) do
        local kind, n = v:sub(1, 1), tonumber(v:sub(2))
        if kind == "m" or kind == "S" then
            for mi, o in pairs(s.objs) do
                local m = s.S.marbles[mi]
                if (kind == "m" and mi == n) or (kind == "S" and m.kind == 'S' and m.seat == n) then
                    s.glowObjs[#s.glowObjs + 1] = o
                    local ok, p = pcall(function() return o.getPosition() end)
                    if ok and p then s.rings[#s.rings + 1] = { x = p.x, y = p.y, z = p.z } end
                end
            end
        elseif kind == "c" and nsp[n] then
            local p = nsp[n].position
            if taken[v] then
                -- a marble sits on the spot: ring it at marble height, or the marble hides a ring down in the hole
                -- (user); clicking the marble picks the spot
                local ok, q = pcall(function() return taken[v].getPosition() end)
                if ok and q then p = q end
                s.rings[#s.rings + 1] = { x = p.x, y = p.y, z = p.z }
            else
                s.rings[#s.rings + 1] = { x = p.x, y = p.y, z = p.z }
                s.markObjs[#s.markObjs + 1] = spawnMarker(p, v, nil)
            end
        end
    end
    s.pulseId = (s.pulseId or 0) + 1
    s.id = s.baseId * 1000 + s.pulseId
    pulse(s.id, true)
end

function easyIsMarker(o)
    local ok, g = pcall(function() return o.getGUID() end)
    return ok and g and EASY.markers[g] ~= nil
end

------------------------------------------------------------------------
-- session
------------------------------------------------------------------------
function easyCancel(why)
    local s = EASY.session
    EASY.burn = nil
    if not s then return end
    glowOff(s)
    EASY.session = nil
    if why then broadcastToColor(why, s.ctrl or s.color, { 1, 0.8, 0.3 }) end
    if refreshGameUI then refreshGameUI() end
end

local function promptText(s)
    local k = #s.picks
    if s.choices then return "Pick a move" end
    if s.card == '$' then return k == 0 and "Joker: click the marble to move" or "Joker: click the marble to land on" end
    if s.card == '7' then
        local part = k < 2 and "first" or "second"
        if k % 2 == 0 then return "7: click the " .. part .. " marble to move" end
        return "7: click where the " .. part .. " marble goes"
    end
    if k % 2 == 1 then return cardWord(s.card) .. ": click where it goes" end
    return cardWord(s.card) .. ": click the marble to move"
end

-- the human's turn ends by itself after an easy-play move or burn (same as clicking END TURN)
local function autoEndTurn(color, gen)
    if not (TURN_STATE and TURN_STATE.active) or TURN_STATE.gen ~= gen or TURN_STATE.busy then return end
    if seatColors()[TURN_STATE.seat] ~= color then return end
    endTurnClicked(nil, color, false)
end

local function execute(a)
    local s = EASY.session
    s.busy = true
    glowOff(s)
    s.choices = nil
    if refreshGameUI then refreshGameUI() end
    -- a marble clicked in the start may not be the one the action names (they're all the same move): swap them
    local objs = {}
    for i, o in pairs(s.objs) do objs[i] = o end
    local rep, clicked = a.steps[1].mi, s.clicked[1]
    if clicked and clicked ~= rep and objs[clicked] then objs[rep], objs[clicked] = objs[clicked], objs[rep] end
    local gen = TURN_STATE and TURN_STATE.gen
    if s.leg1 then a = { card = a.card, steps = { a.steps[2] }, state = a.state, bumps = a.bumps } end   -- part 1 is done
    botRunMove(a, objs, function()
        if EASY.session == s then EASY.session = nil end
        if refreshGameUI then refreshGameUI() end
        autoEndTurn(s.color, gen)
    end, true)
end

function runLeg1(s, a)
    s.busy = true
    glowOff(s)
    if refreshGameUI then refreshGameUI() end
    local leg = { card = a.card, steps = { a.steps[1] }, state = a.state, bumps = a.bumps }
    botRunMove(leg, s.objs, function()
        if EASY.session ~= s then return end
        s.busy, s.leg1 = false, true
        s.S, s.objs = botReadState()                    -- the board as it is now (bonks included)
        easyNextStep()
    end, true)
end

-- after each click: glow the next choices; when every click is made, play it (or list the moves if still several)
function easyNextStep()
    local s = EASY.session
    if not s then return end
    while true do
        local k = #s.picks
        local cand, seen, distinct = {}, {}, 0
        for _, a in ipairs(s.acts) do
            local ok = true
            for i = 1, k do if a.picks[i] ~= s.picks[i] then ok = false; break end end
            if ok then
                cand[#cand + 1] = a
                if not seen[a.key] then seen[a.key] = true; distinct = distinct + 1 end
            end
        end
        if #cand == 0 then easyCancel("That move isn't possible - play it by hand"); return end
        -- a 7: the first part plays as soon as its spot is picked (user), so a marble it bonks is already where it
        -- lands when the second marble is picked
        if s.card == '7' and k == 2 and not s.leg1 and cand[1].steps[2] then runLeg1(s, cand[1]); return end
        local nextSet, n, only = {}, 0, nil
        for _, a in ipairs(cand) do
            local v = a.picks[k + 1]
            if v and not nextSet[v] then nextSet[v] = true; n = n + 1; only = v end
        end
        -- only one thing to click: it's clicked for you (user), so a move with no choice plays by itself
        if n == 1 then
            s.picks[#s.picks + 1] = only
        elseif n > 0 then
            s.next = nextSet
            glow(s, nextSet)
            if refreshGameUI then refreshGameUI() end
            return
        else
            -- every click made: play it, or choose when several moves are still left
            if distinct == 1 then execute(cand[1]); return end
            local list, used = {}, {}
            for _, a in ipairs(cand) do
                if not used[a.key] then used[a.key] = true; list[#list + 1] = a end
            end
            s.next = nil
            s.choices = list
            glowOff(s)
            if refreshGameUI then refreshGameUI() end
            return
        end
    end
end

-- a card landed on its owner's play zone (handlers.lua)
function easyCardPlayed(color, card)
    if not EASY.on[color] then return end
    if not (TURN_STATE and TURN_STATE.active) or TURN_STATE.paused then return end
    if seatColors()[TURN_STATE.seat] ~= color or botIsBot(color) then return end
    local token = botCardToken(card.getName())
    if not token then return end
    easyStart(color, token, card.getGUID(), nil)
end

-- Start choosing a move for `color`'s turn with that card. ctrl = who clicks (nil = that player; the host for an
-- in-person seat, irl.lua). Returns false if a move is already being played.
function easyStart(color, token, guid, ctrl)
    local s0 = EASY.session
    if s0 and s0.busy then return false end               -- a move is already being played
    if s0 then glowOff(s0); EASY.session = nil end
    EASY.burn = nil
    pcall(easyCleanup)
    local S, objs = botReadState()
    local seat = botSeatIndex(color)
    local acts = JokerBot.legalActions(S, seat, { token })
    if #acts == 0 then
        broadcastToColor("No legal move with that " .. cardWord(token) .. ": it's burned.", ctrl or color, { 1, 0.8, 0.3 })
        if refreshGameUI then refreshGameUI() end
        local burn = { guid = guid, gen = TURN_STATE.gen }
        EASY.burn = burn
        Wait.time(function()
            if EASY.burn ~= burn then return end          -- taken back, or another card played
            EASY.burn = nil
            autoEndTurn(color, burn.gen)
        end, EASY_BURN_WAIT)
        return true
    end
    -- a move that wins the game: only those (user: nobody runs past their finish on the last move)
    local winning = {}
    for _, a in ipairs(acts) do
        local all = true
        for t = 1, a.state.N do
            if t % 2 == seat % 2 and not JokerBot.isFinished(a.state, t) then all = false; break end
        end
        if all then winning[#winning + 1] = a end
    end
    if #winning > 0 then acts = winning end
    for _, a in ipairs(acts) do a.picks = actionPicks(S, a); a.key = outcomeKey(a) end
    EASY.n = EASY.n + 1
    EASY.session = { color = color, ctrl = ctrl, seat = seat, guid = guid, card = token, acts = acts, picks = {},
                     clicked = {}, S = S, objs = objs, baseId = EASY.n, glowObjs = {}, markObjs = {} }
    easyNextStep()
    return true
end

-- the played card left the play zone (taken back): stop
function easyCardRemoved(color, card)
    local g = card.getGUID()
    if EASY.burn and EASY.burn.guid == g then EASY.burn = nil end
    local s = EASY.session
    if s and s.color == color and not s.busy and s.guid == g then easyCancel() end
end

-- a marble or marker was clicked (picked up). Returns true when easy play used the click (the pick-up is then
-- cancelled). Markers can never be picked up.
function easyOnPickUp(player, targets)
    local s = EASY.session
    local marker
    for _, o in ipairs(targets or {}) do if o and easyIsMarker(o) then marker = o end end
    if not (s and player and player.color == (s.ctrl or s.color)) then return marker ~= nil end
    if s.busy then return true end                        -- hands off while the move plays
    local v, mi
    if marker then
        local e = EASY.markers[marker.getGUID()]
        v, mi = e.v, e.mi
    else
        local obj
        for _, o in ipairs(targets or {}) do if o and o.tag == "Checker" then obj = o; break end end
        if not obj then return false end
        local guid = obj.getGUID()
        for i, o in pairs(s.objs) do if o.getGUID() == guid then mi = i end end
        if mi then
            v = marbleValue(s.S, mi)
            -- choosing a spot: clicking the marble sitting on it picks that spot
            if not (s.next and s.next[v]) then v = marbleSpot(s.S, mi) or v end
        end
    end
    if v and s.next and s.next[v] then
        if v:sub(1, 1) ~= "c" then s.clicked[#s.picks + 1] = mi end
        s.picks[#s.picks + 1] = v
        easyNextStep()
        return true
    end
    if s.choices then
        broadcastToColor("Pick one of the moves on screen (or Cancel)", s.ctrl or s.color, { 1, 0.8, 0.3 })
    else
        broadcastToColor("Click something glowing (or Cancel to move by hand)", s.ctrl or s.color, { 1, 0.8, 0.3 })
    end
    return true
end


------------------------------------------------------------------------
-- on-screen UI: the toggle for every player, the prompt / chooser for the player choosing
------------------------------------------------------------------------
function easyToggle(player)
    if not player or not player.color then return end
    EASY.on[player.color] = not EASY.on[player.color]
    if not EASY.on[player.color] and EASY.session and EASY.session.color == player.color then easyCancel() end
    broadcastToColor(EASY.on[player.color] and "Easy play ON: play a card, then click a glowing marble"
                     or "Easy play OFF: move marbles by hand", player.color, { 0.6, 1, 0.6 })
    if refreshGameUI then refreshGameUI() end
end


function easyCancelClicked(player)
    local s = EASY.session
    if s and player and player.color == (s.ctrl or s.color) and not s.busy then
        easyCancel(s.leg1 and "Easy play cancelled: move the rest of the 7 by hand" or "Easy play cancelled: move by hand")
    end
end

function easyChoose(player, value, id)
    local s = EASY.session
    if not (s and player and player.color == (s.ctrl or s.color) and s.choices) then return end
    local i = tonumber(tostring(id or ""):match("(%d+)$"))
    local a = i and s.choices[i]
    if a then execute(a) end
end

local function esc(t) return (tostring(t):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")) end

function easyUiXml()
    if not (GAME_STATS and TURN_STATE and TURN_STATE.active) then return "" end
    local x = {}
    -- one toggle per seat, each only visible to that player
    for _, c in ipairs(seatColors()) do
        if not botIsBot(c) then
            local on = EASY.on[c]
            x[#x + 1] = string.format('<Button id="easyToggle_%s" visibility="%s" onClick="easyToggle" rectAlignment="LowerRight" '
                .. 'offsetXY="-20 230" width="200" height="44" fontSize="18" fontStyle="Bold" textColor="#FFFFFF" color="%s">Easy play: %s</Button>',
                c, c, on and "#1F8F3A" or "#555555", on and "ON" or "OFF")
            local cl = EASY.click[c]
            x[#x + 1] = string.format('<Button id="clickToggle_%s" visibility="%s" onClick="clickToggle" rectAlignment="LowerRight" '
                .. 'offsetXY="-20 180" width="200" height="40" fontSize="16" fontStyle="Bold" textColor="#FFFFFF" color="%s">Click to play: %s</Button>',
                c, c, cl and "#1F8F3A" or "#555555", cl and "ON" or "OFF")
        end
    end
    local s = EASY.session
    if s and not s.busy then
        local h = 60 + (s.choices and 44 * #s.choices or 0)
        x[#x + 1] = string.format('<Panel id="easyPrompt" visibility="%s" rectAlignment="LowerCenter" offsetXY="0 40" width="560" height="%d" color="#000000D0" padding="10 10 8 8">'
            .. '<VerticalLayout spacing="6">', s.ctrl or s.color, h)
        x[#x + 1] = string.format('<HorizontalLayout spacing="8" preferredHeight="40"><Text fontSize="20" fontStyle="Bold" color="#FFE066" preferredWidth="420">%s</Text>'
            .. '<Button onClick="easyCancelClicked" fontSize="16" preferredWidth="110">Cancel</Button></HorizontalLayout>', esc(promptText(s)))
        for i, a in ipairs(s.choices or {}) do
            x[#x + 1] = string.format('<Button id="easyOpt_%d" onClick="easyChoose" fontSize="17" preferredHeight="38">%s</Button>', i, esc(easyDescribe(a)))
        end
        x[#x + 1] = '</VerticalLayout></Panel>'
    end
    return table.concat(x, "\n")
end

