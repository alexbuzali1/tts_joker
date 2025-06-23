--#include "constants.lua"
--#include "helpers.lua"

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