-- build.lua
-- Builds the scripts Tabletop Simulator runs from the sources in src/.
--
--   lua build.lua            (run from the repository root; plain Lua 5.1+, no extra libraries)
--
-- Every TTS object with a script has an ENTRY file in src/, named the way TTS names it: "<object name>.<GUID>.lua"
-- (the Global script is "Global.-1.lua"; the button objects' scripts are in src/Buttons/). An entry pulls other
-- source files in with
--
--   --#include "path/to/file.lua"
--
-- The path is relative to the file that has the include line (falling back to src/). Each file is included once
-- per entry script; later includes of the same file become a comment. Every included file is wrapped in its own
-- do ... end block, so its top-level `local`s stay private to that file (Lua allows at most 200 locals in one
-- chunk, and all the modules together would go over that).
--
-- Output: build/<entry name>.lua for every entry (plus Global.-1.xml), ready to send to TTS with
-- tools/push_to_tts.sh. build/ is generated: never edit it, edit src/ and rebuild.

local SOURCE_DIR = "src"
local BUILD_DIR = "build"

------------------------------------------------------------------------
-- files
------------------------------------------------------------------------
local function readFile(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

local function writeFile(path, content)
    local file = assert(io.open(path, "w"), "cannot write " .. path)
    file:write(content)
    file:close()
end

-- "src/game/../helpers.lua" -> "src/helpers.lua"
local function normalize(path)
    path = path:gsub("/%./", "/")
    local n
    repeat path, n = path:gsub("[^/]+/%.%./", "", 1) until n == 0
    return path
end

local function dirOf(path) return path:match("^(.*)/[^/]*$") or "." end

------------------------------------------------------------------------
-- includes
------------------------------------------------------------------------
local function resolve(includePath, currentDir)
    for _, p in ipairs({ normalize(currentDir .. "/" .. includePath), normalize(SOURCE_DIR .. "/" .. includePath) }) do
        if readFile(p) then return p end
    end
    error("include not found: \"" .. includePath .. "\" (from " .. currentDir .. ")")
end

local function processIncludes(code, visited, currentDir)
    return (code:gsub('%-%-#include%s+"(.-)"', function(includePath)
        local fullPath = resolve(includePath, currentDir)
        if visited[fullPath] then return "-- already included: " .. includePath end
        visited[fullPath] = true
        local body = processIncludes(readFile(fullPath), visited, dirOf(fullPath))
        return "-- Begin include: " .. includePath .. "\ndo\n" .. body .. "\nend\n-- End include: " .. includePath
    end))
end

------------------------------------------------------------------------
-- entry scripts: "<name>.<GUID>.lua" in src/ and src/Buttons/
------------------------------------------------------------------------
local function listEntries()
    local out = {}
    for _, dir in ipairs({ SOURCE_DIR, SOURCE_DIR .. "/Buttons" }) do
        local p = io.popen('ls "' .. dir .. '"')
        for name in p:lines() do
            if name:match("^.+%.[%w%-]+%.lua$") then out[#out + 1] = dir .. "/" .. name end
        end
        p:close()
    end
    return out
end

os.execute('mkdir -p "' .. BUILD_DIR .. '"')
os.execute('rm -f "' .. BUILD_DIR .. '"/*.lua "' .. BUILD_DIR .. '"/*.xml')

local total = 0
for _, path in ipairs(listEntries()) do
    local name = path:match("([^/]+)$")
    local code = processIncludes(readFile(path), { [path] = true }, dirOf(path))
    writeFile(BUILD_DIR .. "/" .. name, code)
    total = total + 1
    print(string.format("built %-40s %7.1f KB", name, #code / 1024))
end
local xml = readFile(SOURCE_DIR .. "/Global.-1.xml")
if xml then writeFile(BUILD_DIR .. "/Global.-1.xml", xml) end
print(total .. " scripts in " .. BUILD_DIR .. "/")
