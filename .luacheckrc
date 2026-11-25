-- luacheck config: run on the BUILT scripts (build/*.lua), after `lua build.lua`.
--
-- Only checks for undefined globals (warning 113). build.lua wraps every included file in its own do ... end
-- block, so a `local` in one file is invisible to the others; calling it from another file reads a nil global
-- and only fails when that line runs. This catches it before then, along with misspelt TTS API calls.

std = "lua54"
only = { "113" }

-- globals defined anywhere in the script (function foo() ... end, FOO = ...) count as defined
allow_defined = true

-- provided by Tabletop Simulator
read_globals = {
    -- objects and classes
    "self", "Global", "Player", "UI", "Wait", "JSON", "Color", "Vector", "Time", "Tables", "Turns", "Notes",
    "Hands", "Lighting", "Physics", "Info", "Grid", "MusicPlayer", "WebRequest",
    -- functions
    "getObjectFromGUID", "getAllObjects", "getObjects", "getSeatedPlayers", "spawnObject", "spawnObjectJSON",
    "spawnObjectData", "destroyObject", "printToAll", "printToColor", "broadcastToAll", "broadcastToColor",
    "log", "logStyle", "startLuaCoroutine", "stringColorToRGB", "group", "copy", "paste", "flipTable",
}
