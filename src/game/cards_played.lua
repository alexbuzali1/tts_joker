-- game/cards_played.lua  (Global script)
-- Cards landing on (and leaving) the play zones. Each play zone has a scripting zone named "<Seat colour>_DiscardPile"
-- (discard_piles.lua). A card counts as played when it lands on its own player's zone (the player who last picked
-- it up, "last_player_color"); then it's announced, counted in the stats, and easy play starts for it. A card taken
-- back off the zone into the hand the same turn no longer counts.

-- Global onObjectEnterScriptingZone (cards only)
function cardEnteredZone(zone, obj)
    local player_color = zone.getName():match("^(%a+)_DiscardPile")
    if not player_color then return end
    if player_color == obj.getVar("last_player_color") then
        printToAll(playerLabel(player_color) .. " played a " .. obj.getName())
        obj.setVar("held_by", nil)
        statsCardPlayed(player_color, obj)
        pcall(easyCardPlayed, player_color, obj)
    else
        printToAll('Wrong discard pile, idiot')
    end
end

-- Global onObjectLeaveScriptingZone (cards only). If its player picked it up again this turn (taken back into the
-- hand), it no longer counts and easy play stops. Cards merging into the pile (the card object is replaced by a
-- deck) and reshuffles (nobody picks those up) are not take-backs.
function cardLeftZone(zone, obj)
    local color = (zone.getName() or ""):match("^(%a+)_DiscardPile")
    if not color then return end
    Wait.time(function()
        local ok, gone = pcall(function() return obj == nil or obj.isDestroyed() end)
        if not ok or gone then return end
        if obj.getVar("held_by") ~= color then return end
        local pile = (Global.getTable("discard_piles") or {})[color]
        if pile then                                       -- back on the zone already (dropped again)
            local p, q = obj.getPosition(), pile.getPosition()
            if isNear(p.x, p.z, q.x, q.z, 1) and p.y < q.y + 1.5 then return end
        end
        if statsCardUnplayed(color, obj) then printToAll(playerLabel(color) .. " took back the " .. obj.getName()) end
        pcall(easyCardRemoved, color, obj)
    end, 0.3)
end
