-- ui/settings.lua  (Global script)
-- The host's settings menu (user, 11-17): a gear button at the top right, only the host sees it. It holds what the
-- host chat commands set (host/commands.lua), so nobody has to remember them:
--   * bot level 1-10 (!level) and animation speed (!speed)
--   * hybrid mode (!hybrid): from the next Start Game, empty seats are played in person
--   * what players who join start with: easy play and click to play on or off (each player can still switch their
--     own at the bottom right; once they do, their choice sticks)
--   * the turn timer (game/turn_timer.lua): the flashing border and its sounds
-- Saved with the game (game/save.lua).

SETTINGS = SETTINGS or { easy = false, click = false, timer = true, sound = true }
UI_STATE.settings = UI_STATE.settings or false

-- images the UI loads (UI.setCustomAssets): the gear, and the tutorial's screenshots (ui/tutorial.lua). They're
-- served from the GitHub repository; ASSET_BASE is where.
ASSET_BASE = "https://raw.githubusercontent.com/lewisbv/tts_joker/restructure/assets/"
function uiAssets()
    local list = { { name = "gear", url = ASSET_BASE .. "ui/gear.png" } }
    for _, page in ipairs(TUTORIAL_PAGES or {}) do
        if page.image and TUTORIAL_HAVE_IMAGES then list[#list + 1] = { name = "tut_" .. page.image, url = ASSET_BASE .. "tutorial/" .. page.image .. ".png" } end
    end
    pcall(function() UI.setCustomAssets(list) end)
end

function settingsLoad(t)
    for _, k in ipairs({ "easy", "click", "timer", "sound" }) do
        if type(t[k]) == "boolean" then SETTINGS[k] = t[k] end
    end
end

-- a player sitting down (or a new game) gets the defaults, unless they've switched easy play / click to play
-- themselves (EASY.chosen)
function settingsApplyDefaults(color)
    if not (EASY and color) then return end
    EASY.chosen = EASY.chosen or {}
    if EASY.chosen[color] then return end
    EASY.on[color] = SETTINGS.easy or nil
    EASY.click[color] = SETTINGS.click or nil
end
function settingsApplyDefaultsAll()
    for _, c in ipairs(PLAYER_COLORS[Global.getVar("num_players")] or {}) do settingsApplyDefaults(c) end
end

local function isHost(player) return player and Player[player.color] and Player[player.color].host end

function settingsGearXml()
    return '<Button id="settingsGear" visibility="Host" onClick="settingsToggle" rectAlignment="UpperRight" offsetXY="-16 -64" '
        .. 'width="54" height="54" icon="gear" color="#000000B0" tooltip="Settings" tooltipPosition="Left"/>'
end

local function row(label, buttons)
    local x = { string.format('<HorizontalLayout spacing="5" preferredHeight="36"><Text fontSize="16" color="#FFFFFF" alignment="MiddleLeft" preferredWidth="150">%s</Text>', xmlEscape(label)) }
    for _, b in ipairs(buttons) do
        x[#x + 1] = string.format('<Button id="%s" onClick="settingsClick" fontSize="15" color="%s" textColor="%s">%s</Button>',
            b.id, b.on and "#E8C547" or "#555555", b.on and "#000000" or "#FFFFFF", xmlEscape(b.text))
    end
    x[#x + 1] = '</HorizontalLayout>'
    return table.concat(x)
end
local function onOff(key, on)
    return { { id = "set_" .. key .. "_off", text = "Off", on = not on }, { id = "set_" .. key .. "_on", text = "On", on = on } }
end

function settingsXml()
    if not UI_STATE.settings then return "" end
    local lv1, lv2 = {}, {}
    for n = 1, 10 do
        local b = { id = "set_level_" .. n, text = tostring(n), on = BOT_DIFFICULTY == n }
        if n <= 5 then lv1[#lv1 + 1] = b else lv2[#lv2 + 1] = b end
    end
    local sp = {}
    for i, s in ipairs(BOT_SPEEDS) do sp[#sp + 1] = { id = "set_speed_" .. i, text = s.name, on = BOT_STATE.speed_index == i } end
    local x = {}
    x[#x + 1] = '<Panel id="settingsPanel" visibility="Host" rectAlignment="UpperRight" offsetXY="-16 -126" width="520" height="520" color="#000000E0" padding="14 14 10 10">'
        .. '<VerticalLayout spacing="7" childForceExpandHeight="false">'
        .. '<HorizontalLayout preferredHeight="36"><Text fontSize="24" fontStyle="Bold" color="#FFE066" alignment="MiddleLeft">Settings</Text>'
        .. '<Button id="set_close" onClick="settingsClick" fontSize="16" preferredWidth="90" flexibleWidth="0">Close</Button></HorizontalLayout>'
    x[#x + 1] = row("Bot level (9 = best)", lv1)
    x[#x + 1] = row("", lv2)
    x[#x + 1] = row("Animation speed", sp)
    x[#x + 1] = row("Hybrid mode", onOff("hybrid", IRL and IRL.mode))
    x[#x + 1] = '<Text fontSize="13" color="#BBBBBB" preferredHeight="34">Hybrid: from the next Start Game, empty seats are played at a real board instead of by bots.</Text>'
    x[#x + 1] = row("New players: Easy play", onOff("easy", SETTINGS.easy))
    x[#x + 1] = row("New players: Click to play", onOff("click", SETTINGS.click))
    x[#x + 1] = row("Turn timer", onOff("timer", SETTINGS.timer))
    x[#x + 1] = row("Timer sounds", onOff("sound", SETTINGS.sound))
    x[#x + 1] = '<Text fontSize="13" color="#BBBBBB" preferredHeight="52">Turn timer: the screen edge glows in the player\'s colour on their turn, flashes after 25 s, faster with ticking after 40 s, and goes all out after 55 s. The ticks play through TTS\'s music player, so everyone hears them.</Text>'
    x[#x + 1] = '</VerticalLayout></Panel>'
    return table.concat(x)
end

function settingsToggle(player)
    if not isHost(player) then return end
    UI_STATE.settings = not UI_STATE.settings
    refreshGameUI()
end

function settingsClick(player, value, id)
    if not isHost(player) then return end
    id = tostring(id or "")
    if id == "set_close" then UI_STATE.settings = false; refreshGameUI(); return end
    local n = tonumber(id:match("^set_level_(%d+)$"))
    if n then botSetDifficulty(n) end
    local i = tonumber(id:match("^set_speed_(%d+)$"))
    if i and BOT_SPEEDS[i] then BOT_STATE.speed_index = i; botHostMsg("Animation speed: " .. BOT_SPEEDS[i].name) end
    local key, v = id:match("^set_(%a+)_(o%a+)$")
    if key then
        local on = (v == "on")
        if key == "hybrid" then
            if IRL then IRL.mode = on end
            botHostMsg(on and "Hybrid mode ON: from the next Start Game, empty seats are played in person"
                       or "Hybrid mode OFF: bots fill empty seats from the next Start Game")
        elseif key == "easy" or key == "click" then
            SETTINGS[key] = on
            settingsApplyDefaultsAll()
        elseif key == "timer" then
            SETTINGS.timer = on
            if not on and turnTimerStop then turnTimerStop() end
        elseif key == "sound" then
            SETTINGS.sound = on
            if not on and turnTimerSound then turnTimerSound(nil) end
        end
    end
    refreshGameUI()
end
