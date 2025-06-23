-- Begin include: ../setup.lua
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
-- Begin include: board.lua
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
-- End include: board.lua
-- Begin include: cards.lua
-- already included: constants.lua
-- Begin include: helpers.lua
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

function changeMatShape(shapeNumber)
    local hex_mat = getObjectFromGUID("b62603")
    local data = hex_mat.getData()
    data["CustomImage"]["CustomTile"]["Type"] = shapeNumber
    local new_mat = spawnObjectJSON({json = JSON.encode(data)})
    destroyObject(hex_mat)
    return new_mat
end

function isNear(obj_x, obj_z, target_x, target_z, threshold)
    return math.abs(obj_x - target_x) <= threshold and math.abs(obj_z - target_z) <= threshold
end

function objectDistance(obj1, obj2)
    local p1 = obj1.getPosition()
    local p2 = obj2.getPosition()
    return math.sqrt((p1.x - p2.x)^2 + (p1.y - p2.y)^2 + (p1.z - p2.z)^2)
end

function tableRemoveByValue(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            table.remove(tbl, i)
            break
        end
    end
end

function shallowCopyTable(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = v
    end
    return copy
end
-- End include: helpers.lua

function dealCardsToAllPlayers(deck, count)
    for _, player in ipairs(Player.getPlayers()) do
        deck.deal(count, player.color)
    end
end

function findCenterDeck()
    for _, obj in ipairs(getAllObjects()) do
        if obj.tag == "Deck" then
            pos = obj.getPosition()
                if isNear(pos[1],pos[3],0,0,1) then
                return obj
            end
        end
    end
end

function labelDeck()
    
    deck = getObjectFromGUID(DECK_GUID)

    local total = #deck.getObjects()

    for i = 0, total - 1 do
        deck.takeObject({
            index = 0,
            position = {x = 0, y=1.2 + i * .1, z = 0},
            smooth = false,
            callback_function = function(card)
                local label = CARD_NAMES[(i % 54) + 1]
                card.setName(label)
                card.tooltip = false
            end
        })
    end
end

-- End include: cards.lua
-- Begin include: discard_piles.lua
-- already included: constants.lua

function singleDiscardPile(playerColor, position, rotation)

    local tile_data = {
        type = "Custom_Tile",
        position = position,
        rotation = rotation,
        scale = DISCARD_PILE_SCALE,
        callback_function = function(obj)
            obj.setName(playerColor .. "'s Play Zone")
            obj.setLock(true)
            -- obj.interactable = false
            obj.setSnapPoints({{position = {0, 0, 0}, rotation = {0, 0, 0},rotation_snap = true}}) 
        end
    }

    local pile = spawnObject(tile_data)
    pile.setCustomObject({image = DISCARD_PILE_LINK})
    return pile
end

function createDiscardPiles(numPlayers)

    local l = DEFAULT_BOARD_LENGTH * BOARD_SCALES[numPlayers]
    local w = DEFAULT_BOARD_WIDTH * BOARD_SCALES[numPlayers]
    local a = w/WIDTH_LEG_RATIO
    local out = .5*((l/math.tan(math.pi/numPlayers)) + a - w)
    local alpha = 2*math.pi/numPlayers
    local over = a * math.sin(alpha)/2
    
    local d = (l-a)/17

    local player_colors = PLAYER_COLORS[numPlayers]
    local x = -(over + 2.5 * d)
    local z =-(out - w/2)
    local theta, x_prime, z_prime, pos
    local discard_piles = {}

    for i = 1,#player_colors do

        theta = -alpha*(i-1)
        x_prime = x * math.cos(theta) - z * math.sin(theta)
        z_prime = x * math.sin(theta) + z * math.cos(theta)
        pos = {x_prime,1.2,z_prime}

        local discard_pile = singleDiscardPile(player_colors[i], pos, {0,180-theta*180/math.pi,0})
        spawnObject({
            type = "ScriptingTrigger",
            position = pos,
            rotation = discard_pile.getRotation(),
            scale = DISCARD_TRIGGER_SCALE,
            callback_function = function(zone)
                zone.setName(player_colors[i] .. "_DiscardPile") 
            end
        })
        discard_piles[player_colors[i]] = discard_pile
    end
    return discard_piles
end
-- End include: discard_piles.lua
-- Begin include: helpers.lua
-- already included: constants.lua

function changeMatShape(shapeNumber)
    local hex_mat = getObjectFromGUID("b62603")
    local data = hex_mat.getData()
    data["CustomImage"]["CustomTile"]["Type"] = shapeNumber
    local new_mat = spawnObjectJSON({json = JSON.encode(data)})
    destroyObject(hex_mat)
    return new_mat
end

function isNear(obj_x, obj_z, target_x, target_z, threshold)
    return math.abs(obj_x - target_x) <= threshold and math.abs(obj_z - target_z) <= threshold
end

function objectDistance(obj1, obj2)
    local p1 = obj1.getPosition()
    local p2 = obj2.getPosition()
    return math.sqrt((p1.x - p2.x)^2 + (p1.y - p2.y)^2 + (p1.z - p2.z)^2)
end

function tableRemoveByValue(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            table.remove(tbl, i)
            break
        end
    end
end

function shallowCopyTable(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = v
    end
    return copy
end
-- End include: helpers.lua
-- Begin include: buttons.lua
-- already included: constants.lua

function playerNumberButtonSetup(object,click_function,label,button_name)
    object.createButton({
        click_function = click_function,
        function_owner = object,                   
        label = label,                      
        position = {0, 0, 0},                 
        rotation = {0, 90, 0},                 
        width = 700,                             
        height = 300,                            
        font_size = 150                          
    })
    object.setName(button_name)
    object.locked = true
    object.setColorTint({0, 0, 0, 0})
    object.tooltip = false 
end

function destroyPlayerButtons()
    destroyObject(getObjectFromGUID(FOUR_PLAYER_BUTTON_GUID))
    destroyObject(getObjectFromGUID(SIX_PLAYER_BUTTON_GUID))
    destroyObject(getObjectFromGUID(EIGHT_PLAYER_BUTTON_GUID))
end

function reshuffleButtonSetup(object,click_function,label,button_name)
    object.createButton({
        click_function = click_function,
        function_owner = object,                   
        label = label,                      
        position = {0, 0, 0},                 
        rotation = {0, 90, 0},                 
        width = 700,                             
        height = 300,                            
        font_size = 150                          
    })
    object.setName(button_name)
    object.locked = true
    object.setColorTint({0, 0, 0, 0})
    object.setPosition({0,1.2,-4})
    object.tooltip = false 
end

function turnPlayerButtonSetup(object,click_function,label,button_name)
    object.createButton({
        click_function = click_function,
        function_owner = Global,                   
        label = label,                      
        position = {0, 0, 0},                 
        rotation = {0, 90, 0},                 
        width = 700,                             
        height = 300,                            
        font_size = 100,                       
    })
    object.setName(button_name)
    object.locked = true
    object.setColorTint({0, 0, 0, 0})
    object.tooltip = false 
end

function startGameButtonSetup(object,click_function,label,button_name)
    object.createButton({
        click_function = click_function,
        function_owner = object,                   
        label = label,                      
        position = {0, 0, 0},                 
        rotation = {0, 90, 0},                 
        width = 700,                             
        height = 300,                            
        font_size = 130,                       
    })
    object.setName(button_name)
    object.locked = true
    object.setColorTint({0, 0, 0, 0})
    object.tooltip = false 
end
    

-- End include: buttons.lua
-- Begin include: marbles.lua
-- already included: constants.lua
-- already included: helpers.lua

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
                    obj.setVar("pickedUp", false)
                    obj.setTable("start_points",start_points_by_player[player_colors[i]])
                    obj.setTable("friendly_bonk_position",friendly_bonk_points_by_player[player_colors[i]]["position"])
                end
            })
            marble.registerCollisions()
            table.insert(team_marbles,marble)
        end
        marbles_by_player[player_colors[i]] = team_marbles
    end 
    return marbles_by_player
end

function marbleCollisionDetection(registered_object, info)
    
    if registered_object.tag == "Checker" and info.collision_object.tag == "Checker" then
        this_marble = registered_object
        other_marble = info.collision_object

        if (objectDistance(this_marble,other_marble) < COLLISION_DISTANCE_THRESHOLDS[Global.getVar("num_players")] and 
        this_marble.getPosition().y < other_marble.getPosition().y) then
            
            --Sometimes happens when a marble gets bonked back home, just don't do anything
            if this_marble.getVar("team_number") == other_marble.getVar("team_number") then
                return
            end

            --Enemy bonk
            if this_marble.getVar("team_number") % 2 != other_marble.getVar("team_number") % 2 then
                bonkAnimation(this_marble,findEmptyStartPosition(this_marble))

            --Friendly bonk
            else
                bonkAnimation(this_marble,this_marble.getVar("friendly_bonk_position"))
            end

            --Announce bonk
            local bonkee = Player[this_marble.getVar("player_color")].steam_name
            local bonker = Player[other_marble.getVar("player_color")].steam_name

            if bonker and bonkee then printToAll(bonker .. " bonked " .. bonkee .. "!") end
                
        end
    end
end

function bonkAnimation(marble, target_position)
    local current_position = marble.getPosition()
    marble.setPositionSmooth({current_position.x, current_position.y + 3, current_position.z})
    Wait.time(function()
        marble.setPositionSmooth({target_position.x, target_position.y + 3, target_position.z})
    end,.5)
end

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
end

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

function getMarblePointIndex(marble)
    -- local board_points = Global.getVar("board_points")
    local non_start_points = Global.getVar("non_start_points")
    local marble_x = marble.getPosition()[1]
    local marble_z = marble.getPosition()[3]
    local board_point_x, board_point_z

    for i = 1,#non_start_points do
        point_x = non_start_points[i]["position"]["x"]
        point_z = non_start_points[i]["position"]["z"]
        if isNear(marble_x,marble_z,point_x,point_z,.05) then
            return i
        end
    end
end
-- End include: marbles.lua
-- Begin include: color_picker.lua
function showColorGridForPlayer(color)
    
    local grid_size = COLOR_PICKER_GRID_SIZE

    local panel_size = 300
    local cell_size = math.floor(panel_size / grid_size)

    local xml = string.format([[
        <Text id = "colorText_%s" text="Pick a marble color" fontSize="28" color="#FFFFFF" position="500 -125"/>
        <Panel id="colorPanel_%s" player_color="%s" width="%d" height="%d" position="500 -300">
            <VerticalLayout spacing="0">
    ]], color, color, color, panel_size, panel_size)

    for row = 0, grid_size - 1 do
        xml = xml .. '<HorizontalLayout spacing="0" childAlignment="MiddleCenter">'
        for col = 0, grid_size - 1 do
            local r = row / (grid_size - 1)
            local g = col / (grid_size - 1)
            local b = 1 - (row + col) / (2 * (grid_size - 1))

            local hex = string.format("#%02X%02X%02X", r * 255, g * 255, b * 255)
            local id = string.format("colorBtn_%s_%d_%d", color, row, col)

            xml = xml .. string.format([[
                <Button id="%s" onClick="colorChosen" color="%s" preferredWidth="%d" preferredHeight="%d" />
            ]], id, hex, cell_size, cell_size)
        end
        xml = xml .. '</HorizontalLayout>'
    end

    xml = xml .. '</VerticalLayout></Panel>'
    UI.setXml(UI.getXml() .. xml)
end

function colorChosen(player, value, id)

    local _, _, row, col = string.find(id, "colorBtn_%a+_(%d+)_(%d+)")
    row = tonumber(row)
    col = tonumber(col)

    local grid_size = COLOR_PICKER_GRID_SIZE

    local r = row / (grid_size - 1)
    local g = col / (grid_size - 1)
    local b = 1 - (row + col) / (2 * (grid_size - 1))

    local team_marbles = Global.getTable("marbles_by_player")[player.color]
    for _, marble in ipairs(team_marbles) do
        marble.setColorTint({r = r, g = g, b = b})
    end
end
-- End include: color_picker.lua
-- Begin include: hover_numbers.lua
-- already included: constants.lua
-- already included: helpers.lua

function spawnHoverNumbers(num_players)

    local player_colors = PLAYER_COLORS[num_players]
    local hover_numbers_by_player = {}
    local hover_numbers

    for i = 1,num_players do

        hover_numbers = {}

        for j = 1,#HOVER_NUMBER_MESHES do
            hover_numbers[j] = spawnObjectJSON({
            json = hoverNumberJSON(HOVER_NUMBER_MESHES[j],HOVER_NUMBER_GUIDS[j]),
            position = {4+.5*j, 10 + i, 0}, --FIX THIS LATER
            rotation = {0,0,0},
            callback_function = function(obj)
                obj.setInvisibleTo(PLAYER_COLORS[num_players])
                obj.setLock(true)
            end
            })
        end
        hover_numbers_by_player[player_colors[i]] = hover_numbers
    end
    
    return hover_numbers_by_player
end

function hoverNumberJSON(meshURL, guid)
    local obj = {
        GUID = guid,
        Name = "Custom_Model",
        Transform = {
            posX = 0,
            posY = 0,
            posZ = 0,
            rotX = 0,
            rotY = 0,
            rotZ = 0,
            scaleX = .75,
            scaleY = .75,
            scaleZ = .75
        },
        Nickname = "",
        Description = "",
        GMNotes = "",
        AltLookAngle = { x = 0.0, y = 0.0, z = 0.0 },
        ColorDiffuse = { r = 1.0, g = 1.0, b = 1.0 },
        LayoutGroupSortIndex = 0,
        Value = 0,
        Locked = true,
        Grid = true,
        Snap = true,
        IgnoreFoW = false,
        MeasureMovement = false,
        DragSelectable = true,
        Autoraise = true,
        Sticky = true,
        Tooltip = true,
        GridProjection = false,
        HideWhenFaceDown = false,
        Hands = false,
        CustomMesh = {
            MeshURL = meshURL,
            DiffuseURL = "",
            NormalURL = "",
            ColliderURL = PLANE_COLLIDER_URL,
            Convex = false,
            MaterialIndex = 0,
            TypeIndex = 0,
            CastShadows = true
        },
        LuaScript = "",
        LuaScriptState = "",
        XmlUI = "",
    }
    return JSON.encode(obj)
end

function arrangeHoverNumbers(player_color, marble_index, team_number, marble_color)

    hideHoverNumbers(player_color)
    local hover_numbers = Global.getTable("hover_numbers_by_player")[player_color]
    local non_start_points = Global.getTable("non_start_points")
    local alpha = (2*math.pi/Global.getVar("num_players")) * 180/math.pi

    local player_colors = shallowCopyTable(PLAYER_COLORS[Global.getVar("num_players")])
    tableRemoveByValue(player_colors, player_color)

    local first_goal_index = 4 + (team_number-1) * 23
    local last_goal_index = first_goal_index + 4
    
    local numbers_arranged = 0
    local i = 1
    local potential_index

    while numbers_arranged < 13 do

        potential_index = (((marble_index + i) - 1) % #non_start_points) + 1

        if potential_index % 23 == 4 and potential_index ~= first_goal_index then
            i = i + 5
        else 
            hover_numbers[numbers_arranged+1].setPosition(non_start_points[potential_index]["position"])
            hover_numbers[numbers_arranged+1].setRotation({HOVER_NUMBER_ROTATION,alpha * (team_number - 1), 0})
            hover_numbers[numbers_arranged+1].setInvisibleTo(player_colors)
            hover_numbers[numbers_arranged+1].highlightOn(marble_color)
            hover_numbers[numbers_arranged+1].setColorTint(HOVER_NUMBER_COLOR)
            numbers_arranged = numbers_arranged + 1
            i = i + 1

            if potential_index == last_goal_index then return end
        end
    end
end

function hideHoverNumbers(player_color)

    local hover_numbers = Global.getTable("hover_numbers_by_player")[player_color]
    local player_colors = PLAYER_COLORS[Global.getVar("num_players")]

    for i = 1,13 do
        hover_numbers[i].setInvisibleTo(player_colors)
        hover_numbers[i].setPosition({4+.5*i, 10, 0})
    end
end
-- End include: hover_numbers.lua

function preGameSetup(num_players)

    printToAll("Loading " .. num_players .. " player game")

    --Change table and mat
    local new_mat = changeMatShape(MAT_SHAPES[num_players])
    Global.setVar("num_players",num_players)
    Global.call("setTableShape",{shape=TABLE_SHAPES[num_players]})

    --Create start game button
    start_game_chip =  getObjectFromGUID(START_GAME_BUTTON_GUID)
    startGameButtonSetup(start_game_chip,"startButtonFunction","Start\nGame","Start Game Button")

    --Calculate and assign snap points
    local board_points, start_points_by_player, friendly_bonk_points_by_player, non_start_points = getBoardPoints(num_players)
    Global.setSnapPoints(board_points)
    Global.setTable("non_start_points",non_start_points)

    --Spawn invisible planes for marble stability
    spawnInvisiblePlanes(num_players,board_points)
    
    --Create board
    local board_array = createBoard(num_players)
    local player_colors = PLAYER_COLORS[num_players]
    local boards_by_player = {}
    
    for i = 1,num_players do
        boards_by_player[player_colors[i]] = board_array[i]
    end
    Global.setTable("boards_by_player",boards_by_player)

    --Spawn marbles
    local marbles_by_player = spawnMarbles(num_players,start_points_by_player,friendly_bonk_points_by_player)
    Global.setTable("marbles_by_player", marbles_by_player)

    --Spawn hover_numbers
    local hover_numbers_by_player = spawnHoverNumbers(num_players)
    Global.setTable("hover_numbers_by_player",hover_numbers_by_player)
    
    --Label and shuffle cards
    labelDeck()
    Wait.time(function()
        deck = findCenterDeck()
    end,1)
    
    Wait.time(function()
        deck.shuffle()
    end,2)

    --Destroy player number buttons
    destroyPlayerButtons()

    --Display color picker
    for _, player in ipairs(Player.getPlayers()) do
        showColorGridForPlayer(player.color)
    end
end

function startGame(num_players)

    printToAll('Starting game')

    --Remove marble color picker
    for _, player in ipairs(Player.getPlayers()) do
        UI.hide("colorPanel_" .. player.color)
        UI.hide("colorText_" .. player.color)
    end

    --Destroy start game button
    destroyObject(getObjectFromGUID(START_GAME_BUTTON_GUID))    
    
    --Deal cards
    local deck = findCenterDeck()
    dealCardsToAllPlayers(deck,6)
    
    --Create discard piles
    local discard_piles = createDiscardPiles(num_players)
    Global.setTable("discard_piles",discard_piles)
    discard_pile_positions = {}
    for _, discard_pile in pairs(discard_piles) do
        table.insert(discard_pile_positions, discard_pile.getPosition())
    end

    --Set up reshuffle button
    local reshuffle_chip = getObjectFromGUID(RESHUFFLE_BUTTON_GUID)
    Global.setTable("discard_pile_positions", discard_pile_positions)
    reshuffleButtonSetup(reshuffle_chip,"reshuffle","Reshuffle","Reshuffle Button") 

    --Set up turn button
    local turn_chip = getObjectFromGUID(TURN_BUTTON_GUID)
    turnPlayerButtonSetup(turn_chip,"noop","","Turn Button")

    --Set up turn system
    Turns.enable = true
    Turns.pass_turns = true
    Turns.type = 1
    Turns.disable_interactations = false

    local players = Player.getPlayers()
    local random_index = math.random(#players)
    local chosen_player = players[random_index]
    Turns.turn_color = chosen_player.color
end
-- End include: ../setup.lua

function onLoad()
    self.setName('Start Game Button')
end

function startButtonFunction()
    startGame(Global.getVar("num_players"))
end