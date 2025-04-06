--4 Player Button
--GUID: 34e910

function onLoad()
        self.createButton({
        click_function = "load4Player",  -- Function to call when button is clicked
        function_owner = self,                   -- The object that owns the function
        label = "4 Player",                      -- Text on the button
        position = {0, 0.2, 0},                  -- Position relative to the chip
        rotation = {0, 90, 0},                  -- Rotation (usually face up)
        width = 600,                             -- Button width
        height = 300,                            -- Button height
        font_size = 150                          -- Font size
    })
    self.setName('4 Player Button')
    self.locked = true
    self.setColorTint({0, 0, 0, 0})
    self.tooltip = false  

end

function load4Player()
    print('Loading 4 Player Game')
    destroyButtons()
    loadSquareMat()
    Global.call("setTableShape",{shape="Square"})
end

function loadSquareMat()
    local hexMat = getObjectFromGUID("b62603")
    local data = hexMat.getData()
    data["CustomImage"]["CustomTile"]["Type"] = 0
    spawnObjectJSON({json = JSON.encode(data)})
    destroyObject(hexMat)
end

function destroyButtons()
    destroyObject(getObjectFromGUID("3acad9"))
    destroyObject(getObjectFromGUID("34e910"))
    destroyObject(getObjectFromGUID("fa9491"))
end