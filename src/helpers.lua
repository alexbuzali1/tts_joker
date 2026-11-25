-- helpers.lua
-- Small general helpers shared by every script.
--#include "constants.lua"

-- Replace the mat with one of the given shape (0 square, 1 hexagon, 2 octagon) and return the new mat.
function changeMatShape(shapeNumber)
    local hex_mat = getObjectFromGUID(MAT_GUID)
    local data = hex_mat.getData()
    data["CustomImage"]["CustomTile"]["Type"] = shapeNumber
    local new_mat = spawnObjectJSON({json = JSON.encode(data)})
    destroyObject(hex_mat)
    return new_mat
end

-- Is (obj_x, obj_z) within `threshold` of (target_x, target_z) on both axes? (a square, not a circle)
function isNear(obj_x, obj_z, target_x, target_z, threshold)
    return math.abs(obj_x - target_x) <= threshold and math.abs(obj_z - target_z) <= threshold
end

-- Straight-line distance between two objects.
function objectDistance(obj1, obj2)
    local p1 = obj1.getPosition()
    local p2 = obj2.getPosition()
    return math.sqrt((p1.x - p2.x)^2 + (p1.y - p2.y)^2 + (p1.z - p2.z)^2)
end

-- Remove the first entry equal to `value` from an array.
function tableRemoveByValue(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            table.remove(tbl, i)
            break
        end
    end
end

-- A copy of a table (one level deep).
function shallowCopyTable(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = v
    end
    return copy
end