local source=assert(avatarSource,"run python tests/check_smokestack.py")
local helper=source:match("(local smokestackStates=.-)local groups=")
assert(helper,"seasonal helper exists")
local function node(class,name,parent)
 local n={ClassName=class,Name=name,Parent=parent,children={},Transparency=0,Texture="original-particle",Enabled=false}
 function n:IsA(c)return self.ClassName==c end
 function n:FindFirstChild(name)for _,v in ipairs(self.children)do if v.Name==name then return v end end end
 function n:FindFirstChildOfClass(c)for _,v in ipairs(self.children)do if v:IsA(c)then return v end end end
 function n:GetDescendants()local a={};local function visit(o)for _,v in ipairs(o.children)do a[#a+1]=v;visit(v)end end;visit(self);return a end
 function n:Destroy()self.destroyed=true;self.Parent=nil end
 if parent then parent.children[#parent.children+1]=n end
 return n
end
local made={}
Instance={new=function(c)local n=node(c,c);made[#made+1]=n;return n end}
Vector2={new=function()return {}end};UDim2={fromScale=function()return {}end};Color3={fromRGB=function()return {}end}
local apply=assert(load(helper.."return applySmokestackSeasonal"))()
local hat=node("Accessory","RbadamTophat")
local handle=node("MeshPart","Handle",hat);handle.TextureID="default"
local effects={}
for _,name in ipairs({"ParticleEmitter","Burst","Hallow","Leaf1","Leaf2","Snowflake1","Snowflake2","Snowflake3","Confetti","Clover1","Clover2","Heart","Hats","Smokescreen"})do effects[name]=node("ParticleEmitter",name,handle)end
local function check(m,d,texture,names)
 local state=apply(hat,{year=2026,month=m,day=d})
 assert(handle.TextureID==(texture and "rbxassetid://"..texture or "default"),"hat texture "..m.."/"..d)
 for name,effect in pairs(effects)do
  assert(effect.Enabled==(names[name]==true),"effect "..name.." on "..m.."/"..d)
  assert(effect.Texture=="original-particle","particle textures preserved")
 end
 return state
end
local normal={ParticleEmitter=true}
check(10,21,nil,normal);check(10,22,"6991166143",{Hallow=true});check(10,31,"6991166143",{Hallow=true});check(11,1,nil,normal)
check(11,19,nil,normal);check(11,20,"6991393806",{ParticleEmitter=true,Leaf1=true,Leaf2=true});check(11,30,"6991393806",{ParticleEmitter=true,Leaf1=true,Leaf2=true});check(12,1,nil,normal)
check(12,17,nil,normal);check(12,18,nil,{Snowflake1=true,Snowflake2=true,Snowflake3=true});check(12,27,nil,{Snowflake1=true,Snowflake2=true,Snowflake3=true});check(12,28,nil,normal)
check(2,8,nil,normal);check(2,9,"2399448372",{Heart=true});check(2,16,"2399448372",{Heart=true});check(2,17,nil,normal)
check(3,11,nil,normal);check(3,12,"2399447918",{ParticleEmitter=true,Clover1=true,Clover2=true});check(3,19,"2399447918",{ParticleEmitter=true,Clover1=true,Clover2=true});check(3,20,nil,normal)
local birthday=check(8,27,"2399316028",{Confetti=true});assert(birthday.birthday~=nil and made[#made].Text=="20","birthday age displays 2026 minus 2006")
check(8,28,nil,normal);assert(not birthday.birthday,"birthday display removed")
local april=check(4,1,nil,{Hats=true,Smokescreen=true});assert(handle.Transparency==1)
check(4,2,nil,normal);assert(handle.Transparency==0)
april.cleanup();assert(handle.TextureID=="default" and not effects.ParticleEmitter.Enabled)
-- Older assets use a Part/SpecialMesh instead of MeshPart.
local legacy=node("Accessory","Legacy");local part=node("Part","Handle",legacy);local mesh=node("SpecialMesh","Mesh",part);mesh.TextureId="legacy-default"
local state=apply(legacy,{year=2026,month=10,day=22});assert(mesh.TextureId=="rbxassetid://6991166143");state.cleanup();assert(mesh.TextureId=="legacy-default")
for style,expected in pairs({normal="default",halloween="rbxassetid://6991166143",thanksgiving="rbxassetid://6991393806",christmas="default",birthday="rbxassetid://2399316028",stpatricks="rbxassetid://2399447918",valentines="rbxassetid://2399448372",aprilfools="default"})do
 apply(hat,{year=2026,month=1,day=1},style)
 assert(handle.TextureID==expected,"manual style "..style.." overrides the calendar")
end
apply(hat,{year=2026,month=10,day=22},"auto");assert(effects.Hallow.Enabled and handle.Transparency==0,"Automatic restores current season and visibility")
assert(not pcall(apply,hat,{year=2026,month=1,day=1},"unknown"),"unknown styles rejected")
local metaSource=source:match("(local function accessoryMeta.-)local function sameMeta")
local clean=assert(load(helper..metaSource.."return accessoryMeta"))()
assert(clean({smokestackStyle="halloween"}).smokestackStyle=="halloween","style survives metadata validation")
assert(not pcall(clean,{smokestackStyle="invalid"}),"metadata rejects unknown styles")
print("Smokestack holiday boundaries, effects, texture restoration, birthday, and cleanup passed.")
