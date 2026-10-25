-- Backend fixture: strict Roblox-like instances, parenting, CFrames, and APIs.
local function cf(x,y,z)
    local c={x=x or 0,y=y or 0,z=z or 0}
    function c:Inverse() return cf(-self.x,-self.y,-self.z) end
    function c:ToObjectSpace(other) return cf(other.x-self.x,other.y-self.y,other.z-self.z) end
    return setmetatable(c,{__mul=function(a,b)return cf(a.x+b.x,a.y+b.y,a.z+b.z)end})
end
local function node(class,name)
    local x={ClassName=class,Name=name,children={},destroyed=false}
    local mt={__index=function(t,k)if k=="Parent" then return rawget(t,"_parent") end end,__newindex=function(t,k,v)
        if k=="Parent" then
            local old=rawget(t,"_parent"); if old then for i,c in ipairs(old.children)do if c==t then table.remove(old.children,i)break end end end
            rawset(t,"_parent",v); if v then v.children[#v.children+1]=t end
        else rawset(t,k,v) end
    end}; setmetatable(x,mt)
    function x:IsA(k)return k==self.ClassName or k=="BasePart" and(self.ClassName=="Part"or self.ClassName=="MeshPart") or k=="LuaSourceContainer" and(self.ClassName=="Script"or self.ClassName=="LocalScript"or self.ClassName=="ModuleScript") or k=="JointInstance" and self.ClassName=="Weld"end
    function x:GetChildren()return self.children end
    function x:GetDescendants()local out={};local function walk(v)for _,c in ipairs(v.children)do out[#out+1]=c;walk(c)end end;walk(self);return out end
    function x:FindFirstChild(n,r)for _,c in ipairs(self.children)do if c.Name==n then return c end;if r then local q=c:FindFirstChild(n,true);if q then return q end end end end
    function x:FindFirstChildOfClass(k)for _,c in ipairs(self.children)do if c:IsA(k)then return c end end end
    function x:FindFirstChildWhichIsA(k,r)for _,c in ipairs(r and self:GetDescendants()or self.children)do if c:IsA(k)then return c end end end
    function x:ApplyMesh(source)
        assert(self.ClassName=='MeshPart' and source.ClassName=='MeshPart')
        local h=self.Parent and self.Parent:FindFirstChildOfClass('Humanoid')
        assert(not h or h.failName~=self.Name,'Fixture rejected mesh update')
        self.MeshId=source.MeshId;self.TextureID=source.TextureID
    end
 function x:Destroy()self.destroyed=true;self.Parent=nil;for i=#self.children,1,-1 do self.children[i]:Destroy()end end
    function x:SetAttribute(k,v)self[k]=v end
    function x:GetAttribute(k)return self[k] end
    function x:Clone()local n=node(self.ClassName,self.Name);for k,v in pairs(self)do if k~="children"and k~="Parent"and k~="_parent"and type(v)~="function"then n[k]=v end end;for _,c in ipairs(self.children)do c:Clone().Parent=n end;return n end
    return x
end
local function signal()local s={};function s:Connect(f)self.f=f;return{Disconnect=function()self.f=nil end}end;function s:Fire(...)if self.f then self.f(...)end end;return s end
local function hum()local h=node("Humanoid","Humanoid");h.Health=100;h.RigType="R15";h.replaced={};function h:GetAppliedDescription()local d=node('HumanoidDescription','Description');function d:GetAccessories()return{{AssetId=9876}}end;return d end;function h:AddAccessory(a)a.Parent=self.Parent end;function h:ReplaceBodyPartR15(n,p)if self.failName==n then return false end;local old=self.Parent:FindFirstChild(n);if old then old:Destroy()end;self.replaced[n]=p;p.Parent=self.Parent;return true end;return h end
Enum={HumanoidRigType={R6="R6",R15="R15"},BodyPartR15={}}
CFrame={new=function(x,y,z)return cf(x,y,z)end}
for _,n in ipairs({"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"})do Enum.BodyPartR15[n]=n end
Instance={new=function(c)return node(c,c)end}
local body=node("Model","Character");hum().Parent=body;local root=node("Part","HumanoidRootPart");root.CFrame=cf();root.Parent=body
for _,n in ipairs({"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"})do local p=node("MeshPart",n);p.Color={r=1,g=1,b=1};p.CFrame=cf();p.Parent=body end
local bc=node("BodyColors","Body Colors");bc.HeadColor3={r=1,g=1,b=1};bc.TorsoColor3={r=1,g=1,b=1};bc.LeftArmColor3={r=1,g=1,b=1};bc.RightArmColor3={r=1,g=1,b=1};bc.LeftLegColor3={r=1,g=1,b=1};bc.RightLegColor3={r=1,g=1,b=1};bc.Parent=body
local head=body:FindFirstChild("Head");local ha=node("Attachment","HatAttachment");ha.CFrame=cf();ha.Parent=head
local player={Character=body,CharacterAdded=signal()};local accessory=node("Accessory","Blue Hat");local handle=node("Part","Handle");handle.CFrame=cf();handle.AttachmentPoint=cf();handle.Parent=accessory;local at=node("Attachment","HatAttachment");at.CFrame=cf();at.Parent=handle;local injected=node("Script","Injected");injected.Parent=accessory
local template=node("Model","Template");for _,n in ipairs({"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"})do local p=node("MeshPart",n);p.CFrame=cf();p.Parent=template end
local armCage=node("WrapTarget","ArmCage");armCage.Parent=template:FindFirstChild("LeftUpperArm")
local incomingFlame=node("Fire","IncomingBodyFlame");incomingFlame.Parent=template:FindFirstChild("LeftUpperArm")
local players={template=template};function players:GetHumanoidDescriptionFromOutfitIdAsync(id)local d=node("HumanoidDescription","Description");d.id=id;d.Head=901;d.Torso=902;d.LeftArm=903;d.RightArm=904;d.LeftLeg=905;d.RightLeg=906;return d end;function players:CreateHumanoidModelFromDescriptionAsync(description)self.lastDescription=description;self.generated=true;if self.onGenerate then self.onGenerate()end;return self.template:Clone() end
local savedSettings=nil;local http={bundleType="BodyParts"};function http:GetAsync()return'{"items":[{"type":"UserOutfit","id":131929576}]}'end;function http:JSONDecode(value)if value=="settings-token"then return savedSettings end;return{bundleType=self.bundleType,items={{type="UserOutfit",id=131929576}}}end;function http:JSONEncode(value)savedSettings=value;return"settings-token"end
local gui=node("PlayerGui","PlayerGui");function gui:SetAttribute(k,v)self[k]=v end;function gui:GetAttribute(k)return self[k]end
player.PlayerGui=gui;function player:FindFirstChild(n)return self[n]end;function player:FindFirstChildOfClass(n)if n=="PlayerGui"then return self.PlayerGui end end;function player:WaitForChild(n)return self[n]end;function player:HasAppearanceLoaded()return true end
Color3={fromRGB=function(r,g,b)return{R=r/255,G=g/255,B=b/255,r=r/255,g=g/255,b=b/255}end,new=function(r,g,b)return{R=r,G=g,B=b,r=r,g=g,b=b}end};task={queue={},wait=function()end,spawn=function(f)table.insert(task.queue,f)end}
local mode="normal";local function freshAccessory()local a=node("Accessory","Blue Hat");a.SourceAssetId=9876;a.AttachmentPoint=cf();local h=node("Part","Handle");h.CFrame=cf();h.AttachmentPoint=cf();h.Parent=a;return a end
local gameTool=node("Tool","Game Tool");local gameHandle=node("Part","Handle");gameHandle.CFrame=cf();gameHandle.Parent=gameTool
local gearAsset=node("Tool","Cosmetic Gear");gearAsset.Grip=cf();local gearHandle=node("Part","Handle");gearHandle.CFrame=cf(0,0,1);gearHandle.Parent=gearAsset;local gearScript=node("Script","Gear Script");gearScript.Parent=gearAsset
local marketplace={assetType=28};function marketplace:GetProductInfoAsync()return{AssetTypeId=self.assetType}end
game={GetService=function(_,n)return({Players=players,HttpService=http,MarketplaceService=marketplace,ContentProvider={PreloadAsync=function()end}})[n]end,GetObjects=function(_,id)assert(id=="rbxassetid://123" or id=="rbxassetid://456");if id=="rbxassetid://456"then return{gearAsset:Clone()}end;if mode=="respawn"then local fresh=node("Model","Fresh");player.Character=fresh;player.CharacterAdded:Fire(fresh)end;if mode=="blocked"then return{node("Part","NotWearable")}end;if accessory.destroyed then return{freshAccessory()}end;return{accessory}end,HttpGet=function()return http:GetAsync()end}
Enum.InfoType={Asset="Asset"}

local create=dofile("avatar.lua")

-- Focused body-fitting regression: classic shoulder welds follow a changed
-- attachment frame, and layered clothing keeps the replacement WrapTarget.
local arm=body:FindFirstChild("LeftUpperArm")
local liveAttachment=node("Attachment","LeftShoulderAttachment");liveAttachment.CFrame=cf();liveAttachment.Parent=arm
local liveFlame=node("Fire","BodyFlame");liveFlame.Parent=arm
local nestedFlame=node("ParticleEmitter","NestedBodyFlame");nestedFlame.Parent=liveAttachment
local shoulderAccessory=node("Accessory","Shoulder");local shoulderHandle=node("Part","Handle");shoulderHandle.CFrame=cf();shoulderHandle.AttachmentPoint=cf();shoulderHandle.Parent=shoulderAccessory
local shoulderPoint=node("Attachment","LeftShoulderAttachment");shoulderPoint.CFrame=cf();shoulderPoint.Parent=shoulderHandle
game.GetObjects=function()return{shoulderAccessory}end
local fitting=create(player);fitting.equipAccessory(123)
local entry=fitting.listAccessories()[1];local shoulder=body:FindFirstChild("Shoulder")
assert(shoulder and shoulder:FindFirstChild("Handle"):FindFirstChild("AccessoryWeld"),"fixture shoulder accessory is welded")
local replacementPoint=node("Attachment","LeftShoulderAttachment");replacementPoint.CFrame=cf(4,0,0);replacementPoint.Parent=template:FindFirstChild("LeftUpperArm");marketplace.assetType=29
assert(fitting.applyBodyPart("LeftArm",456):match("LeftArm"),"body part replacement succeeds")
local weld=shoulder:FindFirstChild("Handle"):FindFirstChild("AccessoryWeld")
assert(weld and weld.C1.x==4,"classic shoulder weld follows the replacement attachment")
assert(arm:FindFirstChild("ArmCage"),"replacement body part preserves its layered WrapTarget cage")
assert(not arm:FindFirstChild("BodyFlame"),"replaced body part removes its old direct visual effect")
assert(not liveAttachment:FindFirstChild("NestedBodyFlame"),"replaced body part removes nested visual effects")
assert(arm:FindFirstChild("IncomingBodyFlame"),"replacement body part keeps its incoming visual effect")
fitting.restoreBodyPart("LeftArm")
assert(arm:FindFirstChild("BodyFlame"),"restoring the avatar restores its original direct visual effect")
assert(arm:FindFirstChild("LeftShoulderAttachment"):FindFirstChild("NestedBodyFlame"),"restoring the avatar restores nested visual effects")
assert(not arm:FindFirstChild("IncomingBodyFlame"),"restoring the avatar removes the replacement visual effect")
print("PASS: shoulder refit and layered WrapTarget preservation")

