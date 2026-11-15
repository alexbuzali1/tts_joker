-- bot/setups.lua
-- Bonuses for moves that pay off on a later turn, deeper than the search looks: a defensive Joker, chains of bonks,
-- "7 traps" (a teammate's marble placed so a 7 split can bonk next turn), ambushes on an enemy's exit or -8 spot,
-- plus the risk of having to burn a card next turn, and which bonks are worth anything.
local JB = JokerBot

-- Defensive Joker: an enemy marble within reach of its finish (it could turn in next turn), whose seat already
-- has at least JB.DEFENSIVE_MIN_HOME marbles home, is the most valuable thing a Joker can hit. Sending it back
-- to start costs that player a whole lap. The bonus is larger the more of them are home and the closer it is.
JB.JOKER_DEFENCE_HOME = 4      -- a defensive Joker: only on a player's last marble (was JB.DEFENSIVE_MIN_HOME, 3)
JB.JOKER_DEFENCE_RANGE = JB.THREAT_RANGE   -- (13; a last marble is the winning one: stopping it is the important defence)
JB.DEFENSIVE_MIN_HOME = 3      -- was 2; flag 48: a Joker on a player with 2 home was "bizarre and unforced"
function JB.defensiveBonus(S, act)
    if act.card ~= '$' or not act.bumpList then return 0 end
    local bonus = 0
    for _, b in ipairs(act.bumpList) do
        local z = S.marbles[b.idx]
        if not b.friendly and z.kind == 'R' then
            local home = JB.goalCount(S, z.seat)
            local d = JB.distToEntrance(S, z.seat, z.p)
            -- the LAST marble only (user, 2026-11-11 game 3: three Jokers on players with 3 home and other marbles
            -- still out were "terrible"; play conservatively, save the Joker)
            if home >= JB.JOKER_DEFENCE_HOME and d <= JB.JOKER_DEFENCE_RANGE then
                bonus = bonus + 150 + 60 * (home - JB.DEFENSIVE_MIN_HOME) + 6 * (JB.THREAT_RANGE - d)
            end
        end
    end
    return bonus
end

-- Multi-bonks: every bonk beyond the first in one play (a chain: you bonk a teammate, who is sent to their
-- finish entrance and bonks whoever stands there, ... or two bonks with the two halves of a 7) scores extra,
-- and much more with a Joker, so a Joker that sets off a chain is worth spending.
JB.CHAIN_BONUS = 80          -- per extra bonk, any card
JB.JOKER_CHAIN_BONUS = 250   -- per extra bonk, on top of that, when the card is a Joker (was 150; raised with JB.JOKER_MIN_MARGIN, user 2026-11-11)
function JB.chainBonus(act)
    local extra = (act.bumps or 0) - 1
    if extra <= 0 then return 0 end
    local per = JB.CHAIN_BONUS + (act.card == '$' and JB.JOKER_CHAIN_BONUS or 0)
    return per * extra
end

-- 7 trap: park a marble k cells behind a teammate's exit cell while holding a 7. When the teammate comes out
-- of start, the 7 splits k + (7-k): your marble bonks them (friendly -> sent to their finish entrance) and the
-- remaining 7-k steps carry their marble straight into their finish. k = 2 is best (+5 = the deepest finish cell).
-- Needs: the teammate has a marble in start, and their finish cells 1..(7-k) are empty.
-- Returns the bonus for the position S for `seat` (0 when it holds no 7 / no trap is set). Search-only heuristic:
-- the payoff is several turns away, deeper than the search can see.
JB.SEVEN_TRAP = { [2] = 70, [3] = 45, [4] = 30, [5] = 18, [6] = 10 }   -- bonus by distance behind the exit cell
function JB.sevenTrapBonus(S, seat, hasSeven)
    if not hasSeven then return 0 end
    local total = 0
    for _, m in ipairs(S.marbles) do
        if m.seat == seat and m.kind == 'R' then
            local best = 0
            for t = 1, S.N do
                if t ~= seat and JB.sameTeam(t, seat) then
                    local inStart = false
                    for _, o in ipairs(S.marbles) do if o.seat == t and o.kind == 'S' then inStart = true end end
                    -- the teammate can't come out while its own marble stands on its exit cell
                    local blocker = S.ring[JB.exitCell(t)]
                    if blocker and S.marbles[blocker].seat == t then inStart = false end
                    local k = (JB.exitCell(t) - m.p) % S.R
                    local b = JB.SEVEN_TRAP[k]
                    if inStart and b then
                        local clear = true
                        for j = 1, 7 - k do if S.goal[t][j] then clear = false end end
                        if clear and b > best then best = b end
                    end
                end
            end
            total = total + best
        end
    end
    return math.min(total, 200)
end

-- Ambush (user strategy): an enemy that comes out of start often plays an 8 backwards straight away, landing
-- on its "-8 spot" (its exit cell - 8 = 3 cells before its finish entrance). Standing ON that spot gets you bonked
-- (evaluate counts an enemy 8 ahead as a threat); standing d cells BEFORE it while keeping a card worth d lets you
-- bonk them next turn (e.g. play a 4 now, keep the 6). Same for an enemy's finish entrance (the K spot from your
-- exit). Bonus for the position after the move, given the cards still held. 8s don't count (they go backwards).
JB.AMBUSH_BONUS = { minus8 = 25, entrance = 15 }   -- was 45/25: a maybe-bonk kept beating sure moves (flags 38, 46, 70, 74)
-- (no 7: user, flag 31 - 7 behind the next player's -8 spot "can't play defense"; a split 7 can't move one marble 7)
local REACH = { a = 1, ['2'] = 2, ['3'] = 3, ['4'] = 4, ['5'] = 5, ['6'] = 6, ['9'] = 9, ['10'] = 10,
                j = 11, q = 12, k = 13 }
function JB.ambushBonus(S, seat, hand)
    local reach = {}
    for _, c in ipairs(hand or {}) do if REACH[c] then reach[REACH[c]] = true end end
    local total = 0
    -- formation: in the home stretch only the defender (its rearmost marble) waits in ambush; the others are runners
    local rearD = nil
    for _, m in ipairs(S.marbles) do
        if m.seat == seat and JB.inHomeStretch(S, m) then
            local d = (m.p - JB.exitCell(seat)) % S.R
            if not rearD or d < rearD then rearD = d end
        end
    end
    for _, m in ipairs(S.marbles) do
        local runnerNearStart = JB.inHomeStretch(S, m) and (m.p - JB.exitCell(seat)) % S.R ~= rearD
        if m.seat == seat and m.kind == 'R' and not runnerNearStart then
            local best = 0
            for e = 1, S.N do
                if not JB.sameTeam(e, seat) then
                    local inStart, onRing = false, false
                    for _, o in ipairs(S.marbles) do
                        if o.seat == e and o.kind == 'S' then inStart = true end
                        if o.seat == e and o.kind == 'R' then onRing = true end
                    end
                    -- entrance ambush only if that enemy has a marble on its way home (flag 49: not a finished player)
                    local targets = { { cell = JB.wrap(S, JB.exitCell(e) - 8), b = JB.AMBUSH_BONUS.minus8, need = inStart },
                                      { cell = JB.entrance(e), b = JB.AMBUSH_BONUS.entrance, need = onRing } }
                    for _, t in ipairs(targets) do
                        local d = (t.cell - m.p) % S.R
                        if t.need and d >= 1 and reach[d] and t.b > best then best = t.b end
                    end
                end
            end
            total = total + best
        end
    end
    return math.min(total, 90)
end

-- Combo 7 ready: holding a 7, is there a 7 split available right now that both bonks someone AND brings a marble into
-- a finish (e.g. your marble 2 behind a teammate: +2 bonks them to their entrance, +5 carries them in)? If the bot
-- can reach such a position with its other card, it keeps the 7 for next turn. Generalises the teammate-exit trap
-- (sevenTrapBonus) to marbles already on the board and to enemy bonks.
JB.COMBO7_BONUS = 60
function JB.comboSevenBonus(S, seat, hasSeven)
    if not hasSeven then return 0 end
    -- discounted by the danger the bot's own marble making the play is in (user, flag 21: waiting on an enemy's
    -- exit cell for the combo is not worth it)
    local par, exits, best = seat % 2, JB.exitThreats(S, seat % 2), 0
    for _, a in ipairs(JB.legalActions(S, seat, { '7' })) do
        if JB.worthyBumps(S, a) > 0 and JB.entersFinish(S, a) then
            local risk = 0
            for _, st in ipairs(a.steps) do
                local m = S.marbles[st.mi]
                if m.seat == seat and m.kind == 'R' then risk = math.max(risk, JB.marbleRisk(S, m.p, par, exits)) end
            end
            best = math.max(best, JB.COMBO7_BONUS * (1 - risk))
        end
    end
    return best
end

-- Burn risk (user: "prioritise not burning"), for the position after a move and the cards still held:
--  * none of those cards would have a legal move next turn                        -> JB.BURN_NEXT_PENALTY
--  * every marble on the board is in danger and no exit card (A, J, Q, K, Joker) is held, so one bonk leaves
--    the player stuck burning (e.g. parking the only marble on an enemy's exit cell)    -> JB.BURN_EXPOSED_PENALTY
JB.BURN_NEXT_PENALTY = 60
JB.BURN_EXPOSED_PENALTY = 80
function JB.burnRisk(S, seat, hand)
    local penalty = 0
    if #hand > 0 and #JB.legalActions(S, seat, hand, { simple7 = true }) == 0 then penalty = penalty + JB.BURN_NEXT_PENALTY end
    local hasExit = false
    for _, c in ipairs(hand) do if JB.EXIT_CARDS[c] then hasExit = true end end
    if not hasExit then
        local onBoard, threatened, minRisk = 0, 0, 1
        local par = seat % 2
        local exits = JB.exitThreats(S, par)
        for _, m in ipairs(S.marbles) do
            if m.seat == seat and m.kind == 'R' then
                onBoard = onBoard + 1
                if JB.threatsAt(S, m.p, par, exits, true) > 0 then threatened = threatened + 1 end   -- real threats only
                minRisk = math.min(minRisk, JB.marbleRisk(S, m.p, par, exits))
            end
        end
        local inStart = false
        for _, m in ipairs(S.marbles) do if m.seat == seat and m.kind == 'S' then inStart = true end end
        -- scaled by how likely the bonk is (flags 47/50/51: one enemy needing an exact K cost the full 80): full at
        -- a 60% risk (an enemy's exit cell, or two threats), about half for a single threat
        if inStart and onBoard > 0 and threatened == onBoard then
            penalty = penalty + JB.BURN_EXPOSED_PENALTY * math.min(1, minRisk / 0.6)
        end
    end
    return penalty
end

-- What playing this card adds to a move's score: minus the cost of spending the card (good cards are worth
-- keeping), plus the defensive Joker and multi-bonk bonuses. S = the position BEFORE the move.
-- Hard rule (user): at the strategy levels (JB.STRATEGY > 0) a 7 is only played if it bonks or brings a marble into
-- a finish, even when an idle 7 looks like the best move. Idle 7s are dropped from the list of moves, unless they
-- are the only legal moves (then one must be played: burning is only allowed with no legal move at all).
-- Not every bonk is a good bonk (user, flag 26): knocking an enemy marble off (or just past) its own exit cell costs
-- that player almost nothing (it comes straight back out), so for the 7 and 8 rules such a bonk doesn't count.
-- Friendly bonks (a teammate sent on to its finish entrance) always count.
JB.CHEAP_BONK_RANGE = 3          -- an enemy marble fewer than this many cells past its exit cell is a cheap bonk
function JB.worthyBumps(S, act)
    local n = 0
    for _, b in ipairs(act.bumpList or {}) do
        local z = S.marbles[b.idx]
        if b.friendly or z.kind ~= 'R' or (z.p - JB.exitCell(z.seat)) % S.R >= JB.CHEAP_BONK_RANGE or JB.BURNING[z.seat] then n = n + 1 end
    end
    return n
end

-- A 7 into a finish only counts when it is worth the 7 (user, flag 36: "no threat on White and it couldn't move it
-- all the way in, so it was a waste"): the move leaves that finish with no gaps, or with fewer than before
-- (cleaning house; flag 5: tidy up before lining up more), or the marble that enters was in danger where it stood.
-- true when every finish the move enters is left with no gaps, or fewer gaps than before
function JB.tidyEntry(S, act)
    for _, st in ipairs(act.steps or {}) do
        if st.kind == 'G' then
            local seat = S.marbles[st.mi].seat
            local after, before = JB.untidyCells(act.state, seat), JB.untidyCells(S, seat)
            if not (after == 0 or after < before) then return false end
        end
    end
    return true
end
function JB.goodFinishEntry(S, act)
    local exits
    for _, st in ipairs(act.steps or {}) do
        if st.kind == 'G' then
            local m = S.marbles[st.mi]
            local after, before = JB.untidyCells(act.state, m.seat), JB.untidyCells(S, m.seat)
            if after == 0 or after < before then return true end      -- finish left tidy, or tidier than before
            if m.kind == 'R' then
                exits = exits or JB.exitThreats(S, m.seat % 2)
                -- real danger only: marbles that can hit it, or standing on an enemy's exit (not "an enemy might
                -- come out and then hit it", which is two turns away)
                if JB.threatsAt(S, m.p, m.seat % 2, exits, true) > 0 then return true end
            end
        end
    end
    return false
end

-- A 7 needs a HIGH-QUALITY bonk (user: "it favors any bonk with a 7 too much. it needs to be a high quality bonk or
-- out of urgency"): an enemy marble that has travelled JB.SEVEN_BONK_MIN_TRAVEL+ cells, or is within reach of its
-- finish (urgent), or whose player has 3+ home; or a friendly bonk that jumps a teammate JB.SEVEN_FRIENDLY_MIN+
-- cells. (The 8 keeps the plainer JB.worthyBumps rule.)
JB.SEVEN_BONK_MIN_TRAVEL = 25
JB.SEVEN_FRIENDLY_MIN = 15
function JB.qualityBumps(S, act)
    local n = 0
    for _, b in ipairs(act.bumpList or {}) do
        local z = S.marbles[b.idx]
        if z.kind == 'R' then
            local toEntrance = JB.distToEntrance(S, z.seat, z.p)
            if b.friendly then
                if toEntrance >= JB.SEVEN_FRIENDLY_MIN then n = n + 1 end
            else
                local travelled = (z.p - JB.exitCell(z.seat)) % S.R
                -- (3+ home only counts together with being close to finishing - covered by toEntrance; on its own
                -- only a LAST marble counts: flag 75, a 7 bonk on a marble 44 from home "was bad")
                if travelled >= JB.SEVEN_BONK_MIN_TRAVEL or toEntrance <= JB.THREAT_RANGE
                   or JB.goalCount(S, z.seat) >= JB.GOAL_SIZE - 1 then
                    n = n + 1
                end
            end
        end
    end
    return n
end

-- ... or it leaves a marble right at its entrance (2 or fewer cells), ready to go straight in (user, flag 64: "it
-- allowed me to play straight into my home")
JB.READY_FROM = 6
function JB.readiesEntry(S, act)
    for _, st in ipairs(act.steps or {}) do
        local m = S.marbles[st.mi]
        -- from out of small-card range (more than 6 away): a marble already 3 out gains nothing worth a 7 (user,
        -- 2026-11-11: Blue's 7 took Red from 3 out to 1 out, "bad 7 by blue, wasteful")
        if m.kind == 'R' and st.kind == 'R' and JB.distToEntrance(S, m.seat, m.p) > JB.READY_FROM
           and JB.distToEntrance(S, m.seat, st.p) <= 2 then return true end
    end
    return false
end

function JB.dropIdleSevens(S, acts)
    if JB.STRATEGY <= 0 then return acts end
    local kept, other = {}, false
    for _, a in ipairs(acts) do
        local idle7 = a.card == '7' and JB.qualityBumps(S, a) == 0 and not JB.goodFinishEntry(S, a) and not JB.readiesEntry(S, a)
            and JB.finishPackBonus(S, a) == 0   -- packing the finish is a purpose (set piece pack-with-7)
        -- same hard rule for an 8 (user, flag 70: "blue's 8 was really bad and had no purpose"): it must bonk
        -- someone or leave the marble within reach of its finish
        local idle8 = a.card == '8' and JB.worthyBumps(S, a) == 0 and not JB.readiesForFinish(S, a)
        if not idle7 and not idle8 then
            kept[#kept + 1] = a
            -- only a non-Joker move counts as a real alternative (user, 2026-11-11 game 3: Blue held 8 8 8 8 8 $; with
            -- every 8 dropped the Joker was all that was left, "terrible use of joker"). Jokers alone: keep the idle
            -- 7s/8s too and let the scores (and JB.holdJoker) decide.
            if a.card ~= '$' then other = true end
        end
    end
    return other and kept or acts
end

-- Card cost in context (S = position BEFORE the move).
