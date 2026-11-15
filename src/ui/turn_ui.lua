-- ui/turn_ui.lua  (Global script)
-- Showing whose turn it is:
--   * a banner at the top centre: "<name>'s turn" in their marble colour (always visible during a game)
--   * an END TURN button at the bottom right, only for the player whose turn it is (hidden for players with easy
--     play on, whose turns end by themselves; the host's on an in-person seat's turn)
--   * a splash in the middle of the screen at every turn change: "YOUR TURN!" for that player, "<name>'s turn" for
--     everyone else; it fades out after TURN_SPLASH_TIME seconds
--   * the Turn Button on the table: its label says whose turn it is, and clicking it ends the turn
--   * the seat's board and play zone glow green, and the play zones are named after who plays there
-- All of this is rebuilt with the rest of the UI by refreshGameUI (ui/ui.lua).

TURN_BUTTON_SIZE = { w = 1300, h = 440, font = 120 }   -- the Turn Button on the table (was 700 x 300, font 100)
TURN_SPLASH_TIME = 1.6
TURN_UI = TURN_UI or { text = nil, hex = "#FFFFFF", color = nil, human = false, splash = 0 }

local function othersThan(color)
    local out = {}
    for _, c in ipairs(BOT_ALL_COLORS or {}) do if c ~= color then out[#out + 1] = c end end
    return table.concat(out, "|")
end

function turnUiXml()
    if not TURN_UI.text then return "" end
    local xml = string.format([[
<Panel id="turnBanner" rectAlignment="UpperCenter" offsetXY="0 -36" width="620" height="70" color="#000000D0">
  <Text id="turnBannerText" fontSize="40" fontStyle="Bold" color="%s" outline="#000000" outlineSize="2 2" text="%s"/>
</Panel>]], TURN_UI.hex, xmlEscape(TURN_UI.text))
    if TURN_UI.human and TURN_UI.color and not (EASY and EASY.on[TURN_UI.color]) then   -- easy play: the turn ends by itself
        xml = xml .. string.format([[
<Button id="turnEndBtn" visibility="%s" onClick="turnEndTurnUI" rectAlignment="LowerRight" offsetXY="-20 40"
        width="320" height="76" fontSize="34" fontStyle="Bold" textColor="#FFFFFF" color="#1F8F3A">END TURN</Button>]],
            (irlIsSeat(TURN_UI.color)) and "Host" or TURN_UI.color)     -- in person: the host ends it
    end
    if TURN_UI.splash_text then
        local who = TURN_UI.color or ""
        xml = xml .. string.format([[
<Panel id="turnSplash" active="false" width="1000" height="190" color="#000000B0" showAnimation="Grow" hideAnimation="FadeOut" animationDuration="0.25">
  <Text visibility="%s" fontSize="84" fontStyle="Bold" color="%s" outline="#000000" outlineSize="3 3" text="%s"/>
  %s
</Panel>]], othersThan(who), TURN_UI.hex, xmlEscape(TURN_UI.splash_text),
            TURN_UI.human and string.format('<Text visibility="%s" fontSize="96" fontStyle="Bold" color="%s" outline="#000000" outlineSize="3 3" text="YOUR TURN!"/>', who, TURN_UI.hex) or "")
    end
    return xml
end

-- the on-screen END TURN button: same as clicking the Turn Button
function turnEndTurnUI(player)
    if player and player.color then endTurnClicked(nil, player.color, false) end
end

-- show whose turn it is: banner + splash. color = the seat's colour, or nil with text for e.g. game over.
function turnShowTurn(color, text, hex, human)
    TURN_UI.color, TURN_UI.text, TURN_UI.human = color, text, human and true or false
    TURN_UI.hex = hex or (color and ("#" .. colorHex(nameColorOnDark(color)))) or "#FFFFFF"
    TURN_UI.splash_text = text
    TURN_UI.splash = (TURN_UI.splash or 0) + 1
    local token = TURN_UI.splash
    refreshGameUI()
    -- the rebuilt UI exists a moment later; then grow the splash in and fade it out
    Wait.time(function()
        if TURN_UI.splash ~= token then return end
        pcall(function() UI.show("turnSplash") end)
        Wait.time(function()
            if TURN_UI.splash == token then pcall(function() UI.hide("turnSplash") end) end
        end, TURN_SPLASH_TIME)
    end, 0.25)
end

-- The Turn Button's label (and tooltip). font_color: a bot's marble colour on bot turns, black otherwise.
function turnButtonLabel(label, tooltip, font_color)
    local chip = getObjectFromGUID(TURN_BUTTON_GUID)
    if chip and chip.getButtons() then
        chip.editButton({ index = 0, label = label, tooltip = tooltip or "", font_color = font_color or { 0, 0, 0 },
                          width = TURN_BUTTON_SIZE.w, height = TURN_BUTTON_SIZE.h, font_size = TURN_BUTTON_SIZE.font })
    end
end

-- The seat's board piece and play zone glow green while it's their turn.
function turnHighlight(color, on)
    local board = Global.getTable("boards_by_player")[color]
    local pile = Global.getTable("discard_piles")[color]
    if on then
        if board then board.highlightOn(Color.fromString('Green')) end
        if pile then pile.highlightOn(Color.fromString('Green')) end
    else
        if board then board.highlightOff() end
        if pile then pile.highlightOff() end
    end
end


-- Rename the play zones (hover text) after who plays there: "BOT (Blue)'s Play Zone" / "Alice's Play Zone".
-- The original names use the seat colour, which isn't the marble colour. Only the visible name changes; the
-- "<Seat>_DiscardPile" scripting zones that recognise plays keep their names.
function turnNamePlayZones()
    local piles = Global.getTable("discard_piles")
    if not piles then return end
    for _, color in ipairs(turnColors()) do
        local pile = piles[color]
        if pile then
            local who
            if botIsBot(color) then who = botName(color)
            else
                local p = Player[color]
                who = (p and p.steam_name and p.steam_name ~= "") and p.steam_name or marbleColorName(color)
            end
            pile.setName(who .. "'s Play Zone")
        end
    end
end

-- A player picked a new marble colour: everything named after marble colours (bot names, play zones, the bot
-- panel, the Turn Button during a bot's turn) is renamed. Batched, since the picker tints 5 marbles at once.
TURN_RENAME_PENDING = false
function turnRefreshNames()
    if TURN_RENAME_PENDING then return end
    TURN_RENAME_PENDING = true
    Wait.time(function()
        TURN_RENAME_PENDING = false
        pcall(turnNamePlayZones)
        if refreshGameUI then pcall(refreshGameUI) end
        local cur = BOT_STATE and BOT_STATE.current
        if cur and cur.color and not cur.finished then
            pcall(turnButtonLabel, botName(cur.color) .. "'s\nTurn",
                "Bot stuck? Host: click twice to skip its turn, right-click to make it rethink its move.",
                nameColorOnLight(cur.color))
        end
    end, 0.3)
end

