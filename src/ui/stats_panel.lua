-- ui/stats_panel.lua  (Global script)
-- The post-game stats screen (opens by itself a few seconds after a team wins; mid-game the host can open it with
-- !stats) and the buttons of the top-left panel: Pause/Resume and Undo during a game, Stats once it's over, and
-- Deal to 6.

------------------------------------------------------------------------
local function esc(s)
    s = tostring(s)
    return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

-- plain display name (playerLabel adds chat colour codes for bots, which XML can't show)
local function statsName(color)
    if botIsBot(color) then return botName(color) end
    if irlIsSeat and irlIsSeat(color) then return (IRL.names and IRL.names[color]) or marbleColorName(color) end   -- hybrid
    local p = Player[color]
    if p and p.steam_name and p.steam_name ~= "" then return p.steam_name end
    return marbleColorName(color)
end

local NAME_W, CARD_W, NUM_W, AWARD_W = 130, 30, 58, 260

-- 3725 -> "1:02:05", 125 -> "2:05"
function statsClock(secs)
    secs = math.max(0, math.floor(tonumber(secs) or 0))
    local h, m, sec = math.floor(secs / 3600), math.floor(secs % 3600 / 60), secs % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
    return string.format("%d:%02d", m, sec)
end
-- time of play so far (or of the whole game once it is won)
function statsGameTime()
    if not (GAME_STATS and GAME_STATS.started) then return 0 end
    return (GAME_STATS.ended or os.time()) - GAME_STATS.started
end
local TEAM_BG = { "#1F3F6ACC", "#6A1F1FCC" }

local function cell(text, color, bold)
    return string.format('<Cell><Text fontSize="13" color="%s"%s alignment="MiddleCenter">%s</Text></Cell>',
        color or "#FFFFFF", bold and ' fontStyle="Bold"' or "", esc(text))
end

-- awards can be a long list (several awards per player): wrap onto two lines and shrink the text to fit the cell
local function awardCell(text)
    return string.format('<Cell><Text fontSize="12" color="#FFE9A8" alignment="MiddleCenter" horizontalOverflow="Wrap"'
        .. ' resizeTextForBestFit="true" resizeTextMinSize="8" resizeTextMaxSize="12">%s</Text></Cell>', esc(text))
end

local function columnWidths(lastCols)
    local w = { NAME_W }
    for _ = 1, #STATS_CARDS do w[#w + 1] = CARD_W end
    for _, x in ipairs(lastCols) do w[#w + 1] = x end
    return table.concat(w, " ")
end

local function headerRow(first, extra)
    local r = '<Row preferredHeight="26">' .. cell(first, "#FFD84D", true)
    for _, l in ipairs(STATS_CARD_LABELS) do r = r .. cell(l, "#FFD84D", true) end
    for _, l in ipairs(extra) do r = r .. cell(l, "#FFD84D", true) end
    return r .. '</Row>'
end

function statsPanelXml()
    if not GAME_STATS then return "" end
    local N = GAME_STATS.num_players
    local colors = PLAYER_COLORS[N]
    local awards = statsAwards()
    local playerCols = { NUM_W, NUM_W, NUM_W, NUM_W, NUM_W, NUM_W, NUM_W, NUM_W, NUM_W, AWARD_W }
    local width = NAME_W + #STATS_CARDS * CARD_W + 9 * NUM_W + AWARD_W + 40

    local x = {}
    x[#x + 1] = string.format('<Panel id="statsPanel" width="%d" height="%d" color="#000000E6" padding="15 15 10 10" rectAlignment="MiddleCenter">',
        width, 170 + 34 * N + 26 * 3 + 86)
    x[#x + 1] = '<VerticalLayout spacing="6" childForceExpandHeight="false">'
    x[#x + 1] = string.format('<Text fontSize="26" fontStyle="Bold" color="#FFD84D" preferredHeight="36">Post Game Stats   -   time of play %s</Text>', statsClock(statsGameTime()))

    -- players
    x[#x + 1] = string.format('<TableLayout columnWidths="%s" preferredHeight="%d" autoCalculateHeight="false" cellBackgroundColor="clear">',
        columnWidths(playerCols), 26 + 34 * N)      -- header 26 + player rows 34 (awards can wrap to 2 lines)
    x[#x + 1] = headerRow("Player", { "Burned", "Tm Bop", "En Bop", "By Tm", "By En", "Distance", "Finished", "Time", "Avg", "Awards" })
    for seat, color in ipairs(colors) do
        local ps = statsPlayer(color)
        local r = string.format('<Row preferredHeight="34" color="%s">', TEAM_BG[seat % 2 == 1 and 1 or 2])
        r = r .. cell(statsName(color), "#" .. colorHex(nameColorOnDark(color)), true)
        for i = 1, #STATS_CARDS do r = r .. cell(ps.cards[i]) end
        r = r .. cell(ps.burned) .. cell(ps.teammatesBopped) .. cell(ps.enemiesBopped)
                .. cell(ps.boppedByTeammate) .. cell(ps.boppedByEnemy) .. cell(tonumber(ps.distance) or 0)
                .. cell(statsNum(ps.turnFinished, "turnFinished for " .. color) > 0 and ps.turnFinished or "-")
                .. cell(statsClock(ps.time)) .. cell((tonumber(ps.turns) or 0) > 0 and statsClock(ps.time / ps.turns) or "-")
                .. awardCell(table.concat(statsPickAwards(color, awards[color]), ", "))
        x[#x + 1] = r .. '</Row>'
    end
    x[#x + 1] = '</TableLayout>'

    -- teams
    x[#x + 1] = string.format('<TableLayout columnWidths="%s" preferredHeight="%d" autoCalculateHeight="false" cellBackgroundColor="clear">',
        columnWidths({ NUM_W, NUM_W, NUM_W, NUM_W, NUM_W, NUM_W }), 26 * 3)
    x[#x + 1] = headerRow("Team", { "Burned", "Tm Bop", "En Bop", "Distance", "Last Fin", "Result" })
    for team = 1, 2 do
        local t = statsTeamTotals(team)
        local r = string.format('<Row preferredHeight="26" color="%s">', TEAM_BG[team])
        r = r .. cell("Team " .. team, "#FFFFFF", true)
        for i = 1, #STATS_CARDS do r = r .. cell(t.cards[i]) end
        local result, rc = "-", "#FFFFFF"
        if GAME_STATS.winner == team then result, rc = "WINNER", "#5CFF5C"
        elseif GAME_STATS.winner ~= 0 then result, rc = "LOSER", "#FF5C5C" end
        r = r .. cell(t.burned) .. cell(t.teammatesBopped) .. cell(t.enemiesBopped) .. cell(t.distance or 0)
                .. cell(t.lastFinished > 0 and t.lastFinished or "-") .. cell(result, rc, true)
        x[#x + 1] = r .. '</Row>'
    end
    x[#x + 1] = '</TableLayout>'

    -- the key lines and the Close button sit in the middle of the space left at the bottom (user)
    x[#x + 1] = '<VerticalLayout flexibleHeight="1" childAlignment="MiddleCenter" childForceExpandHeight="false" spacing="6">'
    x[#x + 1] = string.format('<Text fontSize="12" color="#BBBBBB" preferredHeight="18">Turn %d, time of play %s. Time / Avg = time spent on own turns, in total / per turn. Tm Bop / En Bop = teammates / enemies this player bopped; By Tm / By En = times bopped by them.</Text>', GAME_STATS.turn, statsClock(statsGameTime()))
    x[#x + 1] = '<Text fontSize="11" color="#BBBBBB" preferredHeight="30" horizontalOverflow="Wrap">Marathon Runner / Couch Potato = moved the most / least. Speed Demon = biggest single turn. Hitchhiker = most cells gained from catapults. Heartbreaker = bonked the marble that had come furthest. Wild Card / Lucky Sevens / Moonwalker = most Jokers / 7s / 8s played. Cold Streak = most burns in a row.</Text>'
    -- a third of the panel's content width, centred (user)
    x[#x + 1] = string.format('<HorizontalLayout preferredHeight="34" minHeight="34" flexibleHeight="0" childAlignment="MiddleCenter" childForceExpandWidth="false" childForceExpandHeight="false">'
        .. '<Button onClick="statsClose" preferredHeight="34" minHeight="34" flexibleHeight="0" preferredWidth="%d" fontSize="16">Close</Button></HorizontalLayout>',
        math.floor((width - 30) / 3))
    x[#x + 1] = '</VerticalLayout>'
    x[#x + 1] = '</VerticalLayout></Panel>'
    return table.concat(x, "\n")
end

-- "Stats" button for the top-left panel (only once a game has started)
function statsButtonXml()
    if not GAME_STATS then return "" end
    -- Stats and "Deal to 6" (turns.lua dealToSix) share one row, so the panel height stays the same
    -- during the game: Undo (undo.lua) in place of Stats, plus Resume while paused; Stats once the game is over
    local first
    if GAME_STATS.winner ~= 0 or not undoClicked then
        first = '<Button id="statsBtn" onClick="statsToggle" fontSize="16" text="Stats"/>'
    else
        first = ((TURN_STATE and TURN_STATE.paused) and '<Button id="resumeBtn" onClick="undoResume" fontSize="16" text="Resume"/>'
                 or '<Button id="pauseBtn" onClick="undoPause" fontSize="16" text="Pause"/>')
            .. '<Button id="undoBtn" visibility="Host" onClick="undoClicked" fontSize="16" text="Undo"/>'
    end
    return '<HorizontalLayout spacing="4" preferredHeight="32">' .. first
        .. '<Button id="dealBtn" onClick="dealToSix" fontSize="16" text="Deal to 6"/>'
        .. '</HorizontalLayout>'
end

STATS_OPEN_DELAY = 3      -- seconds after the win before the stats screen opens
function statsOpen()  UI_STATE.stats = true;  refreshGameUI() end
function statsClose() UI_STATE.stats = false; refreshGameUI() end
function statsToggle() if UI_STATE.stats then statsClose() else statsOpen() end end
