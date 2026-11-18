-- cards.lua
-- The deck in the middle of the table: dealing, finding it, and labelling its cards.
--#include "constants.lua"
--#include "helpers.lua"

-- Deal `count` cards from `deck` to every seated player.
function dealCardsToAllPlayers(deck, count)
    for _, player in ipairs(Player.getPlayers()) do
        deck.deal(count, player.color)
    end
end

-- The draw deck: the Deck object at the centre of the table (nil while it's being rebuilt, or when only one card is
-- left, since a lone card isn't a Deck).
function findCenterDeck()
    for _, obj in ipairs(getAllObjects()) do
        if obj.tag == "Deck" then
            local pos = obj.getPosition()
            if isNear(pos[1], pos[3], 0, 0, 1) then
                return obj
            end
        end
    end
end

-- Name every card in the deck (CARD_NAMES, in order; two copies of the 54 cards make the 108-card deck) by taking
-- them out one by one into a new stack in the middle. The bots and the stats read the cards by these names.
function labelDeck()

    local deck = getObjectFromGUID(DECK_GUID)

    local total = #deck.getObjects()

    for i = 0, total - 1 do
        deck.takeObject({
            index = 0,
            position = {x = 0, y=1.2 + i * .1, z = 0},
            smooth = false,
            callback_function = function(card)
                local label = CARD_NAMES[(i % 54) + 1]
                card.setName(label)
                card.tooltip = false
            end
        })
    end
end
