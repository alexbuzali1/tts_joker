-- build.lua
-- Automatically builds Lua scripts from src/, supports recursive --#include, relative paths, 3D folder structure, and outputs to build/

local lfs = require("lfs")

-- === CONFIGURATION ===
local SOURCE_DIR = "src"
local BUILD_DIR = "build"

-- === FILE HELPERS ===
local function readFile(path)
    print("🔍 Reading file:", path)
    local file = io.open(path, "r")
    if not file then error("❌ Cannot open file: " .. path) end
    local content = file:read("*a")
    file:close()
    return content
end

local function writeFile(path, content)
    local filename = path:match("([^/\\]+%.lua)$")
    local outputPath = BUILD_DIR .. "/" .. filename
    local file = io.open(outputPath, "w")
    if not file then error("❌ Cannot write to: " .. outputPath) end
    file:write(content)
    file:close()
    print("✅ Output -> " .. outputPath)
end

-- === INCLUDE PROCESSOR ===
local function processIncludes(code, visited, currentDir)
    visited = visited or {}
    currentDir = currentDir or SOURCE_DIR

    return code:gsub('%-%-#include%s+"(.-)"', function(includePath)
        local fullPath = currentDir .. "/" .. includePath

        -- Normalize path
        fullPath = fullPath:gsub("/%./", "/")
        while fullPath:find("[^/]+/%.%./") do
            fullPath = fullPath:gsub("[^/]+/%.%./", "")
        end

        if visited[fullPath] then
            return "-- already included: " .. includePath
        end

        visited[fullPath] = true

        print("📥 Including: " .. fullPath)
        local includedCode = readFile(fullPath)
        local includeDir = fullPath:match("(.*/)")
        return "-- Begin include: " .. includePath .. "\n"
            .. processIncludes(includedCode, visited, includeDir)
            .. "\n-- End include: " .. includePath
    end)
end

-- === RECURSIVE FILE FINDER ===
local function findLuaFiles(folder, out)
    out = out or {}
    for file in lfs.dir(folder) do
        if file ~= "." and file ~= ".." then
            local fullPath = folder .. "/" .. file
            local attr = lfs.attributes(fullPath)
            if attr.mode == "file" and file:match("%.lua$") then
                table.insert(out, fullPath)
            elseif attr.mode == "directory" then
                findLuaFiles(fullPath, out)
            end
        end
    end
    return out
end

-- === BUILD START ===
os.execute("mkdir -p " .. BUILD_DIR)

local luaFiles = findLuaFiles(SOURCE_DIR)

for _, filePath in ipairs(luaFiles) do
    print("\n🔨 Building: " .. filePath)
    local content = readFile(filePath)
    local currentDir = filePath:match("(.*/)")
    local processed = processIncludes(content, {}, currentDir)
    writeFile(filePath, processed)
end
