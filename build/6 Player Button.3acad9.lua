-- Begin include: ../setup.lua
-- Begin include: constants.lua
--Default object GUID's
FOUR_PLAYER_BUTTON_GUID = "34e910"
SIX_PLAYER_BUTTON_GUID = "3acad9"
EIGHT_PLAYER_BUTTON_GUID = "fa9491"
MAT_ID = "b62603"

--Mat/table shapes
MAT_SHAPES = {[4] = 0, [6] = 1, [8] = 2}
TABLE_SHAPES = {[4] = "Square", [6] = "Hexagon", [8] = "Octagon"}

--Board dimensions
DEFAULT_BOARD_LENGTH = 6.5074
DEFAULT_BOARD_WIDTH = 1.4754
WIDTH_LEG_RATIO = 3.77
BOARD_Y = 1.16
BOARD_SCALES = {[4] = 2.95, [6] = 2.10, [8] = 1.70}

--Marble dimensions/colors
MARBLE_SCALES = {[4] = 1.15, [6] = 0.83, [8] = 0.66}
MARBLE_HEIGHTS = {[4] = 1.75, [6] = 1.85, [8] = 1.70}
MARBLE_COLORS = {
    {r = 0, g = 0, b = 0},
    {r = 0, g = 0, b = 1},
    {r = 0, g = 1, b = 0},
    {r = 1, g = 0, b = 0},
    {r = 0, g = 1, b = 1},
    {r = 1, g = 0, b = 1},
    {r = 1, g = 1, b = 0},
    {r = 1, g = 1, b = 1},
}
-- End include: constants.lua
-- Begin include: board.lua
-- Begin include: constants.lua
--Default object GUID's
FOUR_PLAYER_BUTTON_GUID = "34e910"
SIX_PLAYER_BUTTON_GUID = "3acad9"
EIGHT_PLAYER_BUTTON_GUID = "fa9491"
MAT_ID = "b62603"

--Mat/table shapes
MAT_SHAPES = {[4] = 0, [6] = 1, [8] = 2}
TABLE_SHAPES = {[4] = "Square", [6] = "Hexagon", [8] = "Octagon"}

--Board dimensions
DEFAULT_BOARD_LENGTH = 6.5074
DEFAULT_BOARD_WIDTH = 1.4754
WIDTH_LEG_RATIO = 3.77
BOARD_Y = 1.16
BOARD_SCALES = {[4] = 2.95, [6] = 2.10, [8] = 1.70}

--Marble dimensions/colors
MARBLE_SCALES = {[4] = 1.15, [6] = 0.83, [8] = 0.66}
MARBLE_HEIGHTS = {[4] = 1.75, [6] = 1.85, [8] = 1.70}
MARBLE_COLORS = {
    {r = 0, g = 0, b = 0},
    {r = 0, g = 0, b = 1},
    {r = 0, g = 1, b = 0},
    {r = 1, g = 0, b = 0},
    {r = 0, g = 1, b = 1},
    {r = 1, g = 0, b = 1},
    {r = 1, g = 1, b = 0},
    {r = 1, g = 1, b = 1},
}
-- End include: constants.lua
-- Begin include: saved_object_data/light_board.lua
lightBoardJSON = [[
{
      "GUID": "990ba6",
      "Name": "Custom_Model",
      "Transform": {
        "posX": 0.0,
        "posY": 1.16,
        "posZ": 0.0,
        "rotX": 0.0348675549,
        "rotY": 0.00275248964,
        "rotZ": 4.64923833E-05,
        "scaleX": 2.95,
        "scaleY": 2.95,
        "scaleZ": 2.95
      },
      "Nickname": "",
      "Description": "",
      "GMNotes": "",
      "AltLookAngle": {
        "x": 0.0,
        "y": 0.0,
        "z": 0.0
      },
      "ColorDiffuse": {
        "r": 1.0,
        "g": 1.0,
        "b": 1.0
      },
      "LayoutGroupSortIndex": 0,
      "Value": 0,
      "Locked": false,
      "Grid": true,
      "Snap": true,
      "IgnoreFoW": false,
      "MeasureMovement": false,
      "DragSelectable": true,
      "Autoraise": true,
      "Sticky": true,
      "Tooltip": true,
      "GridProjection": false,
      "HideWhenFaceDown": false,
      "Hands": false,
      "CustomMesh": {
        "MeshURL": "https://steamusercontent-a.akamaihd.net/ugc/16432616709978613/DDFD15AF5E9D474A78E9879B6BD8B8E20ECDF1EC/",
        "DiffuseURL": "https://steamusercontent-a.akamaihd.net/ugc/16432158165210463/F13758A7E268ABACCE9F7B29341B6ADD675F5C4A/",
        "NormalURL": "",
        "ColliderURL": "https://steamusercontent-a.akamaihd.net/ugc/16432158165211267/83126B855FA9E798F432672309C17CDD7940D115/",
        "Convex": false,
        "MaterialIndex": 0,
        "TypeIndex": 0,
        "CastShadows": true
      },
      "LuaScript": "",
      "LuaScriptState": "",
      "XmlUI": ""
    }
]]
-- End include: saved_object_data/light_board.lua
-- Begin include: saved_object_data/dark_board.lua
darkBoardJSON = [[
{
      "GUID": "990ba6",
      "Name": "Custom_Model",
      "Transform": {
        "posX": 0.0,
        "posY": 1.16,
        "posZ": 0.0,
        "rotX": 0.0348675549,
        "rotY": 0.00275248964,
        "rotZ": 4.64923833E-05,
        "scaleX": 2.95,
        "scaleY": 2.95,
        "scaleZ": 2.95
      },
      "Nickname": "",
      "Description": "",
      "GMNotes": "",
      "AltLookAngle": {
        "x": 0.0,
        "y": 0.0,
        "z": 0.0
      },
      "ColorDiffuse": {
        "r": 1.0,
        "g": 1.0,
        "b": 1.0
      },
      "LayoutGroupSortIndex": 0,
      "Value": 0,
      "Locked": false,
      "Grid": true,
      "Snap": true,
      "IgnoreFoW": false,
      "MeasureMovement": false,
      "DragSelectable": true,
      "Autoraise": true,
      "Sticky": true,
      "Tooltip": true,
      "GridProjection": false,
      "HideWhenFaceDown": false,
      "Hands": false,
      "CustomMesh": {
        "MeshURL": "https://steamusercontent-a.akamaihd.net/ugc/16432616709978613/DDFD15AF5E9D474A78E9879B6BD8B8E20ECDF1EC/",
        "DiffuseURL": "https://steamusercontent-a.akamaihd.net/ugc/16432158165214925/BBD4B98054EA5B4FD9325E332B7AB1AC379E2CE7/",
        "NormalURL": "",
        "ColliderURL": "https://steamusercontent-a.akamaihd.net/ugc/16432158165211267/83126B855FA9E798F432672309C17CDD7940D115/",
        "Convex": false,
        "MaterialIndex": 0,
        "TypeIndex": 0,
        "CastShadows": true
      },
      "LuaScript": "",
      "LuaScriptState": "",
      "XmlUI": ""
    }
]]
-- End include: saved_object_data/dark_board.lua

function createBoard(n)

    local l = DEFAULT_BOARD_LENGTH * BOARD_SCALES[n]
    local w = DEFAULT_BOARD_WIDTH * BOARD_SCALES[n]
    local a = w/WIDTH_LEG_RATIO
    local alpha = 2*math.pi/n

    local out = .5*((l/math.tan(math.pi/n)) + a - w)
    local over = a * math.sin(alpha)/2
    local radius = math.sqrt(out*out+over*over)

    local theta0 = math.pi/2-math.asin(over/radius)
    local theta, boardJSON

    for i = 1,n do

        if math.fmod(i,2) == 0 then
            boardJSON = lightBoardJSON
        else
            boardJSON = darkBoardJSON
        end

        theta = theta0 - (i-1)*alpha

        board = spawnObjectJSON({
            json = boardJSON,
            position = {radius * math.cos(theta),BOARD_Y,radius * math.sin(theta)},
            rotation = {0,(i-1)*alpha*180/math.pi,0},
            scale = {BOARD_SCALES[n],BOARD_SCALES[n],BOARD_SCALES[n]} 
        })
        board.lock()
    end
end

function getBoardPoints(n)

    local l = DEFAULT_BOARD_LENGTH * BOARD_SCALES[n]
    local w = DEFAULT_BOARD_WIDTH * BOARD_SCALES[n]
    local a = w/WIDTH_LEG_RATIO
    local out = .5*((l/math.tan(math.pi/n)) + a - w)
    local alpha = 2*math.pi/n
    local d = (l-a)/17
    local xOffset = a * math.sin(alpha)/2-d/2

    local theta, x, z, xPrime, zPrime

    local startPoints = {}
    local snapPoints = {}

    local startPositions = {
        {-d,MARBLE_HEIGHTS[n],out + .5*(w-a)-d},
        {-d,MARBLE_HEIGHTS[n],out + .5*(w-a)-2*d},
        {-d,MARBLE_HEIGHTS[n],out + .5*(w-a)-3*d},
        {-2*d,MARBLE_HEIGHTS[n],out + .5*(w-a)-2*d},
        {0,MARBLE_HEIGHTS[n],out + .5*(w-a)-2*d}
    }

    local goalPositions = {
        {-6*d,MARBLE_HEIGHTS[n],out + .5*(w-a)-d},
        {-6*d,MARBLE_HEIGHTS[n],out + .5*(w-a)-2*d},
        {-5*d,MARBLE_HEIGHTS[n],out + .5*(w-a)-2*d},
        {-4*d,MARBLE_HEIGHTS[n],out + .5*(w-a)-2*d},
        {-4*d,MARBLE_HEIGHTS[n],out + .5*(w-a)-3*d},
    }

    for side = 1,n do

        theta = alpha*(side-1)

        --Outer points
        for i = 1,18 do
            x = xOffset + (-9+i)*d
            z = out + .5*(w-a)
            xPrime = x * math.cos(theta) - z * math.sin(theta)
            zPrime = x * math.sin(theta) + z * math.cos(theta)
            
            snapPoints[#snapPoints + 1] = {position = Vector({x = xPrime, y = MARBLE_HEIGHTS[n], z = zPrime})}
        end

        --Start points
        for i = 1,5 do
            x = xOffset + startPositions[i][1]
            z = startPositions[i][3]
            xPrime = x * math.cos(theta) - z * math.sin(theta)
            zPrime = x * math.sin(theta) + z * math.cos(theta)
            
            startPoints[#startPoints + 1] = {position = Vector({x = xPrime, y = MARBLE_HEIGHTS[n]+1, z = zPrime})}
            snapPoints[#snapPoints + 1] = {position = Vector({x = xPrime, y = MARBLE_HEIGHTS[n], z = zPrime})}
        end
        
        --Goal points
        for i = 1,5 do
            x = xOffset + goalPositions[i][1]
            z = goalPositions[i][3]
            xPrime = x * math.cos(theta) - z * math.sin(theta)
            zPrime = x * math.sin(theta) + z * math.cos(theta)
            
            snapPoints[#snapPoints + 1] = {position = Vector({x = xPrime, y = MARBLE_HEIGHTS[n], z = zPrime})}
        end
    end

    return startPoints, snapPoints
end
-- End include: board.lua

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
-- End include: ../setup.lua

function onLoad()
    buttonSetup(self,"load6Player","6 Player")      
end

function load6Player()
    loadGame(6)
end