-- bot/play.lua  (Global script)
-- A bot's turn, start to finish (botTakeTurn, called by game/turns.lua):
--   1. wait for the board to settle, read it (bot/players.lua botReadState) and the bot's hand
--   2. think: the search (bot/search.lua, or bot/engine.lua at level 10) runs inside a TTS coroutine so the table
--      keeps drawing frames while it thinks
--   3. play the chosen card face up on its play zone, then carry the marbles over one step at a time (the normal
--      collision code bonks whatever they land on)
--   4. draw a card and hand the turn back
-- Also: the host's controls for a stuck bot (skip / rethink), stopping a bot for an undo, and "wait until no
-- marble is moving" (botWhenBoardSettled), which the turn cycle uses too.

-- tokens for the bot's current hand (parallel list of card objects)
local function botHandTokens(color)
    local tokens, objs = {}, {}
    for _, card in ipairs(BOT_STATE.hands[color]) do
        local t = botCardToken(card.getName())
        if t then tokens[#tokens + 1] = t; objs[#objs + 1] = card end
    end
    return tokens, objs
end

local function botCardName(token)
    local names = { a = "Ace", j = "Jack", q = "Queen", k = "King", ['$'] = "Joker" }
    return names[token] or token
end

-- Lay the chosen card face up on the bot's play zone.
local function botPlayCard(color, token, done)
    local hand = BOT_STATE.hands[color]
    local card
    for i, c in ipairs(hand) do
        if botCardToken(c.getName()) == token then card = c; table.remove(hand, i); break end
    end
    if not card then if done then done() end return end
    botLayoutHand(color)                                   -- close the gap left in the (debug-visible) hand
    local pile = Global.getTable("discard_piles")[color]
    local pp, rot = pile.getPosition(), pile.getRotation()
    local target = { x = pp.x, y = pp.y + 0.6, z = pp.z }
    local above = { x = pp.x, y = pp.y + 2.5, z = pp.z }
    card.interactable = true
    pcall(function() card.setInvisibleTo({}) end)         -- played: everyone sees it
    card.setVar("last_player_color", color)               -- lets the play-zone message accept it
    if botSpeed().instant then                             -- Instant speed: straight onto the zone, face up
        card.setRotation({ 0, rot.y, 0 })
        card.setLock(false)
        card.setPosition(target)
        Wait.time(function() if done then done() end end, 0.3)
        return
    end
    -- One continuous motion (user: the old teleport-up + instant flip looked choppy): the card stays locked (no
    -- physics wobble) while it glides from its place in the hand to just above the bot's own play zone, turning face
    -- up on the way, then sinks onto the zone and is unlocked so it settles and merges with the cards there.
    -- Lands above the bot's own zone, which is on the table in 6- and 8-player games too.
    card.setLock(true)
    card.setRotationSmooth({ 0, rot.y, 0 }, false, false)
    card.setPositionSmooth(above, false, false)
    local function settled() return card == nil or card.isDestroyed() or not card.isSmoothMoving() end
    local function finish()
        -- safety net: if the card didn't arrive, put it straight above the zone and let it drop in
        -- (the card no longer exists once it has merged into the cards already on the zone: that means it arrived)
        pcall(function()
            if card ~= nil and not card.isDestroyed() then
                card.setLock(false)
                local p = card.getPosition()
                if not isNear(p.x, p.z, pp.x, pp.z, 1) then card.setPosition({ x = pp.x, y = pp.y + 1.5, z = pp.z }) end
            end
        end)
        botAfter(0.4, function() if done then done() end end)
    end
    -- the smooth move starts on the next frame, so check after a short delay
    Wait.time(function()
        Wait.condition(function()
            pcall(function()
                if card ~= nil and not card.isDestroyed() then card.setPositionSmooth(target, false, true) end
            end)
            Wait.time(function() Wait.condition(finish, settled, 2, finish) end, 0.1)
        end, settled, 3, function() finish() end)
    end, 0.1)
end

------------------------------------------------------------------------
-- marble movement
------------------------------------------------------------------------
local function smoothTo(obj, pos, nextFn)
    obj.setPositionSmooth(pos, false, botSpeed().fast)
    Wait.time(function()
        Wait.condition(nextFn, function() return not obj.isSmoothMoving() end, 4, nextFn)
    end, 0.15)
end

-- lift, carry over, drop. The normal collision code bonks whatever is underneath.
local function botMoveMarble(obj, target, done)
    local p = obj.getPosition()
    obj.setTable("origin_position", { x = p.x, y = p.y, z = p.z })
    obj.setVar("picked_up", true)
    if botSpeed().instant then
        obj.setPosition({ x = target.x, y = target.y + 1.2, z = target.z })
        Wait.time(function() obj.setVar("picked_up", false); done() end, 0.1)
        return
    end
    smoothTo(obj, { x = p.x, y = p.y + 3, z = p.z }, function()
        smoothTo(obj, { x = target.x, y = p.y + 3, z = target.z }, function()
            smoothTo(obj, { x = target.x, y = target.y + 1.2, z = target.z }, function()
                obj.setVar("picked_up", false)
                done()
            end)
        end)
    end)
end

local function botRunSteps(act, i, objs, nsp, done, alive, quick)
    if alive and not alive() then return end                 -- the turn was skipped or is being redone
    local st = act.steps[i]
    if not st then done() return end
    local seat = act.state.marbles[st.mi].seat
    local target = nsp[JokerBot.cellToIndex(st.kind, st.p, seat)].position
    botMoveMarble(objs[st.mi], target, function()
        if quick then
            -- easy play (user: no pauses): only wait for the board to settle (a bonk gets a moment to start)
            Wait.time(function()
                botWhenBoardSettled(function() botRunSteps(act, i + 1, objs, nsp, done, alive, quick) end)
            end, (act.bumps or 0) > 0 and 0.3 or 0)
            return
        end
        -- Let every bonk play out before the next marble moves (user, flag 61: in a 7 where the first part bonks
        -- your own marble to your entrance, that marble was moved on while still flying, so it never landed and
        -- skipped over the marble sitting on the entrance). A short beat, then wait until no marble is moving.
        botAfter(act.bumps > 0 and 0.8 or 0.4, function()
            botWhenBoardSettled(function()
                botAfter(0.3, function() botRunSteps(act, i + 1, objs, nsp, done, alive) end)
            end)
        end)
    end)
end

-- play a chosen move with the bots' animation (easy play, easyplay.lua)
function botRunMove(act, objs, done, quick)
    if quick then
        botRunSteps(act, 1, objs, Global.getTable("non_start_points"), done, nil, true)
        return
    end
    botRunSteps(act, 1, objs, Global.getTable("non_start_points"), function()
        botAfter(0.4, function() botWhenBoardSettled(done) end)
    end)
end

------------------------------------------------------------------------
-- one bot turn
------------------------------------------------------------------------
local function botHighlight(color, on)
    local board = Global.getTable("boards_by_player")[color]
    local pile = Global.getTable("discard_piles")[color]
    if on then
        board.highlightOn(Color.fromString('Green'))
        pile.highlightOn(Color.fromString('Green'))
    else
        board.highlightOff()
        pile.highlightOff()
    end
end

local function botEndTurn(color, done)
    botDrawCards(color, 1, function()
        botSafe("finish check", function() botCheckFinish(color) end)
        botHighlight(color, false)
        botSetStatus(botName(color) .. " done", color)
        done()
    end)
end

function botCheckFinish(color)
    -- "made it home" and the winner are handled (once each, for humans and bots) by stats.lua
    if statsCheckFinish then statsCheckFinish() end
end

------------------------------------------------------------------------
-- thinking: JokerSearch.choose (bot_search.lua) inside a TTS coroutine, so the table keeps drawing frames
-- while the bot searches (it yields every ~25 ms). If the coroutine dies (a script error) a watchdog falls
-- back to the quick one-move choice so the game never gets stuck.
------------------------------------------------------------------------
-- Level 10 (bot_engine.lua) counts cards: every card played since the last reshuffle (stats.lua statsCardPlayed
-- calls botCardsSeen) is out of the unseen pool. A reshuffle shows up as the draw deck growing: the count resets.
BOT_SEEN = BOT_SEEN or {}
function botCardsSeen(token) if token then BOT_SEEN[token] = (BOT_SEEN[token] or 0) + 1 end end
local function botDeckCount()
    local ok, n = pcall(function() local d = findCenterDeck(); return d and d.getQuantity() or 0 end)
    return ok and n or 0
end
local function botCardCounting(N)
    local n = botDeckCount()
    if BOT_DECK_LAST and n > BOT_DECK_LAST + 2 then BOT_SEEN = {} end      -- discard piles went back in
    BOT_DECK_LAST = n
    local seen = 0
    for _, k in pairs(BOT_SEEN) do seen = seen + k end
    return BOT_SEEN, math.max(1, math.floor((n + seen + 6 * N) / 54 + 0.5))
end

function botThink(color, S, seat, tokens, done)
    local job = { finished = false }
    local function finish(act)
        if job.finished then return end
        job.finished = true
        Wait.time(function() done(act) end, 0.05)        -- continue outside the coroutine
    end
    job.run = function()
        if BOT_DIFFICULTY >= 10 then
            local seen, decks = botCardCounting(S.N)
            return JokerEngine.choose(S, seat, tokens, {
                time_limit = BOT_THINK_TIME, clock = os.clock or os.time, debug = true, seen = seen, decks = decks,
                yield = function() coroutine.yield(0) end,
                progress = function(depth)
                    botSetStatus(string.format("%s is thinking... %d turn%s ahead", botName(color), depth, depth == 1 and "" or "s"), color)
                end,
            })
        end
        return JokerSearch.choose(S, seat, tokens, {
            level = BOT_DIFFICULTY, time_limit = BOT_THINK_TIME, clock = os.clock or os.time, rng = math.random, debug = true,
            yield = function() coroutine.yield(0) end,
            progress = function(depth)
                botSetStatus(string.format("%s is thinking... %d turn%s ahead", botName(color), depth, depth == 1 and "" or "s"), color)
            end,
        })
    end
    job.finish = finish
    BOT_SEARCH_JOB = job
    startLuaCoroutine(Global, "botSearchCoroutine")
    Wait.time(function()
        if not job.finished then
            botHostMsg("BOT ERROR (search): " .. botChatName(color) .. "'s search didn't finish, playing a quick move", { 1, 0.4, 0.4 })
            finish(JokerBot.choose(S, seat, tokens, math.random))
        end
    end, BOT_THINK_TIME + 6)
end

function botSearchCoroutine()
    local job = BOT_SEARCH_JOB
    if job and not job.finished then job.finish(job.run()) end
    return 1
end

-- One bot turn. Every bot turn gets a token; each step checks it is still the live turn, so a turn the host
-- skipped (or that is being redone) can't carry on later. opts.replay = the card token the bot already played
-- this turn: think again with just that card (used by "rethink" after a broken move), don't play another card.
BOT_TURN_WATCHDOG = 25     -- seconds past the think time before a stuck bot turn is rethought, then skipped

function botTakeTurn(color, done, opts)
    opts = opts or {}
    local seat = botSeatIndex(color)
    BOT_STATE.token = (BOT_STATE.token or 0) + 1
    local token = BOT_STATE.token
    local cur = { color = color, done = done, played = opts.replay, token = token, finished = false }
    BOT_STATE.current = cur
    local function alive() return BOT_STATE.token == token end
    local function finish()
        if not alive() or cur.finished then return end
        cur.finished = true
        BOT_STATE.current = nil
        done()
    end

    local chip = getObjectFromGUID(TURN_BUTTON_GUID)
    if chip then chip.editButton({ index = 0, label = botName(color) .. "'s\nTurn", font_color = nameColorOnLight(color),
        tooltip = "Bot stuck? Host: click twice to skip its turn, right-click to make it rethink its move." }) end
    botHighlight(color, true)
    botSetStatus(botName(color) .. (opts.replay and " is rethinking..." or " is thinking..."), color)

    local function bail() if alive() then botHighlight(color, false); finish() end end

    -- watchdog: a turn that never finishes is rethought once, then skipped
    Wait.time(function()
        if alive() and not cur.finished then
            if not opts.retried then
                printToAll(botChatName(color) .. " seems stuck, rethinking its move")
                botRethink()
            else
                printToAll(botChatName(color) .. " is still stuck, skipping its turn")
                botSkipTurn()
            end
        end
    end, BOT_THINK_TIME + BOT_TURN_WATCHDOG)

    botAfter(1.0, function() botWhenBoardSettled(function()
        if not alive() then return end
        botSafe("turn", function()
            local S, objs = botReadState()
            local tokens = opts.replay and { opts.replay } or botHandTokens(color)
            if #tokens == 0 then
                printToAll(botChatName(color) .. " has no cards to play.")
                bail()
                return
            end
            -- who is burning (burned on their last turn): their start isn't a threat (JokerBot.BURNING)
            JokerBot.BURNING = {}
            pcall(function()
                for s, c in ipairs(PLAYER_COLORS[Global.getVar("num_players")] or {}) do
                    local ps = GAME_STATS and GAME_STATS.players and GAME_STATS.players[c]
                    if ps and (tonumber(ps.burnStreak) or 0) >= 1 then JokerBot.BURNING[s] = true end
                end
            end)
            -- search (bot_search.lua) runs spread over frames; the turn continues when it has a move
            botThink(color, S, seat, tokens, function(act)
              if not alive() then return end
              botSafe("record", function() botRecordMove(color, seat, S, tokens, act) end)
              botSafe("turn", function()
                local nsp = Global.getTable("non_start_points")
                local colors = PLAYER_COLORS[Global.getVar("num_players")]
                local how = act.depth and string.format(" (looked %d turn%s ahead, %.1fs)", act.depth, act.depth == 1 and "" or "s", act.elapsed or 0) or ""
                local function afterCard(fn)          -- play the card, unless it was already played (rethink)
                    if opts.replay then fn() else cur.played = act.card; botPlayCard(color, act.card, fn) end
                end
                if act.burn then
                    botSetStatus(botName(color) .. " burns a " .. botCardName(act.card), color)
                    afterCard(function() if alive() then botEndTurn(color, finish) end end)
                    return
                end
                -- describe the move for the chat log
                local parts = {}
                for _, st in ipairs(act.steps) do
                    local m = act.state.marbles[st.mi]
                    parts[#parts + 1] = marbleOwnerText(colors[m.seat]) .. " " .. (((st.mi - 1) % 5) + 1)
                end
                botSetStatus(botName(color) .. ": " .. botCardName(act.card) .. how, color)
                afterCard(function()
                    if not alive() then return end
                    botSafe("move", function()
                        printToAll(botChatName(color) .. " moves " .. table.concat(parts, " and "))
                        botRunSteps(act, 1, objs, nsp, function()
                            botAfter(0.4, function()
                                if not alive() then return end
                                -- game log (gamelog.lua): compare the board with what the bot meant to do
                                botWhenBoardSettled(function()
                                    if not alive() then return end
                                    if botVerifyMove then botSafe("verify", function() botVerifyMove(color, act) end) end
                                    botEndTurn(color, finish)
                                end)
                            end)
                        end, alive)
                    end, bail)
                end)
              end, bail)
            end)
        end, bail)
    end) end)                                           -- closes botWhenBoardSettled and botAfter
end

-- Host controls for a broken bot turn (Turn Button while a bot is playing; see endTurnClicked in turns.lua).
-- Skip: end the bot's turn as it is (move its marble by hand first if a move was left half done). Its hand is
-- topped back up to 6 and play moves on.
-- stop a bot's turn where it is, nothing drawn (undo.lua puts the hands back itself)
function botStopTurn()
    local cur = BOT_STATE.current
    if not cur then return false end
    BOT_STATE.token = (BOT_STATE.token or 0) + 1
    BOT_STATE.current = nil
    cur.finished = true
    botHighlight(cur.color, false)
    return true
end

function botSkipTurn()
    local cur = BOT_STATE.current
    if not cur then return false end
    BOT_STATE.token = (BOT_STATE.token or 0) + 1           -- the old turn's pending steps stop here
    BOT_STATE.current = nil
    cur.finished = true
    botHighlight(cur.color, false)
    botSetStatus(botName(cur.color) .. "'s turn was skipped", cur.color)
    printToAll(botChatName(cur.color) .. "'s turn was skipped by the host")
    local missing = 6 - #(BOT_STATE.hands[cur.color] or {})
    botDrawCards(cur.color, math.max(0, missing), function()
        botSafe("finish check", function() botCheckFinish(cur.color) end)
        cur.done()
    end)
    return true
end

-- Rethink: stop the current attempt and think again from the board as it is now. If the bot already played its
-- card this turn, it picks a new move for that same card instead of playing another one.
function botRethink()
    local cur = BOT_STATE.current
    if not cur then return false end
    BOT_STATE.token = (BOT_STATE.token or 0) + 1
    printToAll(botChatName(cur.color) .. " is rethinking its move")
    botTakeTurn(cur.color, cur.done, { replay = cur.played, retried = true })
    return true
end

------------------------------------------------------------------------
-- Wait until the board is still: no marble moving (smooth move, bonk flight, falling) or held by a player.
-- Used before a bot reads the board and before the next turn starts, so a bonk animation from the previous
-- turn can't be read as a marble sitting on the wrong cell. Gives up after 10 s (and carries on).
------------------------------------------------------------------------
function botBoardSettled()
    local mbp = Global.getTable("marbles_by_player")
    if not mbp then return true end
    for _, team in pairs(mbp) do
        for _, m in ipairs(team) do
            if m.isSmoothMoving() or m.resting == false or m.getVar("picked_up") or m.getVar("rejecting") then
                return false
            end
        end
    end
    return true
end

function botWhenBoardSettled(fn)
    -- a short pause first: a bonk starts its flight a moment after the drop
    Wait.time(function()
        Wait.condition(fn, botBoardSettled, 10, fn)
    end, 0.3)
end
