local selection={version=1,kind="larpblox-cosmetic-outfit",userId=7,items={}}
local types={8,19,41,42,43,44,45,46,47,64,65,66,67,68,69,70,71,72,76,77,2,11,12,48,50,51,52,53,54,55,56}
for _,assetType in ipairs(types)do selection.items[#selection.items+1]={id=1000+assetType,name="Item",itemType="Asset",assetType=assetType}end
game={GetService=function()return {JSONDecode=function()return selection end}end}
local applied={}
local avatar={equipAccessory=function(id)applied[id]=true end,equipGear=function(id)applied[id]=true end}
local clothes={equipTShirt=function(id)applied[id]=true end,equipShirt=function(id)applied[id]=true end,equipPants=function(id)applied[id]=true end}
local movement={equipAssets=function(items)for _,item in ipairs(items)do applied[item.id]=true end end}
local importer=dofile("browser_outfit.lua")({UserId=7},function()return avatar end,function()return clothes end,nil,function()return movement end)
local message=importer.import("fixture")
assert(not message:find("Unsupported:") and not message:find("Could not load:"),"supported imports have no failures")
for _,assetType in ipairs(types)do assert(applied[1000+assetType],"import category dispatched: "..assetType)end
selection.items={}
for _,assetType in ipairs({8,41,42,43,44,45,46,47,64,65,66,67,68,69,70,71,72,76,77})do
    for n=1,20 do selection.items[#selection.items+1]={id=assetType*100+n,name="Accessory",itemType="Asset",assetType=assetType}end
end
assert(not importer.import("fixture"):find("Could not load:"),"380 accessory snapshots import without a total100 cap")
selection.userId=8;assert(not pcall(importer.import,"fixture"),"another account's import is rejected")
print("Browser outfit import accessory, clothing, animation dispatch and account isolation passed.")
