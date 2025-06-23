--#include "../setup.lua"
--#include "../buttons.lua"

function onLoad()
    playerNumberButtonSetup(self,"load6Player","6 Player",'6 Player Button')      
end

function load6Player()
    preGameSetup(6)
end