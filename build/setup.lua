-- Begin include: constants.lua
FOUR_PLAYER_BUTTON_GUID = "34e910"
SIX_PLAYER_BUTTON_GUID = "3acad9"
EIGHT_PLAYER_BUTTON_GUID = "fa9491"
MAT_ID = "b62603"
-- End include: constants.lua

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