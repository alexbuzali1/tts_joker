-- tts_mock.lua: a small mock of the Tabletop Simulator API, shared by the tests.
-- Usage:  local M = dofile("tts_mock.lua"); M.setup(4, { White = true })   -- N players, seated colours
-- Simulates just enough "physics" for the hooks under test:
--   * a Card that lands on a play zone fires onObjectEnterScriptingZone(zone, card)
--   * a Checker that lands on top of another Checker fires marbleCollisionDetection(lower, {collision_object = upper})
-- Timers (Wait.time) are queued and run in time order by M.pump().

local M = {}

PLAYER_COLORS = {
    [4] = { "White", "Orange", "Green", "Purple" },
    [6] = { "White", "Red", "Yellow", "Green", "Blue", "Pink" },
    [8] = { "White", "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink" },
}
MARBLE_COLORS = { {r=0,g=0,b=0}, {r=0,g=0,b=1}, {r=0,g=1,b=0}, {r=1,g=0,b=0}, {r=0,g=1,b=1}, {r=1,g=0,b=1}, {r=1,g=1,b=0}, {r=1,g=1,b=1} }
TURN_BUTTON_GUID = "435315"; COLOR_PICKER_GRID_SIZE = 10
COLLISION_DISTANCE_THRESHOLDS = { [4] = 1, [6] = .7, [8] = .59 }
HOVER_NUMBER_ROTATION = 45

M.chat, M.broadcasts = {}, {}
function printToAll(s) M.chat[#M.chat + 1] = s; if M.verbose then print("  [chat] " .. s) end end
function broadcastToAll(s) M.broadcasts[#M.broadcasts + 1] = s; if M.verbose then print("  [BROADCAST] " .. s) end end
function broadcastToColor(s, c) M.broadcasts[#M.broadcasts + 1] = c .. ": " .. s end
Color = { fromString = function(s) return s end }
UI = { xml = "", setXml = function(x) UI.xml = x end, setValue = function() end, setAttribute = function(id, a, v) UI.last = v; UI.attrs = UI.attrs or {}; UI.attrs[id] = UI.attrs[id] or {}; UI.attrs[id][a] = v end, show = function(id) UI.shown = id end, hide = function(id) UI.hidden = id end }
Turns = {}
JSON = { encode = function(t) return "<json>" end, decode = function(s) return {} end }
-- WebRequest: record posts; M.web_ok decides whether the "server" answers
M.posts, M.web_ok = {}, true
WebRequest = { custom = function(url, method, download, data, headers, cb)
    M.posts[#M.posts + 1] = { url = url, method = method, data = data }
    cb(M.web_ok and { is_error = false, text = "saved" } or { is_error = true, error = "Cannot connect to destination host", text = "" })
end }

-- timers: queued, run in time order by pump()
local timers = {}
Wait = {
    time = function(fn, t) timers[#timers + 1] = { t = t or 0, fn = fn } end,
    frames = function(fn, n) timers[#timers + 1] = { t = (n or 1) / 60, fn = fn } end,
    -- like TTS: re-check the condition every frame (here every 0.1 s) until it holds or the timeout passes
    condition = function(fn, cond, timeout, onTimeout)
        local waited = 0
        local function poll()
            if cond() then fn()
            elseif timeout and waited >= timeout then if onTimeout then onTimeout() end
            else waited = waited + 0.1; Wait.time(poll, 0.1) end
        end
        poll()
    end,
}
-- run only the timers due within the next `seconds` (simulated time), leaving later ones queued
M.clock = 0                    -- simulated time (TTS: Time.time)
Time = setmetatable({}, { __index = function(_, k) if k == "time" then return M.clock end end })
function M.pumpFor(seconds)
    local left = seconds
    while #timers > 0 do
        table.sort(timers, function(a, b) return a.t < b.t end)
        if timers[1].t > left then
            for _, o in ipairs(timers) do o.t = o.t - left end
            M.clock = M.clock + left
            return
        end
        local t = table.remove(timers, 1)
        left = left - t.t
        M.clock = M.clock + t.t
        for _, o in ipairs(timers) do o.t = o.t - t.t end
        t.fn()
    end
    M.clock = M.clock + left
end

function M.pump(limit)
    local n = 0
    while #timers > 0 and n < (limit or 200000) do
        table.sort(timers, function(a, b) return a.t < b.t end)
        local t = table.remove(timers, 1)
        M.clock = M.clock + t.t
        for _, o in ipairs(timers) do o.t = o.t - t.t end
        t.fn(); n = n + 1
    end
    return n
end

-- startLuaCoroutine(owner, "fnName"): run the global function as a coroutine, resuming after each yield
M.coroutine_yields = 0
function startLuaCoroutine(owner, name)
    local co = coroutine.create(_G[name])
    while true do
        local ok, err = coroutine.resume(co)
        if not ok then error(err) end
        if coroutine.status(co) == "dead" then return end
        M.coroutine_yields = M.coroutine_yields + 1
    end
end

function isNear(a, b, c, d, t) return math.abs(a - c) <= t and math.abs(b - d) <= t end
function objectDistance(o1, o2)
    local p, q = o1.getPosition(), o2.getPosition()
    return math.sqrt((p.x - q.x) ^ 2 + (p.z - q.z) ^ 2)
end
function shallowCopyTable(t) local c = {}; for k, v in pairs(t) do c[k] = v end; return c end
function tableRemoveByValue(t, v) for i = #t, 1, -1 do if t[i] == v then table.remove(t, i) end end end

local all_objects = {}
function getAllObjects() return all_objects end

local function vec(p) return { x = p.x or p[1], y = p.y or p[2], z = p.z or p[3] } end

function M.newObj(t)
    t.vars, t.tables = {}, {}
    t.getPosition = function() return { x = t.pos.x, y = t.pos.y, z = t.pos.z, [1] = t.pos.x, [2] = t.pos.y, [3] = t.pos.z } end
    t.setPosition = function(p) t.pos = vec(p); M.landed(t) end
    t.setPositionSmooth = function(p) t.pos = vec(p); t.moves = (t.moves or 0) + 1; M.landed(t) end
    t.isSmoothMoving = function() return false end
    t.setVar = function(k, v) t.vars[k] = v end
    t.getVar = function(k) return t.vars[k] end
    t.setTable = function(k, v) t.tables[k] = v end
    t.getTable = function(k) return t.tables[k] end
    t.setLock = function(v) t.locked = v end
    t.setRotation = function(r) t.rot = vec(r) end
    t.setRotationSmooth = function(r) t.rot = vec(r) end
    t.getRotation = function() return t.rot or { x = 0, y = 90, z = 0 } end
    t.highlightOn = function(c) t.hl = true; t.hlc = c end
    t.highlightOff = function() t.hl = false end
    t.getColorTint = function() return t.tint or { r = 1, g = 1, b = 1 } end
    t.setColorTint = function(c) t.tint = c end
    t.getName = function() return t.name or "" end
    t.setName = function(n) t.name = n end
    t.isDestroyed = function() return false end
    t.getGUID = function() return tostring(t) end
    t.drop = function() end
    t.setInvisibleTo = function(c) t.invisible = c end
    t.destruct = function()
        t.destroyed = true
        t.isDestroyed = function() return true end
        for i = #all_objects, 1, -1 do if all_objects[i] == t then table.remove(all_objects, i) end end
    end
    t.createButton = function(b) t.buttons = t.buttons or {}; t.buttons[#t.buttons + 1] = b end
    t.getScale = function() return t.scale or { x = 1, y = 1, z = 1 } end
    t.setScale = function(v) t.scale = vec(v) end
    t.getBounds = function() local sc = t.getScale(); return { size = { x = sc.x, y = sc.y, z = sc.z } } end
    all_objects[#all_objects + 1] = t
    return t
end

local SPAWN_TAGS = { BlockSquare = "Block" }
function spawnObject(params)
    local o = M.newObj({ pos = vec(params.position or { 0, 0, 0 }), tag = SPAWN_TAGS[params.type] or params.type,
                         spawned = params.type })
    o.scale = params.scale and vec(params.scale) or nil
    if params.callback_function then params.callback_function(o) end
    return o
end

-- "physics": what TTS would fire when an object comes to rest somewhere
function M.landed(obj)
    if M.no_physics then return end
    if obj.tag == "Card" and onObjectEnterScriptingZone then
        for color, pile in pairs(M.discard) do
            if isNear(obj.pos.x, obj.pos.z, pile.pos.x, pile.pos.z, 0.5) and obj.pos.y < pile.pos.y + 1.5 then
                onObjectEnterScriptingZone(M.zones[color], obj)
                if M.merge_cards then          -- like TTS: the card merges into the pile and the object is gone
                    obj.isDestroyed = function() return true end
                    obj.getPosition = function() error("Object reference not set to an instance of an object") end
                end
            end
        end
    elseif obj.tag == "Checker" and marbleCollisionDetection then
        for _, other in ipairs(all_objects) do
            if other ~= obj and other.tag == "Checker" and isNear(obj.pos.x, obj.pos.z, other.pos.x, other.pos.z, 0.3)
               and obj.pos.y > other.pos.y and obj.pos.y - other.pos.y < 1.5 then   -- carried high = no contact
                marbleCollisionDetection(other, { collision_object = obj })
            end
        end
    end
end

function M.setup(N, seated)
    M.N = N
    all_objects = {}
    M.chat, M.broadcasts = {}, {}
    local colors = PLAYER_COLORS[N]
    -- board points: N sides x 23 entries (same index layout as board.lua), spread on a circle
    M.nsp = {}
    for s = 1, N do
        for o = 1, 23 do
            local ang = ((s - 1) * 23 + o) / (23 * N) * 2 * math.pi
            M.nsp[#M.nsp + 1] = { position = { x = 30 * math.cos(ang), y = 1.75, z = 30 * math.sin(ang) } }
        end
    end
    M.mbp, M.discard, M.zones, M.boards, M.hands = {}, {}, {}, {}, {}
    for s = 1, N do
        local color = colors[s]
        local start = {}
        for k = 1, 5 do start[k] = { position = { x = 100 + s * 5, y = 2.75, z = k * 2 } } end
        M.mbp[color] = {}
        for k = 1, 5 do
            local m = M.newObj({ pos = { x = start[k].position.x, y = 1.75, z = start[k].position.z }, tag = "Checker",
                                 tint = MARBLE_COLORS[s] })
            m.tables.start_points = start
            local entrance = M.nsp[(s - 1) * 23 + 3].position
            m.tables.friendly_bonk_position = { x = entrance.x, y = entrance.y, z = entrance.z }
            m.vars.team_number = s; m.vars.player_color = color
            M.mbp[color][k] = m
        end
        M.discard[color] = M.newObj({ pos = { x = 10 * s, y = 1.2, z = -60 }, rot = { x = 0, y = 180, z = 0 } })
        M.zones[color] = { getName = function() return color .. "_DiscardPile" end }
        M.boards[color] = M.newObj({ pos = { x = 0, y = -5, z = 0 } })
    end
    -- centre deck (infinite)
    local ranks = { "Ace","2","3","4","5","6","7","8","9","10","Jack","Queen","King" }
    local names = {}
    local function refill()
        for _, suit in ipairs({ "Spades","Hearts","Clubs","Diamonds" }) do for _, r in ipairs(ranks) do names[#names+1] = r .. " of " .. suit end end
        names[#names+1] = "Joker"; names[#names+1] = "Joker"
        for i = #names, 2, -1 do local j = math.random(i); names[i], names[j] = names[j], names[i] end
    end
    M.deck = M.newObj({ pos = { x = 0, y = 1, z = 0 }, tag = "Deck" })
    M.deck.getObjects = function()
        if #names == 0 then refill() end
        local t = {}
        for i, n in ipairs(names) do t[i] = { guid = n, name = n } end
        return t
    end
    M.deck.takeObject = function(p)
        if #names == 0 then refill() end
        local name
        if p.guid then
            for i, n in ipairs(names) do if n == p.guid then name = table.remove(names, i); break end end
        end
        local c = M.newObj({ pos = vec(p.position), tag = "Card", name = name or table.remove(names) })
        p.callback_function(c)
    end
    M.deck.deal = function(n, color) M.dealt = (M.dealt or 0) + n end
    M.deck.shuffle = function() M.shuffles = (M.shuffles or 0) + 1 end
    M.deck.getQuantity = function() return M.deck_count or #names end
    function findCenterDeck() return M.deck end
    M.reshuffle_btn = { call = function(fn) M.reshuffled = (M.reshuffled or 0) + 1 end }

    M.chip = { label = "", getButtons = function() return { {} } end,
               editButton = function(b) M.chip.label = b.label; if M.verbose then print("  [turn chip] " .. b.label) end end }
    function getObjectFromGUID(g)
        if g == TURN_BUTTON_GUID then return M.chip end
        if g == RESHUFFLE_BUTTON_GUID then return M.reshuffle_btn end
        for _, o in ipairs(all_objects) do if o.getGUID() == g and not o.isDestroyed() then return o end end
    end

    Global = {
        getVar = function(k) if k == "num_players" then return N end end,
        getTable = function(k)
            if k == "non_start_points" then return M.nsp elseif k == "marbles_by_player" then return M.mbp
            elseif k == "discard_piles" then return M.discard elseif k == "boards_by_player" then return M.boards end
        end,
        call = function(fn, params) return _G[fn](params) end,
        getVectorLines = function() return M.lines or {} end,
        setVectorLines = function(l) M.lines = l end,
    }
    Player = setmetatable({}, { __index = function(_, c)
        return { seated = seated[c] == true, steam_name = seated[c] and ("Human-" .. c) or nil, color = c, host = (c == "White"),
                 getHoldingObjects = function() return {} end, getHandObjects = function() return M.hands[c] or {} end,
                 getHandTransform = function() return { position = { x = 0, y = 3, z = -90 }, rotation = { x = 0, y = 180, z = 0 } } end }
    end })
    rawset(Player, "Action", { PickUp = "PickUp", Select = "Select" })
    -- the host (White): host-only messages (botHostMsg) land in M.chat too, marked [host]
    rawset(Player, "getPlayers", function()
        return { { host = true, color = "White", print = function(msg) M.chat[#M.chat + 1] = "[host] " .. tostring(msg) end } }
    end)
end

-- put marble k of a colour on board index idx (non_start_points)
function M.place(color, k, idx)
    local p = M.nsp[idx].position
    M.mbp[color][k].pos = { x = p.x, y = p.y, z = p.z }
end

-- a card object with a name, last touched by a colour
function M.card(name, last_color)
    local c = M.newObj({ pos = { x = 0, y = 5, z = 50 }, tag = "Card", name = name })
    c.vars.last_player_color = last_color
    return c
end

-- Load the BUILT Global script (run `lua build.lua` first; tests/run_all.sh does) - the same code TTS runs.
function M.loadGlobal()
    local mockDistance = objectDistance
    dofile("build/Global.-1.lua")
    -- the mock has no physics: a marble "dropped" on another is teleported a little above it, and the mock decides
    -- contact itself (M.landed). Keep its flat distance so that drop counts as touching.
    objectDistance = mockDistance
end

function M.loadModules(list)
    for _, f in ipairs(list) do dofile(f) end
end

return M
