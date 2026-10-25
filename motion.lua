-- Local emote wheel assignments.
local Http=game:GetService("HttpService")
local function assetId(value)
    if type(value)=="number" then
        assert(value>0 and value%1==0 and value<9007199254740992,"Enter a positive whole asset ID.")
        return value
    end
    value=tostring(value or ""):match("^%s*(.-)%s*$")
    local digits=value:match("^(%d+)$") or value:match("^rbxassetid://(%d+)$")
    local path=value:match("^https?://www%.roblox%.com/(.+)$") or value:match("^https?://roblox%.com/(.+)$")
        or value:match("^https?://create%.roblox%.com/(.+)$")
    if path then
        digits=path:match("^catalog/(%d+)") or path:match("^library/(%d+)")
            or path:match("^store/asset/(%d+)") or path:match("^asset/%?id=(%d+)")
    end
    local id=tonumber(digits)
    assert(id and id>0 and id<9007199254740992,"Paste a Roblox asset link or a positive numeric ID.")
    return id
end
local function copy(value)
    if type(value)~="table" then return value end
    local result={};for key,item in pairs(value) do result[key]=copy(item) end;return result
end
return function(player,onStatus,managedRespawn)
    local gui=player:FindFirstChildOfClass("PlayerGui")
    local attribute="HoneyBunCosmeticEmotes"
    local slots,original={},nil
    local wheelNames={}
    local replaceOriginals=false
    local alive,generation=true,0
    local baseline,accountChecked=nil,false
    local currentDescription
    local function liveDescription(humanoid)
        if currentDescription and currentDescription.Parent==humanoid then return currentDescription end
        currentDescription=nil
        for _,child in ipairs(humanoid:GetChildren())do
            if child:IsA("HumanoidDescription")then currentDescription=child end
        end
        return currentDescription
    end
    if gui then
        local ok,saved=pcall(function() return Http:JSONDecode(gui:GetAttribute(attribute) or "{}") end)
        if ok and type(saved)=="table" then
            replaceOriginals=saved.replaceOriginals==true
            saved=type(saved.slots)=="table" and saved.slots or saved
            for i=1,8 do
                local entry=saved[tostring(i)]
                local id=type(entry)=="table" and entry.id or entry
                if type(id)=="number" and id>0 and id%1==0 and id<9007199254740992 then
                    slots[i]={id=id,name=type(entry)=="table" and entry.name or "Custom"}
                end
            end
        end
    end
    local function save()
        if not gui then return end
        local saved={}
        for slot,item in pairs(slots) do saved[tostring(slot)]={id=item.id,name=item.name} end
        gui:SetAttribute(attribute,Http:JSONEncode(replaceOriginals and {slots=saved,replaceOriginals=true} or saved))
    end
    local function context()
        assert(alive,"The cosmetic menu was closed.")
        local character=player.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        assert(humanoid and humanoid.Health>0,"Wait for your avatar to finish spawning.")
        return character,humanoid,generation
    end
    local function check(character,ticket)
        assert(alive and player.Character==character and generation==ticket,"Your avatar changed while loading. Try again.")
    end
    local function description()
        local character,humanoid=context()
        assert(humanoid.RigType==Enum.HumanoidRigType.R15,"Roblox's emote wheel needs an R15 avatar.")
        -- CoreScripts observe this live child, not the copy from GetAppliedDescription().
        local desc=liveDescription(humanoid)
        assert(desc,"This avatar has no live emote description. Wait for it to load, then retry.")
        if not original or original.description~=desc then
            local emotes,equipped=desc:GetEmotes(),desc:GetEquippedEmotes()
            if next(equipped) then baseline={emotes=copy(emotes),equipped=copy(equipped)} end
            original={description=desc,character=character,emotes=emotes,equipped=equipped}
        end
        return desc,humanoid
    end
    local function restoreWheel()
        if original and original.character==player.Character and original.description.Parent then
            original.description:SetEmotes(copy(original.emotes))
            original.description:SetEquippedEmotes(copy(original.equipped))
        end
    end
    local function ensureBaseline()
        local desc=description()
        if not next(original.equipped) then
            if not baseline and not accountChecked then
                accountChecked=true
                local ok,account=pcall(function()return game:GetService("Players"):GetHumanoidDescriptionFromUserIdAsync(player.UserId)end)
                if ok then baseline={emotes=account:GetEmotes(),equipped=account:GetEquippedEmotes()};account:Destroy() end
            end
            if baseline and next(baseline.equipped) then
                original.emotes=copy(baseline.emotes);original.equipped=copy(baseline.equipped)
            end
        end
        return desc
    end
    local function applyWheel()
        local desc=ensureBaseline()
        local emotes,equipped=copy(original.emotes),{}
        local names={}
        for _,entry in ipairs(original.equipped) do
            if not replaceOriginals and not slots[entry.Slot] then equipped[#equipped+1]=copy(entry) end
        end
        for slot,item in pairs(slots) do
            local label=tostring(item.name or "Emote"):gsub("[%c]",""):match("^%s*(.-)%s*$")
            if label=="" then label="Emote" end
            local name=label
            local suffix=2
            while emotes[name] and (#emotes[name]~=1 or emotes[name][1]~=item.id)do
                name=label.." ("..suffix..")";suffix=suffix+1
            end
            emotes[name]={item.id}
            names[slot]=name
            equipped[#equipped+1]={Slot=slot,Name=name}
        end
        table.sort(equipped,function(a,b) return a.Slot<b.Slot end)
        local ok,message=pcall(function() desc:SetEmotes(emotes);desc:SetEquippedEmotes(equipped) end)
        if not ok then pcall(restoreWheel);error("Roblox could not update this emote wheel: "..tostring(message)) end
        wheelNames=names
    end
    local function slotNumber(value)
        assert(type(value)=="number" and value>=1 and value<=8 and value%1==0,"Choose a slot from 1 to 8.")
        return value
    end
    local api={}
    function api.getSlots()
        local result={}
        local ok,desc=pcall(description)
        if ok and not replaceOriginals then
            local emotes=desc:GetEmotes()
            local equipped=desc:GetEquippedEmotes()
            if not next(equipped) and baseline then emotes=baseline.emotes;equipped=baseline.equipped end
            for _,entry in ipairs(equipped) do
                local ids=emotes[entry.Name]
                if ids and ids[1] then result[entry.Slot]={id=ids[1],name=entry.Name} end
            end
        end
        for index,item in pairs(slots) do result[index]=copy(item) end
        return result
    end
    function api.replaceSlots(entries)
        assert(type(entries)=="table" and #entries<=8,"Invalid emote slots.")
        local desired={}
        for _,item in ipairs(entries) do
            local index=slotNumber(item.slot)
            assert(not desired[index],"Duplicate emote slot.")
            desired[index]={id=assetId(item.id),name=tostring(item.name or "Emote"):sub(1,80)}
        end
        local current=api.getSlots()
        local changed=false
        for index=1,8 do
            local a,b=current[index],desired[index]
            if (a and a.id)~=(b and b.id) then changed=true end
        end
        if not changed then return false end
        local previous,previousReplace=slots,replaceOriginals
        slots=desired;replaceOriginals=true
        local ok,message=pcall(applyWheel)
        if not ok then slots=previous;replaceOriginals=previousReplace;error(message) end
        save();return true
    end
    local walkingEnabled=gui and gui:GetAttribute("HoneyBunCosmeticUI_emoteWhileWalking")==true
    local jumpingEnabled=gui and gui:GetAttribute("HoneyBunCosmeticUI_emoteWhileJumping")==true
    local isolated=gui and gui:GetAttribute("HoneyBunCosmeticUI_isolateEmote")==true
    local walkingHook,walkingTrack,walkingState,runningConnection,trackStopped,animationPlayed
    local suppressed={}
    local callbackConnections,observedCallbacks={},{}
    local environment=type(getgenv)=="function" and getgenv() or _G
    local runtime=environment.__LarpbloxEmoteEvents
    if not runtime then
        runtime={callbacks=setmetatable({}, {__mode="k"}),muted=setmetatable({}, {__mode="k"})}
        environment.__LarpbloxEmoteEvents=runtime
    end
    runtime.callbackHooks=runtime.callbackHooks or setmetatable({}, {__mode="k"})
    local scheduleBinding
    local function stopWalkingEmote()
        local track=walkingTrack;walkingTrack=nil
        if trackStopped then trackStopped:Disconnect();trackStopped=nil end
        if animationPlayed then animationPlayed:Disconnect();animationPlayed=nil end
        if track then pcall(function()track:Stop(0.15);track:Destroy()end)end
        for other,state in pairs(suppressed)do
            runtime.muted[other]=nil
            pcall(function()
                if other.IsPlaying then other:AdjustSpeed(state.speed);other:AdjustWeight(state.weight,0.15)end
            end)
        end
        suppressed={}
    end
    local function unbindWalking()
        stopWalkingEmote()
        if walkingState then walkingState:Disconnect();walkingState=nil end
        if runningConnection then runningConnection:Disconnect();runningConnection=nil end
        if walkingHook then
            local hook=walkingHook;walkingHook=nil
            if hook.dispatch and hook.dispatch.handler==hook.callback then hook.dispatch.handler=nil end
        end
    end
    local function bindWalking()
        if not (walkingEnabled or jumpingEnabled)then unbindWalking();return true end
        assert(type(getcallbackvalue)=="function" and type(hookfunction)=="function","Your executor cannot enable movement during emotes.")
        local character,humanoid=context()
        local animate=character:FindFirstChild("Animate")
        local play=animate and animate:FindFirstChild("PlayEmote")
        if not play or not play:IsA("BindableFunction")then return false end
        local nativeCallback=getcallbackvalue(play,"OnInvoke")
        local dispatch=runtime.callbackHooks[nativeCallback]
        if walkingHook and walkingHook.object==play and walkingHook.dispatch==dispatch
            and dispatch and dispatch.handler==walkingHook.callback then return true end
        local originalCallback=nativeCallback
        local animator=humanoid:FindFirstChildOfClass("Animator")
        if type(originalCallback)~="function" or not animator then return false end
        unbindWalking()
        if not dispatch then
            dispatch={}
            local trampoline
            trampoline=hookfunction(nativeCallback,function(...)
                local handler=dispatch.handler
                if handler then return handler(...)end
                return trampoline(...)
            end)
            dispatch.original=trampoline
            runtime.callbackHooks[nativeCallback]=dispatch
        end
        originalCallback=dispatch.original
        local function callback(emote,...)
            if not alive or not (walkingEnabled or jumpingEnabled)then return originalCallback(emote,...)end
            if typeof(emote)~="Instance" or not emote:IsA("Animation")then return originalCallback(emote,...)end
            stopWalkingEmote()
            local ok,newTrack=pcall(function()return animator:LoadAnimation(emote)end)
            if not ok then return originalCallback(emote,...)end
            walkingTrack=newTrack
            newTrack.Priority=Enum.AnimationPriority.Action
            if isolated then
                if not runtime.weightHook then
                    local originalWeight
                    originalWeight=hookfunction(newTrack.AdjustWeight,function(track,weight,fade)
                        if runtime.muted[track]then weight=0 end
                        return originalWeight(track,weight,fade)
                    end)
                    runtime.weightHook=true
                end
                local function suppress(track)
                    if track==newTrack then return end
                    if not suppressed[track]then suppressed[track]={speed=track.Speed,weight=track.WeightTarget}end
                    runtime.muted[track]=true
                    track:AdjustWeight(0,0)
                end
                animationPlayed=animator.AnimationPlayed:Connect(function(track)
                    if walkingTrack==newTrack then suppress(track)end
                end)
                for _,track in ipairs(animator:GetPlayingAnimationTracks())do suppress(track)end
            end
            trackStopped=newTrack.Stopped:Connect(function()if walkingTrack==newTrack then stopWalkingEmote()end end)
            newTrack:Play(0.15)
            return true,newTrack
        end
        walkingHook={object=play,native=nativeCallback,dispatch=dispatch,callback=callback}
        dispatch.handler=callback
        walkingState=humanoid.StateChanged:Connect(function(_,state)
            if state==Enum.HumanoidStateType.Dead or (state==Enum.HumanoidStateType.Jumping and not jumpingEnabled)then stopWalkingEmote()end
        end)
        runningConnection=humanoid.Running:Connect(function(speed)
            local state=humanoid:GetState()
            local airborne=state==Enum.HumanoidStateType.Jumping or state==Enum.HumanoidStateType.Freefall
            if speed>0.1 and not walkingEnabled and not (jumpingEnabled and airborne)then stopWalkingEmote()end
        end)
        return true
    end
    local bindingInProgress=false
    scheduleBinding=function()
        if bindingInProgress or not alive then return end
        -- These events already run after their relevant instance/property change.
        -- Bind directly so an executor's deferred queue cannot strand the toggle.
        bindingInProgress=true
        local ok,ready=pcall(bindWalking)
        bindingInProgress=false
        if not ok and onStatus then onStatus("Emote movement binding failed: "..tostring(ready))end
        return ok and ready
    end
    local function watchEmoteControls(character)
        for _,connection in ipairs(callbackConnections)do connection:Disconnect()end
        callbackConnections={}
        for object,handler in pairs(observedCallbacks)do
            if runtime.callbacks[object]==handler then runtime.callbacks[object]=nil end
        end
        observedCallbacks={}
        if not character then return end
        if not runtime.assignmentHook and type(hookmetamethod)=="function"then
            local original
            original=hookmetamethod(game,"__newindex",newcclosure(function(object,key,value)
                original(object,key,value)
                if key=="OnInvoke"then
                    local handler=runtime.callbacks[object]
                    if handler then handler(value)end
                end
            end))
            runtime.assignmentHook=true
        end
        local function watch(object)
            if object:IsA("BindableFunction") and object.Name=="PlayEmote"then
                local handler=function(value)
                    if not walkingHook or value~=walkingHook.native then scheduleBinding()end
                end
                runtime.callbacks[object]=handler;observedCallbacks[object]=handler
                scheduleBinding()
            elseif object:IsA("Animator") or object:IsA("Humanoid")then scheduleBinding()end
        end
        callbackConnections[#callbackConnections+1]=character.DescendantAdded:Connect(watch)
        callbackConnections[#callbackConnections+1]=character.DescendantRemoving:Connect(function(object)
            if observedCallbacks[object]then runtime.callbacks[object]=nil;observedCallbacks[object]=nil;scheduleBinding()end
        end)
        for _,object in ipairs(character:GetDescendants())do watch(object)end
        scheduleBinding()
    end
    local function saveEmoteOptions()
        if gui then
            gui:SetAttribute("HoneyBunCosmeticUI_emoteWhileWalking",walkingEnabled)
            gui:SetAttribute("HoneyBunCosmeticUI_emoteWhileJumping",jumpingEnabled)
            gui:SetAttribute("HoneyBunCosmeticUI_isolateEmote",isolated)
        end
    end
    function api.setEmoteWhileWalking(enabled)
        assert(type(getcallbackvalue)=="function" and type(hookfunction)=="function","Your executor cannot enable movement during emotes.")
        walkingEnabled=enabled==true;saveEmoteOptions();scheduleBinding();return walkingEnabled
    end
    function api.getEmoteWhileWalking()return walkingEnabled end
    function api.setEmoteWhileJumping(enabled)
        assert(type(getcallbackvalue)=="function" and type(hookfunction)=="function","Your executor cannot enable movement during emotes.")
        jumpingEnabled=enabled==true;saveEmoteOptions();scheduleBinding();return jumpingEnabled
    end
    function api.getEmoteWhileJumping()return jumpingEnabled end
    function api.setIsolateEmote(enabled)
        assert(not enabled or type(hookfunction)=="function","Your executor cannot isolate emote animations.")
        isolated=enabled==true;stopWalkingEmote();saveEmoteOptions();return isolated
    end
    function api.getIsolateEmote()return isolated end
    local catalogCache={}
    function api.searchEmotes(query,page,sort)
        query=tostring(query or ""):match("^%s*(.-)%s*$"):sub(1,100)
        page=tonumber(page) or 1
        assert(page>=1 and page%1==0,"Choose a valid catalog page.")
        sort=sort or "Relevance"
        local sorts={Relevance=true,MostFavorited=true,Bestselling=true,RecentlyCreated=true,PriceLowToHigh=true,PriceHighToLow=true}
        assert(sorts[sort],"Choose a valid catalog sort order.")
        local key=query:lower()..":"..sort
        local saved=catalogCache[key]
        if saved and page==1 and not saved.loading and os.clock()-saved.time>300 then saved.completed:Destroy();saved=nil end
        if not saved then saved={results={},time=os.clock(),loading=false,finished=false,completed=Instance.new("BindableEvent")};catalogCache[key]=saved end
        if saved.loading then saved.completed.Event:Wait()end
        if saved.results[page]then return saved.results[page],page<#saved.results or not saved.finished end
        assert(page==#saved.results+1,"Return to the previous catalog page first.")
        if saved.finished then return {},false end
        saved.loading=true
        local ok,result=pcall(function()
            if not saved.cursor then
                local params=CatalogSearchParams.new()
                params.SearchKeyword=query;params.Limit=30;params.IncludeOffSale=true
                params.SortType=Enum.CatalogSortType[sort]
                params.AssetTypes={Enum.AvatarAssetType.EmoteAnimation}
                saved.cursor=game:GetService("AvatarEditorService"):SearchCatalogAsync(params)
            else saved.cursor:AdvanceToNextPageAsync()end
            local items,seen={},{}
            for _,item in ipairs(saved.cursor:GetCurrentPage())do
                local id=tonumber(item.Id)
                if id and not seen[id]then
                    seen[id]=true;items[#items+1]={id=id,name=tostring(item.Name or "Roblox item")}
                end
            end
            saved.finished=saved.cursor.IsFinished
            saved.results[page]=items
            return items
        end)
        saved.loading=false
        saved.completed:Fire()
        if not ok then error(result,0)end
        return result,not saved.finished
    end
    function api.setEmote(slot,value)
        slot=slotNumber(slot)
        local id=assetId(value)
        description()
        local previous=slots[slot]
        local info=game:GetService("MarketplaceService"):GetProductInfo(id)
        assert(tonumber(info.AssetTypeId)==61,"Choose an emote from the Roblox catalog.")
        slots[slot]={id=id,name=tostring(info.Name or "Custom"):sub(1,80)}
        local ok,message=pcall(applyWheel)
        if not ok then slots[slot]=previous;error(message) end
        save()
        return "Assigned emote to wheel slot "..slot..". Open the Roblox wheel to use it."
    end
    function api.clearEmote(slot)
        slot=slotNumber(slot)
        local previous=slots[slot];slots[slot]=nil
        local ok,message=pcall(applyWheel)
        if not ok then slots[slot]=previous;error(message) end
        save();return "Slot "..slot.." reset to its original assignment."
    end
    function api.openWheel()
        local _,humanoid=context()
        assert(humanoid.RigType==Enum.HumanoidRigType.R15,"Roblox's emote wheel needs an R15 avatar.")
        local starter=game:GetService("StarterGui")
        assert(starter:GetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu),"This game has disabled Roblox's emote wheel.")
        local ok=pcall(function() game:GetService("GuiService"):SetEmotesMenuOpen(true) end)
        assert(ok,"Roblox's emote wheel is not available yet. Try its usual menu button.")
        return "Opened the Roblox emote wheel."
    end
    function api.playEmote(slot)
        slot=slotNumber(slot);assert(slots[slot],"Assign an emote to that slot first.")
        applyWheel()
        local character,humanoid,ticket=context()
        local ok,played=pcall(function() return humanoid:PlayEmoteAsync(wheelNames[slot]) end)
        check(character,ticket)
        assert(ok and played,"Roblox could not play this emote. Check its permissions and your avatar rig.")
        return "Playing emote from slot "..slot.."."
    end
    function api.reapplySaved()
        applyWheel()
        scheduleBinding()
        return "Saved emote wheel assignments restored."
    end
    function api.restore()
        restoreWheel();slots={};replaceOriginals=false;save();original=nil
        return "Original emote wheel restored."
    end
    local wheelConnections={}
    local wheelReconcilePending=false
    local function reconcileWheel()
        if wheelReconcilePending or not alive then return end
        wheelReconcilePending=true
        task.defer(function()
            wheelReconcilePending=false
            if not alive or (not next(slots) and not replaceOriginals)then return end
            local character=player.Character
            local humanoid=character and character:FindFirstChildOfClass("Humanoid")
            local desc=humanoid and liveDescription(humanoid)
            if not desc or humanoid.Health<=0 then return end
            local ok,reason=pcall(function()
                local emotes,equipped=desc:GetEmotes(),{}
                for _,entry in ipairs(desc:GetEquippedEmotes())do equipped[entry.Slot]=entry.Name end
                local changed=false
                for slot,item in pairs(slots)do
                    local name=equipped[slot]
                    local ids=name and emotes[name]
                    if not ids or #ids~=1 or ids[1]~=item.id or name~=wheelNames[slot]then changed=true;break end
                end
                if not changed and replaceOriginals then
                    for slot in pairs(equipped)do if not slots[slot]then changed=true;break end end
                end
                if changed then applyWheel()end
            end)
            if not ok and onStatus then onStatus("Could not restore emote wheel: "..tostring(reason))end
        end)
    end
    local function watchWheel(character)
        for _,connection in ipairs(wheelConnections)do connection:Disconnect()end
        wheelConnections={}
        currentDescription=nil
        if not character then return end
        local watched={}
        local function watch(instance)
            if watched[instance]then return end
            if instance:IsA("HumanoidDescription")then
                -- CoreScripts rebind to the newly added description. During
                -- replication the preceding description can still be present.
                if instance.Parent and instance.Parent.Parent==character and instance.Parent:IsA("Humanoid")then
                    currentDescription=instance
                end
                watched[instance]=true
                wheelConnections[#wheelConnections+1]=instance.EmotesChanged:Connect(reconcileWheel)
                wheelConnections[#wheelConnections+1]=instance.EquippedEmotesChanged:Connect(reconcileWheel)
            elseif instance:IsA("Humanoid")then
                watched[instance]=true
                wheelConnections[#wheelConnections+1]=instance.ApplyDescriptionFinished:Connect(function()reconcileWheel();scheduleBinding()end)
            end
        end
        wheelConnections[#wheelConnections+1]=character.DescendantAdded:Connect(function(instance)
            if instance:IsA("Humanoid") or instance:IsA("HumanoidDescription")then watch(instance);reconcileWheel()end
        end)
        wheelConnections[#wheelConnections+1]=character.DescendantRemoving:Connect(function(instance)
            if instance:IsA("Humanoid") or instance:IsA("HumanoidDescription")then reconcileWheel()end
        end)
        for _,instance in ipairs(character:GetDescendants())do watch(instance)end
        reconcileWheel()
    end
    local changed=player.CharacterAdded:Connect(function(character)
        generation=generation+1;local ticket=generation
        original=nil
        unbindWalking()
        scheduleBinding()
        watchWheel(character)
        watchEmoteControls(character)
    end)
    function api.destroy()
        if not alive then return end
        alive=false;generation=generation+1;changed:Disconnect();unbindWalking();pcall(restoreWheel);original=nil
        for _,connection in ipairs(wheelConnections)do connection:Disconnect()end
        wheelConnections={}
        for _,entry in pairs(catalogCache)do entry.completed:Fire();entry.completed:Destroy()end
        catalogCache={}
        watchEmoteControls(nil)
    end
    watchEmoteControls(player.Character)
    watchWheel(player.Character)
    scheduleBinding()
    return api
end
