--#include "../setup.lua"
--#include "../constants.lua"

function onLoad()
    buttonSetup(self,"load4Player","4 Player")  
end

function load4Player()
    loadGame(4)
end