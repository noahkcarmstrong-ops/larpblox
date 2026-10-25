local fs=require("@lune/fs")
local luau=require("@lune/luau")
local fixture=fs.readFile("tests/run_appearance_mapping.luau")
local first=assert(fixture:find('local mapping=fs.readFile',1,true))
local setup=fixture:sub(1,first-1)
local run=setup..[[
local names=fs.readFile("local_names.lua")
local test=luau.load(fs.readFile("tests/name_identity.luau"),{environment=environment})()
print(test(names))
]]
luau.load(run)()
