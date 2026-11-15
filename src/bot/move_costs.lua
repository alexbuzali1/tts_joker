-- bot/move_costs.lua
-- Per-move costs and bonuses on top of the board evaluation: what the card spent is worth keeping (JB.cardCost),
-- landing in danger, nudging a defender, clumping, passing your own finish entrance, closing gaps in a finish,
-- defence, the last marbles of a team... JB.cardAdjust adds them all up for one move.
local JB = JokerBot

-- Face cards (J, Q, K) are what gets marbles out of start, so as a plain board move they cost a lot
-- (JB.FACE_BOARD_COST), except: (1) defence, i.e. bonking an enemy within reach of its finish, and (2) late game,
-- when the mover has no marbles left in start. K and 10 are also the defence cards: from your exit cell a K lands on
-- the next enemy's finish entrance and a 10 lands where an enemy who comes out and plays an 8 back ends up, so they
-- cost more than a similar card (JB.CARD_COST) and nothing when they are used for that defence.
JB.FACE_BOARD_COST = { j = 20, q = 20, k = 60 }   -- J/Q 20 (was 45): below a 10 for plain movement (user)
function JB.defends(S, act)
    for _, b in ipairs(act.bumpList or {}) do
        local z = S.marbles[b.idx]
        if not b.friendly and z.kind == 'R' and JB.distToEntrance(S, z.seat, z.p) <= JB.THREAT_RANGE then return true end
    end
    return false
end
-- A 7 should (almost) always bonk someone or bring a marble into a finish; a 7 that does neither is "idle" and
-- costs JB.SEVEN_IDLE_COST (scaled by JB.STRATEGY), so the bot keeps it for a better moment.
JB.SEVEN_IDLE_COST = 60
-- true when the move brings a marble into a finish, or moves one deeper inside its finish (cleaning house)
function JB.entersFinish(S, act)
    for _, st in ipairs(act.steps or {}) do
        if st.kind == 'G' then return true end
    end
    return false
end

-- Same idea for an 8: it should bonk, or leave the moved marble within JB.THREAT_RANGE (13) of its own finish entrance
-- (getting ready to go in; e.g. coming out and playing the 8 back lands 3 short of the entrance).
JB.EIGHT_IDLE_COST = 40
function JB.readiesForFinish(S, act)
    for _, st in ipairs(act.steps or {}) do
        local m = S.marbles[st.mi]
        if st.kind == 'R' and JB.distToEntrance(S, m.seat, st.p) <= JB.THREAT_RANGE then return true end
    end
    return false
end

JB.CARD_COST_PLAIN = { k = 10, ['10'] = 1 }   -- K and 10 without the defence thrift (strategy 0)
-- Bigger tables: a lap is longer, so jumps (the Joker) are worth more in cells; Joker cost and margin scale with it.
function JB.boardScale(S) return math.max(1, (S.R - 5) / 67) end

function JB.cardCost(S, act)
    local c = act.card
    local s = JB.STRATEGY
    local cost = JB.CARD_COST[c] or 0
    if c == '$' then cost = cost * JB.boardScale(S) end
    if JB.CARD_COST_PLAIN[c] then cost = JB.CARD_COST_PLAIN[c] + s * (cost - JB.CARD_COST_PLAIN[c]) end
    if s <= 0 then return cost end
    -- an Ace used inside or into the finish is what it was saved for: free (user, 2026-11-11 game 5: Green's finish
    -- was jammed, it held an A and played a 3 instead)
    if c == 'a' and act.steps and act.steps[1] and act.steps[1].kind == 'G' then return 0 end
    local defence = JB.defends(S, act)
    if (c == 'k' or c == '10') and defence then return 0 end
    if c == '7' and JB.qualityBumps(S, act) == 0 and not JB.goodFinishEntry(S, act) and not JB.readiesEntry(S, act) and JB.finishPackBonus(S, act) == 0 then
        cost = cost + s * (JB.SEVEN_IDLE_COST - cost)
    end
    if c == '8' and JB.worthyBumps(S, act) == 0 and not JB.readiesForFinish(S, act) then
        cost = cost + s * (JB.EIGHT_IDLE_COST - cost)
    end
    return cost + JB.faceBoardExtra(S, act)
end

-- the part of a face card's cost that comes from using it as a board move (see JB.FACE_BOARD_COST)
function JB.faceBoardExtra(S, act)
    local c = act.card
    if JB.STRATEGY <= 0 or not JB.FACE_BOARD_COST[c] or not act.steps or not act.steps[1] then return 0 end
    if JB.defends(S, act) then return 0 end
    local mover = S.marbles[act.steps[1].mi]
    if mover.kind == 'S' then return 0 end                       -- leaving start
    for _, m in ipairs(S.marbles) do
        if m.seat == mover.seat and m.kind == 'S' then          -- not late game: marbles still in start
            local base = JB.CARD_COST[c] or 0
            if JB.CARD_COST_PLAIN[c] then base = JB.CARD_COST_PLAIN[c] + JB.STRATEGY * (base - JB.CARD_COST_PLAIN[c]) end
            return JB.STRATEGY * (JB.FACE_BOARD_COST[c] - base)
        end
    end
    return 0
end

-- Formation as a move rule (user): nudging the defender (the rearmost marble in its home stretch) forward while it
-- stays in the stretch, when that player has another marble on the board to move instead, is a wasted move.
-- No penalty when the nudge bonks someone (a better defensive spot is rewarded by the ambush bonus instead).
JB.NUDGE_PENALTY = 40
function JB.nudgePenalty(S, act)
    if not act.steps or #act.steps ~= 1 or (act.bumps or 0) > 0 then return 0 end
    local st = act.steps[1]
    local m = S.marbles[st.mi]
    if m.kind ~= 'R' or st.kind ~= 'R' or not JB.inHomeStretch(S, m) or not JB.needsDefender(S, m.seat) then return 0 end
    if not JB.inHomeStretch(S, { seat = m.seat, kind = 'R', p = st.p }) then return 0 end
    local dm = (m.p - JB.exitCell(m.seat)) % S.R
    local other = false
    for i, o in ipairs(S.marbles) do
        if i ~= st.mi and o.seat == m.seat and o.kind == 'R' then
            if JB.inHomeStretch(S, o) and (o.p - JB.exitCell(o.seat)) % S.R < dm then return 0 end   -- not the defender
            other = true
        end
    end
    -- a marble in start is an alternative too (bring it out instead); if every legal move is a nudge, they all
    -- get this penalty, so it changes nothing there
    -- (only when the exit cell is free: you can't come out onto your own marble - flag 8)
    local onExit = S.ring[JB.exitCell(m.seat)]
    if not other and not (onExit and S.marbles[onExit].seat == m.seat) then
        for _, o in ipairs(S.marbles) do if o.seat == m.seat and o.kind == 'S' then other = true end end
    end
    return other and JB.NUDGE_PENALTY or 0
end

-- Dead defender spot as a move rule (user, flag 31): the defender (rearmost marble in the home stretch) 2 or 3 past
-- its exit can't hit the next player's -8 spot (exit + 10, 8 or 7 ahead: an 8 can't go forward and a 7 rarely
-- can), so a move that leaves it there, while the next player still has marbles in start, costs
-- JB.DEAD_DEFENDER_PENALTY (only if it wasn't there already).
local function deadDefender(st, seat)
    local nxt = seat % st.N + 1
    local inStart = false
    for _, o in ipairs(st.marbles) do if o.seat == nxt and o.kind == 'S' then inStart = true end end
    if not inStart then return false end
    local rear
    for _, o in ipairs(st.marbles) do
        if o.seat == seat and JB.inHomeStretch(st, o) then
            local d = (o.p - JB.exitCell(seat)) % st.R
            if not rear or d < rear then rear = d end
        end
    end
    return rear ~= nil and JB.DEAD_DEFENDER_SPOT[rear] == true
end
function JB.deadDefenderPenalty(S, act)
    if not act.steps or not act.steps[1] or not act.state then return 0 end
    local seat = S.marbles[act.steps[1].mi].seat
    if deadDefender(act.state, seat) and not deadDefender(S, seat) then return JB.DEAD_DEFENDER_PENALTY end
    return 0
end

-- Push the runner, don't shuffle near start (user, flags 39/41/42 "push the furthest marble", 2026-11-11 game 3: "lots
-- of clumping near start going on instead of pushing a runner"). A move of a marble that is NOT the player's
-- front-most ring marble, starting and ending on its own side of the board (within JB.OWN_SIDE of its exit), while
-- another of its marbles is also on that side, costs JB.CLUMP_PENALTY. Bonks and finish entries are exempt; the
-- front-most marble may always move (that is pushing the runner). One defender near start is fine: it only counts
-- when 2+ marbles are there.
JB.CLUMP_PENALTY = 35   -- below a danger landing: safety beats formation (user, 2026-11-11 game 4 turn 143)
JB.OWN_SIDE = 17
function JB.clumpPenalty(S, act)
    if not act.steps or JB.STRATEGY <= 0 then return 0 end
    -- each part of a 7 too, for whichever player's marble it moves (user, 2026-11-11 game 6 flags 34/36: a 7 split
    -- moved a teammate's rear marble off its exit instead of the runner heading home)
    for _, st in ipairs(act.steps) do
        local m = S.marbles[st.mi]
        local bonkPart = st.kind == 'R' and S.ring[st.p] ~= nil and S.ring[st.p] ~= st.mi   -- this part bonks: exempt
        if m.kind == 'R' and st.kind == 'R' and not bonkPart then
            local seat = m.seat
            local function side(p) return (p - JB.exitCell(seat)) % S.R <= JB.OWN_SIDE end
            if side(m.p) and side(st.p) then
                local front, others = nil, 0
                for i, o in ipairs(S.marbles) do
                    if o.seat == seat and o.kind == 'R' then
                        if not front or JB.distToEntrance(S, seat, o.p) < JB.distToEntrance(S, seat, S.marbles[front].p) then front = i end
                        if i ~= st.mi and side(o.p) then others = others + 1 end
                    end
                end
                -- clumping = a rear marble shuffled near start while another is there, or while the runner could go
                if front ~= st.mi and (others > 0 or #act.steps > 1) then return JB.CLUMP_PENALTY end
            end
        end
    end
    return 0
end

-- Formation as a move rule (user, flag 12): bringing a marble out of start while that player already has 2 or more
-- marbles in its home stretch is clumping; move the furthest one along instead.
JB.CROWD_EXIT_PENALTY = 50
function JB.crowdExitPenalty(S, act)
    if not act.steps or not act.steps[1] then return 0 end
    local m = S.marbles[act.steps[1].mi]
    if m.kind ~= 'S' then return 0 end
    local n = 0
    for _, o in ipairs(S.marbles) do if o.seat == m.seat and JB.inHomeStretch(S, o) then n = n + 1 end end
    return n >= 2 and JB.CROWD_EXIT_PENALTY or 0
end

-- A Joker or an 8 that lands the moved marble somewhere dangerous (JB.threatsAt) is mostly wasted: penalty = 30
-- plus a share of that marble's value (35% per threat, up to all of it).
JB.SAFETY_CHECKED = { ['$'] = true, ['8'] = true }
-- Every other card: half that (user: "look for safe spots in front of an enemy", e.g. 3 behind an enemy, a J lands
-- 8 in front of it (safe) instead of a 4 landing 1 in front). A move rule, so the deeper search can't talk the bot
-- into ending in front of an enemy because it "will probably move past".
JB.OTHER_LANDING_SHARE = 0.5
-- the fixed part: a bonk also costs an exit card and a turn, however little the marble had travelled (2v2 all-bot
-- game 2026-11-11 #2: cheap early marbles kept landing 1-6 in front of enemies when a safe move was within ~10)
JB.LANDING_BASE = 50
-- 8s land in danger 1.6x as costly (user flagged unsafe 8s in flags 3, 8, 37, 62 and the 2v2 all-bot review: an 8
-- back from the exit that lands 6 in front of an enemy). Each half of a 7 is checked too (2v2 review, turn 34: the
-- teammate half moved a defender off its exit to land 6 in front of an enemy), at the ordinary share.
JB.EIGHT_LANDING_MULT = 1.6
function JB.landingPenalty(act)
    if not act.steps or not act.steps[1] then return 0 end
    local share = JB.SAFETY_CHECKED[act.card] and 1 or JB.OTHER_LANDING_SHARE
    -- (not an 8 that bonks: user, 2026-11-11, Blue's 8 back from 3 past its exit onto Black on Blue's own entrance
    -- "would have placed it at its own entrance" - a purposeful 8 isn't the wasted 8 the multiplier is for)
    -- (not an 8 that takes a marble back from on / right by its entrance: the alternative is running past it, a lap;
    -- game 5 turn 93. Its distance to the entrance after the 8 is then 8-11.)
    local rescue = false
    if act.card == '8' and act.steps[1] and act.steps[1].kind == 'R' then
        local mm = act.state.marbles[act.steps[1].mi]
        local d = JB.distToEntrance(act.state, mm.seat, act.steps[1].p)
        rescue = d >= 8 and d <= 11
    end
    if act.card == '8' and (act.bumps or 0) == 0 and not rescue then share = share * JB.EIGHT_LANDING_MULT end
    local S2 = act.state
    local steps = act.card == '7' and act.steps or { act.steps[1] }
    local total = 0
    for _, st in ipairs(steps) do
        local m = S2.marbles[st.mi]
        if m.kind == 'R' then
            local par = m.seat % 2
            local t = JB.threatsAt(S2, m.p, par, JB.exitThreats(S2, par), true)   -- real threats only (flag 45)
            -- the very next player moves first: a threat from it counts twice (user, 2026-11-11 game 4 turn 143:
            -- Red's 5 landed 4 in front of Black, who sat on its exit and moved next)
            if t > 0 and act.seat then
                local nxt = act.seat % S2.N + 1
                if not JB.sameTeam(nxt, m.seat) then
                    for back = 1, JB.THREAT_RANGE do
                        if back ~= 7 and back ~= 8 then
                            local i = S2.ring[JB.wrap(S2, m.p - back)]
                            if i and S2.marbles[i].seat == nxt then t = t + 1; break end
                        end
                    end
                end
            end
            if t > 0 then total = total + share * (JB.LANDING_BASE + math.min(1, 0.35 * t) * JB.pieceValue(S2, m)) end
        end
    end
    return total
end

-- Cleaning house (user, flags 18/19: "not every bonk is a good bonk"): a move that closes gaps in the mover's finish
-- or a teammate's (a 7 split) (fewer empty cells deeper than a marble) is worth JB.CLEAN_HOUSE_BONUS per gap closed, on top of the evaluation.
-- An untidy finish needs exact small cards later and blocks marbles behind it; a 7 is the best tool to fix it.
JB.CLEAN_HOUSE_BONUS = 220      -- per gap closed (was 100, then 130): clearing gaps is very high priority
JB.GAP_PENALTY = 100            -- per gap made beyond the first (max 2 counted)
JB.FIRST_GAP_PENALTY = 40
-- What a move that makes `gaps` new gaps in `seat`'s finish is charged as a move (cleanHouseBonus), on top of the
-- board's JB.UNTIDY_PENALTY per gap. The first gap is cheaper (user, flag 43: "playing the 3 and fixing the gap later
-- makes more sense"), more gaps cost JB.GAP_PENALTY (max 2 counted).
-- Escaping a real threat into the finish (user, 2026-11-11: Red 1 out with Green 6 behind "should enter to avoid
-- getting bonked even though it doesn't have a clean enter"; "it should depend, judgement based but 10-13 is def still
-- a threat"): part of the move charge and of the board's gap penalty (at most 2 gaps) is forgiven, JB.ESCAPE_RELIEF
-- with one real threat on the marble, all of it with two or more. Can be negative (a refund).
function JB.gapMoveCharge(S, act, seat, gaps)
    -- the cheap first gap only for a tidy finish; making an untidy finish worse costs the full rate (game 5 flag 30:
    -- entering cell 1 behind a jam made Green need a third Ace)
    local messy = JB.untidyCells(S, seat) > 0
    local first = messy and (JB.GAP_PENALTY + JB.JAM_PENALTY) or JB.FIRST_GAP_PENALTY
    local cost = first + JB.GAP_PENALTY * math.min(1, gaps - 1)
    local threats = 0
    for _, s2 in ipairs(act.steps) do
        local z = S.marbles[s2.mi]
        if s2.kind == 'G' and z.kind == 'R' and z.seat == seat then
            local par = seat % 2
            threats = math.max(threats, JB.threatsAt(S, z.p, par, JB.exitThreats(S, par), true))
        end
    end
    if threats > 0 then
        local f = math.min(1, JB.ESCAPE_RELIEF + JB.ESCAPE_RELIEF_PER_THREAT * (threats - 1))
        return cost - f * (cost + JB.UNTIDY_PENALTY * math.min(3, gaps))
    end
    return cost
end

function JB.cleanHouseBonus(S, act)
    if not act.state or not act.steps then return 0 end
    local bonus, done = 0, {}
    for _, st in ipairs(act.steps) do
        local seat = S.marbles[st.mi].seat
        if not done[seat] then
            done[seat] = true
            local fixed = JB.untidyCells(S, seat) - JB.untidyCells(act.state, seat)
            if fixed > 0 then bonus = bonus + JB.CLEAN_HOUSE_BONUS * fixed
            -- making a mess costs too (flags 50/51: a 7 entering to cell 2 with cell 3 empty "didn't even move it all
            -- the way in"); at most 2 gaps count, so entering an empty finish shallow is still better than passing it
            -- (7s only: a split can choose how deep to go; with any other card the entry is fixed, and the
            -- alternative is often passing the entrance, a whole lap - flag 43)
            -- (now any card: an all-bot game had Red enter cell 2 with 3-5 empty, Blue two entries with gaps; the
            -- user: "really bad". One gap still beats running past the entrance for a whole lap - flag 43)
            -- the first gap is cheaper (user on flag 43: "playing the 3 and fixing the gap later makes more sense"
            -- than backing off or running past); every further gap costs the full JB.GAP_PENALTY
            elseif fixed < 0 then bonus = bonus - JB.gapMoveCharge(S, act, seat, -fixed)
            end
        end
    end
    return bonus
end

-- Defence beats offence (user, flag 47): bonking an enemy marble that is close to its finish, with any card, earns
-- a bonus that grows with how many marbles that player already has home. Its LAST marble (4 home) trumps
-- everything: JB.LAST_BALL_BONUS wherever it is on the ring. (The Joker also has its own JB.defensiveBonus.)
JB.LAST_BALL_BONUS = 300
JB.DEFENCE_BONUS_PER_HOME = 40
JB.IMMINENT_DEFENCE_BONUS = 40
-- marbles a team (parity) still has to bring home
function JB.teamLeft(S, parity)
    local n = 0
    for _, m in ipairs(S.marbles) do if m.seat % 2 == parity and m.kind ~= 'G' then n = n + 1 end end
    return n
end
-- Race mode (user, flag 54: "it should be focused on winning ... we have 1 more ball"): when your team has fewer
-- marbles left than the enemy team, ordinary defence counts JB.RACE_DEFENCE_SHARE; a last marble still counts fully.
JB.RACE_DEFENCE_SHARE = 0.25
function JB.defenceBonus(S, act)
    local bonus = 0
    for _, b in ipairs(act.bumpList or {}) do
        local z = S.marbles[b.idx]
        -- not on (or just past) its own exit: it comes straight back out and bonks whoever bonked it there
        -- (user, flag 78; a good time for that is when they've been burning - the bot doesn't track that)
        local cheap = z.kind == 'R' and (z.p - JB.exitCell(z.seat)) % S.R < JB.CHEAP_BONK_RANGE and not JB.BURNING[z.seat]
        if not b.friendly and z.kind == 'R' and not cheap then
            local home = JB.goalCount(S, z.seat)
            if home >= JB.GOAL_SIZE - 1 and (act.card ~= '$' or JB.distToEntrance(S, z.seat, z.p) <= JB.JOKER_DEFENCE_RANGE) then
                -- full when it is close to finishing; a last marble far away is less urgent (flag 79: finishing a
                -- teammate's last marble beat bonking an enemy's last marble 48 from home)
                local d = JB.distToEntrance(S, z.seat, z.p)
                local f = d <= JB.THREAT_RANGE and 1 or math.max(0.25, 1 - (d - JB.THREAT_RANGE) / 50)
                bonus = bonus + JB.LAST_BALL_BONUS * f
            elseif home >= JB.DEFENSIVE_MIN_HOME and JB.distToEntrance(S, z.seat, z.p) <= JB.THREAT_RANGE and act.card ~= '$' then
                -- (not with a Joker: a defensive Joker is for a LAST marble only - game 6 flag 40)
                local ours, theirs = JB.teamLeft(S, 1 - z.seat % 2), JB.teamLeft(S, z.seat % 2)
                local share = ours < theirs and JB.RACE_DEFENCE_SHARE or 1
                bonus = bonus + share * JB.DEFENCE_BONUS_PER_HOME * home
            end
            -- about to go in (6 or fewer from its finish) with 2+ home: bonking it is worth another
            -- JB.IMMINENT_DEFENCE_BONUS, and with 2 home it counts like 3 (user, 2026-11-11: "black should have bonked
            -- blue with the king" - Blue, 2 home, on its own entrance; Black's 8 bonked a Red marble 10 out of start).
            -- Not for the Joker (flag 48: a Joker on a player with 2 home was "bizarre and unforced").
            local d = JB.distToEntrance(S, z.seat, z.p)
            if act.card ~= '$' and home >= 2 and home < JB.GOAL_SIZE - 1 and d <= 6 then
                local ours, theirs = JB.teamLeft(S, 1 - z.seat % 2), JB.teamLeft(S, z.seat % 2)
                local share = ours < theirs and JB.RACE_DEFENCE_SHARE or 1
                local base = home >= JB.DEFENSIVE_MIN_HOME and 0 or JB.DEFENCE_BONUS_PER_HOME * home
                bonus = bonus + share * (base + JB.IMMINENT_DEFENCE_BONUS)
            end
        end
    end
    return bonus
end

-- Don't stop 2-7 behind the next enemy's marble (user, 2026-11-11: Blue's 9 went "past the defensive position and
-- letting green 8 behind it"): that enemy plays its 8 backwards and lands 1-6 behind you, and its teammate moves
-- before you do (Black's 7 then bonked Blue with Green's marble). Only the next seat: after any other enemy's 8 you
-- move first and can get away. Costs JB.EIGHT_BACK_PENALTY per marble landed there (not when that move bonks).
JB.EIGHT_BACK_PENALTY = 30
function JB.eightBackPenalty(S, act)
    if not (act.state and act.steps and act.seat) or JB.STRATEGY <= 0 then return 0 end
    local T = act.state
    local nextSeat = act.seat % T.N + 1
    if JB.sameTeam(nextSeat, act.seat) then return 0 end
    local pen = 0
    for _, st in ipairs(act.steps) do
        if st.kind == 'R' and S.marbles[st.mi].p ~= st.p then
            local me = T.marbles[st.mi]
            for _, z in ipairs(T.marbles) do
                if z.kind == 'R' and z.seat == nextSeat then
                    local ahead = (z.p - st.p) % T.R
                    local back = ((z.p - 8 - 1) % T.R) + 1
                    if ahead >= 2 and ahead <= 7 and not (T.ring[back] and T.marbles[T.ring[back]].seat == nextSeat)
                       and not JB.sameTeam(me.seat, nextSeat) then
                        pen = pen + JB.EIGHT_BACK_PENALTY
                        break
                    end
                end
            end
        end
    end
    -- the next enemy still in start: when it comes out, its 8 back lands on its -8 spot; stopping 1-6 past that spot
    -- leaves you right in front of it (set piece ambush-not-minus-8; user, flag 41: wait BEHIND the -8 spot)
    if not JB.sameTeam(nextSeat, act.seat) and not JB.BURNING[nextSeat] then
        local inStart = false
        for _, z in ipairs(T.marbles) do if z.seat == nextSeat and z.kind == 'S' then inStart = true end end
        if inStart then
            local spot = ((JB.exitCell(nextSeat) - 8 - 1) % T.R) + 1
            for _, st in ipairs(act.steps) do
                local past = (st.p - spot) % T.R
                if st.kind == 'R' and S.marbles[st.mi].p ~= st.p and past >= 1 and past <= 6
                   and JB.sameTeam(T.marbles[st.mi].seat, act.seat) then pen = pen + JB.PAST_SPOT_PENALTY; break end
            end
        end
    end
    return JB.STRATEGY * pen
end
JB.PAST_SPOT_PENALTY = 20

-- Never land on an enemy's -8 spot or finish entrance (user, flag 41; JB.exitThreats .spots). Waiting behind them is
-- good (ambush), standing on them gets you bonked "out of nowhere". Bonking someone there is still fine.
JB.SPOT_LANDING_PENALTY = 50
JB.EXIT_SQUAT_PENALTY = 40     -- landing on an enemy's exit cell while it has marbles in start (x1.5 if it moves next)
function JB.spotLandingPenalty(S, act)
    if not act.steps or not act.state then return 0 end
    local pen = 0
    for _, st in ipairs(act.steps) do
        local m = S.marbles[st.mi]
        -- exempt only when THIS marble bonks someone on that spot (flag 67: the other half of a 7 bonked elsewhere)
        -- (a bonk there still costs half: user, 2026-11-11, Blue's forced Joker onto Green on Black's -8 spot, with
        -- Black still in start, was "a risky joker" when a Joker onto Green's other marble was safer)
        local occupant = S.ring[st.p]
        if st.kind == 'R' then
            -- (exitThreats leaves out the -8 spot of an enemy with nobody in start or that is burning: user,
            -- 2026-11-11 "its ok to land on the negative 8 if that ball is burning or has nobody at start")
            local threats = JB.exitThreats(act.state, m.seat % 2)
            if threats.spots[st.p] then pen = pen + ((occupant and occupant ~= st.mi) and 0.5 or 1) * JB.SPOT_LANDING_PENALTY end
            -- an enemy's exit cell while it has marbles in start (not burning): it comes out onto you. Bonking the
            -- marble sitting there doesn't excuse it - that only puts one more in its start and costs it nothing but
            -- an exit card (user, 2026-11-12 flag 42: Red's Q bonked Cyan on Cyan's exit, Cyan, next to move, came
            -- straight out and bonked Red back). Worse when that enemy moves next.
            if threats[st.p] then
                local owner = math.floor((st.p - 8) / 18) + 1
                local nextSeat = (act.seat or m.seat) % S.N + 1
                pen = pen + JB.EXIT_SQUAT_PENALTY * (owner == nextSeat and 1.5 or 1)
            end
        end
    end
    return pen
end

-- Don't give up your finish entrance (user, flag 73: "it should wait as long as possible before giving up the finish
-- entrance spot ... I'd rather it take the bonk"): a marble within 3 of its entrance that moves past it, staying on
-- the ring (another lap), costs JB.PASS_ENTRANCE_PENALTY. Applies to any marble within JB.THREAT_RANGE (13) of its
-- entrance (2v2 stress test: 6 away holding 4 4, a 9 ran past the entrance to dodge an enemy 2 behind; a whole lap
-- thrown away to avoid a bonk risk).
JB.PASS_ENTRANCE_PENALTY = 60
JB.PASS_ENTRANCE_RANGE = JB.THREAT_RANGE
-- from on or right by the entrance (3 or less): a sure lap thrown away; the user would rather take the bonk (flag 73,
-- game 5 turn 93: on its entrance with no card to go in, Black ran a 9 past instead of an 8 back to 8 out with the 10)
JB.PASS_ENTRANCE_NEAR_PENALTY = 250
function JB.passEntrancePenalty(S, act)
    local pen = 0
    -- a marble a friendly bonk earlier in the same 7 sent to its own entrance starts its part there (user, 2026-11-11
    -- game 3: Red's 7 bonked Blue onto Blue's entrance, then "moved blue forwards instead of in")
    if act.card == '8' then return 0 end   -- an 8 goes backwards: it never runs past the entrance (game 5 bug)
    -- follow the parts of a 7 in order: a friendly bonk sends that marble to its own entrance, and only a LATER part
    -- that carries it on from there runs past (game 6: the part that moved Blue came first, then Red bonked it)
    local pos = {}
    for _, st in ipairs(act.steps or {}) do
        local m = S.marbles[st.mi]
        local cur = pos[st.mi] or (m.kind == 'R' and m.p or nil)
        local from = cur and JB.distToEntrance(S, m.seat, cur) or nil
        if from and st.kind == 'R' and from <= JB.PASS_ENTRANCE_RANGE
           and JB.distToEntrance(S, m.seat, st.p) > from then
            pen = pen + (from <= 3 and JB.PASS_ENTRANCE_NEAR_PENALTY or JB.PASS_ENTRANCE_PENALTY)
        end
        if st.kind == 'R' then
            -- a teammate marble standing where this part lands is bonked to its own entrance
            for i, o in ipairs(S.marbles) do
                local op = pos[i] or (o.kind == 'R' and o.p or nil)
                if i ~= st.mi and op == st.p and JB.sameTeam(o.seat, m.seat) then pos[i] = JB.entrance(o.seat) end
            end
            pos[st.mi] = st.p
        end
    end
    return pen
end

-- Get in range of an urgent enemy (user, flag 76: "caught lacking by being 8 behind an important defense situation, it
-- should move forward to give me the chance to 7 it"): an enemy marble within 13 of its finish whose player has 3+
-- home is urgent. Moving one of your team's marbles to 1-6 cells behind it (from out of that range) lets you or a
-- teammate (7 split, small cards) bonk it next: +JB.DEFENCE_SETUP_BONUS.
JB.DEFENCE_SETUP_BONUS = 50
function JB.defenceSetupBonus(S, act)
    if not act.steps or not act.state or JB.STRATEGY <= 0 then return 0 end
    local T = act.state
    for _, st in ipairs(act.steps) do
        local m = S.marbles[st.mi]
        if st.kind == 'R' then
            for _, z in ipairs(T.marbles) do
                if z.kind == 'R' and not JB.sameTeam(z.seat, m.seat) and JB.goalCount(T, z.seat) >= JB.DEFENSIVE_MIN_HOME
                   and JB.distToEntrance(T, z.seat, z.p) <= JB.THREAT_RANGE then
                    local after = (z.p - st.p) % T.R
                    local before = m.kind == 'R' and (z.p - m.p) % S.R or 99
                    if after >= 1 and after <= 6 and not (before >= 1 and before <= 6) then return JB.DEFENCE_SETUP_BONUS end
                end
            end
        end
    end
    return 0
end

-- Completing a player (user, flag 79: "that move should be very highly valued, only beaten by a game saving defensive
-- play"): a move that brings a player's last marble home earns JB.PLAYER_DONE_BONUS, just under the full last-marble
-- defence bonus (JB.LAST_BALL_BONUS). A finished player then plays its cards on its teammates' marbles.
JB.PLAYER_DONE_BONUS = 250
function JB.playerDoneBonus(S, act)
    if not act.state then return 0 end
    local bonus, seen = 0, {}
    for _, st in ipairs(act.steps or {}) do
        local seat = S.marbles[st.mi].seat
        if not seen[seat] then
            seen[seat] = true
            if JB.goalCount(act.state, seat) == JB.GOAL_SIZE and JB.goalCount(S, seat) < JB.GOAL_SIZE then
                bonus = bonus + JB.PLAYER_DONE_BONUS
            end
        end
    end
    return bonus
end

-- Keep a last marble within one card of home (2v2 all-bot game, turn 177: Black, finished, moved Green's last marble
-- 8 backwards, out of reach, when a 2 left it a 4 away from winning the game; in TTS the search rarely looks far
-- enough to see the teammate's turn). A player's LAST marble is "in reach" when one card (1-13, not 8) takes it
-- exactly into its deepest free finish cell. Moving it into reach earns, out of reach costs, JB.REACH_LAST (or
-- JB.REACH_TEAM_LAST when it is the team's last marble: that card wins the game).
JB.REACH_LAST = 60
JB.REACH_TEAM_LAST = 150
local function lastInReach(st, seat)
    local onRing
    for _, m in ipairs(st.marbles) do
        if m.seat == seat and m.kind ~= 'G' then
            if onRing or m.kind ~= 'R' then return nil end     -- not the last marble, or it is still in start
            onRing = m
        end
    end
    if not onRing then return nil end
    local deepest = 0
    for j = JB.GOAL_SIZE, 1, -1 do if not st.goal[seat][j] then deepest = j; break end end
    local d = JB.distToEntrance(st, seat, onRing.p) + deepest
    return d >= 1 and d <= 13 and d ~= 8
end
function JB.finishReachBonus(S, act)
    if not act.state or not act.steps or JB.STRATEGY <= 0 then return 0 end
    local bonus, seen = 0, {}
    for _, st in ipairs(act.steps) do
        local seat = S.marbles[st.mi].seat
        if not seen[seat] then
            seen[seat] = true
            local before, after = lastInReach(S, seat), lastInReach(act.state, seat)
            if before ~= nil and after ~= nil and before ~= after then
                local teamLast = JB.teamLeft(act.state, seat % 2) == 1
                local v = teamLast and JB.REACH_TEAM_LAST or JB.REACH_LAST
                -- coming into reach only counts on a safe spot (user, 2026-11-11: Blue's 10 put its last marble in
                -- reach, 2 in front of Black on its exit, "landing unsafely to get bonked by black")
                if after then
                    local m = act.state.marbles[st.mi]
                    local par = seat % 2
                    if m.kind == 'R' then
                        local ex = JB.exitThreats(act.state, par)
                        if JB.threatsAt(act.state, m.p, par, ex, true) > 0 or ex[m.p] then v = 0 end
                    end
                end
                bonus = bonus + (after and v or -v)
            end
        end
    end
    return bonus
end

-- Clearing up the finish comes first (user, 2026-11-11 game 5: "priority should almost always be to clear up finish,
-- besides the really important stuff like game saving defense ... or any defense that prevents an enemy from entering
-- its finish without the use of a joker"). Every cell a marble moves deeper inside its own finish earns
-- JB.FINISH_PACK_BONUS: packing from the deep end frees the shallow cells for the marbles still coming in (Green had
-- cells 1-3 and 5 full, its last marble blocked 3 out, an A in hand, and played a 3).
JB.FINISH_PACK_BONUS = 100
function JB.finishPackBonus(S, act)
    if not act.steps or JB.STRATEGY <= 0 then return 0 end
    local b = 0
    for _, st in ipairs(act.steps) do
        local m = S.marbles[st.mi]
        if m.kind == 'G' and st.kind == 'G' and st.p > m.p then b = b + JB.FINISH_PACK_BONUS * (st.p - m.p) end
    end
    return b
end
-- ... and the defence that ranks with it: a bonk (not with a Joker) of an enemy marble within JB.THREAT_RANGE of its
-- finish entrance, whatever its home count, earns JB.ENTRY_DEFENCE_BONUS (cheap bonks on its own exit excepted). With
-- an Ace (cost 35) it comes out about even with a cell of packing, as the user asked.
JB.ENTRY_DEFENCE_BONUS = 50
JB.ENTRY_DEFENCE_PER_HOME = 25     -- 0 home 50, 1: 75, 2: 100, 3: 125
function JB.entryDefenceBonus(S, act)
    if act.card == '$' or JB.STRATEGY <= 0 then return 0 end
    for _, b in ipairs(act.bumpList or {}) do
        local z = S.marbles[b.idx]
        if not b.friendly and z.kind == 'R' and JB.distToEntrance(S, z.seat, z.p) <= JB.THREAT_RANGE then
            -- scaled by how close that player is to finishing (turn 67, game 4: stopping a 1-home player's marble was
            -- worth less than putting a teammate's 4th marble home)
            return JB.ENTRY_DEFENCE_BONUS + JB.ENTRY_DEFENCE_PER_HOME * JB.goalCount(S, z.seat)
        end
    end
    return 0
end

-- A clean finish entry beats a bonk (user, 2026-11-11 game 4: "clean finish entrance outweighs bonk unless the bonk
-- was defending an enemy from entering their finish"; turn 67 Red's K bonk instead of a 7 putting teammate Blue's
-- marble cleanly home was "really bad"). A move that brings a marble (own or a teammate's) into the finish, leaving no
-- gap, earns JB.CLEAN_ENTRY_BONUS. Defensive bonks (an enemy within 13 of its finish) keep their own bonuses.
JB.CLEAN_ENTRY_BONUS = 60
JB.CLEAN_ENTRY_PER_HOME = 20
function JB.cleanEntryBonus(S, act)
    if not (act.steps and act.state) or JB.STRATEGY <= 0 then return 0 end
    for _, st in ipairs(act.steps) do
        local m = S.marbles[st.mi]
        if st.kind == 'G' and m.kind == 'R' and act.seat and JB.sameTeam(m.seat, act.seat)
           and JB.untidyCells(act.state, m.seat) == 0 then
            -- more the closer it brings that player to finishing (a 4th marble home: 60 + 3 x 20)
            return JB.CLEAN_ENTRY_BONUS + JB.CLEAN_ENTRY_PER_HOME * (JB.goalCount(act.state, m.seat) - 1)
        end
    end
    return 0
end

-- Fire the park (user, flags 46/66: park on a teammate's exit and "their next exit card catapults you to your
-- entrance"): coming out of start onto a teammate's marble parked on your exit sends it to its own entrance. The
-- board score saw little in it (the marble then sits on its entrance, an exposed spot), so in two 2v2 all-bot games
-- 2026-11-11 the bots set parks up and then didn't use them (turns 62, 63 / 122, 126, 132). +JB.CATAPULT_BONUS when
-- the catapulted marble was 13+ from its entrance.
JB.CATAPULT_BONUS = 50
function JB.catapultBonus(S, act)
    -- (not the Joker: flag 25, it waits for a bigger payoff than a catapult)
    if not act.steps or not act.steps[1] or JB.STRATEGY <= 0 then return 0 end   -- (Jokers too: JB.holdJoker's 250 margin still saves an unforced one)
    -- any card and any marble, not only coming out of start (game 6 review: a dozen catapults of 26-67 cells went
    -- unused, e.g. Red's 7 combos sending Blue home, Blue's 10 sending Red 67 cells)
    for _, b in ipairs(act.bumpList or {}) do
        local z = S.marbles[b.idx]
        if b.friendly and z.kind == 'R' and act.seat and z.seat ~= act.seat and JB.sameTeam(z.seat, act.seat)
           and JB.distToEntrance(S, z.seat, z.p) >= JB.THREAT_RANGE then
            return JB.CATAPULT_BONUS
        end
    end
    return 0
end

-- Coming out onto an enemy that sits on your exit cell (user, flag 38: "should have used the king and bonked
-- yellow"): a sure bonk that also clears your way out beats keeping the card for a maybe (e.g. an ambush bonus).
JB.EXIT_BONK_BONUS = 60
function JB.exitBonkBonus(S, act)
    if not act.steps or not act.steps[1] then return 0 end
    local m = S.marbles[act.steps[1].mi]
    if m.kind ~= 'S' then return 0 end
    for _, b in ipairs(act.bumpList or {}) do
        local z = S.marbles[b.idx]
        if not b.friendly and z.kind == 'R' and z.p == JB.exitCell(m.seat) then return JB.EXIT_BONK_BONUS end
    end
    return 0
end

function JB.cardAdjust(S, act)
    return JB.STRATEGY * (JB.defensiveBonus(S, act) + JB.chainBonus(act) - JB.landingPenalty(act) - JB.nudgePenalty(S, act)
                          - JB.crowdExitPenalty(S, act) - JB.clumpPenalty(S, act) - JB.deadDefenderPenalty(S, act) - JB.spotLandingPenalty(S, act) - JB.eightBackPenalty(S, act) - JB.passEntrancePenalty(S, act) + JB.defenceSetupBonus(S, act) + JB.finishReachBonus(S, act) + JB.playerDoneBonus(S, act) + JB.cleanHouseBonus(S, act)
                          + JB.exitBonkBonus(S, act) + JB.catapultBonus(S, act) + JB.cleanEntryBonus(S, act) + JB.finishPackBonus(S, act) + JB.entryDefenceBonus(S, act) + JB.defenceBonus(S, act))
           - JB.cardCost(S, act)
end
