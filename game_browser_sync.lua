-- Local-only appearance data and typed avatar lookups. No executable code crosses the relay.
local HttpService=game:GetService("HttpService")
local MarketplaceService=game:GetService("MarketplaceService")
local PORT=38261
local accessoryTypes={[8]=true,[41]=true,[42]=true,[43]=true,[44]=true,[45]=true,[46]=true,[47]=true,[64]=true,[65]=true,[66]=true,[67]=true,[68]=true,[69]=true,[70]=true,[71]=true,[72]=true,[76]=true,[77]=true}
local animationTypes={[48]="ClimbAnimation",[50]="FallAnimation",[51]="IdleAnimation",[52]="JumpAnimation",[53]="RunAnimation",[54]="SwimAnimation",[55]="WalkAnimation",[56]="PoseAnimation",[78]="MoodAnimation"}
local SCALE_PROPERTIES={height="BodyHeightScale",width="BodyWidthScale",depth="BodyDepthScale",head="HeadScale",bodyType="BodyTypeScale",proportion="BodyProportionScale"}
local function safeId(v)return type(v)=="number" and v==v and v>0 and v%1==0 and v<9007199254740992 end
local function imageBytes(url)
    assert(type(url)=="string" and (url:match("^https://tr%.rbxcdn%.com/") or url:match("^https://t%d%.rbxcdn%.com/")),"Invalid avatar image URL.")
    local fn=request or http_request or (syn and syn.request)
    assert(type(fn)=="function","This executor does not provide HTTP requests.")
    local response=fn({Url=url,Method="GET",Timeout=15})
    assert(response and tonumber(response.StatusCode or response.Status)==200,"Could not download avatar image.")
    return response.Body
end
local function hex(c)
    local function n(v)return math.clamp(math.floor(v*255+0.5),0,255) end
    return string.format("%02x%02x%02x",n(c.R),n(c.G),n(c.B))
end
local function call(method,path,token,body)
    local url="http://127.0.0.1:"..PORT..path
    local headers={Authorization="Bearer "..token,["Content-Type"]="application/json"}
    local fn= request or http_request or (syn and syn.request)
    assert(type(fn)=="function","This executor does not provide a localhost HTTP request function.")
    local result=fn({Url=url,Method=method,Headers=headers,Body=body and HttpService:JSONEncode(body),Timeout=5})
    local code=result and (result.StatusCode or result.Status)
    if tonumber(code)==404 then return nil end
    assert(tonumber(code)==200,"Browser relay returned HTTP "..tostring(code or "unknown"))
    return result.Body and HttpService:JSONDecode(result.Body) or {}
end
return function(player,getAvatar,getClothes,isAlive,onStatus,getAnimations,getNames,getViews,sharing)
    local api,token,connected,lastJson,lastRevision={},nil,false,nil,0
    api.downloadImage=imageBytes
    local generation=0
    local lastNameState=nil
    local lastBrowserCommand
    local lastSharingPreference=nil
    local sharingConnected=false
    local scheduleSnapshot
    local larpEnabled,larpName,larpDisplayName,larpVerified,lastSnapshot=false,"","",false,nil
    local browserModeKnown=false
    local socket,socketReady,socketMine=nil,false,0
    local incoming,pumping={},false
    local retryCommand
    local retryTimerCommand,retryRevision,retryAttempt=nil,nil,0
    local imageValue,imageAsset,imageUrl,imageSerial=nil,nil,nil,0
    local appearanceConnections={}
    local characterConnections={}
    local instanceConnections={}
    local pump
    local scheduleReconnect
    local snapshotPending=false
    local snapshotScheduleId=0
    local loadingImageUrl
    local lastDefinition,imageAssetDefinition,lastBrowserSnapshot
    local commandSnapshotPending=false
    local snapshotListeners,sharingListeners={},{}
    local desiredSharing,socketSupportsSharing=nil,false
    local lastModeValue
    local function readyForAppearance()
        return not sharing or not sharing.isReady or sharing.isReady()
    end
    local function notifySnapshot()
        for callback in pairs(snapshotListeners)do pcall(callback,lastSnapshot)end
    end
    local function notifySharing(value)
        if type(value)=="table" then
            if value.type=="snapshot" then sharingConnected=true
            elseif value.type=="status" then sharingConnected=false end
            if scheduleSnapshot then scheduleSnapshot()end
        end
        for callback in pairs(sharingListeners)do pcall(callback,value)end
    end
    local file="larpblox-browser-pair-"..tostring(player.UserId)..".txt"
    local cache,assetTypes,bodyCache={},{},{}
    local function status(message)if onStatus and isAlive() then onStatus(message)end end
    local function connectionState(ready)
        if sharing and sharing.onConnectionState and isAlive()then sharing.onConnectionState(ready)end
    end
    local viewOptions,viewPending,cachedViews
    local function queueViews(options)
        viewOptions=options
        if not getViews or viewPending or (not options.enabled and not cachedViews)then return end
        viewPending=true
        task.defer(function()
            local ok,reason=pcall(function()
                if not isAlive()then return end
                cachedViews=cachedViews or getViews()
                if isAlive()then cachedViews.update(viewOptions)end
            end)
            viewPending=false
            if not ok and isAlive()then status("Avatar preview: "..tostring(reason))end
        end)
    end
    local function validToken(v)return type(v)=="string" and #v==32 and v:match("^%x+$") end
    local function readSaved()
        if type(readfile)=="function" and type(isfile)=="function" then
            local ok,v=pcall(function()if isfile(file)then return readfile(file)end end)
            if ok and validToken(v)then return v end
        end
    end
    local function save(v)
        if type(writefile)=="function" then pcall(writefile,file,v)end
    end
    local function product(id,fallback)
        if cache[id]then return cache[id]end
        -- Browser commands carry validated names and asset types.  Keep that
        -- metadata authoritative for this sync so a slow marketplace lookup
        -- cannot delay applying the outfit.
        if fallback and assetTypes[id] then cache[id]=fallback;return fallback end
        local name=fallback or tostring(id);local ok,info=pcall(function()return MarketplaceService:GetProductInfo(id,Enum.InfoType.Asset)end)
        if ok and type(info)=="table" then if type(info.Name)=="string" then name=info.Name end;assetTypes[id]=tonumber(info.AssetTypeId) end
        cache[id]=name;return name
    end
    local function bodyDescription(value)
        if bodyCache[value] then return bodyCache[value] end
        local presets={Girl=131929545,["Robloxian 2.0"]=131929576}
        local outfit=presets[value]
        if not outfit then
            local id=tonumber(value) or tonumber(tostring(value):match("/bundles/(%d+)"))
            assert(safeId(id),"Invalid body bundle.")
            local bundle=HttpService:JSONDecode(game:HttpGet("https://catalog.roblox.com/v1/bundles/"..string.format("%.0f",id).."/details",false))
            for _,item in ipairs(bundle.items or {})do if item.type=="UserOutfit" then outfit=tonumber(item.id);break end end
        end
        assert(safeId(outfit),"Body bundle has no outfit.")
        local source=game:GetService("Players"):GetHumanoidDescriptionFromOutfitIdAsync(outfit)
        local result={}
        for _,key in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg","BodyTypeScale","ProportionScale"})do result[key]=source[key] end
        source:Destroy();bodyCache[value]=result;return result
    end
    local bodyRegions={{"Head",17},{"Torso",27},{"RightArm",28},{"LeftArm",29},{"LeftLeg",30},{"RightLeg",31}}
    local bodyTypeRegions={[17]="Head",[79]="Head",[27]="Torso",[28]="RightArm",[29]="LeftArm",[30]="LeftLeg",[31]="RightLeg"}
    local browserBody,originalBody={},{ }
    local browserFace=false
    local function definitionKey(definition)
        if type(definition)~="table" then return "" end
        local ids,styles,values={}, {},{}
        for _,asset in ipairs(definition.assets or {})do
            ids[#ids+1]=asset.id
            styles[asset.id]=asset.meta and asset.meta.smokestackStyle or ""
        end
        table.sort(ids);for _,id in ipairs(ids)do values[#values+1]=tostring(id);values[#values+1]=tostring(styles[id] or "")end
        for _,key in ipairs({"headColor","torsoColor","leftArmColor","rightArmColor","leftLegColor","rightLegColor"})do
            values[#values+1]=tostring((definition.bodyColors or {})[key] or ""):gsub("^#",""):lower()
        end
        for _,key in ipairs({"height","width","depth","head","bodyType","proportion"})do values[#values+1]=tostring((definition.scales or {})[key] or "")end
        return table.concat(values,"|")
    end
    local function currentImage()
        local expected=lastBrowserSnapshot and lastBrowserSnapshot.definition
        return imageAsset and imageAssetDefinition and (not expected or definitionKey(imageAssetDefinition)==definitionKey(expected)) and imageAsset or nil
    end
    local function updateViews()
        queueViews({enabled=larpEnabled,name=larpName,displayName=larpDisplayName,verified=larpVerified,snapshot=lastBrowserSnapshot or lastSnapshot,image=currentImage()})
    end
    local function applyImage(value)
        if type(value)~="table" or value.version~=1 or tostring(value.userId)~=tostring(player.UserId) then return end
        local url=value.imageUrl
        if type(url)~="string" or #url>2048 or not (url:match("^https://tr%.rbxcdn%.com/[%w%-%._~/]+$") or url:match("^https://t%d%.rbxcdn%.com/[%w%-%._~/]+$")) then return end
        if type(value.definition)~="table" then return end
        imageValue=value
        notifySnapshot()
        if imageUrl==url and imageAsset then imageAssetDefinition=value.definition;updateViews();return end
        local custom=getcustomasset or getsynasset
        if type(custom)~="function" or type(writefile)~="function" then return end
        if loadingImageUrl==url then return end
        loadingImageUrl=url
        local mine=generation
        local ok,result=pcall(function()
            local bytes=imageBytes(url)
            assert(type(bytes)=="string" and #bytes<=4*1024*1024 and bytes:sub(1,8)=="\137PNG\r\n\26\n","The avatar image is not a valid PNG.")
            if mine~=generation or not imageValue or imageValue.imageUrl~=url then return end
            imageSerial=imageSerial+1
            local path="larpblox-avatar-"..player.UserId.."-"..imageSerial..".png"
            writefile(path,bytes)
            return custom(path)
        end)
        if loadingImageUrl==url then loadingImageUrl=nil end
        if ok and type(result)=="string" and mine==generation and imageValue and imageValue.imageUrl==url then imageAsset=result;imageUrl=url;imageAssetDefinition=imageValue.definition;updateViews()
        elseif not ok then status("Browser avatar image: "..tostring(result))end
    end
    local function snapshot()
        local character=player.Character;local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        assert(character and humanoid,"Wait for your avatar to finish spawning.")
        local desc=humanoid:GetAppliedDescription();local settings=getAvatar():getSettings();local clothes=getClothes():getSettings()
        local colors=character:FindFirstChildOfClass("BodyColors")
        local function color(region,name)
            -- This snapshot edits the saved browser outfit. Native game colors
            -- (uniforms, morphs, death effects) must not replace a selected Larp
            -- color just because they changed the live character's presentation.
            local selected=settings.colors and (settings.colors[region] or settings.colors.All)
            if selected then return hex(Color3.new(selected[1],selected[2],selected[3]))end
            local c=colors and colors[region.."Color3"]
            if not c then local part=character:FindFirstChild(name) or character:FindFirstChild(region=="Torso" and "Torso" or region:gsub("Arm","UpperArm"):gsub("Leg","UpperLeg"));c=part and part.Color end
            return c and hex(c) or "ffffff"
        end
        local definition={assets={},bodyColors={headColor=color("Head","Head"),torsoColor=color("Torso","UpperTorso"),leftArmColor=color("LeftArm","Left Arm"),rightArmColor=color("RightArm","Right Arm"),leftLegColor=color("LeftLeg","Left Leg"),rightLegColor=color("RightLeg","Right Leg")},scales={},playerAvatarType={playerAvatarType=humanoid.RigType==Enum.HumanoidRigType.R6 and "R6" or "R15"}}
        for _,pair in ipairs({{"HeightScale","height"},{"WidthScale","width"},{"DepthScale","depth"},{"HeadScale","head"},{"BodyTypeScale","bodyType"},{"ProportionScale","proportion"}})do local live=humanoid:FindFirstChild(({height="BodyHeightScale",width="BodyWidthScale",depth="BodyDepthScale",head="HeadScale",bodyType="BodyTypeScale",proportion="BodyProportionScale"})[pair[2]]);local v=live and live:IsA("NumberValue") and live.Value or desc[pair[1]];if type(v)=="number" and v==v and v<math.huge then definition.scales[pair[2]]=v end end
        local items,seen={},{}
        local function add(id,name,assetType,include,meta)
            if include and safeId(id) and not seen[id] and #items<512 then
                local label=product(id,name);assetType=assetTypes[id] or assetType
                seen[id]=true;items[#items+1]={id=id,name=string.sub(label,1,128),itemType="Asset",assetType=assetType};definition.assets[#definition.assets+1]={id=id,meta=meta}
            end
        end
        local added={};for _,entry in ipairs(getAvatar():listAccessories())do added[entry.id]=true;local typeId=assetTypes[entry.id] or 8;add(entry.id,entry.name,typeId,true,entry.meta)end
        if getAvatar().listGear then for _,entry in ipairs(getAvatar():listGear())do add(entry.id,entry.name,19,true) end end
        local ok,entries=pcall(function()return desc:GetAccessories(true)end)
        if ok and type(entries)=="table" then for _,entry in ipairs(entries)do local id=entry.AssetId;local typeId=assetTypes[id] or 8;add(id,entry.Name,typeId,not settings.hideOriginals or added[id],entry.IsLayered and {order=entry.Order or 0,puffiness=entry.Puffiness or 0} or nil)end end
        local bodyTypes={Head=17,Torso=27,LeftArm=29,RightArm=28,LeftLeg=30,RightLeg=31}
        local source=desc
        if settings.body and settings.body~="Blocky" then source=bodyDescription(settings.body) end
        if source~=desc then definition.scales.bodyType=source.BodyTypeScale;definition.scales.proportion=source.ProportionScale end
        -- Direct local scale changes do not update GetAppliedDescription().
        for key,name in pairs(SCALE_PROPERTIES)do
            local value=humanoid:FindFirstChild(name)
            if value and value:IsA("NumberValue") and value.Value==value.Value and value.Value>=0 and value.Value<=5 then
                definition.scales[key]=value.Value
            end
        end
        for key,value in pairs(settings.scales or {})do definition.scales[key]=value end
        for region,typeId in pairs(bodyTypes)do
            local id=source[region]
            if settings.body=="Blocky" and (region~="Head" or humanoid.RigType~=Enum.HumanoidRigType.R6) then id=0 end
            local override=settings.bodyParts and settings.bodyParts[region]
            if override then
                local text=tostring(override)
                if text:find("/bundles/",1,true) then id=bodyDescription(override)[region]
                else id=tonumber(override) or tonumber(text:match("/catalog/(%d+)")) end
            end
            add(id,region,typeId,true)
        end
        add(settings.face or desc.Face,"Face",18,true)
        add(clothes.ShirtGraphic or desc.GraphicTShirt,"Graphic T-Shirt",2,true)
        add(clothes.Shirt or desc.Shirt,"Shirt",11,(clothes.Shirt or desc.Shirt)~=nil);add(clothes.Pants or desc.Pants,"Pants",12,(clothes.Pants or desc.Pants)~=nil)
        local animationSettings=getAnimations and getAnimations().getSettings() or {}
        local overridden={}
        for _,item in ipairs(animationSettings.assets or {})do overridden[item.assetType]=true;add(item.id,"Movement animation",item.assetType,true)end
        for assetType,property in pairs(animationTypes)do
            if not overridden[assetType] and property~="PoseAnimation" then
                local readable,id=pcall(function()return desc[property]end)
                if readable then add(id,property,assetType,true)end
            end
        end
        local emotes={}
        if sharing and sharing.getMotion then
            local equipped=sharing.getMotion().getSlots()
            for index=1,8 do local item=equipped[index];if item then emotes[#emotes+1]={slot=index,id=item.id,name=item.name} end end
        end
        local backgroundId,backgrounds
        if sharing and sharing.getBackgroundState then backgroundId,backgrounds=sharing.getBackgroundState() end
        if backgroundId and backgroundId>0 then definition.backgroundId=backgroundId;definition.backgroundRequestModel={id=backgroundId} end
        return {version=1,userId=tostring(player.UserId),definition=definition,items=items,emotes=emotes,backgroundId=backgroundId,backgrounds=backgrounds,
            sharing={enabled=desiredSharing~=nil and desiredSharing.enabled==true,connected=sharingConnected},verified=larpVerified}
    end
    local function validSnapshot(value)
        assert(type(value)=="table" and value.version==1 and tostring(value.userId)==tostring(player.UserId),"Browser snapshot is for a different account.")
        assert(type(value.definition)=="table" and type(value.definition.assets)=="table" and #value.definition.assets<=512,"Browser snapshot assets are invalid.")
        assert(type(value.items)=="table" and #value.items<=512,"Browser snapshot items are invalid.")
        for _,asset in ipairs(value.definition.assets)do assert(type(asset)=="table" and safeId(asset.id),"Browser asset is invalid.")end
        local colors=value.definition.bodyColors;local colorKeys={"headColor","torsoColor","leftArmColor","rightArmColor","leftLegColor","rightLegColor"}
        assert(type(colors)=="table", "Browser body colors are invalid.")
        for _,key in ipairs(colorKeys)do
            assert(type(colors[key])=="string" and colors[key]:match("^#?%x%x%x%x%x%x$"),"Browser body colors are invalid.")
            colors[key]=colors[key]:gsub("^#",""):lower()
        end
        local scales=value.definition.scales;assert(type(scales)=="table","Browser scales are invalid.")
        for _,v in pairs(scales)do assert(type(v)=="number" and v==v and v<math.huge and v>=0 and v<=5,"Browser scales are invalid.")end
        local rig=value.definition.playerAvatarType;assert(type(rig)=="table" and (rig.playerAvatarType=="R6" or rig.playerAvatarType=="R15"),"Browser avatar type is invalid.")
        for _,item in ipairs(value.items)do assert(type(item)=="table" and safeId(item.id) and type(item.name)=="string" and #item.name<=128 and item.itemType=="Asset" and safeId(item.assetType),"Browser item is invalid.")end
        local background=value.backgroundId or value.definition.backgroundId or (value.definition.backgroundRequestModel and value.definition.backgroundRequestModel.id)
        if background~=nil then assert(background==0 or safeId(background),"Invalid background ID.") end
        if value.backgrounds~=nil then
            assert(type(value.backgrounds)=="table" and #value.backgrounds<=100,"Invalid background collection.")
            local seen={}
            for _,item in ipairs(value.backgrounds)do
                assert(type(item)=="table" and safeId(item.id) and not seen[item.id] and type(item.name)=="string" and #item.name<=128,"Invalid collected background.")
                seen[item.id]=true
            end
            if background and background>0 then assert(seen[background],"Collect this background in the extension first.") end
        end
        if value.emotes~=nil then
            assert(type(value.emotes)=="table" and #value.emotes<=8,"Invalid browser emotes.")
            local seen={}
            for _,item in ipairs(value.emotes) do
                assert(type(item)=="table" and type(item.slot)=="number" and item.slot%1==0 and item.slot>=1 and item.slot<=8 and not seen[item.slot] and safeId(item.id) and type(item.name)=="string" and #item.name<=128,"Invalid browser emote.")
                seen[item.slot]=true
            end
        end
        return value
    end
    local function applyCommand(value)
        validSnapshot(value);assert(value.verified==nil or type(value.verified)=="boolean","Browser verification is invalid.");local revision=tonumber(value.revision);assert(revision and revision%1==0 and revision>0 and revision<9007199254740992,"Browser revision is invalid.")
        if not lastBrowserCommand or revision>=lastBrowserCommand.revision then lastBrowserCommand=value end
        if not readyForAppearance() then return end
        if revision<=lastRevision then return end
        if browserModeKnown and not larpEnabled then lastRevision=revision;return end
        local avatar,clothes=getAvatar(),getClothes();local failed={};local loadErrors={};local desired={};local current={}
        for _,item in ipairs(value.items)do
            assetTypes[item.id]=item.assetType
            cache[item.id]=item.name
            if accessoryTypes[item.assetType] then desired[item.id]=true end
        end
        local ok,msg=pcall(function()
            local before=snapshot()
            for _,item in ipairs(before.items)do if accessoryTypes[item.assetType] then current[item.id]=true end end
            local preparationFailures={}
            if avatar.prepareAppearance and sharing and sharing.describeSnapshot then
                local function currentPreparation()
                    return isAlive() and readyForAppearance() and lastBrowserCommand==value
                        and (not browserModeKnown or larpEnabled)
                end
                local prepared,reason=pcall(avatar.prepareAppearance,value,sharing.describeSnapshot,currentPreparation)
                if not currentPreparation()then return end
                if not prepared and sharing.log then sharing.log("local_native_source_failed",{detail=tostring(reason)})end
            end
            if avatar.prepareAccessories then
                local ids={}
                for _,item in ipairs(value.items)do
                    if accessoryTypes[item.assetType] and not current[item.id]then ids[#ids+1]=item.id end
                end
                preparationFailures=avatar.prepareAccessories(ids)
                if not readyForAppearance()then return end
            end
            local currentBody,desiredBody={},{ }
            for _,item in ipairs(before.items)do local region=bodyTypeRegions[item.assetType];if region then currentBody[region]=item.id end end
            for _,item in ipairs(value.items)do local region=bodyTypeRegions[item.assetType];if region then desiredBody[region]=item.id end end
            if avatar.prepareBodyParts then
                local changed=false
                for _,entry in ipairs(bodyRegions)do
                    local region=entry[1]
                    if browserBody[region]==nil or (currentBody[region] or 0)~=(desiredBody[region] or 0)then changed=true end
                end
                for key,scale in pairs(value.definition.scales)do
                    if (before.definition.scales or {})[key]~=scale then changed=true end
                end
                if changed then avatar.prepareBodyParts(desiredBody,value.definition.scales)end
            end
            if next(value.definition.scales)~=nil and avatar.setScales then
                local loaded,reason=pcall(avatar.setScales,value.definition.scales)
                if not loaded then loadErrors[#loadErrors+1]="Proportions: "..tostring(reason)end
            end
            local bodySettings=avatar.getSettings()
            local resetBody=false
            if bodySettings.body and avatar.restoreBody then
                local loaded,reason=pcall(avatar.restoreBody)
                if loaded then currentBody={};browserBody={};originalBody={};resetBody=true
                else loadErrors[#loadErrors+1]="Body: "..tostring(reason)end
            end
            if avatar.applyBodyParts then
                local changed=resetBody
                local complete={}
                for _,entry in ipairs(bodyRegions)do
                    local region=entry[1]
                    complete[region]=desiredBody[region] or 0
                    if browserBody[region]==nil or (currentBody[region] or 0)~=complete[region] then changed=true end
                end
                for key,scale in pairs(value.definition.scales)do
                    if (before.definition.scales or {})[key]~=scale then changed=true end
                end
                if changed then
                    -- The native generated root and HipHeight must accompany
                    -- the complete body; individual regions cannot supply them.
                    local loaded,reason=pcall(avatar.applyBodyParts,complete,value.definition.scales)
                    if loaded then
                        for region,id in pairs(complete)do
                            if originalBody[region]==nil then originalBody[region]=currentBody[region] end
                            browserBody[region]=id
                        end
                    else loadErrors[#loadErrors+1]="Body: "..tostring(reason)end
                end
            else
            for _,entry in ipairs(bodyRegions)do
                local region=entry[1];local wanted=desiredBody[region];local owned=browserBody[region] or (bodySettings.bodyParts or {})[region]
                if wanted and currentBody[region]~=wanted then
                    if not originalBody[region] then originalBody[region]=currentBody[region] end
                    local loaded,reason=pcall(avatar.applyBodyPart,region,wanted)
                    if loaded then browserBody[region]=wanted else loadErrors[#loadErrors+1]=region..": "..tostring(reason)end
                elseif not wanted and browserBody[region]~=0 and (resetBody or owned or currentBody[region]~=nil) then
                    local loaded,reason=pcall(avatar.applyBodyPart,region,0)
                    if loaded then browserBody[region]=0;originalBody[region]=nil else loadErrors[#loadErrors+1]=region..": "..tostring(reason)end
                end
            end
            end
            for _,entry in ipairs({{"Head","headColor"},{"Torso","torsoColor"},{"LeftArm","leftArmColor"},{"RightArm","rightArmColor"},{"LeftLeg","leftLegColor"},{"RightLeg","rightLegColor"}})do
                local wanted=value.definition.bodyColors[entry[2]]:gsub("^#",""):lower()
                if before.definition.bodyColors[entry[2]]~=wanted or next(desiredBody)~=nil or bodySettings.body then
                    local loaded,reason=pcall(avatar.setSkin,Color3.fromRGB(tonumber(wanted:sub(1,2),16),tonumber(wanted:sub(3,4),16),tonumber(wanted:sub(5,6),16)),entry[1])
                    if not loaded then loadErrors[#loadErrors+1]=entry[1].." color: "..tostring(reason)end
                end
            end
            local currentFace,desiredFace
            for _,item in ipairs(before.items)do if item.assetType==18 then currentFace=item.id end end
            for _,item in ipairs(value.items)do if item.assetType==18 then desiredFace=item.id end end
            if desiredFace and avatar.applyFace and currentFace~=desiredFace then
                local loaded,reason=pcall(avatar.applyFace,desiredFace)
                if loaded then browserFace=true else loadErrors[#loadErrors+1]="Face: "..tostring(reason)end
            elseif not desiredFace and browserFace and avatar.restoreFace then
                local loaded,reason=pcall(avatar.restoreFace)
                if not loaded then loadErrors[#loadErrors+1]="Face: "..tostring(reason)end
                browserFace=false
            end
            local accessoryMetadata={}
            for _,asset in ipairs(value.definition.assets)do accessoryMetadata[asset.id]=asset.meta end
            local managed={};for _,entry in ipairs(avatar.listAccessories())do managed[entry.id]=true end
            local function needsManaged(id)
                local meta=accessoryMetadata[id]
                return not managed[id] and meta and (meta.scale or meta.position or meta.rotation or meta.smokestackStyle)
            end
            local changed=false;for id in pairs(desired)do if not current[id] or needsManaged(id)then changed=true end end;for id in pairs(current)do if not desired[id]then changed=true end end
            if changed then
                -- Keep unchanged instances: some already-worn hats cannot be loaded again.
                local entries=avatar.listAccessories();local localIds={};local present={}
                for _,entry in ipairs(entries)do localIds[entry.id]=true end
                local hideOriginals=false
                for id in pairs(current)do
                    if not localIds[id] then
                        if desired[id] and not needsManaged(id) then present[id]=true else hideOriginals=true end
                    end
                end
                if hideOriginals then avatar.removeCurrentAccessories();present={} end
                for _,entry in ipairs(entries)do
                    if desired[entry.id] then present[entry.id]=true else avatar.removeAccessory(entry.key) end
                end
                for _,item in ipairs(value.items)do
                    if accessoryTypes[item.assetType] and not present[item.id] then
                        local loaded,reason
                        if preparationFailures[item.id]then loaded,reason=false,preparationFailures[item.id]
                        else loaded,reason=pcall(avatar.equipAccessory,item.id,accessoryMetadata[item.id],item.assetType)end
                        if loaded then present[item.id]=true else loadErrors[#loadErrors+1]=item.name..": "..tostring(reason) end
                    end
                end
            end
            if avatar.setAccessoryMetadata then
                for _,entry in ipairs(avatar.listAccessories())do
                    if desired[entry.id]then
                        local loaded,reason=pcall(avatar.setAccessoryMetadata,entry.key,accessoryMetadata[entry.id])
                        if not loaded then loadErrors[#loadErrors+1]="Accessory adjustments: "..tostring(reason)end
                    end
                end
            end
            -- Gear remains in the saved browser outfit, but is not rendered
            -- until equip/unequip state can be synchronized.
            local clothingTypes={[2]={"ShirtGraphic","equipTShirt","removeTShirt"},[11]={"Shirt","equipShirt","removeShirt"},[12]={"Pants","equipPants","removePants"}}
            local wantedClothes={};local wantedAnimations={}
            for _,item in ipairs(value.items)do
                local slot=clothingTypes[item.assetType]
                if slot then
                    wantedClothes[item.assetType]=true
                    -- Saved settings can outlive the native Shirt/Pants instances.
                    -- Reapply the selected item so Roblox's actual template matches.
                    clothes[slot[2]](item.id)
                elseif animationTypes[item.assetType] then wantedAnimations[#wantedAnimations+1]={id=item.id,assetType=item.assetType,name=item.name}
                elseif item.assetType~=19 and not accessoryTypes[item.assetType] and item.assetType~=17 and item.assetType~=18 and item.assetType~=27 and item.assetType~=28 and item.assetType~=29 and item.assetType~=30 and item.assetType~=31 and item.assetType~=79 then failed[#failed+1]=item.name end
            end
            for assetType,slot in pairs(clothingTypes)do
                -- Saved settings may say a slot is already removed while Roblox
                -- has recreated its native Shirt/Pants instance after a reset.
                if not wantedClothes[assetType] and clothes[slot[3]] then clothes[slot[3]]()end
            end
            if getAnimations then
                local animationApi=getAnimations();local settings=animationApi.getSettings()
                local currentAnimations={};for _,item in ipairs(before.items)do if animationTypes[item.assetType] then currentAnimations[item.assetType]=item.id end end
                local changedAnimations=false;local desiredAnimations={}
                for _,item in ipairs(wantedAnimations)do desiredAnimations[item.assetType]=item.id;if currentAnimations[item.assetType]~=item.id then changedAnimations=true end end
                for assetType in pairs(currentAnimations)do if not desiredAnimations[assetType] then changedAnimations=true end end
                if changedAnimations then
                    local loaded,reason=pcall(function()animationApi.setAvatarAssets(wantedAnimations) end)
                    if not loaded then loadErrors[#loadErrors+1]="Movement animations: "..tostring(reason)end
                end
            elseif #wantedAnimations>0 then loadErrors[#loadErrors+1]="Reload the connected script to enable movement animations." end
            if value.emotes~=nil and sharing and sharing.getMotion then
                local loaded,reason=pcall(function()sharing.getMotion().replaceSlots(value.emotes)end)
                if not loaded then loadErrors[#loadErrors+1]="Emotes: "..tostring(reason) end
            end
            if #loadErrors>0 then error(table.concat(loadErrors,"; "))end
        end)
        if ok then
            if sharing and sharing.setBackgroundState then
                local id=value.backgroundId or value.definition.backgroundId or (value.definition.backgroundRequestModel and value.definition.backgroundRequestModel.id)
                sharing.setBackgroundState(id,value.backgrounds)
            end
            if value.verified~=nil then larpVerified=value.verified==true end;lastRevision=revision;lastDefinition=value.definition;lastBrowserSnapshot=value;commandSnapshotPending=true
            if sharing and sharing.onChanged then sharing.onChanged() end
        end
        if not ok then status("Browser outfit failed: "..tostring(msg)) elseif #failed>0 then status("Browser outfit applied; unsupported items: "..table.concat(failed,", ")) else status("Browser outfit applied locally.") end
    end
    local function applyNameState(value)
        if value then lastModeValue=value end
        local state="disabled"
        local username=""
        local displayName=""
        local verified=false
        if value then
            -- Older relays may return an outfit-shaped payload for unknown paths.
            if value.enabled==nil and value.name==nil then return end
            assert(type(value)=="table" and value.version==1 and tostring(value.userId)==tostring(player.UserId) and type(value.enabled)=="boolean" and type(value.name)=="string" and (value.verified==nil or type(value.verified)=="boolean"),"Browser name is invalid.")
            verified=value.verified==true
            if value.enabled then
                assert(value.name=="" or (value.name:match("^[A-Za-z0-9_]+$") and #value.name>=3 and #value.name<=20),"Browser name is invalid.")
                username=value.name
                displayName=type(value.displayName)=="string" and value.displayName or username
                assert(#displayName>=1 and #displayName<=50 and not displayName:find("[%c]"),"Browser display name is invalid.")
                state="enabled:"..username..":"..displayName..(verified and ":verified" or "")
            end
        end
        local firstModeState=value~=nil and not browserModeKnown
        local reenabled=browserModeKnown and not larpEnabled and state~="disabled"
        larpEnabled=state~="disabled";larpName=username;larpDisplayName=displayName;larpVerified=larpEnabled and verified or false
        if reenabled then
            -- Turning off restores the real avatar without deleting the saved
            -- Larp command. A mode-only toggle does not create a new revision.
            lastRevision=0
            if lastBrowserCommand then incoming.browser={value=lastBrowserCommand}end
        end
        if sharing then
            assert(not value or value.sharing==nil or type(value.sharing)=="boolean","Browser sharing preference is invalid.")
            -- The extension owns the persisted preference. Never fall back to
            -- an old in-game toggle when an older extension omits this field.
            local enabled=state~="disabled" and value~=nil and value.sharing==true
            if enabled~=lastSharingPreference then
                sharing.setEnabled(enabled)
                lastSharingPreference=enabled
                if scheduleSnapshot then scheduleSnapshot()end
            end
        end
        if value then browserModeKnown=true end
        if state==lastNameState and not firstModeState then return end
        if value and state=="disabled" and readyForAppearance() then
            -- Restore captured originals, without loading assets or replacing the character.
            -- The browser retains the saved Larp outfit for the next enable.
            retryCommand=nil;incoming.browser=nil
            local avatar=getAvatar()
            avatar.restore()
            if avatar.releasePreparedAppearance then avatar.releasePreparedAppearance()end
            getClothes().restore()
            if getAnimations then getAnimations().setAvatarAssets({}) end
            browserBody,originalBody,browserFace={},{},false
            lastDefinition=nil;lastBrowserSnapshot=nil;imageValue=nil;imageAsset=nil;imageAssetDefinition=nil
            commandSnapshotPending=true
        end
        if getNames then
            local names=getNames()
            if state=="disabled" then names.setEnabled(false)
            elseif username=="" then names.restore()
            else names.set(username,displayName)end
            if names.setVerified then names.setVerified(larpVerified) end
        end
        updateViews()
        lastNameState=state
        -- Rebuild before publishing so peers receive the new verification flag.
        if scheduleSnapshot then scheduleSnapshot() else notifySnapshot()end
    end
    local function closeSocket()
        socketMine=socketMine+1;socketReady=false;socketSupportsSharing=false;sharingConnected=false
        if scheduleSnapshot then scheduleSnapshot()end
        local previous=socket;socket=nil
        if previous then pcall(function()previous:Close()end)end
    end
    local function send(channel,value)
        if socketReady and socket then
            local ok=pcall(function()socket:Send(HttpService:JSONEncode({type="publish",channel=channel,value=value}))end)
            if ok then return end
            closeSocket()
            if scheduleReconnect then scheduleReconnect()end
        end
        local path="/v1/"..(channel=="game" and "game" or channel).."/"..player.UserId
        local ok,result=pcall(call,"POST",path,token,value)
        if not ok and tostring(result):find("HTTP 401",1,true)then
            -- A desktop restart can invalidate the cached credential before
            -- the socket closes. Recover once in response to that rejection.
            local paired,pair=pcall(call,"GET","/v1/pair","")
            if paired and pair and validToken(pair.code) and pair.code~=token then
                local connectedAgain=pcall(api.connect,pair.code)
                if connectedAgain then return call("POST",path,token,value)end
            end
        end
        if not ok then connectionState(false);error(result,0)end
        return result
    end
    local function publishSnapshot()
        snapshotScheduleId=snapshotScheduleId+1
        snapshotPending=false
        if not readyForAppearance() then return end
        local made,value=pcall(snapshot)
        local changed=false
        if made then
            if commandSnapshotPending then
                commandSnapshotPending=false
            elseif not lastDefinition or (lastSnapshot and definitionKey(value.definition)~=definitionKey(lastSnapshot.definition)) then
                lastDefinition=value.definition
            end
            lastSnapshot=value
            local encoded=HttpService:JSONEncode(value)
            if encoded~=lastJson then
                changed=true
                local sent,reason=pcall(send,"game",value)
                if sent then lastJson=encoded else status("Desktop update failed: "..tostring(reason))end
            end
        end
        if changed then updateViews();notifySnapshot()end
    end
    local function disconnectAll(connections)
        for _,connection in ipairs(connections)do pcall(function()connection:Disconnect()end)end
        table.clear(connections)
    end
    local function connectSignal(signal,connections,callback)
        if not signal then return end
        local ok,connection=pcall(function()return signal:Connect(callback)end)
        if ok and connection then connections[#connections+1]=connection end
    end
    local function disconnectCharacterWatchers()
        disconnectAll(characterConnections)
        for _,connections in pairs(instanceConnections)do disconnectAll(connections)end
        instanceConnections={}
    end
    local function watchProperty(instance,property)
        local ok,signal=pcall(function()return instance:GetPropertyChangedSignal(property)end)
        if ok then connectSignal(signal,instanceConnections[instance],scheduleSnapshot)end
    end
    scheduleSnapshot=function()
        if not connected or snapshotPending then return end
        snapshotPending=true
        local mine=generation
        snapshotScheduleId=snapshotScheduleId+1
        local scheduleId=snapshotScheduleId
        task.delay(0.15,function()
            if mine~=generation or scheduleId~=snapshotScheduleId then return end
            snapshotPending=false
            if connected then publishSnapshot()end
        end)
    end
    local function watchAppearanceInstance(instance)
        if instanceConnections[instance]then return false end
        -- Effects, animation tracks and equipped tools are not outfit data.
        -- In particular, Chroma weapon colors change continuously.
        local character=player.Character
        if instance:FindFirstAncestorOfClass("Tool")then return false end
        local relevant=instance:IsA("Accessory") or instance:IsA("Humanoid") or instance:IsA("BodyColors")
            or instance:IsA("Clothing") or instance:IsA("ShirtGraphic") or instance:IsA("CharacterMesh")
            or (instance:IsA("BasePart") and instance.Parent==character)
        local scale=false
        if instance:IsA("NumberValue") and instance.Parent and instance.Parent:IsA("Humanoid")then
            for _,name in pairs(SCALE_PROPERTIES)do if instance.Name==name then scale=true;break end end
        end
        if not relevant and not scale then return false end
        instanceConnections[instance]={}
        if scale then watchProperty(instance,"Value");return true end
        local okHumanoid,isHumanoid=pcall(function()return instance:IsA("Humanoid")end)
        if okHumanoid and isHumanoid then
            local ok,signal=pcall(function()return instance.ApplyDescriptionFinished end)
            if ok then connectSignal(signal,instanceConnections[instance],scheduleSnapshot)end
        end
        local okBodyColors,isBodyColors=pcall(function()return instance:IsA("BodyColors")end)
        if okBodyColors and isBodyColors then
            for _,property in ipairs({"HeadColor3","TorsoColor3","LeftArmColor3","RightArmColor3","LeftLegColor3","RightLegColor3"})do
                watchProperty(instance,property)
            end
            return true
        end
        local okPart,isPart=pcall(function()return instance:IsA("BasePart")end)
        if okPart and isPart and instance.Parent==character then watchProperty(instance,"Color")end
        local propertyByClass={
            Shirt={"ShirtTemplate"},Pants={"PantsTemplate"},ShirtGraphic={"Graphic"},
            MeshPart={"MeshId","TextureID"},SpecialMesh={"MeshId","TextureId","VertexColor"},
            Decal={"Texture"},CharacterMesh={"MeshId","BaseTextureId","OverlayTextureId"},
            SurfaceAppearance={"ColorMap"},
        }
        for className,properties in pairs(propertyByClass)do
            local ok,isClass=pcall(function()return instance:IsA(className)end)
            if ok and isClass then
                for _,property in ipairs(properties)do watchProperty(instance,property)end
            end
        end
        return true
    end
    local function forgetAppearanceSubtree(root)
        for instance,connections in pairs(instanceConnections)do
            local ok,inside=pcall(function()return instance==root or instance:IsDescendantOf(root)end)
            if ok and inside then
                disconnectAll(connections)
                instanceConnections[instance]=nil
            end
        end
    end
    local function bindCharacter(character)
        disconnectCharacterWatchers()
        if not character then return end
        connectSignal(character.DescendantAdded,characterConnections,function(instance)
            if watchAppearanceInstance(instance)then scheduleSnapshot()end
        end)
        connectSignal(character.DescendantRemoving,characterConnections,function(instance)
            local relevant=instanceConnections[instance]~=nil
            forgetAppearanceSubtree(instance)
            if relevant then scheduleSnapshot()end
        end)
        for _,instance in ipairs(character:GetDescendants())do watchAppearanceInstance(instance)end
        scheduleSnapshot()
    end
    local function startAppearanceWatchers()
        disconnectAll(appearanceConnections)
        disconnectCharacterWatchers()
        snapshotPending=false
        snapshotScheduleId=snapshotScheduleId+1
        local playerGui=player:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            connectSignal(playerGui.AttributeChanged,appearanceConnections,function(attribute)
                if type(attribute)=="string" and (attribute:find("CosmeticUI",1,true) or attribute=="HoneyBunCosmeticEmotes" or attribute=="HoneyBunCosmeticAnimationBundle")then scheduleSnapshot()end
            end)
        end
        connectSignal(player.CharacterAdded,appearanceConnections,bindCharacter)
        connectSignal(player.CharacterAppearanceLoaded,appearanceConnections,function()
            if retryCommand then
                incoming.browser={value=retryCommand};retryCommand=nil
                task.defer(function()if connected then pump()end end)
            end
            scheduleSnapshot()
        end)
        connectSignal(player.CharacterRemoving,appearanceConnections,function()bindCharacter(nil)end)
        bindCharacter(player.Character)
    end
    local function stopAppearanceWatchers()
        disconnectAll(appearanceConnections)
        disconnectCharacterWatchers()
        snapshotPending=false
        snapshotScheduleId=snapshotScheduleId+1
    end
    pump=function()
        if pumping then return end
        pumping=true;local mine=generation
        local ok,err=pcall(function()
            while connected and generation==mine and next(incoming)do
                local batch=incoming;incoming={}
                if batch.browser and batch.browser.value and batch.browser.value.revision then
                    -- Sharing can use the validated saved outfit before local
                    -- asset restoration finishes. Never publish a half-restored body.
                    local value=validSnapshot(batch.browser.value)
                    local revision=tonumber(value.revision)
                    assert(revision and revision%1==0 and revision>0 and revision<9007199254740992,"Browser revision is invalid.")
                    if not lastBrowserCommand or revision>=lastBrowserCommand.revision then
                        lastBrowserCommand=value
                        for callback in pairs(snapshotListeners)do pcall(callback,nil)end
                    end
                end
                if batch.names then applyNameState(batch.names.value)end
                local previousRevision=lastRevision
                if batch.browser and batch.browser.value and batch.browser.value.revision then
                    local command=batch.browser.value
                    applyCommand(command)
                    if lastRevision<command.revision then
                        retryCommand=command
                        if retryTimerCommand~=command then
                            if retryRevision~=command.revision then retryAttempt=0;retryRevision=command.revision end
                            retryTimerCommand=command
                            local delay=math.min(30,2^math.min(retryAttempt,5))
                            retryAttempt=retryAttempt+1
                            task.delay(delay,function()
                                if retryTimerCommand~=command then return end
                                retryTimerCommand=nil
                                if not connected or generation~=mine or not larpEnabled or not isAlive()
                                    or lastRevision>=command.revision or not lastBrowserCommand
                                    or lastBrowserCommand.revision~=command.revision then return end
                                -- A failed download must recover without a new
                                -- browser event or respawn. Only retry the latest outfit.
                                if not incoming.browser then incoming.browser={value=command}end
                                task.spawn(pump)
                            end)
                        end
                    else retryCommand=nil;retryTimerCommand=nil;retryAttempt=0 end
                end
                if batch.image then
                    local value=batch.image.value
                    task.spawn(function()if generation==mine and connected then applyImage(value)end end)
                end
                if lastRevision~=previousRevision then publishSnapshot()end
            end
        end)
        pumping=false
        if not ok then status("Browser socket: "..tostring(err))end
    end
    local recovery={enabled=true,pending=false,attempt=0,serial=0}
    scheduleReconnect=function()
        if not recovery.enabled or recovery.pending or not isAlive()then return end
        recovery.pending=true
        local serial=recovery.serial
        local delay=math.min(30,2^math.min(recovery.attempt,5))
        recovery.attempt=recovery.attempt+1
        status("Desktop disconnected. Reconnecting automatically...")
        task.delay(delay,function()
            if recovery.serial~=serial then return end
            recovery.pending=false
            if not recovery.enabled or not isAlive() or socketReady then return end
            pcall(api.connect)
        end)
    end
    local function openSocket()
        local ws=WebSocket or websocket or (syn and syn.websocket)
        local connect=ws and (ws.connect or ws.new)
        if socket then return false end
        if type(connect)~="function"then connectionState(false);return false end
        local mine=generation;local serial=socketMine
        local ok,candidate=pcall(connect,"ws://127.0.0.1:"..PORT.."/v1/socket")
        if not ok or not candidate then connectionState(false);status("Desktop connection unavailable. Open desktop and reload the interface.");return false end
        if mine~=generation then pcall(function()candidate:Close()end);return end
        socket=candidate
        candidate.OnClose:Connect(function()
            if socket==candidate then
                socket=nil;socketReady=false;lastJson=nil;sharingConnected=false
                connectionState(false)
                scheduleReconnect()
            end
        end)
        candidate.OnMessage:Connect(function(message)
            if socket~=candidate or generation~=mine or socketMine~=serial then return end
            local read,value=pcall(function()return HttpService:JSONDecode(message)end)
            if not read or type(value)~="table" then return end
            if value.type=="ready" then
                socketReady=true;lastJson=nil
                recovery.attempt=0
                connectionState(true)
                local function keepAlive()
                    task.delay(20,function()
                        if socket~=candidate or generation~=mine or not socketReady then return end
                        local sent=pcall(function()candidate:Send('{"type":"ping"}')end)
                        if sent then keepAlive()else candidate:Close()end
                    end)
                end
                keepAlive()
                socketSupportsSharing=value.sharing==true
                if desiredSharing and socketSupportsSharing then
                    pcall(function()candidate:Send(HttpService:JSONEncode({type="sharing",value=desiredSharing}))end)
                elseif desiredSharing and desiredSharing.enabled then
                    notifySharing({type="status",message="Update Larpblox Desktop to use shared appearances."})
                end
                if value.instanceId~=api.instanceId then lastRevision=0;lastNameState=nil;api.instanceId=value.instanceId end
                scheduleSnapshot()
                status("Browser connected via WebSocket.")
            elseif value.type=="client-request" and sharing and sharing.clientRequest then
                local id,method,params=value.id,value.method,value.params
                if type(id)~="string" or #id~=36 or not id:match("^[%x%-]+$") or type(method)~="string" or #method>64 or not method:match("^[%l%d%._]+$") or type(params)~="table"then return end
                task.spawn(function()
                    if socket~=candidate or generation~=mine or not isAlive()then return end
                    local loaded,result=pcall(sharing.clientRequest,method,params)
                    if socket~=candidate or generation~=mine or not isAlive()then return end
                    local response={type="client-result",id=id,ok=loaded}
                    if loaded then response.result=result
                    else response.error=tostring(result):gsub("%c"," "):sub(1,256)end
                    pcall(function()candidate:Send(HttpService:JSONEncode(response))end)
                end)
            elseif value.type=="avatar-lookup" and sharing and sharing.lookupAvatar then
                local id,target=value.id,tonumber(value.targetUserId)
                if type(id)~="string" or #id~=36 or not id:match("^[%x%-]+$") or not safeId(target)then return end
                task.spawn(function()
                    if socket~=candidate or generation~=mine or not isAlive()then return end
                    local loaded,result=pcall(sharing.lookupAvatar,target)
                    if socket~=candidate or generation~=mine or not isAlive()then return end
                    local response={type="avatar-lookup-result",id=id,ok=loaded}
                    if loaded then response.snapshot=result
                    else response.error=tostring(result):gsub("%c"," "):sub(1,256)end
                    pcall(function()candidate:Send(HttpService:JSONEncode(response))end)
                end)
            elseif value.type=="state" and value.channel=="shared" then
                notifySharing(value.value)
            elseif value.type=="state" and (value.channel=="browser" or value.channel=="names" or value.channel=="image") then
                incoming[value.channel]={value=value.value};task.spawn(pump)
            elseif value.type=="error" then connectionState(false);closeSocket();scheduleReconnect()end
        end)
        local sent=pcall(function()candidate:Send(HttpService:JSONEncode({version=1,type="auth",token=token,userId=tostring(player.UserId),role="game",avatarLookup=sharing and type(sharing.lookupAvatar)=="function" or false,clientRequests=sharing and type(sharing.clientRequest)=="function" or false}))end)
        if not sent then connectionState(false);closeSocket();return false end
        task.delay(5,function()
            if socket==candidate and generation==mine and not socketReady then
                connectionState(false)
                closeSocket();scheduleReconnect()
            end
        end)
        return true
    end
    local function connectOnce(code)
        if not code or code=="" then
            local ok,pair=pcall(call,"GET","/v1/pair","")
            code=ok and pair and pair.code or readSaved()
        end
        assert(validToken(code),"Open the Larpblox app to connect.")
        local relay=call("GET","/v1/status",code);if relay and relay.instanceId and relay.instanceId~=api.instanceId then lastRevision=0;lastNameState=nil;api.instanceId=relay.instanceId end
        closeSocket();incoming={};retryCommand=nil;retryTimerCommand=nil;retryAttempt=0;generation=generation+1;token=code;connected=true;lastJson=nil;save(code);status("Browser connected.")
        startAppearanceWatchers()
        local opened=openSocket()
        if not opened then connected=false end
        return opened
    end
    function api.connect(code)
        recovery.enabled=true
        local ok,result=pcall(connectOnce,code)
        if not ok or not result then scheduleReconnect()end
        if not ok then error(result,0)end
        return result
    end
    function api.disconnect()recovery.enabled=false;recovery.pending=false;recovery.serial=recovery.serial+1;generation=generation+1;stopAppearanceWatchers();closeSocket();incoming={};retryCommand=nil;retryTimerCommand=nil;retryAttempt=0;connected=false;token=nil;lastJson=nil;lastNameState=nil;sharingConnected=false;applyNameState(nil);lastSharingPreference=nil;queueViews({enabled=false});status("Browser disconnected.")end
    function api.isLarpEnabled()return larpEnabled end
    function api.isConnected()return connected end
    function api.status()return connected and (socketReady and "Browser connected via WebSocket." or "Waiting for desktop WebSocket.") or "Browser disconnected."end
    function api.publish()assert(connected,"Connect the browser first.");local value=snapshot();local encoded=HttpService:JSONEncode(value);if encoded~=lastJson then send("game",value);lastJson=encoded end;return value end
    function api.snapshot()return snapshot()end
    function api.snapshotForSharing()
        local saved=lastBrowserCommand or lastBrowserSnapshot
        if saved then
            local value={};for key,item in pairs(saved)do value[key]=item end
            value.verified=larpVerified
            return value
        end
        assert(readyForAppearance(),"Waiting for the saved browser outfit.")
        return snapshot()
    end
    function api.prepareSavedAppearance()
        -- The bridge already retains commands before startup readiness. Warming
        -- their native source is read-only; visible application still waits for
        -- the existing restore/readiness lifecycle.
        local command=lastBrowserCommand
        if not larpEnabled or not command or not sharing or not sharing.describeSnapshot then return end
        local avatar=getAvatar()
        if not avatar.prepareAppearance then return end
        local character=player.Character
        local function current()
            return isAlive() and larpEnabled and lastBrowserCommand==command and player.Character==character
        end
        local ok,err=pcall(avatar.prepareAppearance,command,sharing.describeSnapshot,current)
        if not ok and current() and sharing.log then sharing.log("local_native_source_failed",{detail=tostring(err)})end
    end
    function api.resumeAppearance(characterChanged)
        if not readyForAppearance()then return end
        -- A revision belongs to an applied character, not just a received outfit.
        -- Replay the retained browser selection after respawn restoration finishes.
        if characterChanged and larpEnabled and lastBrowserCommand then
            lastRevision=0
            retryCommand=lastBrowserCommand
        end
        if lastModeValue then lastNameState=nil;applyNameState(lastModeValue)end
        if retryCommand then incoming.browser={value=retryCommand};retryCommand=nil end
        if connected then task.defer(pump);scheduleSnapshot()end
    end
    function api.onSnapshot(callback)
        snapshotListeners[callback]=true
        return function()snapshotListeners[callback]=nil end
    end
    function api.onShared(callback)
        sharingListeners[callback]=true
        return function()sharingListeners[callback]=nil end
    end
    function api.setSharing(value)
        if value.enabled then
            -- Preferences can arrive through HTTP before the socket handshake.
            -- Keep the publication queued; the ready event sends it once the
            -- transport is available instead of discarding the names update.
            if socketReady then
                assert(socketSupportsSharing,"Update Larpblox Desktop to use shared appearances.")
            end
        end
        desiredSharing=value
        if not value.enabled then sharingConnected=false end
        if scheduleSnapshot then scheduleSnapshot()end
        if socketReady and socketSupportsSharing then
            socket:Send(HttpService:JSONEncode({type="sharing",value=value}))
        end
    end
    function api.sharedImageUrl()
        if not connected or not larpEnabled or not imageValue then return nil end
        if lastBrowserSnapshot and definitionKey(imageValue.definition)~=definitionKey(lastBrowserSnapshot.definition) then return nil end
        return imageValue.imageUrl
    end
    function api.destroy()api.disconnect()end
    local saved=readSaved()
    task.defer(function()
        if not isAlive()then return end
        local ok,err=pcall(api.connect)
        if not ok then connectionState(false);scheduleReconnect()end
    end)
    return api,saved
end
