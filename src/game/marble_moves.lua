-- game/marble_moves.lua  (Global script)
-- Who may pick up marbles. Off your turn you can't move marbles (the host can switch that with !freemove on|off),
-- but you can still hover them to see distances and handle your cards - TTS's own "disable interactions" would
-- also kill hovering, so it stays off and pick-ups are checked here instead (Global onPlayerAction /
-- onObjectPickedUp). The host can always move marbles (to fix mistakes), and before the game starts anything goes.

TURN_FREE_MOVE = TURN_FREE_MOVE or false

-- May this player NOT pick up marbles right now?
function turnMarbleMoveBlocked(player_color)
    if TURN_FREE_MOVE or not (TURN_STATE and TURN_STATE.active) then return false end
    local p = Player[player_color]
    if p and p.host then return false end
    local cols = PLAYER_COLORS[Global.getVar("num_players")] or {}
    local cur = cols[TURN_STATE.seat]
    if cur == player_color and not botIsBot(cur) then return false end
    return true
end

-- Does a pick-up include a marble (or one of easy play's click targets)?
function actionTargetsMarble(targets)
    for _, o in ipairs(targets or {}) do
        if o and (o.tag == "Checker" or easyIsMarker(o)) then return true end
    end
    return false
end
