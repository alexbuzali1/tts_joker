-- The Reshuffle button (in the middle of the table, under the deck): gathers every played card from the play zones
-- back into the middle and shuffles it into the draw deck. Players press it when the deck runs out; the Global
-- script also does it by itself when the deck runs low (game/deck.lua autoReshuffleCheck calls `reshuffle` here).
--#include "../helpers.lua"
--#include "../cards.lua"

function onLoad()
    self.setName('Reshuffle Button')
end

-- Gather the play zones' cards into the middle, then shuffle once they've landed.
function reshuffle()

    -- Find decks and cards in discard piles
    local decksToCombine = {}
    local looseCards = {}

    for _, obj in ipairs(getAllObjects()) do
        if obj.tag == "Deck" and isInDiscardPile(obj,Global.getTable("discard_pile_positions")) then
            table.insert(decksToCombine, obj)
        elseif obj.tag == "Card" and isInDiscardPile(obj,Global.getTable("discard_pile_positions")) then
            table.insert(looseCards, obj)
        end
    end

    --Do nothing if no cards found to recombine
    if #decksToCombine == 0 and #looseCards == 0 then
        printToAll("No cards or decks found to recombine.")
        return
    end

    --Put all other decks and cards into the middle
    for i, deck in ipairs(decksToCombine) do
        deck.setRotation({180,0,0})
        deck.setPositionSmooth({0, 3 + i, 0})
    end
    for i, card in ipairs(looseCards) do
        card.setRotation({180,0,0})
        card.setPositionSmooth({0, 3 + i, 0})
    end

    --Shuffle the rebuilt deck once everything has landed
    Wait.time(function()
        local deck = findCenterDeck()
        if deck then deck.shuffle() end
        printToAll('Deck Reshuffled')
    end, 2)
end

-- Is the object lying on one of the play zones?
function isInDiscardPile(obj,discard_pile_positions)

    local pos = obj.getPosition()

    for _, discard_pile_pos in ipairs(discard_pile_positions) do
        if isNear(pos[1],pos[3],discard_pile_pos[1],discard_pile_pos[3],.1) then
            return true
        end
    end
    return false
end
