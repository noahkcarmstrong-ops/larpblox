local fs=require("@lune/fs")
local luau=require("@lune/luau")
local fixture=fs.readFile("tests/run_appearance_mapping.luau")
local first=assert(fixture:find('local mapping=fs.readFile',1,true))
luau.load(fixture:sub(1,first-1)..[[
environment.UDim=roblox.UDim;environment.UDim2=roblox.UDim2
local test=luau.load(fs.readFile("tests/portrait_ownership.luau"),{environment=environment})()
print(test(fs.readFile("native_avatar_views.lua")))
]])()
