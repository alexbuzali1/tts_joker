-- hover_numbers.lua
-- The distance numbers 1-13 that appear in front of a marble you hover over (only you see yours). This file
-- spawns the number pieces when the table is set up: 13 per seat, parked out of sight above the table. Placing
-- them on hover is game/hover.lua (Global script).
--#include "constants.lua"
--#include "helpers.lua"

-- Spawn the 13 number pieces for every seat. Returns { [seat colour] = { piece 1, ..., piece 13 } }.
function spawnHoverNumbers(num_players)

    local player_colors = PLAYER_COLORS[num_players]
    local hover_numbers_by_player = {}
    local hover_numbers

    for i = 1,num_players do

        hover_numbers = {}

        for j = 1,#HOVER_NUMBER_MESHES do
            hover_numbers[j] = spawnObjectJSON({
            json = hoverNumberJSON(HOVER_NUMBER_MESHES[j],HOVER_NUMBER_GUIDS[j]),
            position = {4+.5*j, 10 + i, 0},        -- parked above the table until needed
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

-- The saved-object JSON of one number piece: a locked, untinted custom model with a flat collider.
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
