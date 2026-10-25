-- Movement bundles for Roblox's standard R15 Animate script.
local Http=game:GetService("HttpService")
local assetStates={[48]="climb",[50]="fall",[51]="idle",[52]="jump",[53]="run",[54]="swim",[55]="walk",[56]="pose",[78]="mood"}
local states={idle=true,walk=true,run=true,jump=true,fall=true,climb=true,swim=true,swimidle=true,pose=true,mood=true}
local function bundleId(value)
    local digits=tostring(value or ""):match("^%s*(%d+)%s*$")
    local path=tostring(value or ""):match("^%s*https?://www%.roblox%.com/bundles/(%d+)")
        or tostring(value or ""):match("^%s*https?://roblox%.com/bundles/(%d+)")
    local id=tonumber(digits or path)
    assert(id and id>0 and id%1==0 and id<9007199254740992,"Paste a Roblox animation bundle link or bundle ID.")
    return id
end
return function(player,onStatus,managedRespawn,readAsset)
    local gui=player:FindFirstChildOfClass("PlayerGui")
    local attribute="HoneyBunCosmeticAnimationBundle"
    local savedId=gui and gui:GetAttribute(attribute)
    local savedAssets,savedComponents,savedLabels,savedName
    savedLabels={}
    if type(savedId)=="string" then
        local ok,value=pcall(function() return Http:JSONDecode(savedId) end)
        if ok and type(value)=="table" then savedAssets=value.assets;savedId=value.bundleId;savedLabels=type(value.labels)=="table" and value.labels or {};savedName=value.name end
    end
    if type(savedId)~="number" or savedId<=0 or savedId%1~=0 or savedId>=9007199254740992 then savedId=nil end
    local function validAssetType(value) return assetStates[tonumber(value)] end
    local function normalizeAssets(items)
        assert(type(items)=="table","Animation components must be an array.")
        local result={}
        for index,item in ipairs(items) do
            assert(type(item)=="table","Animation component #"..index.." is invalid.")
            local id=tonumber(item.id);local assetType=tonumber(item.assetType)
            assert(id and id>0 and id%1==0 and id<9007199254740992 and validAssetType(assetType),
                "Animation components need a valid catalog asset ID and supported assetType (48, 50-56, 78).")
            result[#result+1]={id=id,assetType=assetType,name=type(item.name)=="string" and item.name:sub(1,128) or nil}
        end
        return result
    end
    if type(savedAssets)=="table" then
        local ok,normalized=pcall(normalizeAssets,savedAssets)
        savedAssets=ok and normalized or nil
    end
    local alive,generation=true,0
    local snapshot,cache=nil,{}
    local avatarSnapshot,avatarAssets
    if gui then
        local ok,value=pcall(function()return Http:JSONDecode(gui:GetAttribute("HoneyBunCosmeticUI_avatarAnimations") or "null")end)
        if ok and type(value)=="table" then local valid,items=pcall(normalizeAssets,value);if valid then avatarAssets=items end end
    end
    local function context()
        assert(alive,"The cosmetic menu was closed.")
        local character=player.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        local animate=character and character:FindFirstChild("Animate")
        assert(humanoid and humanoid.Health>0,"Wait for your avatar to finish spawning.")
        assert(humanoid.RigType==Enum.HumanoidRigType.R15,"Roblox movement animation bundles need an R15 avatar.")
        assert(animate and animate:IsA("LocalScript") and not animate.Disabled and animate:FindFirstChild("idle")
            and animate:FindFirstChild("walk") and animate:FindFirstChild("run"),"This character does not have Roblox's standard movement animation controls ready.")
        return {character=character,humanoid=humanoid,animate=animate,generation=generation}
    end
    local function check(ctx)
        assert(alive and generation==ctx.generation and player.Character==ctx.character and ctx.humanoid.Health>0,
            "Your avatar changed while loading. Try again on the new character.")
    end
    local function restart(ctx)
        -- Reusing the existing Animator preserves normal multiplayer replication.
        local animator=ctx.humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
                if track.Priority==Enum.AnimationPriority.Core or track.Priority==Enum.AnimationPriority.Idle or track.Priority==Enum.AnimationPriority.Movement then
                    track:Stop(0.1)
                end
            end
        end
        ctx.animate.Disabled=false
    end
    local function restoreCurrent()
        if not snapshot then return end
        local previous=snapshot;snapshot=nil
        if previous.character==player.Character and previous.animate.Parent then
            previous.animate.Disabled=true
            for _,folder in pairs(previous.added) do folder:Destroy() end
            for _,folder in pairs(previous.originals) do folder.Parent=previous.animate end
            restart(previous)
        else
            for _,folder in pairs(previous.originals) do folder:Destroy() end
        end
    end
    local componentCache,componentOrder={},{}
    local function extractAsset(id,default,ctx)
        local key=tostring(id)..":"..default
        if componentCache[key]then return componentCache[key]end
        local loaded,roots=pcall(function()
            if readAsset then return readAsset(id)end
            return game:GetObjects("rbxassetid://"..string.format("%.0f",id))
        end)
        local extracted={}
        if loaded and type(roots)=="table" then
            for _,root in ipairs(roots) do
                local items=root:GetDescendants();table.insert(items,1,root)
                for _,node in ipairs(items) do
                    if node:IsA("Animation") and node.AnimationId~="" then
                        local parentName=node.Parent and string.lower(node.Parent.Name) or ""
                        local state=states[parentName] and parentName or default
                        if string.lower(node.Name):find("swimidle",1,true) then state="swimidle" end
                        local weight=node:FindFirstChild("Weight")
                        extracted[state]=extracted[state] or {}
                        table.insert(extracted[state],{name=node.Name,id=node.AnimationId,weight=weight and weight:IsA("NumberValue") and weight.Value or 1})
                    end
                end
            end
            for _,root in ipairs(roots) do root:Destroy() end
        end
        check(ctx);assert(next(extracted),"Roblox could not load the "..default.." animation component. Your current animations were kept.")
        local assets={}
        for _,entries in pairs(extracted)do for _,entry in ipairs(entries)do assets[#assets+1]=entry.id end end
        game:GetService("ContentProvider"):PreloadAsync(assets)
        check(ctx)
        componentCache[key]=extracted;componentOrder[#componentOrder+1]=key
        if #componentOrder>64 then componentCache[table.remove(componentOrder,1)]=nil end
        return extracted
    end
    local function groupsForAssets(items,ctx)
        local groups={}
        for _,item in ipairs(items) do
            local default=assetStates[item.assetType]
            for state,entries in pairs(extractAsset(item.id,default,ctx)) do groups[state]=entries end
        end
        assert(next(groups),"These animation components contain no playable animations.")
        return groups
    end
    local function loadBundle(id,ctx)
        if cache[id] then return cache[id] end
        local ok,bundle=pcall(function()
            return Http:JSONDecode(game:HttpGet("https://catalog.roblox.com/v1/bundles/"..string.format("%.0f",id).."/details",false))
        end)
        check(ctx)
        assert(ok and type(bundle)=="table" and type(bundle.items)=="table","Roblox could not read that animation bundle.")
        assert(bundle.bundleType=="AvatarAnimations","That is not an animation bundle. Copy a movement animation bundle link from Roblox.")
        local groups,assets={},{ }
        for _,item in ipairs(bundle.items) do
            local default=assetStates[tonumber(item.assetType)]
            if item.type=="Asset" and default then
                assets[#assets+1]={id=tonumber(item.id),assetType=tonumber(item.assetType)}
                for state,entries in pairs(extractAsset(item.id,default,ctx)) do groups[state]=entries end
            end
        end
        assert(next(groups),"This bundle has no supported movement animations.")
        local result={name=bundle.name or "Animation bundle",groups=groups,assets=assets}
        cache[id]=result;return result
    end
    local function applyGroups(groups)
        local ctx=context()
        local prepared={}
        for state,entries in pairs(groups) do
            local folder=Instance.new(state=="mood" and "StringValue" or "Folder");folder.Name=state
            for _,entry in ipairs(entries) do
                local animation=Instance.new("Animation");animation.Name=entry.name;animation.AnimationId=entry.id;animation.Parent=folder
                local weight=Instance.new("NumberValue");weight.Name="Weight";weight.Value=entry.weight;weight.Parent=animation
            end
            prepared[state]=folder
        end
        restoreCurrent()
        snapshot={character=ctx.character,humanoid=ctx.humanoid,animate=ctx.animate,originals={},added=prepared}
        ctx.animate.Disabled=true
        local ok,message=pcall(function()
            for state,folder in pairs(prepared) do
                local old=ctx.animate:FindFirstChild(state)
                if old then snapshot.originals[state]=old;old.Parent=nil end
                folder.Parent=ctx.animate
            end
            restart(ctx)
        end)
        if not ok then pcall(restoreCurrent);error("Could not equip this movement bundle: "..tostring(message)) end
        return true
    end
    local function apply(id)
        local ctx=context();local bundle=loadBundle(id,ctx);check(ctx)
        applyGroups(bundle.groups)
        return bundle.name
    end
    local function applyAssets(items)
        local ctx=context();local groups=groupsForAssets(items,ctx);check(ctx)
        applyGroups(groups)
        return #items
    end
    local api={}
    local searches={}
    local catalogTypes={idle="IdleAnimation",walk="WalkAnimation",run="RunAnimation",jump="JumpAnimation",fall="FallAnimation",climb="ClimbAnimation",swim="SwimAnimation"}
    function api.searchChoices(kind,query,page,sort)
        query=tostring(query or ""):match("^%s*(.-)%s*$"):sub(1,100)
        page=tonumber(page) or 1
        assert(page>=1 and page%1==0,"Choose a valid catalog page.")
        sort=sort or "Relevance"
        local sorts={Relevance=true,MostFavorited=true,Bestselling=true,RecentlyCreated=true,PriceLowToHigh=true,PriceHighToLow=true}
        assert(sorts[sort],"Choose a valid catalog sort order.")
        local key=kind..":"..query:lower()..":"..sort
        local saved=searches[key]
        if saved and page==1 and not saved.loading and os.clock()-saved.time>300 then saved.completed:Destroy();saved=nil end
        if not saved then saved={results={},time=os.clock(),loading=false,finished=false,completed=Instance.new("BindableEvent")};searches[key]=saved end
        if saved.loading then saved.completed.Event:Wait()end
        if saved.results[page]then return saved.results[page],page<#saved.results or not saved.finished end
        assert(page==#saved.results+1,"Return to the previous catalog page first.")
        if saved.finished then return {},false end
        saved.loading=true
        local ok,result=pcall(function()
            if not saved.cursor then
                local params=CatalogSearchParams.new()
                params.SearchKeyword=query;params.Limit=30;params.IncludeOffSale=true
                params.SortType=Enum.CatalogSortType[sort]
                if kind=="bundle" then params.BundleTypes={Enum.BundleType.Animations}
                else assert(catalogTypes[kind],"Choose an animation type.");params.AssetTypes={Enum.AvatarAssetType[catalogTypes[kind]]}end
                saved.cursor=game:GetService("AvatarEditorService"):SearchCatalogAsync(params)
            else saved.cursor:AdvanceToNextPageAsync()end
            local items,seen={},{}
            for _,item in ipairs(saved.cursor:GetCurrentPage())do
                local id=tonumber(item.Id)
                if id and not seen[id]then
                    seen[id]=true;items[#items+1]={id=id,name=tostring(item.Name or "Roblox item"),itemType=kind=="bundle" and "Bundle" or "Asset"}
                end
            end
            saved.finished=saved.cursor.IsFinished
            saved.results[page]=items
            return items
        end)
        saved.loading=false;saved.completed:Fire()
        if not ok then error(result,0)end
        return result,not saved.finished
    end
    function api.setAvatarAssets(items)
        local normalized=normalizeAssets(items)
        local same=avatarAssets and #avatarAssets==#normalized
        if same then
            local ids={};for _,item in ipairs(avatarAssets)do ids[item.assetType]=item.id end
            for _,item in ipairs(normalized)do if ids[item.assetType]~=item.id then same=false;break end end
        end
        if same and not savedId and not savedAssets then return false end
        local groups=#normalized>0 and groupsForAssets(normalized,context()) or nil
        restoreCurrent()
        snapshot=avatarSnapshot;avatarSnapshot=nil;restoreCurrent()
        if groups then applyGroups(groups);avatarSnapshot=snapshot;snapshot=nil end
        avatarAssets=normalized;savedId=nil;savedAssets=nil;savedComponents=nil;savedLabels={};savedName=nil
        if gui then gui:SetAttribute(attribute,nil);gui:SetAttribute("HoneyBunCosmeticUI_avatarAnimations",Http:JSONEncode(normalized)) end
        return true
    end
    function api.equipBundle(value)
        local id=bundleId(value)
        local name=apply(id)
        savedId=id;savedAssets=nil;savedComponents=cache[id] and cache[id].assets;savedName=name
        savedLabels={}
        for _,item in ipairs(savedComponents or {}) do savedLabels[assetStates[item.assetType]]=name end
        if gui then gui:SetAttribute(attribute,Http:JSONEncode({bundleId=id,labels=savedLabels,name=name})) end
        return "Equipped "..name..". Walk or run to try it."
    end
    function api.equipAssets(items)
        local normalized=normalizeAssets(items)
        local count=applyAssets(normalized)
        savedId=nil;savedAssets=normalized;savedComponents=normalized
        savedLabels={};savedName=nil
        for _,item in ipairs(normalized) do
            if item.name then savedLabels[assetStates[item.assetType]]=item.name:gsub("[ -]+[Aa]nimation$",""):gsub("[ -]+[Ii]dle$",""):gsub("[ -]+[Ww]alk$",""):gsub("[ -]+[Rr]un$",""):gsub("[ -]+[Jj]ump$",""):gsub("[ -]+[Ff]all$",""):gsub("[ -]+[Cc]limb$",""):gsub("[ -]+[Ss]wim$","") end
        end
        if gui then gui:SetAttribute(attribute,Http:JSONEncode({assets=normalized,labels=savedLabels})) end
        return "Equipped "..count.." animation component"..(count==1 and "" or "s")..". Walk or run to try it."
    end
    function api.restore()
        restoreCurrent();savedId=nil;savedAssets=nil;savedComponents=nil;savedLabels={};savedName=nil;if gui then gui:SetAttribute(attribute,nil) end
        return "Original movement animations restored."
    end
    function api.prepareSaved()
        if not savedId and not savedAssets and (not avatarAssets or #avatarAssets==0)then return end
        local ctx=context()
        if avatarAssets and #avatarAssets>0 then groupsForAssets(avatarAssets,ctx)end
        if savedAssets then groupsForAssets(savedAssets,ctx)end
        if savedId then loadBundle(savedId,ctx)end
        check(ctx)
    end
    function api.reapplySaved()
        if avatarAssets and not avatarSnapshot then
            local base=avatarAssets
            local overrideId,overrideAssets,overrideComponents,overrideLabels,overrideName=savedId,savedAssets,savedComponents,savedLabels,savedName
            avatarAssets=nil;api.setAvatarAssets(base)
            savedId,savedAssets,savedComponents,savedLabels,savedName=overrideId,overrideAssets,overrideComponents,overrideLabels,overrideName
            if gui then
                if savedId then gui:SetAttribute(attribute,Http:JSONEncode({bundleId=savedId,labels=savedLabels,name=savedName}))
                elseif savedAssets then gui:SetAttribute(attribute,Http:JSONEncode({assets=savedAssets,labels=savedLabels})) end
            end
        end
        if savedAssets then return "Restored "..applyAssets(savedAssets).." animation components." end
        if savedId then
            local name=apply(savedId)
            savedComponents=cache[savedId] and cache[savedId].assets
            savedName=name
            for _,item in ipairs(savedComponents or {}) do savedLabels[assetStates[item.assetType]]=name end
            return "Restored "..name.."."
        end
        return "No movement animation bundle selected."
    end
    function api.getSettings()
        local merged,labels={},{}
        for _,item in ipairs(avatarAssets or {})do
            merged[item.assetType]=item
            if item.name then labels[assetStates[item.assetType]]=item.name:gsub("[ -]+[Aa]nimation$",""):gsub("[ -]+[Ii]dle$",""):gsub("[ -]+[Ww]alk$",""):gsub("[ -]+[Rr]un$",""):gsub("[ -]+[Jj]ump$",""):gsub("[ -]+[Ff]all$",""):gsub("[ -]+[Cc]limb$",""):gsub("[ -]+[Ss]wim$","") end
        end
        for _,item in ipairs(savedAssets or savedComponents or {})do merged[item.assetType]=item end
        for key,value in pairs(savedLabels)do labels[key]=value end
        local assets={};for _,item in pairs(merged)do assets[#assets+1]={id=item.id,assetType=item.assetType}end
        local common
        for _,item in ipairs(assets)do
            local label=labels[assetStates[item.assetType]]
            if not label then common=false;break end
            if common==nil then common=label elseif common~=label then common=false;break end
        end
        return {bundleId=savedId,assets=assets,labels=labels,name=savedName or common or nil}
    end
    local function typeAssets()
        if savedAssets or savedComponents then return savedAssets or savedComponents end
        if savedId then local ctx=context();savedComponents=loadBundle(savedId,ctx).assets;return savedComponents end
        return {}
    end
    local function replaceType(state,item,label)
        assert(states[state],"Choose a supported animation type.")
        local nextAssets={}
        for _,previous in ipairs(typeAssets()) do if assetStates[previous.assetType]~=state then nextAssets[#nextAssets+1]=previous end end
        if item then nextAssets[#nextAssets+1]=item end
        if #nextAssets>0 then applyAssets(nextAssets) else restoreCurrent() end
        savedAssets=#nextAssets>0 and nextAssets or nil;savedComponents=savedAssets;savedId=nil;savedName=nil;savedLabels[state]=label
        if gui then gui:SetAttribute(attribute,savedAssets and Http:JSONEncode({assets=savedAssets,labels=savedLabels}) or nil) end
        return "Animation updated."
    end
    function api.equipTypeFromBundle(state,value,label)
        local ctx=context();local bundle=loadBundle(bundleId(value),ctx);check(ctx)
        for _,item in ipairs(bundle.assets) do
            if assetStates[item.assetType]==state then return replaceType(state,item,label or bundle.name) end
        end
        error("This bundle has no "..tostring(state).." animation.")
    end
    function api.equipType(state,value)
        local id=tonumber(tostring(value):match("^%s*(%d+)%s*$") or tostring(value):match("/catalog/(%d+)"))
        assert(id and id>0 and id%1==0 and id<9007199254740992,"Paste an animation catalog link or ID.")
        local ctx=context()
        local info=game:GetService("MarketplaceService"):GetProductInfo(id)
        check(ctx)
        local assetType=tonumber(info.AssetTypeId)
        assert(assetStates[assetType]==state,"Choose a "..state.." animation catalog item.")
        local label=tostring(info.Name or "Custom"):gsub("[ -]+[Ii]dle$",""):gsub("[ -]+[Ww]alk$",""):gsub("[ -]+[Rr]un$",""):gsub("[ -]+[Jj]ump$",""):gsub("[ -]+[Ff]all$",""):gsub("[ -]+[Cc]limb$",""):gsub("[ -]+[Ss]wim$","")
        return replaceType(state,{id=id,assetType=assetType},label)
    end
    function api.restoreType(state) return replaceType(state,nil,nil) end
    function api.getPreviewIds(state)
        local character=player.Character;local animate=character and character:FindFirstChild("Animate")
        local folder=animate and animate:FindFirstChild(state)
        local ids={}
        if folder then for _,item in ipairs(folder:GetDescendants()) do if item:IsA("Animation") and item.AnimationId~="" then ids[#ids+1]=item.AnimationId end end end
        return ids
    end
    local readyConnections={}
    local function cancelReady()
        for _,connection in ipairs(readyConnections)do connection:Disconnect()end
        readyConnections={}
    end
    local function whenReady(character,ready,callback)
        cancelReady()
        local pending,finished=false,false
        local function changed()
            if pending or finished then return end
            pending=true
            task.defer(function()
                pending=false
                if finished or not alive or player.Character~=character then return end
                if not ready()then return end
                finished=true;cancelReady();callback()
            end)
        end
        local function watch(object)
            if object:IsA("Humanoid")then
                readyConnections[#readyConnections+1]=object.HealthChanged:Connect(changed)
            elseif object:IsA("LocalScript") and object.Name=="Animate"then
                readyConnections[#readyConnections+1]=object:GetPropertyChangedSignal("Disabled"):Connect(changed)
            end
        end
        readyConnections[#readyConnections+1]=character.DescendantAdded:Connect(function(object)watch(object);changed()end)
        readyConnections[#readyConnections+1]=player.CharacterAppearanceLoaded:Connect(changed)
        for _,object in ipairs(character:GetDescendants())do watch(object)end
        changed()
    end
    local changed=player.CharacterAdded:Connect(function(character)
        generation=generation+1;local ticket=generation
        restoreCurrent()
        snapshot=avatarSnapshot;avatarSnapshot=nil;restoreCurrent()
        if managedRespawn or (not savedId and not savedAssets and not avatarAssets) then return end
        whenReady(character,function()
            return pcall(context) and player:HasAppearanceLoaded()
        end,function()
            local ok,message=pcall(api.reapplySaved)
            if not ok and onStatus then onStatus("Could not restore saved animation bundle: "..tostring(message))end
        end)
    end)
    function api.destroy()
        cancelReady()
        if not alive then return end
        alive=false;generation=generation+1;changed:Disconnect();pcall(restoreCurrent)
        snapshot=avatarSnapshot;avatarSnapshot=nil;pcall(restoreCurrent)
    end
    return api
end
