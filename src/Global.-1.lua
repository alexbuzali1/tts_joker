-- Global.-1.lua - the Global script of TTS Joker.
--
-- This file is the table of contents: it pulls in every module (lua build.lua resolves the --#include lines into
-- build/Global.-1.lua) and defines each Tabletop Simulator event handler ONCE, handing the event to the modules
-- that care about it. To find where something happens, start from the event here.
--
-- The table itself is set up by the button objects' scripts (setup.lua): the 4/6/8 Player buttons build the board
-- and marbles, Start Game deals and starts the turns. From then on this script runs the game.
-- docs/ARCHITECTURE.md describes how the pieces fit together.

------------------------------------------------------------------------
-- modules (order matters only for the few that read another's tables when they load)
------------------------------------------------------------------------
-- the table (shared with the setup buttons)
--#include "constants.lua"
--#include "helpers.lua"
--#include "cards.lua"
--#include "marbles.lua"
--#include "hover_numbers.lua"

-- the bots' rules and judgement (pure Lua, also run by the tests)
--#include "bot/rules.lua"
--#include "bot/evaluate.lua"
--#include "bot/setups.lua"
--#include "bot/move_costs.lua"
--#include "bot/hand.lua"
--#include "bot/search.lua"
--#include "bot/engine.lua"

-- names, colours and the on-screen UI
--#include "ui/ui.lua"
--#include "ui/names.lua"
--#include "ui/color_picker.lua"
--#include "ui/turn_ui.lua"
--#include "ui/stats_panel.lua"
--#include "ui/settings.lua"
--#include "ui/tutorial.lua"

-- the bots at the table
--#include "bot/players.lua"
--#include "bot/play.lua"
--#include "bot/panel.lua"
--#include "bot/flags.lua"

-- the game
--#include "game/turns.lua"
--#include "game/deck.lua"
--#include "game/cards_played.lua"
--#include "game/marble_moves.lua"
--#include "game/bonks.lua"
--#include "game/hover.lua"
--#include "game/stats.lua"
--#include "game/undo.lua"
--#include "game/save.lua"
--#include "game/turn_timer.lua"

-- ways to play
--#include "play/easy_play.lua"
--#include "play/click_to_play.lua"
--#include "play/hybrid.lua"

-- the host
--#include "host/game_log.lua"
--#include "host/commands.lua"

------------------------------------------------------------------------
-- loading and saving
------------------------------------------------------------------------
function onLoad(saved)
    printToAll('Welcome to Joker!')
    loadGameState(saved)                                 -- a game in progress carries on (game/save.lua)
    uiAssets()                                           -- the gear icon, tutorial images (ui/settings.lua)
    Wait.time(function() pcall(easyCleanup) end, 2)      -- easy play's leftover click targets, if any
    Wait.time(function() pcall(refreshGameUI) end, 1)    -- the settings gear and "?" from the start screen on
end

function onSave()
    return saveGameState()
end

------------------------------------------------------------------------
-- called from the button scripts (setup.lua)
------------------------------------------------------------------------
function setTableShape(params)
    Tables.setTable(params.shape)
end

-- Start Game: a new game counts from zero, with no undo history and no easy-play choice in progress.
function resetForNewGame(params)
    statsReset(params)
    undoReset()
    EASY.session = nil
    turnTimerStop()
    settingsApplyDefaultsAll()          -- easy play / click to play defaults for who hasn't chosen (ui/settings.lua)
end

------------------------------------------------------------------------
-- chat
------------------------------------------------------------------------
function onChat(message, player)
    if hostChatCommand(message, player) then return false end   -- a host "!command": hidden from chat
end

------------------------------------------------------------------------
-- players coming and going
------------------------------------------------------------------------
function onPlayerChangeColor(color)
    turnSeatTaken(color)                -- sat down in a bot's seat: it's theirs (game/turns.lua)
    hybridSeatTaken(color)              -- sat down in an in-person seat: it's theirs (play/hybrid.lua)
    settingsApplyDefaults(color)        -- the host's easy play / click to play defaults (ui/settings.lua)
    pcall(refreshGameUI)
end

function onPlayerConnect(player)
    turnPlayerConnected(player)         -- a reconnect: re-send marble colours and the turn
end

------------------------------------------------------------------------
-- cards and marbles being picked up and dropped
------------------------------------------------------------------------
-- Before TTS picks anything up. Returning false cancels the pick-up.
function onPlayerAction(player, action, targets)
    if not (player and Player.Action and action == Player.Action.PickUp) then return true end
    -- click to play: remember where a card in the hand was picked up, so a click can be told from a drag
    for _, o in ipairs(targets or {}) do
        if o and (o.tag == "Card" or o.tag == "Deck") then
            local ok, why = pcall(cardTouchBlocked, player.color, o)          -- other players' cards (cards_played.lua)
            if ok and why then broadcastToColor(why .. " - hands off!", player.color, { 1, 0.8, 0.3 }); return false end
            if o.tag == "Card" then pcall(easyCardLifted, player.color, o) end
        end
    end
    if actionTargetsMarble(targets) then
        -- easy play: clicking a glowing marble (or spot) chooses it instead of picking it up
        local ok, used = pcall(easyOnPickUp, player, targets)
        if ok and used then return false end
        -- off your turn you can't move marbles (game/marble_moves.lua)
        if turnMarbleMoveBlocked(player.color) then
            broadcastToColor("Not your turn - you can't move marbles right now (hover them to see distances)", player.color, { 1, 0.8, 0.3 })
            return false
        end
    end
    return true
end

-- After TTS picked something up. The checks repeat onPlayerAction's, for older TTS versions that don't send it:
-- an easy-play click or an off-turn marble is dropped straight back.
function onObjectPickedUp(player_color, obj)
    local easyClick = (obj.tag == "Checker" and EASY.session and (EASY.session.ctrl or EASY.session.color) == player_color)
                      or easyIsMarker(obj)
    if easyClick then
        local ok, used = pcall(easyOnPickUp, { color = player_color }, { obj })
        if ok and used then
            pcall(function() obj.drop() end)
            local origin = obj.getTable("origin_position")
            if origin then obj.setPositionSmooth({ origin.x, origin.y + 0.5, origin.z }, false, true) end
            return
        end
    end
    if obj.tag == "Card" then
        obj.setVar("held_by", player_color)               -- taking a card back off the play zone (cards_played.lua)
        obj.setVar("last_player_color", player_color)     -- whose card it is when it lands on a play zone
        pcall(easyCardLifted, player_color, obj)
    elseif obj.tag == "Checker" then
        if turnMarbleMoveBlocked(player_color) then
            pcall(function() obj.drop() end)
            local origin = obj.getTable("origin_position")
            if origin then obj.setPositionSmooth({ origin.x, origin.y + 1, origin.z }, false, true) end
            broadcastToColor("Not your turn - you can't move marbles right now", player_color, { 1, 0.8, 0.3 })
            return
        end
        obj.setVar("picked_up", true)
        recordMarbleOrigin(obj)                           -- an illegal move puts it back here (game/bonks.lua)
    end
end

function onObjectDrop(player_color, obj)
    if not obj then return end
    if obj.tag == "Card" then
        pcall(easyCardDropped, player_color, obj)         -- click to play: a click plays the card
    elseif obj.tag == "Checker" then
        obj.setVar("picked_up", false)
        statsScheduleFinishCheck()                        -- did someone just get all five marbles home?
    end
end

------------------------------------------------------------------------
-- the board
------------------------------------------------------------------------
-- a card landed on / left a play zone (game/cards_played.lua)
function onObjectEnterScriptingZone(zone, obj)
    if obj and obj.tag == "Card" then cardEnteredZone(zone, obj) end
end

function onObjectLeaveScriptingZone(zone, obj)
    if obj and obj.tag == "Card" then cardLeftZone(zone, obj) end
end

-- marbles touching: a marble landing on another bonks it (game/bonks.lua)
function onObjectCollisionEnter(registered_object, info)
    marbleCollisionDetection(registered_object, info)
end

-- hovering a marble shows the distance numbers (game/hover.lua)
function onObjectHover(player_color, object)
    hoverMarble(player_color, object)
end
