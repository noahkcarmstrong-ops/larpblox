-- Cosmetic recreation of TeapotTurret1055299 with optional shared playback.
return function(player,onStatus,sharing)
    local Players=game:GetService("Players")
    local TweenService=game:GetService("TweenService")
    local alive,enabled,doom=true,true,false
    local doomToken=0
    local character,hat,folder
    local connections,characterConnections,rockets={}, {},{}
    local lastMessage,lastMessageAt,lastFireAt= nil,nil,-math.huge
    sharing=sharing or {}
    local remote=sharing.remote==true
    enabled=not remote
    local function emit(kind,payload)if not remote and type(sharing.emit)=="function"then pcall(sharing.emit,kind,payload or {})end end
    local function read(o,k)local ok,v=pcall(function()return o[k]end);return ok and v or nil end
    local function is(o,c)return o and read(o,"IsA") and o:IsA(c)end
    local function connect(signal,fn,list)
        if signal and signal.Connect then local c=signal:Connect(fn);(list or connections)[#(list or connections)+1]=c;return c end
    end
    local function status(message)if onStatus then pcall(onStatus,message)end end
    local function soundEnabled()
        local gui=sharing.viewerGui or read(player,"PlayerGui")
        return not gui or gui:GetAttribute("HoneyBunCosmeticUI_HatSounds")~=false
    end
    local function disconnectAll(list)list=list or connections;for _,c in ipairs(list)do pcall(function()c:Disconnect()end)end;for i in ipairs(list)do list[i]=nil end end
    local function clearRockets()
        for rocket in pairs(rockets)do pcall(function()rocket:Destroy()end);rockets[rocket]=nil end
    end
    local function ownsAccessory(a)
        return (is(a,"Accessory")or is(a,"Hat")) and (a.Name=="TeapotTurret"or tonumber(read(a,"SourceAssetId"))==1055299)
    end
    local function findHat()
        if not character then return nil end
        for _,a in ipairs(character:GetChildren())do if ownsAccessory(a)then return a end end
    end
    local function active()
        local handle=hat and hat:FindFirstChild("Handle")
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        return alive and enabled and character and player.Character==character and hat and hat.Parent==character
            and (not handle or (tonumber(handle.Transparency)or 0)<1) and (not humanoid or (tonumber(humanoid.Health)or 1)>0)
    end
    local function origin()
        local h=hat and hat:FindFirstChild("Handle")
        local root=character and (character:FindFirstChild("HumanoidRootPart")or character:FindFirstChild("Head"))
        return h or root
    end
    local function position(part)
        local source=origin();if not source then return false end
        local cf=read(source,"CFrame")
        if cf then part.CFrame=cf*CFrame.new(0,0,-3) else part.Position=read(source,"Position") end
        return true
    end
    local function fire(target)
        if not active() or not target or target==player or os.clock()-lastFireAt<0.1 then return false end
        local root=target.Character and (target.Character:FindFirstChild("HumanoidRootPart")or target.Character:FindFirstChild("Head"))
        if not root then return false end
        local rocket=Instance.new("Part");rocket.Name="Part1";rocket.Size=Vector3.new(1,1,4)
        rocket.Anchored=true;rocket.CanCollide=false;rocket.CanTouch=false;rocket.CanQuery=false
        rocket.BrickColor=BrickColor.new("Bright green");rocket.Parent=folder or character
        if not position(rocket)then rocket:Destroy();return false end
        local rocketCount=0;for _ in pairs(rockets)do rocketCount=rocketCount+1 end
        if rocketCount>=8 then rocket:Destroy();return false end
        lastFireAt=os.clock();rockets[rocket]=true
        local light=Instance.new("PointLight");light.Name="TeapotGlow";light.Color=Color3.new(0.2,1,0.2);light.Brightness=2;light.Range=8;light.Parent=rocket
        local whoosh=Instance.new("Sound");whoosh.Name="TeapotWhoosh";whoosh.SoundId="rbxasset://sounds/Rocket whoosh 01.wav";whoosh.Volume=0.7;whoosh.Looped=false;whoosh.Parent=rocket;if soundEnabled()then pcall(function()whoosh:Play()end)end
        local destination=read(root,"Position")
        if TweenService and destination then
            local tween=TweenService:Create(rocket,TweenInfo.new(0.45,Enum.EasingStyle.Linear),{Position=destination});tween:Play()
        end
        task.delay(0.45,function()
            if rockets[rocket]then
                local hit=Instance.new("Sound");hit.Name="TeapotImpact";hit.SoundId="rbxasset://sounds/collide.wav";hit.Volume=1;hit.Parent=rocket;if soundEnabled()then pcall(function()hit:Play()end)end
                local burst=Instance.new("Part");burst.Name="TeapotBurst";burst.Shape=Enum.PartType.Ball
                burst.Size=Vector3.new(1,1,1);burst.CFrame=rocket.CFrame;burst.Color=Color3.new(1,0.6,0.1)
                burst.Material=Enum.Material.Neon;burst.Transparency=0.3;burst.Anchored=true
                burst.CanCollide=false;burst.CanTouch=false;burst.CanQuery=false;burst.Parent=rocket
                TweenService:Create(burst,TweenInfo.new(0.3,Enum.EasingStyle.Linear),{Size=Vector3.new(6,6,6),Transparency=1}):Play()
            end
        end)
        task.delay(0.8,function()rockets[rocket]=nil;pcall(function()rocket:Destroy()end)end)
        return true
    end
    local function targetFor(text)
        local query=text:match("^[Tt]eapot,%s*[Pp][Ww][Nn]%s+(.+)!%s*$")
        if not query then return nil end
        query=query:gsub("^%s+",""):gsub("%s+$","")
        local exactName,exactDisplay,partial,count= nil,nil,nil,0
        for _,p in ipairs(Players:GetPlayers())do
            if p~=player then
                local name,display=tostring(p.Name or ""),tostring(p.DisplayName or "")
                if name:lower()==query:lower()then exactName=p end
                if display:lower()==query:lower()then exactDisplay=p end
                if name:lower():sub(1,#query)==query:lower()or display:lower():sub(1,#query)==query:lower()then
                    count=count+1;partial=p
                end
            end
        end
        if exactName then return exactName end
        if exactDisplay then return exactDisplay end
        return count==1 and partial
    end
    local function volley(target,announce)
        if fire(target)then
            if announce~=false then emit("turret-fire",{target=tostring(target.UserId)})end
            status("Teapot rocket launched at "..tostring(target.DisplayName or target.Name)..".")return true
        end
        return false
    end
    local function chooseOther()
        local list={};for _,p in ipairs(Players:GetPlayers())do if p~=player then list[#list+1]=p end end
        return #list>0 and list[math.random(1,#list)]
    end
    local function doomLoop(token)
        if not alive or not doom or token~=doomToken then return end
        if not active()then doom=false;clearRockets();return end
        volley(chooseOther())
        task.delay(2,function()doomLoop(token)end)
    end
    local function command(message)
        if type(message)~="string"or not active()then return false end
        local now=os.clock();if message==lastMessage and now-lastMessageAt<0.2 then return false end
        lastMessage,lastMessageAt=message,now
        if message=="..."then doom=false;doomToken=doomToken+1;clearRockets();emit("doom-stop");status("Teapot doom stopped.");return true end
        if message=="CLOCKWORK INVOKES TEAPOT DOOM!"then
            doom=true;doomToken=doomToken+1;local token=doomToken;status("CLOCKWORK INVOKES TEAPOT DOOM!");task.spawn(function()doomLoop(token)end);return true
        end
        local target=targetFor(message);if target then return volley(target)end
        return false
    end
    local function refresh()
        if not alive then return false end
        local nextHat=findHat()
        if nextHat~=hat then clearRockets();hat=nextHat end
        if not active()then doom=false;clearRockets()end
        return active()
    end
    local function bind(c)
        disconnectAll(characterConnections);clearRockets();if folder then folder:Destroy()end;character=c;hat=nil;doom=false;folder=nil
        if not c then return end
        folder=Instance.new("Folder");folder.Name="LarpbloxTeapotTurret";folder.Parent=c
        connect(c.DescendantAdded,function(o)if ownsAccessory(o)or is(o,"Humanoid")or (o and o.Name=="Handle" and o.Parent==hat)then refresh()end end,characterConnections)
        connect(c.DescendantRemoving,function(o)if ownsAccessory(o)or is(o,"Humanoid")or o==hat then task.defer(refresh)end end,characterConnections)
        connect(read(c,"ChildAdded"),refresh,characterConnections);connect(read(c,"ChildRemoved"),refresh,characterConnections)
        local humanoid=c:FindFirstChildOfClass("Humanoid");if humanoid then connect(humanoid.Died,function()clearRockets();doom=false end,characterConnections)end
        refresh()
    end
    if not remote then connect(player.Chatted,command,connections)end
    connect(player.CharacterAdded,function(c)bind(c)end,connections)
    local textService=game:GetService("TextChatService")
    if not remote then connect(textService and textService.SendingMessage,function(message)command(read(message,"Text"))end,connections)end
    bind(player.Character)
    local api={refresh=refresh,command=command}
    function api.replay(kind,payload)
        if not remote or type(payload)~="table" then return false end
        if kind=="turret-fire" then
            local id=tonumber(payload.target);local target=id and Players:GetPlayerByUserId(id)
            return target and volley(target,false) or false
        elseif kind=="doom-stop" then doom=false;doomToken=doomToken+1;clearRockets();return true
        end
        return false
    end
    function api.setEnabled(value)
        enabled=value==true
        if not enabled then doom=false;clearRockets() end
        refresh();return enabled
    end
    function api.destroy()
        if not alive then return end;alive=false;doom=false;disconnectAll();disconnectAll(characterConnections);clearRockets();if folder then folder:Destroy()end;folder=nil;hat=nil;character=nil
    end
    function api.diagnostics()return{active=active(),doom=doom,rockets=(function()local n=0;for _ in pairs(rockets)do n=n+1 end;return n end)()}end
    return api
end
