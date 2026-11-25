-- bot/engine.lua: the level-10 Joker bot ("engine"). Pure Lua like bot/rules.lua / bot/search.lua (no TTS calls).
--
-- Unlike levels 1-9 it has no list of hand-made strategy rules. It scores a position with ONE general cost function
-- and searches deep, round the table:
--
--   cost of a seat = cells its marbles still have to travel to fill its finish
--                    + START_COST for every marble still in start (it needs an exit card first)
--                    + PACK_COST for every single step needed to pack the finish from the deep end (those steps
--                      need exact small cards: Aces, 2s, a split 7)
--                    + expected loss from bonks: for each marble, the chance an enemy holds the exact card to hit it
--                      before it moves again (card counting: odds come from the cards not seen yet) x what a bonk
--                      costs (the cells travelled + START_COST)
--   score for a team = the enemy team's total cost - our team's total cost (+ a small value for the cards we hold)
--
-- Teammates count fully (it's a team score), so helping, catapulting and keeping a teammate in reach come from the
-- score itself, as do clean finishes, saving small cards for the finish and keeping out of the next player's range.
--
-- SEARCH: expectimax in seat order. The bot's own later turns use the cards it really holds (a beam of its best
-- moves). Every other seat's hand is hidden: for each card type the seat's best move with that card is found
-- (greedy, by the same cost function for ITS team), and the outcomes are weighted by the chance that this is the
-- best card it holds (hypergeometric odds from the unseen cards). Only the likeliest JE.CHANCE_K outcomes are searched
-- deeper; the rest are scored where they stand. Iterative deepening until the time limit.
--
-- SPEED: the search works on flat number arrays with make/unmake (no tables created per node), so it runs in
-- Tabletop Simulator's slow Lua. Root moves come from JokerBot.legalActions (exact rules incl. every 7 split).
--
-- Opponent / teammate / later own turns: a 7 is a plain 7 (no splits) and no Jokers - the root still has them all.
JokerEngine = JokerEngine or {}
local JE = JokerEngine
local JB = JokerBot

JE.START_COST = 12        -- a marble in start: ~ the turns it waits for an exit card, in cells
JE.PACK_COST = 25         -- extra per single step needed to pack the finish (needs an exact small card)
JE.RISK_SHARE = 0.75      -- an enemy holding the card doesn't always use it on you
JE.RISK_AVERSION = 1.5    -- our own bonk risk counts this much more than the enemy's (play conservatively)
-- the option value of holding a card, in cells: a Joker's later jump, an Ace / split 7 for exact finishing steps,
-- the K's reach for defence, the 8's shortcut, 10s; plain cards little
JE.HAND = { ['$'] = 150, a = 15, ['7'] = 15, k = 20, ['8'] = 8, ['10'] = 6, q = 5, j = 5 }
JE.WIN = 1000000
JE.CHANCE_K = 4           -- outcomes searched deeper at another seat's turn
JE.BEAM = 3               -- own later turns: best moves searched deeper
JE.ROOT_KEEP = 12         -- root moves kept for the deeper iterations
JE.HAND_SIZE = 5          -- cards another player holds when it is to move (6 dealt, before drawing)
JE.GREEDY_FULL = 1        -- other seats: options per card scored with the full cost function (best by the quick estimate)

local CARD_TYPES = { 'a', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'j', 'q', 'k', '$' }
local STEP = { a = 1, ['2'] = 2, ['3'] = 3, ['4'] = 4, ['5'] = 5, ['6'] = 6, ['7'] = 7, ['8'] = -8, ['9'] = 9,
               ['10'] = 10, j = 11, q = 12, k = 13 }
local EXIT = { a = true, j = true, q = true, k = true, ['$'] = true }
JE.DECK = { a = 4, ['2'] = 4, ['3'] = 4, ['4'] = 4, ['5'] = 4, ['6'] = 4, ['7'] = 4, ['8'] = 4, ['9'] = 4, ['10'] = 4,
            j = 4, q = 4, k = 4, ['$'] = 2 }
-- which card types can hit a marble from d cells behind (d < 0: from |d| ahead, the 8 backwards)
local HIT = {}
for d = 1, 13 do HIT[d] = {} end
HIT[1] = { 'a' }; HIT[2] = { '2' }; HIT[3] = { '3' }; HIT[4] = { '4' }; HIT[5] = { '5' }; HIT[6] = { '6' }
HIT[9] = { '9' }; HIT[10] = { '10' }; HIT[11] = { 'j' }; HIT[12] = { 'q' }; HIT[13] = { 'k' }

------------------------------------------------------------------------
-- compact state
------------------------------------------------------------------------
-- E.pos[i]: 0 = start, 1..R = ring cell, R + j = finish cell j. E.ring[c] / E.fin[(s-1)*5 + j] = marble or 0.
local G = 5
function JE.load(S)
    local E = { N = S.N, R = S.R, M = #S.marbles, seat = {}, pos = {}, ring = {}, fin = {}, ent = {}, ex = {},
                uMi = {}, uPos = {}, uTop = 0, vt = (JE.EVAL == 2) and JE.valueTables(S.R) or nil }
    for c = 1, S.R do E.ring[c] = 0 end
    for k = 1, S.N * G do E.fin[k] = 0 end
    for s = 1, S.N do E.ent[s] = JB.entrance(s); E.ex[s] = JB.exitCell(s) end
    for i, m in ipairs(S.marbles) do
        E.seat[i] = m.seat
        if m.kind == 'S' then E.pos[i] = 0
        elseif m.kind == 'R' then E.pos[i] = m.p; E.ring[m.p] = i
        else E.pos[i] = S.R + m.p; E.fin[(m.seat - 1) * G + m.p] = i end
    end
    return E
end

local function setPos(E, i, p)       -- move marble i to p (occupancy kept in sync; caller logs undo)
    local R = E.R
    local old = E.pos[i]
    if old > 0 then
        if old <= R then if E.ring[old] == i then E.ring[old] = 0 end
        else local k = (E.seat[i] - 1) * G + (old - R); if E.fin[k] == i then E.fin[k] = 0 end end
    end
    E.pos[i] = p
    if p > 0 then
        if p <= R then E.ring[p] = i else E.fin[(E.seat[i] - 1) * G + (p - R)] = i end
    end
end
local function logMove(E, i, p)
    local t = E.uTop + 1
    E.uTop = t; E.uMi[t] = i; E.uPos[t] = E.pos[i]
    setPos(E, i, p)
end
local function undoTo(E, mark)
    while E.uTop > mark do
        local t = E.uTop
        setPos(E, E.uMi[t], E.uPos[t])
        E.uTop = t - 1
    end
end
local function wrap(R, c) return ((c - 1) % R) + 1 end
local function dist(E, s, c) return (E.ent[s] - c) % E.R end      -- ring cell c to the entrance of seat s

local function goalCount(E, s)
    local n, b = 0, (s - 1) * G
    for j = 1, G do if E.fin[b + j] ~= 0 then n = n + 1 end end
    return n
end
local function finished(E, s) return goalCount(E, s) == G end

-- where does marble i end after v steps (enter = turn into the finish when passing the entrance)? nil if illegal
local function target(E, i, v, enter)
    local p, s, R = E.pos[i], E.seat[i], E.R
    if p == 0 then return nil end
    local b = (s - 1) * G
    if p > R then
        if v < 0 then return nil end
        local j = p - R + v
        if j > G then return nil end
        for k = p - R + 1, j do if E.fin[b + k] ~= 0 then return nil end end
        return R + j
    end
    if v > 0 then
        local d = dist(E, s, p)
        if v > d and enter then
            local j = v - d
            if j > G then return nil end
            for st = 1, d do local o = E.ring[wrap(R, p + st)]; if o ~= 0 and E.seat[o] == s then return nil end end
            for k = 1, j do if E.fin[b + k] ~= 0 then return nil end end
            return R + j
        end
        for st = 1, v do local o = E.ring[wrap(R, p + st)]; if o ~= 0 and E.seat[o] == s then return nil end end
        return wrap(R, p + v)
    end
    for st = 1, -v do local o = E.ring[wrap(R, p - st)]; if o ~= 0 and E.seat[o] == s then return nil end end
    return wrap(R, p + v)
end

-- put marble i on p with the bonk chain (enemy -> start, teammate -> its entrance). Returns false if illegal
-- (the undo log then holds a partial move: the caller undoes to its mark either way).
local function land(E, i, p)
    local R = E.R
    local cur, to = i, p
    for _ = 1, 6 do
        local occ = (to <= R) and E.ring[to] or 0
        if occ == cur then occ = 0 end
        if occ == 0 then logMove(E, cur, to); return true end
        local zs, cs = E.seat[occ], E.seat[cur]
        if zs == cs then return false end
        if zs % 2 == cs % 2 then
            if E.pos[occ] == E.ent[zs] then return false end   -- a teammate on its own entrance can't be bonked
            logMove(E, occ, 0)                                -- lift it, then move cur in
            logMove(E, cur, to)
            cur, to = occ, E.ent[zs]
        else
            logMove(E, occ, 0)
            logMove(E, cur, to)
            return true
        end
    end
    return false
end

------------------------------------------------------------------------
-- cost function
------------------------------------------------------------------------
-- odds that a seat holds at least one card of type c (hand of h from the unseen cards)
local function holdOdds(unseen, total, h)
    local out = {}
    for _, c in ipairs(CARD_TYPES) do
        local n = unseen[c] or 0
        if n <= 0 or total <= 0 then out[c] = 0
        else
            local miss = 1
            for k = 0, h - 1 do miss = miss * math.max(0, (total - n - k)) / (total - k) end
            out[c] = 1 - miss
        end
    end
    return out
end
JE.holdOdds = holdOdds

-- chance a marble on ring cell c (seat s) is hit before its owner moves again: any enemy marble 1-6 / 9-13 behind
-- with that card, an enemy 8 ahead with an 8, a split 7 from 1-6 behind
local function hitChance(E, s, c, odds)
    local miss = 1
    local R = E.R
    for d = 1, 13 do
        if d ~= 7 and d ~= 8 then
            local o = E.ring[wrap(R, c - d)]
            if o ~= 0 and E.seat[o] % 2 ~= s % 2 then
                local q = odds[HIT[d][1]]
                if d <= 6 then q = 1 - (1 - q) * (1 - 0.5 * odds['7']) end
                miss = miss * (1 - q * JE.RISK_SHARE)
            end
        end
    end
    local o = E.ring[wrap(R, c + 8)]
    if o ~= 0 and E.seat[o] % 2 ~= s % 2 then miss = miss * (1 - odds['8'] * JE.RISK_SHARE) end
    return 1 - miss
end

-- score of position E for team `par` (higher = better): enemy team's cost - our team's cost, in cells.
-- One pass over the marbles; finish cells per seat. hand: the bot's remaining cards (or nil)
local seatAcc = {}
local function evaluate1(E, par, odds, hand)
    local R, N = E.R, E.N
    local span = R - 5
    local SC, PC = JE.START_COST, JE.PACK_COST + 1
    for s = 1, N do
        local b, k, pack, free = (s - 1) * G, 0, 0, 0
        for j = G, 1, -1 do
            if E.fin[b + j] ~= 0 then k = k + 1; pack = pack + (G - k + 1) - j else free = free + j end
        end
        seatAcc[s] = free + PC * pack
    end
    local myLeft, theirLeft = 0, 0
    for i = 1, E.M do
        local s, p = E.seat[i], E.pos[i]
        if p <= R then
            if s % 2 == par then myLeft = myLeft + 1 else theirLeft = theirLeft + 1 end
            if p == 0 then seatAcc[s] = seatAcc[s] + span + SC
            else
                local d = (E.ent[s] - p) % R
                local h = hitChance(E, s, p, odds)
                if h > 0 then
                    if s % 2 == par then h = h * JE.RISK_AVERSION end
                    seatAcc[s] = seatAcc[s] + h * ((span - d) + SC)
                end
                seatAcc[s] = seatAcc[s] + d
            end
        end
    end
    if myLeft == 0 then return JE.WIN end
    if theirLeft == 0 then return -JE.WIN end
    local v = 0
    for s = 1, N do if s % 2 == par then v = v - seatAcc[s] else v = v + seatAcc[s] end end
    if hand then for _, c in ipairs(hand) do v = v + (JE.HAND[c] or 1) end end
    return v
end
JE.evaluate1 = evaluate1
------------------------------------------------------------------------
-- evaluation 2 (JE.EVAL = 2): a position in MOVES, from a value map of the board
------------------------------------------------------------------------
-- The value map (JE.valueTables, worked out once per board size) holds, for every ring cell and every finish
-- target, the expected number of moves a marble still needs to get home from there. It is back-propagated from the
-- finish (value iteration) with the real card odds: the best card of a 6-card hand each move, entering the finish
-- exactly or running past for another lap, the 8 backwards (cells just past your exit are close to home), split 7s
-- for exact small steps, small cards to pack the finish, and a part-wasted turn (JE.WAIT) when no card fits. It
-- looks laps ahead, which the search tree can't.
--
-- A seat's cost = the moves its marbles still need: marbles in the finish to their packed cells, ring marbles to
-- the closest available finish cell (the marble nearest home gets the deepest free cell), start marbles = an exit
-- move + the trip from the exit + a wait when the player is short of exit cards (JE.SCARCE; worse with nothing on
-- the ring to play meanwhile, JE.SCARCE_IDLE). Plus each ring marble's danger: the chance it is hit x what it would
-- lose (its moves to go from start again - its moves to go now), so a marble near home, or any marble when its owner
-- is short of exit cards, is valuable, and a fresh marble with exit cards in hand is cheap to lose.
-- Bonks score themselves: an enemy loses (start - where it was), big near its finish and small on its exit; a
-- teammate sent to its entrance gains (where it was - its entrance), minus the danger on that entrance.
-- A marble whose finish cell is behind a finish marble that still has to move (a gap ahead of that one) can't go in
-- until it moves: the blocker's moves that outlast its own approach are added as waiting (JE.BLOCK_WAIT), so moving
-- the blocker deeper is worth more the closer the marbles behind it are.
-- Team score = the enemy team's moves - ours (+ JE.HANDV for the cards the bot still holds, in moves).
JE.EVAL = 2
JE.WAIT = 1.5            -- a move of this marble's player that it can't use (no card fits): wasted, and more (self-play vs level 9: 0.5 35%, 1 47%, 1.5 51%)
JE.SPLIT7_SHARE = 0.5    -- how often a 7 can be split for an exact small step (needs a teammate's marble)
JE.SCARCE = 1.5          -- each start marble beyond the exit cards in hand: moves lost waiting for an exit card
JE.SCARCE_IDLE = 3       -- ... when the player has nothing on the ring to play meanwhile (it burns)
JE.EXIT_HELD = 2         -- exit cards another player is assumed to hold
JE.BLOCK_WAIT = 1        -- a marble whose finish cell is behind an unpacked finish marble: its wait counts this much
JE.DP_HAND = 3           -- hand size the value map assumes: a marble shares the hand with the others, so less than 6
JE.HANDV = { ['$'] = 4, a = 0.5, ['7'] = 0.4, k = 0.5, ['8'] = 0.25, ['10'] = 0.2, q = 0.15, j = 0.15 }

local dpVals, dpQs, dpOrd = {}, {}, {}
-- expected moves from a state: option k (taken with chance q_k if no better card is held) costs 1 + vals[k]; with
-- no useful card the move is part-wasted (JE.WAIT) and the marble stays (self)
local function expectMoves(n, self)
    for k = 1, n do dpOrd[k] = k end
    for k = 2, n do                                   -- insertion sort by value
        local x = dpOrd[k]; local vx = dpVals[x]; local m = k - 1
        while m >= 1 and dpVals[dpOrd[m]] > vx do dpOrd[m + 1] = dpOrd[m]; m = m - 1 end
        dpOrd[m + 1] = x
    end
    local stay = JE.WAIT + self
    local none, total = 1, 0
    for k = 1, n do
        local x = dpOrd[k]
        local v = 1 + dpVals[x]
        if v >= stay then break end
        local w = dpQs[x] * none
        total = total + w * v
        none = none * (1 - dpQs[x])
    end
    return total + none * stay
end

local VT_CACHE = {}
function JE.valueTables(R)
    local key = R .. ":" .. JE.WAIT .. ":" .. JE.SPLIT7_SHARE .. ":" .. JE.DP_HAND
    if VT_CACHE[key] then return VT_CACHE[key] end
    local total = 0
    for _, n in pairs(JE.DECK) do total = total + n end
    local cards = {}
    local q7 = 0
    for _, c in ipairs(CARD_TYPES) do
        if c ~= '$' then
            local q = 1 - (1 - JE.DECK[c] / total) ^ JE.DP_HAND
            if c == '7' then q7 = q; q = q * (1 - JE.SPLIT7_SHARE) end
            cards[#cards + 1] = { v = STEP[c], q = q }
        end
    end
    local q7s = q7 * JE.SPLIT7_SHARE
    -- finish: VF[r] = moves to cover the last r steps to the target cell (exact small cards, or part of a split 7)
    local VF = { [0] = 0 }
    for r = 1, G do
        local v = 3
        for _ = 1, 200 do
            local n = 0
            for _, cd in ipairs(cards) do
                if cd.v > 0 and cd.v <= r then n = n + 1; dpVals[n] = VF[r - cd.v]; dpQs[n] = cd.q end
            end
            n = n + 1; dpVals[n] = 0; dpQs[n] = q7s
            local nv = expectMoves(n, v)
            if math.abs(nv - v) < 1e-7 then v = nv; break end
            v = nv
        end
        VF[r] = v
    end
    -- ring: VR[t][d] = moves to get home from d cells before the entrance, aiming for finish cell t
    local VR, VS = {}, {}
    for t = 1, G do
        local V = {}
        for d = 0, R - 1 do V[d] = 1 + d / 6 end
        for _ = 1, 400 do
            local delta = 0
            for d = 0, R - 1 do
                local n = 0
                for _, cd in ipairs(cards) do
                    local st = cd.v
                    local best
                    if st < 0 then best = V[(d - st) % R]                -- the 8 backwards
                    elseif st <= d then best = V[d - st]
                    else
                        best = V[(d - st) % R]                             -- run past the entrance: another lap
                        local j = st - d
                        if j <= t then local e = VF[t - j]; if e < best then best = e end end
                    end
                    n = n + 1; dpVals[n] = best; dpQs[n] = cd.q
                end
                local b7                                                   -- split 7: own part 1..6
                for a = 1, 6 do
                    local x
                    if a <= d then x = V[d - a] else local j = a - d; if j <= t then x = VF[t - j] end end
                    if x and (not b7 or x < b7) then b7 = x end
                end
                if b7 then n = n + 1; dpVals[n] = b7; dpQs[n] = q7s end
                local nv = expectMoves(n, V[d])
                local dd = math.abs(nv - V[d])
                if dd > delta then delta = dd end
                V[d] = nv
            end
            if delta < 1e-5 then break end
            if JE.buildYield then JE.buildYield() end       -- Tabletop Simulator: let the game run (built once per board)
        end
        VR[t] = V
        VS[t] = 1 + V[(R - 5) % R]                                         -- out onto the exit: 5 past the entrance
    end
    local T = { VF = VF, VR = VR, VS = VS, R = R }
    VT_CACHE[key] = T
    return T
end

local cntR, cntS, ringI, ringD = {}, {}, {}, {}
local function evaluate2(E, par, odds, hand)
    local R, N = E.R, E.N
    local T = E.vt
    local VF, VR, VS = T.VF, T.VR, T.VS
    local me = E.me
    local myExit = JE.EXIT_HELD
    if hand then
        myExit = 0
        for _, c in ipairs(hand) do if EXIT[c] then myExit = myExit + 1 end end
    end
    for s = 1, N do cntR[s] = 0; cntS[s] = 0 end
    local myLeft, theirLeft = 0, 0
    for i = 1, E.M do
        local p = E.pos[i]
        if p <= R then
            local s = E.seat[i]
            if s % 2 == par then myLeft = myLeft + 1 else theirLeft = theirLeft + 1 end
            if p == 0 then cntS[s] = cntS[s] + 1
            else
                local k = cntR[s] + 1
                cntR[s] = k
                local d = (E.ent[s] - p) % R
                -- insertion by distance (closest to home first)
                local b = (s - 1) * G
                local m = k - 1
                while m >= 1 and ringD[b + m] > d do ringD[b + m + 1] = ringD[b + m]; ringI[b + m + 1] = ringI[b + m]; m = m - 1 end
                ringD[b + m + 1] = d; ringI[b + m + 1] = i
            end
        end
    end
    if myLeft == 0 then return JE.WIN end
    if theirLeft == 0 then return -JE.WIN end
    local v = 0
    for s = 1, N do
        local b = (s - 1) * G
        local cost = 0
        local tgt = G
        local firstOcc, blockCost = G + 1, 0     -- shallowest finish marble, and its moves still to go if not packed
        for j = G, 1, -1 do
            if E.fin[b + j] ~= 0 then
                firstOcc = j
                if j < tgt then blockCost = VF[tgt - j]; cost = cost + blockCost else blockCost = 0 end
                tgt = tgt - 1
            end
        end
        local n, sc = cntR[s], cntS[s]
        local exitHeld = (s == me) and myExit or JE.EXIT_HELD
        local scarce = (n > 0) and JE.SCARCE or JE.SCARCE_IDLE
        local aversion = (s % 2 == par) and JE.RISK_AVERSION or 1
        -- a bonked marble goes back to start as one more needing an exit card
        local backExtra = (sc + 1 > exitHeld) and scarce or 0
        for k = 1, n do
            local t = tgt; if t < 1 then t = 1 end
            tgt = tgt - 1
            local d = ringD[b + k]
            local here = VR[t][d]
            cost = cost + here
            -- its finish cell lies behind a finish marble that still has to move (a gap ahead of it): it can't go in
            -- until that marble moves, so it waits for whatever of the blocker's moves outlast its own approach
            if t >= firstOcc and blockCost > 0 then
                local wait = blockCost - (here - VR[t][0])
                if wait > 0 then cost = cost + JE.BLOCK_WAIT * wait end
            end
            local loss = VS[t] + backExtra - here
            if loss > 0 then
                local h = hitChance(E, s, E.pos[ringI[b + k]], odds)
                if h > 0 then cost = cost + h * aversion * loss end
            end
        end
        for k = 1, sc do
            local t = tgt; if t < 1 then t = 1 end
            tgt = tgt - 1
            cost = cost + VS[t] + ((k > exitHeld) and scarce or 0)
        end
        if s % 2 == par then v = v - cost else v = v + cost end
    end
    if hand then for _, c in ipairs(hand) do v = v + (JE.HANDV[c] or 0.05) end end
    return v
end
JE.evaluate2 = evaluate2

local function evaluate(E, par, odds, hand)
    if E.vt then return evaluate2(E, par, odds, hand) end
    return evaluate1(E, par, odds, hand)
end
JE.evaluate = evaluate
local function handVal(c)
    if JE.EVAL == 2 then return JE.HANDV[c] or 0.05 end
    return JE.HAND[c] or 1
end

------------------------------------------------------------------------
-- move generation. A move is 4 numbers in a buffer: i1, p1, i2, p2 (marble i1 lands on p1, then marble i2 on p2;
-- i2 = 0 for a one-marble move). Moves are applied in place (play) and taken back with undoTo.
-- full = false (Tabletop Simulator): a 7 is a plain 7 and there are no Jokers in the search tree (the root still has
-- every legal move). full = true (deep mode, offline): Jokers and the house-rule 7 splits are searched too.
------------------------------------------------------------------------
local moverBuf, startStamp, stampN = {}, {}, 0
local function movers(E, s)
    local n = 0
    stampN = stampN + 1
    local fin = finished(E, s)
    for i = 1, E.M do
        local ms = E.seat[i]
        local ok
        if fin then ok = (ms ~= s and ms % 2 == s % 2) else ok = (ms == s) end
        if ok then
            if E.pos[i] == 0 then
                if startStamp[ms] ~= stampN then startStamp[ms] = stampN; n = n + 1; moverBuf[n] = i end
            else n = n + 1; moverBuf[n] = i end
        end
    end
    return moverBuf, n
end

local function push(out, n, i1, p1, i2, p2)
    out[n + 1] = i1; out[n + 2] = p1; out[n + 3] = i2; out[n + 4] = p2
    return n + 4
end

local function play(E, b, k)
    if not land(E, b[k], b[k + 1]) then return false end
    if b[k + 2] ~= 0 then return land(E, b[k + 2], b[k + 3]) end
    return true
end

-- where marble i can end after v steps: up to two cells (turning into the finish or running past)
local function legTargets(E, i, v, t)
    local n = 0
    local a = target(E, i, v, true)
    if a then n = 1; t[1] = a end
    local p = E.pos[i]
    if v > 0 and p > 0 and p <= E.R and v > dist(E, E.seat[i], p) then
        local b2 = target(E, i, v, false)
        if b2 and b2 ~= a then n = n + 1; t[n] = b2 end
    end
    return n
end

-- the house-rule 7 (JB.sevenMustSplit): split with a teammate's eligible marble when there is one
local function eligible(E, i)
    local p = E.pos[i]
    if p == 0 then return false end
    if p <= E.R then return true end
    local j = p - E.R
    return j < G and E.fin[(E.seat[i] - 1) * G + j + 1] == 0
end
local ownerStamp, ownerN = {}, 0
local function mustSplit(E, s)
    ownerN = ownerN + 1
    local n = 0
    for i = 1, E.M do
        local ms = E.seat[i]
        if ms ~= s and ms % 2 == s % 2 and ownerStamp[ms] ~= ownerN and eligible(E, i) then
            ownerStamp[ms] = ownerN; n = n + 1
        end
    end
    if finished(E, s) then return n >= 2 end
    return n >= 1
end
local t1, t2 = {}, {}
local function splits(E, s, out)
    local n = 0
    local fin = finished(E, s)
    local par = s % 2
    for i = 1, E.M do
        local si = E.seat[i]
        if si % 2 == par and E.pos[i] ~= 0 then
            for j = 1, E.M do
                local sj = E.seat[j]
                if j ~= i and sj % 2 == par and si ~= sj and E.pos[j] ~= 0 then
                    local ok
                    if fin then ok = (si ~= s and sj ~= s) else ok = ((si == s) ~= (sj == s)) end
                    if ok then
                        for a = 1, 6 do
                            local n1 = legTargets(E, i, a, t1)
                            local x1, x2 = t1[1], t1[2]
                            for x = 1, n1 do
                                local p1 = (x == 1) and x1 or x2
                                local mark0 = E.uTop
                                if land(E, i, p1) then
                                    local mark1 = E.uTop
                                    local n2 = legTargets(E, j, 7 - a, t2)
                                    local y1, y2 = t2[1], t2[2]
                                    for y = 1, n2 do
                                        local p2 = (y == 1) and y1 or y2
                                        if land(E, j, p2) then n = push(out, n, i, p1, j, p2) end
                                        undoTo(E, mark1)
                                    end
                                end
                                undoTo(E, mark0)
                            end
                        end
                    end
                end
            end
        end
    end
    return n
end

-- legal moves for seat s playing card c (4 numbers each); returns the buffer length
local function options(E, s, c, out, full)
    if c == '7' and full and mustSplit(E, s) then return splits(E, s, out) end
    local n = 0
    local list, cnt = movers(E, s)
    if c == '$' then
        if not full then return 0 end
        local R = E.R
        for t = 1, cnt do
            local i = list[t]
            if E.pos[i] <= R then
                local si = E.seat[i]
                for o = 1, E.M do
                    local q = E.pos[o]
                    if q > 0 and q <= R and E.seat[o] ~= si then n = push(out, n, i, q, 0, 0) end
                end
            end
        end
        return n
    end
    local v = STEP[c]
    for t = 1, cnt do
        local i = list[t]
        local p = E.pos[i]
        if p == 0 then
            if EXIT[c] then n = push(out, n, i, E.ex[E.seat[i]], 0, 0) end
        elseif v then
            local m = legTargets(E, i, v, t1)
            for x = 1, m do n = push(out, n, i, t1[x], 0, 0) end
        end
    end
    return n
end

------------------------------------------------------------------------
-- search
------------------------------------------------------------------------
local function tick(ctx)
    ctx.nodes = ctx.nodes + 1
    if ctx.nodes % 64 ~= 0 then return end
    local now = ctx.clock()
    if now >= ctx.deadline then ctx.stop = true; return end
    if ctx.yield and now - ctx.slice >= 0.025 then ctx.yield(); ctx.slice = ctx.clock() end
end

local value   -- forward

-- cheap estimate of a one-marble move for its mover's team: cells gained + what a bonk costs the victim's team
-- (a friendly bonk sends a teammate to its entrance: its cells saved count as gain) - the new spot's bonk risk
local function quick(E, i, p, odds)
    local R, s = E.R, E.seat[i]
    local old = E.pos[i]
    local span = R - 5
    local before = (old == 0) and (span + JE.START_COST + 5) or (old <= R and ((E.ent[s] - old) % R) + 3 or (2 * G + 1 - (old - R)))
    local after = (p <= R) and (((E.ent[s] - p) % R) + 3) or (2 * G + 1 - (p - R))
    local g = before - after
    if p <= R then
        local o = E.ring[p]
        if o ~= 0 and o ~= i then
            local zs = E.seat[o]
            local zd = (E.ent[zs] - p) % R
            if zs % 2 == s % 2 then g = g + zd else g = g + (span - zd) + JE.START_COST end
        end
        g = g - hitChance(E, s, p, odds) * ((span - ((E.ent[s] - p) % R)) + JE.START_COST)
    end
    return g
end
-- the same in moves (evaluation 2): the seat's deepest free finish cell is the target
local function deepFree(E, s)
    local b = (s - 1) * G
    for j = G, 1, -1 do if E.fin[b + j] == 0 then return j end end
    return 1
end
local function movesAt(E, T, s, pos, t)
    if pos == 0 then return T.VS[t] end
    if pos <= E.R then return T.VR[t][(E.ent[s] - pos) % E.R] end
    local j = pos - E.R
    return (j < t) and T.VF[t - j] or 0
end
local function quick2(E, i, p, odds)
    local T, R, s = E.vt, E.R, E.seat[i]
    local t = deepFree(E, s)
    local after = movesAt(E, T, s, p, t)
    local g = movesAt(E, T, s, E.pos[i], t) - after
    if p <= R then
        local o = E.ring[p]
        if o ~= 0 and o ~= i then
            local zs = E.seat[o]
            local zt = deepFree(E, zs)
            local zv = movesAt(E, T, zs, p, zt)
            if zs % 2 == s % 2 then g = g + (zv - T.VR[zt][0]) else g = g + (T.VS[zt] - zv) end
        end
        g = g - hitChance(E, s, p, odds) * (T.VS[t] - after)
    end
    return g
end
local function quickMove(E, b, k, odds)
    if E.vt then
        local g = quick2(E, b[k], b[k + 1], odds)
        if b[k + 2] ~= 0 then g = g + quick2(E, b[k + 2], b[k + 3], odds) end
        return g
    end
    local g = quick(E, b[k], b[k + 1], odds)
    if b[k + 2] ~= 0 then g = g + quick(E, b[k + 2], b[k + 3], odds) end
    return g
end
local function moveKey(b, k) return ((b[k] * 512 + b[k + 1]) * 512 + b[k + 2]) * 512 + b[k + 3] end

-- another seat's best move with card c, by ITS team's cost function: best few by the quick estimate get the full
-- cost function. Returns value (bot's view), its own view, buffer, offset - or nil
local optBuf = {}
local function greedy(ctx, E, s, c)
    local buf = optBuf[ctx.ply] or {}
    optBuf[ctx.ply] = buf
    local n = options(E, s, c, buf, ctx.full)
    if n == 0 then return nil end
    local par = s % 2
    local k1, k2, v1, v2
    for k = 1, n, 4 do
        local q = quickMove(E, buf, k, ctx.odds)
        if not v1 or q > v1 then k2, v2 = k1, v1; k1, v1 = k, q
        elseif not v2 or q > v2 then k2, v2 = k, q end
    end
    local best, bk
    local memo = ctx.memo                      -- same move from another card type (A/J/Q/K out of start): reuse
    for t = 1, ctx.greedyFull do
        local k = (t == 1) and k1 or k2
        if k then
            local key = moveKey(buf, k)
            local v = memo[key]
            if v == nil then
                local mark = E.uTop
                if play(E, buf, k) then v = evaluate(E, par, ctx.odds, nil) else v = false end
                undoTo(E, mark)
                memo[key] = v
                ctx.nodes = ctx.nodes + 1
            end
            if v and (not best or v > best) then best, bk = v, k end
        end
    end
    if not bk then return nil end
    return (par == ctx.par) and best or -best, best, buf, bk
end

local function cheapestIndex(hand)
    local lo, li = nil, nil
    for hi, c in ipairs(hand) do
        local w = handVal(c)
        if not lo or w < lo then lo, li = w, hi end
    end
    return li
end

-- value of E for the bot's team when seat s is to move, `left` plies to go
value = function(ctx, E, s, left, hand)
    tick(ctx)
    if ctx.stop then return 0 end
    local base = evaluate(E, ctx.par, ctx.odds, hand)
    if left == 0 or base >= JE.WIN or base <= -JE.WIN then return base end
    local nextS = s % E.N + 1
    ctx.ply = ctx.ply + 1

    if s == ctx.seat then
        -- the bot again: its own cards, best of the beam
        local cand = {}
        local seen = {}
        local buf = {}
        for hi, c in ipairs(hand) do
            if not seen[c] then
                seen[c] = true
                local n = options(E, s, c, buf, ctx.full)
                local cost = handVal(c)
                for k = 1, n, 4 do
                    cand[#cand + 1] = { q = quickMove(E, buf, k, ctx.odds) - cost, cost = cost, hi = hi,
                                        buf[k], buf[k + 1], buf[k + 2], buf[k + 3] }
                end
            end
        end
        local best
        if #cand == 0 then
            local rest = {}
            local li = cheapestIndex(hand)
            for hi, c in ipairs(hand) do if hi ~= li then rest[#rest + 1] = c end end
            best = value(ctx, E, nextS, left - 1, rest)       -- burns its cheapest card
        else
            if #cand > ctx.ownEval then
                table.sort(cand, function(x, y) return x.q > y.q end)
                for k = #cand, ctx.ownEval + 1, -1 do cand[k] = nil end
            end
            for _, m in ipairs(cand) do
                local mark = E.uTop
                if play(E, m, 1) then m.v = evaluate(E, ctx.par, ctx.odds, nil) - m.cost else m.v = -math.huge end
                undoTo(E, mark)
            end
            table.sort(cand, function(x, y) return x.v > y.v end)
            for k = 1, math.min(ctx.beam, #cand) do
                local m = cand[k]
                local rest = {}
                for hi, c in ipairs(hand) do if hi ~= m.hi then rest[#rest + 1] = c end end
                local mark = E.uTop
                play(E, m, 1)
                local v = value(ctx, E, nextS, left - 1, rest)
                undoTo(E, mark)
                if ctx.stop then ctx.ply = ctx.ply - 1; return 0 end
                if not best or v > best then best = v end
            end
        end
        ctx.ply = ctx.ply - 1
        return best
    end

    -- another seat: chance over the best card it holds
    local friend = (s % 2 == ctx.par)
    local savedMemo = ctx.memo
    ctx.memo = {}
    local outs = {}
    for _, c in ipairs(CARD_TYPES) do
        local q = ctx.odds[c]
        if q > 0 and (ctx.full or c ~= '$') then
            local v, own, buf, k = greedy(ctx, E, s, c)
            if v then
                -- it prefers keeping valuable cards (a Joker for a big payoff only)
                outs[#outs + 1] = { v = v, q = q, own = own - handVal(c),
                                    buf[k], buf[k + 1], buf[k + 2], buf[k + 3] }
            end
        end
    end
    ctx.memo = savedMemo
    -- the seat plays its best card: sort by ITS value, P(best = k) = q_k * prod(1 - q_j) over better ones
    table.sort(outs, function(x, y) return x.own > y.own end)
    local none = 1
    for _, o in ipairs(outs) do o.w = o.q * none; none = none * (1 - o.q) end
    -- expand the likeliest ctx.chanceK outcomes; the rest keep their greedy value; "no card" = burn
    table.sort(outs, function(x, y) return x.w > y.w end)
    local total = 0
    for k, o in ipairs(outs) do
        local v = o.v
        if k <= ctx.chanceK and left > 1 then
            local mark = E.uTop
            play(E, o, 1)
            v = value(ctx, E, nextS, left - 1, hand)
            undoTo(E, mark)
            if ctx.stop then ctx.ply = ctx.ply - 1; return 0 end
        end
        total = total + o.w * v
    end
    if none > 0.001 then
        local v = (left > 1 and none > 0.15) and value(ctx, E, nextS, left - 1, hand) or base
        total = total + none * v
    end
    ctx.ply = ctx.ply - 1
    return total
end

local function without(hand, card)
    local out, removed = {}, false
    for _, c in ipairs(hand) do if c == card and not removed then removed = true else out[#out + 1] = c end end
    return out
end

-- unseen card counts: the deck minus the bot's hand minus every card seen played (opts.seen = { card = count }).
-- opts.unseen overrides it directly.
function JE.unseenCounts(hand, opts)
    if opts and opts.unseen then return opts.unseen end
    local decks = (opts and opts.decks) or 1
    local u = {}
    for c, n in pairs(JE.DECK) do u[c] = n * decks end
    for _, c in ipairs(hand) do u[c] = math.max(0, (u[c] or 0) - 1) end
    if opts and opts.seen then for c, n in pairs(opts.seen) do u[c] = math.max(0, (u[c] or 0) - n) end end
    return u
end

-- Deep mode (offline only: far too slow for Tabletop Simulator's Lua). Jokers and 7 splits in the whole tree,
-- more outcomes per seat and a wider beam.
JE.DEEP = { CHANCE_K = 6, BEAM = 4, ROOT_KEEP = 20, OWN_EVAL = 40, GREEDY_FULL = 2 }
JE.OWN_EVAL = 24          -- own later turns: moves scored with the full cost function (best by the quick estimate)

-- Choose a move. Same shape as JokerSearch.choose: an action from JokerBot.legalActions or { burn = true, card = }.
-- opts: time_limit (s), clock, yield, max_depth, seen / unseen / decks (card counting), hand_size, debug,
--       deep (true: deep mode, see JE.DEEP)
function JE.choose(S, seat, hand, opts)
    opts = opts or {}
    local clock = opts.clock or os.clock
    local t0 = clock()
    JE.buildYield = nil
    if opts.yield then                                -- (time-sliced, like the search's own yields)
        local last = clock()
        JE.buildYield = function() if clock() - last >= 0.025 then opts.yield(); last = clock() end end
    end
    local saved = JB.STRATEGY
    JB.STRATEGY = 0                                   -- JokerBot's rule bonuses play no part in level 10
    local acts = JB.legalActions(S, seat, hand)
    JB.STRATEGY = saved
    if #acts == 0 then
        local r = JB.choose(S, seat, hand)            -- burn (JB.burnPick)
        r.depth, r.nodes, r.elapsed = 0, 0, clock() - t0
        return r
    end
    local unseen = JE.unseenCounts(hand, opts)
    local total = 0
    for _, n in pairs(unseen) do total = total + n end
    local deep = opts.deep and JE.DEEP or nil
    local P = deep or JE
    local limit = opts.time_limit or (opts.max_depth and 1e9) or 2
    local ctx = { clock = clock, deadline = t0 + limit, yield = opts.yield, slice = t0, nodes = 0,
                  stop = false, seat = seat, par = seat % 2, ply = 0, memo = {}, full = deep ~= nil,
                  chanceK = P.CHANCE_K, beam = P.BEAM, ownEval = P.OWN_EVAL, greedyFull = P.GREEDY_FULL,
                  odds = holdOdds(unseen, total, opts.hand_size or JE.HAND_SIZE) }
    -- root: every legal move, scored by the static cost function first
    local roots = {}
    for _, a in ipairs(acts) do
        local E = JE.load(a.state)
        E.me = seat
        local rest = without(hand, a.card)
        roots[#roots + 1] = { act = a, E = E, rest = rest, score = evaluate(E, ctx.par, ctx.odds, rest) }
    end
    table.sort(roots, function(x, y) return x.score > y.score end)
    local completed = 1
    local maxDepth = opts.max_depth or 4 * S.N
    local keep = P.ROOT_KEEP
    for depth = 2, maxDepth do
        if clock() >= ctx.deadline then break end
        local n = math.min(#roots, depth == 2 and #roots or keep)
        local scores = {}
        for k = 1, n do
            local r = roots[k]
            scores[k] = value(ctx, r.E, seat % S.N + 1, depth - 1, r.rest)
            if ctx.stop then break end
        end
        if ctx.stop then break end
        for k = 1, n do roots[k].score = scores[k] end
        local floor = scores[1]
        for k = 1, n do if scores[k] < floor then floor = scores[k] end end
        for k = n + 1, #roots do if roots[k].score > floor then roots[k].score = floor - 1 end end
        table.sort(roots, function(x, y) return x.score > y.score end)
        completed = depth
        if opts.progress then opts.progress(depth) end
    end
    local pick = roots[1].act
    pick.depth, pick.nodes, pick.elapsed, pick.score = completed, ctx.nodes, clock() - t0, roots[1].score
    if opts.debug then
        pick.all = {}
        for k, r in ipairs(roots) do r.act.score = r.score; pick.all[k] = r.act end
    end
    return pick
end

-- test hooks
JE._options, JE._land, JE._undoTo, JE._play = options, land, undoTo, play
-- (no `return` here: build_paste.sh concatenates the modules into one script)
