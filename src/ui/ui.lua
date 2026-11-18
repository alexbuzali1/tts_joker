-- ui/ui.lua  (Global script)
-- The on-screen UI is ONE XML document for everybody, rebuilt from scratch by refreshGameUI() whenever something
-- shown changes. Each part is a function returning its XML (or ""), and parts only one player should see use
-- TTS's visibility="<colour>" (or "Host"). Rebuilding everything keeps the parts from getting out of step - the
-- original colour picker appended panels and tried to hide them again, and some never went away.
--   colour pickers         ui/color_picker.lua     before the game (or !picker on)
--   bot panel + buttons    bot/panel.lua, ui/stats_panel.lua   top left
--   whose turn             ui/turn_ui.lua          banner, END TURN, splash
--   easy play              play/easy_play.lua      toggles bottom right, prompt / chooser bottom centre
--   in-person card bar     play/hybrid.lua         the host's, on in-person seats' turns
--   stats screen           ui/stats_panel.lua      after the game (or !stats)
--   settings gear + menu   ui/settings.lua         top right, the host's
--   "?" + how to play      ui/tutorial.lua         top right, everyone
--   turn timer border      game/turn_timer.lua     the edge of the player's screen on their turn

UI_STATE = UI_STATE or { picker = false, stats = false }

function refreshGameUI()
    local xml = ""
    if UI_STATE.picker then xml = xml .. colorPickerXml() end
    xml = xml .. botPanelXml()
    xml = xml .. turnUiXml()
    xml = xml .. easyUiXml()
    xml = xml .. irlUiXml()
    if UI_STATE.stats then xml = xml .. statsPanelXml() end
    xml = xml .. turnTimerXml()                       -- the turn timer's border (game/turn_timer.lua), under the menus
    xml = xml .. settingsGearXml() .. tutorialButtonXml() .. settingsXml() .. tutorialXml()
    UI.setXml(xml)
end

-- & < > " made safe for XML text and attributes
function xmlEscape(s)
    if s == nil then return "" end
    return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end
