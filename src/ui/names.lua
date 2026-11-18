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

-- A person can pick the name they're shown by (user, 11-17): a field in their colour picker, like the host names
-- in-person seats. Kept per seat with the Steam name it was set for, so someone else sitting there later isn't
-- called by it. Saved with the game (game/save.lua).
PLAYER_NAMES = PLAYER_NAMES or {}      -- [seat colour] = { name = "Henry", steam = "Henny P" }
function personName(color)
    local p = Player[color]
    local steam = p and p.steam_name
    local e = PLAYER_NAMES[color]
    if e and e.name and e.name ~= "" and e.steam == steam then return e.name end
    if steam and steam ~= "" then return steam end
    return nil
end

-- name to show in chat for a colour: coloured bot label, or the human's (picked or Steam) name
function playerLabel(color)
    if botIsBot(color) then return botChatName(color) end
    if irlIsSeat(color) then return irlLabel(color) end
    local who = personName(color)
    if who then return who end
    return marbleColorName(color)          -- empty seat: its marble colour, not the TTS seat colour
end

-- Seat number (1..N, turn order) of a seat colour, or nil for colours not in this game.
function botSeatIndex(color)
    local N = Global.getVar("num_players")
    for i, c in ipairs(PLAYER_COLORS[N]) do if c == color then return i end end
    return nil
end


-- "Blue marble" for a bot's marble, "Alice's marble" for a person's; in the marble colour for chat
function marbleOwnerText(color)
    local hex = colorHex(nameColorOnDark(color))
    if botIsBot(color) then return "[" .. hex .. "]" .. marbleColorName(color) .. " marble[-]" end
    local who = personName(color) or color
    return "[" .. hex .. "]" .. who .. "'s marble[-]"
end

------------------------------------------------------------------------
-- A move in words, for the chat log and easy play's choices (user, 11-17: show how a 7 is split; "marble 2" read
-- like the card played, so marbles are named by owner and the moves by distance):
--   "Blue marble 2 into the finish + Alice's marble 5 (7 split 2 + 5)"
--   "Alice's marble 8 back (bonks Blue marble)"      "Blue marble jumps onto Alice's marble (Joker)"
-- S = the board before the move, act = a JokerBot action. chat = true: names in their marble colours (chat only).
------------------------------------------------------------------------
local function ownerWord(color, chat)
    if chat then return marbleOwnerText(color) end
    if botIsBot(color) then return marbleColorName(color) .. " marble" end
    local who = irlIsSeat(color) and ((IRL.names and IRL.names[color]) or marbleColorName(color)) or personName(color) or marbleColorName(color)
    return who .. "'s marble"
end
function moveDescription(S, act, chat)
    if not (S and act and act.steps and act.steps[1]) then return "" end
    local colors = PLAYER_COLORS[Global.getVar("num_players")] or {}
    local function owner(mi) local m = S.marbles[mi]; return ownerWord(colors[m.seat], chat) end
    local bonks = {}
    for _, b in ipairs(act.bumpList or {}) do
        local z = S.marbles[b.idx]
        if z then bonks[#bonks + 1] = owner(b.idx) end
    end
    local tail = #bonks > 0 and (" (bonks " .. table.concat(bonks, " and ") .. ")") or ""
    if act.card == '$' then
        local tgt = act.bumpList and act.bumpList[1] and act.bumpList[1].idx
        if tgt then return owner(act.steps[1].mi) .. " jumps onto " .. owner(tgt) .. " (Joker)" end
    end
    local cur, parts, sizes = {}, {}, {}
    for _, st in ipairs(act.steps) do
        local m = cur[st.mi] or S.marbles[st.mi]
        local txt, n
        if m.kind == 'S' then
            txt = "comes out"
        elseif m.kind == 'R' and st.kind == 'R' then
            if act.card == '8' then txt, n = "8 back", 8
            else n = (st.p - m.p) % S.R; txt = tostring(n) end
        elseif m.kind == 'R' and st.kind == 'G' then
            n = JokerBot.distToEntrance(S, m.seat, m.p) + st.p
            txt = n .. " into the finish"
        else
            n = st.p - m.p
            txt = n .. " in the finish"
        end
        parts[#parts + 1] = owner(st.mi) .. " " .. txt
        if n then sizes[#sizes + 1] = tostring(n) end
        cur[st.mi] = { seat = m.seat, kind = st.kind, p = st.p }
    end
    local split = ""
    if act.card == '7' and #act.steps > 1 then split = " (7 split " .. table.concat(sizes, " + ") .. ")" end
    return table.concat(parts, " + ") .. split .. tail
end
