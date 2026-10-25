-- Real instances/events with deterministic portrait rendering; no network.
return function(source)
    local cleanup={}
    local function own(object,method)
        cleanup[#cleanup+1]=function()object[method or "Destroy"](object)end;return object
    end
    local ok,result=pcall(function()
        local root=own(Instance.new("Folder"))
        local people=Instance.new("Frame");people.Name="People";people.Parent=root
        local function card(username,url)
            local row=Instance.new("Frame");row.Name="CardContent";row.Parent=people
            local image=Instance.new("ImageLabel");image.Name="AvatarThumbnail";image.Image=url or "opaque.png"
            image.BackgroundTransparency=0.2;image.ImageTransparency=0.25;image.Parent=row
            local label=Instance.new("TextLabel");label.Text=username;label.Parent=row
            return image,label,row
        end
        local image,label=card("@Alias","rbxthumb://type=Avatar&id=123&w=150&h=150")
        local foreign,foreignLabel=card("@Other...","rbxthumb://type=Avatar&id=456&w=150&h=150")
        local blank,blankLabel=card("","")
        local event=own(Instance.new("BindableEvent"))
        local player={Name="Original",UserId=123,CharacterAdded=event.Event,FindFirstChildOfClass=function()end}
        local env=setmetatable({game={GetService=function(_,name)
            if name=="CoreGui"then return root end
            if name=="Players"then return {LocalPlayer=player}end
        end},getgenv=false},{__index=getfenv()})
        local chunk=assert(loadstring(source));setfenv(chunk,env);local module=chunk()
        assert(module.isAvatarImage(image,player,{name="Alias"}),"explicit own avatar matches")
        foreignLabel.Text="@Alias"
        assert(not module.isAvatarImage(foreign,player,{name="Alias"}),"foreign thumbnail ID vetoes a stale alias label")
        foreignLabel.Text="@Other..."
        assert(not module.isAvatarImage(blank,player,{name="Alias"}),"an incomplete card cannot borrow a sibling identity")
        foreign.Image="opaque.png"
        assert(not module.isAvatarImage(foreign,player,{name="Alias"}),"a truncated foreign username vetoes broader matching")
        blankLabel.Text="@Alias"
        assert(module.isAvatarImage(blank,player,{name="Alias"}),"exact identity inside one opaque card still matches")
        blankLabel.Text=""
        local function snapshot(version)return {definition={version=version,playerAvatarType={playerAvatarType="R15"}},items={}}end
        local previews={captureDescription=function()return {}end,show=function(viewport)
            local camera=Instance.new("Camera");camera.Parent=viewport;viewport.CurrentCamera=camera;return true
        end}
        local api=own(module.create(player,function()return previews end,function()return Instance.new("HumanoidDescription")end),"destroy")
        local reentered=false
        local connection=image.ChildAdded:Connect(function(child)
            if child.Name=="LarpbloxOwnAvatarPreview"and not reentered then
                reentered=true;api.update({enabled=true,name="Alias",snapshot=snapshot(2)})
            end
        end)
        cleanup[#cleanup+1]=function()connection:Disconnect()end
        api.update({enabled=true,name="Alias",snapshot=snapshot(1)})
        task.wait();task.wait();task.wait()
        local function overlays()
            local count=0
            for _,child in ipairs(image:GetChildren())do if child.Name=="LarpbloxOwnAvatarPreview"then count=count+1 end end
            return count
        end
        assert(overlays()==1,"reentrant native layout events cannot stack portrait previews")
        assert(image.ImageTransparency==1 and image.BackgroundTransparency==1,"transparent preview masks both native image and opaque backing")
        local nativeImage=image.Image
        local beforeImage=api.report()
        api.update({enabled=true,name="Alias",snapshot=snapshot(2),image="rbxassetid://downloaded-local-portrait"})
        assert(api.report()==beforeImage,"downloaded-image changes do not rebuild a cached saved-outfit portrait")
        foreign.Image="rbxthumb://type=Avatar&id=456&w=150&h=150";foreignLabel.Text="@Peer"
        local peer={Name="Other",UserId=456,CharacterAdded=event.Event,FindFirstChildOfClass=function()end}
        local peerApi=own(module.create(peer,function()return previews end,function()return Instance.new("HumanoidDescription")end),"destroy")
        peerApi.update({enabled=true,name="Peer",snapshot=snapshot(2)})
        task.wait();task.wait()
        local ownOverlay=image:FindFirstChild("LarpbloxOwnAvatarPreview")
        local peerOverlay=foreign:FindFirstChild("LarpbloxOwnAvatarPreview")
        assert(image.Image==nativeImage and ownOverlay.ClassName=="CanvasGroup"and peerOverlay.ClassName=="CanvasGroup",
            "local image availability never switches local and peer portraits onto different rendering paths")
        for _,overlay in ipairs({ownOverlay,peerOverlay})do
            local viewport=overlay:FindFirstChild("Viewport")
            assert(viewport and viewport.BackgroundTransparency==1 and overlay.BackgroundTransparency==1,"both subjects use the same transparent viewport surface")
        end
        peerApi.destroy()
        image.BackgroundTransparency=0.4;task.wait();task.wait()
        assert(image.BackgroundTransparency==1,"native backing updates remain masked during preview")
        api.update({enabled=false});task.wait();task.wait()
        assert(overlays()==0 and image.ImageTransparency==0.25 and math.abs(image.BackgroundTransparency-0.4)<0.0001,"disable removes previews and restores latest authored backing")
        api.update({enabled=true,name="Alias",snapshot=snapshot(2)});task.wait();task.wait()
        image.Image="rbxthumb://type=Avatar&id=456&w=150&h=150";task.wait();task.wait()
        assert(overlays()==0 and image.ImageTransparency==0.25 and math.abs(image.BackgroundTransparency-0.4)<0.0001,"recycled card releases old portrait ownership")
        return "PASS: exact portrait identity, sibling isolation, truncated labels, atomic preview ownership, transparent backing and restoration"
    end)
    for i=#cleanup,1,-1 do pcall(cleanup[i])end
    assert(ok,result);return result
end
