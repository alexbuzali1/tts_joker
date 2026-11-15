-- game/bonks.lua  (Global script)
-- What happens when a marble lands on another one. TTS reports the collision (Global onObjectCollisionEnter ->
-- marbleCollisionDetection); the marble underneath is the one bonked:
--   * an ENEMY marble goes back to a free slot in its start
--   * a TEAMMATE's marble jumps to the entrance of its own finish (a "friendly bonk"), and if a marble is sitting
--     there it is bonked in turn (a chain)
--   * an ILLEGAL friendly bonk (see illegalFriendlyBonk) isn't done: the marble that was dropped flies back to
--     where it was picked up, with an "ILLEGAL MOVE" message
-- The bots follow the same rules in bot/rules.lua (JB.land), so a bot never makes an illegal move.

-- The marble (if any) standing on a point, ignoring the marbles whose GUIDs are in `skip`.
local function marbleAt(pos, skip)
    for _, list in pairs(Global.getTable("marbles_by_player") or {}) do
        for _, m in ipairs(list) do
            if not skip[m.getGUID()] then
                local p = m.getPosition()
                if isNear(p.x, p.z, pos.x, pos.z, .3) then return m end
            end
        end
    end
    return nil
end

-- Can this friendly bonk happen? Returns nil when it can, or the reason it can't.
-- The whole chain is checked before anything moves: the bonked teammate flies to the entrance of its finish;
-- whoever sits there is bonked in turn (an enemy goes home, which ends the chain; a teammate flies on to ITS
-- entrance). Illegal anywhere in the chain:
--   * a teammate sitting on the entrance of their own finish can't be bonked (they'd be "sent" where they are)
--   * a marble can't land on one of its own marbles
function illegalFriendlyBonk(bonkee)
    local cur = bonkee
    local skip = { [bonkee.getGUID()] = true }
    for _ = 1, 6 do
        local target = cur.getTable("friendly_bonk_position")
        if not target then return nil end
        local pos = cur.getPosition()
        if isNear(pos.x, pos.z, target.x, target.z, .3) then
            return cur == bonkee and "You can't bonk a teammate who is at the entrance of their finish"
                or "That bonk would knock a teammate off the entrance of their finish"
        end
        local occ = marbleAt(target, skip)
        if not occ then return nil end                                   -- lands on an empty entrance
        if occ.getVar("player_color") == cur.getVar("player_color") then
            return cur == bonkee and "That teammate would land on their own marble"
                or "That bonk chain would land a marble on its own marble"
        end
        if occ.getVar("team_number") % 2 ~= cur.getVar("team_number") % 2 then return nil end   -- enemy: sent home
        skip[occ.getGUID()] = true                                        -- a teammate: bonked on in turn
        cur = occ
    end
    return "That bonk chain is too long"
end

-- An illegal move: a message for everyone, and the marble that was dropped is carried back to where it was picked
-- up. Nothing is bonked.
function rejectMove(marble, reason)
    if marble.getVar("rejecting") then return end
    marble.setVar("rejecting", true)

    broadcastToAll("ILLEGAL MOVE: " .. reason, {1, 0.25, 0.25})

    local origin = marble.getTable("origin_position")
    if origin then
        local cur = marble.getPosition()
        marble.setPositionSmooth({cur.x, cur.y + 3, cur.z}, false, false)
        Wait.time(function()
            marble.setPositionSmooth({origin.x, origin.y + 2, origin.z}, false, false)
        end, .5)
    end
    Wait.time(function() marble.setVar("rejecting", false) end, 2)
end

-- Lift a bonked marble and carry it to target_position (its start slot or its finish entrance).
function bonkAnimation(marble, target_position)
    if not target_position then                          -- no free start slot found: use the first one
        local start_points = marble.getTable("start_points")
        target_position = start_points[1]["position"]
    end
    local current_position = marble.getPosition()
    marble.setPositionSmooth({current_position.x, current_position.y + 3, current_position.z})
    Wait.time(function()
        marble.setPositionSmooth({target_position.x, target_position.y + 3, target_position.z})
    end,.5)
end

-- Two marbles touched (from Global onObjectCollisionEnter). registered_object = the marble the event is for;
-- info.collision_object = the marble that hit it. Only a marble landing ON another (close, and from above) bonks.
function marbleCollisionDetection(registered_object, info)
    if UNDO and UNDO.restoring then return end          -- game/undo.lua is putting the marbles back

    if registered_object.tag ~= "Checker" or info.collision_object.tag ~= "Checker" then return end
    local this_marble = registered_object                -- underneath: the one that gets bonked
    local other_marble = info.collision_object           -- on top: the one that moved

    if objectDistance(this_marble, other_marble) >= COLLISION_DISTANCE_THRESHOLDS[Global.getVar("num_players")]
       or this_marble.getPosition().y >= other_marble.getPosition().y then
        return
    end

    -- two marbles of the same seat (e.g. a bonked marble landing among its own in start): nothing happens
    if this_marble.getVar("team_number") == other_marble.getVar("team_number") then return end

    -- the marble on top is already being sent back (illegal move)
    if other_marble.getVar("rejecting") then return end

    local bonkee_color = this_marble.getVar("player_color")
    local bonker_color = other_marble.getVar("player_color")
    if this_marble.getVar("team_number") % 2 ~= other_marble.getVar("team_number") % 2 then
        -- enemy bonk: back to start
        bonkAnimation(this_marble, findEmptyStartPosition(this_marble))
        statsBonk(bonker_color, bonkee_color, false, this_marble)
    else
        -- friendly bonk: to its finish entrance, unless the chain is illegal
        local reason = illegalFriendlyBonk(this_marble)
        if reason then
            -- still in someone's hand: wait for the drop (the collision fires again) instead of yanking it away
            if not other_marble.getVar("picked_up") then rejectMove(other_marble, reason) end
            return
        end
        bonkAnimation(this_marble, this_marble.getVar("friendly_bonk_position"))
        statsBonk(bonker_color, bonkee_color, true, this_marble)
    end

    printToAll(playerLabel(bonker_color) .. " bonked " .. playerLabel(bonkee_color) .. "!")
end
