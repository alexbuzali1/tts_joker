-- ui/names.lua  (Global script)
-- How players are named and coloured everywhere (chat, banner, Turn Button, panels, stats).
--   * a seat's name follows its MARBLE colour, not its TTS seat colour: the Orange seat with blue marbles is "Blue".
--     Marble colours change with the colour picker (ui/color_picker.lua), so everything here reads them live.
--   * bots are "BOT (<marble colour>)", in-person seats "<name> (in person)" (play/hybrid.lua), people their Steam
--     name, and an empty seat its marble colour.

-- A message for the host only (settings, errors, debug): the other players never see it. Still in the game log.
function botHostMsg(text, color)
    local sent = false
    pcall(function()
        for _, p in ipairs(Player.getPlayers()) do
            if p.host then p.print(text, color or { 1, 0.85, 0.3 }); sent = true end
        end
    end)
    if not sent then print(text) end
    pcall(glog, "host", { text = tostring(text) })
end

-- English name of a seat's marble colour (nearest of a small palette), e.g. the Orange seat's blue marbles -> "Blue".
-- Bots are named after their marbles, not their seat, so "BOT (Blue)" plays the blue marbles.
BOT_COLOR_NAMES = {
    { "Black", 0, 0, 0 }, { "White", 1, 1, 1 }, { "Grey", 0.5, 0.5, 0.5 },
    { "Red", 1, 0, 0 }, { "Orange", 1, 0.5, 0 }, { "Yellow", 1, 1, 0 }, { "Green", 0, 1, 0 },
    { "Dark Green", 0, 0.45, 0 }, { "Cyan", 0, 1, 1 }, { "Blue", 0, 0, 1 }, { "Navy", 0, 0, 0.45 },
    { "Purple", 0.5, 0, 1 }, { "Magenta", 1, 0, 1 }, { "Pink", 1, 0.55, 0.75 }, { "Brown", 0.55, 0.3, 0.1 },
}
function marbleColorName(color)
    local mbp = Global.getTable("marbles_by_player")
    if not (mbp and mbp[color] and mbp[color][1]) then return color end   -- before the marbles exist
    local c = marbleColorOf(color)
    local best, bestD = color, 1e9
    for _, e in ipairs(BOT_COLOR_NAMES) do
        local d = (c.r - e[2]) ^ 2 + (c.g - e[3]) ^ 2 + (c.b - e[4]) ^ 2
        if d < bestD then best, bestD = e[1], d end
    end
    return best
end


function botName(color) return "BOT (" .. marbleColorName(color) .. ")" end

------------------------------------------------------------------------
-- name colours: a bot's name is shown in the colour of its marbles
------------------------------------------------------------------------
-- current tint of that seat's marbles (read live, so it follows the colour picker too)
function marbleColorOf(color)
    -- a picked style (ui/color_picker.lua): its base colour, not the tint an effect is animating right now
    if marbleStyleColor then
        local base = marbleStyleColor(color)
        if base then return base end
    end
    local mbp = Global.getTable("marbles_by_player")
    local team = mbp and mbp[color]
    if team and team[1] then
        local c = team[1].getColorTint()
        return { r = c.r, g = c.g, b = c.b }
    end
    return { r = 1, g = 1, b = 1 }
end

local function colorLuminance(c) return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b end
local function colorMix(c, t, k) return { r = c.r + (t - c.r) * k, g = c.g + (t - c.g) * k, b = c.b + (t - c.b) * k } end

-- for dark backgrounds (chat, bot panel, broadcasts): lift very dark marbles (black, pure blue) so they stay readable
function nameColorOnDark(color)
    local c = marbleColorOf(color)
    if colorLuminance(c) < 0.2 then c = colorMix(c, 1, 0.5) end
    return c
end

-- for the light Turn Button: darken very light marbles (white, yellow, cyan)
function nameColorOnLight(color)
    local c = marbleColorOf(color)
    if colorLuminance(c) > 0.65 then c = colorMix(c, 0, 0.45) end
    return c
end

function colorHex(c)
    return string.format("%02X%02X%02X", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
end

-- bot name with a chat colour code: "[00FF00]BOT (Green)[-]". Chat, printToAll and broadcasts only;
-- object button labels and XML UI do NOT understand [hex] codes.
function botChatName(color)
    return "[" .. colorHex(nameColorOnDark(color)) .. "]" .. botName(color) .. "[-]"
end

-- name to show in chat for a colour: coloured bot label, or the human's steam name
function playerLabel(color)
    if botIsBot(color) then return botChatName(color) end
    if irlIsSeat(color) then return irlLabel(color) end
    local p = Player[color]
    if p and p.steam_name and p.steam_name ~= "" then return p.steam_name end
    return marbleColorName(color)          -- empty seat: its marble colour, not the TTS seat colour
end

-- Seat number (1..N, turn order) of a seat colour, or nil for colours not in this game.
function botSeatIndex(color)
    local N = Global.getVar("num_players")
    for i, c in ipairs(PLAYER_COLORS[N]) do if c == color then return i end end
    return nil
end


-- "Blue marble" for a bot's marble, "donkachu's marble" for a human's; in the marble colour for chat
function marbleOwnerText(color)
    local hex = colorHex(nameColorOnDark(color))
    if botIsBot(color) then return "[" .. hex .. "]" .. marbleColorName(color) .. " marble[-]" end
    local p = Player[color]
    local who = (p and p.steam_name and p.steam_name ~= "") and p.steam_name or color
    return "[" .. hex .. "]" .. who .. "'s marble[-]"
end
