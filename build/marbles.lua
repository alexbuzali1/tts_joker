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