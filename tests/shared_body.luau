-- Run in a Roblox client: loadstring(testSource)(avatarSource).
-- A local synthetic model factory verifies batching without HTTP or live edits.
return function(source)
    local parts={"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand",
        "RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot",
        "RightUpperLeg","RightLowerLeg","RightFoot"}
    local function rig(size)
        local model=Instance.new("Model")
        local h=Instance.new("Humanoid");h.RigType=Enum.HumanoidRigType.R15;h.Parent=model
        for _,name in ipairs({"BodyHeightScale","BodyWidthScale","BodyDepthScale","HeadScale","BodyTypeScale","BodyProportionScale"})do
            local value=Instance.new("NumberValue");value.Name=name
            value.Value=(name=="BodyTypeScale" or name=="BodyProportionScale") and 0 or 1;value.Parent=h
        end
        for _,name in ipairs(parts)do
            local p=Instance.new("MeshPart");p.Name=name;p.Anchored=true;p.Size=Vector3.new(size,size,size);p.Parent=model
        end
        local root=Instance.new("Part");root.Name="HumanoidRootPart";root.Anchored=true;root.Parent=model
        return model
    end
    local character=rig(1)
    local event=Instance.new("BindableEvent")
    local p={Character=character,CharacterAdded=event.Event,FindFirstChildOfClass=function()end}
    local generated=0
    local players={CreateHumanoidModelFromDescriptionAsync=function(_,description)
        generated=generated+1
        assert(description.Head==1 and description.Torso==2 and description.LeftArm==3 and description.RightArm==4
            and description.LeftLeg==5 and (description.RightLeg==6 or description.RightLeg==0),"all six regions must share one request")
        return rig(description.RightLeg==0 and 1 or 2)
    end}
    local environment=setmetatable({game={GetService=function(_,name)
        if name=="Players"then return players end
        if name=="HttpService"then return game:GetService(name)end
        if name=="ContentProvider"then return {PreloadAsync=function()end}end
        error("batch body must not issue extra metadata/preload requests: "..name)
    end}},{__index=getfenv()})
    local chunk=assert(loadstring(source));setfenv(chunk,environment)
    local failNext,meshChecks=false,0
    local diagnostics={run=function(operation,_,callback,...)
        if operation=="MeshPart.ApplyMesh" then
            assert(character.Humanoid.AutomaticScalingEnabled==false,"body replacement must pause automatic scaling")
            meshChecks=meshChecks+1
            if failNext then failNext=false;error("Fixture blocked mesh update")end
        end
        return callback(...)
    end}
    local api=chunk()(p,nil,nil,true,diagnostics)
    local body={Head=1,Torso=2,LeftArm=3,RightArm=4,LeftLeg=5,RightLeg=6}
    local head=character.Head
    api.applyBodyParts(body,{height=1})
    assert(generated==1 and character.Head==head and head.Size==Vector3.new(2,2,2),"one generation applies without replacing live parts")
    api.applyBodyParts(body,{height=1})
    assert(generated==1,"identical body reuses its cached template")
    body.RightLeg=0
    api.applyBodyParts(body,{height=1})
    assert(generated==2 and character.RightUpperLeg.Size==Vector3.new(1,1,1),"unequip restores the default leg")
    body.RightLeg=6
    api.applyBodyParts(body,{height=1})
    assert(generated==2 and character.RightUpperLeg.Size==Vector3.new(2,2,2),"re-equip reuses the loaded body")
    body.RightLeg=0
    api.applyBodyParts(body,{height=1})
    assert(generated==2 and character.RightUpperLeg.Size==Vector3.new(1,1,1),"second unequip avoids Roblox loading")
    body.RightLeg=6
    api.applyBodyParts(body,{height=1.1})
    assert(generated==3,"changed scales invalidate the body cache")
    local humanoid=character.Humanoid
    assert(meshChecks>0 and humanoid.AutomaticScalingEnabled==false,"mapped bodies keep native scaling disabled")
    api.setScales({height=1.2})
    assert(generated==4 and humanoid.AutomaticScalingEnabled==false,"scale changes regenerate the mapped body")
    failNext=true
    local applied=pcall(api.applyBodyParts,body,{height=1.2})
    assert(not applied and humanoid.AutomaticScalingEnabled==false,"rollback preserves the prior scaling flag")
    assert(head.Size==Vector3.new(2,2,2),"rollback preserves the previous body")
    api.restoreBody()
    assert(humanoid.AutomaticScalingEnabled==true and head.Size==Vector3.new(1,1,1),"undo restores native body and original scaling")
    api.applyBodyParts(body,{height=1.2})
    api.destroy()
    assert(head.Size==Vector3.new(1,1,1) and humanoid.AutomaticScalingEnabled==true,"destroy restores original appearance and scaling")
    humanoid.AutomaticScalingEnabled=false
    local disabled=chunk()(p,nil,nil,true,diagnostics)
    disabled.applyBodyParts(body,{height=1.2})
    disabled.restoreBody()
    assert(humanoid.AutomaticScalingEnabled==false,"a natively disabled scaler stays disabled on undo")
    disabled.destroy()
    character:Destroy();event:Destroy()
    return "PASS: one generation for six regions, cache reuse, scale invalidation, part identity, atomic scaling and restoration"
end
