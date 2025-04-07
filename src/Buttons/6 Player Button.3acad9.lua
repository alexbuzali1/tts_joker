--#include "setup.lua"

function onLoad()
    buttonSetup(self,"load6Player","6 Player")      
end

function load6Player()
    
    
    print('Loading 6 Player Game')
    
    --Load six player board
    local sixPlayerBoard = getObjectFromGUID("577dcf")
    sixPlayerBoard.call("setup")

    --Destroy buttons
    destroyButtons()
end