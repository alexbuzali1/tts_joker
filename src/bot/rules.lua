-- bot/rules.lua
-- The rules of Joker for the bots: the board model, how a card moves a marble, bonks (JB.land), and every legal move
-- for a hand (JB.legalActions). Pure Lua with no Tabletop Simulator calls, so it runs in the tests too
-- (tests/test_bot_rules.lua). The bot's judgement is in the other bot/ files:
--   evaluate.lua    how good a board is for a team (JB.evaluate)
--   setups.lua      bonuses for moves that set something up for later turns
--   move_costs.lua  per-move costs and bonuses (which card it spends, where it lands...)
--   hand.lua        choices that depend on the rest of the hand (keep the Joker, which card to burn...)
--   search.lua      looks a few turns ahead and picks the move (difficulty levels 1-9)
--   engine.lua      the experimental level-10 engine
--
-- BOARD MODEL (derived from board.lua / the Google Sheets rules)
--   N seats, seat s = 1..N (seat = index in PLAYER_COLORS[N]).
--   Ring of R = 18*N cells, numbered 1..R, moving "forward" = increasing number (wraps).
--   Seat s owns ring cells (s-1)*18+1 .. s*18.
--     entrance(s) = (s-1)*18 + 3   -- "front of finish". Also where a bonked teammate is sent.
--     exitCell(s) = (s-1)*18 + 8   -- the cell a marble lands on when it leaves start (entrance + 5)
--   Finish ("goal") cells G1..G5 hang off the entrance: a marble passing entrance(s) may turn into goal 1..5.
--   Start: 5 slots per seat, interchangeable, so position of a start marble is just kind='S'.
--
-- MARBLE: { seat=1..N, kind='S'|'R'|'G', p=<ring cell | goal index | 0> }
-- STATE : { N=, R=, marbles={...}, ring={[cell]=marbleIndex}, goal={[seat]={[j]=marbleIndex}} }

JokerBot = JokerBot or {}
local JB = JokerBot

-- JB.STRATEGY (0..1): how much of the "strategy" rules apply. Parking on a teammate's exit, the extra enemy-8-ahead
-- threat, face-card / K / 10 thrift, defensive and multi-bonk Joker bonuses scale with it. bot_search.lua sets it from
-- the difficulty level for each search (low levels play plainly); 1 when the bot_logic chooser is used on its own.
JB.STRATEGY = 1
JB.GOAL_SIZE = 5
JB.PER_SIDE = 18
JB.THREAT_RANGE = 13

-- Cards: a 2..10 j q k are single moves (8 goes backwards), 7 is a split, $ is the joker.
JB.CARD_STEPS = { a = 1, ['2'] = 2, ['3'] = 3, ['4'] = 4, ['5'] = 5, ['6'] = 6, ['8'] = -8,
                  ['9'] = 9, ['10'] = 10, j = 11, q = 12, k = 13, ['7'] = 7 }
JB.EXIT_CARDS = { a = true, j = true, q = true, k = true, ['$'] = true }

-- Small penalty for spending a card that is more useful later (keeps aces/faces/jokers for leaving start).
-- The Joker is worth 160: a typical Joker jump scores ~130 more than the best other move, so a lower cost made
-- the bot spend it almost every turn it held one (93%). At 160 it plays it on ~30% of those turns, when the jump
-- is clearly better; in simulated games 160 beat the old 16 by 32-28 (200 lost 26-34). See defensiveBonus and
-- chainBonus below for the situations where a Joker is worth spending anyway.
JB.CARD_COST = { ['2'] = 0, ['3'] = 0, ['4'] = 0, ['5'] = 0, ['6'] = 0, ['8'] = 1, ['9'] = 1, ['10'] = 12,
                 ['7'] = 20, j = 7, q = 7, k = 12, a = 60, ['$'] = 160 }   -- a: 60 (was 35, 20; user 2026-11-12 flag 41: an Ace spent on a 1-step setup when a 5 did nearly as well - "aces are still undervalued when they aren't making high impact moves"; free into the finish, see JB.cardCost); 7: 20 (was 4; game 6 flag 33: a 7 spent where the 4 alone did the same)
-- 10 = 12 and A = 20 (user; flag 44: "ace is more valuable than both [J and Q]"): "10s are valuable" (defence: from your exit a 10 hits the next player's -8 spot; free
-- when it defends, see JB.cardCost) and "aces are very useful in niche situations so I like to hold them".
-- E.g. a target 20 away with 10 10 J 9 in hand: J + 9, not both 10s.
-- K costs more than J and Q (user, flags 23/24: a bot left start with a K while holding J or Q; the K is the
-- defence card, see JB.cardCost). When it is unclear, play the card you hold several of (JB.handAdjust).

-- If true, a 7 may also be split between two marbles of the SAME player (house-rule switch).
-- The Google Sheets game only allows "your marble + a teammate's marble".
JB.ALLOW_OWN_SPLIT = false

------------------------------------------------------------------------
-- state helpers
------------------------------------------------------------------------
function JB.entrance(seat) return (seat - 1) * JB.PER_SIDE + 3 end
function JB.exitCell(seat) return (seat - 1) * JB.PER_SIDE + 8 end
function JB.wrap(S, r) return ((r - 1) % S.R) + 1 end
function JB.sameTeam(a, b) return a % 2 == b % 2 end

local function buildOcc(S)
    S.ring, S.goal = {}, {}
    for s = 1, S.N do S.goal[s] = {} end
    for i, m in ipairs(S.marbles) do
        if m.kind == 'R' then S.ring[m.p] = i
        elseif m.kind == 'G' then S.goal[m.seat][m.p] = i end
    end
    return S
end

-- list = array of {seat=, kind=, p=}
function JB.newState(N, list)
    local S = { N = N, R = JB.PER_SIDE * N, marbles = {} }
    for i, m in ipairs(list) do S.marbles[i] = { seat = m.seat, kind = m.kind, p = m.p or 0 } end
    return buildOcc(S)
end

function JB.clone(S)
    local c = { N = S.N, R = S.R, marbles = {} }
    for i, m in ipairs(S.marbles) do c.marbles[i] = { seat = m.seat, kind = m.kind, p = m.p } end
    return buildOcc(c)
end

-- distance (forward steps) from ring cell p to the entrance of `seat`
function JB.distToEntrance(S, seat, p)
    return (JB.entrance(seat) - p) % S.R
end

local function ownAtRing(S, r, seat)
    local i = S.ring[r]
    return i ~= nil and S.marbles[i].seat == seat
end

function JB.goalCount(S, seat)
    local n = 0
    for j = 1, JB.GOAL_SIZE do if S.goal[seat][j] then n = n + 1 end end
    return n
end

function JB.isFinished(S, seat) return JB.goalCount(S, seat) == JB.GOAL_SIZE end

-- A teammate marble is ELIGIBLE to take part of a split 7 when it is on the ring, or in the finish
-- with a free cell directly ahead of it. Marbles still in start, or packed into the finish with
-- nowhere to move, are not eligible.
local function eligibleMarble(S, mi)
    local m = S.marbles[mi]
    if m.kind == 'R' then return true end
    if m.kind == 'G' then return m.p < JB.GOAL_SIZE and not S.goal[m.seat][m.p + 1] end
    return false
end

-- 7 RULE (house rule as described by the players):
--   normal player   : must split (own marble + a teammate's marble) when any teammate has an eligible marble;
--                     otherwise the 7 is a straight 7 on its own marble.
--   finished player : plays for its teammates; must split between marbles of TWO DIFFERENT teammates when two
--                     teammates each have an eligible marble; otherwise it is a straight 7.
function JB.sevenMustSplit(S, seat)
    local owners, n = {}, 0
    for i, m in ipairs(S.marbles) do
        if m.seat ~= seat and JB.sameTeam(m.seat, seat) and not owners[m.seat] and eligibleMarble(S, i) then
            owners[m.seat] = true
            n = n + 1
        end
    end
    if JB.isFinished(S, seat) then return n >= 2 end
    return n >= 1
end

-- kept for older callers: a "straight 7" is a 7 that is NOT required to be split
function JB.isStraight7(S, seat) return not JB.sevenMustSplit(S, seat) end

------------------------------------------------------------------------
-- movement
------------------------------------------------------------------------
-- Where does marble mi end up after `v` steps (v<0 = backwards)? Returns kind, p or nil if illegal.
-- `enter` = turn into the finish when passing the entrance (only matters when v goes past it).
function JB.numericTarget(S, mi, v, enter)
    local m = S.marbles[mi]
    local q = m.seat
    if m.kind == 'S' then return nil end
    if m.kind == 'G' then
        if v < 0 then return nil end                           -- can't back out of the finish
        local j = m.p + v
        if j > JB.GOAL_SIZE then return nil end                -- overshoot
        for k = m.p + 1, j do if S.goal[q][k] then return nil end end
        return 'G', j
    end
    if v > 0 then
        local d = JB.distToEntrance(S, q, m.p)
        if v > d and enter then
            local j = v - d
            if j > JB.GOAL_SIZE then return nil end            -- overshoots the finish
            for s = 1, d do if ownAtRing(S, JB.wrap(S, m.p + s), q) then return nil end end
            for k = 1, j do if S.goal[q][k] then return nil end end
            return 'G', j
        end
        for s = 1, v do if ownAtRing(S, JB.wrap(S, m.p + s), q) then return nil end end
        return 'R', JB.wrap(S, m.p + v)
    end
    local steps = -v
    for s = 1, steps do if ownAtRing(S, JB.wrap(S, m.p - s), q) then return nil end end
    return 'R', JB.wrap(S, m.p - steps)
end

-- Put marble mi on (kind,p), resolving automatic bonks exactly like the table does:
--   enemy  -> back to its start
--   teammate -> to the entrance of ITS finish
-- Returns newState, bumps  or  nil, reason when the move is illegal.
function JB.land(S, mi, kind, p)
    local S2 = JB.clone(S)
    local bumps = {}
    local curIdx, ck, cp = mi, kind, p
    local moves = {}
    for iter = 0, 6 do
        if iter > 5 then return nil, 'bonk chain too long' end
        local occ = nil
        if ck == 'R' then occ = S.ring[cp] end
        if occ == curIdx or occ == mi then occ = nil end   -- the mover has already left its old cell
        local cm = S.marbles[curIdx]
        moves[#moves + 1] = { idx = curIdx, kind = ck, p = cp }
        if occ == nil then break end
        local z = S.marbles[occ]
        if z.seat == cm.seat then return nil, 'cannot land on your own marble' end
        local dk, dp
        if JB.sameTeam(cm.seat, z.seat) then
            -- NEW RULE: a teammate sitting on the entrance of their finish can't be bonked
            -- (they would be sent to the very cell you are standing on).
            if z.kind == 'R' and z.p == JB.entrance(z.seat) then
                return nil, 'cannot bonk a teammate at the entrance of their finish'
            end
            dk, dp = 'R', JB.entrance(z.seat)
        else
            dk, dp = 'S', 0
        end
        bumps[#bumps + 1] = { idx = occ, seat = z.seat, to = dk, friendly = JB.sameTeam(cm.seat, z.seat) }
        curIdx, ck, cp = occ, dk, dp
    end
    -- apply all relocations (later ones were computed against the original board, like the sheet)
    for _, mv in ipairs(moves) do
        local m = S2.marbles[mv.idx]
        m.kind, m.p = mv.kind, mv.p
    end
    return buildOcc(S2), bumps
end

------------------------------------------------------------------------
-- move generation
------------------------------------------------------------------------
-- marbles the current seat may move: its own, or its teammates' once its own are all home
function JB.movable(S, seat)
    local out, startSeen = {}, {}
    local finished = JB.isFinished(S, seat)
    for i, m in ipairs(S.marbles) do
        local ok
        if finished then ok = (m.seat ~= seat and JB.sameTeam(m.seat, seat)) else ok = (m.seat == seat) end
        if ok then
            if m.kind == 'S' then
                if not startSeen[m.seat] then startSeen[m.seat] = true; out[#out + 1] = i end
            else
                out[#out + 1] = i
            end
        end
    end
    return out
end

local function enterOptions(S, mi, v)
    local m = S.marbles[mi]
    if m.kind == 'R' and v > 0 and v > JB.distToEntrance(S, m.seat, m.p) then return { true, false } end
    return { true }
end

local function markName(S, mi)
    local m = S.marbles[mi]
    return 'seat' .. m.seat .. '#' .. mi
end

-- one numeric leg: returns newState, bumps, targetKind, targetP  (or nil)
local function runLeg(S, mi, v, enter)
    local kind, p = JB.numericTarget(S, mi, v, enter)
    if not kind then return nil end
    local S2, bumps = JB.land(S, mi, kind, p)
    if not S2 then return nil end
    return S2, bumps, kind, p
end

local function tag(S, S2, mi, bumps)
    local before, after = S.marbles[mi], S2.marbles[mi]
    local t = {}
    if before.kind == 'S' and after.kind ~= 'S' then t[#t + 1] = 'leaves start' end
    if after.kind == 'G' and before.kind ~= 'G' then t[#t + 1] = 'enters finish' end
    for _, b in ipairs(bumps or {}) do
        t[#t + 1] = (b.friendly and 'bonks teammate ' or 'bonks ') .. 'seat ' .. b.seat
    end
    return #t > 0 and (' (' .. table.concat(t, ', ') .. ')') or ''
end

function JB.concat(a, b) local o = {}; for _, x in ipairs(a or {}) do o[#o + 1] = x end; for _, x in ipairs(b or {}) do o[#o + 1] = x end; return o end

-- Returns a list of legal actions for `seat` holding `hand` (array of card tokens).
-- action = { card=, steps={ {mi=, kind=, p=}, ... }, state=<state after>, text=, bumps=<n> }
-- opts.simple7 = true: treat a 7 as a plain 7-step move (no splits). Used deeper in the search (bot_search.lua),
-- where the thousands of split combinations would cost too much time.
function JB.legalActions(S, seat, hand, opts)
    local acts = {}
    local movable = JB.movable(S, seat)
    local seen = {}
    local straight7 = (opts ~= nil and opts.simple7 == true) or not JB.sevenMustSplit(S, seat)

    for _, card in ipairs(hand) do
        if not seen[card] then
            seen[card] = true
            if card == '$' then
                for _, mi in ipairs(movable) do
                    local m = S.marbles[mi]
                    if m.kind ~= 'G' then
                        for mj, o in ipairs(S.marbles) do
                            if o.kind == 'R' and o.seat ~= m.seat then
                                local S2, bumps = JB.land(S, mi, 'R', o.p)
                                if S2 then
                                    acts[#acts + 1] = { card = card, state = S2, bumps = #bumps, bumpList = bumps,
                                        steps = { { mi = mi, kind = 'R', p = o.p } },
                                        text = 'JOKER: ' .. markName(S, mi) .. ' jumps onto ' .. markName(S, mj) .. tag(S, S2, mi, bumps) }
                                end
                            end
                        end
                    end
                end
            elseif card == '7' and not straight7 then
                JB.sevenActions(S, seat, acts)
            else
                local v = JB.CARD_STEPS[card]
                for _, mi in ipairs(movable) do
                    local m = S.marbles[mi]
                    if m.kind == 'S' then
                        if JB.EXIT_CARDS[card] then
                            local S2, bumps = JB.land(S, mi, 'R', JB.exitCell(m.seat))
                            if S2 then
                                acts[#acts + 1] = { card = card, state = S2, bumps = #bumps, bumpList = bumps,
                                    steps = { { mi = mi, kind = 'R', p = JB.exitCell(m.seat) } },
                                    text = card:upper() .. ': ' .. markName(S, mi) .. tag(S, S2, mi, bumps) }
                            end
                        end
                    else
                        local lastP, lastK
                        for _, enter in ipairs(enterOptions(S, mi, v)) do
                            local S2, bumps, k, p = runLeg(S, mi, v, enter)
                            if S2 then
                                acts[#acts + 1] = { card = card, state = S2, bumps = #bumps, bumpList = bumps,
                                    steps = { { mi = mi, kind = k, p = p } },
                                    text = card:upper() .. ': ' .. markName(S, mi) .. tag(S, S2, mi, bumps) }
                            end
                        end
                    end
                end
            end
        end
    end
    for _, a in ipairs(acts) do a.seat = seat end      -- who plays it (a 7 can move a teammate's marbles too)
    return acts
end

-- 7 split: marble A takes `a` steps, marble B takes 7-a steps (a = 1..6), executed one after the other.
function JB.sevenActions(S, seat, acts)
    local finished = JB.isFinished(S, seat)
    local firsts, seconds = {}, {}
    for i, m in ipairs(S.marbles) do
        if m.kind ~= 'S' and JB.sameTeam(m.seat, seat) then
            if finished then
                if m.seat ~= seat then firsts[#firsts + 1] = i; seconds[#seconds + 1] = i end
            else
                if m.seat == seat then firsts[#firsts + 1] = i end
                if m.seat ~= seat then seconds[#seconds + 1] = i end
                if JB.ALLOW_OWN_SPLIT and m.seat == seat then seconds[#seconds + 1] = i end
            end
        end
    end
    -- Both orders (user, flag 60): the teammate's part can go first, e.g. a teammate's marble +2 lands on yours
    -- (friendly bonk: yours jumps to your finish entrance), then YOUR marble +5 goes straight into your finish.
    local pairs_ = {}
    for _, mi in ipairs(firsts) do
        for _, mj in ipairs(seconds) do
            if mi ~= mj and (not finished or S.marbles[mi].seat ~= S.marbles[mj].seat) then   -- finished: two DIFFERENT teammates
                pairs_[#pairs_ + 1] = { mi, mj }
                if not finished then pairs_[#pairs_ + 1] = { mj, mi } end   -- (finished: both orders already listed)
            end
        end
    end
    for _, pr in ipairs(pairs_) do
        local mi, mj = pr[1], pr[2]
        do
            do
                for a = 1, 6 do
                    local b = 7 - a
                    for _, e1 in ipairs(enterOptions(S, mi, a)) do
                        local S1, bumps1, k1, p1 = runLeg(S, mi, a, e1)
                        if S1 then
                            for _, e2 in ipairs(enterOptions(S1, mj, b)) do
                                local S2, bumps2, k2, p2 = runLeg(S1, mj, b, e2)
                                if S2 then
                                    acts[#acts + 1] = { card = '7', state = S2, bumps = #bumps1 + #bumps2, bumpList = JB.concat(bumps1, bumps2),
                                        steps = { { mi = mi, kind = k1, p = p1 }, { mi = mj, kind = k2, p = p2 } },
                                        text = '7: ' .. markName(S, mi) .. ' +' .. a .. tag(S, S1, mi, bumps1) ..
                                               ' and ' .. markName(S, mj) .. ' +' .. b .. tag(S1, S2, mj, bumps2) }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Convert between table snap-point indices (non_start_points) and logical cells.
-- block of 23 per seat: o=1..3 ring i=1..3 ; o=4..8 goal 1..5 ; o=9..23 ring i=4..18
function JB.indexToCell(idx)
    local s = math.floor((idx - 1) / 23) + 1
    local o = idx - (s - 1) * 23
    if o <= 3 then return 'R', (s - 1) * 18 + o, s end
    if o <= 8 then return 'G', o - 3, s end
    return 'R', (s - 1) * 18 + (o - 5), s
end

function JB.cellToIndex(kind, p, seat)
    if kind == 'G' then return (seat - 1) * 23 + 3 + p end
    local s = math.floor((p - 1) / 18) + 1
    local i = p - (s - 1) * 18
    return (s - 1) * 23 + (i <= 3 and i or i + 5)
end

