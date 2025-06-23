--#include "constants.lua"
--#include "helpers.lua"

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