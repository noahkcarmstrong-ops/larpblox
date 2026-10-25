-- Original accessory audio only; asset scripts are never executed.
return function(player,gui,sharing)
    sharing=sharing or {}
    local remote=sharing.remote==true
    local KEY="HoneyBunCosmeticUI_HatSounds"
    local api,alive={},true
    local enabled=not remote and gui:GetAttribute(KEY)~=false
    local character,entries,connections=nil,{},{}
    local preferenceConnection
    local laughs={['62777535']=true,['88108663']=true,['88108686']=true}
    local function read(o,k)local ok,v=pcall(function()return o[k]end);return ok and v or nil end
    local function is(o,c)local fn=read(o,"IsA");return fn and o:IsA(c)or false end
    local function children(o)return o and o:GetChildren()or{}end
    local function descendants(o)return o and o:GetDescendants()or{}end
    local function connect(signal,fn,list)
        if signal and read(signal,"Connect")then list[#list+1]=signal:Connect(fn)end
    end
    local function disconnect(list)for _,c in ipairs(list)do c:Disconnect()end end
    local function playing(sound)return read(sound,"IsPlaying")==true or read(sound,"Playing")==true end
    local function stop(entry)
        entry.token=entry.token+1;entry.scheduled=false
        for sound in pairs(entry.started)do pcall(function()sound:Stop()end)end
        entry.started={}
    end
    local function worn(entry)
        local handle=entry.accessory:FindFirstChild("Handle")
        return alive and enabled and player.Character==character and entry.accessory.Parent==character
            and (not handle or (read(handle,"Transparency")or 0)<1)
    end
    local function play(entry,sound)
        if playing(sound)then return false end
        local ok=pcall(function()sound:Play()end)
        if ok then entry.started[sound]=true end
        return ok
    end
    local function soundList(entry,witchOnly)
        local out={}
        for _,sound in ipairs(descendants(entry.accessory))do
            if is(sound,"Sound")then
                local id=tostring(read(sound,"SoundId")or"")
                local number=id:match("[?&]id=(%d+)")or id:match("(%d+)%D*$")
                if id~=""and (not witchOnly or laughs[number])then out[#out+1]=sound end
            end
        end
        return out
    end
    local function witches(entry)
        return entry.accessory.Name=="WitchesBrewHat"or read(entry.accessory,"SourceAssetId")==305888394
    end
    local function schedule(entry)
        if entry.scheduled or not worn(entry)or #soundList(entry,true)==0 then return end
        entry.scheduled=true
        local token=entry.token
        task.delay(math.random(5,15),function()
            if not alive or entry.token~=token or entries[entry.accessory]~=entry then return end
            entry.scheduled=false
            if not worn(entry)then return end
            local sounds=soundList(entry,true)
            local anyPlaying=false;for _,sound in ipairs(sounds)do if playing(sound)then anyPlaying=true;break end end
            if #sounds>0 and not anyPlaying then play(entry,sounds[math.random(1,#sounds)])end
            schedule(entry)
        end)
    end
    local function sync(entry)
        if not worn(entry)then stop(entry);return end
        if witches(entry)then schedule(entry)
        else for _,sound in ipairs(soundList(entry,false))do if read(sound,"Looped")==true then play(entry,sound)end end end
    end
    local function remove(accessory)
        local entry=entries[accessory]
        if entry then stop(entry);disconnect(entry.connections);entries[accessory]=nil end
    end
    local function scan()
        for accessory in pairs(entries)do if accessory.Parent~=character then remove(accessory)end end
        for _,accessory in ipairs(children(character))do
            if is(accessory,"Accessory")or is(accessory,"Hat")then
                local entry=entries[accessory]
                if not entry then entry={accessory=accessory,started={},connections={},token=0};entries[accessory]=entry end
                local handle=accessory:FindFirstChild("Handle")
                if handle and entry.handle~=handle then
                    entry.handle=handle
                    local changed=read(handle,"GetPropertyChangedSignal")
                    if changed then connect(handle:GetPropertyChangedSignal("Transparency"),function()sync(entry)end,entry.connections)end
                end
                sync(entry)
            end
        end
    end
    local function equippedAccessory(object)
        local node=object
        while node and node~=character do
            if is(node,"Accessory")or is(node,"Hat")then return node.Parent==character end
            node=read(node,"Parent")
        end
        return false
    end
    local function bind(nextCharacter)
        for accessory in pairs(entries)do remove(accessory)end
        disconnect(connections);connections={};character=nextCharacter
        if not character then return end
        connect(read(character,"DescendantAdded"),function(object)
            if (is(object,"Sound")or is(object,"Accessory")or is(object,"Hat")or read(object,"Name")=="Handle") and equippedAccessory(object) then scan()end
        end,connections)
        connect(read(character,"DescendantRemoving"),function(object)
            if entries[object]then remove(object)end
            for _,entry in pairs(entries)do
                if entry.started[object]then pcall(function()object:Stop()end);entry.started[object]=nil end
            end
        end,connections)
        scan()
    end
    local respawn=player.CharacterAdded:Connect(function(c)if alive then bind(c)end end)
    function api.isEnabled()return enabled end
    function api.setEnabled(value)
        local nextEnabled=value==true and (not remote or gui:GetAttribute(KEY)~=false)
        if enabled==nextEnabled then return enabled and "Hat sounds enabled (only you hear them)."or "Hat sounds disabled." end
        enabled=nextEnabled
        if not remote then gui:SetAttribute(KEY,enabled)end
        scan();if not remote and sharing.changed then pcall(sharing.changed,enabled)end
        return enabled and "Hat sounds enabled (only you hear them)."or "Hat sounds disabled."
    end
    function api.playNow()
        if not enabled then return "Turn Hat sounds on first."end
        scan();local count=0
        for _,entry in pairs(entries)do if worn(entry)then
            local sounds=soundList(entry,witches(entry))
            local busy=false
            if witches(entry)then for _,sound in ipairs(sounds)do if playing(sound)then busy=true;break end end end
            if not busy and #sounds>0 and play(entry,sounds[math.random(1,#sounds)])then count=count+1 end
        end end
        return "Played sounds from "..count.." equipped hat(s). Roblox audio permissions still apply."
    end
    function api.destroy()
        if not alive then return end
        alive=false;respawn:Disconnect();if preferenceConnection then preferenceConnection:Disconnect();preferenceConnection=nil end;bind(nil)
    end
    if remote and gui.GetAttributeChangedSignal then
        preferenceConnection=gui:GetAttributeChangedSignal(KEY):Connect(function()
            local nextEnabled=gui:GetAttribute(KEY)~=false
            if enabled~=nextEnabled then enabled=nextEnabled;scan()end
        end)
    end
    bind(player.Character)
    return api
end
