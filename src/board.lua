--#include "constants.lua"
--#include "saved_object_data/light_board.lua"
--#include "saved_object_data/dark_board.lua"

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