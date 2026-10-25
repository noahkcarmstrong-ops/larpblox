-- Real shared-record application using the same avatar mapping as local updates.
return function(sharedSource,avatarSource,mappingSource)
    local cleanup={}
    local function track(object,method)cleanup[#cleanup+1]=function()object[method](object)end;return object end
    local ok,result=pcall(function()
        local function rig(description)
            assert(description.UseAvatarSettings)
            local model=Instance.new("Model")
            local h=Instance.new("Humanoid");h.RigType=Enum.HumanoidRigType.R15;h.Parent=model
            local scale=Instance.new("NumberValue");scale.Name="BodyHeightScale";scale.Value=description.HeightScale;scale.Parent=h
            for _,name in ipairs({"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand",
                "LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot","HumanoidRootPart"})do
                local part=Instance.new("Part");part.Name=name;part.Size=Vector3.one
                if (name=="RightUpperLeg"or name=="RightLowerLeg"or name=="RightFoot")and description.RightLeg~=0 then part.Shape=Enum.PartType.Ball end
                part.Parent=model
            end
            return model
        end
        local function original()local d=Instance.new("HumanoidDescription");d.UseAvatarSettings=true;return d end
        local function model()local d=original();local value=rig(d);d:Destroy();return track(value,"Destroy")end
        local events={}
        local function event()local value=track(Instance.new("BindableEvent"),"Destroy");events[#events+1]=value;return value end
        local added,removing=event(),event()
        local self={UserId=1,Name="Self",FindFirstChildOfClass=function()end}
        local peer={UserId=123,Name="Peer",Character=model(),CharacterAdded=added.Event,CharacterRemoving=removing.Event,FindFirstChildOfClass=function()end}
        local players={GetPlayers=function()return {self,peer}end,GetPlayerByUserId=function(_,id)return id==123 and peer or self end,
            GetHumanoidDescriptionFromUserIdAsync=function()return original()end,CreateHumanoidModelFromDescriptionAsync=function(_,d)return rig(d)end}
        local services={Players=players,HttpService=game:GetService("HttpService"),ContentProvider={PreloadAsync=function()end}}
        local env=setmetatable({game={PlaceId=123,JobId="fixture",GetService=function(_,name)return services[name]end},getgenv=false,hookfunction=false},{__index=getfenv()})
        local function module(source)local fn=assert(loadstring(source));setfenv(fn,env);return fn()end
        local createAvatar,createMapping=module(avatarSource),module(mappingSource)
        local function noop()end
        local function dummy()return setmetatable({destroy=noop},{__index=function()return noop end})end
        local receive
        local transport={setSharing=noop,onShared=function(callback)receive=callback;return noop end}
        local sync=track(module(sharedSource)(self,function()return nil end,function()return {}end,
            function(player)return createAvatar(player,nil,nil,true,nil,createMapping)end,dummy,dummy,dummy,function()return true end,noop,{transport=transport}),"destroy")
        sync.setEnabled(true);task.wait()
        local function push(id,revision)
            receive({type="upsert",record={version=1,userId="123",snapshot={version=1,userId="123",revision=revision,
                items={{id=id,name="Leg",assetType=31,itemType="Asset"}},definition={assets={{id=id}},bodyColors={},scales={height=1}}}}})
            task.wait();task.wait()
        end
        push(139607718,1)
        local old=peer.Character
        assert(old.RightUpperLeg.Shape==Enum.PartType.Ball,"shared outfit uses the native mapping")
        old.RightUpperLeg.Shape=Enum.PartType.Cylinder;old.RightUpperLeg.Size=Vector3.new(3,4,5);old.RightUpperLeg.Transparency=0.5
        old.Humanoid.BodyHeightScale.Value=0.75;task.wait();task.wait()
        push(139607719,2)
        assert(old.RightUpperLeg.Shape==Enum.PartType.Cylinder and old.RightUpperLeg.Size==Vector3.new(3,4,5)
            and old.RightUpperLeg.Transparency==0.5 and old.Humanoid.BodyHeightScale.Value==0.75,"shared extension update preserves game changes")
        old.RightUpperLeg.Shape=Enum.PartType.Block;task.wait();task.wait()
        assert(old.RightUpperLeg.Shape==Enum.PartType.Ball,"shared original restoration resumes mapping")
        peer.Character=model();added:Fire(peer.Character);task.wait();task.wait()
        assert(peer.Character.RightUpperLeg.Shape==Enum.PartType.Ball,"shared respawn replays against new game state")
        peer.Character.RightUpperLeg.Shape=Enum.PartType.Cylinder;task.wait();sync.setEnabled(false)
        assert(peer.Character.RightUpperLeg.Shape==Enum.PartType.Cylinder,"shared disable preserves current game appearance")
        return "PASS: shared native mapping, game changes, remote revisions, original restoration, respawn and disable"
    end)
    for index=#cleanup,1,-1 do pcall(cleanup[index])end
    assert(ok,result);return result
end
