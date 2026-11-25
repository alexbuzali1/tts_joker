-- The "6 Player" button: sets the table up for 6 players (setup.lua preGameSetup).
--#include "../setup.lua"
--#include "../buttons.lua"

function onLoad()
    playerNumberButtonSetup(self,"load6Player","6 Player",'6 Player Button')      
end

function load6Player()
    preGameSetup(6)
end