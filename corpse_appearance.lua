-- Visual-only corpse adaptation. Ownership must be explicit; never match by proximity.
return function(getSource,log,isEnabled)
    local Players=game:GetService("Players")
    local alive=true
    local bodies={}
    local sources={}
    local playerConnections={}
    local markers=setmetatable({}, {__mode="k"})
    local function mark(character,userId)
        if not markers[character]then markers[character]={previous=character:GetAttribute("LarpbloxSourceUserId"),written=userId}end
        character:SetAttribute("LarpbloxSourceUserId",userId)
    end
    local function track(player)
        if player.Character then mark(player.Character,player.UserId)end
        playerConnections[#playerConnections+1]=player.CharacterAdded:Connect(function(character)mark(character,player.UserId)end)
    end
    for _,player in ipairs(Players:GetPlayers())do track(player)end
    playerConnections[#playerConnections+1]=Players.PlayerAdded:Connect(track)
    local bodyNames={Head=true,Torso=true,["Left Arm"]=true,["Right Arm"]=true,["Left Leg"]=true,["Right Leg"]=true,
        UpperTorso=true,LowerTorso=true,LeftUpperArm=true,LeftLowerArm=true,LeftHand=true,RightUpperArm=true,RightLowerArm=true,RightHand=true,
        LeftUpperLeg=true,LeftLowerLeg=true,LeftFoot=true,RightUpperLeg=true,RightLowerLeg=true,RightFoot=true}
    local visual={SpecialMesh=true,Decal=true,Texture=true,SurfaceAppearance=true}
    local function emit(event,data)if log then log(event,data)end end
    local function owner(model)
        local id=model:GetAttribute("LarpbloxSourceUserId") or model:GetAttribute("LarpbloxAppearanceUserId") or model:GetAttribute("UserId") or model:GetAttribute("PlayerId")
        if tonumber(id)then return Players:GetPlayerByUserId(tonumber(id))end
        local value=model:FindFirstChild("PlayerName") or model:FindFirstChild("Player")
        if value and value:IsA("ObjectValue") and value.Value and value.Value:IsA("Player")then return value.Value end
        if value and value:IsA("StringValue")then return Players:FindFirstChild(value.Value)end
    end
    local function meshId(part)
        if part:IsA("MeshPart")then return part.MeshId end
        local mesh=part:FindFirstChildOfClass("SpecialMesh")
        return mesh and mesh.MeshId
    end
    local function cloneVisual(part)
        local copy=part:Clone()
        if not copy then return end
        for _,child in ipairs(copy:GetChildren())do if not visual[child.ClassName]then child:Destroy()end end
        return copy
    end
    local function discardSource(id)
        local previous=sources[id]
        if not previous then return end
        for _,connection in ipairs(previous.connections or {})do connection:Disconnect()end
        for _,object in ipairs(previous.resources)do object:Destroy()end
        sources[id]=nil
    end
    local function sourceFor(id,refresh,force)
        if isEnabled and not isEnabled(id)then discardSource(id);return nil end
        local previous=sources[id]
        if previous and not refresh then return previous end
        local source=getSource(id)
        if not source then return previous end
        if source.mapped then
            discardSource(id)
            local mapped={character=source.character,origin=source.character,version=source.version,mapped=true,attach=source.attach,resources={},connections={}}
            sources[id]=mapped;return mapped
        end
        if previous and not force and previous.origin==source.character and previous.version==source.version then return previous end
        local model=Instance.new("Model")
        local frozen={character=model,origin=source.character,version=source.version,
            colors=table.clone(source.colors or {}),originalClothes=table.clone(source.originalClothes or {}),
            parts={},hidden={},resources={model},connections={}}
        local ok,err=pcall(function()
            for _,object in ipairs(source.character:GetChildren())do
                local copy
                if object:IsA("BasePart") and bodyNames[object.Name]then copy=cloneVisual(object)
                elseif object:IsA("Accessory") or object:IsA("Hat") or object:IsA("Clothing")
                    or object:IsA("ShirtGraphic") or object:IsA("CharacterMesh")then copy=object:Clone()end
                if copy then
                    for _,child in ipairs(copy:GetDescendants())do
                        if child:IsA("LuaSourceContainer")then child:Destroy()end
                    end
                    copy.Parent=model
                end
            end
            -- A cloned accessory's outside joint references would disappear
            -- with the old character. Rebind only the cached attachment metadata.
            for _,object in ipairs(model:GetChildren())do
                if object:IsA("Accessory") or object:IsA("Hat")then
                    local original=source.character:FindFirstChild(object.Name)
                    local handle=object:FindFirstChild("Handle")
                    local originalHandle=original and original:FindFirstChild("Handle")
                    if handle and originalHandle then
                        for _,joint in ipairs(handle:GetChildren())do if joint:IsA("JointInstance")then joint:Destroy()end end
                        for _,joint in ipairs(originalHandle:GetChildren())do
                            if joint:IsA("JointInstance") and joint.Part0==originalHandle and joint.Part1 then
                                local anchor=model:FindFirstChild(joint.Part1.Name)
                                if anchor then
                                    local weld=Instance.new("Weld");weld.Part0=handle;weld.Part1=anchor
                                    weld.C0=joint.C0;weld.C1=joint.C1;weld.Parent=handle
                                    break
                                end
                            end
                        end
                    end
                end
            end
            for name,part in pairs(source.parts or {})do
                local copy=cloneVisual(part)
                if copy then frozen.parts[name]=copy;frozen.resources[#frozen.resources+1]=copy end
            end
            if source.head then
                frozen.head=cloneVisual(source.head)
                if frozen.head then frozen.resources[#frozen.resources+1]=frozen.head end
            end
            for _,entry in ipairs(source.hidden or {})do
                local original=entry.object:Clone()
                if original then frozen.hidden[#frozen.hidden+1]={object=original};frozen.resources[#frozen.resources+1]=original end
            end
        end)
        if not ok then
            for _,object in ipairs(frozen.resources)do object:Destroy()end
            emit("corpse_source_failed",{peerId=id,detail=tostring(err)})
            return previous
        end
        discardSource(id);sources[id]=frozen
        local refreshQueued=false
        local function refreshWhenAlive()
            if refreshQueued then return end
            local humanoid=source.character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health<=0 then return end
            refreshQueued=true
            task.defer(function()
                refreshQueued=false
                if not alive or sources[id]~=frozen then return end
                local current=source.character:FindFirstChildOfClass("Humanoid")
                if current and current.Health>0 then sourceFor(id,true,true)end
            end)
        end
        frozen.connections[#frozen.connections+1]=source.character.DescendantAdded:Connect(function(object)
            if (object.Parent==source.character and (object:IsA("Accessory") or object:IsA("Hat")
                or object:IsA("Clothing") or object:IsA("ShirtGraphic")))
                or (object:IsA("JointInstance") and object:FindFirstAncestorOfClass("Accessory"))then refreshWhenAlive()end
        end)
        for _,accessory in ipairs(source.character:GetChildren())do
            if accessory:IsA("Accessory") or accessory:IsA("Hat")then
                local handle=accessory:FindFirstChild("Handle")
                if handle then for _,joint in ipairs(handle:GetChildren())do
                    if joint:IsA("JointInstance") and (not joint.Part0 or not joint.Part1)then
                        frozen.connections[#frozen.connections+1]=joint:GetPropertyChangedSignal("Part0"):Connect(refreshWhenAlive)
                        frozen.connections[#frozen.connections+1]=joint:GetPropertyChangedSignal("Part1"):Connect(refreshWhenAlive)
                    end
                end end
            end
        end
        local count=0
        for _,object in ipairs(model:GetChildren())do if object:IsA("Accessory") or object:IsA("Hat")then local handle=object:FindFirstChild("Handle");if handle and handle.Transparency<1 then count=count+1 end end end
        emit("corpse_source_cached",{peerId=id,accessories=count})
        return frozen
    end
    local function copyVisual(target,source,size,transparency)
        -- Keep the corpse's existing parts, constraints, transforms and velocities.
        local frame=target.CFrame
        if transparency==nil then transparency=target.Transparency end
        if target:IsA("MeshPart") and source:IsA("MeshPart")then target:ApplyMesh(source)end
        for _,child in ipairs(target:GetChildren())do if visual[child.ClassName]then child:Destroy()end end
        for _,child in ipairs(source:GetChildren())do if visual[child.ClassName]then child:Clone().Parent=target end end
        if target:IsA("Part") and source:IsA("Part")then target.Shape=source.Shape end
        target.Size=size or source.Size
        target.Color=source.Color
        target.Material=source.Material
        target.Reflectance=source.Reflectance
        target.Transparency=transparency
        target.CFrame=frame
    end
    local function restore(record)
        for target,original in pairs(record.originals)do
            if target.Parent then pcall(copyVisual,target,original,original.Size)end
            original:Destroy()
        end
        for target,value in pairs(record.hidden)do if target.Parent then target.LocalTransparencyModifier=value end end
        for _,object in ipairs(record.added)do object:Destroy()end
        for _,object in ipairs(record.detached)do object.Parent=record.model end
        record.originals={};record.added={};record.detached={};record.hidden={};record.applied=false
    end
    local function apply(model,record)
        if not alive or record.applied or not model:IsDescendantOf(workspace) or Players:GetPlayerFromCharacter(model)then return end
        local player=owner(model)
        if not player then return end
        record.userId=player.UserId
        local source=sourceFor(player.UserId)
        if not source or source.character==model then return end
        if source.mapped then
            -- The mapping adopts the body's actual state. Never repaint it from
            -- a frozen saved outfit, which would erase game/death changes.
            record.applied=source.attach(model)or record.applied
            return
        end
        local head=model:FindFirstChild("Head")
        if not head or not head:IsA("BasePart")then return end
        -- Death systems may remove the Humanoid; an explicit owner and matching rig suffice.
        for _,part in ipairs(source.character:GetChildren())do
            if part:IsA("BasePart") and bodyNames[part.Name] and not model:FindFirstChild(part.Name)then return end
        end
        local factor=Vector3.one
        for _,part in ipairs(model:GetChildren())do
            if part:IsA("BasePart") and not bodyNames[part.Name] and part.Name~="HumanoidRootPart"then
                local id=meshId(part)
                for _,hidden in ipairs(source.hidden or {})do
                    local original=hidden.object:FindFirstChild("Handle")
                    if id and original and meshId(original)==id then
                        factor=part.Size/original.Size
                        record.hidden[part]=part.LocalTransparencyModifier
                        part.LocalTransparencyModifier=1
                        break
                    end
                end
            end
        end
        record.applied=true
        local copiedAccessories=0
        local ok,err=pcall(function()
            local replacedKinds={}
            for _,part in ipairs(source.character:GetChildren())do
                if part:IsA("BasePart") and bodyNames[part.Name]then
                    local target=model:FindFirstChild(part.Name)
                    if target and target:IsA("BasePart")then
                        local baseline=(source.parts or {})[part.Name] or (part.Name=="Head" and source.head)
                        local size=target.Size
                        local ratio=baseline and size/baseline.Size or Vector3.one
                        local color,material,reflectance=target.Color,target.Material,target.Reflectance
                        local transparency=part.Transparency
                        if not baseline or target.Transparency~=baseline.Transparency then transparency=math.max(transparency,target.Transparency)end
                        local effectColor=(source.colors or {})[part.Name] and color~=source.colors[part.Name]
                        local saved=cloneVisual(target)
                        if saved then record.originals[target]=saved end
                        local texture=target:IsA("MeshPart") and target.TextureID
                        local removedTexture=baseline and baseline:IsA("MeshPart") and texture~=baseline.TextureID and texture==""
                        local removedFace=baseline and baseline:FindFirstChildOfClass("Decal") and not target:FindFirstChildOfClass("Decal")
                        copyVisual(target,part,part.Size*ratio,transparency)
                        if effectColor then target.Color=color end
                        if baseline and material~=baseline.Material then target.Material=material end
                        if baseline and reflectance~=baseline.Reflectance then target.Reflectance=reflectance end
                        if removedTexture then target.TextureID=texture end
                        if removedFace then for _,child in ipairs(target:GetChildren())do if child:IsA("Decal")then child:Destroy()end end end
                    end
                elseif part:IsA("Accessory") or part:IsA("Hat")then
                    local handle=part:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") and handle.Transparency<1 then
                        local anchor,offset
                        for _,joint in ipairs(handle:GetChildren())do
                            if joint:IsA("JointInstance")then
                                if joint.Part0==handle and joint.Part1 and bodyNames[joint.Part1.Name]then
                                    anchor=model:FindFirstChild(joint.Part1.Name);offset=joint.C1*joint.C0:Inverse();break
                                end
                            end
                        end
                        if anchor and offset then
                            local copy=part:Clone()
                            for _,child in ipairs(copy:GetDescendants())do
                                if child:IsA("LuaSourceContainer") or child:IsA("JointInstance") or child:IsA("Constraint")then child:Destroy()
                                elseif child:IsA("BasePart")then child.Anchored=false;child.CanCollide=false;child.CanTouch=false;child.CanQuery=false;child.Massless=true;child.LocalTransparencyModifier=0;child.Size=child.Size*factor
                                elseif child:IsA("SpecialMesh")then child.Scale=child.Scale*factor end
                            end
                            local clonedHandle=copy:FindFirstChild("Handle")
                            local originalFrame=clonedHandle.CFrame
                            local destination=anchor.CFrame*(CFrame.new(offset.Position*factor)*offset.Rotation)
                            for _,child in ipairs(copy:GetDescendants())do
                                if child:IsA("BasePart")then
                                    child.CFrame=destination*originalFrame:ToObjectSpace(child.CFrame)
                                    local weld=Instance.new("WeldConstraint");weld.Part0=anchor;weld.Part1=child;weld.Parent=child
                                end
                            end
                            copy.Parent=model;record.added[#record.added+1]=copy;copiedAccessories=copiedAccessories+1
                        end
                    end
                elseif part:IsA("Clothing") or part:IsA("ShirtGraphic") or part:IsA("CharacterMesh")then
                    local kind=part.ClassName
                    local old=model:FindFirstChildOfClass(kind)
                    -- Preserve a death effect that deliberately removed existing clothing.
                    if old or replacedKinds[kind] or ((source.originalClothes or {})[kind] or 0)==0 then
                        if not replacedKinds[kind]then
                            for _,existing in ipairs(model:GetChildren())do
                                if existing:IsA(kind)then existing.Parent=nil;record.detached[#record.detached+1]=existing end
                            end
                            replacedKinds[kind]=true
                        end
                        local copy=part:Clone();copy.Parent=model;record.added[#record.added+1]=copy
                    end
                end
            end
        end)
        if not ok then restore(record)end
        emit(ok and "corpse_applied" or "corpse_failed",{peerId=player.UserId,detail=ok and model.Name or tostring(err),waitMs=math.floor((os.clock()-record.createdAt)*1000),accessories=copiedAccessories})
    end
    local function consider(model)
        if not model or not model:IsA("Model") or bodies[model] or Players:GetPlayerFromCharacter(model) or not owner(model)then return end
        local record={model=model,originals={},added={},detached={},hidden={},createdAt=os.clock()};bodies[model]=record
        record.removed=model.Destroying:Connect(function()
            for _,original in pairs(record.originals)do original:Destroy()end
            for _,original in ipairs(record.detached)do original:Destroy()end
            record.removed:Disconnect();bodies[model]=nil
        end)
        apply(model,record)
    end
    local added=workspace.DescendantAdded:Connect(function(object)
        if object:IsA("Model")then task.defer(consider,object)
        elseif object.Name=="PlayerName" or object.Name=="Player" or (object:IsA("BasePart") and bodies[object.Parent])then
            local model=object.Parent
            task.defer(function()if bodies[model]then apply(model,bodies[model])else consider(model)end end)
        end
    end)
    for _,object in ipairs(workspace:GetDescendants())do
        if object:IsA("StringValue") and object.Name=="PlayerName" or object:IsA("ObjectValue") and object.Name=="Player"then consider(object.Parent)end
    end
    return {refresh=function(userId)
        if userId then sourceFor(userId,true)
        else for _,player in ipairs(Players:GetPlayers())do sourceFor(player.UserId,true)end end
        for model,record in pairs(bodies)do
            if not userId or record.userId==userId then
                if record.applied and not sourceFor(record.userId)then restore(record)end
                apply(model,record)
            end
        end
    end,destroy=function()
        alive=false;added:Disconnect()
        for _,connection in ipairs(playerConnections)do connection:Disconnect()end
        for character,marker in pairs(markers)do pcall(function()if character:GetAttribute("LarpbloxSourceUserId")==marker.written then character:SetAttribute("LarpbloxSourceUserId",marker.previous)end end)end
        for _,record in pairs(bodies)do
            restore(record)
            record.removed:Disconnect()
        end
        bodies={}
        for id in pairs(sources)do discardSource(id)end
    end}
end
