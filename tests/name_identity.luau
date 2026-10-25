-- Run with real Roblox instances, or tests/run_name_identity.luau offline.
return function(source)
    local resources={}
    local function own(object,method)
        resources[#resources+1]=function()object[method or "Destroy"](object)end
        return object
    end
    local ok,result=pcall(function()
        local root=own(Instance.new("Folder"))
        local core=own(Instance.new("Folder"))
        local world=own(Instance.new("Folder"))
        local function event()return own(Instance.new("BindableEvent")).Event end
        local real={Name="OriginalUser",DisplayName="Original Display",UserId=123,CharacterAdded=event()}
        local otherReal={Name="OtherUser",DisplayName="Other Display",UserId=456,CharacterAdded=event()}
        local environment={}
        local legacy={targets={}}
        local originalValues={}
        legacy.original=function(object,key)return originalValues[object][key]end
        local function player(values)
            local p=setmetatable({}, {__index=function(object,key)
                local mapped=legacy.targets[object]
                if mapped and mapped[key]and mapped[key]~=""then return mapped[key]end
                return values[key]
            end})
            values.FindFirstChildOfClass=function(_,class)return class=="PlayerGui"and root or nil end
            originalValues[p]=values
            return p
        end
        local localPlayer,peer=player(real),player(otherReal)
        local players={LocalPlayer=localPlayer,PlayerAdded=event(),PlayerRemoving=event()}
        function players:GetPlayers()return {localPlayer,peer}end
        function players:FindFirstChild(name)
            for object,values in pairs(originalValues)do if values.Name==name then return object end end
        end
        legacy.targets[localPlayer]={Name="StaleAlias",DisplayName="Stale Display"}
        environment.__LarpbloxNameReads=legacy
        environment.__LarpbloxNotificationInterceptor={transform=function()error("retired notification hook ran")end}
        assert(players:FindFirstChild(localPlayer.Name)==nil,"fixture reproduces the legacy identity failure")
        local installs=0
        local services={Players=players,CoreGui=core}
        local env=setmetatable({game={Workspace=world,GetService=function(_,name)return services[name]end},
            getgenv=function()return environment end,
            hookmetamethod=function(_,key)
                installs=installs+1
                return function(object,property,value)if value~=nil then object[property]=value end end
            end,
        },{__index=getfenv()})
        local function factory()
            local chunk=assert(loadstring(source));setfenv(chunk,env);return chunk()
        end
        local function label(text,name,id)
            local row=Instance.new("Frame");row.Name=name or "PlayerRow";row.Parent=root
            if id then row:SetAttribute("UserId",id)end
            local value=Instance.new("TextLabel");value.Text=text;value.Parent=row
            return value
        end
        local basic=label("OriginalUser")
        local decorated=label("[ELITE] OriginalUser")
        local collidingTag=label("[OriginalUser] OriginalUser")
        local rich=label('<b>[VIP] OriginalUser</b>');rich.RichText=true
        local spectate=label("OtherUser")
        local conflict=label("[ELITE] OriginalUser",nil,456)
        local unrelated=label("OriginalUser scored 10 points")
        local notifications=Instance.new("Frame");notifications.Name="Notifications";notifications.Parent=core
        local notice=Instance.new("TextLabel");notice.Text="OriginalUser joined the experience";notice.Parent=notifications
        local make=factory()
        assert(next(legacy.targets)==nil,"reload retires legacy spoof targets")
        local api=own(make(localPlayer,root),"destroy")
        local peerApi=own(make(peer,root),"destroy")
        api.set("LarpUser","Larp Display");peerApi.set("LarpPeer","Peer Display")
        local function checkIdentity()
            local snapshot={}
            for _,p in ipairs(players:GetPlayers())do snapshot[p.Name]={Dead=false}end
            for _,p in ipairs(players:GetPlayers())do
                assert(players:FindFirstChild(p.Name)==p,"native leaderboard keys resolve the same player")
                assert(snapshot[originalValues[p].Name]and snapshot[p.Name],"server round-data keys remain accessible for spectate")
                assert(p.Name==originalValues[p].Name and p.DisplayName==originalValues[p].DisplayName,"raw identity stays native")
            end
        end
        checkIdentity()
        assert(environment.__LarpbloxNotificationInterceptor.transform==nil,"reload retires the legacy notification handler")
        assert(notice.Text=="LarpUser joined the experience","native notification text is mapped without a global hook")
        notice.Text="OriginalUser left the experience";task.wait();task.wait()
        assert(notice.Text=="LarpUser left the experience","native notification redraws use Text events")
        local late=Instance.new("TextLabel");late.Text="";late.Parent=notifications;task.wait()
        late.Text="OtherUser joined the experience";task.wait();task.wait()
        assert(late.Text=="LarpPeer joined the experience","late notification text is observed without intercepting assignments")
        assert(installs==0,"name presentation must not install global read or write hooks")
        assert(basic.Text=="LarpUser"and decorated.Text=="[ELITE] LarpUser","native leaderboard labels display aliases and preserve tags")
        assert(collidingTag.Text=="[OriginalUser] LarpUser","rank tags are not rewritten when they match a username")
        assert(rich.Text=='<b>[VIP] LarpUser</b>',"rich name decoration is preserved")
        assert(spectate.Text=="LarpPeer","spectate labels display the peer alias")
        assert(conflict.Text=="[ELITE] OriginalUser"and unrelated.Text=="OriginalUser scored 10 points","conflicting identity and unrelated game text stay native")
        api.set("NextUser","Next Display");peerApi.set("NextPeer","Next Peer Display")
        checkIdentity()
        assert(decorated.Text=="[ELITE] NextUser"and spectate.Text=="NextPeer","extension revisions update presentation only")
        decorated.Text="[VIP] OriginalUser";spectate.Text="OtherUser"
        task.wait();task.wait()
        assert(decorated.Text=="[VIP] NextUser"and spectate.Text=="NextPeer","native redraws keep aliases")
        api.setEnabled(false);peerApi.setEnabled(false);checkIdentity()
        assert(decorated.Text=="[VIP] OriginalUser"and spectate.Text=="OtherUser","disable restores current native text")
        assert(notice.Text=="OriginalUser left the experience"and late.Text=="OtherUser joined the experience","disable restores original notification text")
        api.setEnabled(true);api.destroy();peerApi.destroy();checkIdentity()
        local reloaded=own(factory()(localPlayer,root),"destroy")
        reloaded.set("ReloadedUser","Reloaded Display");checkIdentity()
        assert(basic.Text=="ReloadedUser"and installs==0,"reload retains visual mapping without installing an identity hook")
        return "PASS: native leaderboard/spectate identity, decorated labels, peer revisions, redraw, disable, reload and legacy hook cleanup"
    end)
    for i=#resources,1,-1 do pcall(resources[i])end
    assert(ok,result);return result
end
