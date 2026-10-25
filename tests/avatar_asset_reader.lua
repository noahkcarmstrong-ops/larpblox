-- Exercises the loader's real avatar asset reader with local and native fallbacks.
local file=assert(io.open("loader.lua","r"))
local loader=file:read("*a");file:close()
local source=assert(loader:match("(    local function readAsset%(path%).-)\n    local function createAvatar"))
source=source:gsub("^    local function readAsset%(path%)","return function(path)",1)
local reader=assert((loadstring or load)(source))()

local nativeCalls,deleted={},{}
local objects={}
game={GetObjects=function(_,uri)
    if uri:match("^rbxassetid://") then
        nativeCalls[#nativeCalls+1]=uri
        assert(objects.native,"native decoder failed")
        return objects.native
    end
    assert(objects.localDecoder,"local decoder failed")
    return objects.localDecoder
end,GetService=function(_,name)
    assert(name=="HttpService")
    return {GenerateGUID=function()return "test-session"end}
end}
request=function()return {StatusCode=200,Body="<roblox>asset</roblox>"}end
writefile=function()end
delfile=function(name)deleted[#deleted+1]=name end
customAsset=function()return "local-file"end
readSource=function()return "<roblox!asset</roblox>"end
assetSerial=0;assetSession="test-session";sha="test"

objects={localDecoder=nil,native={"native"}}
local nativeResult=reader(1744060292)
assert(nativeResult==objects.native,"catalog assets fall back when local decoding fails")
assert(#nativeCalls==1 and #deleted==1,"failed local decoding still cleans up the temp file")

objects={localDecoder={"local"},native={"native"}}
nativeCalls={};deleted={}
local localResult=reader(1744060292)
assert(localResult==objects.localDecoder and #nativeCalls==0,"catalog assets use successful local decoding")
assert(#deleted==1,"successful local decoding cleans up the temp file")

objects={localDecoder=nil,native=nil};nativeCalls={};deleted={}
assert(not pcall(reader,1744060292),"native decoder errors remain visible when fallback also fails")
assert(#nativeCalls==1,"native fallback is attempted after local decoding fails")

objects={localDecoder={"azurelight"},native=nil};nativeCalls={};deleted={}
local azurelight=reader("assets/dominus-azurelight.rbxm")
assert(azurelight==objects.localDecoder and #nativeCalls==0,"Azurelight remains local-only")

objects={localDecoder=nil,native={"native"}};nativeCalls={};deleted={}
assert(not pcall(reader,"assets/dominus-azurelight.rbxm"),"Azurelight local failures do not use catalog fallback")
assert(#nativeCalls==0,"Azurelight never calls native catalog loading")

print("avatar_asset_reader.lua passed")
