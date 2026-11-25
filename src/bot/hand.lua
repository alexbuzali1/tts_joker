-- bot/hand.lua
-- Choices that depend on the rest of the hand: tie-breakers between cards, keeping exit cards and Jokers for later,
-- small "game plan" credit for what the hand can do next turn, which card to burn when nothing is legal, and
-- JB.choose (the simple one-move chooser; the search in search.lua is what the bots normally use).
local JB = JokerBot


-- Tie-breaker from the rest of the hand (user, flag 23: "always play the card you have multiples of when in doubt"):
-- each extra copy of the played card in hand makes it JB.DUP_DISCOUNT cheaper (up to 2 copies), never below 0.
-- Small on purpose: K K J still leaves start with the J (K 10 - 2 = 8 > J 7).
JB.DUP_DISCOUNT = 2
JB.KING_EXIT_PENALTY = 25   -- K out of start while a J or Q could do it (flags 23/24/59; game 5 turn 99 still did it)
function JB.handAdjust(card, hand, S, act, seat)
    if card == 'k' and S and act and act.steps and act.steps[1] and S.marbles[act.steps[1].mi].kind == 'S' then
        for _, c in ipairs(hand or {}) do
            if c == 'j' or c == 'q' then return JB.handAdjustCore(card, hand, S, act, seat) - JB.STRATEGY * JB.KING_EXIT_PENALTY end
        end
    end
    return JB.handAdjustCore(card, hand, S, act, seat)
end
-- A 7 costs JB.CARD_COST['7'] (20) so it isn't spent where a plain card does the same (game 6 flag 33). When the 7
-- brings a marble into the finish that no other card in hand could bring to that cell, that cost is refunded down to
-- the old 4 (game 4 turn 67: only the 7 could put teammate Blue's 4th marble home).
local SINGLE = { a = 1, ['2'] = 2, ['3'] = 3, ['4'] = 4, ['5'] = 5, ['6'] = 6, ['9'] = 9, ['10'] = 10, j = 11, q = 12, k = 13 }
function JB.sevenOnlyEntryRefund(hand, S, act)
    if not (S and act and act.card == '7' and act.steps) or JB.STRATEGY <= 0 then return 0 end
    for _, st in ipairs(act.steps) do
        local m = S.marbles[st.mi]
        if st.kind == 'G' and m.kind == 'R' then
            local need = JB.distToEntrance(S, m.seat, m.p) + st.p
            local other = false
            for _, c in ipairs(hand or {}) do if SINGLE[c] == need then other = true end end
            if not other then return JB.STRATEGY * ((JB.CARD_COST['7'] or 0) - 4) end
        end
    end
    return 0
end
function JB.handAdjustCore(card, hand, S, act, seat)
    local n = -1
    for _, c in ipairs(hand or {}) do if c == card then n = n + 1 end end
    local adj = 0
    if n > 0 then adj = JB.STRATEGY * math.min(JB.CARD_COST[card] or 0, JB.DUP_DISCOUNT * math.min(2, n)) end
    -- Jokers: the cost is what keeping a Joker is worth, and only the last one held is scarce. With n+1 held, playing
    -- one costs 1/(n+1) of it (flag 45: Red held 3 Jokers and nudged a marble 1 with an Ace instead)
    if card == '$' and n > 0 and S and seat then
        local spare = JB.spareJokers(S, seat, hand)
        if spare >= JB.SPARE_JOKERS_MIN then adj = JB.STRATEGY * (JB.CARD_COST['$'] * JB.boardScale(S)) * (1 - 1 / spare) end
    end
    -- Spare face card (user, flag 39: "should have played a queen instead of a 5 and keep moving"): the face-card
    -- board-move cost (JB.FACE_BOARD_COST) is there to keep a way out of start. When the bot keeps at least
    -- JB.SPARE_EXIT_CARDS other exit cards (A, J, Q, K, Joker), this one is spare and the extra cost is refunded.
    if S and act and JB.FACE_BOARD_COST[card] then
        local extra = JB.faceBoardExtra and JB.faceBoardExtra(S, act) or 0
        if extra > 0 then
            local others, skipped = 0, false
            for _, c in ipairs(hand) do
                if c == card and not skipped then skipped = true
                elseif JB.EXIT_CARDS[c] then others = others + 1 end
            end
            if others >= JB.SPARE_EXIT_CARDS then adj = adj + extra end
        end
    end
    -- Stacked hand (user: "when you have that many you should be flying around the board helping teammates and
    -- playing defence"): with JB.STACKED_EXIT_CARDS or more OTHER exit cards kept, a face card costs nothing
    -- at all (its base cost and its board-move cost are both refunded). Few exit cards: stay thrifty (burn risk).
    local fromStart = S and act and act.steps and act.steps[1] and S.marbles[act.steps[1].mi].kind == 'S'
    if S and act and not fromStart and JB.FACE_BOARD_COST[card] then   -- (aces stay held: user)   -- board moves only: out of
        local others, skipped = 0, false                                                -- start, cheapest card wins
        for _, c in ipairs(hand) do
            if c == card and not skipped then skipped = true
            elseif JB.EXIT_CARDS[c] then others = others + 1 end
        end
        if others >= JB.STACKED_EXIT_CARDS then
            local base = JB.CARD_COST[card] or 0
            if JB.CARD_COST_PLAIN[card] then base = JB.CARD_COST_PLAIN[card] + JB.STRATEGY * (base - JB.CARD_COST_PLAIN[card]) end
            adj = adj + JB.STRATEGY * base
            if not (others >= JB.SPARE_EXIT_CARDS and JB.faceBoardExtra and JB.FACE_BOARD_COST[card]) then
                adj = adj + (JB.FACE_BOARD_COST[card] and JB.faceBoardExtra(S, act) or 0)
            end
        end
    end
    adj = adj + JB.parkMoveBonus(S, act, hand) - JB.parkLeavePenalty(S, act) + JB.fixableGapRefund(S, act, hand)
          - JB.avoidableGapPenalty(S, act, hand) - JB.spareFaceFinishPenalty(S, act, hand) + JB.sevenOnlyEntryRefund(hand, S, act)
    -- A risky 8 with no spare (user, flag 62: "shouldn't play the 8 there unless it has multiple"): with another 8
    -- in hand you can try again if it gets bonked; with just the one, its landing danger costs 50% more.
    if S and act and card == '8' then
        local others = -1
        for _, c in ipairs(hand) do if c == '8' then others = others + 1 end end
        if others <= 0 then adj = adj - JB.STRATEGY * JB.SINGLE_EIGHT_EXTRA * JB.landingPenalty(act) end
    end
    -- Finished player (user, flag 52: "it should have been trying to play defense or run"): once all your marbles
    -- are home and your teammates have none left in start, keeping exit cards is pointless; A, J, Q, K and 10 are
    -- just movement, so their cost is refunded (Joker, 7 and 8 rules still apply).
    if S and act and seat and JB.FREE_WHEN_FINISHED[card] and JB.isFinished(S, seat) then
        local mateInStart = false
        for _, o in ipairs(S.marbles) do
            if o.seat ~= seat and JB.sameTeam(o.seat, seat) and o.kind == 'S' then mateInStart = true end
        end
        if not mateInStart then adj = adj + JB.cardCost(S, act) end
    end
    -- ... and run with the big cards (user, flags 56/57: "should be playing the highest value cards to run around
    -- the board, not a 9"): small cards (A-6) are what a last marble needs to get exactly into the finish, so a
    -- finished player pays JB.KEEP_SMALL_COST to spend one on anything but entering a finish; 9s count as small-ish.
    if S and act and seat and JB.isFinished(S, seat) and JB.SMALL_CARDS[card] and not JB.entersFinish(S, act) then
        adj = adj - JB.STRATEGY * JB.SMALL_CARDS[card]
    end
    return adj
end
JB.STACKED_EXIT_CARDS = 3
JB.SINGLE_EIGHT_EXTRA = 0.5
JB.FREE_WHEN_FINISHED = { a = true, j = true, q = true, k = true, ['10'] = true }
JB.SMALL_CARDS = { a = 15, ['2'] = 15, ['3'] = 15, ['4'] = 15, ['5'] = 15, ['6'] = 12, ['9'] = 8 }   -- finished player

-- A gap you can close next turn is fine (user, 2v2 all-bot game: Red with A and 3, finish cell 5 filled, marble on
-- its entrance: "an easy move into home and clean on the next turn"): when a move enters the finish leaving exactly
-- one gap and you keep the card that moves that marble straight into the gap (A = 1 ... 5), the gap costs (move
-- penalty and the board's gap penalty) are refunded and the setup earns JB.FIXABLE_GAP_BONUS.
JB.FIXABLE_GAP_BONUS = 30
JB.ESCAPE_RELIEF = 1.0           -- escaping a threat into the finish with gaps: share of the gap cost forgiven (user: 3 gaps
                                 -- "good if under attack"; was 0.75 and lost by 0.1 in set piece escape-threat)
JB.JAM_PENALTY = 80              -- extra for making an already-untidy finish worse (set piece no-entry-behind-jam)
JB.ESCAPE_RELIEF_PER_THREAT = 0.25   -- (one threat 0.75, two or more 1.0; see cleanHouseBonus)
local GAP_STEPS = { a = 1, ['2'] = 2, ['3'] = 3, ['4'] = 4, ['5'] = 5 }
function JB.fixableGapRefund(S, act, hand)
    if not (S and act and act.state and act.steps) or JB.STRATEGY <= 0 then return 0 end
    for _, st in ipairs(act.steps) do
        local seat = S.marbles[st.mi].seat
        -- only your own finish (or a teammate's once you're finished): the closing card has to be in the hand of
        -- whoever moves that marble next (2026-11-11 turn 50: Blue's A "closed" Red's gap, so a 7 put Red in with a gap)
        local mine = not act.seat or seat == act.seat or JB.isFinished(S, act.seat)
        if st.kind == 'G' and mine then
            local before, after = JB.untidyCells(S, seat), JB.untidyCells(act.state, seat)
            -- any number of gaps, as long as ONE kept card then moves this marble into the deepest free cell and the
            -- finish is clean (user, 2026-11-11 game 3: Green 3 out with 2 and 6 played the 2 first and stayed
            -- exposed; "if it has 2 cards to play into the finish it should play the one that makes it safe first")
            if after > before then
                local deepest = 0
                for j = JB.GOAL_SIZE, 1, -1 do if not act.state.goal[seat][j] then deepest = j; break end end
                local need = deepest - st.p
                local shallower = false        -- another own marble between the entrance and this one would stay behind
                for j = 1, st.p - 1 do if act.state.goal[seat][j] then shallower = true end end
                -- and the way to the deepest free cell must be clear: marbles can't jump in the finish (game 5 flag 30:
                -- entering cell 1 behind marbles in 2 and 3 can't be "closed" by a kept card)
                for j = st.p + 1, deepest - 1 do if act.state.goal[seat][j] then shallower = true end end
                local skipped = false
                for _, c in ipairs(hand or {}) do
                    if c == act.card and not skipped then skipped = true
                    elseif need > 0 and not shallower and (GAP_STEPS[c] == need
                        -- a 7 closes it too: that part of the split, the rest on another marble (user, 2026-11-11
                        -- game 6 flag 32: "it could go in with 5 and clean with 7")
                        -- (only if the 7 can be split: a teammate has a marble to take the rest; house rule)
                        or (c == '7' and need <= 6 and JB.sevenMustSplit(act.state, act.seat or seat))) then
                        local gaps = after - before
                        return JB.STRATEGY * (JB.gapMoveCharge(S, act, seat, gaps) + JB.UNTIDY_PENALTY * gaps + JB.FIXABLE_GAP_BONUS)
                    end
                end
            end
        end
    end
    return 0
end

-- A gap you didn't have to make (user: "it should always be checking if a distance it wants to travel can be made
-- with a combination of cards in its hand"): a move that enters the finish leaving a gap costs another
-- JB.AVOIDABLE_GAP_PENALTY when the hand held a clean way in for that marble instead: one card, or any two cards
-- played one after the other (either order, small cards to K and 7 as a plain 7), that land it in the deepest free
-- finish cell. Not when the gap can be closed next turn (JB.fixableGapRefund).
JB.AVOIDABLE_GAP_PENALTY = 80
local FORWARD = { a = 1, ['2'] = 2, ['3'] = 3, ['4'] = 4, ['5'] = 5, ['6'] = 6, ['7'] = 7, ['9'] = 9, ['10'] = 10,
                  j = 11, q = 12, k = 13 }
-- can cards from `hand` (one, or two in a row) bring marble mi of S into finish cell `cell`?
function JB.cleanPathInHand(S, mi, cell, hand)
    local m = S.marbles[mi]
    local function lands(st, idx, v)
        local k, p = JB.numericTarget(st, idx, v, true)
        return k, p
    end
    for i, c in ipairs(hand) do
        local v = FORWARD[c]
        if v then
            local k, p = lands(S, mi, v)
            if k == 'G' and p == cell then return true end
            if k == 'R' then
                -- a second card from where the first one leaves it (blockers ignored except the marble's own finish)
                local T = JB.clone(S)
                T.marbles[mi].p = p
                T = JB.newState(S.N, T.marbles)
                for j, c2 in ipairs(hand) do
                    local v2 = FORWARD[c2]
                    if j ~= i and v2 then
                        local k2, p2 = lands(T, mi, v2)
                        if k2 == 'G' and p2 == cell then return true end
                    end
                end
            end
        end
    end
    return false
end
function JB.avoidableGapPenalty(S, act, hand)
    if not (S and act and act.state and act.steps and hand) or JB.STRATEGY <= 0 then return 0 end
    for _, st in ipairs(act.steps) do
        local m = S.marbles[st.mi]
        if st.kind == 'G' and m.kind == 'R' then
            local seat = m.seat
            if JB.untidyCells(act.state, seat) > JB.untidyCells(S, seat) and JB.fixableGapRefund(S, act, hand) == 0 then
                local deepest = 0
                for j = JB.GOAL_SIZE, 1, -1 do if not S.goal[seat][j] then deepest = j; break end end
                if deepest > 0 and st.p ~= deepest and JB.cleanPathInHand(S, st.mi, deepest, hand) then
                    return JB.STRATEGY * JB.AVOIDABLE_GAP_PENALTY
                end
            end
        end
    end
    return 0
end

-- Don't spend a face card on a finish the small cards can do (user: "if the turn is a clean finish with the face
-- card but smaller cards could do the trick and there is no defender nearby to make it risky, then use the face card
-- to bring a ball out. if there is a defender, use the face card to finish"). A J/Q/K that brings a marble cleanly
-- into its deepest free finish cell costs JB.SPARE_FACE_FINISH_PENALTY when: the marble isn't threatened where it
-- stands, the other small cards in hand (2-10, no faces, aces or Jokers) can finish it cleanly too (one card or two in
-- a row), and the player has a marble in start with its exit free (so the face card has a better job).
JB.SPARE_FACE_FINISH_PENALTY = 130   -- plus that move's JB.cleanEntryBonus
local FACE = { j = true, q = true, k = true }
local SMALL_PATH = { ['2'] = true, ['3'] = true, ['4'] = true, ['5'] = true, ['6'] = true, ['7'] = true, ['9'] = true,
                     ['10'] = true }
function JB.spareFaceFinishPenalty(S, act, hand)
    if not (S and act and act.state and act.steps and hand) or not FACE[act.card] or JB.STRATEGY <= 0 then return 0 end
    local st = act.steps[1]
    local m = S.marbles[st.mi]
    if #act.steps ~= 1 or st.kind ~= 'G' or m.kind ~= 'R' then return 0 end
    local seat = m.seat
    local deepest = 0
    for j = JB.GOAL_SIZE, 1, -1 do if not S.goal[seat][j] then deepest = j; break end end
    if st.p ~= deepest then return 0 end
    local inStart = false
    for _, z in ipairs(S.marbles) do if z.seat == seat and z.kind == 'S' then inStart = true end end
    local onExit = S.ring[JB.exitCell(seat)]
    if not inStart or (onExit and S.marbles[onExit].seat == seat) then return 0 end
    local par = seat % 2
    -- a defender (a real enemy marble in range behind it, or it sits on an enemy's exit): finish now. Enemies that
    -- could still come out of start don't count here
    local ex = JB.exitThreats(S, par)
    if JB.threatsAt(S, m.p, par, ex, true) > 0 or ex[m.p] then return 0 end
    local small, skipped = {}, false
    for _, c in ipairs(hand) do
        if c == act.card and not skipped then skipped = true
        elseif SMALL_PATH[c] then small[#small + 1] = c end
    end
    if not JB.cleanPathInHand(S, st.mi, deepest, small) then return 0 end
    return JB.STRATEGY * (JB.SPARE_FACE_FINISH_PENALTY + JB.cleanEntryBonus(S, act))   -- that entry is clean too
end

-- Park on a teammate's exit (user, flag 46: "should def prioritize landing in front of teammates home"): when the
-- teammate comes out it bonks you on to your own finish entrance. A move that parks there (teammate has marbles in
-- start, your entrance isn't blocked by your own marble) earns JB.PARK_MOVE_BONUS, plus JB.PARK_FINISH_BONUS when
-- you keep the exact card that takes you from your entrance into your deepest free finish cell (A = 1 ... 5).
JB.PARK_MOVE_BONUS = 40
JB.PARK_FINISH_BONUS = 40
local CARD_STEPS = { a = 1, ['2'] = 2, ['3'] = 3, ['4'] = 4, ['5'] = 5 }
-- Leaving a park costs too (user, flag 66: "a friendly bonk should take precedent"): moving a marble off a
-- teammate's exit cell while that teammate still has marbles in start gives up the jump: -JB.PARK_LEAVE_PENALTY.
JB.PARK_LEAVE_PENALTY = 80
function JB.parkLeavePenalty(S, act)
    if not (S and act and act.steps) or JB.STRATEGY <= 0 then return 0 end
    for _, st in ipairs(act.steps) do
        local m = S.marbles[st.mi]
        if m.kind == 'R' and not (st.kind == 'R' and st.p == m.p) then
            for t = 1, S.N do
                if t ~= m.seat and JB.sameTeam(t, m.seat) and m.p == JB.exitCell(t) then
                    for _, o in ipairs(S.marbles) do
                        if o.seat == t and o.kind == 'S' then return JB.STRATEGY * JB.PARK_LEAVE_PENALTY end
                    end
                end
            end
        end
    end
    return 0
end

JB.PARK_FULL_GAIN = 72    -- cells of jump (to its own entrance) for the full JB.PARK_MOVE_BONUS; less, less bonus
function JB.parkMoveBonus(S, act, hand)
    if not (S and act and act.steps and act.state) or JB.STRATEGY <= 0 then return 0 end
    local T = act.state
    local best = 0
    for _, st in ipairs(act.steps) do
        local m = T.marbles[st.mi]
        if st.kind == 'R' and S.marbles[st.mi].p ~= st.p then
            for t = 1, T.N do
                if t ~= m.seat and JB.sameTeam(t, m.seat) and st.p == JB.exitCell(t) then
                    local inStart = false
                    for _, o in ipairs(T.marbles) do if o.seat == t and o.kind == 'S' then inStart = true end end
                    local own = T.ring[JB.entrance(m.seat)]
                    -- not into a real enemy's range (user: "use a small card to land 7 or 8 from a defender"): a park
                    -- 1-6 in front of an enemy gets bonked before the teammate comes out
                    local par = m.seat % 2
                    local threatened = JB.threatsAt(T, st.p, par, JB.exitThreats(T, par), true) > 0
                    if inStart and not threatened and not (own and T.marbles[own].seat == m.seat) then
                        -- worth as much as the jump it waits for: a park a short way from its own entrance (user,
                        -- flag 47: the bot parked its marble ~31 cells from its entrance and called it a setup)
                        local gain = (JB.entrance(m.seat) - st.p) % T.R
                        local b = JB.PARK_MOVE_BONUS * math.min(1, gain / JB.PARK_FULL_GAIN)
                        local deepest = 0
                        for j = JB.GOAL_SIZE, 1, -1 do if not T.goal[m.seat][j] then deepest = j; break end end
                        local skipped = false
                        for _, c in ipairs(hand or {}) do
                            if c == act.card and not skipped then skipped = true
                            elseif deepest > 0 and CARD_STEPS[c] == deepest then b = b + JB.PARK_FINISH_BONUS; break end
                        end
                        if b > best then best = b end
                    end
                end
            end
        end
    end
    return JB.STRATEGY * best
end
JB.SPARE_EXIT_CARDS = 2

-- The Joker waits for a big payoff (user: bots were "too trigger happy with jokers"): after the search, a Joker
-- move is only played when it beats the best non-Joker move by at least JB.JOKER_MIN_MARGIN (on top of its card
-- cost), or when it is defensive (JB.defensiveBonus), or when nothing else is legal. Scaled by JB.STRATEGY.
JB.JOKER_MIN_MARGIN = 250   -- was 150; user 2026-11-11: play conservatively, no "crazy game altering mistakes" (game 3: Green's Joker on a 0-home player at +196 was "questionable")
-- The Ace's high cost (JB.CARD_COST.a) is for saving it from low-impact moves (user, 2026-11-12 flag 41). When an
-- Ace move lands safely and every other non-Joker move lands in danger (JB.landingPenalty), the Ace IS the
-- high-impact move (test turn 122: a last marble 7 behind Black instead of 1-2 in front): the extra cost above
-- JB.ACE_SAFE_COST is refunded. Only when the danger is worth it: every other move's landing penalty is at least
-- JB.ACE_SAFE_MIN (flag 42: an Ace nudge of a marble 6 past its exit, to dodge a ~30 risk, is still a waste).
-- Applied to the scored root moves, before JB.holdJoker.
JB.ACE_SAFE_COST = 35
JB.ACE_SAFE_MIN = 40
function JB.aceSafety(S, acts)
    if JB.STRATEGY <= 0 then return acts end
    local safeAce, otherSafe, others = false, false, 0
    for _, a in ipairs(acts) do
        if a.card ~= '$' and a.steps and a.steps[1] then
            local pen = JB.landingPenalty(a)
            if a.card == 'a' then safeAce = safeAce or pen <= 0
            else others = others + 1; otherSafe = otherSafe or pen < JB.ACE_SAFE_MIN end
        end
    end
    if not safeAce or otherSafe or others == 0 then return acts end
    local refund = JB.STRATEGY * math.max(0, (JB.CARD_COST.a or 0) - JB.ACE_SAFE_COST)
    for _, a in ipairs(acts) do
        if a.card == 'a' and a.steps and a.steps[1] and JB.landingPenalty(a) <= 0 then a.score = a.score + refund end
    end
    table.sort(acts, function(x, y) return x.score > y.score end)
    return acts
end

-- Jokers held beyond the ones still needed to bring marbles out of start (start marbles not covered by the other
-- exit cards in hand). Only those are "spare": the last Joker, or one needed for an exit, keeps its full value.
JB.SPARE_JOKERS_MIN = 3   -- user 2026-11-12: the discount starts at 3 spare Jokers
function JB.spareJokers(S, seat, hand)
    local jokers, otherExit, start = 0, 0, 0
    for _, c in ipairs(hand or {}) do
        if c == '$' then jokers = jokers + 1 elseif JB.EXIT_CARDS[c] then otherExit = otherExit + 1 end
    end
    for _, m in ipairs(S.marbles) do if m.seat == seat and m.kind == 'S' then start = start + 1 end end
    return jokers - math.max(0, start - otherExit)
end

function JB.holdJoker(S, acts, hand, seat)
    if JB.STRATEGY <= 0 then return acts end
    local bestOther
    for _, a in ipairs(acts) do
        if a.card ~= '$' and (not bestOther or a.score > bestOther) then bestOther = a.score end
    end
    if not bestOther then return acts end
    -- the margin is what the NEXT Joker is kept for: with several held, playing one still keeps the rest, and a hand
    -- clogged with Jokers has few plain cards left (user, 2026-11-12 flag 45: Red held 3 Jokers and spent an Ace on a
    -- 1-step nudge instead of a Joker that put its own marble 36 ahead and sent a teammate's marble home)
    local spare = (hand and seat) and JB.spareJokers(S, seat, hand) or 1
    if spare < JB.SPARE_JOKERS_MIN then spare = 1 end
    local need = bestOther + JB.STRATEGY * JB.JOKER_MIN_MARGIN * JB.boardScale(S) / math.max(1, spare)
    -- what plain cards can already do (user, 2026-11-11 game 3: "black had the 8 to bonk blue but used the joker
    -- instead. terrible"): a Joker that reaches the same position as another card, or bonks a marble another card
    -- also bonks, gets no defensive / multi-bonk exemption, and is never played over that card
    local function key(st) local t = {} for i, m in ipairs(st.marbles) do t[i] = m.kind .. m.p end return table.concat(t, ",") end
    local plainState, plainBonk = {}, {}
    for _, a in ipairs(acts) do
        if a.card ~= '$' and a.state then
            local k = key(a.state)
            if not plainState[k] or a.score > plainState[k] then plainState[k] = a.score end
            for _, b in ipairs(a.bumpList or {}) do if not b.friendly then plainBonk[b.idx] = true end end
        end
    end
    for _, a in ipairs(acts) do
        if a.card == '$' and a.state then
            local same = plainState[key(a.state)]
            local dup = false
            for _, b in ipairs(a.bumpList or {}) do if not b.friendly and plainBonk[b.idx] then dup = true end end
            if same then a.held = true; a.score = math.min(a.score, same - 1)
            elseif dup and JB.defensiveBonus(S, a) > 0 then a.score = a.score - JB.STRATEGY * JB.defensiveBonus(S, a) end
        end
    end
    for _, a in ipairs(acts) do
        -- a Joker that leaves its own marble further from home than it was (it jumps past its own entrance) is
        -- never worth it unless forced (user, 2026-11-11 game 3: Black's Joker from 52 out jumped to 67 out to
        -- bonk Blue, "terrible joker")
        local backwards = false
        if a.card == '$' and a.steps and a.steps[1] then
            local m = S.marbles[a.steps[1].mi]
            if m.kind == 'R' and a.steps[1].kind == 'R'
               and JB.distToEntrance(S, m.seat, a.steps[1].p) > JB.distToEntrance(S, m.seat, m.p) then backwards = true end
            -- except to stop a marble about to go in (6 or fewer from its finish) of a player with 3+ home
            for _, b in ipairs(a.bumpList or {}) do
                local z = S.marbles[b.idx]
                if not b.friendly and z.kind == 'R' and JB.goalCount(S, z.seat) >= JB.JOKER_DEFENCE_HOME
                   and JB.distToEntrance(S, z.seat, z.p) <= 6 then backwards = false end
            end
        end
        if a.card == '$' and (backwards or (a.score < need and JB.defensiveBonus(S, a) <= 0 and JB.chainBonus(a) <= 0)) then   -- multi-bonk Jokers are a big payoff too
            a.held = true
            a.score = math.min(a.score, bestOther - 1)
        end
    end
    table.sort(acts, function(x, y) return x.score > y.score end)
    return acts
end

-- Game plan (user: "they don't think about maximizing positions in advance"): with 4-8 players the search rarely
-- reaches the bot's own next turn, so it can't see that a move sets up a good next turn. planValue scores the position
-- after a move by what the cards the bot keeps could do from there next turn: the gain of the best follow-up plus half
-- the gain of the best follow-up with a different card (both as if nobody moved in between; the caller discounts it).
-- Card costs and the 7/8 rules apply to the follow-ups, so "a Joker could do something" is not a plan.
-- bot_search uses planValue(after) - planValue(now) with the same kept cards: only chances the move creates count.
-- Returns the value and a short text of the best follow-up.
JB.PLAN_CAP = 120          -- plans are guesses (others move in between); flag 43: 250 let a plan beat going home
function JB.planValue(S, seat, hand)
    if not hand or #hand == 0 then return 0 end
    local parity = seat % 2
    local base = JB.evaluate(S, parity)
    local bestByCard = {}
    -- each card once, and no Joker (its cost means it is almost never a plan, and it has the most moves to check)
    local cards, seen = {}, {}
    for _, c in ipairs(hand) do
        if c ~= '$' and not seen[c] then seen[c] = true; cards[#cards + 1] = c end
    end
    local acts = JB.dropIdleSevens(S, JB.legalActions(S, seat, cards))
    local top
    local exits = JB.exitThreats(S, parity)
    for _, a in ipairs(acts) do
        local g = JB.evaluate(a.state, parity) + JB.cardAdjust(S, a) - base
        -- clean finish first (flag 5): a follow-up that enters the finish but leaves a gap is not a plan
        if JB.entersFinish(S, a) and not JB.tidyEntry(S, a) then g = 0 end
        -- the follow-up only happens if the marble it moves survives until then (user, flag 37: an 8 to 3 short of
        -- the entrance with enemies behind, "next turn the 6 goes in", was a plan built on a marble about to be bonked)
        if g > 0 then
            local risk = 0
            for _, st in ipairs(a.steps or {}) do
                local m = S.marbles[st.mi]
                if m.kind == 'R' then risk = math.max(risk, JB.marbleRisk(S, m.p, parity, exits)) end
            end
            g = g * (1 - risk)
        end
        if not bestByCard[a.card] or g > bestByCard[a.card] then bestByCard[a.card] = g end
        if not top or g > top.g then top = { g = g, text = a.text } end
    end
    local g1, g2 = 0, 0
    for _, g in pairs(bestByCard) do
        if g > g1 then g1, g2 = g, g1 elseif g > g2 then g2 = g end
    end
    return math.min(JB.PLAN_CAP, g1 + 0.5 * g2), top and top.text
end

-- Which card to burn when nothing is legal (user, flag 72: "the burn order is anything then 10s then 7s then 8s,
-- especially if there are multiple of any card that gets burned before the 1 8"). Lower rank burns first; among
-- equal ranks the card you hold the most copies of goes first. The Joker is kept above everything.
JB.BURN_KEEP = { ['10'] = 2, ['7'] = 3, ['8'] = 4, ['$'] = 5 }    -- everything else: 1
function JB.burnPick(hand)
    local count = {}
    for _, c in ipairs(hand) do count[c] = (count[c] or 0) + 1 end
    local worst
    for _, c in ipairs(hand) do
        local r, wr = JB.BURN_KEEP[c] or 1, worst and (JB.BURN_KEEP[worst] or 1)
        if not worst or r < wr or (r == wr and count[c] > count[worst]) then worst = c end
    end
    return worst
end

-- Pick the best action. Returns action, or { burn=true, card=<cheapest card> } when nothing is legal.
function JB.choose(S, seat, hand, rng)
    local acts = JB.legalActions(S, seat, hand)
    acts = JB.dropIdleSevens(S, acts)
    local parity = seat % 2
    if #acts == 0 then
        local worst = JB.burnPick(hand)
        return { burn = true, card = worst, text = 'BURN ' .. tostring(worst) .. ' (no legal move)' }
    end
    for _, a in ipairs(acts) do
        local jitter = (rng and rng() or 0.5) * 0.5
        a.score = JB.evaluate(a.state, parity) + JB.cardAdjust(S, a) + JB.handAdjust(a.card, hand, S, a, seat) + jitter
    end
    table.sort(acts, function(x, y) return x.score > y.score end)
    JB.aceSafety(S, acts)
    JB.holdJoker(S, acts, hand, seat)
    return acts[1]
end
