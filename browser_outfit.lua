-- Import an outfit exported by the Larpblox browser extension.
-- This only changes the local avatar through the existing cosmetic editors.
local HttpService=game:GetService("HttpService")

local accessoryTypes={
    [8]=true,[41]=true,[42]=true,[43]=true,[44]=true,[45]=true,[46]=true,[47]=true,
    [64]=true,[65]=true,[66]=true,[67]=true,[68]=true,[69]=true,[70]=true,[71]=true,[72]=true,[76]=true,[77]=true,
}
local animationTypes={[48]=true,[50]=true,[51]=true,[52]=true,[53]=true,[54]=true,[55]=true,[56]=true}
local function safeId(value)
    assert(type(value)=="number" and value==value and value>0 and value%1==0
        and value<9007199254740992,"Each browser outfit item must have a safe positive numeric ID.")
    return value
end

return function(player,getAvatar,getClothes,onStatus,getAnimations)
    local api={}
    function api.import(raw)
        assert(type(raw)=="string" and #raw>0 and #raw<=262144,"Paste the browser outfit JSON export first.")
        local outfit=HttpService:JSONDecode(raw)
        assert(type(outfit)=="table" and outfit.version==1
            and outfit.kind=="larpblox-cosmetic-outfit","That is not a supported Larpblox browser outfit export.")
        assert(tostring(outfit.userId)==tostring(player.UserId),"This browser outfit belongs to a different Roblox account.")
        assert(type(outfit.items)=="table" and #outfit.items<=512,"A browser outfit can contain at most 512 component assets.")

        for index,item in ipairs(outfit.items) do
            assert(type(item)=="table" and item.itemType=="Asset","Browser outfit item #"..index.." is invalid.")
            safeId(item.id)
            assert(type(item.assetType)=="number" and item.assetType==item.assetType and item.assetType%1==0
                and item.assetType>0 and item.assetType<1000,"Browser outfit item #"..index.." has an invalid asset type.")
            if item.name~=nil then assert(type(item.name)=="string" and #item.name<=128,"Browser outfit item #"..index.." has an invalid name.") end
        end

        local applied,unsupported,failed={}, {}, {};local movement={}
        for index,item in ipairs(outfit.items) do
            local id=safeId(item.id)
            local assetType=item.assetType
            local name=type(item.name)=="string" and item.name or tostring(id)
            local ok,message
            if assetType==19 then
                ok,message=pcall(function() return getAvatar().equipGear(id) end)
            elseif accessoryTypes[assetType] then
                ok,message=pcall(function() return getAvatar().equipAccessory(id,nil,assetType) end)
            elseif assetType==11 then
                ok,message=pcall(function() return getClothes().equipShirt(id) end)
            elseif assetType==12 then
                ok,message=pcall(function() return getClothes().equipPants(id) end)
            elseif assetType==2 then
                ok,message=pcall(function() return getClothes().equipTShirt(id) end)
            elseif animationTypes[assetType] and getAnimations then
                movement[#movement+1]={id=id,assetType=assetType}
            else
                unsupported[#unsupported+1]=name.." (asset type "..tostring(assetType)..")"
            end
            if ok then
                applied[#applied+1]=name
            elseif ok==false then
                failed[#failed+1]=name..": "..tostring(message):gsub("^.-:%d+:%s*","")
            end
        end
        if #movement>0 then
            local ok,message=pcall(function()return getAnimations().equipAssets(movement)end)
            if ok then applied[#applied+1]="Movement animations" else failed[#failed+1]=tostring(message)end
        end
        local parts={"Imported "..#applied.." item"..(#applied==1 and "" or "s").." locally."}
        if #unsupported>0 then parts[#parts+1]="Unsupported: "..table.concat(unsupported,", ").."." end
        if #failed>0 then parts[#parts+1]="Could not load: "..table.concat(failed,", ").."." end
        parts[#parts+1]="Nothing was purchased or granted."
        local message=table.concat(parts," ")
        if onStatus then onStatus(message) end
        return message
    end
    return api
end
