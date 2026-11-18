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

-- Hands off other players' cards (user, 11-17): nobody but the host can pick up a card in another player's hand or
-- lying on another player's play zone. Returns the reason, or nil when it's allowed. (The host can, to fix mistakes.)
function cardTouchBlocked(color, card)
    if not (card and (card.tag == "Card" or card.tag == "Deck") and color) then return nil end
    local p = Player[color]
    if p and p.host then return nil end
    local blocked = nil
    pcall(function()
        for _, c in ipairs(PLAYER_COLORS[Global.getVar("num_players")] or {}) do
            if c ~= color then
                local q = Player[c]
                if q and q.seated then
                    for _, o in ipairs(q.getHandObjects() or {}) do
                        if o == card then blocked = "That's " .. (personName(c) or c) .. "'s card" end
                    end
                end
                local pile = (Global.getTable("discard_piles") or {})[c]
                -- (your own card dropped on the wrong zone by mistake: you can still take it back)
                if not blocked and pile and card.getVar("last_player_color") ~= color then
                    local a, b = card.getPosition(), pile.getPosition()
                    if isNear(a.x, a.z, b.x, b.z, 1.5) then blocked = "That card is on someone else's play zone" end
                end
            end
        end
    end)
    return blocked
end
