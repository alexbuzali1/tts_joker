-- bot/evaluate.lua
-- How good a board is for one team (JB.evaluate): progress of every marble, minus the risk of being bonked, plus
-- the team's formation (a defender in each home stretch, a tidy finish). The search (search.lua) compares moves by
-- the board they leave, adjusted by move_costs.lua / setups.lua / hand.lua.
local JB = JokerBot


------------------------------------------------------------------------
-- evaluation
------------------------------------------------------------------------
-- One cell of progress is worth the same on every table size (user, flag 39: "no need to be slow"): 120 points over
-- the 67 cells of a 4-player lap. Before, the 120 was spread over the whole lap, so on a 6- or 8-player table a cell
-- was worth half as much and fixed costs and bonuses drowned out moving faster. The finish is worth a full lap plus 55.
JB.CELL_VALUE = 120 / 67
function JB.pieceValue(S, m)
    if m.kind == 'S' then return 0 end
    local span = S.R - 5
    if m.kind == 'G' then return 80 + JB.CELL_VALUE * span + 8 * (m.p - 1) end   -- deeper in the finish is better
    local traveled = span - JB.distToEntrance(S, m.seat, m.p)
    if traveled < 0 then traveled = 0 end
    return 25 + JB.CELL_VALUE * traveled
end

-- A marble parked on a teammate's exit cell, while that teammate still has marbles in start, is waiting to be
-- friendly-bonked: when the teammate comes out it lands there and sends the marble to its OWN finish entrance.
-- Credit JB.PARK_WEIGHT of that jump (plus JB.PARK_BASE) so the bot keeps it parked instead of moving it on.
-- When its own entrance is held by one of its own marbles the jump can't happen yet (it would land on its own marble),
-- but that is usually for a turn: the marble on the entrance steps into the finish with almost any small card. So it
-- keeps JB.PARK_BLOCKED_SHARE of the bonus (was 0; user 2026-11-14 game, flag 47: his Joker friendly-bonked
-- seat 5's OTHER marble to its entrance, keeping the one parked on seat 7's exit for a later free jump - "I essentially
-- gain a bonk"; the bot preferred jumping onto the parked one because the park then counted for nothing).
-- None if the finish has no room for both.
JB.PARK_WEIGHT = 0.5      -- was 0.7; flag 44: a maybe-jump shouldn't outweigh a sure one
JB.PARK_BASE = 20
JB.PARK_BLOCKED_SHARE = 0.7
local function parkBonus(S, m, inStart)
    if m.kind ~= 'R' then return 0 end
    for t = 1, S.N do
        if t ~= m.seat and JB.sameTeam(t, m.seat) and (inStart[t] or 0) > 0 and m.p == JB.exitCell(t) then
            local share = 1
            local own = S.ring[JB.entrance(m.seat)]
            if own and S.marbles[own].seat == m.seat then
                if JB.goalCount(S, m.seat) > 3 then return 0 end         -- no room in the finish for both
                share = JB.PARK_BLOCKED_SHARE
            end
            local atEntrance = JB.pieceValue(S, { seat = m.seat, kind = 'R', p = JB.entrance(m.seat) })
            return share * JB.STRATEGY * (JB.PARK_BASE + JB.PARK_WEIGHT * math.max(0, atEntrance - JB.pieceValue(S, m)))
        end
    end
    return 0
end

-- How many enemy threats a marble of team `parity` on ring cell p faces.
-- User's rule (strategy levels): an enemy d cells BEHIND is dangerous for d = 1..6 and 9..13; d = 7 is safe (a 7 split
-- never moves one marble 7), d = 8 is safe (an 8 goes backwards), d > 13 is safe. An enemy exactly 8 AHEAD is
-- dangerous (it can play the 8 backwards onto you), and so is an enemy's exit cell while it has marbles in start.
-- At strategy 0 the plain rule applies: any enemy 1..13 behind.
function JB.threatsAt(S, p, parity, exitThreat, realOnly)
    local threats = 0
    for back = 1, JB.THREAT_RANGE do
        if JB.STRATEGY <= 0 or (back ~= 7 and back ~= 8) then
            local i = S.ring[JB.wrap(S, p - back)]
            if i and S.marbles[i].seat % 2 ~= parity then threats = threats + 1 end
        end
    end
    if JB.STRATEGY > 0 then
        local ahead = S.ring[JB.wrap(S, p + 8)]
        if ahead and S.marbles[ahead].seat % 2 ~= parity then threats = threats + 1 end
    end
    if exitThreat and exitThreat[p] then threats = threats + 1 end
    -- an enemy with marbles in start can come out and then hit you from its exit cell next turn (user, flag 21:
    -- "moved in front of my start"), so its exit cell counts as an enemy marble standing there
    if JB.STRATEGY > 0 and exitThreat and not realOnly then
        for back = 1, JB.THREAT_RANGE do
            -- half a threat: it is two turns away (flag 77: "when it moved there wasn't anybody there")
            if back ~= 7 and back ~= 8 and exitThreat[JB.wrap(S, p - back)] and not S.ring[JB.wrap(S, p - back)] then
                threats = threats + 0.5
            end
        end
    end
    if JB.STRATEGY > 0 and exitThreat and exitThreat.spots and not realOnly and exitThreat.spots[p] then
        threats = threats + JB.SPOT_THREATS
    end
    return threats
end
JB.SPOT_THREATS = 2      -- an enemy's -8 spot or finish entrance counts as this many threats

-- Seats that burned on their last turn (set by bot/play.lua from the game stats before each bot move; empty in tests).
-- A burning player most likely has no card to come out of start with.
JB.BURNING = JB.BURNING or {}
function JB.exitThreats(S, parity)
    local exitThreat = { spots = {} }
    for _, m in ipairs(S.marbles) do
        if m.seat % 2 ~= parity then
            if m.kind == 'S' and not JB.BURNING[m.seat] then   -- a burning player has no card to come out with
                exitThreat[JB.exitCell(m.seat)] = true
                -- the enemy's -8 spot: it comes out and plays the 8 backwards onto you (user, flag 41)
                exitThreat.spots[JB.wrap(S, JB.exitCell(m.seat) - 8)] = true
            end
            if m.kind ~= 'G' then
                -- the enemy's finish entrance: its teammate bonks it, it is sent to its entrance and bonks you there
                -- (user, flag 41: "red gets bonked out of nowhere"; flag 68: even a marble that only just came out of
                -- start can be bonked on to its entrance). Wait behind these spots, never on them.
                exitThreat.spots[JB.entrance(m.seat)] = true
            end
        end
    end
    return exitThreat
end

-- Formation (user strategy): keep one "defender" in your home stretch (your exit cell up to 10 past it, covering the
-- next enemy's -8 spot) and send the other marbles round the board. The rearmost marble in that stretch (the
-- defender) gets no credit for
-- progress (nudging the defender forward is worth nothing, so the runner moves instead; a better defensive spot is
-- rewarded by the ambush bonus). Having a defender there is worth JB.DEFENDER_BONUS; every marble beyond 2 in the
-- stretch costs JB.CROWD_PENALTY. All scaled by JB.STRATEGY.
JB.HOME_STRETCH = 10
JB.DEFENDER_BONUS = 25
JB.CROWD_PENALTY = 30
JB.DEAD_DEFENDER_SPOT = { [2] = true, [3] = true }   -- cells past the exit where the defender can't reach the -8 spot
JB.DEAD_DEFENDER_PENALTY = 35
function JB.inHomeStretch(S, m)
    return m.kind == 'R' and (m.p - JB.exitCell(m.seat)) % S.R <= JB.HOME_STRETCH
end

-- Clean finish (user): pack the finish from the deep end before setting up more marbles to enter. Each empty finish
-- cell deeper than a marble already in it costs JB.UNTIDY_PENALTY; while a finish is untidy, each of that player's
-- marbles within JB.THREAT_RANGE of its entrance costs JB.DIRTY_APPROACH_PENALTY. Scaled by JB.STRATEGY.
JB.UNTIDY_PENALTY = 70      -- user: never leave gaps in the finish, clear them by any means (A, small cards, 7 splits)
JB.DIRTY_APPROACH_PENALTY = 25
-- How untidy a finish is = how many single steps it takes to pack it from the deep end (the number of Aces you'd need):
-- the k-th deepest marble belongs in cell GOAL_SIZE - k + 1. (Was: empty cells deeper than a marble, which didn't see
-- that putting a marble into cell 1 behind a jam (cells 2, 3, 5 full) makes it need 3 Aces instead of 2 - user,
-- 2026-11-11 game 5 turn 171.) For one block with empty cells below it, both measures are the same.
function JB.untidyCells(S, seat)
    local n, k = 0, 0
    for j = JB.GOAL_SIZE, 1, -1 do
        if S.goal[seat][j] then
            k = k + 1
            n = n + (JB.GOAL_SIZE - k + 1) - j
        end
    end
    return n
end
local function finishPenalty(S, seat)
    local untidy = JB.untidyCells(S, seat)
    if untidy == 0 then return 0 end
    local p = JB.UNTIDY_PENALTY * untidy
    for _, m in ipairs(S.marbles) do
        if m.seat == seat and m.kind == 'R' and JB.distToEntrance(S, seat, m.p) <= JB.THREAT_RANGE then
            p = p + JB.DIRTY_APPROACH_PENALTY
        end
    end
    return p
end

JB.EXIT_CELL_RISK = 0.85
JB.WIN_VALUE = 100000
JB.RACE_LAST = 1.0         -- see evaluate: a team's last marble on the ring is worth double (2 left: x1.5)
JB.THREAT_RISK = 0.3        -- per threat (was 0.2): the bot ignored ending 1-6 in front of an enemy (user)
-- What a marble in danger has at stake (user, flags 41 and earlier: "sunk cost fallacy is not good"; a marble isn't
-- worth protecting more just because many cards were spent on it). Its value is 25 when it comes out and grows with
-- the distance travelled; the risk counts the 25 plus only JB.STAKE_SHARE of the growth (all of it at strategy 0),
-- so the bot keeps pushing a far runner instead of hiding it.
JB.STAKE_SHARE = 0.6
function JB.atStake(v)
    local flat = math.min(v, 25 + JB.STAKE_SHARE * math.max(0, v - 25))
    return v + JB.STRATEGY * (flat - v)
end
-- Chance-like risk (0..0.85) that a marble of team `parity` on ring cell p is bonked before it moves again.
-- On an enemy's exit cell while it has marbles in start it is bonked just by that enemy coming out, and most hands
-- hold an exit card (user, flags 21/26), so that is far worse than an ordinary threat.
function JB.marbleRisk(S, p, parity, exitThreat)
    -- each threat ~ an enemy holding the exact card (30-40% with a 5-6 card hand); strategy 0 keeps the old 0.2
    local per = 0.2 + JB.STRATEGY * (JB.THREAT_RISK - 0.2)
    local risk = math.min(0.7, per * JB.threatsAt(S, p, parity, exitThreat))
    if exitThreat[p] then risk = math.max(risk, 0.2 + JB.STRATEGY * (JB.EXIT_CELL_RISK - 0.2)) end
    return risk
end
-- Does `seat` need a defender near its start? Only while the next player (an enemy) still has marbles in start.
function JB.needsDefender(S, seat, inStart)
    local nxt = seat % S.N + 1
    if inStart then return (inStart[nxt] or 0) > 0 end
    for _, o in ipairs(S.marbles) do if o.seat == nxt and o.kind == 'S' then return true end end
    return false
end

-- Score from the point of view of team `parity` (seat % 2). Higher = better for that team.
function JB.evaluate(S, parity)
    local total = 0
    local inStart = {}
    for _, m in ipairs(S.marbles) do if m.kind == 'S' then inStart[m.seat] = (inStart[m.seat] or 0) + 1 end end
    -- seats that still have marbles in start can hit their exit cell with an ace/face
    local exitThreat = JB.exitThreats(S, parity)
    local stretch = {}
    local exitValue = {}
    local defender, defenderD = {}, {}           -- per seat: the rearmost marble in its home stretch
    for i, m in ipairs(S.marbles) do
        if JB.inHomeStretch(S, m) then
            stretch[m.seat] = (stretch[m.seat] or 0) + 1
            local d = (m.p - JB.exitCell(m.seat)) % S.R
            -- a defender only while the next player can still come out (user, flag 49: "green is all the way in,
            -- there's no point playing defense"); otherwise every marble is a runner
            if JB.needsDefender(S, m.seat, inStart) and (not defenderD[m.seat] or d < defenderD[m.seat]) then
                defender[m.seat], defenderD[m.seat] = i, d
            end
        end
    end
    -- the last marbles of a team are worth more: finishing them wins (user, flag 54). 1 left: x2, 2 left: x1.5
    local left = { [0] = 0, [1] = 0 }
    for _, m in ipairs(S.marbles) do if m.kind ~= 'G' then left[m.seat % 2] = left[m.seat % 2] + 1 end end
    -- a team with every marble home has WON (user, flag 58: the bot didn't play the ace that won the game)
    if left[parity] == 0 then return JB.WIN_VALUE end
    if left[1 - parity] == 0 then return -JB.WIN_VALUE end
    local raceMult = {}
    for par = 0, 1 do
        local l = left[par]
        raceMult[par] = 1 + JB.STRATEGY * ((l == 1 and JB.RACE_LAST) or (l == 2 and JB.RACE_LAST / 2) or 0)
    end
    for i, m in ipairs(S.marbles) do
        local v = JB.pieceValue(S, m) + parkBonus(S, m, inStart)
        if m.kind == 'R' then v = v * raceMult[m.seat % 2] end
        if JB.STRATEGY > 0 and defender[m.seat] == i then
            -- the defender (rearmost marble in the home stretch) gets no credit for progress: valued as if still on
            -- the exit cell, so nudging it forward is worth nothing and the marbles ahead of it are sent round instead
            exitValue[m.seat] = exitValue[m.seat] or JB.pieceValue(S, { seat = m.seat, kind = 'R', p = JB.exitCell(m.seat) })
            v = v + JB.STRATEGY * (exitValue[m.seat] - JB.pieceValue(S, m))
        end
        if m.seat % 2 == parity then
            local risk = 0
            if m.kind == 'R' then risk = JB.marbleRisk(S, m.p, parity, exitThreat) end
            total = total + v - risk * JB.atStake(v)
        else
            total = total - v
        end
    end
    -- formation: a defender in each home stretch, no more than 2 there
    if JB.STRATEGY > 0 then
        for seat = 1, S.N do
            local fp = finishPenalty(S, seat)
            if seat % 2 == parity then total = total - JB.STRATEGY * fp else total = total + JB.STRATEGY * fp end
        end
        for seat, n in pairs(stretch) do
            local f = (defender[seat] and JB.DEFENDER_BONUS or 0) - JB.CROWD_PENALTY * math.max(0, n - 2)
            if seat % 2 == parity then total = total + JB.STRATEGY * f else total = total - JB.STRATEGY * f end
        end
    end
    return total
end
