-- marbles.lua
-- Spawning the marbles, and questions about where a marble is. Shared by the setup buttons (which spawn them) and
-- the Global script. What happens when marbles collide (bonks) is in game/bonks.lua (Global only).
--
-- Each marble carries:
--   team_number            its seat number (1..N; teams are odd vs even seats)
--   player_color           its seat colour
--   start_points           table: the 5 start slots of its seat
--   friendly_bonk_position table: its seat's finish entrance (where a friendly bonk sends it)
--   picked_up / rejecting  set while a player holds it / while an illegal move is being undone
--   origin_position        table: where it stood when last picked up (an illegal move puts it back there)
--#include "constants.lua"
--#include "helpers.lua"

-- Spawn 5 marbles per seat in their start slots. Returns { [seat colour] = { marble, ... } } (Global keeps this as
-- the "marbles_by_player" table; the bots, stats and turn logic all read the board through it).
function spawnMarbles(num_players,start_points_by_player,friendly_bonk_points_by_player)

    local marbles_by_player = {}
    local player_colors = PLAYER_COLORS[num_players]
    local team_marbles, marble

    for i = 1,num_players do
        team_marbles = {}
        for j = 1,5 do
            marble = spawnObject({
                type = "Red Ball",
                position = start_points_by_player[player_colors[i]][j]["position"],
                velocity = {0,0,0},
                scale = {MARBLE_SCALES[num_players],MARBLE_SCALES[num_players],MARBLE_SCALES[num_players]},
                callback_function = function(obj)
                    obj.setColorTint(MARBLE_COLORS[i])
                    obj.setVar("team_number",i)
                    obj.setVar("player_color",player_colors[i])
                    obj.setVar("picked_up", false)
                    obj.setTable("start_points",start_points_by_player[player_colors[i]])
                    obj.setTable("friendly_bonk_position",friendly_bonk_points_by_player[player_colors[i]]["position"])
                end
            })
            marble.registerCollisions()        -- collisions go to Global's onObjectCollisionEnter
            table.insert(team_marbles,marble)
        end
        marbles_by_player[player_colors[i]] = team_marbles
    end
    return marbles_by_player
end

-- A free start slot for a marble being sent home, or nil if every slot looks taken (e.g. another bonked marble is
-- still flying home; game/bonks.lua bonkAnimation then uses the first slot).
function findEmptyStartPosition(marble)

    local start_points = marble.getTable("start_points")
    local team_marbles = Global.getTable("marbles_by_player")[marble.getVar("player_color")]
    local start_point_full, marble_x, marble_z, start_point_x, start_point_z

    for i = 1,#start_points do
        start_point_full = false
        for j = 1, #team_marbles do
            marble_x = team_marbles[j].getPosition()[1]
            marble_z = team_marbles[j].getPosition()[3]
            start_point_x = start_points[i]["position"]["x"]
            start_point_z = start_points[i]["position"]["z"]

            if isNear(marble_x,marble_z,start_point_x,start_point_z,.05) then
                start_point_full = true
                break
            end
        end
        if not start_point_full then
            return start_points[i]["position"]
        end
    end
    return nil
end

-- Is the marble standing in one of its start slots?
function isAtStart(marble)
    local start_points = marble.getTable("start_points")
    local marble_x = marble.getPosition()[1]
    local marble_z = marble.getPosition()[3]
    local start_point_x, start_point_z

    for i = 1,#start_points do
        start_point_x = start_points[i]["position"]["x"]
        start_point_z = start_points[i]["position"]["z"]
        if isNear(marble_x,marble_z,start_point_x,start_point_z,.05) then
            return true
        end
    end
    return false
end

-- Index of the ring / finish point the marble stands on (into the "non_start_points" table), or nil.
function getMarblePointIndex(marble)
    local non_start_points = Global.getVar("non_start_points")
    local marble_x = marble.getPosition()[1]
    local marble_z = marble.getPosition()[3]
    local point_x, point_z

    for i = 1,#non_start_points do
        point_x = non_start_points[i]["position"]["x"]
        point_z = non_start_points[i]["position"]["z"]
        if isNear(marble_x,marble_z,point_x,point_z,.05) then
            return i
        end
    end
end

-- The nearest board point or start slot to a marble (where it was standing before someone picked it up).
function nearestMarblePoint(marble)
    local pos = marble.getPosition()
    local best, best_d = nil, 1e12
    local function consider(pt)
        local dx, dz = pos.x - pt.x, pos.z - pt.z
        local d = dx*dx + dz*dz
        if d < best_d then best, best_d = pt, d end
    end
    for _, pt in ipairs(Global.getTable("non_start_points")) do consider(pt["position"]) end
    for _, pt in ipairs(marble.getTable("start_points")) do consider(pt["position"]) end
    if best then return {x = best.x, y = best.y, z = best.z} end
end

-- Remember where a marble stood when it was picked up, so an illegal move can put it back (game/bonks.lua).
function recordMarbleOrigin(marble)
    local origin = nearestMarblePoint(marble)
    if origin then marble.setTable("origin_position", origin) end
end
