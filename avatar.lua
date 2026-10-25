-- Local appearance only. No character replacement, remotes, or game detection.
local Players=game:GetService("Players")
local Http=game:GetService("HttpService")
local smokestackStates=setmetatable({}, {__mode="k"})
local smokestackDates={normal={1,1},halloween={10,22},thanksgiving={11,20},christmas={12,18},birthday={8,27},stpatricks={3,12},valentines={2,9},aprilfools={4,1}}
local function applySmokestackSeasonal(candidate,date,style)
    local state=smokestackStates[candidate]
    if not state then
        local handle=candidate:FindFirstChild("Handle")
        if not handle then return end
        local mesh=handle:FindFirstChildOfClass("SpecialMesh")
        local target=handle:IsA("MeshPart") and handle or mesh
        local property=handle:IsA("MeshPart") and "TextureID" or "TextureId"
        state={handle=handle,target=target,property=property,texture=target and target[property],transparency=handle.Transparency}
        smokestackStates[candidate]=state
        function state.cleanup()
            if state.birthday then state.birthday:Destroy();state.birthday=nil end
            if state.target then state.target[state.property]=state.texture end
            state.handle.Transparency=state.transparency
            for _,effect in ipairs(candidate:GetDescendants())do
                if effect:IsA("ParticleEmitter") then effect.Enabled=false end
            end
            smokestackStates[candidate]=nil
        end
    end
    -- Match the original hat: select the holiday when equipped, without date polling.
    local now=date or os.date("*t")
    if style and style~="auto" then
        local selected=assert(smokestackDates[style],"Invalid Smokestack hat style.")
        now={year=now.year,month=selected[1],day=selected[2]}
    end
    local month,day=now.month,now.day
    local texture,names,birthday,april
    if month==10 and day>=22 then texture="6991166143";names={Hallow=true}
    elseif month==11 and day>=20 then texture="6991393806";names={ParticleEmitter=true,Leaf1=true,Leaf2=true}
    elseif month==12 and day>=18 and day<=27 then names={Snowflake1=true,Snowflake2=true,Snowflake3=true}
    elseif month==8 and day==27 then texture="2399316028";names={Confetti=true};birthday=true
    elseif month==3 and day>=12 and day<=19 then texture="2399447918";names={ParticleEmitter=true,Clover1=true,Clover2=true}
    elseif month==2 and day>=9 and day<=16 then texture="2399448372";names={Heart=true}
    elseif month==4 and day==1 then names={Hats=true,Smokescreen=true};april=true
    end
    if state.target then state.target[state.property]=texture and "rbxassetid://"..texture or state.texture end
    state.handle.Transparency=april and 1 or state.transparency
    for _,effect in ipairs(candidate:GetDescendants())do
        if effect:IsA("ParticleEmitter") then effect.Enabled=names and names[effect.Name]==true or not names and effect.Name=="ParticleEmitter" end
    end
    if state.birthday then state.birthday:Destroy();state.birthday=nil end
    if birthday then
        local surface=Instance.new("SurfaceGui");surface.Name="LarpbloxRobloxAge";surface.CanvasSize=Vector2.new(60,50)
        surface.LightInfluence=1;surface.Parent=state.handle
        local text=Instance.new("TextLabel");text.Name="Age";text.BackgroundTransparency=1
        text.Size=UDim2.fromScale(1,1);text.TextScaled=true;text.TextColor3=Color3.fromRGB(210,45,32)
        text.Text=tostring(now.year-2006);text.Parent=surface;state.birthday=surface
    end
    return state
end
local groups={
    Head={"Head"},Torso={"Torso","UpperTorso","LowerTorso"},
    LeftArm={"Left Arm","LeftUpperArm","LeftLowerArm","LeftHand"},
    RightArm={"Right Arm","RightUpperArm","RightLowerArm","RightHand"},
    LeftLeg={"Left Leg","LeftUpperLeg","LeftLowerLeg","LeftFoot"},
    RightLeg={"Right Leg","RightUpperLeg","RightLowerLeg","RightFoot"},
}
local r15={"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand",
    "RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot",
    "RightUpperLeg","RightLowerLeg","RightFoot"}
local scaleFields={height="BodyHeightScale",width="BodyWidthScale",depth="BodyDepthScale",head="HeadScale",bodyType="BodyTypeScale",proportion="BodyProportionScale"}
local descriptionScales={height="HeightScale",width="WidthScale",depth="DepthScale",head="HeadScale",bodyType="BodyTypeScale",proportion="ProportionScale"}
local function nativeSourceSignature(outfit)
    -- Arrays keep this key stable across JSON decode/table insertion order.
    -- Include the data consumed by the native descriptor, not UI labels or
    -- body colors (painted separately on the live mapped parts).
    local metadata,key={},{}
    for _,asset in ipairs(outfit.definition.assets or {})do metadata[asset.id]=asset.meta end
    for _,item in ipairs(outfit.items)do
        local meta=metadata[item.id]
        key[#key+1]={item.id,item.assetType,meta and meta.order or "",meta and meta.puffiness or ""}
    end
    local scales={}
    for _,name in ipairs({"height","width","depth","head","bodyType","proportion"})do
        local value=outfit.definition.scales and outfit.definition.scales[name]
        if value==nil then value=(name=="bodyType" or name=="proportion") and 0 or 1 end
        scales[#scales+1]=value
    end
    key[#key+1]=scales
    return Http:JSONEncode(key)
end
local function validScales(values)
    if type(values)~="table" then return false end
    for key,value in pairs(values)do
        if not scaleFields[key] or type(value)~="number" or value~=value or value<0 or value>5 then return false end
    end
    return true
end
local accessoryKinds={[8]="Hat",[41]="Hair",[42]="Face",[43]="Neck",[44]="Shoulder",[45]="Front",[46]="Back",[47]="Waist",[64]="TShirt",[65]="Shirt",[66]="Pants",[67]="Jacket",[68]="Sweater",[69]="Shorts",[70]="LeftShoe",[71]="RightShoe",[72]="DressSkirt",[76]="Eyebrow",[77]="Eyelash"}
local validAccessoryKinds={};for _,kind in pairs(accessoryKinds)do validAccessoryKinds[kind]=true end
local outfits={Girl=131929545,["Robloxian 2.0"]=131929576}
local function accessoryMeta(value)
    if value==nil then return nil end
    assert(type(value)=="table","Invalid accessory adjustments.")
    local result={}
    for _,field in ipairs({"scale","position","rotation"})do
        if value[field]~=nil then
            assert(type(value[field])=="table","Invalid accessory "..field..".")
            local vector={}
            for _,axis in ipairs({"X","Y","Z"})do
                local n=value[field][axis]
                local limit=field=="rotation" and 360 or (field=="position" and 10 or 5)
                assert(type(n)=="number" and n==n and math.abs(n)<=limit and (field~="scale" or n>0),"Invalid accessory "..field..".")
                vector[axis]=n
            end
            result[field]=vector
        end
    end
    for _,field in ipairs({"order","puffiness","version"})do
        local n=value[field]
        if type(n)=="number" and n==n and math.abs(n)<=1000 then result[field]=n end
    end
    if value.smokestackStyle~=nil then
        assert(type(value.smokestackStyle)=="string" and (value.smokestackStyle=="auto" or smokestackDates[value.smokestackStyle]),"Invalid Smokestack hat style.")
        result.smokestackStyle=value.smokestackStyle
    end
    return next(result) and result or nil
end
local function sameMeta(a,b)
    if (a and a.smokestackStyle or "auto")~=(b and b.smokestackStyle or "auto")then return false end
    for _,field in ipairs({"scale","position","rotation"})do
        for _,axis in ipairs({"X","Y","Z"})do
            if (a and a[field] and a[field][axis])~=(b and b[field] and b[field][axis])then return false end
        end
    end
    for _,field in ipairs({"order","puffiness","version"})do if (a and a[field])~=(b and b[field])then return false end end
    return true
end
local azurelightAccessoryId=14565851673
local bodyRegions={Head=true,Torso=true,LeftArm=true,RightArm=true,LeftLeg=true,RightLeg=true}
local r6BodyPartNames={Head="Head",Torso="Torso",LeftArm="LeftArm",RightArm="RightArm",LeftLeg="LeftLeg",RightLeg="RightLeg"}
local function regionNames(region)
    if region=="Head" then return {"Head"} end
    local names=groups[region];local out={}
    for i=2,#names do out[#out+1]=names[i] end
    return out
end
local function idFrom(value,kind)
    if type(value)=="number" then
        assert(value>0 and value%1==0 and value<9007199254740992,"Enter a positive numeric ID.")
        return value
    end
    value=tostring(value or ""):match("^%s*(.-)%s*$")
    local id=value:match("^(%d+)$")
    if not id then
        local path=value:match("^https?://www%.roblox%.com/(.+)$") or value:match("^https?://roblox%.com/(.+)$")
        if path then id=path:match("^"..kind.."/(%d+)") end
    end
    if kind=="catalog" and not id then id=value:match("^rbxassetid://(%d+)$") end
    local number=tonumber(id)
    assert(number and number>0 and number<9007199254740992,"Paste a Roblox "..kind.." link or a positive numeric ID.")
    return number
end
local function strip(root)
    for _,item in ipairs(root:GetDescendants()) do if item:IsA("LuaSourceContainer") then item:Destroy() end end
end
local function dispose(list)
    for _,item in ipairs(list) do item:Destroy() end
end
local function bodyClone(part)
    local clone=part:Clone()
    assert(clone,"This avatar's body cannot be copied.")
    strip(clone)
    for _,item in ipairs(clone:GetDescendants()) do if item:IsA("JointInstance") then item:Destroy() end end
    return clone
end
return function(player,onStatus,readAsset,managedRespawn,diagnostics,createMapping)
    local function nativeCall(operation,callback,...)
        if diagnostics and diagnostics.run then
            return diagnostics.run(operation,{peerId=player.UserId},callback,...)
        end
        return callback(...)
    end
    local mapping=createMapping and createMapping(player)
    local alive,generation=true,0
    local nativeSource,nativeContainer,nativeDescription,nativeSourceKey,nativeSourceRig,nativePreparation
    local nativeAccessories={}
    local nativeSourceGeneration=0
    local function clearNativeSource()
        nativeSourceGeneration=nativeSourceGeneration+1
        if nativeDescription then nativeDescription:Destroy();nativeDescription=nil end
        if nativeContainer then nativeContainer:Destroy();nativeContainer=nil
        elseif nativeSource then nativeSource:Destroy()end
        nativeSource=nil;nativeSourceKey=nil;nativeSourceRig=nil;nativeAccessories={}
    end
    local snapshot,added,skin,hidden=nil,{},{},{}
    local gear=nil
    local accountAccessoryNames
    local retiredAccessories={}
    local nextKey=0
    local playerGui=player:FindFirstChildOfClass("PlayerGui")
    local attribute="HoneyBunCosmeticSettings"
    local settings={accessoryKinds={},accessories={},colors={},bodyParts={},hideOriginals=false,gear=nil}
    local reapplying,replayGeneration,replayToken=false,nil,0
    local appearanceVersion=0
    local function copySettings()
        local copy={accessoryKinds=table.clone(settings.accessoryKinds),accessories={},colors={},bodyParts={},hideOriginals=settings.hideOriginals,body=settings.body,gear=settings.gear,face=settings.face}
        if settings.scales then copy.scales=table.clone(settings.scales) end
        copy.accessoryMeta={}
        for id,meta in pairs(settings.accessoryMeta or {})do copy.accessoryMeta[id]=accessoryMeta(meta)end
        for i,id in ipairs(settings.accessories) do copy.accessories[i]=id end
        for region,color in pairs(settings.colors) do copy.colors[region]={color[1],color[2],color[3]} end
        for region,value in pairs(settings.bodyParts) do copy.bodyParts[region]=value end
        if type(settings.gear)=="table" then copy.gear={id=settings.gear.id,name=settings.gear.name} end
        return copy
    end
    if playerGui then
        local ok,saved=pcall(function()
            local value=playerGui:GetAttribute(attribute)
            return value and Http:JSONDecode(value)
        end)
        if ok and type(saved)=="table" then
            if type(saved.face)=="number" and saved.face>0 and saved.face%1==0 and saved.face<9007199254740992 then settings.face=saved.face end
            if validScales(saved.scales) then settings.scales=table.clone(saved.scales) end
            settings.accessoryMeta={}
            settings.hideOriginals=saved.hideOriginals==true
            if type(saved.body)=="string" then settings.body=saved.body end
            if type(saved.bodyParts)=="table" then
                for region,value in pairs(saved.bodyParts) do
                    if bodyRegions[region] and ((type(value)=="number" and value>=0 and value%1==0 and value<9007199254740992)
                        or (type(value)=="string" and #value<=8192)) then settings.bodyParts[region]=value end
                end
            end
            if type(saved.accessories)=="table" then
                for _,id in ipairs(saved.accessories) do
                    if type(id)=="number" and id>0 and id%1==0 and id<9007199254740992 and #settings.accessories<512 then
                        table.insert(settings.accessories,id)
                        local kind=type(saved.accessoryKinds)=="table" and saved.accessoryKinds[tostring(id)]
                        if validAccessoryKinds[kind]then settings.accessoryKinds[tostring(id)]=kind end
                        local ok,meta=pcall(accessoryMeta,type(saved.accessoryMeta)=="table" and saved.accessoryMeta[tostring(id)] or nil)
                        if ok then settings.accessoryMeta[tostring(id)]=meta end
                    end
                end
            end
            if type(saved.gear)=="table" and type(saved.gear.id)=="number" and saved.gear.id>0 and saved.gear.id%1==0 and saved.gear.id<9007199254740992 then
                settings.gear={id=saved.gear.id,name=type(saved.gear.name)=="string" and saved.gear.name or tostring(saved.gear.id)}
            end
            if type(saved.colors)=="table" then
                for region,color in pairs(saved.colors) do
                    if (region=="All" or groups[region]) and type(color)=="table" then
                        local validColor=true
                        for i=1,3 do if type(color[i])~="number" or color[i]~=color[i] or color[i]<0 or color[i]>1 then validColor=false end end
                        if validColor then settings.colors[region]={color[1],color[2],color[3]} end
                    end
                end
            end
        end
    end
    local function save()
        if reapplying or not playerGui then return end
        playerGui:SetAttribute(attribute,Http:JSONEncode(settings))
    end
    local function notify(message,working)
        if alive and onStatus then onStatus(message,working) end
    end
    local function context()
        assert(alive,"The cosmetic menu was closed.")
        local c=player.Character
        local humanoid=c and c:FindFirstChildOfClass("Humanoid")
        assert(c and humanoid and humanoid.Health>0,"Wait for your avatar to finish spawning.")
        return {character=c,humanoid=humanoid,generation=generation}
    end
    local function valid(ctx)
        return alive and generation==ctx.generation and player.Character==ctx.character
            and ctx.humanoid.Parent==ctx.character and ctx.humanoid.Health>0
    end
    local function check(ctx)
        assert(valid(ctx),"Your avatar changed while loading. Try again on the new character.")
    end
    local function showOriginalAccessories()
        if mapping then mapping.restore("accessories");hidden={};return end
        for _,entry in ipairs(hidden) do
            for part,properties in pairs(entry.parts) do
                for property,value in pairs(properties) do pcall(function() part[property]=value end) end
            end
        end
        hidden={}
    end
    local function forget(preserveCharacter)
        if preserveCharacter and snapshot and snapshot.character~=player.Character and #hidden>0 then
            local character=snapshot.character
            local record={hidden=hidden,added=added}
            retiredAccessories[character]=record
            record.connection=character.Destroying:Connect(function()
                retiredAccessories[character]=nil
                record.connection:Disconnect()
            end)
            hidden={}
        else showOriginalAccessories()end
        if snapshot then
            dispose(snapshot.meshes)
            if snapshot.r6Head then snapshot.r6Head:Destroy() end
            dispose(snapshot.face or {})
            for _,part in pairs(snapshot.parts) do part:Destroy() end
        end
        snapshot=nil;added={};skin={};hidden={};gear=nil
    end
    local function capture(ctx,body)
        if not snapshot then
            local saved={character=ctx.character,colors={},bodyColors={},meshes={},parts={},bodyChanged=false}
            if ctx.humanoid.RigType==Enum.HumanoidRigType.R15 then
                saved.automaticScaling=ctx.humanoid.AutomaticScalingEnabled
            end
            for _,item in ipairs(ctx.character:GetChildren()) do
                if item:IsA("BasePart") and item.Name~="HumanoidRootPart" then
                    saved.colors[item.Name]=item.Color
                elseif item:IsA("CharacterMesh") then table.insert(saved.meshes,item:Clone())
                elseif item:IsA("BodyColors") then
                    saved.hadBodyColors=true
                    for region in pairs(groups) do saved.bodyColors[region]=item[region.."Color3"] end
                end
            end
            if ctx.humanoid.RigType==Enum.HumanoidRigType.R6 then
                local head=ctx.character:FindFirstChild("Head")
                if head and head:IsA("BasePart") then saved.r6Head=bodyClone(head) end
            end
            saved.scales={}
            for _,name in pairs(scaleFields)do
                local value=ctx.humanoid:FindFirstChild(name)
                if value and value:IsA("NumberValue") then saved.scales[name]=value.Value end
            end
            snapshot=saved
        end
        if body and ctx.humanoid.RigType==Enum.HumanoidRigType.R15 and not next(snapshot.parts) then
            local copies={}
            local ok,message=pcall(function()
                for _,name in ipairs(r15) do
                    local part=ctx.character:FindFirstChild(name)
                    assert(part and part:IsA("BasePart"),"This character does not use a standard R15 body.")
                    copies[name]=bodyClone(part)
                end
                local root=ctx.character:FindFirstChild("HumanoidRootPart")
                assert(root and root:IsA("BasePart"),"This character has no R15 root part.")
                copies.HumanoidRootPart=bodyClone(root)
            end)
            if not ok then for _,part in pairs(copies) do part:Destroy() end;error(message) end
            snapshot.parts=copies
            snapshot.joints={}
            local bodyParts={[ctx.character:FindFirstChild("HumanoidRootPart") or ctx.character]=true}
            for _,name in ipairs(r15) do bodyParts[ctx.character:FindFirstChild(name)]=true end
            for _,joint in ipairs(ctx.character:GetDescendants()) do
                if joint:IsA("Motor6D") and bodyParts[joint.Part0] and bodyParts[joint.Part1] then
                    snapshot.joints[joint]={C0=joint.C0,C1=joint.C1}
                end
            end
            snapshot.hipHeight=ctx.humanoid.HipHeight
        end
    end
    local function freezeBodyScaling(ctx)
        if ctx.humanoid.RigType==Enum.HumanoidRigType.R15 and snapshot then
            if snapshot.automaticScaling==nil then snapshot.automaticScaling=ctx.humanoid.AutomaticScalingEnabled end
            ctx.humanoid.AutomaticScalingEnabled=false
        end
    end
    local function restoreBodyScaling(ctx)
        if snapshot and snapshot.character==ctx.character and snapshot.automaticScaling~=nil then
            ctx.humanoid.AutomaticScalingEnabled=snapshot.automaticScaling
            snapshot.automaticScaling=nil
        end
    end
    local bodyPartSource
    local function resolvedBodyParts(ctx)
        if not next(settings.bodyParts) then return nil end
        local description=ctx.humanoid:GetAppliedDescription()
        local result={Head=description.Head or 0,Torso=description.Torso or 0,LeftArm=description.LeftArm or 0,
            RightArm=description.RightArm or 0,LeftLeg=description.LeftLeg or 0,RightLeg=description.RightLeg or 0}
        description:Destroy()
        for _,region in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"})do
            local value=settings.bodyParts[region]
            if value~=nil then
                if type(value)~="number" then
                    local template,remember,id=bodyPartSource(ctx,region,value)
                    remember();template:Destroy();value=id
                end
                result[region]=value
            end
        end
        return result
    end
    local function paint(c,color,region)
        local colors=c:FindFirstChildOfClass("BodyColors")
        if not colors then
            colors=Instance.new("BodyColors")
            for group,names in pairs(groups) do
                for _,name in ipairs(names) do
                    local part=c:FindFirstChild(name)
                    if part and part:IsA("BasePart") then colors[group.."Color3"]=part.Color;break end
                end
            end
            colors.Parent=c
        end
        for group,names in pairs(groups) do
            if region=="All" or region==group then
                colors[group.."Color3"]=color
                for _,name in ipairs(names) do
                    local part=c:FindFirstChild(name)
                    if part and part:IsA("BasePart") then part.Color=color end
                end
            end
        end
    end
    local function attach(accessory,c,refit)
        local handle=accessory:FindFirstChild("Handle")
        assert(handle and handle:IsA("BasePart"),"This accessory has no wearable Handle.")
        if accessory:FindFirstChildWhichIsA("WrapLayer",true) then
            local humanoid=c:FindFirstChildOfClass("Humanoid")
            assert(humanoid and humanoid.RigType==Enum.HumanoidRigType.R15,"Layered clothing needs an R15 avatar.")
            nativeCall("Humanoid.AddAccessory",function()humanoid:AddAccessory(accessory)end)
            assert(accessory.Parent==c,"Roblox could not attach this layered accessory.")
            return
        end
        -- Let Roblox apply its accessory fitting/scaling rules before using
        -- the client-side weld fallback. A raw catalog handle is not fitted.
        if accessory:IsA("Accessory") and not refit then
            local humanoid=c:FindFirstChildOfClass("Humanoid")
            if humanoid then
                local ok=pcall(function()nativeCall("Humanoid.AddAccessory",humanoid.AddAccessory,humanoid,accessory)end)
                if ok then
                    for _,joint in ipairs(handle:GetChildren())do
                        if joint:IsA("JointInstance") and
                            ((joint.Part0==handle and joint.Part1 and joint.Part1:IsDescendantOf(c))
                                or (joint.Part1==handle and joint.Part0 and joint.Part0:IsDescendantOf(c)))then return end
                    end
                end
            end
        end
        local target,bodyAttachment,handleAttachment
        for _,a in ipairs(handle:GetChildren()) do
            if a:IsA("Attachment") then
                for _,part in ipairs(c:GetChildren()) do
                    if part:IsA("BasePart") and part.Name~="HumanoidRootPart" then
                        local b=part:FindFirstChild(a.Name)
                        if b and b:IsA("Attachment") then target,bodyAttachment,handleAttachment=part,b,a;break end
                    end
                end
            end
            if target then break end
        end
        local c0,c1
        if target then c0,c1=handleAttachment.CFrame,bodyAttachment.CFrame
        else
            assert(not handle:FindFirstChildWhichIsA("Attachment"),"This accessory has no matching attachment on your avatar.")
            target=c:FindFirstChild("Head")
            assert(target,"This avatar has no Head for a legacy hat.")
            c0,c1=accessory.AttachmentPoint,CFrame.new(0,0.5,0)
        end
        for _,item in ipairs(handle:GetChildren()) do
            if item:IsA("JointInstance") or item:IsA("WeldConstraint") then item:Destroy() end
        end
        handle.CFrame=target.CFrame*c1*c0:Inverse()
        local weld=Instance.new("Weld")
        weld.Name,weld.Part0,weld.Part1="AccessoryWeld",handle,target
        weld.C0,weld.C1=c0,c1
        weld.Parent=handle
    end
    local function isBodyVisualEffect(item)
        return item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail")
            or item:IsA("Light") or item:IsA("Fire") or item:IsA("Smoke") or item:IsA("Sparkles")
    end
    local function syncValueChild(target,source,name)
        local existing=target:FindFirstChild(name)
        local incoming=source:FindFirstChild(name)
        if existing and incoming and existing.ClassName==incoming.ClassName and incoming:IsA("ValueBase") then
            if existing.Value~=incoming.Value then existing.Value=incoming.Value end
            return
        end
        if existing then existing:Destroy()end
        if incoming then incoming:Clone().Parent=target end
    end
    local function applyPartAppearance(target,source)
        if target:IsA("MeshPart") and source:IsA("MeshPart") then
            nativeCall("MeshPart.ApplyMesh",function()target:ApplyMesh(source)end)
            if source.Size then target.Size=source.Size end
        elseif target:IsA("Part") and (source:IsA("Part") or source:IsA("MeshPart")) then
            local prepared={}
            if source:IsA("MeshPart") then
                local bounds=source.MeshSize
                assert(bounds and bounds.X>0 and bounds.Y>0 and bounds.Z>0,"This head has no usable mesh dimensions.")
                local mesh=Instance.new("SpecialMesh")
                mesh.MeshType=Enum.MeshType.FileMesh;mesh.MeshId=source.MeshId;mesh.TextureId=source.TextureID
                local size=source.Size or target.Size
                mesh.Scale=Vector3.new(size.X/bounds.X,size.Y/bounds.Y,size.Z/bounds.Z)
                prepared[1]=mesh
            else
                for _,item in ipairs(source:GetChildren()) do if item:IsA("SpecialMesh") then prepared[#prepared+1]=item:Clone() end end
            end
            for _,item in ipairs(target:GetChildren()) do if item:IsA("SpecialMesh") then item:Destroy() end end
            for _,item in ipairs(prepared) do item.Parent=target end
            if source.Size then target.Size=source.Size end
            if source:IsA("Part") then target.Shape=source.Shape end
        else
            error("This body part cannot be changed safely on this avatar. Your gear was left alone.")
        end
        -- Size and its native baseline belong to the same body asset. Leaving
        -- the previous package's baseline makes later native rescaling distort it.
        for _,name in ipairs({"OriginalSize","AvatarPartScaleType"})do
            syncValueChild(target,source,name)
        end
        -- ApplyMesh does not copy SurfaceAppearance. Packages can texture any
        -- limb this way, so replace the surface even when the new body has none.
        for _,item in ipairs(target:GetChildren()) do
            if item:IsA("SurfaceAppearance") then item:Destroy() end
        end
        for _,item in ipairs(source:GetChildren()) do
            if item:IsA("SurfaceAppearance") then
                if target:IsA("MeshPart") then item:Clone().Parent=target
                else
                    local mesh=target:FindFirstChildOfClass("SpecialMesh")
                    if mesh then mesh.TextureId=tostring(item.ColorMap) end
                end
            end
        end
        -- Replace modern heads' face children too when changing or restoring.
        if target.Name=="Head" then
            for _,item in ipairs(target:GetChildren()) do
                if item:IsA("Decal") or item:IsA("FaceControls") or item:IsA("Bone") then item:Destroy() end
            end
            for _,item in ipairs(source:GetChildren()) do
                if item:IsA("Decal") or (target:IsA("MeshPart") and (item:IsA("FaceControls") or item:IsA("Bone"))) then
                    item:Clone().Parent=target
                end
            end
        end
        if source.Transparency~=nil then target.Transparency=source.Transparency end
        -- Layered clothing deforms against the body's WrapTarget cage. Body
        -- part visual updates must carry that cage along with the mesh.
        for _,child in ipairs(target:GetChildren()) do
            if child:IsA("WrapTarget") then child:Destroy() end
        end
        for _,child in ipairs(source:GetChildren()) do
            if child:IsA("WrapTarget") then child:Clone().Parent=target end
        end
        for _,attachment in ipairs(source:GetChildren()) do
            if attachment:IsA("Attachment") then
                local existing=target:FindFirstChild(attachment.Name)
                if existing and existing:IsA("Attachment") then
                    existing.CFrame=attachment.CFrame
                    syncValueChild(existing,attachment,"OriginalPosition")
                elseif not existing then
                    -- Generated body parts also carry hat/hair/face attachment
                    -- points. Preserve those when the replicated part is early.
                    attachment:Clone().Parent=target
                end
            end
        end
        -- Body assets can carry visual effects on the part or its attachments.
        -- Replace that appearance state with the incoming asset so old flames
        -- cannot survive a body swap; the snapshot restores them on unequip.
        for _,item in ipairs(target:GetDescendants()) do
            if isBodyVisualEffect(item) then item:Destroy() end
        end
        local function liveEffectParent(node)
            if node==source then return target end
            if not node then return nil end
            local parent=liveEffectParent(node.Parent)
            return parent and parent:FindFirstChild(node.Name)
        end
        for _,item in ipairs(source:GetDescendants()) do
            if isBodyVisualEffect(item) then
                local parent=liveEffectParent(item.Parent)
                if parent then
                    local copy=item:Clone()
                    if item:IsA("Beam") or item:IsA("Trail") then
                        for _,field in ipairs({"Attachment0","Attachment1"}) do
                            copy[field]=liveEffectParent(item[field])
                        end
                    end
                    copy.Parent=parent
                end
            end
        end
    end
    local function fitBodyJoints(ctx,names)
        local bodyParts,affected={},{}
        for _,name in ipairs(names) do affected[ctx.character:FindFirstChild(name)]=true end
        for _,name in ipairs(r15) do bodyParts[ctx.character:FindFirstChild(name) or ctx.character]=true end
        bodyParts[ctx.character:FindFirstChild("HumanoidRootPart") or ctx.character]=true
        for _,joint in ipairs(ctx.character:GetDescendants()) do
            if joint:IsA("Motor6D") and bodyParts[joint.Part0] and bodyParts[joint.Part1] and (affected[joint.Part0] or affected[joint.Part1]) then
                local attachmentName=(joint.Name=="RootJoint" and "Root" or joint.Name).."RigAttachment"
                for _,attachment in ipairs(joint.Part0:GetChildren()) do
                    if attachment:IsA("Attachment") and attachment.Name==attachmentName then
                        local other=joint.Part1:FindFirstChild(attachment.Name)
                        if other and other:IsA("Attachment") then
                            joint.C0,joint.C1=attachment.CFrame,other.CFrame
                            break
                        end
                    end
                end
            end
        end
    end
    local function replaceParts(ctx,parts,names)
        if not names then
            names=table.clone(r15)
            -- A generated rig's hip height assumes its root size and root
            -- attachment offset. Keep the live root, but fit it with the body.
            if parts.HumanoidRootPart then table.insert(names,"HumanoidRootPart") end
        end
        for _,name in ipairs(names) do
            local target=ctx.character:FindFirstChild(name)
            assert(parts[name] and parts[name]:IsA("BasePart") and target and target:IsA("BasePart"),"This package does not contain the selected R15 body part.")
        end
        if mapping then mapping.body(ctx,parts,names);return end
        local backups,changed,joints={},{},{}
        for _,joint in ipairs(ctx.character:GetDescendants()) do
            if joint:IsA("Motor6D") then joints[joint]={C0=joint.C0,C1=joint.C1} end
        end
        for _,name in ipairs(names) do backups[name]=bodyClone(ctx.character:FindFirstChild(name)) end
        -- Keep native scaling from resizing mapped meshes using the original package.
        local automaticScaling
        if ctx.humanoid and ctx.humanoid.RigType==Enum.HumanoidRigType.R15 then
            automaticScaling=ctx.humanoid.AutomaticScalingEnabled
            if snapshot and snapshot.automaticScaling==nil then snapshot.automaticScaling=automaticScaling end
            ctx.humanoid.AutomaticScalingEnabled=false
        end
        local ok,err=pcall(function()
            for _,name in ipairs(names) do
                local target=ctx.character:FindFirstChild(name)
                -- Keep the actual limb, attachments, RightGrip, and game controllers.
                -- ApplyMesh changes appearance without destroying the gear-holding part.
                table.insert(changed,name)
                local success,message=pcall(applyPartAppearance,target,parts[name])
                if not success then error("Roblox blocked changing "..name.." safely: "..tostring(message)) end
            end
            fitBodyJoints(ctx,names)
        end)
        if not ok then
            for i=#changed,1,-1 do
                local name=changed[i]
                local target=ctx.character:FindFirstChild(name)
                pcall(applyPartAppearance,target,backups[name])
            end
            for joint,offset in pairs(joints) do joint.C0,joint.C1=offset.C0,offset.C1 end
        end
        if not ok and automaticScaling~=nil then ctx.humanoid.AutomaticScalingEnabled=automaticScaling end
        for _,part in pairs(backups) do part:Destroy() end
        assert(ok,err)
    end
    local function refitAccessories(ctx)
        if mapping then
            for _,entry in ipairs(added)do if entry.object.Parent==ctx.character then mapping.fitAccessory(ctx,entry.object)end end
            return
        end
        -- Body replacements keep live limbs, so Roblox does not rerun its
        -- accessory fitting pass. Rebuild classic welds against new frames;
        -- layered clothing remains owned by Roblox.
        for _,entry in ipairs(added) do
            local accessory=entry.object
            if accessory.Parent==ctx.character and not accessory:FindFirstChildWhichIsA("WrapLayer",true) then
                attach(accessory,ctx.character,true)
            end
        end
    end
    local function restoreBodyParts(ctx)
        replaceParts(ctx,snapshot.parts)
        refitAccessories(ctx)
        for joint,offset in pairs(snapshot.joints or {}) do
            if joint.Parent then joint.C0,joint.C1=offset.C0,offset.C1 end
        end
        if snapshot.hipHeight~=nil then ctx.humanoid.HipHeight=snapshot.hipHeight end
    end
    local function r6MeshPart(mesh)
        local value=tostring(mesh.BodyPart or "")
        return value:match("([%w]+)$")
    end
    local function r6MeshesFor(region,list)
        local wanted=r6BodyPartNames[region];local found={}
        for _,mesh in ipairs(list or {}) do
            if mesh:IsA("CharacterMesh") and r6MeshPart(mesh)==wanted then found[#found+1]=mesh end
        end
        return found
    end
    local function removeR6RegionMeshes(ctx,region)
        for _,item in ipairs(ctx.character:GetChildren()) do
            if item:IsA("CharacterMesh") and r6MeshPart(item)==r6BodyPartNames[region] then item:Destroy() end
        end
    end
    local function restoreR6Region(ctx,region)
        if region=="Head" and snapshot and snapshot.r6Head then
            local head=ctx.character:FindFirstChild("Head")
            if head and head:IsA("BasePart") then applyPartAppearance(head,snapshot.r6Head) end
            return
        end
        removeR6RegionMeshes(ctx,region)
        for _,mesh in ipairs(r6MeshesFor(region,snapshot and snapshot.meshes)) do mesh:Clone().Parent=ctx.character end
    end
    local wearableTemplates,wearableOrder={},{}
    local function wearable(ctx,id,kind,prepareOnly)
        -- The complete native source already contains Roblox's fitted accessory.
        -- Keep the bundled visual-effects override on its existing path.
        local prepared=kind=="Accessory" and id~=azurelightAccessoryId and nativeAccessories[id]
        if prepared then return prepareOnly and prepared or prepared:Clone()end
        local key=kind..":"..string.format("%.0f",id)
        local cached=wearableTemplates[key]
        if cached then return prepareOnly and cached or cached:Clone() end
        local ok,objects=pcall(function()
            if kind=="Accessory" and id==azurelightAccessoryId then
                assert(type(readAsset)=="function","Dominus Azurelight's visual effects need local asset loading support in this executor.")
                return readAsset("assets/dominus-azurelight.rbxm")
            end
            if type(readAsset)=="function"then return readAsset(id)end
            return game:GetObjects("rbxassetid://"..string.format("%.0f",id))
        end)
        assert(ok and type(objects)=="table" and #objects>0,"Roblox could not load that "..kind:lower()..". It may be private or unavailable.")
        if not valid(ctx)then dispose(objects);check(ctx)end
        local function matches(item)return item:IsA(kind) or (kind=="Accessory" and item:IsA("Hat"))end
        local source
        for _,root in ipairs(objects)do
            strip(root)
            if matches(root)then source=root;break end
            for _,item in ipairs(root:GetDescendants())do if matches(item)then source=item;break end end
            if source then break end
        end
        if not source then dispose(objects);error("That catalog item is not a wearable "..kind:lower()..".")end
        local template=source:Clone();dispose(objects)
        local handle=template:FindFirstChild("Handle")
        if not handle or not handle:IsA("BasePart")then template:Destroy();error("That item has no usable Handle.")end
        -- Some executors return catalog MeshParts as unit Parts/SpecialMeshes.
        -- Restore the native mesh bounds once, before caching, so AddAccessory
        -- can fit the handle using Roblox's own scaling and attachment logic.
        local mesh=handle:IsA("Part") and handle:FindFirstChildOfClass("SpecialMesh")
        if kind=="Accessory" and mesh and mesh.MeshType==Enum.MeshType.FileMesh
            and mesh.MeshId~="" and mesh.Offset==Vector3.zero
            and not template:FindFirstChildWhichIsA("WrapLayer",true)then
            local converted,native=pcall(function()
                local content=Content and Content.fromUri and Content.fromUri(mesh.MeshId) or mesh.MeshId
                return nativeCall("AssetService.CreateMeshPartAsync",function()return game:GetService("AssetService"):CreateMeshPartAsync(content,{})end)
            end)
            if not valid(ctx)then
                if converted and native then native:Destroy()end
                template:Destroy();check(ctx)
            end
            if converted and native and native:IsA("MeshPart")then
                native.Name=handle.Name;native.CFrame=handle.CFrame
                native.Size=native.Size*mesh.Scale;native.TextureID=mesh.TextureId
                native.Color=Color3.new(handle.Color.R*mesh.VertexColor.X,handle.Color.G*mesh.VertexColor.Y,handle.Color.B*mesh.VertexColor.Z)
                native.Material=handle.Material;native.Transparency=handle.Transparency
                native.Reflectance=handle.Reflectance
                for name,value in pairs(handle:GetAttributes())do native:SetAttribute(name,value)end
                for _,child in ipairs(handle:GetChildren())do
                    if child~=mesh and not child:IsA("JointInstance") and not child:IsA("WeldConstraint")then child:Clone().Parent=native end
                end
                local original=native:FindFirstChild("OriginalSize")
                if not original then original=Instance.new("Vector3Value");original.Name="OriginalSize";original.Parent=native end
                if original:IsA("Vector3Value")then original.Value=native.Size end
                native.Parent=template;handle:Destroy();handle=native
            end
        end
        -- Let Roblox stream textures on attachment; waiting here serializes
        -- every accessory behind the slowest texture in the previous one.
        if not valid(ctx)then template:Destroy();check(ctx)end
        wearableTemplates[key]=template;wearableOrder[#wearableOrder+1]=key
        if #wearableOrder>32 then
            local oldest=table.remove(wearableOrder,1)
            wearableTemplates[oldest]:Destroy();wearableTemplates[oldest]=nil
        end
        return prepareOnly and template or template:Clone()
    end
    local function bunnyExplosion(ctx,candidate)
        -- Recreate the old BootScript's explosion visually; never run asset scripts.
        task.delay(5,function()
            if not alive or not valid(ctx) or candidate.Parent~=ctx.character then return end
            local handle=candidate:FindFirstChild("Handle")
            if not handle then return end
            local explosion=Instance.new("Explosion")
            explosion.BlastRadius=32
            explosion.BlastPressure=0
            explosion.DestroyJointRadiusPercent=0
            explosion.ExplosionType=Enum.ExplosionType.NoCraters
            explosion.Position=handle.Position
            explosion.Parent=workspace
            game:GetService("Debris"):AddItem(explosion,3)
        end)
    end
    local api={}
    local preparedWearables=setmetatable({}, {__mode="k"})
    function api.prepareAppearance(outfit,describe,isCurrent)
        local ctx=context()
        if isCurrent and not isCurrent()then return end
        if nativePreparation then
            nativePreparation.Event:Wait();check(ctx)
            return api.prepareAppearance(outfit,describe,isCurrent)
        end
        -- This source supplies meshes, fitting metadata and accessories only.
        -- Live body colors are mapped by setSkin; rebuilding/preloading the
        -- source for a color-only edit does not contribute to that mapping.
        local key=nativeSourceSignature(outfit)
        if nativeSourceKey==key and nativeSourceRig==ctx.humanoid.RigType then return end
        if nativeSource and nativeSourceRig~=ctx.humanoid.RigType then clearNativeSource()end
        nativeSourceKey=nil;nativeAccessories={}
        if nativeDescription then nativeDescription:Destroy();nativeDescription=nil end
        local description=describe(outfit)
        description.UseAvatarSettings=true
        local sourceGeneration=nativeSourceGeneration
        local function checkSource()
            check(ctx)
            assert(nativeSourceGeneration==sourceGeneration,"Avatar source was released while preparing.")
        end
        local completed=Instance.new("BindableEvent");nativePreparation=completed
        local ok,err=pcall(function()
            if nativeSource then
                nativeCall("Humanoid.ApplyDescriptionAsync.source",function()
                    nativeSource:FindFirstChildOfClass("Humanoid"):ApplyDescriptionAsync(description)
                end)
            else
                nativeSource=nativeCall("Players.CreateHumanoidModelFromDescriptionAsync.source",function()
                    return Players:CreateHumanoidModelFromDescriptionAsync(description,ctx.humanoid.RigType)
                end)
                if not valid(ctx) or nativeSourceGeneration~=sourceGeneration then
                    nativeSource:Destroy();nativeSource=nil;checkSource()
                end
                -- Native incremental application requires a DataModel ancestor.
                -- This locally owned source never enters Workspace or PlayerGui.
                strip(nativeSource)
                nativeContainer=Instance.new("Folder");nativeContainer.Name="LarpbloxAvatarSource"
                nativeSource.Parent=nativeContainer
                nativeContainer.Parent=game:GetService("ReplicatedStorage")
                nativeSourceRig=ctx.humanoid.RigType
            end
            checkSource()
            strip(nativeSource)
            nativeCall("ContentProvider.PreloadAsync.source",function()
                game:GetService("ContentProvider"):PreloadAsync({nativeSource})
            end)
            checkSource()
            if isCurrent and not isCurrent()then clearNativeSource();return end
            local applied=nativeSource:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("HumanoidDescription")
            if applied then for _,child in ipairs(applied:GetChildren())do
                if child:IsA("AccessoryDescription")then
                    local resolved,accessory=pcall(function()return child:GetAppliedInstance()end)
                    if resolved and accessory and accessory.Parent==nativeSource then
                        nativeAccessories[child.AssetId]=accessory
                        preparedWearables[accessory]=true
                    end
                end
            end end
            nativeDescription=description:Clone();nativeSourceKey=key
        end)
        description:Destroy()
        if not ok then clearNativeSource()end
        nativePreparation=nil;completed:Fire();task.defer(function()completed:Destroy()end)
        if not ok then error(err,0)end
    end
    function api.releasePreparedAppearance()clearNativeSource()end
    if mapping then function api.resolveClothes(kind,id)
        local field=({Shirt="Shirt",Pants="Pants",ShirtGraphic="GraphicTShirt"})[kind]
        local prepared=nativeSource and nativeDescription and nativeDescription.UseAvatarSettings and nativeDescription[field]==id and nativeSource or nil
        local original,replacement=mapping.clothingTemplates(context(),kind,id,prepared)
        return original,replacement,mapping.projectClothing,mapping.clothingSource
    end end
    function api.prepareAccessories(ids,isCurrent)
        local ctx=context()
        local failures,preload={},{}
        for _,id in ipairs(ids)do
            if isCurrent and not isCurrent()then return failures end
            local ok,reason=pcall(wearable,ctx,idFrom(id,"catalog"),"Accessory",true)
            check(ctx)
            if not ok then failures[id]=tostring(reason)
            elseif not preparedWearables[reason]then preload[#preload+1]=reason end
        end
        if #preload>0 then
            if isCurrent and not isCurrent()then return failures end
            nativeCall("ContentProvider.PreloadAsync",function()return game:GetService("ContentProvider"):PreloadAsync(preload)end)
            check(ctx)
            for _,template in ipairs(preload)do preparedWearables[template]=true end
        end
        return failures
    end
    local function adjustAccessory(entry,meta)
        local handle=entry.object:FindFirstChild("Handle")
        assert(handle and handle:IsA("BasePart"),"This accessory has no Handle.")
        if entry.object:FindFirstChildWhichIsA("WrapLayer",true)then return end
        local baseline=entry.adjustmentBaseline
        if not baseline and not meta and not mapping then return end
        if not baseline then
            baseline={size=handle.Size,attachments={},meshes={}}
            local geometry=handle:IsA("MeshPart")and handle or handle:FindFirstChildOfClass("SpecialMesh")
            if geometry then baseline.meshId=geometry.MeshId end
            local original=handle:FindFirstChild("OriginalSize")
            if original and original:IsA("Vector3Value")then baseline.originalSize=original.Value end
            baseline.originalPositions={}
            for _,child in ipairs(handle:GetChildren())do
                if child:IsA("Attachment")then
                    baseline.attachments[child]=child.CFrame
                    local position=child:FindFirstChild("OriginalPosition")
                    if position and position:IsA("Vector3Value")then baseline.originalPositions[position]=position.Value end
                elseif child:IsA("SpecialMesh")then baseline.meshes[child]={scale=child.Scale,offset=child.Offset}
                elseif child:IsA("JointInstance") and child.Part0==handle then baseline.joint=child;baseline.c0=child.C0 end
            end
            entry.adjustmentBaseline=baseline
        end
        local function vector(field,default)
            local v=meta and meta[field]
            return v and Vector3.new(v.X,v.Y,v.Z) or default
        end
        local writes={}
        local function write(object,property,source,value)
            if mapping then writes[#writes+1]={object=object,property=property,baseline=source,desired=value}
            else object[property]=value end
        end
        local scale=vector("scale",Vector3.one)
        write(handle,"Size",baseline.size,baseline.size*scale)
        local original=handle:FindFirstChild("OriginalSize")
        if baseline.originalSize and original and original:IsA("Vector3Value")then write(original,"Value",baseline.originalSize,baseline.originalSize*scale)end
        for position,value in pairs(baseline.originalPositions)do write(position,"Value",value,value*scale)end
        for mesh,original in pairs(baseline.meshes)do write(mesh,"Scale",original.scale,original.scale*scale);write(mesh,"Offset",original.offset,original.offset*scale)end
        for attachment,frame in pairs(baseline.attachments)do write(attachment,"CFrame",frame,CFrame.new(frame.Position*scale)*frame.Rotation)end
        local joint=baseline.joint
        if joint and joint.Parent then
            local bodyScale=Vector3.one
            local humanoid=entry.object.Parent and entry.object.Parent:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.RigType==Enum.HumanoidRigType.R15 then
                local function number(name)local n=humanoid:FindFirstChild(name);return n and n.Value or 1 end
                bodyScale=joint.Part1 and joint.Part1.Name=="Head" and Vector3.one*number("HeadScale")
                    or Vector3.new(number("BodyWidthScale"),number("BodyHeightScale"),number("BodyDepthScale"))
            end
            local rotation=vector("rotation",Vector3.zero)*math.pi/180
            local adjustment=CFrame.new(vector("position",Vector3.zero)*bodyScale)*CFrame.Angles(rotation.X,rotation.Y,rotation.Z)
            write(joint,"C0",baseline.c0,(CFrame.new(baseline.c0.Position*scale)*baseline.c0.Rotation)*adjustment:Inverse())
        end
        if mapping then
            local geometry=handle:IsA("MeshPart")and handle or handle:FindFirstChildOfClass("SpecialMesh")
            mapping.adjustments(context(),writes,geometry,baseline.meshId)
        end
    end
    function api.equipAccessory(value,metadata,assetType)
        local ctx=context()
        local id=idFrom(value,"catalog")
        local meta=accessoryMeta(metadata)
        assert(not (meta and meta.smokestackStyle) or id==169444515,"This hat does not support Smokestack styles.")
        local candidate=wearable(ctx,id,"Accessory")
        local function accessoryKind(object)
            local ok,kind=pcall(function()return object.AccessoryType.Name end)
            return ok and kind~="Unknown" and kind or "Hat"
        end
        local kind=accessoryKinds[assetType] or settings.accessoryKinds[tostring(id)] or accessoryKind(candidate)
        local count=0
        for _,entry in ipairs(added)do if (entry.kind or accessoryKind(entry.object))==kind then count=count+1 end end
        if count>=20 then candidate:Destroy();error("You can wear at most 20 "..kind.." accessories at once.")end
        strip(candidate)
        if mapping and not mapping.allowAccessory(ctx,candidate,id)then
            candidate:Destroy()
            if not reapplying then
                if not table.find(settings.accessories,id)then table.insert(settings.accessories,id)end
                settings.accessoryMeta=settings.accessoryMeta or {};settings.accessoryMeta[tostring(id)]=meta;save()
            end
            return "Accessory selection saved; this game's avatar settings exclude it."
        end
        -- The original Dusekkar script gates these existing effects to user 916.
        if id==1474657 then
            for _,effect in ipairs(candidate:GetDescendants()) do
                if effect:IsA("Fire") or effect:IsA("Smoke") then effect.Enabled=true end
            end
        elseif id==169444515 then
            -- Use the original everyday smoke, not the scripted holiday emitters.
            local handle=candidate:FindFirstChild("Handle")
            local attachment=handle and handle:FindFirstChild("HatAttachment")
            local smoke=attachment and attachment:FindFirstChild("ParticleEmitter")
            if smoke and smoke:IsA("ParticleEmitter") then smoke.Enabled=true end
        end
        for _,item in ipairs(candidate:GetDescendants()) do
            if item:IsA("BasePart") then item.Anchored=false;item.CanCollide=false;item.CanTouch=false;item.Massless=true end
        end
        local fitted,message=pcall(attach,candidate,ctx.character)
        if not fitted then candidate:Destroy();error(message) end
        capture(ctx)
        candidate.Parent=ctx.character
        local seasonal=id==169444515 and applySmokestackSeasonal(candidate,nil,meta and meta.smokestackStyle) or nil
        nextKey=nextKey+1
        local entry={key=nextKey,id=id,name=candidate.Name,object=candidate,meta=meta,kind=kind,seasonal=seasonal}
        adjustAccessory(entry,meta)
        table.insert(added,entry)
        if mapping then mapping.accessory(ctx,candidate,id)end
        if id==1527622 then bunnyExplosion(ctx,candidate) end
        if not reapplying then
            table.insert(settings.accessories,id)
            settings.accessoryKinds[tostring(id)]=kind
            settings.accessoryMeta=settings.accessoryMeta or {};settings.accessoryMeta[tostring(id)]=meta;save()
        end
        return "Equipped "..candidate.Name.." (visible to you)."
    end
    function api.setAccessoryMetadata(key,metadata)
        local meta=accessoryMeta(metadata)
        for _,entry in ipairs(added)do
            if entry.key==key then
                assert(not (meta and meta.smokestackStyle) or entry.id==169444515,"This hat does not support Smokestack styles.")
                if sameMeta(entry.meta,meta)then return end
                if not mapping or entry.object.Parent==player.Character then adjustAccessory(entry,meta)end
                entry.meta=meta
                if entry.id==169444515 and (not mapping or entry.object.Parent==player.Character)then entry.seasonal=applySmokestackSeasonal(entry.object,nil,meta and meta.smokestackStyle)end
                settings.accessoryMeta=settings.accessoryMeta or {};settings.accessoryMeta[tostring(entry.id)]=meta;save()
                return
            end
        end
    end
    function api.equipGear(value)
        error("Larpblox gear is temporarily disabled while equip state synchronization is fixed.")
        local ctx=context();local id=idFrom(value,"catalog")
        local candidate=wearable(ctx,id,"Tool")
        local handle=candidate:FindFirstChild("Handle")
        if not handle or not handle:IsA("BasePart") then candidate:Destroy();error("That gear has no usable Handle.") end
        strip(candidate)
        capture(ctx)
        for _,item in ipairs(candidate:GetDescendants()) do
            if item:IsA("BasePart") then item.Anchored=false;item.CanCollide=false;item.CanTouch=false;item.Massless=true end
        end
        local hand=ctx.character:FindFirstChild("RightHand") or ctx.character:FindFirstChild("Right Arm")
        if not hand or not hand:IsA("BasePart") then candidate:Destroy();error("This avatar has no right hand for gear.") end
        local handGrip=hand:FindFirstChild("RightGripAttachment")
        local toolGrip=candidate.Grip or CFrame.new()
        local handAnchor=handGrip and handGrip.CFrame or CFrame.new(0,-1,0)
        local handleTarget=hand.CFrame*handAnchor*toolGrip:Inverse()
        local handleRelative={}
        for _,item in ipairs(candidate:GetDescendants()) do
            if item:IsA("BasePart") and item~=handle then handleRelative[item]=handle.CFrame:ToObjectSpace(item.CFrame) end
        end
        local attached,message=pcall(function()
            candidate:SetAttribute("LarpbloxHubGear",true);candidate.Parent=ctx.character
            handle.CFrame=handleTarget
            for part,relative in pairs(handleRelative) do part.CFrame=handleTarget*relative end
            local weld=Instance.new("Weld");weld.Name="LarpbloxGearWeld";weld.Part0=handle;weld.Part1=hand;weld.C0=CFrame.new();weld.C1=hand.CFrame:ToObjectSpace(handleTarget);weld.Parent=handle
            for part in pairs(handleRelative) do
                local brace=Instance.new("WeldConstraint");brace.Name="LarpbloxGearPartWeld";brace.Part0=handle;brace.Part1=part;brace.Parent=handle
            end
        end)
        if not attached then candidate:Destroy();error(message) end
        if gear and gear.object then gear.object:Destroy() end
        gear={id=id,name=candidate.Name,object=candidate}
        if not reapplying then settings.gear={id=id,name=candidate.Name};save() end
        return "Equipped "..candidate.Name.." gear (visible to you)."
    end
    function api.listGear()
        if gear and gear.object and gear.object.Parent==player.Character then return {{id=gear.id,name=gear.name}} end
        return {}
    end
    function api.removeGear()
        if not gear then return "No gear added by this hub is equipped." end
        local name=gear.name;gear.object:Destroy();gear=nil
        if not reapplying then settings.gear=nil;save() end
        return "Removed "..name.." gear."
    end
    function api.listAccessories()
        local list={}
        for _,entry in ipairs(added) do
            if entry.object.Parent==player.Character then table.insert(list,{key=entry.key,id=entry.id,name=entry.name,meta=accessoryMeta(entry.meta)}) end
        end
        return list
    end
    function api.removeAccessory(key)
        for i,entry in ipairs(added) do
            if entry.key==key then
                if entry.seasonal then entry.seasonal.cleanup() end
                entry.object:Destroy();table.remove(added,i)
                if not reapplying then
                    if settings.accessoryMeta then settings.accessoryMeta[tostring(entry.id)]=nil end
                    for index,id in ipairs(settings.accessories) do if id==entry.id then table.remove(settings.accessories,index);break end end
                    save()
                end
                return "Removed "..entry.name.."."
            end
        end
        error("That added accessory is no longer equipped.")
    end
    local function clearAdded()
        for _,entry in ipairs(added) do if entry.seasonal then entry.seasonal.cleanup() end;entry.object:Destroy() end
        added={}
    end
    local function clearGear()
        if gear and gear.object then gear.object:Destroy() end
        gear=nil
    end
    function api.clearAccessories()
        clearAdded()
        if not reapplying then settings.accessories={};settings.accessoryMeta={};save() end
        return "Removed accessories added by this hub."
    end
    local function attachedToAvatar(item,c)
        local handle=item:FindFirstChild("Handle")
        if not handle or not handle:IsA("BasePart") then return false end
        local attachmentParts={
            HatAttachment={"Head"},HairAttachment={"Head"},FaceFrontAttachment={"Head"},FaceCenterAttachment={"Head"},
            NeckAttachment={"UpperTorso","Torso"},BodyBackAttachment={"UpperTorso","Torso"},BodyFrontAttachment={"UpperTorso","Torso"},
            LeftCollarAttachment={"UpperTorso","Torso"},RightCollarAttachment={"UpperTorso","Torso"},
            LeftShoulderAttachment={"LeftUpperArm","Left Arm"},RightShoulderAttachment={"RightUpperArm","Right Arm"},
            WaistFrontAttachment={"LowerTorso","Torso"},WaistCenterAttachment={"LowerTorso","Torso"},WaistBackAttachment={"LowerTorso","Torso"},
        }
        for _,child in ipairs(handle:GetChildren()) do
            if child:IsA("Attachment") then
                for _,name in ipairs(attachmentParts[child.Name] or {}) do
                    local part=c:FindFirstChild(name)
                    local matching=part and part:IsA("BasePart") and part:FindFirstChild(child.Name)
                    if matching and matching:IsA("Attachment") then return true end
                end
            elseif child:IsA("JointInstance") and child.Name=="AccessoryWeld" then
                local head=c:FindFirstChild("Head")
                if head and ((child.Part0==handle and child.Part1==head) or (child.Part1==handle and child.Part0==head)) then return true end
            end
        end
        return false
    end
    function api.removeCurrentAccessories()
        local ctx=context()
        capture(ctx)
        if mapping then
            mapping.hideAccessories(ctx)
            if not reapplying then settings.hideOriginals=true;save()end
            return "Original avatar accessories mapped (visible to you)."
        end
        local hubAdded={}
        for _,entry in ipairs(added) do hubAdded[entry.object]=true end
        local avatarIds,avatarInstances={},{}
        local liveDescription=ctx.humanoid:FindFirstChildOfClass("HumanoidDescription")
        if liveDescription then
            for _,entry in ipairs(liveDescription:GetChildren()) do
                if entry:IsA("AccessoryDescription") then
                    local found,instance=pcall(function() return entry:GetAppliedInstance() end)
                    if found and instance and instance.Parent==ctx.character then avatarInstances[instance]=true end
                end
            end
        end
        local ok,description=pcall(function() return ctx.humanoid:GetAppliedDescription() end)
        if ok and description then
            local read,entries=pcall(function() return description:GetAccessories(true) end)
            if read then for _,entry in ipairs(entries) do avatarIds[entry.AssetId]=true end end
            description:Destroy()
        end
        -- Some games omit applied accessory instances, and SourceAssetId is restricted.
        -- Use trusted account accessory names as a fallback, never arbitrary game gear.
        if not accountAccessoryNames and type(player.UserId)=="number" then
            local loaded,appearance=pcall(function() return Players:GetCharacterAppearanceInfoAsync(player.UserId) end)
            check(ctx)
            if loaded and type(appearance)=="table" and type(appearance.assets)=="table" then
                accountAccessoryNames={}
                local types={[8]=true,[41]=true,[42]=true,[43]=true,[44]=true,[45]=true,[46]=true,[47]=true,[76]=true,[77]=true}
                for _,asset in ipairs(appearance.assets) do
                    if type(asset)=="table" and type(asset.assetType)=="table" and types[asset.assetType.id] and type(asset.name)=="string" then
                        accountAccessoryNames[asset.name]=true
                    end
                end
            end
        end
        local alreadyHidden={}
        for _,entry in ipairs(hidden) do alreadyHidden[entry.object]=true end
        for _,item in ipairs(ctx.character:GetChildren()) do
            local identified,id=pcall(function() return item.SourceAssetId end)
            if (item:IsA("Accessory") or item:IsA("Hat")) and not hubAdded[item] and not alreadyHidden[item] and (avatarInstances[item] or (identified and avatarIds[id]) or (accountAccessoryNames and accountAccessoryNames[item.Name]) or attachedToAvatar(item,ctx.character)) then
                local entry={object=item,parts={}}
                for _,part in ipairs(item:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
                        entry.parts[part]={Transparency=part.Transparency or 0};part.Transparency=1
                    elseif part:IsA("ParticleEmitter") or part:IsA("Beam") or part:IsA("Trail") or part:IsA("Light") or part:IsA("Fire") or part:IsA("Smoke") or part:IsA("Sparkles") then
                        entry.parts[part]={Enabled=part.Enabled==true};part.Enabled=false
                    end
                end
                table.insert(hidden,entry)
            end
        end
        -- Repeated clicks also re-hide originals if the game changed their visibility.
        for _,entry in ipairs(hidden) do
            for part,properties in pairs(entry.parts) do
                pcall(function()
                    if properties.Transparency~=nil then part.Transparency=1 end
                    if properties.Enabled~=nil then part.Enabled=false end
                end)
            end
        end
        if not reapplying then settings.hideOriginals=true;save() end
        return #hidden==0 and "No identified Roblox avatar accessories to hide. Game equipment was left alone." or "Hidden "..#hidden.." Roblox accessories. Restore original appearance brings them back."
    end
    function api.accessoryReport()
        local ctx=context()
        local lines={"Larpblox accessory report","Build: avatar attachment detection V3","Hide originals saved: "..tostring(settings.hideOriginals),"Tracked hidden accessories: "..#hidden}
        local owned={};for _,entry in ipairs(added) do owned[entry.object]=true end
        for _,item in ipairs(ctx.character:GetChildren()) do
            if item:IsA("Accessory") or item:IsA("Hat") then
                local details={item.Name.." ["..item.ClassName.."]", "hub="..tostring(owned[item]==true),"avatar match="..tostring(attachedToAvatar(item,ctx.character))}
                local handle=item:FindFirstChild("Handle")
                if handle then
                    details[#details+1]="transparency="..tostring(handle.Transparency)
                    for _,child in ipairs(handle:GetChildren()) do
                        if child:IsA("Attachment") then details[#details+1]="attachment="..child.Name end
                    end
                else details[#details+1]="Handle missing" end
                lines[#lines+1]=table.concat(details,"; ")
            end
        end
        return table.concat(lines,"\n")
    end
    function api.setScales(values)
        assert(validScales(values),"Invalid avatar proportions.")
        local ctx=context()
        if ctx.humanoid.RigType~=Enum.HumanoidRigType.R15 then return "Avatar proportions require R15." end
        for key in pairs(values)do
            local value=ctx.humanoid:FindFirstChild(scaleFields[key])
            assert(value and value:IsA("NumberValue"),"This character does not support avatar proportions.")
        end
        capture(ctx,true)
        if mapping then mapping.scales(ctx,values)
        else for key,value in pairs(values)do ctx.humanoid[scaleFields[key]].Value=value end end
        settings.scales=table.clone(values);save()
        if not mapping and snapshot and snapshot.bodyChanged and not reapplying then
            if settings.body then
                api.applyBody(settings.body)
            else
                local body=resolvedBodyParts(ctx)
                if body then api.applyBodyParts(body,values,false) else freezeBodyScaling(ctx) end
            end
        end
        return "Avatar proportions applied."
    end
    function api.setSkin(color,region)
        local ctx=context();region=region or "All"
        assert(region=="All" or groups[region],"Choose a body region.")
        capture(ctx)
        if region=="All" then skin={} end
        skin[region]=color
        if mapping then mapping.skin(ctx,color,region)else paint(ctx.character,color,region)end
        if not reapplying then
            if region=="All" then settings.colors={} end
            settings.colors[region]={color.R,color.G,color.B};save()
        end
        return "Skin color applied (visible to you)."
    end
    function api.setSkinColors(values)
        local ctx=context()
        for region,color in pairs(values)do assert(groups[region]and typeof(color)=="Color3","Invalid avatar color.")end
        capture(ctx)
        if mapping then mapping.skinColors(ctx,values)
        else for region,color in pairs(values)do paint(ctx.character,color,region)end end
        for region,color in pairs(values)do
            skin[region]=color
            settings.colors[region]={color.R,color.G,color.B}
        end
        save();return "Skin colors applied (visible to you)."
    end
    local fullBodyTemplates,fullBodyOrder={},{}
    local function cacheBody(key,template)
        local existing=fullBodyTemplates[key]
        if existing then template:Destroy();return existing end
        fullBodyTemplates[key]=template
        fullBodyOrder[#fullBodyOrder+1]=key
        -- Switching back to a recent outfit should not regenerate its rig.
        if #fullBodyOrder>4 then
            local oldest=table.remove(fullBodyOrder,1)
            fullBodyTemplates[oldest]:Destroy();fullBodyTemplates[oldest]=nil
        end
        return template
    end
    local function bodySource(ctx,value)
        local isR6=ctx.humanoid.RigType==Enum.HumanoidRigType.R6
        local scaleKey={}
        for _,key in ipairs({"height","width","depth","head","bodyType","proportion"})do
            scaleKey[#scaleKey+1]=tostring((settings.scales or {})[key] or "")
        end
        local cacheKey=tostring(ctx.humanoid.RigType)..":"..tostring(value)..":"..table.concat(scaleKey,",")
        if fullBodyTemplates[cacheKey]then return fullBodyTemplates[cacheKey]:Clone()end
        local outfit=outfits[value]
        if value~="Blocky" and not outfit then
            local id=idFrom(value,"bundles")
            local ok,bundle=pcall(function()
                return Http:JSONDecode(game:HttpGet("https://catalog.roblox.com/v1/bundles/"..string.format("%.0f",id).."/details",false))
            end)
            check(ctx)
            assert(ok and type(bundle)=="table" and type(bundle.items)=="table","Roblox could not read that body bundle.")
            for _,item in ipairs(bundle.items) do if item.type=="UserOutfit" then outfit=tonumber(item.id);break end end
            assert(outfit,"That bundle has no avatar body outfit. Choose a character body bundle.")
        end
        local description=Instance.new("HumanoidDescription")
        if outfit then
            local ok,source=pcall(function() return Players:GetHumanoidDescriptionFromOutfitIdAsync(outfit) end)
            if not valid(ctx) then description:Destroy();if ok and source then source:Destroy() end;check(ctx) end
            if not ok or not source then description:Destroy();error("Roblox could not load this package's body description.") end
            for _,name in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"}) do description[name]=source[name] end
            -- R6 has no live NumberValue scale controls. Keep its native body
            -- fields intact instead of asking Roblox to normalize R15 scales
            -- into an R6 description.
            if ctx.humanoid.RigType==Enum.HumanoidRigType.R15 then
                description.BodyTypeScale=source.BodyTypeScale
                description.ProportionScale=source.ProportionScale
            end
            source:Destroy()
        end
        if not isR6 then for key,field in pairs(descriptionScales)do
            local value=settings.scales and settings.scales[key]
            if value~=nil then description[field]=value end
        end end
        description.UseAvatarSettings=true
        local ok,template=pcall(function() return nativeCall("Players.CreateHumanoidModelFromDescriptionAsync",function()return Players:CreateHumanoidModelFromDescriptionAsync(description,ctx.humanoid.RigType)end) end)
        description:Destroy()
        if not valid(ctx) then if ok and template then template:Destroy() end;check(ctx) end
        assert(ok and template,"Roblox blocked generating this body package in this client.")
        strip(template)
        nativeCall("ContentProvider.PreloadAsync",function()return game:GetService("ContentProvider"):PreloadAsync({template})end)
        check(ctx)
        cacheBody(cacheKey,template:Clone())
        return template
    end
    -- Complete shared outfits already include validated region IDs. Generate
    -- their body once instead of generating a full rig separately for each limb.
    local function prepareBodyParts(ctx,parts,scales)
        assert(type(parts)=="table","Body parts are required.")
        assert(scales==nil or validScales(scales),"Invalid body scales.")
        if nativeSource and nativeDescription and nativeSourceRig==ctx.humanoid.RigType then
            local matches=true
            for region in pairs(groups)do
                if nativeDescription[region]~=(parts[region] or 0)then matches=false;break end
            end
            if ctx.humanoid.RigType==Enum.HumanoidRigType.R15 then
                for key,field in pairs(descriptionScales)do
                    local value=scales and scales[key]
                    if value==nil then value=(key=="bodyType" or key=="proportion") and 0 or 1 end
                    if math.abs(nativeDescription[field]-value)>0.000001 then matches=false;break end
                end
            end
            if matches then return nativeSource end
        end
        local description=Instance.new("HumanoidDescription")
        local key={"shared",tostring(ctx.humanoid.RigType)}
        for _,region in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"})do
            local id=parts[region] or 0
            assert(type(id)=="number" and id>=0 and id%1==0 and id<9007199254740992,"Invalid body part.")
            description[region]=id;key[#key+1]=tostring(id)
        end
        local supportsScales=ctx.humanoid.RigType==Enum.HumanoidRigType.R15
        for _,name in ipairs({"height","width","depth","head","bodyType","proportion"})do
            local value=supportsScales and scales and scales[name] or nil
            if value~=nil then description[descriptionScales[name]]=value end
            key[#key+1]=tostring(value or "")
        end
        local cacheKey=table.concat(key,":")
        local cached=fullBodyTemplates[cacheKey]
        description.UseAvatarSettings=true
        local ok,template=pcall(function()
            return cached or nativeCall("Players.CreateHumanoidModelFromDescriptionAsync",function()return Players:CreateHumanoidModelFromDescriptionAsync(description,ctx.humanoid.RigType)end)
        end)
        description:Destroy()
        if not valid(ctx) then if ok and template and not cached then template:Destroy()end;check(ctx)end
        assert(ok and template,"Roblox blocked generating the shared body.")
        if not cached then
            strip(template)
            local loaded,reason=pcall(function()nativeCall("ContentProvider.PreloadAsync",function()return game:GetService("ContentProvider"):PreloadAsync({template})end)end)
            if not loaded or not valid(ctx)then template:Destroy();check(ctx);error(reason)end
        end
        if not cached then
            template=cacheBody(cacheKey,template)
        end
        return template
    end
    function api.prepareBodyParts(parts,scales)
        prepareBodyParts(context(),parts,scales)
    end
    function api.applyBodyParts(parts,scales,headOnly)
        local ctx=context()
        local template=prepareBodyParts(ctx,parts,scales)
        local applied,message=pcall(function()
            capture(ctx,true)
            if mapping and ctx.humanoid.RigType==Enum.HumanoidRigType.R6 then
                mapping.r6(ctx,template)
            elseif ctx.humanoid.RigType==Enum.HumanoidRigType.R6 then
                for _,item in ipairs(ctx.character:GetChildren())do if item:IsA("CharacterMesh")then item:Destroy()end end
                for _,item in ipairs(template:GetChildren())do if item:IsA("CharacterMesh")then item:Clone().Parent=ctx.character end end
                applyPartAppearance(ctx.character:FindFirstChild("Head"),template:FindFirstChild("Head"))
            else
                local generated={}
                for _,name in ipairs(r15)do generated[name]=template:FindFirstChild(name)end
                generated.HumanoidRootPart=template:FindFirstChild("HumanoidRootPart")
                -- A head-only mapping leaves limb assets and proportions
                -- unchanged. Still carry the native root/hip-height pair.
                replaceParts(ctx,generated,headOnly and {"Head","HumanoidRootPart"} or nil)
                refitAccessories(ctx)
                local humanoid=template:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    if mapping then mapping.hip(ctx,humanoid.HipHeight)else ctx.humanoid.HipHeight=humanoid.HipHeight end
                end
                if not mapping then freezeBodyScaling(ctx)end
            end
            snapshot.bodyChanged=true
        end)
        assert(applied,message)
        if not reapplying then
            settings.body=nil;settings.bodyParts={}
            for _,region in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"})do settings.bodyParts[region]=parts[region] or 0 end
            save()
        end
        return "Shared body applied (visible to you)."
    end
    function api.applyBody(value)
        local ctx=context()
        local isR6=ctx.humanoid.RigType==Enum.HumanoidRigType.R6
        if value=="Blocky" and isR6 and not mapping then
            capture(ctx)
            for _,item in ipairs(ctx.character:GetChildren()) do if item:IsA("CharacterMesh") then item:Destroy() end end
            snapshot.bodyChanged=true
            if not reapplying then settings.body=value;save() end
            return "Blocky body applied (visible to you)."
        end
        local template=bodySource(ctx,value)
        local applied,message=pcall(function()
            if mapping and isR6 then
                capture(ctx);mapping.r6(ctx,template)
            elseif isR6 then
                local meshes={}
                for _,item in ipairs(template:GetChildren()) do if item:IsA("CharacterMesh") then table.insert(meshes,item) end end
                assert(#meshes>0,"This package has no compatible R6 body meshes. Try an R15 game.")
                capture(ctx)
                for _,item in ipairs(ctx.character:GetChildren()) do if item:IsA("CharacterMesh") then item:Destroy() end end
                for _,mesh in ipairs(meshes) do mesh:Clone().Parent=ctx.character end
            else
                local parts={}
                for _,name in ipairs(r15) do
                    local part=template:FindFirstChild(name)
                    if part and part:IsA("BasePart") then parts[name]=part end
                end
                parts.HumanoidRootPart=template:FindFirstChild("HumanoidRootPart")
                capture(ctx,true)
                replaceParts(ctx,parts)
                refitAccessories(ctx)
                local generatedHumanoid=template:FindFirstChildOfClass("Humanoid")
                if generatedHumanoid and generatedHumanoid.HipHeight~=nil then
                    if mapping then mapping.hip(ctx,generatedHumanoid.HipHeight)else ctx.humanoid.HipHeight=generatedHumanoid.HipHeight end
                end
                if not mapping then freezeBodyScaling(ctx)end
            end
            snapshot.bodyChanged=true
            if not mapping then
                if skin.All then paint(ctx.character,skin.All,"All") end
                for region,color in pairs(skin) do if region~="All" then paint(ctx.character,color,region) end end
            end
        end)
        template:Destroy()
        assert(applied,message)
        if not reapplying then settings.body=value;settings.bodyParts={};save() end
        return "Body package applied (visible to you)."
    end
    local bodyPartTemplates,bodyPartOrder={},{}
    bodyPartSource=function(ctx,region,value)
        assert(bodyRegions[region],"Choose a body region.")
        local isR6=ctx.humanoid.RigType==Enum.HumanoidRigType.R6
        local field=region;local names=regionNames(region)
        local text=tostring(value or ""):match("^%s*(.-)%s*$")
        local isBundle=text:match("^https?://[^/]+/bundles/%d+") ~= nil
        local scaleKey={}
        for _,key in ipairs({"height","width","depth","head","bodyType","proportion"})do scaleKey[#scaleKey+1]=tostring((settings.scales or {})[key] or "")end
        local cacheKey=tostring(ctx.humanoid.RigType)..":"..region..":"..text..":"..table.concat(scaleKey,",")
        local cached=bodyPartTemplates[cacheKey]
        local id=cached and cached.id
        local isDefault=text=="0"
        if not isBundle and not cached then id=isDefault and 0 or idFrom(value,"catalog") end
        if cached then
            -- Reuse only a successfully applied and validated source model.
        elseif isBundle then
            local bundleId=idFrom(text,"bundles")
            local ok,bundle=pcall(function()
                return Http:JSONDecode(game:HttpGet("https://catalog.roblox.com/v1/bundles/"..string.format("%.0f",bundleId).."/details",false))
            end)
            check(ctx)
            assert(ok and type(bundle)=="table" and type(bundle.items)=="table","Roblox could not read that body bundle.")
            assert(bundle.bundleType=="BodyParts" or bundle.bundleType=="DynamicHead","Choose a body or head bundle, rather than an animation bundle.")
            local outfit
            for _,item in ipairs(bundle.items) do
                if item.type=="UserOutfit" and tonumber(item.id) then outfit=tonumber(item.id);break end
            end
            assert(outfit,"That bundle does not contain a usable body outfit.")
            local loaded,source=pcall(function() return Players:GetHumanoidDescriptionFromOutfitIdAsync(outfit) end)
            if not valid(ctx) then if loaded and source then source:Destroy() end;check(ctx) end
            assert(loaded and source,"Roblox could not load that body bundle.")
            local selected=source[field]
            source:Destroy()
            assert(type(selected)=="number" and selected>0,"That bundle has no selected "..region..".")
            id=selected
        elseif not isDefault and settings.bodyParts[region]~=value then
            local service=game:GetService("MarketplaceService")
            local ok,info=pcall(function() return service:GetProductInfoAsync(id,Enum.InfoType.Asset) end)
            check(ctx)
            assert(ok and type(info)=="table" and info.AssetTypeId, "Roblox could not validate "..region.." ("..tostring(id)..").")
            local expected={Head={[17]=true,[79]=true},Torso={[27]=true},RightArm={[28]=true},LeftArm={[29]=true},LeftLeg={[30]=true},RightLeg={[31]=true}}
            assert(expected[region][info.AssetTypeId],"That catalog item is not a "..region.." body part.")
        end
        local ok,template
        if cached then ok,template=pcall(function()return cached.model:Clone()end)
        else
            local description=Instance.new("HumanoidDescription");description[field]=id
            for key,value in pairs(settings.scales or {})do description[descriptionScales[key]]=value end
            description.UseAvatarSettings=true
            ok,template=pcall(function()return nativeCall("Players.CreateHumanoidModelFromDescriptionAsync",function()return Players:CreateHumanoidModelFromDescriptionAsync(description,ctx.humanoid.RigType)end)end)
            description:Destroy()
        end
        if not valid(ctx) then if ok and template then template:Destroy() end;check(ctx) end
        assert(ok and template,"Roblox blocked generating that body part.")
        strip(template)
        local function remember()
            if cached then return end
            nativeCall("ContentProvider.PreloadAsync",function()return game:GetService("ContentProvider"):PreloadAsync({template})end)
            check(ctx)
            bodyPartTemplates[cacheKey]={id=id,model=template:Clone()}
            bodyPartOrder[#bodyPartOrder+1]=cacheKey
            if #bodyPartOrder>12 then
                local old=table.remove(bodyPartOrder,1)
                bodyPartTemplates[old].model:Destroy();bodyPartTemplates[old]=nil
            end
        end
        return template,remember,id
    end
    function api.applyBodyPart(region,value)
        local ctx=context()
        local isR6=ctx.humanoid.RigType==Enum.HumanoidRigType.R6
        local names=regionNames(region)
        local isDefault=tostring(value):match("^%s*(.-)%s*$")=="0"
        local template,remember=bodyPartSource(ctx,region,value)
        remember()
        if isR6 then
            local applied,message=pcall(function()
                capture(ctx)
                if mapping then mapping.r6(ctx,template,region)
                elseif isDefault then
                    removeR6RegionMeshes(ctx,region)
                elseif region=="Head" then
                    local source=template:FindFirstChild("Head")
                    local target=ctx.character:FindFirstChild("Head")
                    assert(source and source:IsA("BasePart") and target and target:IsA("BasePart"),"That package has no compatible R6 head.")
                    applyPartAppearance(target,source)
                else
                    local meshes=r6MeshesFor(region,template:GetChildren())
                    assert(#meshes>0,"That package has no compatible R6 "..region.." body mesh. Try an R15 game.")
                    removeR6RegionMeshes(ctx,region)
                    for _,mesh in ipairs(meshes) do mesh:Clone().Parent=ctx.character end
                end
            end)
            template:Destroy()
            assert(applied,message)
            snapshot.bodyChanged=true
            if not reapplying then settings.bodyParts[region]=value;save() end
            return region.." body part applied (visible to you)."
        end
        local parts={}
        for _,name in ipairs(names) do local part=template:FindFirstChild(name);if part and part:IsA("BasePart") then parts[name]=part end end
        local applied,message=pcall(function() capture(ctx,true);replaceParts(ctx,parts,names);refitAccessories(ctx) end)
        template:Destroy()
        assert(applied,message)
        if not mapping then freezeBodyScaling(ctx)end
        snapshot.bodyChanged=true
        if not reapplying then settings.bodyParts[region]=value;save() end
        return region.." body part applied (visible to you)."
    end
    function api.restoreBodyPart(region)
        local ctx=context();assert(bodyRegions[region],"Choose a body region.")
        if mapping then mapping.restorePart(region)
        elseif snapshot and snapshot.character==ctx.character then
            if ctx.humanoid.RigType==Enum.HumanoidRigType.R6 then
                restoreR6Region(ctx,region)
            elseif next(snapshot.parts) then
                replaceParts(ctx,snapshot.parts,regionNames(region))
                if not mapping then freezeBodyScaling(ctx)end
            end
        end
        settings.bodyParts[region]=nil;save()
        return "Original "..region.." restored."
    end
    local faceTemplates={}
    local function faceSource(ctx,value)
        local id=idFrom(value,"catalog")
        local texture=faceTemplates[id]
        if not texture then
            local ok,objects=pcall(function()
                if type(readAsset)=="function"then return readAsset(id)end
                return game:GetObjects("rbxassetid://"..string.format("%.0f",id))
            end)
            assert(ok and type(objects)=="table","Roblox could not load that face.")
            if not valid(ctx) then dispose(objects);check(ctx) end
            for _,root in ipairs(objects)do
                if root:IsA("Decal") then texture=root.Texture end
                if not texture then for _,item in ipairs(root:GetDescendants())do if item:IsA("Decal")then texture=item.Texture;break end end end
                if texture then break end
            end
            dispose(objects)
            assert(type(texture)=="string" and texture~="","That catalog item is not a classic face.")
            nativeCall("ContentProvider.PreloadAsync",function()return game:GetService("ContentProvider"):PreloadAsync({texture})end)
            check(ctx)
            faceTemplates[id]=texture
        end
        return texture,id
    end
    function api.applyFace(value)
        local ctx=context()
        local texture,id=faceSource(ctx,value)
        if settings.bodyParts.Head then
            local ok,headId=pcall(idFrom,settings.bodyParts.Head,"catalog")
            if ok and (headId==134082579 or headId==15093053680) then api.restoreBodyPart("Head") end
        end
        local head=ctx.character:FindFirstChild("Head");assert(head,"This avatar has no head.")
        capture(ctx)
        if not snapshot.face then
            snapshot.face={}
            for _,item in ipairs(head:GetChildren())do if item:IsA("Decal")then table.insert(snapshot.face,item:Clone())end end
        end
        if mapping then mapping.face(ctx,texture,id)
        else
            for _,item in ipairs(head:GetChildren())do if item:IsA("Decal")then item:Destroy()end end
            local face=Instance.new("Decal");face.Name="face";face.Texture=texture;face.Parent=head
        end
        if not reapplying then settings.face=id;save()end
        return "Face applied (visible to you)."
    end
    local function restoreFaceAppearance(ctx)
        if mapping then mapping.restore("face");return end
        if not snapshot or not snapshot.face or snapshot.character~=ctx.character then return end
        local head=ctx.character:FindFirstChild("Head");if not head then return end
        for _,item in ipairs(head:GetChildren())do if item:IsA("Decal")then item:Destroy()end end
        for _,item in ipairs(snapshot.face)do item:Clone().Parent=head end
    end
    function api.restoreFace()
        restoreFaceAppearance(context());settings.face=nil;save()
        return "Original face restored."
    end
    local function restoreSkinAppearance(ctx)
        if mapping then mapping.restore("skin");skin={};return true end
        if not snapshot or snapshot.character~=ctx.character then skin={};return false end
        local colors=ctx.character:FindFirstChildOfClass("BodyColors")
        if colors then
            if snapshot.hadBodyColors then
                for region,color in pairs(snapshot.bodyColors) do colors[region.."Color3"]=color end
            else colors:Destroy() end
        end
        for name,color in pairs(snapshot.colors) do
            local part=ctx.character:FindFirstChild(name)
            if part and part:IsA("BasePart") then part.Color=color end
        end
        skin={}
        return true
    end
    local function restoreAppearance(keepOriginalsHidden)
        local ctx=context()
        clearAdded()
        clearGear()
        if mapping then
            mapping.restore();skin={};hidden={}
            if snapshot then snapshot.bodyChanged=false end
            return "Game appearance restored."
        end
        if not snapshot or snapshot.character~=ctx.character then return "Nothing to restore on this character." end
        if not keepOriginalsHidden then showOriginalAccessories() end
        if snapshot.bodyChanged then
            if ctx.humanoid.RigType==Enum.HumanoidRigType.R15 then restoreBodyParts(ctx)
            else
                local oldMeshes={};for _,item in ipairs(ctx.character:GetChildren()) do if item:IsA("CharacterMesh") then oldMeshes[#oldMeshes+1]=item end end
                for _,item in ipairs(oldMeshes) do item:Destroy() end
                for _,mesh in ipairs(snapshot.meshes) do mesh:Clone().Parent=ctx.character end
                if snapshot.r6Head then
                    local head=ctx.character:FindFirstChild("Head")
                    if head and head:IsA("BasePart") then applyPartAppearance(head,snapshot.r6Head) end
                end
            end
            snapshot.bodyChanged=false
            restoreBodyScaling(ctx)
        end
        for name,value in pairs(snapshot.scales or {})do
            local scale=ctx.humanoid:FindFirstChild(name)
            if scale and scale:IsA("NumberValue") then scale.Value=value end
        end
        restoreSkinAppearance(ctx)
        restoreFaceAppearance(ctx)
        return "Original appearance restored."
    end
    function api.restoreSkin()
        local ctx=context()
        restoreSkinAppearance(ctx)
        settings.colors={};save()
        return "Original skin restored."
    end
    function api.restoreBody()
        local ctx=context()
        if mapping then mapping.restore("body")
        elseif snapshot and snapshot.character==ctx.character and snapshot.bodyChanged then
            if ctx.humanoid.RigType==Enum.HumanoidRigType.R15 then restoreBodyParts(ctx)
            else
                local oldMeshes={};for _,item in ipairs(ctx.character:GetChildren()) do if item:IsA("CharacterMesh") then oldMeshes[#oldMeshes+1]=item end end
                for _,item in ipairs(oldMeshes) do item:Destroy() end
                for _,mesh in ipairs(snapshot.meshes) do mesh:Clone().Parent=ctx.character end
                if snapshot.r6Head then
                    local head=ctx.character:FindFirstChild("Head")
                    if head and head:IsA("BasePart") then applyPartAppearance(head,snapshot.r6Head) end
                end
            end
            snapshot.bodyChanged=false
            restoreBodyScaling(ctx)
        end
        settings.body=nil;settings.bodyParts={};save()
        return "Original body restored."
    end
    function api.restore()
        local message=restoreAppearance()
        settings={accessoryKinds={},accessories={},colors={},bodyParts={},hideOriginals=false,gear=nil};save()
        return message
    end
    function api.getSettings() return copySettings() end
    function api.corpseSource()
        if not alive or not snapshot or snapshot.character~=player.Character then return nil end
        return {character=snapshot.character,parts=snapshot.parts,head=snapshot.r6Head,colors=snapshot.colors,hidden=hidden,version=appearanceVersion,mapped=mapping~=nil,
            attach=mapping and mapping.attachBody}
    end
    local operations={}
    for _,name in ipairs({"equipAccessory","setAccessoryMetadata","equipGear","removeGear","removeAccessory","clearAccessories","removeCurrentAccessories","setSkin","setSkinColors","setScales","applyBody","applyBodyParts","applyBodyPart","restoreBodyPart","applyFace","restoreFace","restoreSkin","restoreBody","restore"}) do
        local operation=api[name]
        operations[name]=operation
        api[name]=function(...)
            assert(not reapplying,"Wait for saved cosmetics to finish restoring.")
            local result=table.pack(operation(...))
            appearanceVersion=appearanceVersion+1
            return table.unpack(result,1,result.n)
        end
    end
    function api.prepareSaved()
        local ctx=context()
        if settings.body and not(settings.body=="Blocky" and ctx.humanoid.RigType==Enum.HumanoidRigType.R6)then
            local template=bodySource(ctx,settings.body);template:Destroy()
        end
        local complete=true
        for _,region in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"})do
            if type(settings.bodyParts[region])~="number" then complete=false;break end
        end
        if complete then prepareBodyParts(ctx,settings.bodyParts,settings.scales)
        else for region,value in pairs(settings.bodyParts)do
            local template,remember=bodyPartSource(ctx,region,value);remember();template:Destroy()
        end end
        local failures=api.prepareAccessories(settings.accessories)
        for _,reason in pairs(failures)do error(reason)end
        if settings.face then
            faceSource(ctx,settings.face)
        end
        check(ctx)
    end
    function api.reapplySaved()
        local ctx=context()
        if reapplying and replayGeneration==generation then return "Saved cosmetics are already restoring." end
        replayToken=replayToken+1
        local token=replayToken
        reapplying,replayGeneration=true,generation
        notify("Restoring saved cosmetics...",true)
        local desired=copySettings()
        local failures={}
        local ok,message=pcall(function()
            notify("Restoring original appearance...",true)
            -- Revisions update the replacement side of the mapping. Restoring
            -- a captured outfit first would erase intervening game changes.
            if not mapping then restoreAppearance(desired.hideOriginals)end
            local function apply(label,operation,...)
                check(ctx)
                notify("Restoring "..label.."...",true)
                local success,err=pcall(operation,...)
                check(ctx)
                if not success then table.insert(failures,(tostring(err):gsub("^.-:%d+:%s*",""))) end
            end
            if desired.scales then apply("proportions",operations.setScales,desired.scales) end
            if desired.body then apply("body",operations.applyBody,desired.body) end
            local complete=true
            for _,region in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"})do
                if type(desired.bodyParts[region])~="number" then complete=false;break end
            end
            if complete then apply("body",operations.applyBodyParts,desired.bodyParts,desired.scales)
            else for region,value in pairs(desired.bodyParts) do apply(region,operations.applyBodyPart,region,value) end end
            if desired.face then apply("face",operations.applyFace,desired.face)end
            if desired.hideOriginals then apply("hidden accessories",operations.removeCurrentAccessories) end
            local retained={}
            if mapping then for _,entry in ipairs(added)do
                retained[entry.id]=retained[entry.id]or {};table.insert(retained[entry.id],entry)
            end end
            for _,id in ipairs(desired.accessories)do
                local existing=retained[id]and table.remove(retained[id])
                if existing then apply("accessory adjustments",operations.setAccessoryMetadata,existing.key,(desired.accessoryMeta or {})[tostring(id)])
                else apply("accessory "..id,operations.equipAccessory,id,(desired.accessoryMeta or {})[tostring(id)])end
            end
            local colors={}
            if desired.colors.All then for region in pairs(groups)do colors[region]=Color3.new(desired.colors.All[1],desired.colors.All[2],desired.colors.All[3])end end
            for region,color in pairs(desired.colors)do if region~="All"then colors[region]=Color3.new(color[1],color[2],color[3])end end
            if next(colors)then apply("skin colors",operations.setSkinColors,colors)end
        end)
        if token==replayToken then reapplying=false end
        check(ctx)
        assert(ok,message)
        appearanceVersion=appearanceVersion+1
        local result=#failures==0 and "Saved cosmetics restored." or ("Saved selections kept; some could not load: "..failures[1])
        if token==replayToken then notify(result,false) end
        return result
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
    local function schedule(c)
        whenReady(c,function()
            local h=c:FindFirstChildOfClass("Humanoid")
            return h and h.Health>0 and c:FindFirstChild("Head") and player:HasAppearanceLoaded()
        end,function()
            local ok,err=pcall(api.reapplySaved)
            if not ok and alive then notify("Could not restore saved cosmetics: "..tostring(err),false)end
        end)
    end
    local changed=player.CharacterAdded:Connect(function(c)
        generation=generation+1;if mapping then mapping.reset()end;forget(true);if not managedRespawn then schedule(c)end
    end)
    function api.destroy()
        cancelReady()
        if not alive then return end
        generation=generation+1
        if nativePreparation then nativePreparation:Fire()end
        changed:Disconnect()
        for character,record in pairs(retiredAccessories)do
            record.connection:Disconnect()
            for _,entry in ipairs(record.hidden)do
                for part,properties in pairs(entry.parts)do
                    for property,value in pairs(properties)do pcall(function()part[property]=value end)end
                end
            end
            for _,entry in ipairs(record.added)do pcall(function()entry.object:Destroy()end)end
            retiredAccessories[character]=nil
        end
        if snapshot and snapshot.character==player.Character then pcall(restoreAppearance) end
        if mapping then mapping.destroy()end
        clearNativeSource()
        for _,template in pairs(fullBodyTemplates)do template:Destroy()end
        fullBodyTemplates={};fullBodyOrder={}
        for _,entry in pairs(bodyPartTemplates)do entry.model:Destroy()end
        bodyPartTemplates={};bodyPartOrder={}
        for _,template in pairs(wearableTemplates)do template:Destroy()end
        wearableTemplates={};wearableOrder={}
        forget();alive=false
    end
    return api
end
