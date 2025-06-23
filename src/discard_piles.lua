--#include "constants.lua"

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