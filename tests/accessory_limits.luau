-- Run in a Roblox client: loadstring(testSource)()(avatarSource).
return function(source)
    local model=Instance.new("Model")
    local humanoid=Instance.new("Humanoid");humanoid.RigType=Enum.HumanoidRigType.R6;humanoid.Parent=model
    for _,name in ipairs({"Head","Torso","Left Arm","Right Arm","Left Leg","Right Leg","HumanoidRootPart"})do
        local part=Instance.new("Part");part.Name=name;part.Parent=model
        if name=="Head"then local a=Instance.new("Attachment");a.Name="HatAttachment";a.Parent=part;Instance.new("SpecialMesh").Parent=part end
    end
    local gui=Instance.new("Folder")
    local changed=Instance.new("BindableEvent")
    local player={Name="Fixture",UserId=-1,Character=model,CharacterAdded=changed.Event,
        FindFirstChildOfClass=function(_,name)if name=="PlayerGui"then return gui end end,
        HasAppearanceLoaded=function()return true end}
    local kind=Enum.AccessoryType.Hat
    local services={ContentProvider={PreloadAsync=function()end},HttpService=game:GetService("HttpService"),Players={CreateHumanoidModelFromDescriptionAsync=function()
        local clone=model:Clone()
        for _,child in ipairs(clone:GetChildren())do if child:IsA("Accessory")then child:Destroy()end end
        return clone
    end}}
    local fakeGame={GetService=function(_,name)return services[name]end,GetObjects=function()
        local accessory=Instance.new("Accessory");accessory.Name=kind.Name;accessory.AccessoryType=Enum.AccessoryType.Unknown
        local handle=Instance.new("Part");handle.Name="Handle";handle.Parent=accessory
        local a=Instance.new("Attachment");a.Name="HatAttachment";a.Parent=handle
        return {accessory}
    end}
    local chunk=assert(loadstring(source));setfenv(chunk,setmetatable({game=fakeGame},{__index=getfenv()}))
    local api=chunk()(player,nil,nil,true)
    local ok,result=pcall(function()
        local kinds={"Hat","Hair","Face","Neck","Shoulder","Front","Back","Waist","TShirt","Shirt","Pants","Jacket","Sweater","Shorts","LeftShoe","RightShoe","DressSkirt","Eyebrow","Eyelash"}
        local types={8,41,42,43,44,45,46,47,64,65,66,67,68,69,70,71,72,76,77}
        local id=100000
        for index,name in ipairs(kinds)do
            kind=Enum.AccessoryType[name]
            for _=1,20 do id=id+1;api.equipAccessory(id,nil,types[index])end
            local before=#api.listAccessories();id=id+1
            assert(not pcall(api.equipAccessory,id,nil,types[index]),"the 21st "..name.." must be rejected")
            assert(#api.listAccessories()==before,"rejected accessories must not alter the outfit")
        end
        assert(#api.listAccessories()==380,"all19 types need separate20-item budgets")
        api.applyBodyPart("Head",0)
        assert(#api.listAccessories()==380,"body changes must preserve a full accessory outfit")
        local recreated=chunk()(player,nil,nil,true)
        assert(#recreated.getSettings().accessories==380,"saved accessories must not be truncated to20")
        assert(recreated.getSettings().accessoryKinds[tostring(id-1)]=="Eyelash","legacy accessory categories survive saving")
        recreated.destroy()
        api.restore();kind=Enum.AccessoryType.Hat;api.equipAccessory(id+1,nil,8)
        assert(#api.listAccessories()==1,"restore leaves the editor usable")
        return "PASS: 20 of each19 accessory types, body changes, rejection21 and saved380-item outfits"
    end)
    api.destroy();model:Destroy();gui:Destroy();changed:Destroy()
    assert(ok,result);return result
end

