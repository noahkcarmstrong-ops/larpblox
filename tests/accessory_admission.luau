-- Production accessory loading with raw catalog types and native restrictions.
return function(avatarSource,mappingSource)
    local cleanup={}
    local function own(object,method)
        cleanup[#cleanup+1]=function()object[method or "Destroy"](object)end;return object
    end
    local ok,result=pcall(function()
        local function raw()
            local a=Instance.new("Accessory");a.Name="Catalog Hair";a.AccessoryType=Enum.AccessoryType.Unknown
            local h=Instance.new("Part");h.Name="Handle";h.Parent=a
            local mesh=Instance.new("SpecialMesh");mesh.MeshId="rbxassetid://100";mesh.TextureId="rbxassetid://200";mesh.Parent=h
            local attachment=Instance.new("Attachment");attachment.Name="HairAttachment";attachment.Parent=h
            return a
        end
        local function generate(description)
            local c=Instance.new("Model")
            local h=Instance.new("Humanoid");h.RigType=Enum.HumanoidRigType.R6;h.Parent=c
            for _,name in ipairs({"Head","Torso","HumanoidRootPart"})do
                local part=Instance.new("Part");part.Name=name;part.Parent=c
            end
            local attachment=Instance.new("Attachment");attachment.Name="HairAttachment";attachment.Parent=c.Head
            for _,entry in ipairs(description:GetAccessories(true))do
                if entry.AccessoryType==Enum.AccessoryType.Hair and entry.AssetId~=103 then
                    local hair=raw();hair.AccessoryType=Enum.AccessoryType.Hair;hair.Parent=c
                end
            end
            return c
        end
        local function original()return Instance.new("HumanoidDescription")end
        local players={GetHumanoidDescriptionFromUserIdAsync=function()return original()end,
            CreateHumanoidModelFromDescriptionAsync=function(_,description)
                assert(description.UseAvatarSettings,"native game settings remain enabled")
                return generate(description)
            end}
        local services={Players=players,HttpService=game:GetService("HttpService"),ContentProvider={PreloadAsync=function()end},
            MarketplaceService={GetProductInfoAsync=function()return {AssetTypeId=41}end}}
        local env=setmetatable({game={GetService=function(_,name)return services[name]end},getgenv=false},{__index=getfenv()})
        local function module(source)local chunk=assert(loadstring(source));setfenv(chunk,env);return chunk()end
        local event=own(Instance.new("BindableEvent"))
        local d=original();local character=own(generate(d));d:Destroy()
        local player={UserId=123,Character=character,CharacterAdded=event.Event,FindFirstChildOfClass=function()end}
        local create=module(avatarSource)
        local api=own(create(player,nil,function()return {raw()}end,true,nil,module(mappingSource)),"destroy")
        api.equipAccessory(101,nil,41)
        local hair=character:FindFirstChildOfClass("Accessory")
        assert(hair and hair.AccessoryType==Enum.AccessoryType.Hair,"raw Unknown accessory is categorized before native admission")
        assert(hair.Handle.LocalTransparencyModifier==0,"allowed raw catalog hair remains visible")
        api.reapplySaved();task.wait();task.wait()
        assert(character:FindFirstChildOfClass("Accessory")==hair,"saved replay retains the allowed accessory instance")
        api.equipAccessory(102)
        assert(#api.listAccessories()==2,"direct catalog equip resolves the category without caller metadata")
        api.equipAccessory(103,nil,41)
        assert(#api.listAccessories()==2,"a genuinely excluded native item remains excluded")
        local nextDescription=original();local fresh=own(generate(nextDescription));nextDescription:Destroy()
        player.Character=fresh;event:Fire(fresh);task.wait();task.wait();api.reapplySaved()
        local count=0
        for _,a in ipairs(fresh:GetChildren())do if a:IsA("Accessory")then
            count=count+1;assert(a.AccessoryType==Enum.AccessoryType.Hair,"respawn keeps resolved accessory categories")
        end end
        assert(count==2,"allowed accessories survive respawn while exclusions remain enforced")
        return "PASS: raw catalog category, native accessory admission, saved replay, direct equip, real exclusion and respawn"
    end)
    for i=#cleanup,1,-1 do pcall(cleanup[i])end
    assert(ok,result);return result
end
