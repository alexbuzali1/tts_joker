-- buttons.lua
-- The clickable chips on the table: the 4/6/8 player buttons, Start Game, Reshuffle and the Turn Button.
-- Each turns an invisible chip into one big button.
--#include "constants.lua"

-- 4 / 6 / 8 Player buttons (click function lives in the button's own script).
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

-- The player-count buttons go once the table size is chosen.
function destroyPlayerButtons()
    destroyObject(getObjectFromGUID(FOUR_PLAYER_BUTTON_GUID))
    destroyObject(getObjectFromGUID(SIX_PLAYER_BUTTON_GUID))
    destroyObject(getObjectFromGUID(EIGHT_PLAYER_BUTTON_GUID))
end

-- Reshuffle (click function lives in the Reshuffle Button's script).
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

-- The Turn Button: its click function is in the Global script (game/turns.lua endTurnClicked), and its label
-- shows whose turn it is.
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

-- Start Game (click function lives in the Start Game Button's script).
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
