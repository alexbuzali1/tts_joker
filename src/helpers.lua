--#include "constants.lua"

function changeMatShape(shapeNumber)
    local hex_mat = getObjectFromGUID("b62603")
    local data = hex_mat.getData()
    data["CustomImage"]["CustomTile"]["Type"] = shapeNumber
    local new_mat = spawnObjectJSON({json = JSON.encode(data)})
    destroyObject(hex_mat)
    return new_mat
end

function isNear(obj_x, obj_z, target_x, target_z, threshold)
    return math.abs(obj_x - target_x) <= threshold and math.abs(obj_z - target_z) <= threshold
end

function objectDistance(obj1, obj2)
    local p1 = obj1.getPosition()
    local p2 = obj2.getPosition()
    return math.sqrt((p1.x - p2.x)^2 + (p1.y - p2.y)^2 + (p1.z - p2.z)^2)
end

function tableRemoveByValue(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            table.remove(tbl, i)
            break
        end
    end
end

function shallowCopyTable(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = v
    end
    return copy
end