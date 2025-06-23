function showColorGridForPlayer(color)
    
    local grid_size = COLOR_PICKER_GRID_SIZE

    local panel_size = 300
    local cell_size = math.floor(panel_size / grid_size)

    local xml = string.format([[
        <Text id = "colorText_%s" text="Pick a marble color" fontSize="28" color="#FFFFFF" position="500 -125"/>
        <Panel id="colorPanel_%s" player_color="%s" width="%d" height="%d" position="500 -300">
            <VerticalLayout spacing="0">
    ]], color, color, color, panel_size, panel_size)

    for row = 0, grid_size - 1 do
        xml = xml .. '<HorizontalLayout spacing="0" childAlignment="MiddleCenter">'
        for col = 0, grid_size - 1 do
            local r = row / (grid_size - 1)
            local g = col / (grid_size - 1)
            local b = 1 - (row + col) / (2 * (grid_size - 1))

            local hex = string.format("#%02X%02X%02X", r * 255, g * 255, b * 255)
            local id = string.format("colorBtn_%s_%d_%d", color, row, col)

            xml = xml .. string.format([[
                <Button id="%s" onClick="colorChosen" color="%s" preferredWidth="%d" preferredHeight="%d" />
            ]], id, hex, cell_size, cell_size)
        end
        xml = xml .. '</HorizontalLayout>'
    end

    xml = xml .. '</VerticalLayout></Panel>'
    UI.setXml(UI.getXml() .. xml)
end

function colorChosen(player, value, id)

    local _, _, row, col = string.find(id, "colorBtn_%a+_(%d+)_(%d+)")
    row = tonumber(row)
    col = tonumber(col)

    local grid_size = COLOR_PICKER_GRID_SIZE

    local r = row / (grid_size - 1)
    local g = col / (grid_size - 1)
    local b = 1 - (row + col) / (2 * (grid_size - 1))

    local team_marbles = Global.getTable("marbles_by_player")[player.color]
    for _, marble in ipairs(team_marbles) do
        marble.setColorTint({r = r, g = g, b = b})
    end
end