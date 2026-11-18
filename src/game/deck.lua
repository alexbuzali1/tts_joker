-- game/deck.lua  (Global script)
-- The draw deck during a game: drawing a card at the end of a turn, the automatic reshuffle when the deck runs low,
-- and the "Deal to 6" button (top-left panel) that tops every hand up to 6.

-- Draw cards into a player's hand FACE DOWN (user, 11-17: TTS's deal turns the card face up on the way, and
-- everyone saw it). The card is taken off the deck face down, glides to the hand still face down, and is flipped
-- once it's in the hand, where only its owner sees it (user, 11-18: the hand doesn't turn it over by itself). A card
-- that didn't make it in is put straight into the hand.
DRAW_GAP = 0.25                -- seconds between cards when drawing several
DRAW_CHECK = 2.0               -- seconds after which a card not in the hand is put there directly
DRAW_FLIP_DELAY = 0.2          -- once it's in the hand, wait this long (the hand settles it), then flip it face up
function drawCardsFaceDown(color, n, done)
    local k = 0
    local function one()
        k = k + 1
        if k > n then if done then done() end return end
        local deck = findCenterDeck()
        local ok = deck and pcall(function()
            local ht = Player[color].getHandTransform()
            local dp = deck.getPosition()
            local target = { x = ht.position.x, y = ht.position.y + 0.2, z = ht.position.z }
            local function glide(card)
                if not card then return end
                Wait.frames(function()
                    pcall(function()
                        card.setRotation({ 0, ht.rotation.y, 180 })
                        card.setPositionSmooth(target, false, false)
                    end)
                end, 1)
                local function inHand()
                    for _, o in ipairs(Player[color].getHandObjects() or {}) do if o == card then return true end end
                    return false
                end
                local function faceUp()
                    pcall(function()
                        if card.isDestroyed() then return end
                        local z = card.getRotation().z % 360
                        if z > 90 and z < 270 then card.flip() end
                    end)
                end
                -- flip it as soon as it's in the hand; if it never gets there, put it there and flip it
                Wait.condition(function() Wait.time(faceUp, DRAW_FLIP_DELAY) end,
                    function() local ok, r = pcall(inHand); return ok and r end, DRAW_CHECK, function()
                        pcall(function()
                            if card.isDestroyed() then return end
                            card.setPosition(target)
                            Wait.time(faceUp, DRAW_FLIP_DELAY + 0.3)
                        end)
                    end)
            end
            deck.takeObject({ position = { x = dp.x, y = dp.y + 1.5, z = dp.z }, rotation = { 0, ht.rotation.y, 180 },
                              smooth = false, callback_function = glide })
        end)
        if not ok then
            -- no deck object (a lone last card) or no hand: TTS's own deal
            pcall(function() if deck then deck.deal(1, color) end end)
        end
        Wait.time(one, DRAW_GAP)
    end
    one()
end

-- The player ending their turn draws one card. In-person seats (hybrid mode) draw from their real deck instead.
function turnDrawCard(color)
    if irlIsSeat(color) then return end
    local deck = findCenterDeck()
    if deck then
        drawCardsFaceDown(color, 1)
    else
        printToAll("No deck in the middle - " .. playerLabel(color) .. " couldn't draw. Press Reshuffle.")
    end
end

-- cards left in the middle (a lone last card is a Card, not a Deck)
local function cardsInMiddle()
    local deck = findCenterDeck()
    if deck then return deck.getQuantity() end
    for _, obj in ipairs(getAllObjects()) do
        if obj.tag == "Card" then
            local p = obj.getPosition()
            if isNear(p.x, p.z, 0, 0, 1) then return 1 end
        end
    end
    return 0
end

-- At the start of every turn: with fewer than (players + 2) cards left, put the discard piles back into the deck
-- (the Reshuffle button's own code) and shuffle once more after everything has landed.
AUTO_RESHUFFLE_BUSY = false
function autoReshuffleCheck()
    if AUTO_RESHUFFLE_BUSY then return end
    local n = cardsInMiddle()
    local limit = (Global.getVar("num_players") or 4) + 2
    if n >= limit then return end
    local btn = getObjectFromGUID(RESHUFFLE_BUTTON_GUID)
    if not btn then return end
    AUTO_RESHUFFLE_BUSY = true
    printToAll("Only " .. n .. " cards left: reshuffling the discard piles into the deck")
    btn.call("reshuffle")
    Wait.time(function()
        local deck = findCenterDeck()
        if deck then deck.shuffle() end
        AUTO_RESHUFFLE_BUSY = false
    end, 3.5)
end

-- "Deal to 6": every seat (humans and bots) is topped up to 6 cards, one seat after another.
function dealToSix(player)
    local colors = turnColors()
    if not colors then return end
    local i = 0
    local function nextSeat()
        i = i + 1
        local color = colors[i]
        if not color then printToAll("Everyone has 6 cards"); return end
        if botIsBot(color) then
            local have = #(BOT_STATE.hands[color] or {})
            if have < 6 then botDrawCards(color, 6 - have, function() Wait.time(nextSeat, 0.2) end) else nextSeat() end
        else
            local have = 0
            if Player[color] and Player[color].seated then
                for _, o in ipairs(Player[color].getHandObjects() or {}) do if o.tag == "Card" then have = have + 1 end end
                local deck = findCenterDeck()
                if have < 6 and deck then drawCardsFaceDown(color, 6 - have) end
            end
            Wait.time(nextSeat, 0.3)
        end
    end
    autoReshuffleCheck()
    Wait.time(nextSeat, AUTO_RESHUFFLE_BUSY and 3.8 or 0)
end
