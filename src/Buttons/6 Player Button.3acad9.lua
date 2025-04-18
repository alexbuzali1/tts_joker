--#include "../setup.lua"

function onLoad()
    buttonSetup(self,"load6Player","6 Player",6)      
end

function load6Player()
    loadGame(6)
end