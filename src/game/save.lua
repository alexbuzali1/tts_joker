-- game/save.lua  (Global script)
-- What the Global script keeps in the TTS save, so a reload (or a host's Save & Play) doesn't lose a game in
-- progress. Global onSave returns saveGameState(); Global onLoad passes it back to loadGameState().
--   stats   the post-game stats so far (game/stats.lua)
--   flags   "Flag bad move" reports the flag server never got (bot/flags.lua), sent again later
--   bot     the host's bot settings: difficulty, think time, animation speed, all-bot mode
--   styles  the marble colours / effects players picked (ui/color_picker.lua)
--   irl     hybrid mode: in-person seats and their names (play/hybrid.lua)
--   names   names players picked for themselves (ui/names.lua); bot_names: the host's names for bots (!name)
--   settings the host's settings menu (ui/settings.lua): defaults for joining players, turn timer

-- Bump this when the bot settings' defaults change: settings saved by an older version are then ignored, so an
-- old save doesn't bring back old defaults.
BOT_SETTINGS_VERSION = 3

function saveGameState()
    local flags = BOT_FLAGS and #BOT_FLAGS > 0 and BOT_FLAGS or nil
    return JSON.encode({
        stats = GAME_STATS,
        flags = flags,
        bot = { difficulty = BOT_DIFFICULTY, think_time = BOT_THINK_TIME, all_bots = BOT_ALL_SEATS or false,
                speed = BOT_STATE and BOT_STATE.speed_index, v = BOT_SETTINGS_VERSION },
        styles = MARBLE_STYLE and next(MARBLE_STYLE) and MARBLE_STYLE or nil,
        irl = { mode = IRL.mode, seats = IRL.seats, names = IRL.names },
        names = PLAYER_NAMES and next(PLAYER_NAMES) and PLAYER_NAMES or nil,
        bot_names = BOT_NAMES and next(BOT_NAMES) and BOT_NAMES or nil,
        settings = SETTINGS,
    })
end

function loadGameState(saved)
    if not saved or saved == "" then return end
    local ok, data = pcall(JSON.decode, saved)
    if not ok or type(data) ~= "table" then return end

    if type(data.stats) == "table" and data.stats.players then
        GAME_STATS = data.stats
        GAME_STATS.snapshot = nil
    end
    if type(data.flags) == "table" then BOT_FLAGS = data.flags end
    if type(data.names) == "table" then PLAYER_NAMES = data.names end
    if type(data.bot_names) == "table" then BOT_NAMES = data.bot_names end
    if type(data.settings) == "table" and settingsLoad then settingsLoad(data.settings) end
    if type(data.irl) == "table" then
        IRL.mode = data.irl.mode == true
        IRL.seats = type(data.irl.seats) == "table" and data.irl.seats or {}
        IRL.names = type(data.irl.names) == "table" and data.irl.names or {}
    end
    if type(data.styles) == "table" then
        MARBLE_STYLE = data.styles
        -- once the marbles exist: see-through outlines back on, effects running again
        Wait.time(function()
            for color in pairs(MARBLE_STYLE) do pcall(marbleApplyStyle, color) end
        end, 1)
    end
    -- bot settings (only from this version's saves)
    if type(data.bot) == "table" and data.bot.v == BOT_SETTINGS_VERSION then
        BOT_DIFFICULTY = tonumber(data.bot.difficulty) or BOT_DIFFICULTY
        BOT_THINK_TIME = tonumber(data.bot.think_time) or BOT_THINK_TIME
        if data.bot.all_bots ~= nil then BOT_ALL_SEATS = data.bot.all_bots == true end
        local sp = tonumber(data.bot.speed)
        if sp and BOT_SPEEDS[sp] then BOT_STATE.speed_index = sp end
    end
end
