-- Run in a Roblox client: loadstring(testSource)(avatarSource,mappingSource).
-- Production avatar methods, real instances/events, and deterministic native rules.
return function(avatarSource,mappingSource)
    local cleanup={}
    local function tracked(object,method)
        cleanup[#cleanup+1]=function()object[method](object)end
        return object
    end
    local ok,result=pcall(function()
    local function settle()task.wait();task.wait()end
    local names={"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand",
        "LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot","HumanoidRootPart"}
    local restricted=false
    local function generate(description)
        assert(description.UseAvatarSettings,"avatar generation must retain native game restrictions")
        local model=Instance.new("Model")
        local humanoid=Instance.new("Humanoid");humanoid.RigType=Enum.HumanoidRigType.R15;humanoid.Parent=model
        for _,name in ipairs(names)do
            local part=Instance.new("Part");part.Name=name;part.Anchored=true;part.Size=Vector3.one
            if name:sub(1,5)=="Right"and (name:find("Leg")or name=="RightFoot")then
                part.Shape=restricted and Enum.PartType.Cylinder or description.RightLeg~=0 and Enum.PartType.Ball or Enum.PartType.Block
            end
            part.Parent=model
        end
        return model
    end
    local function original()
        local d=Instance.new("HumanoidDescription");d.UseAvatarSettings=true;return d
    end
    local players={GetHumanoidDescriptionFromUserIdAsync=function()return original()end,
        CreateHumanoidModelFromDescriptionAsync=function(_,d)return generate(d)end}
    local services={Players=players,HttpService=game:GetService("HttpService"),
        ContentProvider={PreloadAsync=function()end},MarketplaceService={GetProductInfoAsync=function()return {AssetTypeId=31}end}}
    local env=setmetatable({game={GetService=function(_,name)assert(services[name],name);return services[name]end},getgenv=false,hookfunction=false},{__index=getfenv()})
    local mappingChunk=assert(loadstring(mappingSource));setfenv(mappingChunk,env);local mapping=mappingChunk()
    local avatarChunk=assert(loadstring(avatarSource));setfenv(avatarChunk,env);local create=avatarChunk()
    local characterEvent=Instance.new("BindableEvent")
    local d=original();local character=tracked(generate(d),"Destroy");d:Destroy()
    local player={UserId=123,Character=character,CharacterAdded=characterEvent.Event,FindFirstChildOfClass=function()end}
    local api=tracked(create(player,nil,nil,true,nil,mapping),"destroy")
    api.applyBodyPart("RightLeg",139607718)
    assert(character.RightUpperLeg.Shape==Enum.PartType.Ball,"avatar controller applies an allowed mapped body")
    character.RightUpperLeg.Shape=Enum.PartType.Cylinder
    character.RightUpperLeg.Size=Vector3.new(3,4,5)
    character.RightUpperLeg.Transparency=1
    settle()
    api.applyBodyPart("RightLeg",139607719)
    api.reapplySaved();settle()
    assert(character.RightUpperLeg.Shape==Enum.PartType.Cylinder and character.RightUpperLeg.Size==Vector3.new(3,4,5)
        and character.RightUpperLeg.Transparency==1,"revision and saved replay both retain game overrides")
    character.RightUpperLeg.Shape=Enum.PartType.Block;settle()
    assert(character.RightUpperLeg.Shape==Enum.PartType.Ball and character.RightUpperLeg.Transparency==1,"restoration maps identity without clearing a death effect")
    local d2=original();local fresh=tracked(generate(d2),"Destroy");d2:Destroy()
    player.Character=fresh;characterEvent:Fire(fresh);settle();api.reapplySaved()
    assert(fresh.RightUpperLeg.Shape==Enum.PartType.Ball,"respawn establishes fresh game state")
    api.restore();settle()
    assert(fresh.RightUpperLeg.Shape==Enum.PartType.Block and character.RightUpperLeg.Transparency==1,"disable restores both characters without undoing effects")
    api.destroy()
    restricted=true
    local d3=original();local enforced=tracked(generate(d3),"Destroy");d3:Destroy();player.Character=enforced
    local nextApi=tracked(create(player,nil,nil,true,nil,mapping),"destroy")
    nextApi.applyBodyPart("RightLeg",139607718)
    assert(enforced.RightUpperLeg.Shape==Enum.PartType.Cylinder,"native forced body wins over Korblox selection")
    nextApi.destroy()
    character:Destroy();fresh:Destroy();enforced:Destroy();characterEvent:Destroy()
    return "PASS: production body API, extension revisions, saved replay, respawn, disable and native forced body"
    end)
    for index=#cleanup,1,-1 do pcall(cleanup[index])end
    assert(ok,result)
    return result
end
