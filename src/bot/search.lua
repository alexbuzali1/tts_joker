-- bot/search.lua
-- Lookahead search for the Joker bot, with a difficulty scale (1 = easiest .. 9 = hardest) and a time limit.
-- Pure Lua like bot/rules.lua (no Tabletop Simulator calls), so it is unit tested outside the game
-- (tests/test_bot_search.lua). bot/play.lua runs it inside a TTS coroutine so the game doesn't freeze while a bot thinks.
--
-- HOW IT THINKS
--   Iterative deepening: search 1 ply (just my move), then 2 (my move + the next player's reply), then 3, ...
--   until the time limit (default 2 s) or the level's maximum depth. The result of the deepest COMPLETED
--   depth is used; a depth cut off by the timer is thrown away.
--   One ply = one seat's turn, in seat order around the table.
--
--   Other players' hands are hidden, so for every other seat the search guesses: for each card type they
--   might hold (A..K, Joker; 7 as a plain move) it assumes they play their best move for THEIR team with that
--   card (judged by the static evaluation), then combines the outcomes:
--     opponent : pessimism * worst case for us + (1 - pessimism) * card-frequency-weighted average
--     teammate : pessimism * best case for us  + (1 - pessimism) * weighted average
--   When the turn comes back round to the bot it uses the cards it really still holds (best of its top moves).
--   Leaves are scored with JokerBot.evaluate (bot/rules.lua) from the bot's team's point of view.
--
--   Only the most promising root moves (by the previous depth's score) are searched deeper ("roots" per level);
--   the rest keep their shallower score. Lower levels also add random noise and occasional blunders.

JokerSearch = JokerSearch or {}
local JS = JokerSearch
local JB = JokerBot

-- card types other players might hold, with their number of copies in the deck (weights for the average)
JS.CARDS = { 'a', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'j', 'q', 'k', '$' }
JS.CARD_WEIGHT = { a = 4, ['2'] = 4, ['3'] = 4, ['4'] = 4, ['5'] = 4, ['6'] = 4, ['7'] = 4, ['8'] = 4,
                   ['9'] = 4, ['10'] = 4, j = 4, q = 4, k = 4, ['$'] = 2 }

-- depth   : maximum plies (one ply = one seat's turn). "full" = two full rounds of the table.
-- roots   : how many of the best root moves are searched deeper than 1 ply
-- beam    : how many of its own top moves the bot considers on its later turns
-- pess    : weight on worst case (opponents) / best case (teammates) vs the weighted average
-- noise   : random score jitter added at the end (evaluation points; a marble on the ring is worth ~25-145)
-- blunder : chance of picking a random move from the top half instead of the best one
-- insight : 0..1, how much of the strategy rules the bot uses (JokerBot.STRATEGY during its search, and the weight
--           of the setup bonuses: 7 trap and ambush). 0 for levels 1-3 (plain play), full at level 9.
-- plan    : weight of the game-plan term (JokerBot.planValue: what the cards kept can do next turn). Levels 7-9.
-- team    : weight of the teammate term (what the next teammate can do from the position the move leaves). Levels 6-9.
JS.PLAN_ROOTS = 12           -- game plan: how many of the best moves get a plan value
JS.PLAN_TIME_SHARE = 0.4     -- at most this share of the think time
JS.PLAN_FIRST = false        -- plan before depth 2 (old order) instead of after it
-- Teammate term (user: "at 2 turns ahead it never sees a teammate move is bad"). The search goes round the table in
-- seat order, so the next teammate (2 seats on) is only reached at depth 3, and in Tabletop Simulator the bot mostly
-- finishes depth 2. So for the best JS.TEAM_ROOTS moves the bot also asks: from the position this move leaves, what
-- can my next teammate do? Its hand is hidden, so for each card type the teammate's best move is found, and the
-- gains are combined as an expected best reply: sorted best first, a card counts with the chance that the teammate
-- holds it and none of the better ones (JS.TEAM_HAND cards dealt from the deck). One gain is capped at
-- JS.TEAM_GAIN_CAP so a possible win next turn counts big but doesn't swamp everything. Added to the score only
-- when the search didn't reach the teammate's turn itself (completed depth < 3), so it is never counted twice.
JS.TEAM_ROOTS = 12
JS.TEAM_TIME_SHARE = 0.25
JS.TEAM_HAND = 5
JS.TEAM_GAIN_CAP = 600
JS.LEVELS = {
    [1] = { depth = 1,      roots = 1,  beam = 1, pess = 0.0, noise = 120, blunder = 0.35, insight = 0 },
    [2] = { depth = 1,      roots = 1,  beam = 1, pess = 0.0, noise = 80,  blunder = 0.25, insight = 0 },
    [3] = { depth = 1,      roots = 1,  beam = 1, pess = 0.0, noise = 45,  blunder = 0.15, insight = 0 },
    [4] = { depth = 2,      roots = 6,  beam = 1, pess = 0.3, noise = 25,  blunder = 0.08, insight = 0.3 },
    [5] = { depth = 2,      roots = 8,  beam = 1, pess = 0.4, noise = 12,  blunder = 0.04, insight = 0.5 },
    [6] = { depth = 3,      roots = 10, beam = 2, pess = 0.4, noise = 6,   blunder = 0.02, insight = 0.6, team = 0.3 },
    [7] = { depth = 4,      roots = 12, beam = 2, pess = 0.5, noise = 3,   blunder = 0, insight = 0.8, plan = 0.25, team = 0.4 },
    [8] = { depth = 6,      roots = 16, beam = 2, pess = 0.5, noise = 1,   blunder = 0, insight = 0.9, plan = 0.35, team = 0.45 },
    [9] = { depth = "full", roots = 24, beam = 3, pess = 0.5, noise = 0,   blunder = 0, insight = 1,   plan = 0.45, team = 0.5 },
}

------------------------------------------------------------------------
-- search context: node counting, time limit, yielding
------------------------------------------------------------------------
local function newCtx(opts)
    local clock = opts.clock or os.clock
    local now = clock()
    return {
        clock = clock,
        deadline = now + (opts.time_limit or 2),
        yield = opts.yield,                -- called every ~slice seconds so TTS can draw frames (coroutine.yield)
        slice = opts.slice or 0.025,
        slice_start = now,
        nodes = 0,
        stop = false,
    }
end

-- called at every node: checks the clock every 32 nodes, yields when the slice is used up
local function tick(ctx)
    ctx.nodes = ctx.nodes + 1
    if ctx.nodes % 32 ~= 0 then return end
    local now = ctx.clock()
    if now >= ctx.deadline then ctx.stop = true; return end
    if ctx.yield and now - ctx.slice_start >= ctx.slice then
        ctx.yield()
        ctx.slice_start = ctx.clock()
    end
end

------------------------------------------------------------------------
-- the search
------------------------------------------------------------------------
-- best k moves for `seat` holding just `card`, judged by the static evaluation for that seat's team.
-- full7: generate real 7 splits (used for the bot's own later turns, so it can see a 7 trap being sprung);
-- other players' 7s are treated as plain 7-step moves to keep the search fast.
local function topMoves(S, seat, card, k, ctx, full7)
    local acts = JB.legalActions(S, seat, { card }, { simple7 = not full7 })
    if full7 then acts = JB.dropIdleSevens(S, acts) end      -- the bot's own later turns follow the 7 rule too
    ctx.nodes = ctx.nodes + #acts
    if #acts == 0 then return nil end
    local par = seat % 2
    for _, a in ipairs(acts) do a.g = JB.evaluate(a.state, par) end
    table.sort(acts, function(x, y) return x.g > y.g end)
    local out = {}
    for i = 1, math.min(k, #acts) do out[i] = acts[i] end
    return out
end

-- value of state S for the bot's team when it is the turn of the seat `ply` seats after the bot,
-- searching `left` more plies
local function value(S, ply, left, ctx)
    tick(ctx)
    if ctx.stop then return 0 end
    if left == 0 then return JB.evaluate(S, ctx.parity) end
    -- the game is over once a team has every marble home: no more turns to search
    if JB.teamLeft(S, 0) == 0 or JB.teamLeft(S, 1) == 0 then return JB.evaluate(S, ctx.parity) end
    local seat = ((ctx.seat - 1 + ply) % S.N) + 1

    if seat == ctx.seat then                         -- back to the bot: it knows its own remaining cards
        local best, seen = nil, {}
        for _, c in ipairs(ctx.rest) do
            if not seen[c] then
                seen[c] = true
                for _, m in ipairs(topMoves(S, seat, c, ctx.L.beam, ctx, true) or {}) do
                    local v = value(m.state, ply + 1, left - 1, ctx)
                    if ctx.stop then return 0 end
                    if best == nil or v > best then best = v end
                end
            end
        end
        if best == nil then best = value(S, ply + 1, left - 1, ctx) end   -- nothing playable: burn
        return best
    end

    local friend = JB.sameTeam(seat, ctx.seat)
    local sum, wsum, extreme, passV = 0, 0, nil, nil
    for _, c in ipairs(JS.CARDS) do
        local moves = topMoves(S, seat, c, 1, ctx)
        local v
        if moves then
            v = value(moves[1].state, ply + 1, left - 1, ctx)
        else
            if passV == nil then passV = value(S, ply + 1, left - 1, ctx) end   -- that card can't move: burn
            v = passV
        end
        if ctx.stop then return 0 end
        local w = JS.CARD_WEIGHT[c]
        sum, wsum = sum + w * v, wsum + w
        if extreme == nil or (friend and v > extreme) or (not friend and v < extreme) then extreme = v end
    end
    local p = ctx.L.pess
    return p * extreme + (1 - p) * (sum / wsum)
end

-- expected gain (bot team's view) of the next teammate's reply from state T. See JS.TEAM_ROOTS.
local DECK_SIZE = 0
for _, c in ipairs(JS.CARDS) do DECK_SIZE = DECK_SIZE + JS.CARD_WEIGHT[c] end
function JS.teamReply(T, mate, parity, ctx)
    local base = JB.evaluate(T, parity)
    local gains = {}
    for _, c in ipairs(JS.CARDS) do
        -- no Joker: it is rare and a teammate saves it for a big payoff (JB.holdJoker), so it is mostly noise here
        local moves = c ~= '$' and topMoves(T, mate, c, 1, ctx, c == '7')     -- real 7 splits: teammate combos move our marbles
        if moves then
            local g = math.min(JS.TEAM_GAIN_CAP, moves[1].g - base)
            local q = 1 - (1 - JS.CARD_WEIGHT[c] / DECK_SIZE) ^ JS.TEAM_HAND     -- chance the teammate holds one
            gains[#gains + 1] = { g = g, q = q, text = moves[1].text }
        end
        if ctx.stop then return 0 end
    end
    table.sort(gains, function(x, y) return x.g > y.g end)
    local e, none = 0, 1
    for _, x in ipairs(gains) do
        e = e + x.g * x.q * none
        none = none * (1 - x.q)
    end
    return e, gains[1] and gains[1].text
end

local function without(hand, card)
    local out, removed = {}, false
    for _, c in ipairs(hand) do
        if c == card and not removed then removed = true else out[#out + 1] = c end
    end
    return out
end

-- Choose a move. Same return shape as JokerBot.choose: an action from JB.legalActions, or
-- { burn = true, card = ... } when nothing is legal. Extra fields on the result: depth (deepest completed
-- search), nodes, elapsed (seconds).
-- opts: level (1-9), time_limit (s), clock (fn -> seconds), yield (fn), rng (fn -> [0,1)), progress (fn(depth))
function JS.choose(S, seat, hand, opts)
    opts = opts or {}
    local level = math.max(1, math.min(9, math.floor(opts.level or 5)))
    local L = JS.LEVELS[level]
    local savedStrategy = JB.STRATEGY
    JB.STRATEGY = L.insight or 1                     -- strategy rules in bot_logic scale with the level
    local rng = opts.rng or math.random
    local ctx = newCtx(opts)
    local t0 = ctx.clock()

    local acts = JB.dropIdleSevens(S, JB.legalActions(S, seat, hand))
    if #acts == 0 then
        local r = JB.choose(S, seat, hand, rng)
        r.depth, r.nodes, r.elapsed = 0, 0, ctx.clock() - t0
        JB.STRATEGY = savedStrategy
        return r
    end

    -- Only one real choice (user: "don't overthink when there is only 1 possible move"): every legal move leads
    -- to the same position (e.g. all marbles in start and a single face card, or a J and a Q that both just bring
    -- a marble out). Then only the card matters: pick the cheapest one and play straight away, no search.
    local function key(st)
        local t = {}
        for i, m in ipairs(st.marbles) do t[i] = m.kind .. m.p end
        return table.concat(t, ",")
    end
    local k1, oneChoice = key(acts[1].state), true
    for i = 2, #acts do if key(acts[i].state) ~= k1 then oneChoice = false; break end end
    if oneChoice then
        local best
        for _, a in ipairs(acts) do
            a.score = JB.evaluate(a.state, seat % 2) + JB.cardAdjust(S, a) + JB.handAdjust(a.card, hand, S, a, seat)
            if not best or a.score > best.score then best = a end
        end
        best.depth, best.nodes, best.elapsed, best.only = 0, #acts, ctx.clock() - t0, true
        if opts.debug then best.all = acts end
        JB.STRATEGY = savedStrategy
        return best
    end

    ctx.seat, ctx.parity, ctx.L = seat, seat % 2, L
    local maxDepth = (L.depth == "full") and (2 * S.N) or L.depth
    if opts.max_depth then maxDepth = math.min(maxDepth, opts.max_depth) end    -- tests: TTS-like shallow search

    -- 7 trap: a setup bonus for the position after the move, if the bot still holds a 7 afterwards
    for _, a in ipairs(acts) do
        local rest = without(hand, a.card)
        local has7 = false
        for _, c in ipairs(rest) do if c == '7' then has7 = true end end
        -- setups that pay off a couple of turns later (deeper than the search sees): 7 trap + ambush
        -- (combo 7 only below level 7: the game-plan term covers it there and would count it twice)
        a.trap = (L.insight or 0) > 0 and L.insight * (JB.sevenTrapBonus(a.state, seat, has7) + ((L.plan or 0) > 0 and 0 or JB.comboSevenBonus(a.state, seat, has7))
                                                     + JB.ambushBonus(a.state, seat, rest)
                                                     - JB.burnRisk(a.state, seat, rest)) or 0
        a.trap = a.trap + JB.handAdjust(a.card, hand, S, a, seat)
    end

    -- depth 1: static evaluation of every legal move (this alone is the old bot)
    for _, a in ipairs(acts) do
        a.score = JB.evaluate(a.state, ctx.parity) + JB.cardAdjust(S, a) + a.trap
        tick(ctx)
    end
    ctx.stop = false                                  -- depth 1 always completes
    table.sort(acts, function(x, y) return x.score > y.score end)

    -- game plan (levels 7-9), run once depth 2 is done (JS.PLAN_FIRST = false; it used to run before and could
    -- cost the bot its look at the opponents' reply in Tabletop Simulator, 2026-11-11 game 4 turn 67)
    --: what the cards kept can do from here next turn (JB.planValue), for the best
    -- JS.PLAN_ROOTS moves. It may use up to JS.PLAN_TIME_SHARE of the think time; if it runs out, no move gets it.
    local function planTerm()
    if (L.plan or 0) > 0 then
        local n = math.min(JS.PLAN_ROOTS, #acts)
        local budget = math.min(ctx.deadline, ctx.clock() + JS.PLAN_TIME_SHARE * (ctx.deadline - t0))
        local done = 0
        -- only NEW chances count: what the kept cards can do after the move minus what they can already do now.
        -- Otherwise "keep the good card for next turn" would beat simply playing it (procrastinating).
        local before = {}
        for i = 1, n do
            local a = acts[i]
            local rest = without(hand, a.card)
            local sorted = {}
            for k, c in ipairs(rest) do sorted[k] = c end
            table.sort(sorted)
            local key = table.concat(sorted, ",")
            if not before[key] then before[key] = JB.planValue(S, seat, rest) end
            local pv, ptext = JB.planValue(a.state, seat, rest)
            a.plan, a.planText = L.plan * math.max(0, pv - before[key]), ptext
            done = i
            tick(ctx)
            if ctx.clock() >= budget then break end
        end
        ctx.stop = false
        if done == n then
            for i = 1, n do acts[i].trap = acts[i].trap + acts[i].plan; acts[i].score = acts[i].score + acts[i].plan end
            -- moves outside the top n keep their score; plans are >= 0, so they can't overtake a planned move
            table.sort(acts, function(x, y) return x.score > y.score end)
        else
            for i = 1, n do acts[i].plan, acts[i].planText = nil, nil end
        end
    end
    end
    if JS.PLAN_FIRST then planTerm() end
    -- teammate term (see JS.TEAM_ROOTS): computed once depth 2 is done (so it never costs the search its first
    -- look at the opponents' reply), and used only if the search then doesn't reach the teammate's turn (depth 3)
    local mate = ((seat - 1 + 2) % S.N) + 1
    local teamDone = false
    local function teamTerm()
        if not ((L.team or 0) > 0 and JB.sameTeam(mate, seat) and mate ~= seat) then return end
        local n = math.min(JS.TEAM_ROOTS, #acts)
        local budget = math.min(ctx.deadline, ctx.clock() + JS.TEAM_TIME_SHARE * (ctx.deadline - t0))
        local done = 0
        for i = 1, n do
            local e, text = JS.teamReply(acts[i].state, mate, ctx.parity, ctx)
            if ctx.stop then break end
            acts[i].team, acts[i].teamText = L.team * e, text
            done = i
            if ctx.clock() >= budget then break end
        end
        ctx.stop = false
        teamDone = done == n
        if not teamDone then for i = 1, n do acts[i].team, acts[i].teamText = nil, nil end end
    end
    local completed = 1

    -- deeper: only the most promising root moves, best first
    for depth = 2, maxDepth do
        if ctx.clock() >= ctx.deadline then break end
        local n = math.min(L.roots, #acts)
        local scores = {}
        for i = 1, n do
            local a = acts[i]
            ctx.rest = without(hand, a.card)
            scores[i] = value(a.state, 1, depth - 1, ctx) + JB.cardAdjust(S, a) + a.trap
            if ctx.stop then break end
        end
        if ctx.stop then break end                    -- incomplete depth: keep the previous result
        for i = 1, n do acts[i].score = scores[i] end
        -- moves not searched this deep keep a shallower score; never let them leapfrog searched ones
        local floor = scores[1]
        for i = 1, n do if scores[i] < floor then floor = scores[i] end end
        for i = n + 1, #acts do if acts[i].score > floor then acts[i].score = floor - 1 end end
        table.sort(acts, function(x, y) return x.score > y.score end)
        completed = depth
        if opts.progress then opts.progress(depth) end
        if depth == 2 and not JS.PLAN_FIRST then planTerm() end
        if depth == 2 and (maxDepth > 2 or opts.max_depth) then teamTerm() end
    end

    -- teammate's turn not searched: add the teammate term. Moves without one (outside the best JS.TEAM_ROOTS at
    -- depth 1) may not leapfrog moves that have one.
    if teamDone and completed < 3 then
        local floor
        for _, a in ipairs(acts) do
            if a.team then
                a.score = a.score + a.team
                if not floor or a.score < floor then floor = a.score end
            end
        end
        for _, a in ipairs(acts) do if not a.team and a.score > floor then a.score = floor - 1 end end
        table.sort(acts, function(x, y) return x.score > y.score end)
    end

    JB.aceSafety(S, acts)                            -- an Ace that is the only safe landing keeps its old cost
    JB.holdJoker(S, acts, hand, seat)                    -- the Joker waits for a big payoff

    -- difficulty: noise and blunders
    local pick = acts[1]
    if L.noise > 0 then
        local best, bestS
        for _, a in ipairs(acts) do
            local s = a.score + (rng() - 0.5) * 2 * L.noise
            if not best or s > bestS then best, bestS = a, s end
        end
        pick = best
    end
    if L.blunder > 0 and rng() < L.blunder then
        local half = math.max(1, math.floor(#acts / 2))
        pick = acts[math.floor(rng() * half) + 1]
    end
    pick.depth, pick.nodes, pick.elapsed = completed, ctx.nodes, ctx.clock() - t0
    if opts.debug then pick.all = acts end            -- every root move with its final score (tests / tuning)
    JB.STRATEGY = savedStrategy
    return pick
end
