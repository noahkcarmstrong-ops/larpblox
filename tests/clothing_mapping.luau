-- Normalized clothing shares the avatar ledger, including clone restoration.
return function(mappingSource,clothingSource)
    local cleanup={}
    local function track(object,method)cleanup[#cleanup+1]=function()object[method](object)end;return object end
    local ok,result=pcall(function()
        local locked=false
        local world=track(Instance.new("WorldModel"),"Destroy");world.Parent=workspace
        local function generate(d)
            assert(d.UseAvatarSettings)
            local model=Instance.new("Model")
            local h=Instance.new("Humanoid");h.RigType=Enum.HumanoidRigType.R15;h.Parent=model
            local value=locked and 800 or d.Shirt==1 and 100 or d.Shirt==2 and 200 or d.Shirt==3 and 300 or nil
            if value then local shirt=Instance.new("Shirt");shirt.Name="Shirt";shirt.ShirtTemplate="rbxassetid://"..value;shirt.Parent=model end
            return model
        end
        local function original()local d=Instance.new("HumanoidDescription");d.UseAvatarSettings=true;d.Shirt=1;return d end
        local d=original();local character=track(generate(d),"Destroy");d:Destroy()
        character.Shirt.ShirtTemplate="rbxassetid://900"
        local event=track(Instance.new("BindableEvent"),"Destroy")
        local player={UserId=123,Character=character,CharacterAdded=event.Event,FindFirstChildOfClass=function()end}
        local players={GetHumanoidDescriptionFromUserIdAsync=function()return original()end,CreateHumanoidModelFromDescriptionAsync=function(_,description)return generate(description)end}
        local services={Players=players,HttpService=game:GetService("HttpService"),ContentProvider={PreloadAsync=function()end}}
        local env=setmetatable({game={GetService=function(_,name)return services[name]end},workspace=world},{__index=getfenv()})
        local function module(source)local fn=assert(loadstring(source));setfenv(fn,env);return fn()end
        local makeMapping,makeClothes=module(mappingSource),module(clothingSource)
        local function asset(id)local shirt=Instance.new("Shirt");shirt.Name="Shirt";shirt.ShirtTemplate="rbxassetid://"..(id*100);return {shirt}end
        local map=track(makeMapping(player),"destroy")
        local ctx={character=character,humanoid=character.Humanoid}
        local clothes=track(makeClothes(player,nil,true,asset,function(kind,id)
            local expected,replacement=map.clothingTemplates(ctx,kind,id)
            return expected,replacement,map.projectClothing,map.clothingSource
        end),"destroy")
        clothes.equipShirt(2);task.wait();task.wait()
        assert(character.Shirt.ShirtTemplate=="rbxassetid://900","an initial game uniform is not adopted as the unlarp baseline")
        character.Shirt.ShirtTemplate="rbxassetid://100";task.wait();task.wait()
        assert(character.Shirt.ShirtTemplate=="rbxassetid://200","restoring the native original resumes clothing mapping")
        local clone=track(character:Clone(),"Destroy");clone.Parent=world;task.wait();task.wait()
        clone.Shirt.ShirtTemplate="rbxassetid://950";task.wait();task.wait()
        clothes.equipShirt(3)
        assert(character.Shirt.ShirtTemplate=="rbxassetid://300"and clone.Shirt.ShirtTemplate=="rbxassetid://950","extension clothing changes preserve a cloned game uniform")
        map.restore();clothes.restore();task.wait();task.wait()
        assert(character.Shirt.ShirtTemplate=="rbxassetid://100"and clone.Shirt.ShirtTemplate=="rbxassetid://950","disable restores source clothing and preserves game changes on clones")
        clothes.destroy();map.destroy()
        locked=true
        local nextDescription=original();local nextCharacter=track(generate(nextDescription),"Destroy");nextDescription:Destroy()
        player.Character=nextCharacter
        local nextMap=track(makeMapping(player),"destroy")
        local nextCtx={character=nextCharacter,humanoid=nextCharacter.Humanoid}
        local nextClothes=track(makeClothes(player,nil,true,asset,function(kind,id)
            local expected,replacement=nextMap.clothingTemplates(nextCtx,kind,id)
            return expected,replacement,nextMap.projectClothing,nextMap.clothingSource
        end),"destroy")
        nextClothes.equipShirt(2);task.wait()
        assert(nextCharacter.Shirt.ShirtTemplate=="rbxassetid://800","native forced clothing also applies to the Larp replacement")
        nextMap.destroy();nextClothes.destroy();task.wait()
        assert(nextCharacter:GetAttribute("LarpbloxAppearanceVersion")==nil,"late clothing cleanup cannot revive a destroyed mapping controller")
        return "PASS: game uniforms, native clothing restrictions, extension revisions, cloned garments and cleanup"
    end)
    for index=#cleanup,1,-1 do pcall(cleanup[index])end
    assert(ok,result);return result
end
