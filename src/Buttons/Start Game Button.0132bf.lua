--#include "../setup.lua"

function onLoad()
    self.setName('Start Game Button')
end

function startButtonFunction()
    startGame(Global.getVar("num_players"))
end