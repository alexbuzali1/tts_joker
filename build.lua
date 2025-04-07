local lfs = require("lfs")

-- === CONFIG ===
local SOURCE_DIR = "src"
local BUILD_DIR = "build"

-- === File Helpers ===
local function readFile(path)
    local file = io.open(path, "r")
    if not file then error("Cannot open file: " .. path) end
    local content = file:read("*a")
    file:close()
    return content
end

local function writeFile(path, content)
    -- Flatten to build/<filename>.lua (no folder structure)
    local fileName = path:match("([^/\\]+)%.lua$")
    local file = io.open(BUILD_DIR .. "/" .. fileName .. ".lua", "w")
    if not file then error("Cannot write to file: " .. path) end
    file:write(content)
    file:close()
end

-- === Recursive Include Processor ===
local function processIncludes(code, visited)
    visited = visited or {}

    return code:gsub('%-%-#include%s+"(.-)"', function(includePath)
        if visited[includePath] then
            return "-- (already included: " .. includePath .. ")"
        end

        visited[includePath] = true
        print("Including: " .. includePath)

        local fullPath = SOURCE_DIR .. "/" .. includePath
        local includedCode = readFile(fullPath)
        includedCode = processIncludes(includedCode, visited)

        return "-- Begin include: " .. includePath .. "\n"
            .. includedCode ..
            "\n-- End include: " .. includePath
    end)
end

-- === Recursive File Finder ===
local function findLuaFiles(folder, files)
    for file in lfs.dir(folder) do
        if file ~= "." and file ~= ".." then
            local fullPath = folder .. "/" .. file
            local attr = lfs.attributes(fullPath)
            if attr.mode == "file" and file:match("%.lua$") then
                table.insert(files, fullPath)
            elseif attr.mode == "directory" then
                findLuaFiles(fullPath, files)
            end
        end
    end
end

-- === Build ===
os.execute("mkdir -p " .. BUILD_DIR)

local luaFiles = {}
findLuaFiles(SOURCE_DIR, luaFiles)

for _, filePath in ipairs(luaFiles) do
    print("🔨 Building: " .. filePath)
    local code = readFile(filePath)
    local processed = processIncludes(code)
    writeFile(filePath, processed)
    print("✅ Output -> " .. BUILD_DIR)
end