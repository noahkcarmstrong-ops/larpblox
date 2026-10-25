-- Map native account appearance to a native, game-compatible Larp appearance.
-- Source values belong to the game. Only our last writes belong to this controller.
local regions={Head={"Head"},Torso={"Torso","UpperTorso","LowerTorso"},
    LeftArm={"Left Arm","LeftUpperArm","LeftLowerArm","LeftHand"},RightArm={"Right Arm","RightUpperArm","RightLowerArm","RightHand"},
    LeftLeg={"Left Leg","LeftUpperLeg","LeftLowerLeg","LeftFoot"},RightLeg={"Right Leg","RightUpperLeg","RightLowerLeg","RightFoot"}}
local scales={height="BodyHeightScale",width="BodyWidthScale",depth="BodyDepthScale",head="HeadScale",bodyType="BodyTypeScale",proportion="BodyProportionScale"}
local descriptionScales={height="HeightScale",width="WidthScale",depth="DepthScale",head="HeadScale",bodyType="BodyTypeScale",proportion="ProportionScale"}
local function content(value)
    if type(value)~="string"then return value end
    return value:match("^rbxassetid://(%d+)$") or value:match("[?&]id=(%d+)") or value
end
local function equal(a,b)
    if typeof(a)=="Vector3"and typeof(b)=="Vector3"then return (a-b).Magnitude<0.0001 end
    return content(a)==content(b)
end
local childFields={SpecialMesh={"MeshId","TextureId","MeshType","Scale","Offset","VertexColor"},
    Decal={"Texture","Color3","Transparency","Face"},Texture={"Texture","Color3","Transparency","Face","StudsPerTileU","StudsPerTileV","OffsetStudsU","OffsetStudsV"},
    SurfaceAppearance={"ColorMap","MetalnessMap","NormalMap","RoughnessMap","AlphaMode","Color"},
    Attachment={"CFrame"},Vector3Value={"Value"},StringValue={"Value"}}
local function relevant(object)
    return object:IsA("SpecialMesh")or object:IsA("Decal")or object:IsA("Texture")or object:IsA("SurfaceAppearance")
        or object:IsA("Attachment")or object.Name=="OriginalSize"or object.Name=="OriginalPosition"or object.Name=="AvatarPartScaleType"
end
local function key(object)return object.ClassName..":"..object.Name end
local function children(object)
    local result={}
    if object then for _,child in ipairs(object:GetChildren())do
        if relevant(child)then
            local k=key(child)
            -- Duplicate slots are ambiguous. Do not substitute them by ordinal or guess.
            if result[k]~=nil then result[k]=false else result[k]=child end
        end
    end end
    return result
end
return function(player)
    local Players=game:GetService("Players")
    local alive=true
    local original,account,rigType
    local originalHistory={}
    local views={}
    local bodyDefinitions,skinDefinitions,scaleDefinitions={}, {}, {}
    local faceDefinition
    local hipDefinition
    local r6Definitions={}
    local accessoryMode=false
    local addedAccessories=setmetatable({}, {__mode="k"})
    local accessoryAllowed={}
    local clothingCache={}
    local namespace={}
    local active=false
    local world=workspace
    local metadataFolders=setmetatable({}, {__mode="k"})
    local tags=setmetatable({}, {__mode="k"})
    local nextTag=0
    local tagAttribute="LarpbloxAppearanceSource"
    local function tag(object)
        if not tags[object]then
            nextTag=nextTag+1
            local id=tostring(namespace)..":"..nextTag
            tags[object]={id=id,previous=object:GetAttribute(tagAttribute)}
            object:SetAttribute(tagAttribute,id)
        end
    end
    local generation=0
    local api={}
    local reconcile,bind,makeView,adopt
    local function disconnect(view)
        for _,connection in ipairs(view.connections)do connection:Disconnect()end
        for _,record in ipairs(view.records)do record.connection:Disconnect()end
        for _,group in pairs(view.accessoryConnections)do for _,connection in ipairs(group)do connection:Disconnect()end end
        view.connections={};view.accessoryConnections={}
    end
    local function belongs(view,object)return object:IsDescendantOf(view.character)end
    local function baseline(ctx)
        if original and rigType==ctx.humanoid.RigType then return original end
        local mine=generation
        local desc=Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
        desc.UseAvatarSettings=true
        local ok,model=pcall(Players.CreateHumanoidModelFromDescriptionAsync,Players,desc,ctx.humanoid.RigType)
        if not alive or generation~=mine or player.Character~=ctx.character then
            desc:Destroy();if ok and model then model:Destroy()end;error("Character changed while reading the original avatar.")
        end
        if not ok or not model then desc:Destroy();error("Could not read the original avatar; game appearance was preserved.")end
        if original then originalHistory[#originalHistory+1]=original end
        if account then account:Destroy()end
        account=desc;original=model;rigType=ctx.humanoid.RigType
        return original
    end
    local function queue(view,rebind)
        if rebind then view.needsBind=true end
        if view.queued or not alive then return end
        view.queued=true
        task.defer(function()
            view.queued=false
            if alive and views[view.character]==view then reconcile(view)end
        end)
    end
    local function encode(value)
        return typeof(value)=="EnumItem"and "__enum:"..tostring(value)or value
    end
    local function decode(value)
        if type(value)=="string"then
            local enum,name=value:match("^__enum:Enum%.([^%.]+)%.(.+)$")
            if enum then return Enum[enum][name]end
        end
        return value
    end
    local function findMetadata(object)
        for _,child in ipairs(object:GetChildren())do
            if child.Name=="LarpbloxAppearanceMapping"and child:IsA("Folder")and child:GetAttribute("UserId")==player.UserId
                and child:GetAttribute("Version")==1 then return child end
        end
    end
    local function metadata(object)
        local folder=metadataFolders[object]
        if not folder then
            folder=findMetadata(object)
            if not folder then
                folder=Instance.new("Folder");folder.Name="LarpbloxAppearanceMapping"
                folder:SetAttribute("UserId",player.UserId);folder:SetAttribute("Version",1);folder.Parent=object
            end
            metadataFolders[object]=folder
        end
        return folder
    end
    local function writeMesh(wanted,record)
        local object=record.object
        local source=equal(wanted,record.baseline)and record.baseMesh or record.desiredMesh
        local size,texture=object.Size,object.TextureID
        object:ApplyMesh(source);object.Size=size;object.TextureID=texture
    end
    local function publish(record)
        local folder=metadata(record.object)
        local values={Source=record.source,Written=record.written,Baseline=record.baseline,Desired=record.desired,
            Group=record.group,Enabled=record.enabled,Gate=record.gate and (tags[record.gate.object].id.."|"..record.gate.property)or "",
            Attachment=record.attachment and tags[record.attachment]and tags[record.attachment].id or ""}
        record.metadataValues=record.metadataValues or {}
        for name,value in pairs(values)do
            value=encode(value)
            if record.metadataValues[name]~=value then
                folder:SetAttribute(name.."_"..record.property,value);record.metadataValues[name]=value
            end
        end
        if record.baseMesh then for _,name in ipairs({"BaseMesh","DesiredMesh"})do
            local value=folder:FindFirstChild(name)
            if not value then value=Instance.new("ObjectValue");value.Name=name;value.Parent=folder end
            value.Value=name=="BaseMesh"and record.baseMesh or record.desiredMesh
        end end
    end
    local function owned(view,object,group)
        tag(object)
        object:SetAttribute("LarpbloxAppearanceOwnedUserId",player.UserId)
        object:SetAttribute("LarpbloxAppearanceOwnedGroup",group)
        -- The avatar controller owns active additions; this controller owns
        -- synthetic children and the extra copies adopted on cloned bodies.
        if group~="accessories"or object.Parent~=player.Character then view.ownedObjects[object]=group end
    end
    local function read(record)
        local value=record.object[record.property]
        if not equal(value,record.written)then
            record.source=value
            if record.group=="clothes"and not equal(value,record.baseline)and record.object:GetAttribute("LarpbloxAppearanceOwnedGroup")=="clothes"then
                record.object:SetAttribute("LarpbloxAppearanceOwnedUserId",nil);record.object:SetAttribute("LarpbloxAppearanceOwnedGroup",nil)
                local view=views[record.object.Parent];if view then view.ownedObjects[record.object]=nil end
            end
        end
        record.written=value
    end
    local function value(record)
        local function eligible(current)
            return not current or (equal(current.source,current.baseline)and eligible(current.gate))
        end
        if record.enabled and equal(record.source,record.baseline)and eligible(record.gate)then
            return record.attachment and record.attachment.CFrame or record.desired
        end
        return record.source
    end
    local function flush(view)
        -- Read every external change before any native operation can touch sibling fields.
        for _,record in ipairs(view.records)do if belongs(view,record.object)then read(record)end end
        view.writing=true
        local ok,err=pcall(function()
            for _,record in ipairs(view.records)do
                if belongs(view,record.object)then
                    local desired=value(record)
                    if not equal(record.object[record.property],desired)then
                        -- Other presentation controllers can observe synchronous
                        -- native property events during this assignment.
                        record.written=desired
                        if record.write then record.write(desired,record)else record.object[record.property]=desired end
                    end
                    record.written=record.object[record.property]
                    publish(record)
                end
            end
        end)
        view.writing=false
        if not ok then error(err)end
    end
    local function property(view,object,name,base,desired,group,gate,write)
        if base==nil or desired==nil then return end
        local props=view.index[object]
        if not props then props={};view.index[object]=props end
        local record=props[name]
        if not record then
            tag(object)
            local current=object[name]
            record={object=object,property=name,source=current,written=current,baseline=base}
            props[name]=record;view.records[#view.records+1]=record
            record.connection=object:GetPropertyChangedSignal(name):Connect(function()
                if not view.writing then queue(view,name=="MeshId"or name=="Shape")end
            end)
        else read(record)end
        record.baseline=base;record.desired=desired;record.group=group;record.gate=gate;record.write=write;record.enabled=true
        return record
    end
    local function disable(view,group)
        for _,record in ipairs(view.records)do if not group or record.group==group then record.enabled=false end end
    end
    local function tree(view,target,base,desired,group,gate)
        local fields=childFields[target.ClassName]
        if target:IsA("SpecialMesh")and base and desired then gate=property(view,target,"MeshId",base.MeshId,desired.MeshId,group,gate)end
        if fields and base and desired then for _,field in ipairs(fields)do
            local ok,a,b=pcall(function()return base[field],desired[field]end)
            if ok and not (target:IsA("SpecialMesh")and field=="MeshId")then property(view,target,field,a,b,group,gate)end
        end end
        local before,after,current=children(base),children(desired),children(target)
        for slot,source in pairs(before)do
            local replacement,object=after[slot],current[slot]
            if source and replacement and object then tree(view,object,source,replacement,group,gate)
            elseif source and object and not replacement and (object:IsA("Decal")or object:IsA("Texture"))then
                -- Absence in the replacement maps the original face/texture to
                -- empty content. Keep the native instance and all game fades.
                property(view,object,"Texture",source.Texture,"",group,gate)
            end
        end
        -- Structural substitutions retain the game's original instances. A game
        -- removal/replacement of a slot is observed separately from our writes.
        for slot,replacement in pairs(after)do
            if replacement and before[slot]==nil then
                view.ids[target]=view.ids[target]or tostring(view.nextId)
                view.nextId=view.nextId+1
                local id=view.ids[target].."/"..slot
                local entry=view.synthetic[id]
                local eligible=not gate or equal(gate.source,gate.baseline)
                if entry and not eligible then
                    view.writing=true;entry.object:Destroy();view.writing=false;view.synthetic[id]=nil
                elseif entry and current[slot]==entry.object then
                    tree(view,entry.object,entry.original,replacement,group,gate)
                elseif eligible and current[slot]==nil and not view.syntheticRemoved[id]and not entry then
                    local copy=replacement:Clone()
                    owned(view,copy,group)
                    local originalChild=replacement:Clone();view.resources[#view.resources+1]=originalChild
                    view.synthetic[id]={object=copy,parent=target,group=group,slot=slot,original=originalChild}
                    view.writing=true;copy.Parent=target;view.writing=false
                end
            end
        end
    end
    local function part(view,target,base,desired,group)
        if not target or not base or not desired or target.ClassName~=base.ClassName or target.ClassName~=desired.ClassName then return end
        local gate
        if target:IsA("MeshPart")then
            gate=property(view,target,"MeshId",base.MeshId,desired.MeshId,group,nil,writeMesh)
            gate.baseMesh=base;gate.desiredMesh=desired
            property(view,target,"TextureID",base.TextureID,desired.TextureID,group,gate)
        elseif target:IsA("Part")then
            gate=property(view,target,"Shape",base.Shape,desired.Shape,group)
        end
        property(view,target,"Size",base.Size,desired.Size,group,gate)
        property(view,target,"Transparency",base.Transparency,desired.Transparency,group,gate)
        tree(view,target,base,desired,group,gate)
    end
    local function accessoryIdentity(object)
        local handle=object:FindFirstChild("Handle")
        if not handle then return end
        local mesh=handle:IsA("MeshPart")and handle or handle:FindFirstChildOfClass("SpecialMesh")
        if not mesh then return end
        local category=object:IsA("Hat")and Enum.AccessoryType.Hat or object.AccessoryType
        return tostring(category)..":"..tostring(content(mesh.MeshId))..":"..tostring(content(mesh:IsA("MeshPart")and mesh.TextureID or mesh.TextureId))
    end
    local function category(object)return tostring(object:IsA("Hat")and Enum.AccessoryType.Hat or object.AccessoryType)end
    local function accessoryState(view)
        if not original then return end
        disable(view,"accessories")
        if view.skipAccessories then return end
        local originals,categories={},{}
        for _,object in ipairs(original:GetChildren())do if object:IsA("Accessory")or object:IsA("Hat")then
            local identity=accessoryIdentity(object)
            if identity then
                originals[identity]=(originals[identity]or 0)+1
                local name=category(object);categories[name]=(categories[name]or 0)+1
            end
        end end
        local present,foreign,observed,sourceObjects={},{},{},{}
        for _,object in ipairs(view.character:GetChildren())do if (object:IsA("Accessory")or object:IsA("Hat"))and not addedAccessories[object]then
            local category=category(object)
            local identity=accessoryIdentity(object)
            if identity and originals[identity]then
                observed[identity]=(observed[identity]or 0)+1
                present[category]=(present[category]or 0)+1
                sourceObjects[object]=category
                if observed[identity]>originals[identity]then foreign[category]=true end
            else foreign[category]=true end
            local handle=object:FindFirstChild("Handle")
            local mesh=handle and (handle:IsA("MeshPart")and handle or handle:FindFirstChildOfClass("SpecialMesh"))
            if mesh and not view.accessoryConnections[mesh]then
                local group={};view.accessoryConnections[mesh]=group
                for _,field in ipairs({"MeshId",mesh:IsA("MeshPart")and "TextureID"or "TextureId"})do
                    local connection=mesh:GetPropertyChangedSignal(field):Connect(function()if not view.writing then queue(view,true)end end)
                    group[#group+1]=connection
                end
            end
        end end
        local function eligible(category)
            -- Map a complete native accessory category. Partial removals, new
            -- game items and replacements preserve that category as supplied.
            return not foreign[category]and (present[category]or 0)==(categories[category]or 0)
        end
        if accessoryMode then for object,category in pairs(sourceObjects)do if eligible(category)then
            for _,child in ipairs(object:GetDescendants())do if child:IsA("BasePart")then
                property(view,child,"LocalTransparencyModifier",0,1,"accessories")
            end end
        end end end
        for object,entry in pairs(addedAccessories)do
            if object.Parent==view.character then
                local allowed=eligible(category(object))
                for _,child in ipairs(object:GetDescendants())do if child:IsA("BasePart")then
                    property(view,child,"LocalTransparencyModifier",0,allowed and 0 or 1,"accessories")
                end end
                entry.eligible=allowed
            end
        end
        for object,group in pairs(view.accessoryConnections)do if not object:IsDescendantOf(view.character)then
            for _,connection in ipairs(group)do connection:Disconnect()end
            view.accessoryConnections[object]=nil
        end end
    end
    bind=function(view)
        local character=view.character
        for name,source in pairs(bodyDefinitions)do
            part(view,character:FindFirstChild(name),original:FindFirstChild(name),source,"body:"..name)
        end
        local nativeJoints={}
        for _,joint in ipairs(original:GetDescendants())do if joint:IsA("Motor6D")and joint.Part0 and joint.Part1 then
            nativeJoints[joint.Part0.Name..":"..joint.Name..":"..joint.Part1.Name]=joint
        end end
        for _,joint in ipairs(character:GetDescendants())do if joint:IsA("Motor6D")and joint.Part0 and joint.Part1 then
            local a,b=joint.Part0,joint.Part1
            local region=bodyDefinitions[a.Name]and a.Name or bodyDefinitions[b.Name]and b.Name
            local native=nativeJoints[a.Name..":"..joint.Name..":"..b.Name]
            if region and native then
                local attachment=(joint.Name=="RootJoint"and "Root"or joint.Name).."RigAttachment"
                local gate=view.index[character:FindFirstChild(region)]
                gate=gate and (gate.MeshId or gate.Shape)
                for _,field in ipairs({"C0","C1"})do
                    local node=(field=="C0"and a or b):FindFirstChild(attachment)
                    if node and node:IsA("Attachment")then
                        local record=property(view,joint,field,native[field],native[field],"body:"..region,gate)
                        record.attachment=node
                    end
                end
            end
        end end
        for region,definition in pairs(r6Definitions)do
            local native,desired=definition.base,definition.desired
            local found={}
            for _,object in ipairs(character:GetChildren())do if object:IsA("CharacterMesh")and object.BodyPart.Name==region then found[#found+1]=object end end
            if #found==1 and native then
                local target=found[1]
                local identity=property(view,target,"BodyPart",native.BodyPart,native.BodyPart,"body:"..region)
                local gate=property(view,target,"MeshId",native.MeshId,desired and desired.MeshId or 0,"body:"..region,identity)
                for _,field in ipairs({"BaseTextureId","OverlayTextureId"})do property(view,target,field,native[field],desired and desired[field]or 0,"body:"..region,gate)end
            elseif #found==0 and not native and desired and not view.r6Removed[region]then
                local copy=desired:Clone();view.r6Added[region]=copy;owned(view,copy,"body:"..region)
                view.writing=true;copy.Parent=character;view.writing=false
            elseif #found>1 and view.r6Added[region]then
                view.writing=true;view.r6Added[region]:Destroy();view.writing=false;view.r6Added[region]=nil
            end
        end
        for region,color in pairs(skinDefinitions)do
            local colors=character:FindFirstChildOfClass("BodyColors")
            local native=original:FindFirstChildOfClass("BodyColors")
            if colors and native then property(view,colors,region.."Color3",native[region.."Color3"],color,"skin")end
            for _,name in ipairs(regions[region])do
                local target,base=character:FindFirstChild(name),original:FindFirstChild(name)
                if target and base and target:IsA("BasePart")then property(view,target,"Color",base.Color,color,"skin")end
            end
        end
        local humanoid=character:FindFirstChildOfClass("Humanoid")
        local native=original:FindFirstChildOfClass("Humanoid")
        if humanoid and native then for name,desired in pairs(scaleDefinitions)do
            local target,base=humanoid:FindFirstChild(name),native:FindFirstChild(name)
            if target and base then property(view,target,"Value",base.Value,desired,"scales")end
        end end
        if humanoid and native and hipDefinition then property(view,humanoid,"HipHeight",native.HipHeight,hipDefinition,"body:HipHeight")end
        if faceDefinition then
            local head,base=character:FindFirstChild("Head"),original:FindFirstChild("Head")
            if head and base then for _,child in ipairs(head:GetChildren())do if child:IsA("Decal")then
                local source=base:FindFirstChildOfClass("Decal")
                if source then property(view,child,"Texture",source.Texture,faceDefinition,"face")end
            end end end
        end
        accessoryState(view)
    end
    reconcile=function(view)
        if not original and not view.retired then return end
        local retained={}
        for _,record in ipairs(view.records)do
            if belongs(view,record.object)then read(record);retained[#retained+1]=record
            else
                -- A removed instance may be reused later. Release only our last
                -- write on it, and stop listening until it belongs to this view again.
                pcall(function()
                    read(record)
                    if not equal(record.object[record.property],record.source)then
                        if record.write then record.write(record.source,record)else record.object[record.property]=record.source end
                    end
                end)
                record.connection:Disconnect()
                if view.index[record.object]then
                    view.index[record.object][record.property]=nil
                    if not next(view.index[record.object])then view.index[record.object]=nil end
                end
            end
        end
        view.records=retained
        if not view.retired and view.needsBind then view.needsBind=false;bind(view)end
        local humanoid=view.character:FindFirstChildOfClass("Humanoid")
        -- Observe death-time changes, but never rebuild a saved outfit onto a dead body.
        if humanoid and humanoid.Health<=0 then return end
        flush(view)
    end
    makeView=function(character)
        local view={character=character,records={},index={},connections={},synthetic={},syntheticRemoved={},ids={},nextId=1,r6Added={},r6Removed={},resources={},ownedAccessories={},ownedObjects={},needsBind=true,accessoryConnections={}}
        views[character]=view
        character:SetAttribute("LarpbloxAppearanceUserId",player.UserId)
        character:SetAttribute("LarpbloxAppearanceVersion",1)
        view.connections[#view.connections+1]=character.DescendantAdded:Connect(function(object)if not view.writing and (relevant(object)or object.Parent==character or object:IsA("Motor6D")or object:IsA("NumberValue"))then queue(view,true)end end)
        view.connections[#view.connections+1]=character.DescendantRemoving:Connect(function(object)
            if view.writing then return end
            for id,entry in pairs(view.synthetic)do if entry.object==object then view.synthetic[id]=nil;view.syntheticRemoved[id]=true end end
            for region,entry in pairs(view.r6Added)do if entry==object then view.r6Added[region]=nil;view.r6Removed[region]=true end end
            queue(view,true)
        end)
        view.destroyConnection=character.Destroying:Connect(function()
            views[character]=nil
            disconnect(view)
            for _,object in ipairs(view.resources)do object:Destroy()end
        end)
        return view
    end
    local function viewFor(ctx)
        baseline(ctx);active=true
        return views[ctx.character]or makeView(ctx.character)
    end
    -- Source/written values travel with cloned instances as local metadata.
    -- Native hierarchy events can therefore adopt the exact cloned state even
    -- when it was copied before a later outfit update. No method hook is needed.
    adopt=function(clone)
        if not alive or views[clone]or clone:GetAttribute("LarpbloxAppearanceUserId")~=player.UserId
            or clone:GetAttribute("LarpbloxAppearanceVersion")~=1 then return false end
        local view=makeView(clone);view.retired=true
        local nodes,records={},{}
        for _,object in ipairs(clone:GetDescendants())do
            local id=object:GetAttribute(tagAttribute)
            if id then if nodes[id]~=nil then nodes[id]=false else nodes[id]=object end end
            if object:GetAttribute("LarpbloxAppearanceOwnedUserId")==player.UserId then
                view.ownedObjects[object]=object:GetAttribute("LarpbloxAppearanceOwnedGroup")
            end
        end
        for _,object in ipairs(clone:GetDescendants())do
            local folder=findMetadata(object)
            if folder then
                tags[object]={id=object:GetAttribute(tagAttribute),previous=nil}
                metadataFolders[object]=folder
                local attrs=folder:GetAttributes()
                for field,source in pairs(attrs)do if field:sub(1,7)=="Source_"then
                    local name=field:sub(8)
                    local originalValue=decode(attrs["Baseline_"..name])
                    local desired=decode(attrs["Desired_"..name])
                    if originalValue~=nil and desired~=nil then
                        local write=object:IsA("MeshPart")and name=="MeshId"and writeMesh or nil
                        local record=property(view,object,name,originalValue,desired,attrs["Group_"..name],nil,write)
                        local previous=decode(attrs["Written_"..name])
                        if equal(object[name],previous)then record.source=decode(source)end
                        record.enabled=attrs["Enabled_"..name]==true
                        if write then
                            local base,appearance=folder:FindFirstChild("BaseMesh"),folder:FindFirstChild("DesiredMesh")
                            record.baseMesh=base and base.Value;record.desiredMesh=appearance and appearance.Value
                            if not record.baseMesh or not record.desiredMesh then record.enabled=false;record.source=object[name]end
                        end
                        records[#records+1]={record=record,gate=attrs["Gate_"..name],attachment=attrs["Attachment_"..name]}
                    end
                end end
            end
        end
        for _,entry in ipairs(records)do
            if entry.gate then
                local id,name=entry.gate:match("^(.*)|([^|]+)$")
                local node=nodes[id];entry.record.gate=node and view.index[node]and view.index[node][name]or nil
            end
            entry.record.attachment=nodes[entry.attachment]
        end
        if not active then
            disable(view);flush(view)
            for object in pairs(view.ownedObjects)do object:Destroy()end;view.ownedObjects={}
        else flush(view)end
        return true
    end
    local added
    if world then added=world.DescendantAdded:Connect(function(object)
        if object:IsA("Model")and object:GetAttribute("LarpbloxAppearanceUserId")==player.UserId then task.defer(adopt,object)end
    end)end
    function api.attachBody(model)
        if not alive then return false end
        if views[model]or adopt(model)then return true end
        if not original then return false end
        local view=makeView(model)
        view.skipAccessories=true
        bind(view);flush(view)
        local humanoid=model:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local pending={}
            for object,entry in pairs(addedAccessories)do if object.Parent==player.Character then pending[#pending+1]={object=object,id=entry.id}end end
            local complete=true
            for _,entry in ipairs(pending)do
                local copy=entry.object:Clone()
                if not copy then complete=false;continue end
                for _,child in ipairs(copy:GetDescendants())do
                    if child:IsA("LuaSourceContainer")then child:Destroy()
                    elseif child:IsA("JointInstance")or child:IsA("WeldConstraint")then
                        if (child.Part0 and not child.Part0:IsDescendantOf(copy))or (child.Part1 and not child.Part1:IsDescendantOf(copy))then child:Destroy()end
                    end
                end
                local ok=pcall(humanoid.AddAccessory,humanoid,copy)
                local fitted=false
                local handle=copy:FindFirstChild("Handle")
                if ok and handle then for _,joint in ipairs(handle:GetChildren())do if joint:IsA("JointInstance")then
                    local other=joint.Part0==handle and joint.Part1 or joint.Part1==handle and joint.Part0
                    if other and other:IsDescendantOf(model)and not other:IsDescendantOf(copy)then fitted=true end
                end end end
                if ok and fitted and copy.Parent==model then
                    addedAccessories[copy]={id=entry.id};view.ownedAccessories[#view.ownedAccessories+1]=copy;owned(view,copy,"accessories")
                else copy:Destroy();complete=false end
            end
            if complete then view.skipAccessories=false;accessoryState(view);flush(view)
            else for _,object in ipairs(view.ownedAccessories)do object:Destroy()end;view.ownedAccessories={}end
        end
        view.retired=true
        return true
    end
    function api.body(ctx,parts,names)
        local view=viewFor(ctx)
        for _,name in ipairs(names)do if parts[name]then
            if bodyDefinitions[name]then bodyDefinitions[name]:Destroy()end
            bodyDefinitions[name]=parts[name]:Clone()
        end end
        view.needsBind=true;reconcile(view)
    end
    function api.r6(ctx,template,region)
        local view=viewFor(ctx)
        for name in pairs(regions)do if not region or region==name then
            if name=="Head"then
                local head=template:FindFirstChild("Head")
                if head then if bodyDefinitions.Head then bodyDefinitions.Head:Destroy()end;bodyDefinitions.Head=head:Clone()end
            else
                local native,desired
                for _,object in ipairs(original:GetChildren())do if object:IsA("CharacterMesh")and object.BodyPart.Name==name then native=object end end
                for _,object in ipairs(template:GetChildren())do if object:IsA("CharacterMesh")and object.BodyPart.Name==name then desired=object end end
                local old=r6Definitions[name];if old and old.desired then old.desired:Destroy()end
                r6Definitions[name]={base=native,desired=desired and desired:Clone()}
                local added=view.r6Added[name]
                if added then view.writing=true;added:Destroy();view.writing=false;view.r6Added[name]=nil end
            end
        end end
        view.needsBind=true;reconcile(view)
    end
    function api.hip(ctx,value)local view=viewFor(ctx);hipDefinition=value;view.needsBind=true;reconcile(view)end
    local function resolve(ctx,edit)
        baseline(ctx)
        local description=account:Clone();edit(description);description.UseAvatarSettings=true
        local ok,model=pcall(Players.CreateHumanoidModelFromDescriptionAsync,Players,description,ctx.humanoid.RigType)
        description:Destroy()
        if not alive or player.Character~=ctx.character then if ok and model then model:Destroy()end;error("Character changed while resolving the mapped appearance.")end
        assert(ok and model,"Could not resolve the game-compatible appearance; game appearance was preserved.")
        return model
    end
    function api.skinColors(ctx,values)
        local view=viewFor(ctx)
        local model=resolve(ctx,function(description)for name,color in pairs(values)do description[name.."Color"]=color end end)
        local colors=model:FindFirstChildOfClass("BodyColors")
        for name in pairs(values)do
            local part=model:FindFirstChild(regions[name][1])or model:FindFirstChild(regions[name][2]or "")
            skinDefinitions[name]=colors and colors[name.."Color3"]or part and part.Color
        end
        model:Destroy()
        view.needsBind=true;reconcile(view)
    end
    function api.clothingTemplates(ctx,kind,id,prepared)
        local source=baseline(ctx)
        local propertyName=({Shirt="ShirtTemplate",Pants="PantsTemplate",ShirtGraphic="Graphic"})[kind]
        local field=({Shirt="Shirt",Pants="Pants",ShirtGraphic="GraphicTShirt"})[kind]
        assert(propertyName,"Unknown clothing kind.")
        local item=source:FindFirstChildOfClass(kind)
        local expected=item and item[propertyName]or ""
        if id==nil then return expected end
        local key=tostring(ctx.humanoid.RigType)..":"..kind..":"..id
        local replacement=clothingCache[key]
        if replacement==nil then
            local model=prepared or resolve(ctx,function(description)description[field]=id end)
            local object=model:FindFirstChildOfClass(kind)
            replacement=object and object[propertyName]or "";clothingCache[key]=replacement
            if not prepared then model:Destroy()end
        end
        return expected,replacement
    end
    function api.clothingSource(object,name)
        local view=views[object.Parent]
        local record=view and view.index[object]and view.index[object][name]
        if record then read(record);return record.source end
        return object[name]
    end
    function api.projectClothing(object,name,source,expected,replacement,value,synthetic)
        if not alive then object[name]=value;return end
        if replacement~=nil then active=true end
        local character=object.Parent
        if not character or not character:IsA("Model")then object[name]=value;return end
        local view=views[character]or makeView(character)
        if synthetic then owned(view,object,"clothes")
        elseif object:GetAttribute("LarpbloxAppearanceOwnedGroup")=="clothes"then
            view.ownedObjects[object]=nil;object:SetAttribute("LarpbloxAppearanceOwnedUserId",nil);object:SetAttribute("LarpbloxAppearanceOwnedGroup",nil)
        end
        local record
        if replacement~=nil then record=property(view,object,name,expected,replacement,"clothes")
        else record=view.index[object]and view.index[object][name];if record then record.enabled=false end end
        if record then
            record.source=source;record.written=object[name];flush(view)
        else object[name]=value end
    end
    function api.skin(ctx,color,region)
        local values={};for name in pairs(regions)do if region=="All"or name==region then values[name]=color end end
        api.skinColors(ctx,values)
    end
    function api.scales(ctx,values)
        local view=viewFor(ctx)
        local model=resolve(ctx,function(description)for name,v in pairs(values)do description[descriptionScales[name]]=v end end)
        local h=model:FindFirstChildOfClass("Humanoid")
        disable(view,"scales");scaleDefinitions={}
        for name in pairs(values)do local v=h and h:FindFirstChild(scales[name]);if v then scaleDefinitions[scales[name]]=v.Value end end
        model:Destroy()
        assert(alive and player.Character==ctx.character,"Character changed while loading proportions.")
        view.needsBind=true;reconcile(view)
    end
    function api.face(ctx,texture,id)
        local view=viewFor(ctx)
        local model=resolve(ctx,function(description)description.Face=id end)
        local head=model:FindFirstChild("Head");local decal=head and head:FindFirstChildOfClass("Decal")
        disable(view,"face")
        faceDefinition=decal and decal.Texture
        model:Destroy();view.needsBind=true;reconcile(view)
    end
    function api.hideAccessories(ctx)local view=viewFor(ctx);accessoryMode=true;view.needsBind=true;reconcile(view)end
    function api.allowAccessory(ctx,object,id)
        if accessoryAllowed[id]~=nil then return accessoryAllowed[id]end
        local model=resolve(ctx,function(description)
            description:SetAccessories({{AssetId=id,AccessoryType=object:IsA("Hat")and Enum.AccessoryType.Hat or object.AccessoryType,IsLayered=object:FindFirstChildWhichIsA("WrapLayer",true)~=nil}},true)
        end)
        local allowed=false
        local identity=accessoryIdentity(object)
        for _,candidate in ipairs(model:GetChildren())do if candidate:IsA("Accessory")or candidate:IsA("Hat")then
            local ok,asset=pcall(function()return candidate.SourceAssetId end)
            if ok and type(asset)=="number"and asset>0 then
                if asset==id then allowed=true end
            elseif identity and accessoryIdentity(candidate)==identity then allowed=true end
        end end
        -- The cached description can retain input IDs after native settings
        -- change the resulting model. Inspect actual generated accessories.
        model:Destroy();accessoryAllowed[id]=allowed
        return allowed
    end
    function api.accessory(ctx,object,id)
        local view=viewFor(ctx)
        owned(view,object,"accessories")
        addedAccessories[object]={id=id}
        view.needsBind=true;reconcile(view)
    end
    function api.adjustments(ctx,writes,geometry,meshId)
        local view=viewFor(ctx)
        local gate
        if geometry and meshId then gate=property(view,geometry,"MeshId",meshId,meshId,"accessory-adjustments")end
        for _,entry in ipairs(writes)do
            if entry.object:IsDescendantOf(ctx.character)then property(view,entry.object,entry.property,entry.baseline,entry.desired,"accessory-adjustments",gate)end
        end
        flush(view)
    end
    function api.fitAccessory(ctx,accessory)
        local view=viewFor(ctx)
        local handle=accessory:FindFirstChild("Handle")
        if not handle or accessory:FindFirstChildWhichIsA("WrapLayer",true)then return end
        for _,joint in ipairs(handle:GetChildren())do if joint:IsA("JointInstance")and joint.Part0==handle and joint.Part1 then
            local anchor=joint.Part1
            local native=original:FindFirstChild(anchor.Name)
            if native then for _,attachment in ipairs(handle:GetChildren())do if attachment:IsA("Attachment")then
                local target,base=anchor:FindFirstChild(attachment.Name),native:FindFirstChild(attachment.Name)
                if target and base and target:IsA("Attachment")and base:IsA("Attachment")then
                    local gate=view.index[anchor];gate=gate and (gate.MeshId or gate.Shape)
                    property(view,joint,"C1",base.CFrame,target.CFrame,"accessory-adjustments",gate)
                    break
                end
            end end end
        end end
        flush(view)
    end
    function api.restore(group)
        if not group then active=false end
        if not group or group=="body"then
            for name,object in pairs(bodyDefinitions)do object:Destroy();bodyDefinitions[name]=nil end
            for name,entry in pairs(r6Definitions)do if entry.desired then entry.desired:Destroy()end;r6Definitions[name]=nil end
            hipDefinition=nil
        end
        if not group or group=="skin"then skinDefinitions={}end
        if not group or group=="scales"then scaleDefinitions={}end
        if not group or group=="face"then faceDefinition=nil end
        if not group or group=="accessories"then accessoryMode=false end
        for _,view in pairs(views)do
            for _,record in ipairs(view.records)do
                if not group or record.group==group or (group=="body"and record.group:sub(1,5)=="body:")
                    or (group=="accessories"and record.group=="accessory-adjustments")then record.enabled=false end
            end
            flush(view)
            for object,ownedGroup in pairs(view.ownedObjects)do
                if not group or group==ownedGroup or (group=="body"and ownedGroup:sub(1,5)=="body:")then
                    object:Destroy();view.ownedObjects[object]=nil
                end
            end
            if not group or group=="accessories"then
                for _,object in ipairs(view.ownedAccessories)do object:Destroy()end
                view.ownedAccessories={}
            end
            if not group or group=="body"then
                for name,object in pairs(view.r6Added)do view.writing=true;object:Destroy();view.writing=false;view.r6Added[name]=nil end
            end
            for id,entry in pairs(view.synthetic)do if not group or entry.group==group or (group=="body"and entry.group:sub(1,5)=="body:")then
                view.writing=true;entry.object:Destroy();view.writing=false;view.synthetic[id]=nil
            end end
        end
    end
    function api.restorePart(region)
        local r6=r6Definitions[region];if r6 then if r6.desired then r6.desired:Destroy()end;r6Definitions[region]=nil end
        for _,name in ipairs(regions[region])do
            local source=bodyDefinitions[name];if source then source:Destroy();bodyDefinitions[name]=nil end
            for _,view in pairs(views)do
                disable(view,"body:"..name);disable(view,"body:"..region);flush(view)
                local object=view.r6Added[region];if object then view.writing=true;object:Destroy();view.writing=false;view.r6Added[region]=nil end
            end
        end
    end
    function api.reset()
        generation=generation+1
        for _,view in pairs(views)do view.retired=true;disconnect(view)end
        -- Definitions survive respawn; game source values never cross characters.
    end
    function api.isMapped()return original~=nil end
    function api.destroy()
        if not alive then return end
        api.restore();alive=false;generation=generation+1
        if added then added:Disconnect()end
        for _,view in pairs(views)do
            view.destroyConnection:Disconnect()
            disconnect(view)
            for _,object in ipairs(view.resources)do object:Destroy()end
        end
        for character in pairs(views)do
            if character:GetAttribute("LarpbloxAppearanceUserId")==player.UserId then
                character:SetAttribute("LarpbloxAppearanceUserId",nil);character:SetAttribute("LarpbloxAppearanceVersion",nil)
            end
        end
        for object,folder in pairs(metadataFolders)do if folder.Parent==object then folder:Destroy()end end
        metadataFolders={}
        views={}
        if original then original:Destroy()end
        for _,object in ipairs(originalHistory)do object:Destroy()end
        if account then account:Destroy()end
        for object,entry in pairs(tags)do pcall(function()if object:GetAttribute(tagAttribute)==entry.id then object:SetAttribute(tagAttribute,entry.previous)end end)end
        tags={}
    end
    return api
end
