-- game/hover.lua  (Global script)
-- The distance numbers: hover over any marble and the numbers 1-13 appear on the next 13 spots along ITS route
-- (they turn into its owner's finish), plus a red "8" where an 8 played backwards would take it. Only the player
-- hovering sees their numbers. Each number:
--   * sits a little above an empty hole, and jumps above a marble sitting in the hole so the marble doesn't hide it
--   * is turned toward the hovering player's seat (TTS doesn't tell scripts where a player's camera is)
--   * stays put while you carry a marble (dragging it over other marbles doesn't switch the numbers)
-- The 13 number pieces per seat are spawned at setup (hover_numbers.lua); the "-8" piece is spawned here when it's
-- first needed. Global onObjectHover calls hoverMarble.

-- Where a hover number goes: on the hole, or (user) lifted above a marble sitting in it, so the marble doesn't
-- hide it (like easy play's rings). occupied = marblesOnSpots(), one board scan per hover.
HOVER_LIFT = 1.05                -- above a marble in the hole (kept above the empty-hole height)
HOVER_BASE_LIFT = 0.62          -- on an empty hole: a little up, so the (bigger) numbers don't clip into the board
HOVER_NUMBER_SCALE = 0.95       -- the numbers are spawned at 0.75 (player buttons); bigger to read (user)
function hoverSizeUp(obj)
    if obj.getVar("hover_scaled") == HOVER_NUMBER_SCALE then return end
    pcall(function()
        obj.setScale({ HOVER_NUMBER_SCALE, HOVER_NUMBER_SCALE, HOVER_NUMBER_SCALE })
        obj.setVar("hover_scaled", HOVER_NUMBER_SCALE)
    end)
end
function marblesOnSpots(nsp)
    local tops = {}
    local marbles = {}
    for _, list in pairs(Global.getTable("marbles_by_player") or {}) do
        for _, m in ipairs(list) do
            local ok, p = pcall(function() return m.getPosition() end)
            if ok and p then marbles[#marbles + 1] = p end
        end
    end
    for i, pt in ipairs(nsp or {}) do
        local q = pt.position
        for _, p in ipairs(marbles) do
            if isNear(p.x, p.z, q.x, q.z, 0.4) and p.y < q.y + 1.5 then tops[i] = math.max(tops[i] or 0, p.y) end
        end
    end
    return tops
end
function hoverSpotPosition(nsp, idx, tops)
    local q = nsp[idx]["position"]
    if tops and tops[idx] then return { x = q.x, y = tops[idx] + HOVER_LIFT, z = q.z } end
    return { x = q.x, y = q.y + HOVER_BASE_LIFT, z = q.z }
end

-- Each number turned toward the hovering player's seat (user: numbers out at the sides were read side-on). The
-- seat's usual angle (base_yaw, every number parallel) is kept for a number in the middle of the board; one off to
-- the side turns by the angle between "middle -> seat" and "number -> seat". The seat = that player's hand.
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local function heading(fx, fz, tx, tz) return math.deg(atan2(tx - fx, tz - fz)) end
local HOVER_CENTER
local function boardCenter(nsp)
    if HOVER_CENTER then return HOVER_CENTER end
    local x, z, n = 0, 0, 0
    for _, pt in ipairs(nsp or {}) do x = x + pt.position.x; z = z + pt.position.z; n = n + 1 end
    if n == 0 then return { x = 0, z = 0 } end
    HOVER_CENTER = { x = x / n, z = z / n }
    return HOVER_CENTER
end
function hoverYaw(player_color, pos, base_yaw, nsp)
    local ok, h = pcall(function() return Player[player_color].getHandTransform().position end)
    if not ok or not h or not h.x then return base_yaw end
    local c = boardCenter(nsp)
    return base_yaw + heading(pos.x, pos.z, h.x, h.z) - heading(c.x, c.z, h.x, h.z)
end

function arrangeHoverNumbers(player_color, marble_index, team_number, marble_color, view_team)

    hideHoverNumbers(player_color)
    local hover_numbers = Global.getTable("hover_numbers_by_player")[player_color]
    local non_start_points = Global.getTable("non_start_points")
    local alpha = (2*math.pi/Global.getVar("num_players")) * 180/math.pi

    local player_colors = shallowCopyTable(PLAYER_COLORS[Global.getVar("num_players")])
    tableRemoveByValue(player_colors, player_color)

    local first_goal_index = 4 + (team_number-1) * 23
    local last_goal_index = first_goal_index + 4

    -- the -8 marker (an 8 played backwards) goes in before the loop, which can return early
    hoverPlaceMinus8(player_color, marble_index, marble_color, alpha * ((view_team or team_number) - 1), player_colors)

    local numbers_arranged = 0
    local i = 1
    local potential_index
    local tops = marblesOnSpots(non_start_points)

    while numbers_arranged < 13 do

        potential_index = (((marble_index + i) - 1) % #non_start_points) + 1

        if potential_index % 23 == 4 and potential_index ~= first_goal_index then
            i = i + 5
        else
            hoverSizeUp(hover_numbers[numbers_arranged+1])
            local spot = hoverSpotPosition(non_start_points, potential_index, tops)
            hover_numbers[numbers_arranged+1].setPosition(spot)
            hover_numbers[numbers_arranged+1].setRotation({HOVER_NUMBER_ROTATION,
                hoverYaw(player_color, spot, alpha * ((view_team or team_number) - 1), non_start_points), 0})
            hover_numbers[numbers_arranged+1].setInvisibleTo(player_colors)
            hover_numbers[numbers_arranged+1].highlightOn(marble_color)
            hover_numbers[numbers_arranged+1].setColorTint(HOVER_NUMBER_COLOR)
            numbers_arranged = numbers_arranged + 1
            i = i + 1

            if potential_index == last_goal_index then return end
        end
    end
end

------------------------------------------------------------------------
-- "-8" hover marker: where the marble would land if an 8 is played on it (8 cells BACKWARDS on the ring).
-- One extra piece per player: the "8" number mesh tinted red. The 1..13 pieces are spawned by the player-count
-- buttons, so this one is created lazily from Global the first time it is needed (named so it can be found
-- again after a reload instead of spawning a duplicate).
------------------------------------------------------------------------
HOVER_MINUS8_TINT = { r = 1, g = 0.25, b = 0.25 }
HOVER_MINUS8 = HOVER_MINUS8 or {}          -- [player colour] = object (nil while spawning)
HOVER_MINUS8_SPAWNING = HOVER_MINUS8_SPAWNING or {}

local function hoverMinus8Name(color) return "HoverMinus8_" .. color end

local function hoverMinus8Object(color)
    local obj = HOVER_MINUS8[color]
    if obj and not obj.isDestroyed() then return obj end
    HOVER_MINUS8[color] = nil
    for _, o in ipairs(getAllObjects()) do         -- after a reload: reuse the one already on the table
        if o.getName() == hoverMinus8Name(color) then HOVER_MINUS8[color] = o; return o end
    end
    if not HOVER_MINUS8_SPAWNING[color] then
        HOVER_MINUS8_SPAWNING[color] = true
        spawnObjectJSON({
            json = hoverNumberJSON(HOVER_NUMBER_MESHES[8], ""),
            position = { 4, 12, 0 },
            rotation = { 0, 0, 0 },
            callback_function = function(o)
                o.setName(hoverMinus8Name(color))
                o.setInvisibleTo(PLAYER_COLORS[Global.getVar("num_players")])
                o.setLock(true)
                o.interactable = false
                HOVER_MINUS8[color] = o
                HOVER_MINUS8_SPAWNING[color] = false
            end
        })
    end
    return nil                                     -- appears from the next hover on
end

-- non_start_points layout per seat: 23 entries = ring cells 1-3, finish cells (offsets 4-8), ring cells 4-18
local function hoverIsFinishIndex(idx)
    local off = ((idx - 1) % 23) + 1
    return off >= 4 and off <= 8
end

-- index in non_start_points of the cell 8 ring cells behind idx, or nil if the marble is in a finish
function hoverMinus8Index(idx, total)
    if hoverIsFinishIndex(idx) then return nil end  -- an 8 can't take a marble back out of the finish
    local steps = 0
    while steps < 8 do
        idx = ((idx - 2) % total) + 1               -- one entry back, wrapping
        if not hoverIsFinishIndex(idx) then steps = steps + 1 end
    end
    return idx
end

function hoverPlaceMinus8(player_color, marble_index, marble_color, rot_y, hidden_from)
    local obj = hoverMinus8Object(player_color)
    if not obj then return end
    local nsp = Global.getTable("non_start_points")
    local target = hoverMinus8Index(marble_index, #nsp)
    if not target then return end
    hoverSizeUp(obj)
    local spot = hoverSpotPosition(nsp, target, marblesOnSpots(nsp))
    obj.setPosition(spot)
    obj.setRotation({ HOVER_NUMBER_ROTATION, hoverYaw(player_color, spot, rot_y, nsp), 0 })
    obj.setInvisibleTo(hidden_from)
    obj.highlightOn(marble_color)
    obj.setColorTint(HOVER_MINUS8_TINT)
end

-- Overrides hideHoverNumbers from hover_numbers.lua: same as before, plus hides the -8 marker.
function hideHoverNumbers(player_color)
    local hover_numbers = Global.getTable("hover_numbers_by_player")[player_color]
    local player_colors = PLAYER_COLORS[Global.getVar("num_players")]

    for i = 1,13 do
        hover_numbers[i].setInvisibleTo(player_colors)
        hover_numbers[i].setPosition({4+.5*i, 10, 0})
    end
    local m8 = HOVER_MINUS8[player_color]
    if m8 and not m8.isDestroyed() then
        m8.setInvisibleTo(player_colors)
        m8.setPosition({ 4, 12, 0 })
    end
end

-- seat index (1..N) of a colour, or nil for spectators / colours not in this game
local function hoverSeatOf(color)
    local N = Global.getVar("num_players")
    for i, c in ipairs(PLAYER_COLORS[N] or {}) do if c == color then return i end end
    return nil
end

-- Global onObjectHover: show the numbers for the hovered marble, or hide them.
function hoverMarble(player_color, object)

    local hover_sets = Global.getTable("hover_numbers_by_player")
    local viewer_seat = hoverSeatOf(player_color)
    if not hover_sets or not viewer_seat or not hover_sets[player_color] then return end   -- before setup / spectators
    -- while a marble (or anything) is being carried, its numbers stay put: dragging it over other marbles must not
    -- switch the numbers to them (user). They are hidden/refreshed again after the drop.
    local held = Player[player_color].getHoldingObjects()
    if held and #held > 0 then return end

    if (object and object.tag == "Checker" and object.getVar("team_number")
    and not isAtStart(object) and not object.getVar("picked_up")) then
        local marble_index = getMarblePointIndex(object)
        if marble_index then          -- nil when the marble isn't sitting on a board point
            arrangeHoverNumbers(player_color, marble_index, object.getVar("team_number"), object.getColorTint(), viewer_seat)
            return
        end
    end
    hideHoverNumbers(player_color)
end
