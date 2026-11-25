-- The "4 Player" button: sets the table up for 4 players (setup.lua preGameSetup).
--#include "../setup.lua"
--#include "../buttons.lua"

function onLoad()
    playerNumberButtonSetup(self,"load4Player","4 Player",'4 Player Button')  
end

function load4Player()
    preGameSetup(4)
end