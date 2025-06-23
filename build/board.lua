-- Begin include: constants.lua
--Default object GUID's
FOUR_PLAYER_BUTTON_GUID = "34e910"
SIX_PLAYER_BUTTON_GUID = "3acad9"
EIGHT_PLAYER_BUTTON_GUID = "fa9491"
RESHUFFLE_BUTTON_GUID = "a18a04"
TURN_BUTTON_GUID = "435315"
START_GAME_BUTTON_GUID = "0132bf"
MAT_GUID = "b62603"
DECK_GUID = "864748"

--Player colors
PLAYER_COLORS = {
[4] = {"White","Orange","Green","Purple"}, 
[6] = {"White","Red","Yellow","Green","Blue","Pink"}, 
[8] = {"White","Red","Orange","Yellow","Green","Blue","Purple","Pink"}
}

--Mat/table/plane
MAT_SHAPES = {[4] = 0, [6] = 1, [8] = 2}
TABLE_SHAPES = {[4] = "Square", [6] = "Hexagon", [8] = "Octagon"}
INVISIBLE_PLANE_HEIGHTS = {[4] = 1.63, [6] = 1.46, [8] = 1.40}

--Board
DEFAULT_BOARD_LENGTH = 6.5074
DEFAULT_BOARD_WIDTH = 1.4754
WIDTH_LEG_RATIO = 3.77
BOARD_Y = 1.16
BOARD_SCALES = {[4] = 2.95, [6] = 2.10, [8] = 1.70}

--Marbles
COLOR_PICKER_GRID_SIZE = 10
COLLISION_DISTANCE_THRESHOLDS = {[4] = 1, [6] = .7, [8] = .59}
MARBLE_SCALES = {[4] = 1.15, [6] = 0.81, [8] = 0.66}
MARBLE_HEIGHTS = {[4] = 1.75, [6] = 1.85, [8] = 1.70}
MARBLE_COLORS = {
    {r = 0, g = 0, b = 0},
    {r = 0, g = 0, b = 1},
    {r = 0, g = 1, b = 0},
    {r = 1, g = 0, b = 0},
    {r = 0, g = 1, b = 1},
    {r = 1, g = 0, b = 1},
    {r = 1, g = 1, b = 0},
    {r = 1, g = 1, b = 1},
}

--Discard piles
DISCARD_PILE_LINK = "https://steamusercontent-a.akamaihd.net/ugc/11381176505335231498/D70CF429940BD6C244F938F4B1ED9B0FFEA98C7D/"
DISCARD_PILE_SCALE = {1.9,.2, 1.9}
DISCARD_TRIGGER_SCALE = {2.5, 1.5, 3.5}

--Cards
local CARD_NAMES = {
    "Ace of Spades", "2 of Spades", "3 of Spades", "4 of Spades", "5 of Spades", "6 of Spades", "7 of Spades", 
    "8 of Spades", "9 of Spades", "10 of Spades", "Jack of Spades", "Queen of Spades", "King of Spades",
    "Ace of Hearts", "2 of Hearts", "3 of Hearts", "4 of Hearts", "5 of Hearts", "6 of Hearts", "7 of Hearts", 
    "8 of Hearts", "9 of Hearts", "10 of Hearts", "Jack of Hearts", "Queen of Hearts", "King of Hearts",
    "Ace of Clubs", "2 of Clubs", "3 of Clubs", "4 of Clubs", "5 of Clubs", "6 of Clubs", "7 of Clubs", "8 of Clubs", 
    "9 of Clubs", "10 of Clubs", "Jack of Clubs", "Queen of Clubs", "King of Clubs", "Ace of Diamonds", "2 of Diamonds", 
    "3 of Diamonds", "4 of Diamonds", "5 of Diamonds", "6 of Diamonds", "7 of Diamonds", "8 of Diamonds", "9 of Diamonds", 
    "10 of Diamonds", "Jack of Diamonds", "Queen of Diamonds", "King of Diamonds", "Joker", "Joker"
}

--Hover numbers
HOVER_NUMBER_MESHES = {
    "https://steamusercontent-a.akamaihd.net/ugc/9840189348820118096/4378904B1A41AE4FAD2053BB315A7604F8C97F0A/",
    "https://steamusercontent-a.akamaihd.net/ugc/13545035685193102406/E218BB8C0E69F18799C967693BB90CEF577F68D9/",
    "https://steamusercontent-a.akamaihd.net/ugc/17420512767893237283/0D58F70D295EA47B72D4F3CF2BF3AB2F8B77BB13/",
    "https://steamusercontent-a.akamaihd.net/ugc/14784526811464589629/E231870ACF52E936A4D2AEBADA33A64A0A90640D/",
    "https://steamusercontent-a.akamaihd.net/ugc/17826752322144790021/A797D60F82ADCAF507E6B7D6EFCC3848B331F946/",
    "https://steamusercontent-a.akamaihd.net/ugc/14237790372111199267/A36442062AB821C25DB7C489DCD29237ABEDE318/",
    "https://steamusercontent-a.akamaihd.net/ugc/15054040462540813228/84C285660EB4A338CB649F223BC4753C47980613/",
    "https://steamusercontent-a.akamaihd.net/ugc/11314675233457242763/458CE4E391195B23850A66718B201C49DB5F141A/",
    "https://steamusercontent-a.akamaihd.net/ugc/16997194073493012351/E710730F4325BB8B2835A6A8ABFAA5B11924EEF7/",
    "https://steamusercontent-a.akamaihd.net/ugc/12738754953360714689/B8DF0EFCF3BAC8F1F3DA3417FC5FE3F9F03B1178/",
    "https://steamusercontent-a.akamaihd.net/ugc/10467153273598234260/7B71A418AA162D836BAF95309513C0FD53F3CFF3/",
    "https://steamusercontent-a.akamaihd.net/ugc/12699726688073351151/932E8E44A6D3DBAD560A4EC846601349C62F6BF0/",
    "https://steamusercontent-a.akamaihd.net/ugc/18080857105465481786/1AF8E59B02D91AB52DD184862249D05325D4DC55/"
}
HOVER_NUMBER_GUIDS = {"f69a6f","90b339","b6e3d8","0c009c","e51d96","dcfe73","b34b0f","f01604","157177","32a4ee","796ace","4218c0","f7cbbb"}
PLANE_COLLIDER_URL = "https://steamusercontent-a.akamaihd.net/ugc/10666753646430391888/DF4C04C429589235BECC2978F879171DD92C0ECC/"
HOVER_NUMBER_ROTATION = 45
HOVER_NUMBER_COLOR = Color.fromString('White')
-- HOVER_NUMBER_OUTLINE_COLOR = Color.fromString('Blue')
-- End include: constants.lua
-- Begin include: saved_object_data/boards/light_board.lua
light_board_JSON = [[
{
      "GUID": "990ba6",
      "Name": "Custom_Model",
      "Transform": {
        "posX": 0.0,
        "posY": 1.16,
        "posZ": 0.0,
        "rotX": 0.0348675549,
        "rotY": 0.00275248964,
        "rotZ": 4.64923833E-05,
        "scaleX": 2.95,
        "scaleY": 2.95,
        "scaleZ": 2.95
      },
      "Nickname": "",
      "Description": "",
      "GMNotes": "",
      "AltLookAngle": {
        "x": 0.0,
        "y": 0.0,
        "z": 0.0
      },
      "ColorDiffuse": {
        "r": 1.0,
        "g": 1.0,
        "b": 1.0
      },
      "LayoutGroupSortIndex": 0,
      "Value": 0,
      "Locked": false,
      "Grid": true,
      "Snap": true,
      "IgnoreFoW": false,
      "MeasureMovement": false,
      "DragSelectable": true,
      "Autoraise": true,
      "Sticky": true,
      "Tooltip": true,
      "GridProjection": false,
      "HideWhenFaceDown": false,
      "Hands": false,
      "CustomMesh": {
        "MeshURL": "https://steamusercontent-a.akamaihd.net/ugc/16432616709978613/DDFD15AF5E9D474A78E9879B6BD8B8E20ECDF1EC/",
        "DiffuseURL": "https://steamusercontent-a.akamaihd.net/ugc/16432158165210463/F13758A7E268ABACCE9F7B29341B6ADD675F5C4A/",
        "NormalURL": "",
        "ColliderURL": "https://steamusercontent-a.akamaihd.net/ugc/16432158165211267/83126B855FA9E798F432672309C17CDD7940D115/",
        "Convex": false,
        "MaterialIndex": 0,
        "TypeIndex": 0,
        "CastShadows": true
      },
      "LuaScript": "",
      "LuaScriptState": "",
      "XmlUI": ""
    }
]]
-- End include: saved_object_data/boards/light_board.lua
-- Begin include: saved_object_data/boards/dark_board.lua
dark_board_JSON = [[
{
      "GUID": "990ba6",
      "Name": "Custom_Model",
      "Transform": {
        "posX": 0.0,
        "posY": 1.16,
        "posZ": 0.0,
        "rotX": 0.0348675549,
        "rotY": 0.00275248964,
        "rotZ": 4.64923833E-05,
        "scaleX": 2.95,
        "scaleY": 2.95,
        "scaleZ": 2.95
      },
      "Nickname": "",
      "Description": "",
      "GMNotes": "",
      "AltLookAngle": {
        "x": 0.0,
        "y": 0.0,
        "z": 0.0
      },
      "ColorDiffuse": {
        "r": 1.0,
        "g": 1.0,
        "b": 1.0
      },
      "LayoutGroupSortIndex": 0,
      "Value": 0,
      "Locked": false,
      "Grid": true,
      "Snap": true,
      "IgnoreFoW": false,
      "MeasureMovement": false,
      "DragSelectable": true,
      "Autoraise": true,
      "Sticky": true,
      "Tooltip": true,
      "GridProjection": false,
      "HideWhenFaceDown": false,
      "Hands": false,
      "CustomMesh": {
        "MeshURL": "https://steamusercontent-a.akamaihd.net/ugc/16432616709978613/DDFD15AF5E9D474A78E9879B6BD8B8E20ECDF1EC/",
        "DiffuseURL": "https://steamusercontent-a.akamaihd.net/ugc/16432158165214925/BBD4B98054EA5B4FD9325E332B7AB1AC379E2CE7/",
        "NormalURL": "",
        "ColliderURL": "https://steamusercontent-a.akamaihd.net/ugc/16432158165211267/83126B855FA9E798F432672309C17CDD7940D115/",
        "Convex": false,
        "MaterialIndex": 0,
        "TypeIndex": 0,
        "CastShadows": true
      },
      "LuaScript": "",
      "LuaScriptState": "",
      "XmlUI": ""
    }
]]
-- End include: saved_object_data/boards/dark_board.lua

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

        board = spawnObjectJSON({
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

function spawnInvisiblePlanes(num_players, board_points)

    local w = DEFAULT_BOARD_WIDTH * BOARD_SCALES[num_players]
    local l = DEFAULT_BOARD_LENGTH * BOARD_SCALES[num_players]
    local a = w/WIDTH_LEG_RATIO
    local d = (l-a)/17

    for i, pos in ipairs(board_points) do
        local s = spawnObject({
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