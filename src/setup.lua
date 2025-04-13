--#include "constants.lua"
--#include "board.lua"

function buttonSetup(object,click_function,label)
    self.createButton({
        click_function = click_function,  -- Function to call when button is clicked
        function_owner = self,                   -- The object that owns the function
        label = label,                      -- Text on the button
        position = {0, 0.2, 0},                  -- Position relative to the chip
        rotation = {0, 90, 0},                  -- Rotation (usually face up)
        width = 600,                             -- Button width
        height = 300,                            -- Button height
        font_size = 150                          -- Font size
    })
    self.setName('8 Player Button')
    self.locked = true
    self.setColorTint({0, 0, 0, 0})
    self.tooltip = false 
end

function destroyButtons()
    destroyObject(getObjectFromGUID(FOUR_PLAYER_BUTTON_GUID))
    destroyObject(getObjectFromGUID(SIX_PLAYER_BUTTON_GUID))
    destroyObject(getObjectFromGUID(EIGHT_PLAYER_BUTTON_GUID))
end

function changeMatShape(shapeNumber)
    local hexMat = getObjectFromGUID("b62603")
    local data = hexMat.getData()
    data["CustomImage"]["CustomTile"]["Type"] = shapeNumber
    spawnObjectJSON({json = JSON.encode(data)})
    destroyObject(hexMat)
end

function loadGame(numPlayers)

    print("Loading " .. numPlayers .. " player game")
    
    --Change table and mat
    changeMatShape(MAT_SHAPES[numPlayers])
    Global.call("setTableShape",{shape=TABLE_SHAPES[numPlayers]})

    --Create board
    createBoard(numPlayers)

    local startPoints, boardPoints = getBoardPoints(numPlayers)

    --Set snap points
    Global.setSnapPoints(boardPoints)

    --Spawn marbles
    for i = 1,numPlayers*5 do
        spawnObject({
            type = "Red Ball",
            position = startPoints[i]["position"],
            scale = {MARBLE_SCALES[numPlayers],MARBLE_SCALES[numPlayers],MARBLE_SCALES[numPlayers]},
            callback_function = function(obj)
                obj.setColorTint(MARBLE_COLORS[math.floor((i-1)/5)+1]) 
            end
        })
    end 

    --Destroy buttons
    destroyButtons()
end