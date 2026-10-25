-- Run in a Roblox client: loadstring(testSource)(mappingSource).
-- Detached real instances, native property events, and a controlled model factory.
return function(source)
    local cleanup={}
    local function tracked(object,method)
        cleanup[#cleanup+1]=function()object[method](object)end
        return object
    end
    local ok,result=pcall(function()
    local function settle()task.wait();task.wait()end
    local function rig()
        local model=Instance.new("Model")
        local humanoid=Instance.new("Humanoid");humanoid.RigType=Enum.HumanoidRigType.R15;humanoid.Parent=model
        for _,name in ipairs({"Head","UpperTorso","RightUpperLeg","HumanoidRootPart"})do
            local p=Instance.new("Part");p.Name=name;p.Size=Vector3.one;p.Anchored=true;p.CanCollide=false;p.CFrame=CFrame.new(1000000,1000000,1000000);p.Parent=model
        end
        local face=Instance.new("Decal");face.Name="face";face.Texture="rbxassetid://100";face.Parent=model.Head
        local scale=Instance.new("NumberValue");scale.Name="BodyHeightScale";scale.Value=1;scale.Parent=humanoid
        local colors=Instance.new("BodyColors");colors.Parent=model
        return model
    end
    local world=tracked(Instance.new("WorldModel"),"Destroy");world.Parent=workspace
    local native=tracked(rig(),"Destroy")
    local function accessory(id)
        local object=Instance.new("Accessory");object.AccessoryType=Enum.AccessoryType.Hat
        local handle=Instance.new("Part");handle.Name="Handle";handle.Parent=object
        local mesh=Instance.new("SpecialMesh");mesh.MeshId="rbxassetid://"..id;mesh.Parent=handle
        return object
    end
    local nativeHat=accessory(101);nativeHat.Parent=native
    local character=tracked(native:Clone(),"Destroy")
    local player={UserId=123,Character=character}
    local generated=0
    local function originalDescription()
        local d=Instance.new("HumanoidDescription")
        for _,region in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"})do d[region.."Color"]=native.Head.Color end
        return d
    end
    local players={GetHumanoidDescriptionFromUserIdAsync=function()return originalDescription()end,
        CreateHumanoidModelFromDescriptionAsync=function(_,d)
            assert(d.UseAvatarSettings,"all mapping templates must respect native game settings")
            generated+=1
            local model=native:Clone()
            model.Humanoid.BodyHeightScale.Value=math.min(d.HeightScale,1.25)
            model.Head.Color=d.HeadColor
            model:FindFirstChildOfClass("BodyColors").HeadColor3=d.HeadColor
            model.Head.face.Texture="rbxassetid://"..(d.Face==0 and 100 or d.Face)
            return model
        end}
    local env=setmetatable({game={GetService=function(_,name)assert(name=="Players");return players end},workspace=world,
        hookfunction=function()error("clone mapping must use native events")end,
        hookmetamethod=function()error("clone mapping must not install a global method hook")end},{__index=getfenv()})
    local chunk=assert(loadstring(source));setfenv(chunk,env)
    local map=tracked(chunk()(player),"destroy")
    local ctx={character=character,humanoid=character.Humanoid}
    local replacement=tracked(native:Clone(),"Destroy");replacement.RightUpperLeg.Shape=Enum.PartType.Ball;replacement.RightUpperLeg.Size=Vector3.new(2,2,2)
    map.body(ctx,{RightUpperLeg=replacement.RightUpperLeg},{"RightUpperLeg"})
    assert(character.RightUpperLeg.Shape==Enum.PartType.Ball,"original component maps on initial load")
    assert(generated==1,"account baseline is generated once")
    character.RightUpperLeg.Shape=Enum.PartType.Cylinder
    character.RightUpperLeg.Size=Vector3.new(3,4,5)
    character.RightUpperLeg.Transparency=0.6
    settle()
    replacement.RightUpperLeg.Size=Vector3.new(5,5,5)
    map.body(ctx,{RightUpperLeg=replacement.RightUpperLeg},{"RightUpperLeg"})
    assert(character.RightUpperLeg.Shape==Enum.PartType.Cylinder and character.RightUpperLeg.Size==Vector3.new(3,4,5)
        and math.abs(character.RightUpperLeg.Transparency-0.6)<0.0001,"extension revisions preserve game geometry, dimensions and fading")
    character.RightUpperLeg.Shape=Enum.PartType.Block;settle()
    assert(character.RightUpperLeg.Shape==Enum.PartType.Ball and math.abs(character.RightUpperLeg.Transparency-0.6)<0.0001,"restoring original identity resumes substitution without removing fading")
    local old=character.RightUpperLeg;old.Parent=nil;settle()
    assert(old.Shape==Enum.PartType.Block,"removal releases only our owned write")
    local new=native.RightUpperLeg:Clone();new.Parent=character;settle()
    assert(new.Shape==Enum.PartType.Ball,"instance replacement receives the same mapping")
    new.Shape=Enum.PartType.Cylinder;settle()
    map.restore("body")
    assert(new.Shape==Enum.PartType.Cylinder,"feature disable preserves current game geometry")
    new.Shape=Enum.PartType.Block;map.body(ctx,{RightUpperLeg=replacement.RightUpperLeg},{"RightUpperLeg"});settle()
    local clone=tracked(character:Clone(),"Destroy")
    clone.Parent=world;clone.RightUpperLeg.Transparency=1;settle()
    map.restore("body")
    assert(clone.RightUpperLeg.Shape==Enum.PartType.Block and clone.RightUpperLeg.Transparency==1,"clones inherit game source and preserve death visibility on disable")
    local red,blue=Color3.new(1,0,0),Color3.new(0,0,1)
    map.skin(ctx,red,"Head");character.Head.Color=blue;settle();map.skin(ctx,Color3.new(0,1,0),"Head")
    assert(character.Head.Color==blue,"extension color updates preserve game colors")
    map.face(ctx,"rbxassetid://200",200)
    character.Head.face.Texture="rbxassetid://300";settle();map.face(ctx,"rbxassetid://400",400)
    assert(character.Head.face.Texture=="rbxassetid://300","face and makeup overrides survive extension updates")
    character.Head.face.Texture="https://www.roblox.com/asset/?id=100";settle()
    assert(character.Head.face.Texture=="rbxassetid://400","equivalent original content resumes face mapping")
    map.scales(ctx,{height=2});assert(character.Humanoid.BodyHeightScale.Value==1.25,"native scale restriction wins")
    character.Humanoid.BodyHeightScale.Value=0.75;settle();map.scales(ctx,{height=1.1})
    assert(character.Humanoid.BodyHeightScale.Value==0.75,"game scale survives extension update")
    map.destroy();settle()
    assert(character.Head.Color==blue and character.Head.face.Texture:match("100$")
        and character.Humanoid.BodyHeightScale.Value==0.75,"destroy restores latest game state")
    local nextMap=tracked(chunk()(player),"destroy")
    nextMap.body(ctx,{RightUpperLeg=replacement.RightUpperLeg},{"RightUpperLeg"})
    replacement.Head:FindFirstChildOfClass("Decal"):Destroy()
    nextMap.body(ctx,{Head=replacement.Head},{"Head"})
    assert(character.Head.face.Texture=="","a replacement without a face suppresses only the original face")
    character.Head.face.Texture="rbxassetid://300";settle()
    assert(character.Head.face.Texture=="rbxassetid://300","game face additions remain visible when the Larp face is absent")
    nextMap.destroy()
    assert(new.Shape==Enum.PartType.Block,"interface reload does not capture an old replacement as original")
    local accessoriesMap=tracked(chunk()(player),"destroy")
    local larpHat=accessory(202);larpHat.Parent=character
    assert(not accessoriesMap.allowAccessory(ctx,larpHat,202),"native accessory exclusion is checked against generated instances")
    accessoriesMap.hideAccessories(ctx);accessoriesMap.accessory(ctx,larpHat,202);settle()
    local accountHat
    for _,object in ipairs(character:GetChildren())do if object:IsA("Accessory")and object~=larpHat then accountHat=object end end
    assert(accountHat.Handle.LocalTransparencyModifier==1 and larpHat.Handle.LocalTransparencyModifier==0,"native accessory category maps to its Larp equivalent")
    local uniformHat=accessory(303);uniformHat.Parent=character;settle()
    assert(uniformHat.Handle.LocalTransparencyModifier==0 and accountHat.Handle.LocalTransparencyModifier==0
        and larpHat.Handle.LocalTransparencyModifier==1,"game category additions preserve the entire game category")
    accessoriesMap.accessory(ctx,larpHat,202);settle()
    assert(larpHat.Handle.LocalTransparencyModifier==1,"extension accessory update retains game category changes")
    uniformHat:Destroy();settle()
    assert(accountHat.Handle.LocalTransparencyModifier==1 and larpHat.Handle.LocalTransparencyModifier==0,"category restoration resumes mapping")
    local handle=larpHat.Handle
    local geometry=handle:FindFirstChildOfClass("SpecialMesh")
    accessoriesMap.adjustments(ctx,{{object=handle,property="Size",baseline=Vector3.new(4,1.2,2),desired=Vector3.new(5,5,5)}},geometry,geometry.MeshId)
    handle.Size=Vector3.new(7,8,9);settle()
    accessoriesMap.adjustments(ctx,{{object=handle,property="Size",baseline=Vector3.new(4,1.2,2),desired=Vector3.new(6,6,6)}},geometry,geometry.MeshId)
    assert(handle.Size==Vector3.new(7,8,9),"extension accessory metadata preserves game transforms")
    accountHat.Handle:FindFirstChildOfClass("SpecialMesh").MeshId="rbxassetid://404";settle()
    assert(accountHat.Handle.LocalTransparencyModifier==0 and larpHat.Handle.LocalTransparencyModifier==1,"accessory property edits have the same identity rule as replacement")
    accountHat.Handle:FindFirstChildOfClass("SpecialMesh").MeshId="rbxassetid://101";settle()
    local accessoryClone=tracked(character:Clone(),"Destroy");accessoryClone.Parent=world;settle();accessoriesMap.restore("accessories")
    assert(#accessoryClone:GetChildren()<#character:GetChildren(),"disable removes only cloned Larp resources and reveals cloned native accessories")
    accessoriesMap.destroy();larpHat:Destroy();accessoryClone:Destroy()
    native.Humanoid.RigType=Enum.HumanoidRigType.R6
    local nativeMesh=Instance.new("CharacterMesh");nativeMesh.BodyPart=Enum.BodyPart.RightLeg;nativeMesh.MeshId=100;nativeMesh.Parent=native
    local r6=tracked(native:Clone(),"Destroy");player.Character=r6
    local r6ctx={character=r6,humanoid=r6.Humanoid}
    local r6map=tracked(chunk()(player),"destroy")
    local r6desired=tracked(native:Clone(),"Destroy");r6desired.CharacterMesh.MeshId=200
    r6map.r6(r6ctx,r6desired,"RightLeg")
    assert(r6.CharacterMesh.MeshId==200,"R6 native region maps")
    r6.CharacterMesh.MeshId=300;settle();r6desired.CharacterMesh.MeshId=400;r6map.r6(r6ctx,r6desired,"RightLeg")
    assert(r6.CharacterMesh.MeshId==300,"R6 game package survives extension updates")
    r6.CharacterMesh.MeshId=100;settle();assert(r6.CharacterMesh.MeshId==400,"R6 original restoration resumes mapping")
    r6map.restorePart("RightLeg");assert(r6.CharacterMesh.MeshId==100,"R6 region restore releases mapping")
    r6map.destroy();r6:Destroy();r6desired:Destroy()
    character:Destroy();native:Destroy();replacement:Destroy();clone:Destroy();old:Destroy()
    return "PASS: native restrictions, game overrides, extension revisions, original restoration, replacement, clone provenance, disable and reload"
    end)
    for index=#cleanup,1,-1 do pcall(cleanup[index])end
    assert(ok,result)
    return result
end
