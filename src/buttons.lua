--#include "constants.lua"

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
    
