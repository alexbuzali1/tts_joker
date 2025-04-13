--#include "../setup.lua"

function onLoad()
    buttonSetup(self,"load6Player","6 Player")      
end

function load6Player()
    loadGame(6)
end