-- ui/color_picker.lua  (Global script)
-- The marble colour picker, shown before a game starts (and mid-game with the host's !picker on). Every seated
-- player gets their own panel, which only they see:
--   * a colour square for the hue on the slider below it: saturation (PICK_SAT_MIN..1) left to right, brightness
--     (1..PICK_VAL_MIN) top to bottom - the muddy dark / grey colours are left out of it
--   * a white ... black row
--   * a hue slider with a rainbow strip above it, and a preview swatch
--   * Solid / See-through (PICK_TRANSLUCENT opaque, with a black outline)
--   * effects: Plain, Pulse (brightness breathes), Twinkle (each marble flickers)
--   * the HOST's panel also has a tab per in-person seat (hybrid mode, play/hybrid.lua) to colour and name it
-- The style is kept per seat in MARBLE_STYLE (saved with the game, game/save.lua) and an effect keeps running
-- during the game. Names ("Red", "Magenta"...) use the picked base colour, not the animated tint (ui/names.lua).
-- The button scripts open / close it with Global.call("showColorPickers") / Global.call("hideColorPickers").

MARBLE_STYLE = MARBLE_STYLE or {}      -- [seat colour] = { h = 0-360, s = 0-1, v = 0-1, see = bool, fx = "plain"|... }
PICK_COLS, PICK_ROWS = 8, 6
PICK_SAT_MIN, PICK_VAL_MIN = 0.2, 0.4  -- no muddy greys or near-blacks in the square (user); see the neutral row
PICK_NEUTRALS = 6                      -- white ... black, under the square
PICK_TRANSLUCENT = 0.69                -- see-through marbles: 69% opaque (user: 80% barely see-through, 50% too faint)
PICK_OUTLINE = { r = 0, g = 0, b = 0 } -- see-through marbles get a black outline (user) so they stand out
PICK_FX = { { "plain", "Plain" }, { "pulse", "Pulse" }, { "twinkle", "Twinkle" } }   -- (Rainbow dropped: confusing)
PICK_HUE = PICK_HUE or {}              -- [seat colour] = hue on that player's slider (not applied until a square is clicked)

function hsvToRgb(h, s, v)
    h = (h % 360) / 60
    local i = math.floor(h)
    local f = h - i
    local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    local r, g, b
    if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
    return { r = r, g = g, b = b }
end

local function hex(c) return string.format("#%02X%02X%02X", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5)) end

local function cellSV(col, row)
    return PICK_SAT_MIN + (1 - PICK_SAT_MIN) * col / (PICK_COLS - 1),
           1 - (1 - PICK_VAL_MIN) * row / (PICK_ROWS - 1)
end
local function neutralV(k) return 1 - k / (PICK_NEUTRALS - 1) end

local function pickerSeats()
    local out = {}
    for _, c in ipairs(PLAYER_COLORS and PLAYER_COLORS[Global.getVar("num_players")] or {}) do
        if not (botIsBot(c)) then out[#out + 1] = c end
    end
    return out
end

-- the picked base colour of a seat (nil = never picked)
function marbleStyleColor(color)
    local st = MARBLE_STYLE[color]
    if not st then return nil end
    return hsvToRgb(st.h, st.s, st.v)
end

-- The host can also colour and name the in-person seats (play/hybrid.lua; user): their picker has a tab per seat.
-- Seats: the host's own, the in-person ones, and before a game with "!async on" every empty seat.
PICK_TARGET = PICK_TARGET or {}          -- [viewer colour] = the seat that viewer's picker is colouring
local function isHost(c) local p = Player[c]; return p and p.host end
function pickTargets(viewer)
    local out = { viewer }
    if not isHost(viewer) then return out end
    for _, c in ipairs(PLAYER_COLORS and PLAYER_COLORS[Global.getVar("num_players")] or {}) do
        if c ~= viewer and not (botIsBot(c)) and not (Player[c] and Player[c].seated)
           and ((irlIsSeat(c)) or (IRL and IRL.mode)) then
            out[#out + 1] = c
        end
    end
    return out
end
function pickTarget(viewer)
    local t = PICK_TARGET[viewer]
    for _, c in ipairs(pickTargets(viewer)) do if c == t then return t end end
    return viewer
end
local function seatName(c) return (IRL and IRL.names and IRL.names[c]) or (marbleColorName(c)) or c end

local function onePickerXml(c)
    local tgt = pickTarget(c)
    local targets = pickTargets(c)
    local st = MARBLE_STYLE[tgt] or {}
    local hue = PICK_HUE[c] or st.h or 0
    local x = {}
    local extra = (#targets > 1 and 40 or 0) + (tgt ~= c and 40 or 0)
    x[#x + 1] = string.format('<Panel id="pick_%s" visibility="%s" position="500 -250" width="400" height="%d" color="#000000D8" padding="12 12 10 10">'
        .. '<VerticalLayout spacing="6" childForceExpandHeight="false">'
        .. '<Text fontSize="24" fontStyle="Bold" color="#FFFFFF" preferredHeight="32">%s</Text>', c, c, 500 + extra,
        tgt == c and "Pick your marble colour" or xmlEscape("Colour for " .. seatName(tgt) .. " (in person)"))
    if #targets > 1 then                                   -- the host: whose marbles this picker colours
        x[#x + 1] = '<HorizontalLayout spacing="4" preferredHeight="34">'
        for _, t in ipairs(targets) do
            x[#x + 1] = string.format('<Button id="pickTo_%s_%s" onClick="pickerTarget" fontSize="15" color="%s">%s</Button>',
                c, t, t == tgt and "#E8C547" or "#777777", t == c and "You" or xmlEscape(seatName(t)))
        end
        x[#x + 1] = '</HorizontalLayout>'
    end
    if tgt ~= c then                                       -- an in-person seat: its name
        x[#x + 1] = string.format('<InputField id="pickName_%s" onEndEdit="pickerName" fontSize="17" preferredHeight="34" placeholder="Name (e.g. Pat)" text="%s"/>',
            c, xmlEscape(IRL and IRL.names and IRL.names[tgt] or ""))
    end
    -- the colour square
    x[#x + 1] = '<VerticalLayout spacing="0" preferredHeight="200">'
    for row = 0, PICK_ROWS - 1 do
        x[#x + 1] = '<HorizontalLayout spacing="0">'
        for col = 0, PICK_COLS - 1 do
            local sat, val = cellSV(col, row)
            x[#x + 1] = string.format('<Button id="sv_%s_%d_%d" onClick="colorChosen" color="%s" colors="%s|#FFFFFF|#FFFFFF|%s"/>',
                c, col, row, hex(hsvToRgb(hue, sat, val)), hex(hsvToRgb(hue, sat, val)), hex(hsvToRgb(hue, sat, val)))
        end
        x[#x + 1] = '</HorizontalLayout>'
    end
    x[#x + 1] = '</VerticalLayout>'
    -- white to black (the same whatever the hue)
    x[#x + 1] = '<HorizontalLayout spacing="2" preferredHeight="26">'
    for k = 0, PICK_NEUTRALS - 1 do
        local h = hex(hsvToRgb(0, 0, neutralV(k)))
        x[#x + 1] = string.format('<Button id="nv_%s_%d" onClick="colorChosen" color="%s" colors="%s|#E8C547|#E8C547|%s"/>', c, k, h, h, h)
    end
    x[#x + 1] = '</HorizontalLayout>'
    -- rainbow strip + hue slider
    x[#x + 1] = '<HorizontalLayout spacing="0" preferredHeight="12">'
    for k = 0, 23 do x[#x + 1] = string.format('<Panel color="%s"/>', hex(hsvToRgb(k * 15, 1, 1))) end
    x[#x + 1] = '</HorizontalLayout>'
    x[#x + 1] = string.format('<Slider id="hue_%s" minValue="0" maxValue="359" value="%d" onValueChanged="pickerHue" preferredHeight="24"/>', c, math.floor(hue))
    -- preview + solid / see-through
    local cur = marbleStyleColor(tgt) or (marbleColorOf(tgt)) or { r = 1, g = 1, b = 1 }
    x[#x + 1] = string.format('<HorizontalLayout spacing="8" preferredHeight="40">'
        .. '<Panel id="pickPrev_%s" color="%s" preferredWidth="70"/>'
        .. '<Button id="pickSolid_%s" onClick="pickerSee" fontSize="17" color="%s">Solid</Button>'
        .. '<Button id="pickSee_%s" onClick="pickerSee" fontSize="17" color="%s">See-through</Button></HorizontalLayout>',
        c, hex(cur), c, st.see and "#777777" or "#E8C547", c, st.see and "#E8C547" or "#777777")
    -- effects
    x[#x + 1] = '<HorizontalLayout spacing="6" preferredHeight="40">'
    for _, fx in ipairs(PICK_FX) do
        x[#x + 1] = string.format('<Button id="pickFx_%s_%s" onClick="pickerFx" fontSize="16" color="%s">%s</Button>',
            c, fx[1], (st.fx or "plain") == fx[1] and "#E8C547" or "#777777", fx[2])
    end
    x[#x + 1] = '</HorizontalLayout></VerticalLayout></Panel>'
    return table.concat(x)
end

function colorPickerXml()
    local x = {}
    for _, c in ipairs(pickerSeats()) do x[#x + 1] = onePickerXml(c) end
    return table.concat(x, "\n")
end

function showColorPickers()
    marbleStylesReset()                  -- fresh marbles in the standard colours
    UI_STATE.picker = true
    refreshGameUI()
end

function hideColorPickers()
    UI_STATE.picker = false
    refreshGameUI()
end

-- a square in the colour grid: that colour, at the hue on the slider
function colorChosen(player, value, id)
    id = tostring(id or "")
    local c, col, row = id:match("^sv_(%a+)_(%d+)_(%d+)$")
    local sat, val
    if c then
        sat, val = cellSV(tonumber(col), tonumber(row))
    else
        local k
        c, k = id:match("^nv_(%a+)_(%d+)$")                 -- the white ... black row
        if not c then return end
        sat, val = 0, neutralV(tonumber(k))
    end
    if not player or player.color ~= c then return end
    local tgt = pickTarget(c)                               -- the host may be colouring an in-person seat
    local team_marbles = Global.getTable("marbles_by_player")[tgt]
    if not team_marbles then return end   -- spectators / colours without marbles
    local st = MARBLE_STYLE[tgt] or { see = false, fx = "plain" }
    st.h, st.s, st.v = PICK_HUE[c] or st.h or 0, sat, val
    MARBLE_STYLE[tgt] = st
    marbleApplyStyle(tgt)
    pcall(function() UI.setAttribute("pickPrev_" .. c, "color", hex(hsvToRgb(st.h, st.s, st.v))) end)
    turnRefreshNames()
end

-- the hue slider: recolour that player's square (batched: the slider fires on every step of a drag)
function pickerHue(player, value, id)
    local c = tostring(id or ""):match("^hue_(%a+)$")
    if not c or not player or player.color ~= c then return end
    PICK_HUE[c] = tonumber(value) or 0
    if PICK_PENDING and PICK_PENDING[c] then return end
    PICK_PENDING = PICK_PENDING or {}
    PICK_PENDING[c] = true
    Wait.time(function()
        PICK_PENDING[c] = nil
        local hue = PICK_HUE[c] or 0
        for col = 0, PICK_COLS - 1 do
            for row = 0, PICK_ROWS - 1 do
                local sat, val = cellSV(col, row)
                local h = hex(hsvToRgb(hue, sat, val))
                pcall(function()
                    UI.setAttribute(string.format("sv_%s_%d_%d", c, col, row), "color", h)
                    UI.setAttribute(string.format("sv_%s_%d_%d", c, col, row), "colors", h .. "|#FFFFFF|#FFFFFF|" .. h)
                end)
            end
        end
    end, 0.1)
end

function pickerSee(player, value, id)
    local which, c = tostring(id or ""):match("^pick(%a+)_(%a+)$")
    if not c or not player or player.color ~= c then return end
    c = pickTarget(c)
    local st = MARBLE_STYLE[c]
    if not st then
        local cur = marbleColorOf(c)
        st = rgbStyle(cur)
        MARBLE_STYLE[c] = st
    end
    st.see = (which == "See")
    marbleApplyStyle(c)
    refreshGameUI()
end

function pickerFx(player, value, id)
    local c, fx = tostring(id or ""):match("^pickFx_(%a+)_(%a+)$")
    if not c or not player or player.color ~= c then return end
    c = pickTarget(c)
    local st = MARBLE_STYLE[c]
    if not st then st = rgbStyle(marbleColorOf(c)); MARBLE_STYLE[c] = st end
    st.fx = fx
    marbleApplyStyle(c)
    refreshGameUI()
end

-- the host's seat tabs
function pickerTarget(player, value, id)
    local c, t = tostring(id or ""):match("^pickTo_(%a+)_(%a+)$")
    if not c or not player or player.color ~= c then return end
    PICK_TARGET[c] = t
    refreshGameUI()
end

-- the host named an in-person seat
function pickerName(player, value, id)
    local c = tostring(id or ""):match("^pickName_(%a+)$")
    if not c or not player or player.color ~= c or not IRL then return end
    local tgt = pickTarget(c)
    if tgt == c then return end
    local name = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    IRL.names[tgt] = name ~= "" and name or nil
    turnRefreshNames()
    refreshGameUI()
end

-- an rgb tint -> a style (hue, saturation, brightness)
function rgbStyle(c)
    local r, g, b = c.r or 1, c.g or 1, c.b or 1
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    local d = mx - mn
    local h = 0
    if d > 0 then
        if mx == r then h = 60 * (((g - b) / d) % 6) elseif mx == g then h = 60 * ((b - r) / d + 2) else h = 60 * ((r - g) / d + 4) end
    end
    return { h = h, s = mx > 0 and d / mx or 0, v = mx, see = false, fx = "plain" }
end

------------------------------------------------------------------------
-- applying a style, and the effects
------------------------------------------------------------------------
local function setTeamTint(color, list)
    local team = (Global.getTable("marbles_by_player") or {})[color]
    for k, m in ipairs(team or {}) do
        local c = list[k] or list[1]
        pcall(function() m.setColorTint(c) end)
    end
end

-- the tint(s) of a seat's marbles right now (t = seconds, for the effects)
function marbleStyleTints(color, t)
    local st = MARBLE_STYLE[color]
    if not st then return nil end
    local a = st.see and PICK_TRANSLUCENT or 1
    local out = {}
    for k = 1, 5 do
        local h, s, v = st.h, st.s, st.v
        if st.fx == "pulse" then
            v = v * (0.55 + 0.45 * (0.5 + 0.5 * math.cos(t * math.pi)))   -- breathes every 2 s
        elseif st.fx == "twinkle" then
            v = v * (0.6 + 0.4 * math.random())
        end
        local c = hsvToRgb(h, s, v)
        c.a = a
        out[k] = c
    end
    return out
end

-- a marble's resting outline: black when its seat's marbles are see-through, else none. Easy play calls this
-- after its own glow so the outline comes back.
function marbleRestoreOutline(obj)
    local owner
    for color, list in pairs(Global.getTable("marbles_by_player") or {}) do
        for _, m in ipairs(list) do if m == obj then owner = color end end
    end
    local st = owner and MARBLE_STYLE[owner]
    pcall(function()
        if st and st.see then obj.highlightOn(PICK_OUTLINE) else obj.highlightOff() end
    end)
end

function marbleApplyStyle(color)
    local tints = marbleStyleTints(color, PICK_T or 0)
    if tints then setTeamTint(color, tints) end
    for _, m in ipairs((Global.getTable("marbles_by_player") or {})[color] or {}) do marbleRestoreOutline(m) end
    pickerStartFx()
end

-- one loop runs every effect (only while some seat has one)
PICK_FX_STEP = 0.25
function pickerStartFx()
    if PICK_FX_RUNNING then return end
    local any = false
    for _, st in pairs(MARBLE_STYLE) do if st.fx and st.fx ~= "plain" then any = true end end
    if not any then return end
    PICK_FX_RUNNING = true
    local function step()
        PICK_T = (PICK_T or 0) + PICK_FX_STEP
        local still = false
        for color, st in pairs(MARBLE_STYLE) do
            if st.fx and st.fx ~= "plain" then
                still = true
                if st.fx ~= "twinkle" or math.random() < 0.5 then
                    setTeamTint(color, marbleStyleTints(color, PICK_T))
                end
            end
        end
        if still then Wait.time(step, PICK_FX_STEP) else PICK_FX_RUNNING = false end
    end
    Wait.time(step, PICK_FX_STEP)
end

-- a new game's marbles start in the standard colours: forget the styles
function marbleStylesReset() MARBLE_STYLE = {}; PICK_HUE = {} end

