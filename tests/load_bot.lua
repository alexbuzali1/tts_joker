-- tests/load_bot.lua
-- Loads the bot's rules and search (pure Lua, no Tabletop Simulator needed) into plain Lua, in the same order as
-- the Global script includes them. Used by the bot test suites and the analysis tools:
--   dofile("tests/load_bot.lua")    -- from the repository root
for _, f in ipairs({ "rules", "evaluate", "setups", "move_costs", "hand", "search", "engine" }) do
    dofile("src/bot/" .. f .. ".lua")
end
