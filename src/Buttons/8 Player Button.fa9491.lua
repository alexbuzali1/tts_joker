--#include "../setup.lua"
--#include "../buttons.lua"

function onLoad()
    playerNumberButtonSetup(self,"load8Player","8 Player",'8 Player Button')   
end

function load8Player()
    preGameSetup(8)
end