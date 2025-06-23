--#include "constants.lua"
--#include "helpers.lua"

function dealCardsToAllPlayers(deck, count)
    for _, player in ipairs(Player.getPlayers()) do
        deck.deal(count, player.color)
    end
end

function findCenterDeck()
    for _, obj in ipairs(getAllObjects()) do
        if obj.tag == "Deck" then
            pos = obj.getPosition()
                if isNear(pos[1],pos[3],0,0,1) then
                return obj
            end
        end
    end
end

function labelDeck()
    
    deck = getObjectFromGUID(DECK_GUID)

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
