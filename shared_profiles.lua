-- Saved public Larp profiles are independent of a player's game connection.
-- Older extensions omitted item metadata; resolve it once, with bounded work.
local Http=game:GetService("HttpService")
local metadata={}
local function id(value)
    local n=tonumber(value)
    return n and n>0 and n%1==0 and n<9007199254740992 and n
end
return function(userIds)
    assert(type(userIds)=="table" and #userIds>0 and #userIds<=50,"Invalid profile request")
    local wanted,query={},{}
    for _,value in ipairs(userIds)do
        local n=assert(id(value),"Invalid profile user")
        wanted[tostring(n)]=true;query[#query+1]=string.format("%.0f",n)
    end
    local data=Http:JSONDecode(game:HttpGet("https://larp.3xjn.dev/v1/profiles?userIds="..table.concat(query,","),false))
    assert(type(data)=="table" and type(data.players)=="table","Invalid profile response")
    local records,missing,queued={},{},{}
    for _,record in ipairs(data.players)do
        local snapshot=type(record)=="table" and record.snapshot
        if type(record)=="table" and wanted[record.userId] and type(snapshot)=="table" and type(snapshot.definition)=="table"
            and type(snapshot.definition.assets)=="table" and #snapshot.definition.assets<=512 and type(snapshot.items)=="table" then
            local known={}
            for _,item in ipairs(snapshot.items)do if type(item)=="table" and id(item.id) then known[item.id]=item end end
            local valid=true
            for _,asset in ipairs(snapshot.definition.assets)do
                local assetId=type(asset)=="table" and id(asset.id)
                if not assetId then valid=false;break end
                if not known[assetId] and not metadata[assetId] and not queued[assetId]then
                    queued[assetId]=true;missing[#missing+1]=assetId
                end
            end
            if valid then records[#records+1]={record=record,known=known}end
        end
    end
    for start=1,#missing,50 do
        local batch={};for i=start,math.min(start+49,#missing)do batch[#batch+1]=missing[i]end
        local ok,details=pcall(function()
            return game:GetService("AvatarEditorService"):GetBatchItemDetailsAsync(batch,Enum.AvatarItemType.Asset)
        end)
        if ok and type(details)=="table"then
            for _,info in ipairs(details)do
                local parsed,assetType=pcall(function()return Enum.AvatarAssetType[info.AssetType].Value end)
                if parsed and id(info.Id) and id(assetType) and type(info.Name)=="string"then
                    metadata[info.Id]={id=info.Id,itemType="Asset",assetType=assetType,name=info.Name:sub(1,128)}
                end
            end
        end
    end
    local result={}
    for _,entry in ipairs(records)do
        local items,complete={},true
        for _,asset in ipairs(entry.record.snapshot.definition.assets)do
            local item=entry.known[asset.id] or metadata[asset.id]
            if not item then complete=false;break end
            items[#items+1]=item
        end
        if complete then entry.record.snapshot.items=items;result[#result+1]=entry.record end
    end
    return result
end
