--6 Player Button
--GUID: 3acad9

function onLoad()
        self.createButton({
        click_function = "load6Player",  -- Function to call when button is clicked
        function_owner = self,                   -- The object that owns the function
        label = "6 Player",                      -- Text on the button
        position = {0, 0.2, 0},                  -- Position relative to the chip
        rotation = {0, 90, 0},                  -- Rotation (usually face up)
        width = 600,                             -- Button width
        height = 300,                            -- Button height
        font_size = 150                          -- Font size
    })
    self.setName('6 Player Button') 
    self.locked = true
    self.setColorTint({0, 0, 0, 0})
    self.tooltip = false    

end

function load6Player()

    print('Loading 6 Player Game')
    destroyButtons()
    local sixPlayerBoard = getObjectFromGUID("577dcf")
    sixPlayerBoard.call("setup")
    
end

function destroyButtons()
    destroyObject(getObjectFromGUID("3acad9"))
    destroyObject(getObjectFromGUID("34e910"))
    destroyObject(getObjectFromGUID("fa9491"))
end