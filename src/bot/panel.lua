-- bot/panel.lua  (Global script)
-- The panel at the top left: which seats are bots, what the bot is doing, and the Pause / Undo / Stats / Deal to 6
-- buttons (game/stats.lua statsButtonXml). With !dev on it also shows the bot settings and the "Flag bad move" box.
-- The settings themselves are normally the host's chat commands (host/commands.lua).

------------------------------------------------------------------------
function botPanelXml()
    local stats_btn = statsButtonXml() or ""
    if not BOT_STATE.active then
        -- no bots: the panel only holds the Stats button (once a game has started)
        if stats_btn == "" then return "" end
        return [[
<Panel id="botPanel" rectAlignment="UpperLeft" offsetXY="55 -60" width="220" height="48" color="#000000B0" padding="8 8 8 8">
  <VerticalLayout spacing="4">]] .. stats_btn .. [[</VerticalLayout>
</Panel>]]
    end
    local names = {}
    for color, _ in pairs(BOT_STATE.seats) do table.insert(names, color) end
    table.sort(names)
    -- each bot's name in its marble colour (TTS XML rich-text tag <textcolor>)
    local colored = {}
    for i, color in ipairs(names) do
        colored[i] = string.format('<textcolor color="#%s">%s</textcolor>', colorHex(nameColorOnDark(color)), xmlEscape(marbleColorName(color)))
    end
    -- the title wraps with many bots (6- and 8-player games): about 22 characters fit on a line
    local plain = {}
    for i, color in ipairs(names) do plain[i] = marbleColorName(color) end
    local lines = math.max(1, math.ceil(#("Bots: " .. table.concat(plain, ", ")) / 22))
    local title_h = 26 * lines
    local title_extra = title_h - 26
    local controls, controls_h = "", 0
    if BOT_DEV_UI then
        controls = string.format([[
    <Button id="botSpeedBtn" onClick="botCycleSpeed" fontSize="16" preferredHeight="32" text="Bot speed: %s"/>
    <HorizontalLayout spacing="4" preferredHeight="32">
      <Button onClick="botDifficultyDown" fontSize="18" preferredWidth="40" text="-"/>
      <Text id="botDifficultyText" fontSize="16" color="#FFFFFF" preferredWidth="176" text="%s"/>
      <Button onClick="botDifficultyUp" fontSize="18" preferredWidth="40" text="+"/>
    </HorizontalLayout>
    <HorizontalLayout spacing="4" preferredHeight="32">
      <Button onClick="botThinkDown" fontSize="18" preferredWidth="40" text="-"/>
      <Text id="botThinkText" fontSize="16" color="#FFFFFF" preferredWidth="176" text="%s"/>
      <Button onClick="botThinkUp" fontSize="18" preferredWidth="40" text="+"/>
    </HorizontalLayout>
    %s]], botSpeed().name, botDifficultyLabel(), botThinkLabel(), flagPanelXml())
        controls_h = 200
    end
    return string.format([[
<Panel id="botPanel" rectAlignment="UpperLeft" offsetXY="55 -60" width="280" height="%d" color="#000000B0" padding="8 8 8 8">
  <VerticalLayout spacing="4">
    <Text id="botTitle" fontSize="20" color="#FFD84D" fontStyle="Bold" preferredHeight="%d">Bots: %s</Text>
    <Text id="botStatus" fontSize="16" color="%s" text="%s"/>
    %s
    %s
  </VerticalLayout>
</Panel>]], (stats_btn ~= "" and 36 or 0) + 30 + 16 + controls_h + title_h, title_h, table.concat(colored, ", "), BOT_STATE.status_color or "#FFFFFF",
        xmlEscape(BOT_STATE.status), controls, stats_btn)
end

function botCycleSpeed(player, value, id)
    BOT_STATE.speed_index = (BOT_STATE.speed_index % #BOT_SPEEDS) + 1
    if BOT_DEV_UI then UI.setAttribute("botSpeedBtn", "text", "Bot speed: " .. botSpeed().name) end
    botHostMsg("Bot speed: " .. botSpeed().name)
end

-- difficulty (1-9) and think time (seconds of search per move), changed with the panel's - / + buttons
function botDifficultyLabel() return "Difficulty: " .. BOT_DIFFICULTY .. " / 10" end
function botThinkLabel() return string.format("Think time: %.1f s", BOT_THINK_TIME) end

function botSetDifficulty(d)
    BOT_DIFFICULTY = math.max(1, math.min(10, d))
    if BOT_DEV_UI then UI.setAttribute("botDifficultyText", "text", botDifficultyLabel()) end
    botHostMsg("Bot difficulty: " .. BOT_DIFFICULTY .. " / 10" .. (BOT_DIFFICULTY >= 10 and " (engine: deep search, card counting)" or ""))
end
function botSetThink(t)
    BOT_THINK_TIME = math.max(0.5, math.min(60, t))
    if BOT_DEV_UI then UI.setAttribute("botThinkText", "text", botThinkLabel()) end
    botHostMsg(string.format("Bot think time: %.1f s", BOT_THINK_TIME))
end
function botDifficultyDown() botSetDifficulty(BOT_DIFFICULTY - 1) end
function botDifficultyUp() botSetDifficulty(BOT_DIFFICULTY + 1) end
function botThinkDown() botSetThink(BOT_THINK_TIME - 0.5) end
function botThinkUp() botSetThink(BOT_THINK_TIME + 0.5) end

-- the "Flag bad move" box (only with !dev on; normally the host types !flag)
function flagPanelXml()
    if not BOT_STATE.active then return "" end
    return [[
    <InputField id="flagNote" onValueChanged="flagNoteChanged" placeholder="What was wrong? (optional)" fontSize="14" preferredHeight="30"/>
    <Button id="flagBtn" onClick="flagBadMove" fontSize="16" preferredHeight="32" text="Flag bad move" textColor="#B00000"/>]]
end
