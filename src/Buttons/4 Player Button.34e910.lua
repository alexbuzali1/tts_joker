--#include "setup.lua"

function onLoad()
    buttonSetup(self,"load4Player","4 Player")  
end

function load4Player()

    print('Loading 4 Player Game')
    
    --Change table and mat
    changeMatShape(0)
    Global.call("setTableShape",{shape="Square"})

    --Load four player board
    local fourPlayerBoard = getObjectFromGUID("50d0e9")
    fourPlayerBoard.call("setup")

    --Destroy buttons
    destroyButtons()
end