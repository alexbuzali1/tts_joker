--#include "constants.lua"
--#include "cards.lua"
--#include "setup.lua"
--#include "helpers.lua"
--#include "marbles.lua"
--#include "hover_numbers.lua"

function onLoad()
    printToAll('Welcome to Joker!')  
end

--[[ The onUpdate event is called once per frame. --]]
function onUpdate()
    --[[ print('onUpdate loop!') --]]
end

function onPlayerTurn(player, previous)
    
    if not player then
        return
    end 

    turn_chip = getObjectFromGUID(TURN_BUTTON_GUID)
    turn_chip.editButton({index = 0, label = player.steam_name.."'s\nTurn"})
    Global.getTable("boards_by_player")[player.color].highlightOn(Color.fromString('Green'))
    Global.getTable("discard_piles")[player.color].highlightOn(Color.fromString('Green'))
    
    if not previous then
        return
    end

    --Can probably make this more efficient by not finding deck every turn, we'll see if it poses an issue
    Global.getTable("boards_by_player")[previous.color].highlightOff()
    Global.getTable("discard_piles")[player.color].highlightOff()
    deck = findCenterDeck()

    Wait.time(function()
        deck.deal(1,previous.color)
    end,.2)
    
end

function setTableShape(params)
    Tables.setTable(params.shape)
end

function onObjectEnterScriptingZone(zone, obj)
    
    if obj.tag == "Card" then

        local zone_name = zone.getName()        
        local player_color = zone_name:match("^(%a+)_DiscardPile")
        local last_player_color = obj.getVar("last_player_color")
        local player_name = Player[player_color].steam_name

        if player_color == last_player_color and player_name then
            printToAll(player_name .. " played a " .. obj.getName())
        else
            printToAll('Wrong discard pile, idiot')
        end
    end
end

function onObjectPickedUp(player_color, obj)
    if obj.tag == "Card" then
        obj.setVar("last_player_color", player_color)
    elseif obj.tag == "Checker" then
        obj.setVar("picked_up", true)
    end
end

function onObjectDrop(player_color, obj)
    if obj and obj.tag == "Checker" then
        obj.setVar("picked_up", false)
    end
end

function noop() end

function onObjectCollisionEnter(registered_object, info)

    --Marble collision
    marbleCollisionDetection(registered_object,info)
end

function onObjectHover(player_color, object)

    if (object and object.tag == "Checker" and player_color == object.getVar("player_color") 
    and not isAtStart(object) and not object.getVar("picked_up")) then
        local marble_index = getMarblePointIndex(object)
        arrangeHoverNumbers(player_color, marble_index, object.getVar("team_number"), object.getColorTint())
    else
        if Global.getVar("hover_numbers_by_player") ~= nil and #Player[player_color].getHoldingObjects() == 0 then
            hideHoverNumbers(player_color)        
        end
    end
end