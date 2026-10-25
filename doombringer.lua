-- Cosmetic recreation of Doombringer (SourceAssetId 4640898), with shared playback.
-- It deliberately does not execute the original downloaded scripts or write to a server.
return function(player,onStatus,sharing)
    local Players=game:GetService("Players")
    local alive,enabled=true,true
    local character,hat,folder,satellite
    local connections,characterConnections,appearanceConnections,toolConnections={},{},{},{}
    local watchedHandle,watchedHumanoid
    local effects,tools={},{}
    local effectToken=0
    local lastMessage,lastMessageAt=nil,-math.huge
    local lastBeamAt=-math.huge
    local satellitePosition=Vector3.new(100,3000,0)
    sharing=sharing or {}
    local remote=sharing.remote==true
    enabled=not remote
    local held=false
    local function emit(kind,payload)if not remote and type(sharing.emit)=="function"then pcall(sharing.emit,kind,payload or {})end end
    local function point(v)return {v.X or v.x,v.Y or v.y,v.Z or v.z}end

    local function read(o,k)local ok,v=pcall(function()return o[k]end);return ok and v or nil end
    local function is(o,c)return o and read(o,"IsA") and o:IsA(c)end
    local function connect(signal,fn,list)
        if signal and signal.Connect then local c=signal:Connect(fn);(list or connections)[#(list or connections)+1]=c;return c end
    end
    local function status(message)if onStatus then pcall(onStatus,message)end end
    local function disconnectAll(list)
        list=list or connections
        for _,c in ipairs(list)do pcall(function()c:Disconnect()end)end
        for i in ipairs(list)do list[i]=nil end
    end
    local function destroy(o)if o then pcall(function()o:Destroy()end)end end
    local function clearEffects()
        effectToken=effectToken+1
        for o in pairs(effects)do destroy(o);if o==satellite then satellite=nil end;effects[o]=nil end
    end
    local function ownsAccessory(a)
        return (is(a,"Accessory")or is(a,"Hat")) and
            (a.Name=="Doombringer"or tonumber(read(a,"SourceAssetId"))==4640898)
    end
    local function findHat()
        if not character then return nil end
        for _,a in ipairs(character:GetChildren())do if ownsAccessory(a)then return a end end
    end
    local function active()
        local handle=hat and hat:FindFirstChild("Handle")
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        return alive and enabled and character and player.Character==character and hat and hat.Parent==character
            and (not handle or (tonumber(handle.Transparency)or 0)<1)
            and (not humanoid or (tonumber(humanoid.Health)or 1)>0)
    end
    local function rootFor(p)
        return p and p.Character and (p.Character:FindFirstChild("HumanoidRootPart")or p.Character:FindFirstChild("Head"))
    end
    local function posOf(o)
        local p=read(o,"Position");if p then return p end
        local cf=read(o,"CFrame");return cf and cf.Position
    end
    local function makePart(name,size,color,position)
        local p=Instance.new("Part");p.Name=name;p.Size=size;p.Anchored=true
        p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Transparency=0.25
        if color then p.Color=color end
        p.CFrame=CFrame.new(position);p.Parent=folder or character;effects[p]=true
        return p
    end
    local function ensureSatellite()
        if not active() then return nil end
        if satellite and satellite.Parent then return satellite end
        satellite=makePart("DoombringerSatellite",Vector3.new(5,16.8,5),Color3.new(0.12,0.12,0.12),satellitePosition)
        satellite.Transparency=0.05
        return satellite
    end
    local function setSatellite(position)
        satellitePosition=position
        if ensureSatellite() then satellite.CFrame=CFrame.new(position) end
        emit("doom-satellite",{position=point(position)})
    end
    local function beamAt(position,label,batch)
        if not active() or not position then return false end
        if not batch and os.clock()-lastBeamAt<0.08 then return false end
        local count=0;for _ in pairs(effects)do count=count+1 end;if count>=40 then return false end
        local sat=ensureSatellite();if not sat then return false end
        lastBeamAt=os.clock()
        -- Beam endpoints avoid Roblox's 2048-stud Part size limit.
        local source=makePart(label or "DoombringerSatelliteExplosionBeam",Vector3.new(0.2,0.2,0.2),nil,satellitePosition)
        source.Transparency=1
        local impact=makePart("DoombringerImpact",Vector3.new(10,10,10),Color3.new(1,0.35,0.02),position)
        impact.Shape=Enum.PartType.Ball;impact.Material=Enum.Material.Neon;impact.Transparency=0.3
        local a=Instance.new("Attachment");a.Parent=source
        local b=Instance.new("Attachment");b.Parent=impact
        local beam=Instance.new("Beam");beam.Attachment0=a;beam.Attachment1=b
        beam.Width0=3;beam.Width1=3;beam.FaceCamera=true;beam.LightEmission=1
        beam.Color=ColorSequence.new(Color3.new(1,0.12,0.02));beam.Parent=source
        emit("doom-beam",{position=point(position)})
        task.delay(0.6,function()
            for _,o in ipairs({source,impact})do if effects[o]then effects[o]=nil;destroy(o)end end
        end)
        return true
    end
    local function findTarget(query)
        query=tostring(query or ""):gsub("^%s+",""):gsub("%s+$","");if query==""then return nil end
        if query:lower()=="me"then return player end
        local exactName,exactDisplay,partial,count
        for _,p in ipairs(Players:GetPlayers())do
            if p then
                local n,d=tostring(p.Name or ""),tostring(p.DisplayName or "")
                if n:lower()==query:lower()then exactName=p end
                if d:lower()==query:lower()then exactDisplay=p end
                if n:lower():sub(1,#query)==query:lower()or d:lower():sub(1,#query)==query:lower()then count=(count or 0)+1;partial=p end
            end
        end
        return exactName or exactDisplay or ((count==1)and partial)
    end
    local function coordinates(words,start)
        local x,y,z=tonumber(words[start]),tonumber(words[start+1]),tonumber(words[start+2])
        if not (x and y and z) or x~=x or y~=y or z~=z or math.abs(x)>100000 or math.abs(y)>100000 or math.abs(z)>100000 then return nil end
        return Vector3.new(x,y,z)
    end
    local function smitePosition(position,message)
        if beamAt(position,"DoombringerSatelliteExplosionBeam")then status(message or "Doombringer satellite beam fired.");return true end
        return false
    end
    local function vanishAt(position)
        if not active() or not position then return false end
        local count=0;for _ in pairs(effects)do count=count+1 end;if count>=40 then return false end
        local vanish=makePart("DoombringerVanishEffect",Vector3.new(5,7,5),Color3.new(0.05,0.05,0.05),position)
        vanish.Transparency=0.35
        emit("doom-vanish",{position=point(position)})
        task.delay(0.6,function()if effects[vanish]then effects[vanish]=nil;destroy(vanish)end end)
        return true
    end
    local function giveWeapon()
        if not active() then return false end
        for tool in pairs(tools)do if tool.Parent then status("Doombringer targeting tool is already equipped locally.");return true end end
        disconnectAll(toolConnections);for tool in pairs(tools)do tools[tool]=nil end
        local backpack=read(player,"Backpack") or character
        local tool=Instance.new("Tool");tool.Name="Doombringer Targeting Tool";tool.RequiresHandle=false;tool.CanBeDropped=false
        tool.Parent=backpack;tools[tool]=true
        connect(tool.Equipped,function()held=true;if sharing.changed then pcall(sharing.changed)end end,toolConnections)
        connect(tool.Unequipped,function()held=false;if sharing.changed then pcall(sharing.changed)end end,toolConnections)
        connect(tool.Activated,function()
            if not active()then return end
            local mouse=read(player,"GetMouse") and player:GetMouse()
            local hit=mouse and read(mouse,"Hit");local position=hit and (read(hit,"Position")or hit)
            if position then smitePosition(position,"Doombringer targeting tool fired.")else status("Equip the Doombringer tool and point at the world to fire.")end
        end,toolConnections)
        status("Doombringer targeting tool created locally.");return true
    end
    local function clearTools()
        disconnectAll(toolConnections)
        local wasHeld=held;held=false
        for tool in pairs(tools)do tools[tool]=nil;destroy(tool)end
        if wasHeld and sharing.changed then pcall(sharing.changed)end
    end
    local function armageddon()
        if not active()then return false end
        clearEffects();local token=effectToken
        status("Doombringer armageddon started (25 cosmetic strikes).")
        local n=0
        local function strike()
            if token~=effectToken or not active()or n>=25 then return end
            n=n+1;local origin=posOf(rootFor(player))or Vector3.new(0,0,0)
            local x=(origin.X or origin.x)+math.random(-40,40);local z=(origin.Z or origin.z)+math.random(-40,40)
            beamAt(Vector3.new(x,(origin.Y or origin.y)-3,z),"DoombringerArmageddonStrike",true)
            if n<25 then task.delay(0.12,strike)end
        end
        strike();return true
    end
    local function command(message)
        if type(message)~="string"or not active()then return false end
        local now=os.clock();if message==lastMessage and now-lastMessageAt<0.5 then return false end
        lastMessage,lastMessageAt=message,now
        local words={};for word in message:gmatch("%S+")do words[#words+1]=word end
        local verb=(words[1]or ""):lower()
        if verb=="stop"or message=="..."or verb=="cancel"then clearEffects();emit("doom-stop");status("Doombringer effects stopped.");return true end
        if verb=="location"then local localRoot=rootFor(player);local p=posOf(localRoot)or satellitePosition;status(string.format("Doombringer location %.1f, %.1f, %.1f.",p.X or p.x,p.Y or p.y,p.Z or p.z));return true end
        if verb=="movesat"then local p=coordinates(words,2);if p and #words==4 then setSatellite(p);status("Doombringer satellite moved.");return true end end
        if verb=="target"then local p=coordinates(words,2);if p and #words==4 then return smitePosition(p)end end
        if verb=="smite"then local t=findTarget(message:sub(6));local r=rootFor(t);return r and smitePosition(posOf(r),"Doombringer smote "..tostring(t.DisplayName or t.Name)..".")or false end
        if verb=="giveweapon"then
            if #words~=2 then return false end
            local who=words[2]:lower();local own=tostring(player.Name or ""):lower();local display=tostring(player.DisplayName or ""):lower()
            if who~="me"and who~=own and who~=display then status("Doombringer targeting tool is local-only; it cannot be given to another player's Backpack.");return false end
            return giveWeapon()
        end
        if verb=="kill"then
            if words[2]and words[2]:lower()=="all"then
                local fired=false
                for _,p in ipairs(Players:GetPlayers())do local r=rootFor(p);if p~=player and r then fired=beamAt(posOf(r),"DoombringerSatelliteExplosionBeam",true)or fired;vanishAt(posOf(r))end end
                if fired then status("Doombringer cosmetic kill-all fired.")end
                return fired
            end
            local t=findTarget(message:sub(6));local r=rootFor(t);if r then local p=posOf(r);return smitePosition(p,"Doombringer visual kill fired.")and vanishAt(p) end;return false
        end
        if verb=="armageddon"then return armageddon()end
        return false
    end
    local function refresh()
        if not alive then return false end
        local nextHat=findHat();if nextHat~=hat then clearEffects();clearTools();hat=nextHat end
        local handle=hat and hat:FindFirstChild("Handle")
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if handle~=watchedHandle or humanoid~=watchedHumanoid then
            disconnectAll(appearanceConnections);watchedHandle=handle;watchedHumanoid=humanoid
            if handle and read(handle,"GetPropertyChangedSignal")then connect(handle:GetPropertyChangedSignal("Transparency"),refresh,appearanceConnections)end
            if humanoid then connect(humanoid.Died,function()clearEffects();clearTools()end,appearanceConnections)end
        end
        if not active()then clearEffects();clearTools();satellite=nil end
        if active()then ensureSatellite()end
        return active()
    end
    local function bind(c)
        disconnectAll(characterConnections);disconnectAll(appearanceConnections);watchedHandle=nil;watchedHumanoid=nil;clearEffects();clearTools();if folder then destroy(folder)end;character=c;hat=nil;satellite=nil;folder=nil
        if not c then return end
        folder=Instance.new("Folder");folder.Name="LarpbloxDoombringer";folder.Parent=c
        connect(c.DescendantAdded,function(o)if ownsAccessory(o)or is(o,"Humanoid")or (o and o.Name=="Handle")then refresh()end end,characterConnections)
        connect(c.DescendantRemoving,function(o)if ownsAccessory(o)or is(o,"Humanoid")or (o and o.Name=="Handle")then task.defer(refresh)end end,characterConnections)
        refresh()
    end
    if not remote then connect(player.Chatted,command,connections)end;connect(player.CharacterAdded,function(c)bind(c)end,connections)
    local textService=game:GetService("TextChatService");if not remote then connect(textService and textService.SendingMessage,function(m)command(read(m,"Text"))end,connections)end
    bind(player.Character)
    local api={refresh=refresh,command=command}
    function api.replay(kind,payload)
        if not remote or type(payload)~="table" then return false end
        if kind=="doom-stop" then clearEffects();return true end
        local p=payload.position
        if type(p)=="table" and tonumber(p[1] or p.X or p.x) and tonumber(p[2] or p.Y or p.y) and tonumber(p[3] or p.Z or p.z) then
            local position=Vector3.new(tonumber(p[1] or p.X or p.x),tonumber(p[2] or p.Y or p.y),tonumber(p[3] or p.Z or p.z))
            if kind=="doom-satellite" then setSatellite(position);return true end
            if kind=="doom-beam" then return beamAt(position,"DoombringerSatelliteExplosionBeam")end
            if kind=="doom-vanish" then return vanishAt(position)end
        end
        return false
    end
    function api.isHeld()return held end
    function api.setHeld(value)value=value==true;if held==value then return held end;held=value;if not held then clearTools()end;if sharing.changed then pcall(sharing.changed)end;return held end
    function api.setEnabled(value)enabled=value==true;if not enabled then clearEffects();clearTools()end;refresh();return enabled end
    function api.destroy()if not alive then return end;alive=false;disconnectAll();disconnectAll(characterConnections);disconnectAll(appearanceConnections);clearEffects();clearTools();if folder then destroy(folder)end;folder=nil;hat=nil;character=nil;satellite=nil end
    function api.diagnostics()local n=0;for _ in pairs(effects)do n=n+1 end;return{active=active(),effects=n,satellite=satellite~=nil,tools=(function()local x=0;for _ in pairs(tools)do x=x+1 end;return x end)()}end
    return api
end
