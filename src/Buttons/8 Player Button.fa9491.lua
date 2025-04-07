--#include "setup.lua"

function onLoad()
    buttonSetup(self,"load8Player","8 Player")   
end

function load8Player()

    print('Loading 8 Player Game')

    --Change table and mat
    changeMatShape(2)
    Global.call("setTableShape",{shape="Octagon"})

    --Load 8 player board
    local eightPlayerBoard = getObjectFromGUID("786755")
    eightPlayerBoard.call("setup")

    --Destroy buttons
    destroyButtons()

end