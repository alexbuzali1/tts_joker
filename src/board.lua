-- board.lua
-- The board: one board piece per seat around the table, and every point a marble can stand on.
--#include "constants.lua"
--#include "saved_object_data/boards/light_board.lua"
--#include "saved_object_data/boards/dark_board.lua"

-- Spawn and lock the board pieces (alternating light and dark) for a table of num_players. Returns them in seat order.
function createBoard(num_players)

    local l = DEFAULT_BOARD_LENGTH * BOARD_SCALES[num_players]
    local w = DEFAULT_BOARD_WIDTH * BOARD_SCALES[num_players]
    local a = w/WIDTH_LEG_RATIO
    local alpha = 2*math.pi/num_players

    local out = .5*((l/math.tan(math.pi/num_players)) + a - w)
    local over = a * math.sin(alpha)/2
    local radius = math.sqrt(out*out+over*over)

    local theta0 = math.pi + math.pi/2-math.asin(over/radius)
    local theta, boardJSON
    local boards = {}

    for i = 1,num_players do

        if math.fmod(i,2) == 0 then
            boardJSON = light_board_JSON
        else
            boardJSON = dark_board_JSON
        end

        theta = theta0 - (i-1)*alpha

        local board = spawnObjectJSON({
            json = boardJSON,
            position = {radius * math.cos(theta),BOARD_Y,radius * math.sin(theta)},
            rotation = {0,180+(i-1)*alpha*180/math.pi,0},
            scale = {BOARD_SCALES[num_players],BOARD_SCALES[num_players],BOARD_SCALES[num_players]} 
        })

        board.lock()
        table.insert(boards, board)
    end
    return boards
end

-- Every point of the board, computed from the board geometry. Returns:
--   snap_points                   all points (ring, finishes, start slots) as TTS snap points
--   start_points_by_player[color] the 5 start slots of each seat
--   friendly_bonk_points_by_player[color]   each seat's finish entrance (where a friendly-bonked marble goes)
--   non_start_points              ring and finish points in board order: per seat 23 entries =
--                                 ring cells 1-3, that seat's finish cells 1-5, ring cells 4-18
--                                 (the bots' cell numbering, bot/rules.lua cellToIndex, follows this order)
function getBoardPoints(num_players)

    local player_colors = PLAYER_COLORS[num_players]
    local l = DEFAULT_BOARD_LENGTH * BOARD_SCALES[num_players]
    local w = DEFAULT_BOARD_WIDTH * BOARD_SCALES[num_players]
    local a = w/WIDTH_LEG_RATIO
    local out = .5*((l/math.tan(math.pi/num_players)) + a - w)
    local alpha = 2*math.pi/num_players
    local d = (l-a)/17
    local x_offset = a * math.sin(alpha)/2-d/2

    local theta, x, z, x_prime, z_prime


    local snap_points = {}
    local non_start_points = {}
    local start_points_by_player = {}
    local friendly_bonk_points_by_player = {}
    local start_points

    local start_positions = {
        {-d,MARBLE_HEIGHTS[num_players],out + .5*(w-a)-d},
        {-d,MARBLE_HEIGHTS[num_players],out + .5*(w-a)-2*d},
        {-d,MARBLE_HEIGHTS[num_players],out + .5*(w-a)-3*d},
        {-2*d,MARBLE_HEIGHTS[num_players],out + .5*(w-a)-2*d},
        {0,MARBLE_HEIGHTS[num_players],out + .5*(w-a)-2*d}
    }

    local goal_positions = {
        {-6*d,MARBLE_HEIGHTS[num_players],out + .5*(w-a)-d},
        {-6*d,MARBLE_HEIGHTS[num_players],out + .5*(w-a)-2*d},
        {-5*d,MARBLE_HEIGHTS[num_players],out + .5*(w-a)-2*d},
        {-4*d,MARBLE_HEIGHTS[num_players],out + .5*(w-a)-2*d},
        {-4*d,MARBLE_HEIGHTS[num_players],out + .5*(w-a)-3*d},
    }

    for side = 1,num_players do

        theta = math.pi - alpha*(side-1)

        --Outer points
        for i = 1,18 do
            x = x_offset + (-9+i)*d
            z = out + .5*(w-a)
            x_prime = x * math.cos(theta) - z * math.sin(theta)
            z_prime = x * math.sin(theta) + z * math.cos(theta)
            
            snap_points[#snap_points + 1] = {position = Vector({x = x_prime, y = MARBLE_HEIGHTS[num_players], z = z_prime})}
            non_start_points[#non_start_points + 1] = {position = Vector({x = x_prime, y = MARBLE_HEIGHTS[num_players], z = z_prime})}
            
            if i == 3 then 
                friendly_bonk_points_by_player[player_colors[side]] = {position = Vector({x = x_prime, y = MARBLE_HEIGHTS[num_players], z = z_prime})}
                
                --Goal points (done here to ensure proper ordering)
                for j = 1,5 do
                    x = x_offset + goal_positions[j][1]
                    z = goal_positions[j][3]
                    x_prime = x * math.cos(theta) - z * math.sin(theta)
                    z_prime = x * math.sin(theta) + z * math.cos(theta)
                    
                    snap_points[#snap_points + 1] = {position = Vector({x = x_prime, y = MARBLE_HEIGHTS[num_players], z = z_prime})}
                    non_start_points[#non_start_points + 1] = {position = Vector({x = x_prime, y = MARBLE_HEIGHTS[num_players], z = z_prime})}
                end
            end 
        end

        --Start points
        start_points = {}
        for i = 1,5 do
            x = x_offset + start_positions[i][1]
            z = start_positions[i][3]
            x_prime = x * math.cos(theta) - z * math.sin(theta)
            z_prime = x * math.sin(theta) + z * math.cos(theta)
            
            start_points[#start_points + 1] = {position = Vector({x = x_prime, y = MARBLE_HEIGHTS[num_players]+1, z = z_prime})}
            snap_points[#snap_points + 1] = {position = Vector({x = x_prime, y = MARBLE_HEIGHTS[num_players], z = z_prime})}
        end
        start_points_by_player[player_colors[side]] = start_points
    end

    return snap_points, start_points_by_player, friendly_bonk_points_by_player, non_start_points
end

-- A locked, invisible, untouchable square under every board point: the marbles rest on these instead of the
-- board mesh, which keeps them from rolling.
function spawnInvisiblePlanes(num_players, board_points)

    local w = DEFAULT_BOARD_WIDTH * BOARD_SCALES[num_players]
    local l = DEFAULT_BOARD_LENGTH * BOARD_SCALES[num_players]
    local a = w/WIDTH_LEG_RATIO
    local d = (l-a)/17

    for i, pos in ipairs(board_points) do
        spawnObject({
            type = "BlockSquare",
            position = {x = pos["position"][1], y = INVISIBLE_PLANE_HEIGHTS[num_players], z=pos["position"][3]},
            scale = {x = d, y = 0.1, z = d},
            callback_function = function(obj)
                obj.setColorTint({r = 1, g = 1, b = 1, a = 0})
                obj.setLock(true)                              
                obj.interactable = false                       
                obj.setName("InvisiblePlane")
            end
        })
    end
end