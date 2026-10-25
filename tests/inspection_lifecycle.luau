-- Run in a Roblox client: loadstring(testSource)()(nativeInspectionSource).
-- Detached real Instances exercise property signals and yielding renders without
-- opening the user's inspector or requesting avatar assets.
return function(source)
    local function settle()task.wait();task.wait()end
    local fixtureCount=0
    local function fixture(options)
        options=options or {}
        local core=Instance.new("Folder")
        local screen=Instance.new("ScreenGui");screen.Parent=core
        local shell=Instance.new("Frame");shell.Name="InspectAndBuy";shell.Parent=screen
        local title=Instance.new("TextLabel");title.Text="Original's Avatar";title.Parent=shell
        local viewport=Instance.new("ViewportFrame");viewport.Size=UDim2.fromOffset(200,250);viewport.Parent=shell
        local gate,entered,finished=Instance.new("BindableEvent"),false,false
        local shows=0
        local requests,repairPending=0,false
        local modernCard,modernLabel,modernImage
        local snapshot={version=1,definition={},items={{id=123,name="Custom Hat"}}}
        local gui={InspectPlayerFromHumanoidDescription=function(_,_,name)
            requests=requests+1;title.Text=name.."'s Avatar"
            if modernLabel then repairPending=true end
        end,
            InspectPlayerFromUserId=function()end}
        local services={CoreGui=core,GuiService=gui,HttpService=game:GetService("HttpService")}
        local environment=setmetatable({game={GetService=function(_,name)return services[name]end}},{__index=getfenv()})
        local chunk=assert(loadstring(source));setfenv(chunk,environment)
        local module=chunk()
        local previews={captureDescription=function()
            if options.yieldCapture then entered=true;gate.Event:Wait()end
            return {version=1,records={}}
        end,show=function()
            if options.yieldShow then entered=true;gate.Event:Wait()end
            shows=shows+1;return true
        end}
        local api=module.create({Name="Original",UserId=-1},function()return previews end)
        local function update(image)
            api.update({enabled=true,name="Alias",snapshot=snapshot,image=image})
        end
        local function overlay()
            local parent=core:FindFirstChild("LarpbloxOwnPreview")
            return parent,parent and parent:FindFirstChild("LarpbloxInspectPreview")
        end
        update("rbxasset://textures/whiteCircle.png");settle();update("rbxasset://textures/whiteCircle.png");settle()
        local parent,image=overlay()
        assert(parent and parent.Enabled and image.Visible,"fixture inspector must be visible")
        local f={core=core,screen=screen,shell=shell,title=title,api=api,overlay=overlay,update=update}
        function f.addModernCard()
            local list=Instance.new("Frame");list.Name="List";list.Parent=shell
            local card=Instance.new("Frame");card.Name="Item1";card.Parent=list
            local image=Instance.new("ImageLabel");image.Image="rbxthumb://type=Asset&id=999&w=150&h=150";image.Parent=card
            local label=Instance.new("TextLabel");label.Name="ItemCardFooterTitle";label.Text="Real Hat";label.Parent=card
            modernCard,modernLabel,modernImage=card,label,image
            settle();task.wait(0.25);return card,label,image
        end
        function f.repairModernCard()
            assert(repairPending,"stale cards must request the custom description again")
            repairPending=false
            modernLabel.Text="Custom Hat";modernImage.Image="rbxthumb://type=Asset&id=123&w=150&h=150";settle();task.wait(0.25)
            assert(modernCard.Visible,"matching custom cards must become visible")
        end
        function f.resetModernCard()
            local before=requests
            modernLabel.Text="Real Hat";modernImage.Image="rbxthumb://type=Asset&id=999&w=150&h=150";settle();task.wait(0.25)
            assert(not modernCard.Visible,"a replaced real outfit must be quarantined")
            assert(requests==before+1,"each stale reset must issue exactly one new description request")
            f.repairModernCard()
        end
        function f.normalizedCard()
            local card=Instance.new("Frame");card.Name="Item2";card.Parent=modernCard.Parent
            local label=Instance.new("TextLabel");label.Name="ItemCardFooterTitle";label.Text="Normalized Dynamic Head";label.Parent=card
            settle();task.wait(0.25)
            local before=requests
            for _=1,5 do update("rbxasset://textures/whiteCircle.png");settle()end
            task.wait(0.25)
            assert(requests==before,"a stable normalized catalog item must not cause an inspection loop")
            card:Destroy();settle()
        end
        function f.progressiveModernCard()
            local before=requests
            local parent=f.overlay();local flickers=0
            local listener=parent:GetPropertyChangedSignal("Enabled"):Connect(function()if not parent.Enabled then flickers=flickers+1 end end)
            local card=Instance.new("Frame");card.Name="Item3";card.Parent=modernCard.Parent
            local image=Instance.new("ImageLabel");image.Parent=card
            local label=Instance.new("TextLabel");label.Name="ItemCardFooterTitle";label.Text="Loading item";label.Parent=card
            for _,text in ipairs({"Loading item","Catalog item","Custom Hat"})do
                label.Text=text;task.wait()
            end
            image.Image="rbxthumb://type=Asset&id=123&w=150&h=150";task.wait(0.3);settle()
            listener:Disconnect()
            assert(requests==before,"progressive modern card loading must not re-adopt before its matching catalog data arrives")
            assert(flickers==0,"card loading must never hide an already-ready preview")
            if repairPending then f.repairModernCard()end
            local parent,overlay=f.overlay()
            assert(parent and parent.Enabled and overlay.Visible,"progressive card loading must preserve the ready preview")
            card:Destroy();settle()
        end
        function f.hidden(message)
            local parent,image=overlay()
            assert(not parent or not parent.Enabled,message)
            assert(not image or not image.Visible or not parent.Enabled,message)
        end
        function f.startRender()
            task.spawn(function()update(nil);finished=true end)
            settle();assert(entered,"render must reach the asynchronous boundary")
        end
        function f.finishRender()
            gate:Fire();settle();settle();assert(finished,"render call must finish")
        end
        function f.destroy()
            api.destroy(true);core:Destroy();gate:Destroy();settle()
            fixtureCount=fixtureCount+1
        end
        return f
    end

    local f=fixture()
    f.shell.Visible=false;settle();f.hidden("hiding the native shell must hide its independent overlay")
    f.shell.Visible=true;settle()
    local parent,image=f.overlay();assert(parent.Enabled and image.Visible,"reopening the same shell must restore its preview")
    f.screen.Enabled=false;settle();f.hidden("disabling the ancestor ScreenGui must hide the overlay")
    f.screen.Enabled=true;settle()
    parent,image=f.overlay();assert(parent.Enabled and image.Visible,"re-enabling the native screen must recover")
    f.title.Text="SomeoneElse's Avatar";settle();f.hidden("switching players must hide the previous preview")
    f.destroy()

    f=fixture();f.shell.Parent=nil;settle();f.hidden("unmounting the native shell must hide the overlay")
    f.shell.Parent=f.screen;settle()
    parent,image=f.overlay();assert(parent.Enabled and image.Visible,"remounting the shell must recover")
    f.shell:Destroy();settle();f.hidden("destroying the native shell must hide the overlay")
    f.destroy()

    for _,boundary in ipairs({"yieldCapture","yieldShow"})do
        f=fixture({[boundary]=true});f.startRender()
        f.shell.Visible=false;settle();f.hidden("closing during "..boundary.." must hide immediately")
        f.finishRender();f.hidden("late "..boundary.." completion must not revive a closed overlay")
        f.shell.Visible=true;settle();settle()
        parent,image=f.overlay();assert(parent.Enabled and image.Visible,"opening after a completed render must recover")
        f.destroy()
    end

    f=fixture({yieldCapture=true});f.startRender()
    f.shell.Visible=false;settle();f.shell.Visible=true;settle()
    f.finishRender();settle()
    parent,image=f.overlay();assert(parent.Enabled and image.Visible,"close/reopen during loading must use the completed result")
    f.destroy()

    f=fixture({yieldCapture=true});f.startRender();f.api.destroy(true)
    f.finishRender();f.hidden("destroying the controller must cancel the pending preview")
    f.destroy()

    f=fixture();f.shell.Visible=false;f.shell.Visible=true;f.api.destroy(true)
    settle();f.hidden("a deferred refresh must not recreate overlays after destroy")
    f.destroy()

    f=fixture()
    local card,label,image=f.addModernCard()
    assert(not card.Visible,"a late modern native card with a stale outfit is quarantined")
    f.repairModernCard()
    f.progressiveModernCard()
    f.normalizedCard()
    for _=1,5 do f.resetModernCard()end
    f.shell.Visible=false;settle();f.shell.Visible=true;settle();settle()
    assert(card.Visible,"reopening preserves the adopted modern item card")
    f.destroy()
    return "PASS: "..fixtureCount.." inspector fixtures cover hide, close, screen disable, unmount, destruction, player switching and render races"
end
