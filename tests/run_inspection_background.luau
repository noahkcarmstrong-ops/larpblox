local fs = require("@lune/fs")
local source = fs.readFile("tests/inspection_background.lua")
local chunk = assert(loadstring(source, "tests/inspection_background.lua"))
local base = getfenv()
local env = setmetatable({}, {__index = base})
env.os = {clock = function() return 0 end}
env.task = {defer = function() end, delay = function() end}
env.dofile = function(path)
    local nested = assert(loadstring(fs.readFile(path), path))
    setfenv(nested, env)
    return nested()
end
setfenv(chunk, env)
chunk()
