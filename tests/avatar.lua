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
local players={template=template};function players:GetHumanoidDescriptionFromOutfitIdAsync(id)local d=node("HumanoidDescription","Description");d.id=id;d.Head=901;d.Torso=902;d.LeftArm=903;d.RightArm=904;d.LeftLeg=905;d.RightLeg=906;return d end;function players:CreateHumanoidModelFromDescriptionAsync(description)self.lastDescription=description;self.generated=true;if self.onGenerate then self.onGenerate()end;return self.template:Clone() end
local savedSettings=nil;local http={bundleType="BodyParts"};function http:GetAsync()return'{"items":[{"type":"UserOutfit","id":131929576}]}'end;function http:JSONDecode(value)if value=="settings-token"then return savedSettings end;return{bundleType=self.bundleType,items={{type="UserOutfit",id=131929576}}}end;function http:JSONEncode(value)savedSettings=value;return"settings-token"end
local gui=node("PlayerGui","PlayerGui");function gui:SetAttribute(k,v)self[k]=v end;function gui:GetAttribute(k)return self[k]end
player.PlayerGui=gui;function player:FindFirstChild(n)return self[n]end;function player:FindFirstChildOfClass(n)if n=="PlayerGui"then return self.PlayerGui end end;function player:WaitForChild(n)return self[n]end;function player:HasAppearanceLoaded()return true end
Color3={fromRGB=function(r,g,b)return{R=r/255,G=g/255,B=b/255,r=r/255,g=g/255,b=b/255}end,new=function(r,g,b)return{R=r,G=g,B=b,r=r,g=g,b=b}end};task={queue={},wait=function()end,spawn=function(f)table.insert(task.queue,f)end}
local mode="normal";local function freshAccessory()local a=node("Accessory","Blue Hat");a.SourceAssetId=9876;a.AttachmentPoint=cf();local h=node("Part","Handle");h.CFrame=cf();h.AttachmentPoint=cf();h.Parent=a;return a end
local gameTool=node("Tool","Game Tool");local gameHandle=node("Part","Handle");gameHandle.CFrame=cf();gameHandle.Parent=gameTool
local gearAsset=node("Tool","Cosmetic Gear");gearAsset.Grip=cf();local gearHandle=node("Part","Handle");gearHandle.CFrame=cf(0,0,1);gearHandle.Parent=gearAsset;local gearScript=node("Script","Gear Script");gearScript.Parent=gearAsset
local marketplace={assetType=28};function marketplace:GetProductInfoAsync()return{AssetTypeId=self.assetType}end
game={GetService=function(_,n)return({Players=players,HttpService=http,MarketplaceService=marketplace})[n]end,GetObjects=function(_,id)assert(id=="rbxassetid://123" or id=="rbxassetid://456");if id=="rbxassetid://456"then return{gearAsset:Clone()}end;if mode=="respawn"then local fresh=node("Model","Fresh");player.Character=fresh;player.CharacterAdded:Fire(fresh)end;if mode=="blocked"then return{node("Part","NotWearable")}end;if accessory.destroyed then return{freshAccessory()}end;return{accessory}end,HttpGet=function()return http:GetAsync()end}
Enum.InfoType={Asset="Asset"}
local create=dofile(arg and arg[1] or "avatar.lua");assert(type(create)=="function","module returns create(player)");local api=create(player)
if arg and arg[2]=="package-regression" then
    table.clone=table.clone or function(value)local copy={};for k,v in pairs(value)do copy[k]=v end;return copy end
    local getService=game.GetService
    game.GetService=function(self,name)
        if name=="ContentProvider" then return {PreloadAsync=function()end} end
        return getService(self,name)
    end
    -- Start with a textured account package, rather than a plain body.
    local torso=body:FindFirstChild("UpperTorso")
    local original=node("SurfaceAppearance","SurfaceAppearance");original.ColorMap="account-package";original.Parent=torso
    local source=template:FindFirstChild("UpperTorso")
    local replacement=node("SurfaceAppearance","SurfaceAppearance");replacement.ColorMap="larp-package";replacement.Parent=source
    api.applyBody("Girl")
    assert(torso:FindFirstChildOfClass("SurfaceAppearance").ColorMap=="larp-package","Larp body must replace the real package's body surface")
    replacement:Destroy()
    api.applyBody("Blocky")
    assert(not torso:FindFirstChildOfClass("SurfaceAppearance"),"Default Larp body must remove the real package's texture")
    api.restoreBody()
    assert(torso:FindFirstChildOfClass("SurfaceAppearance").ColorMap=="account-package","Restore must return the original real package's texture")
    assert(body:FindFirstChild("UpperTorso")==torso,"Package changes preserve the live body part")
    api.destroy()
    print("Real-package body surfaces replace, clear, and restore correctly.")
    return
end
assert(api.equipAccessory(123):match("Equipped"));local candidate=body:FindFirstChild("Blue Hat");assert(injected.destroyed and candidate,"sanitizing removes inserted script and parents cloned accessory");assert(#api.listAccessories()==1)
-- Azurelight uses Roblox's modern avatar model format; the callback supplies
-- that model so its original particle visuals survive script stripping.
local modern=node("Accessory","Dominus Azurelight");local modernHandle=node("Part","Handle");modernHandle.CFrame=cf();modernHandle.AttachmentPoint=cf();modernHandle.Parent=modern
local modernAttachment=node("Attachment","HatAttachment");modernAttachment.CFrame=cf();modernAttachment.Parent=modernHandle
local modernParticles=node("ParticleEmitter","AzurelightParticles");modernParticles.Enabled=true;modernParticles.Parent=modernHandle
local modernSurface=node("SurfaceAppearance","AzurelightSurface");modernSurface.Parent=modernHandle
local modernScript=node("Script","AzurelightScript");modernScript.Parent=modern
local modernRead=false
local modernApi=create(player,nil,function(path)assert(path=="assets/dominus-azurelight.rbxm");modernRead=true;return{modern}end)
modernApi.equipAccessory(14565851673)
local modernWorn=body:FindFirstChild("Dominus Azurelight")
assert(modernRead and modernWorn and modernWorn:FindFirstChild("AzurelightParticles",true).Enabled,"modern Azurelight keeps its particle effects")
assert(modernWorn:FindFirstChild("AzurelightSurface",true) and not modernWorn:FindFirstChild("AzurelightScript",true),"modern Azurelight keeps surface appearance and strips scripts")
modernApi.destroy()
gameTool.Parent=body;assert(gearAsset:FindFirstChild("Handle"),"gear fixture has handle");assert(api.equipGear(456):match("gear"));local wornGear=api.listGear()[1];assert(gameTool.Parent==body and not body:FindFirstChild("Cosmetic Gear"):FindFirstChild("Gear Script"),"gear weld preserves existing game tools and strips scripts");assert(wornGear.id==456,"hub gear is tracked separately");assert(api.removeGear():match("Removed") and gameTool.Parent==body,"removing hub gear leaves game tools alone");assert(api.equipGear(456));assert(api.getSettings().gear.id==456,"gear selection is saved");local held=body:FindFirstChild("Cosmetic Gear");local gearLoader=game.GetObjects;local badGear=node("Tool","Broken Gear");game.GetObjects=function()return {badGear}end;assert(not pcall(api.equipGear,789),"gear without a Handle is rejected");assert(body:FindFirstChild("Cosmetic Gear")==held and api.listGear()[1].id==456,"failed replacement preserves previous gear");game.GetObjects=gearLoader;api.clearAccessories();assert(api.listGear()[1].id==456,"clearing accessories keeps gear");assert(api.restore():match("restored") and #api.listGear()==0 and gameTool.Parent==body,"restore removes saved hub gear without removing game tools")
api.setSkin(Color3.new(.5,.4,.3),"All");assert(head.Color.r==.5 and body:FindFirstChild("LeftUpperArm").Color.r==.5 and bc.HeadColor3.r==.5,"R15 grouped skin applies");api.restore();assert(head.Color.r==1 and bc.HeadColor3.r==1,"restore returns original colors")
assert(api.applyBody("https://www.roblox.com/bundles/555"):match("applied"));assert(players.generated and body:FindFirstChild('Head')==head and not head.destroyed,"bundle outfit generates appearance without replacing live parts")
mode="respawn";local stale=create(player);local ok=pcall(function()stale.equipAccessory(123)end);assert(not ok,"respawn cancels stale asset operation");stale.destroy();player.Character=body;player.CharacterAdded:Fire(body)

-- Blocked body replacement rolls back every changed limb and preserves the root.
mode="normal"; local rootBefore=root; local r15=create(player); local h=body:FindFirstChildOfClass("Humanoid"); h.failName="LeftHand"; local beforeChildren=#body:GetChildren(); local rolled=pcall(function()r15.applyBody("https://www.roblox.com/bundles/555")end); assert(not rolled,"a rejected ReplaceBodyPartR15 fails"); assert(body:FindFirstChild("HumanoidRootPart")==rootBefore,"rollback preserves root identity"); assert(#body:GetChildren()<=beforeChildren+1,"rollback leaves no unowned body clones"); h.failName=nil; r15.destroy()

-- R6 Blocky is local CharacterMesh removal and restore; Girl uses generated R6 meshes.
local r6=node("Model","R6Character"); local r6h=hum(); r6h.RigType=Enum.HumanoidRigType.R6; r6h.Parent=r6; local r6root=node("Part","HumanoidRootPart");r6root.Parent=r6;local torso=node("Part","Torso");torso.Parent=r6;local leftLeg=node("Part","Left Leg");leftLeg.Parent=r6;local rightLeg=node("Part","Right Leg");rightLeg.Parent=r6;local r6gear=node("Tool","R6 game gear");r6gear.Parent=r6;local originalMesh=node("CharacterMesh","BodyMesh");originalMesh.BodyPart="Torso";originalMesh.MeshId="original-torso";originalMesh.Parent=r6
local r6player={Character=r6,CharacterAdded=signal(),PlayerGui=gui};function r6player:FindFirstChildOfClass(n)if n=="PlayerGui"then return self.PlayerGui end end;local oldTemplate=players.template;local r6template=node("Model","R6Template");local girlMesh=node("CharacterMesh","GirlMesh");girlMesh.BodyPart="Torso";girlMesh.Parent=r6template;players.template=r6template;local r6api=create(r6player);players.generated=false;assert(r6api.applyBody("Blocky"):match("Blocky"));assert(originalMesh.destroyed and not players.generated and r6root.Parent==r6,"R6 Blocky removes meshes without generating or replacing model");assert(r6api.restore():match("restored") and r6:FindFirstChild("BodyMesh"),"R6 restore returns original CharacterMesh");assert(r6api.applyBody("Girl"):match("Body") and r6:FindFirstChild("GirlMesh"),"R6 Girl applies generated CharacterMesh only")
local r6leg=node("CharacterMesh","CustomLeftLeg");r6leg.BodyPart="LeftLeg";r6leg.MeshId="custom-leg";r6leg.Parent=r6template
marketplace.assetType=30
assert(r6api.applyBodyPart("LeftLeg",456):match("LeftLeg") and r6:FindFirstChild("CustomLeftLeg"),"R6 individual limb applies CharacterMesh while preserving the live torso")
marketplace.assetType=31
assert(not pcall(r6api.applyBodyPart,"RightLeg",456) and not r6:FindFirstChild("CustomRightLeg"),"An R15-only R6 body asset is rejected when no matching R6 mesh is generated")
local r6right=node("CharacterMesh","CustomRightLeg");r6right.BodyPart="RightLeg";r6right.MeshId="custom-right-leg";r6right.Parent=r6template
assert(r6api.applyBodyPart("RightLeg",456):match("RightLeg") and r6:FindFirstChild("CustomRightLeg"),"R6 applies a valid second limb region")
assert(r6:FindFirstChild("Left Leg")==leftLeg and r6:FindFirstChild("Right Leg")==rightLeg and r6:FindFirstChild("R6 game gear")==r6gear,"R6 region changes preserve live limbs and game gear")
assert(r6api.restoreBodyPart("LeftLeg"):match("restored") and not r6:FindFirstChild("CustomLeftLeg") and r6:FindFirstChild("CustomRightLeg") and r6:FindFirstChild("GirlMesh"),"R6 individual region restore preserves the other custom region and torso")
assert(r6api.applyBodyPart("RightLeg",0):match("RightLeg") and not r6:FindFirstChild("CustomRightLeg"),"R6 default limb removes a custom CharacterMesh region")
assert(r6api.restoreBody():match("restored"),"R6 full restore reports success")
assert(r6:FindFirstChild("BodyMesh"),"R6 full restore returns original meshes")
assert(not r6:FindFirstChild("CustomRightLeg"),"R6 full restore removes custom regions")
assert(r6:FindFirstChild("R6 game gear")==r6gear,"R6 full restore keeps game gear")
r6api.destroy();players.template=oldTemplate

-- Destroying during template generation cancels the completed operation.
players.template=template; local cancel=create(player); players.onGenerate=function()cancel.destroy()end; local cancelled=pcall(function()cancel.applyBody("Robloxian 2.0")end); players.onGenerate=nil; assert(not cancelled,"destroy during generation cancels operation")

-- Failed assets have no side effects; repeated keys remain unique after removal.
local clean=create(player); local count=#body:GetChildren();mode="blocked";assert(not pcall(function()clean.equipAccessory(123)end) and #body:GetChildren()==count,"blocked asset has no side effects");mode="normal";local a=clean.equipAccessory(123);local first=clean.listAccessories()[1].key;clean.equipAccessory(123);local second=clean.listAccessories()[2].key;assert(first~=second,"repeated equips receive unique keys");clean.removeAccessory(first);assert(#clean.listAccessories()==1,"individual removal keeps other accessory");clean.destroy()
-- Original Roblox accessories can be hidden without deleting them or hub-added hats.
local originalHat=freshAccessory();originalHat.Name="Original Roblox Hat";originalHat.Parent=body
local wardrobe=create(player);wardrobe.equipAccessory(123)
local addedHat=wardrobe.listAccessories()[1]
wardrobe.removeCurrentAccessories()
assert(originalHat.Parent==body and originalHat:FindFirstChild('Handle').Transparency==1 and not originalHat.destroyed,"original accessory is hidden without changing its parent")
assert(#wardrobe.listAccessories()==1 and wardrobe.listAccessories()[1].key==addedHat.key,"hub-added accessory stays equipped")
wardrobe.removeCurrentAccessories();wardrobe.restore()
assert(originalHat.Parent==body and not originalHat.destroyed,"restore returns original hat")
assert(#wardrobe.listAccessories()==0,"restore removes hub-added hats")
wardrobe.removeCurrentAccessories();wardrobe.destroy()
assert(originalHat.Parent==body,"closing or refreshing returns original hats")

-- Saved selections survive editor recreation and a fresh character, while restore clears them.
mode="normal"; local persist=create(player); persist.equipAccessory(123); persist.setSkin(Color3.fromRGB(128,96,64),"All"); persist.applyBody("https://www.roblox.com/bundles/555")
local saved=persist.getSettings(); assert(saved and saved.accessories and #saved.accessories==1 and saved.colors and saved.colors.All and saved.hideOriginals==true,"getSettings returns normalized saved selections")
persist.destroy(); local resumed=create(player); local fresh=body:Clone(); local freshHum=fresh:FindFirstChildOfClass("Humanoid"); freshHum.Health=100; freshHum.RigType=Enum.HumanoidRigType.R15; freshHum.replaced={}; freshHum.GetAppliedDescription=hum().GetAppliedDescription; freshHum.ReplaceBodyPartR15=function(self,n,p)self.replaced[n]=p;p.Parent=self.Parent;return true end; freshHum.AddAccessory=function(self,a)a.Parent=self.Parent end; local freshHat=freshAccessory();freshHat.Name="Original Roblox Hat";freshHat.Parent=fresh; player.Character=fresh; player.CharacterAdded:Fire(fresh)
while #task.queue>0 do local work=table.remove(task.queue,1);work() end
assert(resumed.getSettings().accessories and #resumed.getSettings().accessories==1,"new editor reads prior session settings"); assert(freshHat.Parent==fresh and freshHat:FindFirstChild("Handle").Transparency==1 and not freshHat.destroyed,"saved hideOriginals hides fresh original accessories without reparenting"); local replay=resumed.reapplySaved(); assert(type(replay)=="string" and #replay>0,"saved accessories/body/color replay on fresh character"); local count=#resumed.listAccessories(); resumed.reapplySaved(); assert(#resumed.listAccessories()==count,"manual replay does not duplicate cosmetics")
mode="blocked"; local failed=pcall(function()resumed.reapplySaved()end); assert(failed,"blocked saved asset reports without throwing"); local failedMessage=resumed.reapplySaved(); assert(failedMessage:match("some could not load") and #resumed.getSettings().accessories==1,"failed saved accessory remains persisted")
mode="normal"; resumed.restore(); local cleared=resumed.getSettings(); assert((not cleared.accessories or #cleared.accessories==0) and freshHat.Parent==fresh,"restore clears saved selections and restores original hat"); resumed.destroy()

-- Skin-only restore keeps added hats, body changes, and hidden originals while clearing saved colors.
player.Character=body
local originalSkin=Color3.new(.8,.7,.6)
player.Character:FindFirstChild("Head").Color=originalSkin
local skinOnly=create(player); local hiddenHat=freshAccessory();hiddenHat.Name="Hidden Original Hat";hiddenHat.Parent=player.Character
skinOnly.equipAccessory(123); skinOnly.equipAccessory(123); skinOnly.removeCurrentAccessories(); skinOnly.applyBody("https://www.roblox.com/bundles/555"); skinOnly.setSkin(Color3.new(.2,.3,.4),"All")
local beforeSkinOnly=skinOnly.getSettings(); assert(beforeSkinOnly.hideOriginals and beforeSkinOnly.body and #skinOnly.listAccessories()==2,"skin-only setup keeps multiple cosmetics")
local changedBodyHead=player.Character:FindFirstChild("Head")
skinOnly.restoreSkin(); local afterSkinOnly=skinOnly.getSettings()
assert(#skinOnly.listAccessories()==2 and hiddenHat.Parent==body and hiddenHat:FindFirstChild("Handle").Transparency==1 and not hiddenHat.destroyed,"skin-only restore preserves added hats and hidden originals")
assert(afterSkinOnly.hideOriginals and afterSkinOnly.body and next(afterSkinOnly.colors)==nil,"skin-only restore clears saved colors only")
assert(player.Character:FindFirstChild("Head")==changedBodyHead and changedBodyHead.Color==originalSkin,"skin-only restore returns actual original color without replacing body")
skinOnly.destroy()

-- Mixed R15 regions replace only selected segments and restore keeps hats and colors.
player.Character=body; local mixed=create(player); local mixedRoot=body:FindFirstChild("HumanoidRootPart"); local mixedHead=body:FindFirstChild("Head"); mixedHead.Color=Color3.new(.7,.6,.5)
local mixedHat=freshAccessory();mixedHat.Name="Mixed Hat";mixedHat.Parent=body
body:FindFirstChild("LeftUpperArm").MeshId="original-arm"
template:FindFirstChild("LeftUpperArm").MeshId="custom-arm"
assert(mixed.applyBodyPart("LeftArm","https://www.roblox.com/bundles/555"):match("LeftArm")); marketplace.assetType=31
assert(body:FindFirstChild("LeftUpperArm").MeshId=="custom-arm","selected arm geometry actually changes")
assert(mixed.applyBodyPart("RightLeg",456):match("RightLeg")); local mixedSettings=mixed.getSettings()
assert(mixedSettings.bodyParts.LeftArm and mixedSettings.bodyParts.RightLeg,"mixed body selections are saved")
assert(body:FindFirstChild("HumanoidRootPart")==mixedRoot and body:FindFirstChild("Head")==mixedHead,"mixed replacement preserves unrelated parts")
marketplace.assetType=27; assert(not pcall(function()mixed.applyBodyPart("Head",456)end),"wrong catalog category is rejected")
assert(mixed.restoreBody():match("restored") and mixedHat.Parent==body and mixedHead.Color.r==.7,"restoreBody keeps hats and colors")
assert(body:FindFirstChild("LeftUpperArm").MeshId=="original-arm","body-only restore restores geometry after only region changes")
assert(next(mixed.getSettings().bodyParts)==nil and not mixed.getSettings().body,"restoreBody clears body selections")
marketplace.assetType=79
mixed.applyBodyPart("Head","https://www.roblox.com/catalog/789/Dynamic-Head")
assert(players.lastDescription.Head==789,"dynamic head catalog ID is passed to body generation")
mixed.applyBodyPart("Head","https://www.roblox.com/bundles/555/Head")
assert(players.lastDescription.Head==901,"head bundle uses outfit head asset")
http.bundleType="AvatarAnimations"
assert(not pcall(mixed.applyBodyPart,"Head","https://www.roblox.com/bundles/82/Robot"),"animation bundles cannot replace body parts")
http.bundleType="BodyParts"
local partialHead=body:FindFirstChild("Head")
mixed.reapplySaved()
assert(mixed.getSettings().bodyParts.Head and body:FindFirstChild("Head")==partialHead and not partialHead.destroyed,"custom heads survive saved replay without destroying the head")
mixed.applyBody("Girl")
assert(next(mixed.getSettings().bodyParts)==nil,"new full body package clears mixed overrides")
mixed.destroy()
-- Equipped gear grips live on hands; cosmetic body changes must preserve them.
player.Character=body
local gear=node("Tool","Equipped gear");gear.Parent=body
local gearHandle=node("Part","Handle");gearHandle.Parent=gear
local rightHand=body:FindFirstChild("RightHand")
local grip=node("Weld","RightGrip");grip.Part0=rightHand;grip.Part1=gearHandle;grip.Parent=rightHand
local gearScript=node("LocalScript","GameGearController");gearScript.Parent=rightHand
local backpack=node('Backpack','Backpack');player.Backpack=backpack
local storedGear=node('Tool','Stored gear');storedGear.Parent=backpack
local gameEquipment=freshAccessory();gameEquipment.Name='Game weapon';gameEquipment.SourceAssetId=0;gameEquipment.Parent=body
local gameHandle=gameEquipment:FindFirstChild('Handle')
local gameWeld=node('Weld','GameWeaponJoint');gameWeld.Part0=gameHandle;gameWeld.Part1=rightHand;gameWeld.Parent=gameHandle
local weaponController=node('LocalScript','GameWeaponController');weaponController.Parent=gameEquipment
local appliedHat=freshAccessory();appliedHat.SourceAssetId=nil;appliedHat.Parent=body
player.UserId=55
function players:GetCharacterAppearanceInfoAsync(id)
    assert(id==55);self.appearanceReads=(self.appearanceReads or 0)+1
    return {assets={{id=555,name='Account hair',assetType={id=41}},{id=777,name='Game weapon',assetType={id=19}}}}
end
local accountHair=freshAccessory();accountHair.Name='Account hair';accountHair.SourceAssetId=nil;accountHair.Parent=body
local renamedHat=freshAccessory();renamedHat.Name='Renamed server hat';renamedHat.SourceAssetId=nil;renamedHat.Parent=body
local renamedAttachment=node('Attachment','HatAttachment');renamedAttachment.CFrame=cf();renamedAttachment.Parent=renamedHat:FindFirstChild('Handle')
local bodyAccessories={}
for _,spec in ipairs({{'GravyScarf','NeckAttachment'},{'FestiveChristmasPixaxePack','BodyBackAttachment'}}) do
    local a=freshAccessory();a.Name=spec[1];a.SourceAssetId=nil;a.Parent=body
    node('Attachment',spec[2]).Parent=a:FindFirstChild('Handle')
    node('Attachment',spec[2]).Parent=body:FindFirstChild('UpperTorso')
    table.insert(bodyAccessories,a)
end
local hairHandle=accountHair:FindFirstChild('Handle');hairHandle.Transparency=0.3
local hairEffect=node('ParticleEmitter','Hair effect');hairEffect.Enabled=true;hairEffect.Parent=hairHandle
local liveDescription=node('HumanoidDescription','Live Description');liveDescription.Parent=body:FindFirstChildOfClass('Humanoid')
local hatDescription=node('AccessoryDescription','Avatar Hat');hatDescription.Parent=liveDescription
function hatDescription:GetAppliedInstance()return appliedHat end
-- Original Korblox Deathspeaker asset 139607718 hides these R15ArtistIntent placeholders.
for _,name in ipairs({'RightLowerLeg','RightFoot'}) do
    template:FindFirstChild(name).Transparency=1;body:FindFirstChild(name).Transparency=0
end
local gearApi=create(player)
local upper=body:FindFirstChild('LeftUpperArm');local lower=body:FindFirstChild('LeftLowerArm')
upper.Size={X=1,Y=2,Z=1};template:FindFirstChild('LeftUpperArm').Size={X=0.8,Y=1.4,Z=0.8}
local elbow0=node('Attachment','LeftElbowRigAttachment');elbow0.CFrame=cf(0,-1,0);elbow0.Parent=upper
local elbow1=node('Attachment','LeftElbowRigAttachment');elbow1.CFrame=cf(0,1,0);elbow1.Parent=lower
local sourceElbow0=node('Attachment','LeftElbowRigAttachment');sourceElbow0.CFrame=cf(0,-0.7,0);sourceElbow0.Parent=template:FindFirstChild('LeftUpperArm')
local sourceElbow1=node('Attachment','LeftElbowRigAttachment');sourceElbow1.CFrame=cf(0,0.6,0);sourceElbow1.Parent=template:FindFirstChild('LeftLowerArm')
local elbow=node('Motor6D','LeftElbow');elbow.Part0=upper;elbow.Part1=lower;elbow.C0=elbow0.CFrame;elbow.C1=elbow1.CFrame;elbow.Parent=lower
local heldAttachment=node('Attachment','RightGripAttachment');heldAttachment.CFrame=cf(0,0.25,0);heldAttachment.Parent=rightHand
local templateGrip=node('Attachment','RightGripAttachment');templateGrip.CFrame=cf(0,9,0);templateGrip.Parent=template:FindFirstChild('RightHand')
body:FindFirstChildOfClass('Humanoid').HipHeight=2
local templateHumanoid=hum();templateHumanoid.HipHeight=1.5;templateHumanoid.Parent=template
gearApi.applyBody("Girl")
assert(body:FindFirstChild('RightLowerLeg').Transparency==1 and body:FindFirstChild('RightFoot').Transparency==1,'Korblox hidden lower-leg and foot placeholders must not become visible fragments')
assert(upper.Size.Y==1.4 and elbow0.CFrame.y==-0.7 and elbow.C0.y==-0.7 and elbow.C1.y==0.6,'Package proportions and existing skeletal joints must match the source package')
assert(not grip.destroyed and grip.Parent==rightHand and not gearScript.destroyed,"cosmetic body change destroyed equipped gear grip or controller")
assert(body:FindFirstChild("RightHand")==rightHand and gear.Parent==body and not gear.destroyed,"cosmetics replaced the live gear-holding hand or equipped tool")
assert(heldAttachment.CFrame.y==0.25 and body:FindFirstChildOfClass('Humanoid').HipHeight==1.5,'Package applies floor height without moving gear attachment offsets')
gearApi.removeCurrentAccessories()
for _,a in ipairs(bodyAccessories) do assert(a:FindFirstChild('Handle').Transparency==1,'Neck and back avatar accessories must be hidden: '..a.Name) end
assert(renamedHat:FindFirstChild('Handle').Transparency==1,'Head attachment fallback hides hats with missing asset identity and different server names')
local accessoryReport=gearApi.accessoryReport()
assert(accessoryReport:find('Renamed server hat',1,true) and accessoryReport:find('avatar match=true',1,true),'Accessory report includes the live detection path')
assert(gameEquipment.Parent==body and gameHandle.Transparency~=1 and not gameWeld.destroyed and not weaponController.destroyed,'Avatar hat hiding leaves game weapons and their welds/controllers alone')
assert(appliedHat.Parent==body and appliedHat:FindFirstChild('Handle').Transparency==1,'Public applied accessory descriptions identify hats without protected SourceAssetId')
local originalHandle=appliedHat:FindFirstChild('Handle')
originalHandle.LocalTransparencyModifier=0 -- Roblox's camera resets this during normal play.
gearApi.equipAccessory(123);local removable=gearApi.listAccessories();gearApi.removeAccessory(removable[#removable].key)
assert(originalHandle.Transparency==1,'Removing added hats must not reveal originals after the camera resets local transparency')
assert(hairHandle.Transparency==1 and not hairEffect.Enabled,'Account accessory names hide originals and their effects when asset IDs cannot be read')
assert(gearApi.getSettings().hideOriginals==true,'Removing added hats preserves the originals-hidden setting')
originalHandle.Transparency=0;gearApi.removeCurrentAccessories()
assert(originalHandle.Transparency==1 and players.appearanceReads==1,'Repeated remove re-hides existing originals without another account lookup')
local stayedHiddenDuringLoad=false
players.onGenerate=function()stayedHiddenDuringLoad=originalHandle.Transparency==1 end
local hiddenReplay=gearApi.reapplySaved();players.onGenerate=nil
assert(stayedHiddenDuringLoad and not hiddenReplay:find('some could not load',1,true),'Replaying cosmetics keeps originals hidden throughout successful asset loading')
gearApi.restoreBody()
assert(body:FindFirstChild('RightLowerLeg').Transparency==0 and body:FindFirstChild('RightFoot').Transparency==0,'Restore reveals the original visible leg and foot')
assert(upper.Size.Y==2 and elbow.C0.y==-1 and elbow.C1.y==1 and elbow0.CFrame.y==-1,'Restore returns original dimensions, attachment positions, and existing motor offsets')
assert(body:FindFirstChildOfClass('Humanoid').HipHeight==2,'Restore returns original floor height')
marketplace.assetType=31
gearApi.applyBodyPart('RightLeg',139607718)
assert(body:FindFirstChild('RightLowerLeg').Transparency==1 and body:FindFirstChild('RightFoot').Transparency==1,'A mixed Korblox right leg preserves the original hidden segments too')
gearApi.restoreBody();marketplace.assetType=28
body:FindFirstChildOfClass('Humanoid').failName='LeftLowerArm'
assert(not pcall(gearApi.applyBodyPart,'LeftArm','https://www.roblox.com/bundles/555'),'A blocked region fails safely')
body:FindFirstChildOfClass('Humanoid').failName=nil
assert(upper.Size.Y==2 and elbow0.CFrame.y==-1 and elbow.C0.y==-1,'Failed package operation rolls back dimensions, attachment offsets, and joints')
gearApi.applyBodyPart('LeftArm','https://www.roblox.com/bundles/555')
assert(upper.Size.Y==1.4 and elbow.C0.y==-0.7 and body:FindFirstChildOfClass('Humanoid').HipHeight==2,'Mixed arm applies its own proportions without changing floor height')
gearApi.restoreBody()
gearApi.reapplySaved();gearApi.destroy()
assert(not grip.destroyed and gear.Parent==body,"restore, replay, and cleanup preserve equipped gear")
assert(storedGear.Parent==backpack and not storedGear.destroyed and not gameWeld.destroyed,'Backpack gear and game weapon joints survive all cosmetic operations')
assert(appliedHat:FindFirstChild('Handle').Transparency==0,'Cleanup restores hidden avatar visuals without destroying inventory')
assert(hairHandle.Transparency==0.3 and hairEffect.Enabled,'Cleanup restores original accessory transparency and effects exactly')
for _,a in ipairs(bodyAccessories) do assert(a:FindFirstChild('Handle').Transparency==0,'Cleanup restores neck and back accessories') end
assert(renamedHat:FindFirstChild('Handle').Transparency==0,'Head attachment fallback preserves reversible visibility')
-- A Part-based R15 head keeps its existing face, joints, and controllers too.
Enum.MeshType={FileMesh='FileMesh'}
Vector3={new=function(x,y,z)return{X=x,Y=y,Z=z}end}
local headCharacter=body:Clone();headCharacter:FindFirstChild('Head'):Destroy()
local partHead=node('Part','Head');partHead.CFrame=cf();partHead.Size=Vector3.new(2,2,2);partHead.Color=Color3.new(1,1,1);partHead.Parent=headCharacter
local headJoint=node('Weld','GameHeadJoint');headJoint.Parent=partHead
local originalHeadMesh=node('SpecialMesh','OriginalHeadMesh');originalHeadMesh.Parent=partHead
local headPlayer={Character=headCharacter,CharacterAdded=signal()}
function headPlayer:FindFirstChildOfClass()return nil end
local sourceHead=template:FindFirstChild('Head');sourceHead.MeshId='head-shape';sourceHead.MeshSize=Vector3.new(4,4,4)
local headEditor=create(headPlayer);marketplace.assetType=79
headEditor.applyBodyPart('Head',789)
assert(headCharacter:FindFirstChild('Head')==partHead and not headJoint.destroyed,'Part head keeps game-owned identity and joints')
local headMesh=partHead:FindFirstChildOfClass('SpecialMesh')
assert(headMesh.MeshId=='head-shape' and headMesh.Scale.X==0.5,'Part head uses properly scaled visual geometry')
headEditor.restoreBody()
assert(partHead:FindFirstChild('OriginalHeadMesh') and not headJoint.destroyed,'Part head visual restore preserves game joints')
headEditor.destroy()
print("Avatar backend fixture and lifecycle tests passed.")

-- Exercise the real rigid accessory attachment path for each supported region.
player.Character=body;local accessoryEditor=create(player)
local previousObjects=game.GetObjects;local fixtureAttachment="BodyBackAttachment";local layered=false
local regions={HatAttachment="Head",HairAttachment="Head",FaceFrontAttachment="Head",NeckAttachment="UpperTorso",LeftCollarAttachment="UpperTorso",BodyFrontAttachment="UpperTorso",BodyBackAttachment="UpperTorso",WaistCenterAttachment="LowerTorso"}
for name,partName in pairs(regions)do local part=body:FindFirstChild(partName);part.CFrame=cf();local a=part:FindFirstChild(name);if not a then a=node("Attachment",name);a.Parent=part end;a.CFrame=cf()end
game.GetObjects=function(_,id)
    local item=node("Accessory","Region accessory");local h=node("Part","Handle");h.CFrame=cf();h.AttachmentPoint=cf();h.Parent=item
    local a=node("Attachment",fixtureAttachment);a.CFrame=cf();a.Parent=h
    if layered then node("WrapLayer","WrapLayer").Parent=h end
    return{item}
end
for name,partName in pairs(regions)do
    fixtureAttachment=name;accessoryEditor.equipAccessory(19399858)
    local entry=accessoryEditor.listAccessories()[1];local object
    for _,candidate in ipairs(body:GetChildren())do if candidate.Name=="Region accessory"then object=candidate end end
    assert(object and object:FindFirstChild("Handle"):FindFirstChild("AccessoryWeld").Part1.Name==partName,"accessory attaches to its correct region: "..name)
    accessoryEditor.removeAccessory(entry.key)
end
layered=true;fixtureAttachment="BodyFrontAttachment";accessoryEditor.equipAccessory(123)
assert(#accessoryEditor.listAccessories()==1,"R15 layered accessory uses native Humanoid attachment")
accessoryEditor.clearAccessories();body:FindFirstChildOfClass("Humanoid").RigType=Enum.HumanoidRigType.R6
assert(not pcall(accessoryEditor.equipAccessory,123),"R6 layered clothing reports unsupported rig")
body:FindFirstChildOfClass("Humanoid").RigType=Enum.HumanoidRigType.R15
accessoryEditor.destroy();game.GetObjects=previousObjects
print("Accessory head, hair, face, neck, shoulder, front, back, waist and R15 layered attachment passed.")

local generatedParts=0;local generatePart=players.CreateHumanoidModelFromDescriptionAsync
function players:CreateHumanoidModelFromDescriptionAsync(...)generatedParts=generatedParts+1;return generatePart(self,...)end
local partRestore=create(player)
marketplace.assetType=30;partRestore.applyBodyPart("LeftLeg",123)
marketplace.assetType=28;partRestore.applyBodyPart("RightArm",456)
partRestore.restoreBodyPart("LeftLeg")
assert(partRestore.getSettings().bodyParts.LeftLeg==nil and partRestore.getSettings().bodyParts.RightArm==456,"restoring one body region preserves other mixed parts")
partRestore.applyBodyPart("LeftLeg",0)
assert(partRestore.getSettings().bodyParts.LeftLeg==0 and players.lastDescription.LeftLeg==0,"default body part is generated and saved as an explicit reset")
local beforeReequip=generatedParts
marketplace.assetType=30;partRestore.applyBodyPart("LeftLeg",123)
assert(generatedParts==beforeReequip,"re-equipping a validated body part reuses its prepared model without another Roblox generation request")
partRestore.restoreBodyPart("LeftLeg")
partRestore.destroy()
local faceHead=body:FindFirstChild("Head")
local originalFace=node("Decal","face");originalFace.Texture="original-face";originalFace.Parent=faceHead
local faceReads=0
game.GetObjects=function()faceReads=faceReads+1;local face=node("Decal","face");face.Texture="new-face";return{face}end
local faceEditor=create(player);faceEditor.applyFace(900)
assert(faceHead:FindFirstChildOfClass("Decal").Texture=="new-face","browser face asset applies to existing head")
assert(faceEditor.getSettings().face==900,"face selection persists")
faceEditor.restoreFace();assert(faceHead:FindFirstChildOfClass("Decal").Texture=="original-face","face restoration preserves original")
faceEditor.applyFace(900);assert(faceReads==1,"face re-equip reuses validated texture")
faceEditor.destroy();assert(faceHead:FindFirstChildOfClass("Decal").Texture=="original-face","cleanup restores original face")
marketplace.assetType=17
local headlessFaceEditor=create(player)
headlessFaceEditor.applyBodyPart("Head",134082579)
assert(headlessFaceEditor.getSettings().bodyParts.Head==134082579)
headlessFaceEditor.applyFace(900)
assert(headlessFaceEditor.getSettings().bodyParts.Head==nil,"classic face removes the active Headless override")
assert(faceHead:FindFirstChildOfClass("Decal").Texture=="new-face","face is applied after restoring the visible head")
headlessFaceEditor.destroy()
game.GetObjects=previousObjects
print("Classic face equip, cache, persistence and restore passed.")

local effectEditor=create(player)
game.GetObjects=function()
    local hat=node("Accessory","TheDusekkar");hat.AttachmentPoint=cf()
    local handle=node("Part","Handle");handle.CFrame=cf();handle.Parent=hat
    for _,class in ipairs({"Fire","Smoke"})do local effect=node(class,class);effect.Enabled=false;effect.Parent=handle end
    node("Script","DusekkarScript").Parent=handle
    return{hat}
end
for _,id in ipairs({1474657,123})do
    effectEditor.equipAccessory(id)
    local hat=body:FindFirstChild("TheDusekkar")
    assert(hat:FindFirstChild("Fire",true).Enabled==(id==1474657),"Dusekkar effects work for any wearer without changing other hats")
    assert(hat:FindFirstChild("Smoke",true).Enabled==(id==1474657),"Dusekkar smoke enabled")
    assert(not hat:FindFirstChild("DusekkarScript",true),"asset scripts remain removed")
    effectEditor.clearAccessories()
end
effectEditor.destroy();game.GetObjects=previousObjects
print("Dusekkar fire and smoke enable without an owner restriction; other hats remain unchanged.")

-- Smokestack's normal smoke is separate from its disabled holiday emitters.
local smokestack=create(player)
game.GetObjects=function()
    local hat=node("Accessory","RbadamTophat");hat.AttachmentPoint=cf()
    local handle=node("Part","Handle");handle.CFrame=cf();handle.Parent=hat
    local attachment=node("Attachment","HatAttachment");attachment.CFrame=cf();attachment.Parent=handle
    for _,name in ipairs({"ParticleEmitter","Burst","Hallow","Confetti","Smokescreen"})do
        local effect=node("ParticleEmitter",name);effect.Enabled=false;effect.Parent=attachment
    end
    node("Script","HatScript2.0").Parent=attachment
    return{hat}
end
for _,id in ipairs({169444515,123})do
    smokestack.equipAccessory(id)
    local hat=body:FindFirstChild("RbadamTophat")
    assert(hat:FindFirstChild("ParticleEmitter",true).Enabled==(id==169444515),"Smokestack original smoke works for any wearer; other hats stay unchanged")
    for _,name in ipairs({"Burst","Hallow","Confetti","Smokescreen"})do assert(not hat:FindFirstChild(name,true).Enabled,"Holiday emitters stay off")end
    assert(not hat:FindFirstChild("HatScript2.0",true),"Smokestack asset script remains removed")
    smokestack.clearAccessories()
    assert(not body:FindFirstChild("RbadamTophat"),"Removing Smokestack removes its effects")
end
smokestack.destroy();game.GetObjects=previousObjects
print("Smokestack original smoke enables without holiday effects or asset scripts.")

-- Modern dynamic heads carry their face in a child SurfaceAppearance, not TextureID.
player.Character=body;players.template=template;marketplace.assetType=79
local liveHead=body:FindFirstChild("Head")
for _,v in ipairs(liveHead:GetChildren())do if v:IsA("SurfaceAppearance")or v:IsA("Decal")then v:Destroy()end end
local originalFace=node("Decal","face");originalFace.Texture="original-face";originalFace.Parent=liveHead
local templateHead=template:FindFirstChild("Head")
local surface=node("SurfaceAppearance","SurfaceAppearance");surface.ColorMap="dynamic-face-map";surface.Parent=templateHead
local dynamic=create(player);dynamic.applyBodyPart("Head",106418043406599)
assert(liveHead:FindFirstChildOfClass("SurfaceAppearance").ColorMap=="dynamic-face-map","dynamic face surface is copied with the mesh")
assert(not liveHead:FindFirstChildOfClass("Decal"),"old face does not cover the dynamic head")
dynamic.restoreBodyPart("Head")
assert(not liveHead:FindFirstChildOfClass("SurfaceAppearance"),"restoring removes the dynamic face surface")
assert(liveHead:FindFirstChildOfClass("Decal").Texture=="original-face","restoring preserves the original face")
dynamic.destroy();surface:Destroy()
print("Dynamic head surface copy and original face restoration passed.")
