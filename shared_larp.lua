-- Opt-in, local rendering of Larpblox appearances shared by clients in the same Roblox server.
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local ACCESSORY_TYPES={[8]=true,[41]=true,[42]=true,[43]=true,[44]=true,[45]=true,[46]=true,[47]=true,[64]=true,[65]=true,[66]=true,[67]=true,[68]=true,[69]=true,[70]=true,[71]=true,[72]=true,[76]=true,[77]=true}
local BODY_TYPES={[17]="Head",[27]="Torso",[28]="RightArm",[29]="LeftArm",[30]="LeftLeg",[31]="RightLeg",[79]="Head"}
local BODY_REGIONS={"Head","Torso","RightArm","LeftArm","LeftLeg","RightLeg"}
local SCALE_VALUES={height="BodyHeightScale",width="BodyWidthScale",depth="BodyDepthScale",head="HeadScale",bodyType="BodyTypeScale",proportion="BodyProportionScale"}
local CLOTHES_TYPES={[2]="ShirtGraphic",[11]="Shirt",[12]="Pants"}
local ANIMATION_TYPES={[48]=true,[50]=true,[51]=true,[52]=true,[53]=true,[54]=true,[55]=true,[56]=true,[78]=true}
local COLOR_REGIONS={{"Head","headColor"},{"Torso","torsoColor"},{"LeftArm","leftArmColor"},{"RightArm","rightArmColor"},{"LeftLeg","leftLegColor"},{"RightLeg","rightLegColor"}}

local function safeId(value)
    local n=tonumber(value)
    return n and n>0 and n%1==0 and n<9007199254740992 and n or nil
end
local function safeImageUrl(value)
    return type(value)=="string" and #value<=2048 and
        (value:match("^https://tr%.rbxcdn%.com/[%w%-%._~/]+$") or value:match("^https://t%d%.rbxcdn%.com/[%w%-%._~/]+$"))~=nil
end

local function sameValue(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for key,value in pairs(a)do if not sameValue(value,b[key])then return false end end
    for key in pairs(b)do if a[key]==nil then return false end end
    return true
end

return function(localPlayer,getSnapshot,getNameSettings,createAvatar,createClothes,createAnimations,createNames,isAlive,onStatus,presentation)
    presentation=presentation or {}
    local sharing=false
    local generation=0
    local peers={}
    local imageSerial=0
    local lastSent
    local transport=presentation.transport
    local latestRecords,pending,connections={},{},{}
    local liveRecords,profileRecords,profileRequests={},{},{}
    local profileQueued=false
    local processing={}
    local processPending
    local nextStatus=0
    local lastDiagnostic={}
    local diagnosticGui=localPlayer:FindFirstChildOfClass("PlayerGui")
    local function diagnose(userId,phase,detail,ms,checkpoint)
        local key=tostring(userId)
        local signature=phase..":"..tostring(detail or "")
        if ms==nil and lastDiagnostic[key]==signature then return end
        lastDiagnostic[key]=signature
        if presentation.log then presentation.log("shared_"..phase,{peerId=key,detail=detail or "",ms=ms},checkpoint)end
        if not diagnosticGui then return end
        -- Event-written, bounded metadata for support; never include tokens.
        diagnosticGui:SetAttribute("LarpbloxShared_"..tostring(userId),HttpService:JSONEncode({
            phase=phase,detail=detail or "",time=os.clock(),
        }))
    end
    local function status(message)
        if onStatus and os.clock()>=nextStatus then nextStatus=os.clock()+4;onStatus(message)end
    end
    local function roomContext()
        local placeId=tonumber(game.PlaceId)
        local jobId=tostring(game.JobId or "")
        assert(placeId and placeId>0 and placeId%1==0,"Join a live Roblox server before enabling shared Larp mode.")
        assert(jobId~="" and jobId~="00000000-0000-0000-0000-000000000000","Shared Larp mode is available in live game servers, not Studio.")
        assert(jobId:match("^[A-Za-z0-9%-]+$"),"This game server has an unsupported instance ID.")
        return string.format("%.0f",placeId),jobId
    end
    local function cleanupPeer(userId)
        local entry=peers[userId]
        if not entry then return end
        peers[userId]=nil
        if entry.stopObserving then entry.stopObserving();entry.stopObserving=nil end
        for value,original in pairs(entry.originalScales or {})do
            pcall(function()if value.Parent then value.Value=original end end)
        end
        if entry.hatScripts then pcall(entry.hatScripts.destroy)end
        for _,api in ipairs({entry.names,entry.animations,entry.clothes,entry.avatar,entry.views})do
            if api and api.destroy then pcall(api.destroy)end
        end
        if entry.imagePath and type(delfile)=="function" then pcall(delfile,entry.imagePath)end
    end
    local function cleanupAll()
        for userId in pairs(peers)do cleanupPeer(userId)end
    end
    local function peerApis(player)
        local playerGui
        -- Other players' names are displayed in this client's GUI.
        pcall(function()playerGui=localPlayer:FindFirstChildOfClass("PlayerGui")end)
        local function callback(message)status("Shared appearance for "..player.Name..": "..tostring(message))end
        return {
            avatar=createAvatar(player,callback),
            clothes=createClothes(player,callback),
            animations=createAnimations(player,callback),
            names=createNames(player,playerGui),
            player=player,
            character=player.Character,
        }
    end
    local function validRecord(record)
        if type(record)~="table" or record.version~=1 or type(record.userId)~="string" then return false end
        local snapshot=record.snapshot
        if type(snapshot)~="table" or snapshot.version~=1 or tostring(snapshot.userId)~=record.userId then return false end
        if snapshot.verified~=nil and type(snapshot.verified)~="boolean" then return false end
        if not safeId(record.userId) or type(snapshot.definition)~="table" or type(snapshot.definition.assets)~="table" or #snapshot.definition.assets>512 or type(snapshot.items)~="table" or #snapshot.items>512 then return false end
        if record.imageUrl~=nil and not safeImageUrl(record.imageUrl) then return false end
        if record.verified~=nil and type(record.verified)~="boolean" then return false end
        if record.hatScripts~=nil and presentation.validHatScripts and not presentation.validHatScripts(record.hatScripts)then return false end
        if record.name~=nil then
            local name=record.name
            if type(name)~="table" or type(name.enabled)~="boolean" or type(name.username)~="string" or #name.username>20 or not name.username:match("^[A-Za-z0-9_]*$") or type(name.displayName)~="string" or #name.displayName>50 or name.displayName:find("[%c]") then return false end
            if name.enabled and (#name.username<3 or #name.displayName<1) then return false end
        end
        return true
    end
    local function presentRecord(entry,record)
        local previous=entry.presented
        if previous and sameValue(previous.snapshot,record.snapshot) and sameValue(previous.name,record.name)
            and previous.verified==record.verified and previous.imageUrl==record.imageUrl then return end
        local name=record.name
        if not sameValue(entry.name,name)then
            if type(name)=="table" and name.enabled then pcall(entry.names.set,name.username,name.displayName)
            else pcall(entry.names.restore)end
        end
        entry.name=name
        if entry.names.setVerified and entry.verified~=(record.verified==true) then entry.names.setVerified(record.verified==true) end
        entry.verified=record.verified==true
        if presentation.createViews and peers[record.userId]==entry and sharing and isAlive() then
            if not entry.views then entry.views=presentation.createViews(entry.player)end
            local options={enabled=true,name=name and name.enabled and name.username or "",displayName=name and name.enabled and name.displayName or "",verified=record.verified==true,snapshot=record.snapshot,image=entry.image}
            entry.viewOptions=options
            local custom=getcustomasset or getsynasset
            if record.imageUrl~=entry.presentationImageUrl then
                entry.imageGeneration=(entry.imageGeneration or 0)+1
                entry.image=nil;options.image=nil
            end
            entry.views.update(options)
            if record.imageUrl and record.imageUrl~=entry.presentationImageUrl and type(custom)=="function" and type(writefile)=="function" then
                local imageGeneration=entry.imageGeneration
                task.spawn(function()
                    local loaded,reason=pcall(function()
                        local bytes=transport.downloadImage(record.imageUrl)
                        assert(type(bytes)=="string" and #bytes<=4*1024*1024 and bytes:sub(1,8)=="\137PNG\r\n\26\n","Invalid shared avatar image.")
                        if peers[record.userId]~=entry or entry.imageGeneration~=imageGeneration or not sharing or not isAlive() then return end
                        imageSerial=imageSerial+1
                        local path="larpblox-shared-avatar-"..record.userId.."-"..imageSerial..".png"
                        local previousPath=entry.imagePath
                        entry.imagePath=path
                        writefile(path,bytes)
                        local image=custom(path)
                        if peers[record.userId]~=entry or entry.imageGeneration~=imageGeneration or not sharing or not isAlive() then return end
                        entry.image=image;entry.viewOptions.image=image;entry.views.update(entry.viewOptions)
                        if previousPath and type(delfile)=="function"then pcall(delfile,previousPath)end
                    end)
                    if not loaded and peers[record.userId]==entry then status("Shared avatar image: "..tostring(reason))end
                end)
            end
        end
        entry.presentationImageUrl=record.imageUrl
        entry.presented=record
    end
    local function observeAppearance(entry,userId)
        if entry.stopObserving then entry.stopObserving()end
        local character=entry.character
        if not character then return end
        local connections,expected={},{}
        local active,queued=true,false
        local function properties(object)
            local parent=object.Parent
            if parent==character then
                if object:IsA("BasePart") and object.Name~="HumanoidRootPart" then
                    if object:IsA("MeshPart")then return {"Color","Size","Transparency","MeshId","TextureID"}end
                    return {"Color","Size","Transparency"}
                elseif object:IsA("Clothing") or object:IsA("ShirtGraphic")then return nil
                elseif object:IsA("CharacterMesh")then return {"MeshId","BaseTextureId","OverlayTextureId"}
                elseif object:IsA("BodyColors")then return {"HeadColor3","TorsoColor3","LeftArmColor3","RightArmColor3","LeftLegColor3","RightLegColor3"}
                elseif object:IsA("Accessory") or object:IsA("Hat")then return {}end
            elseif parent and parent.Parent==character and parent.Name=="Head"then
                if object:IsA("Decal")then return {"Texture","Transparency"}
                elseif object:IsA("SpecialMesh")then return {"MeshId","TextureId","Scale","Offset"}
                elseif object:IsA("SurfaceAppearance")then return {"ColorMap"}end
            end
        end
        local function changed()
            if not active or queued then return end
            queued=true
            task.defer(function()
                queued=false
                if not active or not sharing or not isAlive() or peers[userId]~=entry
                    or entry.player.Character~=character then return end
                local dirty,accessoryOnly=false,true
                local reason
                local function mark(object,detail)
                    dirty=true
                    local accessory=object:IsA("Accessory") or object:IsA("Hat")
                    if not accessory then accessoryOnly=false end
                    reason=detail
                end
                for object,values in pairs(expected)do
                    if not object:IsDescendantOf(character)then mark(object,object.ClassName.." "..object.Name.." removed")
                    else for property,value in pairs(values)do
                        if object[property]~=value then mark(object,object.Name.."."..property);break end
                    end
                    end
                    if dirty and not accessoryOnly then break end
                end
                -- An accessory event can coincide with a body replacement.
                -- Check both before deciding that only accessories need repair.
                if accessoryOnly then
                    for _,object in ipairs(character:GetChildren())do
                        if properties(object) and not expected[object]then mark(object,object.ClassName.." added")end
                        if dirty and not accessoryOnly then break end
                    end
                    local head=character:FindFirstChild("Head")
                    if accessoryOnly and head then
                        for _,object in ipairs(head:GetChildren())do
                            if properties(object) and not expected[object]then mark(object,object.ClassName.." added");break end
                        end
                    end
                end
                if dirty then
                    if accessoryOnly then
                        entry.accessoriesComplete=false;entry.refreshAccessories=true
                    else
                        entry.snapshot=nil;entry.appearanceStarted=nil;entry.accessoriesComplete=nil
                    end
                    local record=latestRecords[userId]
                    if record then
                        diagnose(userId,"appearance_changed",reason)
                        pending[userId]=record;processPending()
                    end
                end
            end)
        end
        local function watch(object)
            local fields=properties(object)
            if not fields then return end
            local values={};expected[object]=values
            for _,property in ipairs(fields)do
                local ok,value=pcall(function()return object[property]end)
                if ok then
                    values[property]=value
                    connections[#connections+1]=object:GetPropertyChangedSignal(property):Connect(changed)
                end
            end
        end
        local attachmentRetryQueued=false
        connections[#connections+1]=character.DescendantAdded:Connect(function(object)
            if properties(object)then changed()end
            local parent=object.Parent
            if object:IsA("Attachment") and parent and parent:IsA("BasePart") and parent.Parent==character
                and entry.accessoriesComplete==false and not attachmentRetryQueued then
                attachmentRetryQueued=true
                task.defer(function()
                    attachmentRetryQueued=false
                    if not active or not sharing or not isAlive() or peers[userId]~=entry
                        or entry.player.Character~=character or entry.accessoriesComplete~=false then return end
                    local record=latestRecords[userId]
                    if record then
                        diagnose(userId,"retry_accessories",object.Name)
                        -- Retain the completed body/clothing state and existing
                        -- accessories; applyRecord retries only missing items.
                        pending[userId]=record;processPending()
                    end
                end)
            end
        end)
        connections[#connections+1]=character.DescendantRemoving:Connect(function(object)if expected[object]then changed()end end)
        for _,object in ipairs(character:GetChildren())do watch(object)end
        local head=character:FindFirstChild("Head")
        if head then for _,object in ipairs(head:GetChildren())do watch(object)end end
        entry.stopObserving=function()
            active=false
            for _,connection in ipairs(connections)do connection:Disconnect()end
        end
    end
    local function refreshCharacter(entry,target)
        if entry.character==target.Character then return end
        if entry.stopObserving then entry.stopObserving();entry.stopObserving=nil end
        -- Controllers already reset character-owned state on CharacterAdded.
        -- Preserve their asset caches, names and thumbnail renderers.
        entry.character=target.Character
        entry.snapshot=nil
        entry.appearanceStarted=nil
        entry.accessoriesComplete=nil
        entry.refreshAccessories=nil
        entry.animationAssets=nil
        entry.originalScales=nil
    end
    local function appearanceReady(target,character)
        if not character or target.Character~=character then return false end
        local humanoid=character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health<=0 or not character:FindFirstChild("Head")then return false end
        -- CharacterAppearanceLoaded is server-only. On the receiving client,
        -- use replicated rig parts instead of waiting on that server signal.
        local required=humanoid.RigType==Enum.HumanoidRigType.R6
            and {"Torso","Left Arm","Right Arm","Left Leg","Right Leg"}
            or {"UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand",
                "RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg",
                "LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"}
        for _,name in ipairs(required)do
            local part=character:FindFirstChild(name)
            if not part or not part:IsA("BasePart")then return false end
        end
        return true
    end
    local function queueRecord(record)
        local changed=not sameValue(latestRecords[record.userId],record)
        latestRecords[record.userId]=record;pending[record.userId]=record
        if changed then diagnose(record.userId,"received","revision "..tostring(record.snapshot.revision or "unknown")..", "..tostring(#record.snapshot.items).." items")end
        local target=Players:GetPlayerByUserId(tonumber(record.userId))
        if not target or target==localPlayer then return end
        local entry=peers[record.userId]
        if entry and entry.player~=target then cleanupPeer(record.userId);entry=nil end
        if entry then refreshCharacter(entry,target)end
        if not entry then entry=peerApis(target);peers[record.userId]=entry end
        local ok,reason=pcall(presentRecord,entry,record)
        if not ok then status("Shared appearance: "..tostring(reason))end
    end
    local function applyRecord(record)
        if not validRecord(record) or record.userId==tostring(localPlayer.UserId) then return end
        local target=Players:GetPlayerByUserId(tonumber(record.userId))
        if not target or target==localPlayer then return end
        local character=target.Character
        local snapshot=record.snapshot
        local entry=peers[record.userId]
        if entry and entry.player==target and entry.character==target.Character
            and entry.accessoriesComplete~=false
            and sameValue(entry.snapshot,snapshot) and sameValue(entry.name,record.name)
            and entry.verified==(record.verified==true)
            and entry.imageUrl==record.imageUrl then
            if entry.hatScripts then entry.hatScripts.update(record.hatScripts,record.snapshot)end
            return
        end
        if entry and entry.player~=target then cleanupPeer(record.userId);entry=nil end
        if entry then refreshCharacter(entry,target)end
        local fresh=not entry or not entry.appearanceStarted
        if not entry then entry=peerApis(target);peers[record.userId]=entry end
        local function current()
            return sharing and isAlive() and peers[record.userId]==entry
                and latestRecords[record.userId]==record and target.Character==character
        end
        -- Names and thumbnails need no generated body. Present them as soon as
        -- the record arrives, even while Roblox is still spawning the character.
        presentRecord(entry,record)
        -- Readiness events replay the retained record once a body is available.
        if not appearanceReady(target,character)then diagnose(record.userId,"waiting_for_character");return end
        diagnose(record.userId,"applying")
        local applyStarted=os.clock()
        if entry.stopObserving then entry.stopObserving();entry.stopObserving=nil end
        local accessoryFailures={}
        local ok,err=pcall(function()
            -- Resolve cold catalog assets before any visible body changes.
            -- Cached preparation does not clone or attach an accessory.
            local preparationFailures={}
            if entry.avatar.prepareAppearance and presentation.describeSnapshot then
                local prepared,reason=pcall(entry.avatar.prepareAppearance,snapshot,presentation.describeSnapshot,current)
                if not current()then return end
                if not prepared then diagnose(record.userId,"native_source_failed",tostring(reason))end
            end
            if entry.avatar.prepareAccessories then
                local ids,existing={},{}
                for _,item in ipairs(entry.avatar.listAccessories())do existing[item.id]=true end
                for _,item in ipairs(snapshot.items)do
                    if ACCESSORY_TYPES[tonumber(item.assetType)] and not existing[item.id]then ids[#ids+1]=item.id end
                end
                if fresh then diagnose(record.userId,"preparing_accessories",tostring(#ids).." assets",nil,true)end
                preparationFailures=entry.avatar.prepareAccessories(ids,current)
                if not current()then return end
            end
            -- Keep the live overlay and its caches when only part of the outfit changes.
            local previous=entry.snapshot or {}
            local oldItems,oldSlots,slots={},{},{}
            for _,item in ipairs(previous.items or {})do oldItems[tostring(item.assetType)..":"..tostring(item.id)]=true;oldSlots[tonumber(item.assetType) or 0]=true end
            for _,item in ipairs(snapshot.items)do slots[tonumber(item.assetType) or 0]=true end
            for _,item in ipairs(previous.items or {})do
                local kind=tonumber(item.assetType)
                if not slots[kind]then
                    if kind==18 then pcall(entry.avatar.restoreFace)
                    elseif kind==19 then pcall(entry.avatar.removeGear)end
                end
            end
            local wanted={}
            local wantedClothes={}
            local animationAssets={}
            local body,oldBody={},{}
            for _,item in ipairs(previous.items or {})do
                local region=BODY_TYPES[tonumber(item.assetType)]
                if region then oldBody[region]=item.id end
            end
            for _,item in ipairs(snapshot.items)do
                local region=BODY_TYPES[tonumber(item.assetType)]
                if region then body[region]=item.id end
            end
            -- These are complete outfits. Zero/default body parts are deliberately
            -- omitted from the asset list; absence means blocky, not the peer's
            -- original Roblox package. Apply on first render and after respawn too.
            local humanoid=target.Character and target.Character:FindFirstChildOfClass("Humanoid")
            local blocky,bodyChanged=true,fresh
            local headOnly=not fresh and not sameValue(body.Head or 0,oldBody.Head or 0)
                and sameValue(snapshot.definition.scales,previous.definition and previous.definition.scales)
            for _,region in ipairs(BODY_REGIONS)do
                if region~="Head" and (body[region] or 0)~=0 then blocky=false end
                if region~="Head" and (body[region] or 0)~=(oldBody[region] or 0)then headOnly=false end
                if (body[region] or 0)~=(oldBody[region] or 0)then bodyChanged=true end
            end
            local previousScales=previous.definition and previous.definition.scales or {}
            local scalesChanged=not sameValue(snapshot.definition.scales or {},previousScales)
            local batched=(bodyChanged or scalesChanged) and type(entry.avatar.applyBodyParts)=="function"
            local bulk=not batched and blocky and bodyChanged and type(entry.avatar.applyBody)=="function"
            if fresh then diagnose(record.userId,"preparing_body",nil,nil,true)end
            if batched then entry.avatar.applyBodyParts(body,snapshot.definition.scales,headOnly)
            elseif bulk then entry.avatar.applyBody("Blocky")end
            if not current()then return end
            for _,region in ipairs(batched and {} or BODY_REGIONS)do
                local desired=body[region] or 0
                local changed=fresh or desired~=(oldBody[region] or 0)
                if bulk then
                    changed=region=="Head" and (desired~=0 or (humanoid and humanoid.RigType==Enum.HumanoidRigType.R6 and changed))
                end
                if changed then
                    entry.avatar.applyBodyPart(region,desired)
                    if not current()then return end
                end
            end
            if humanoid and humanoid.RigType==Enum.HumanoidRigType.R15 then
                entry.originalScales=entry.originalScales or {}
                for key,property in pairs(SCALE_VALUES)do
                    local scale=humanoid:FindFirstChild(property)
                    local desired=(snapshot.definition.scales or {})[key]
                    if scale and scale:IsA("NumberValue")then
                        if desired~=nil then
                            assert(type(desired)=="number" and desired==desired and desired>=0 and desired<=5,"Invalid shared body scale")
                            if entry.originalScales[scale]==nil then entry.originalScales[scale]=scale.Value end
                            if scale.Value~=desired then scale.Value=desired end
                        elseif entry.originalScales[scale]~=nil then
                            scale.Value=entry.originalScales[scale];entry.originalScales[scale]=nil
                        end
                    end
                end
            end
            for _,item in ipairs(snapshot.items)do
                if type(item)=="table" and safeId(item.id) and tonumber(item.assetType) then
                    local assetType=tonumber(item.assetType)
                    local changed=not oldItems[tostring(item.assetType)..":"..tostring(item.id)]
                    if ACCESSORY_TYPES[assetType] then wanted[item.id]=item
                    elseif BODY_TYPES[assetType] then -- Applied by region above, including absent/default parts.
                    elseif assetType==18 then if changed then pcall(entry.avatar.applyFace,item.id)end
                    elseif CLOTHES_TYPES[assetType]=="ShirtGraphic" then wantedClothes.ShirtGraphic=true;if changed then pcall(entry.clothes.equipTShirt,item.id)end
                    elseif CLOTHES_TYPES[assetType]=="Shirt" then wantedClothes.Shirt=true;if changed then pcall(entry.clothes.equipShirt,item.id)end
                    elseif CLOTHES_TYPES[assetType]=="Pants" then wantedClothes.Pants=true;if changed then pcall(entry.clothes.equipPants,item.id)end
                    elseif assetType==19 then
                        -- Gear equip/unequip state is not shared yet. Keep tools
                        -- local instead of showing a permanently equipped copy.
                    elseif ANIMATION_TYPES[assetType] then animationAssets[#animationAssets+1]={id=item.id,assetType=assetType}
                    end
                end
            end
            if fresh then diagnose(record.userId,"equipping_accessories",nil,nil,true)end
            if fresh or entry.refreshAccessories then entry.avatar.removeCurrentAccessories();entry.appearanceStarted=true end
            local equipped={}
            for _,item in ipairs(entry.avatar.listAccessories())do equipped[item.id]=item.key end
            local accessoryMetadata={}
            for _,asset in ipairs(snapshot.definition.assets)do accessoryMetadata[asset.id]=asset.meta end
            -- Load additions first so existing accessories remain visible while assets load.
            for id in pairs(wanted)do
                if preparationFailures[id]then
                    accessoryFailures[#accessoryFailures+1]=tostring(id)..": "..preparationFailures[id]
                elseif not equipped[id]then
                    local loaded,reason=pcall(entry.avatar.equipAccessory,id,accessoryMetadata[id])
                    if not loaded then accessoryFailures[#accessoryFailures+1]=tostring(id)..": "..tostring(reason)end
                elseif entry.avatar.setAccessoryMetadata then
                    local loaded,reason=pcall(entry.avatar.setAccessoryMetadata,equipped[id],accessoryMetadata[id])
                    if not loaded then accessoryFailures[#accessoryFailures+1]=tostring(id)..": "..tostring(reason)end
                end
                if not current()then return end
            end
            for _,item in ipairs(entry.avatar.listAccessories())do if not wanted[item.id]then pcall(entry.avatar.removeAccessory,item.key)end end
            if not wantedClothes.ShirtGraphic and (fresh or oldSlots[2])then pcall(entry.clothes.removeTShirt)end
            if not wantedClothes.Shirt and (fresh or oldSlots[11])then pcall(entry.clothes.removeShirt)end
            if not wantedClothes.Pants and (fresh or oldSlots[12])then pcall(entry.clothes.removePants)end
            local colors=snapshot.definition.bodyColors or {}
            for _,pair in ipairs(COLOR_REGIONS)do
                local value=colors[pair[2]]
                local oldColors=previous.definition and previous.definition.bodyColors or {}
                if value~=oldColors[pair[2]] and type(value)=="string" and value:match("^#?%x%x%x%x%x%x$")then
                    value=value:gsub("^#","")
                    entry.avatar.setSkin(Color3.fromRGB(tonumber(value:sub(1,2),16),tonumber(value:sub(3,4),16),tonumber(value:sub(5,6),16)),pair[1])
                end
            end
            table.sort(animationAssets,function(a,b)return a.assetType==b.assetType and a.id<b.id or a.assetType<b.assetType end)
            if not sameValue(entry.animationAssets,animationAssets)then
                if #animationAssets>0 then pcall(entry.animations.equipAssets,animationAssets)
                elseif entry.animationAssets and #entry.animationAssets>0 then pcall(entry.animations.restore)end
                entry.animationAssets=animationAssets
            end
        end)
        if ok and current() then
            -- A partial outfit must not satisfy the unchanged-record fast path.
            -- Retain loaded assets; the next record/readiness event retries only
            -- missing accessories using listAccessories above.
            entry.snapshot=snapshot
            entry.accessoriesComplete=#accessoryFailures==0
            entry.refreshAccessories=nil
            diagnose(record.userId,#accessoryFailures==0 and "applied" or "partial",table.concat(accessoryFailures,"; "),math.floor((os.clock()-applyStarted)*1000))
            entry.name=record.name;entry.imageUrl=record.imageUrl
            if presentation.createHatScripts then
                if not entry.hatScripts then entry.hatScripts=presentation.createHatScripts(target)end
                entry.hatScripts.update(record.hatScripts,record.snapshot)
            end
            observeAppearance(entry,record.userId)
            if presentation.onAppearanceApplied then presentation.onAppearanceApplied(record.userId)end
            if #accessoryFailures>0 then
                status("Could not load shared accessories for "..target.Name..": "..table.concat(accessoryFailures,"; "))
            end
        elseif not ok and current()then
            diagnose(record.userId,"failed",tostring(err))
            cleanupPeer(record.userId)
            status("Could not apply a shared appearance: "..tostring(err))
        end
    end
    local function publish(snapshot)
        snapshot=snapshot or getSnapshot()
        local settings=getNameSettings and getNameSettings() or {}
        local name={enabled=false,username="",displayName=""}
        local username,displayName=settings.username,settings.displayName
        if settings.enabled==true and type(username)=="string" and #username>=3 and #username<=20
            and username:match("^[A-Za-z0-9_]+$") and type(displayName)=="string"
            and #displayName>=1 and #displayName<=50 and not displayName:find("[%c]") then
            name={enabled=true,username=username,displayName=displayName}
        end
        local record={version=1,userId=tostring(localPlayer.UserId),snapshot=snapshot,name=name,verified=snapshot.verified==true}
        if presentation.getHatScripts then record.hatScripts=presentation.getHatScripts()end
        if presentation.getImageUrl then
            local url=presentation.getImageUrl()
            if safeImageUrl(url) then record.imageUrl=url end
        end
        if sameValue(record,lastSent)then return end
        assert(transport and transport.setSharing,"Update Larpblox Desktop and the game script to share appearances.")
        local placeId,jobId=roomContext()
        transport.setSharing({enabled=true,placeId=placeId,jobId=jobId,record=record})
        lastSent=record
    end
    local function chooseRecord(userId)
        local record=liveRecords[userId] or profileRecords[userId]
        if record then queueRecord(record)
        else latestRecords[userId]=nil;pending[userId]=false end
    end
    local function requestProfiles(userId)
        if not sharing or not presentation.fetchProfiles then return end
        if userId then profileRequests[userId]=true
        else
            for _,player in ipairs(Players:GetPlayers())do
                if player~=localPlayer then profileRequests[tostring(player.UserId)]=true end
            end
        end
        if profileQueued then return end
        profileQueued=true
        local mine=generation
        task.defer(function()
            if not sharing or generation~=mine or not isAlive()then return end
            profileQueued=false
            local ids={};for id in pairs(profileRequests)do ids[#ids+1]=id end;profileRequests={}
            for start=1,#ids,50 do
                local batch={};for i=start,math.min(start+49,#ids)do batch[#batch+1]=ids[i]end
                local ok,records=pcall(presentation.fetchProfiles,batch)
                if not sharing or generation~=mine or not isAlive()then return end
                if ok and type(records)=="table"then
                    local found={}
                    for _,record in ipairs(records)do
                        if validRecord(record)then found[record.userId]=record end
                    end
                    for _,id in ipairs(batch)do
                        profileRecords[id]=found[id]
                        if Players:GetPlayerByUserId(tonumber(id)) and not liveRecords[id]then chooseRecord(id)end
                    end
                    processPending()
                elseif not ok then status("Saved shared appearances: "..tostring(records))end
            end
        end)
    end
    processPending=function()
        if not sharing or not isAlive()then return end
        for userId in pairs(pending)do
            if not processing[userId]then
                local ticket={generation=generation}
                processing[userId]=ticket
                task.spawn(function()
                    while sharing and generation==ticket.generation and isAlive()and pending[userId]~=nil do
                        local record=pending[userId];pending[userId]=nil
                        if record==false then cleanupPeer(userId)
                        else
                            local ok,reason=pcall(applyRecord,record)
                            if not ok then status("Shared appearance: "..tostring(reason))end
                        end
                    end
                    if processing[userId]==ticket then processing[userId]=nil end
                end)
            end
        end
    end
    local function receive(event)
        if not sharing or not isAlive()or type(event)~="table"then return end
        if event.type=="status"then status(tostring(event.message));return end
        if event.type=="hat-scripts"then
            local id=event.userId
            if type(id)~="string" or id==tostring(localPlayer.UserId) or not liveRecords[id]
                or not presentation.validHatScripts or not presentation.validHatScripts(event.hatScripts)then return end
            -- This path never reloads bodies, thumbnails, or accessory models.
            liveRecords[id].hatScripts=event.hatScripts
            if latestRecords[id]then latestRecords[id].hatScripts=event.hatScripts end
            local entry=peers[id]
            if entry and entry.hatScripts and entry.character==entry.player.Character then entry.hatScripts.update(event.hatScripts)end
            return
        end
        if event.type=="snapshot"and type(event.players)=="table"then
            local seen={}
            for _,record in ipairs(event.players)do
                if validRecord(record)and record.userId~=tostring(localPlayer.UserId)then
                    seen[record.userId]=true;liveRecords[record.userId]=record;queueRecord(record)
                end
            end
            for userId in pairs(liveRecords)do if not seen[userId]then liveRecords[userId]=nil;chooseRecord(userId);requestProfiles(userId)end end
        elseif event.type=="upsert"and validRecord(event.record)then
            local record=event.record
            if record.userId~=tostring(localPlayer.UserId)then liveRecords[record.userId]=record;queueRecord(record)end
        elseif event.type=="remove"and type(event.userId)=="string"then
            local entry=peers[event.userId];if entry and entry.hatScripts then entry.hatScripts.update(nil)end
            liveRecords[event.userId]=nil;chooseRecord(event.userId);requestProfiles(event.userId)
        end
        processPending()
    end
    if transport and transport.onShared then connections[#connections+1]=transport.onShared(receive)end
    if transport and transport.onSnapshot then
        connections[#connections+1]=transport.onSnapshot(function(snapshot)
            if sharing and isAlive()then
                local ok,reason=pcall(publish,snapshot)
                if not ok then status("Shared appearance: "..tostring(reason))end
            end
        end)
    end
    if presentation.onHatScriptsChanged then
        connections[#connections+1]=presentation.onHatScriptsChanged(function()
            if sharing and isAlive()then
                local ok,reason=pcall(publish)
                if not ok then status("Shared hat effects: "..tostring(reason))end
            end
        end)
    end
    local function watchPlayer(player)
        if player==localPlayer then return end
        requestProfiles(tostring(player.UserId))
        local readinessConnections={}
        local function clearReadiness()
            for _,connection in ipairs(readinessConnections)do connection:Disconnect()end
            readinessConnections={}
        end
        local function replay()
            local key=tostring(player.UserId)
            if not latestRecords[key]then diagnose(key,"no_shared_record")end
            if latestRecords[key]then pending[key]=latestRecords[key];processPending()end
        end
        local function watchCharacter(character)
            diagnose(player.UserId,"respawn")
            clearReadiness()
            local queued=false
            local function ready()
                if queued or not appearanceReady(player,character)then return end
                queued=true
                clearReadiness()
                task.defer(replay)
            end
            local watchedHumanoid
            local function watch(object)
                if object:IsA("Humanoid") and object~=watchedHumanoid then
                    watchedHumanoid=object
                    readinessConnections[#readinessConnections+1]=object.HealthChanged:Connect(ready)
                    readinessConnections[#readinessConnections+1]=object:GetPropertyChangedSignal("RigType"):Connect(ready)
                end
                ready()
            end
            readinessConnections[#readinessConnections+1]=character.ChildAdded:Connect(watch)
            local humanoid=character:FindFirstChildOfClass("Humanoid")
            if humanoid then watch(humanoid)else ready()end
        end
        local added=player.CharacterAdded:Connect(watchCharacter)
        local removing=player.CharacterRemoving:Connect(clearReadiness)
        connections[#connections+1]=function()
            added:Disconnect();removing:Disconnect();clearReadiness()
        end
        if player.Character then watchCharacter(player.Character)end
    end
    for _,player in ipairs(Players:GetPlayers())do watchPlayer(player)end
    pcall(function()
        local added=Players.PlayerAdded:Connect(watchPlayer)
        local removed=Players.PlayerRemoving:Connect(function(player)
            local key=tostring(player.UserId);liveRecords[key]=nil;profileRecords[key]=nil;latestRecords[key]=nil;pending[key]=false;processPending()
        end)
        connections[#connections+1]=function()added:Disconnect();removed:Disconnect()end
    end)
    local api={}
    function api.setEnabled(value)
        value=value==true
        if sharing==value then return api.status()end
        generation=generation+1;lastSent=nil
        if sharing then
            sharing=false
            if transport then pcall(transport.setSharing,{enabled=false})end
            pending={};latestRecords={};liveRecords={};profileRecords={};profileRequests={};profileQueued=false;processing={};cleanupAll();status("Shared Larp mode is off.")
        elseif value then
            sharing=true
            local ok,reason=pcall(publish)
            -- Spawning or restoring an outfit can temporarily prevent a
            -- snapshot. Keep the preference and retry on the next snapshot.
            if not ok then status("Waiting to share your appearance: "..tostring(reason))
            else status("Sharing your Larp appearance through desktop.")end
            requestProfiles()
        end
        if presentation.onAppearanceApplied then presentation.onAppearanceApplied()end
        return api.status()
    end
    function api.hasSharedAppearance(userId)return sharing and latestRecords[tostring(userId)]~=nil end
    function api.corpseSource(userId)
        local entry=sharing and peers[tostring(userId)]
        if not entry or not entry.snapshot then return nil end
        local source=entry.avatar.corpseSource()
        if source then source.originalClothes=entry.clothes.corpseOriginalClothes()end
        return source
    end
    function api.isEnabled()return sharing end
    function api.status()return sharing and "Shared Larp mode: ON" or "Shared Larp mode: OFF"end
    function api.destroy()
        if sharing and transport then pcall(transport.setSharing,{enabled=false})end
        sharing=false;generation=generation+1;cleanupAll()
        for _,disconnect in ipairs(connections)do pcall(disconnect)end
        connections={};pending={};latestRecords={};liveRecords={};profileRecords={};profileRequests={};profileQueued=false;processing={}
    end
    return api
end
