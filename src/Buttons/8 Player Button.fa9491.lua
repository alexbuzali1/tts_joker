--#include "../setup.lua"

function onLoad()
    buttonSetup(self,"load8Player","8 Player",8)   
end

function load8Player()
    loadGame(8)
end