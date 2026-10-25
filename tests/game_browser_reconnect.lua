-- Mocked relay/Roblox check for game_browser_sync.lua. Run with lupa (see parent command).
local function color(r,g,b)return {R=r/255,G=g/255,B=b/255}end
math.clamp=function(v,a,b)return math.max(a,math.min(b,v))end
local body={HeadColor3=color(255,0,0),TorsoColor3=color(0,255,0),LeftArmColor3=color(0,0,255),RightArmColor3=color(255,255,0),LeftLegColor3=color(255,0,255),RightLegColor3=color(0,255,255)}
local character={BodyColors=body,Head={Color=color(255,0,0)},UpperTorso={Color=color(0,255,0)}}
function character:FindFirstChildOfClass(k)return k=="BodyColors" and body or k=="Humanoid" and self.humanoid end
local desc={Shirt=101,Pants=202,Head=301,Face=302,Torso=303,LeftArm=304,RightArm=305,LeftLeg=306,RightLeg=307,GraphicTShirt=308,HeightScale=1,WidthScale=1,DepthScale=1,HeadScale=1,BodyTypeScale=0,ProportionScale=0}
function desc:GetAccessories()return {{AssetId=11,Name="Original Hat"}} end
for _,property in ipairs({"ClimbAnimation","FallAnimation","IdleAnimation","JumpAnimation","RunAnimation","SwimAnimation","WalkAnimation"})do desc[property]=0 end
setmetatable(desc,{__index=function(_,property)error(property.." is not a valid member of HumanoidDescription")end})
local humanoid={Health=100,RigType={Name="R15"}}
function humanoid:GetAppliedDescription()return desc end
function humanoid:FindFirstChild()return nil end
humanoid.Parent=character;character.humanoid=humanoid
local player={UserId=7,Character=character}
function player:FindFirstChildOfClass()return nil end
function character:GetDescendants()return {}end
table.clear=table.clear or function(value)for key in pairs(value)do value[key]=nil end end
local localHats={{key=1,id=12,name="Local Hat"}}
local gearEntry=nil
local settings={accessories={12},hideOriginals=false,colors={},bodyParts={},body="Blocky",face=302}
local avatar={}
local bodyCalls={}
local faceCalls={}
function avatar.getSettings()return settings end
function avatar.listAccessories()local entries={};for i,entry in ipairs(localHats)do entries[i]=entry end;return entries end
function avatar.listGear()return gearEntry and {gearEntry} or {} end
function avatar.equipGear(id)gearEntry={id=id,name="Gear"} end
function avatar.removeGear()gearEntry=nil end
function avatar.removeAccessory(key)for i,v in ipairs(localHats)do if v.key==key then table.remove(localHats,i)end end end
function avatar.equipAccessory(id)assert(id~=11,"an already worn original cannot be downloaded again");localHats[#localHats+1]={key=id,id=id,name="Added"}end
function avatar.clearAccessories()localHats={}end
function avatar.removeCurrentAccessories()settings.hideOriginals=true end
function avatar.applyBodyPart(region,id)bodyCalls[#bodyCalls+1]={region,id};settings.bodyParts[region]=id end
function avatar.restoreBodyPart(region)bodyCalls[#bodyCalls+1]={region,"restore"};settings.bodyParts[region]=nil end
function avatar.applyFace(id)faceCalls[#faceCalls+1]={"apply",id};settings.face=id end
function avatar.restoreFace()faceCalls[#faceCalls+1]={"restore"};settings.face=302 end
local clothes={Shirt=101,Pants=202};local clothing={}
function clothing.getSettings()return clothes end
function clothing.equipShirt(id)clothes.Shirt=id end
function clothing.equipPants(id)clothes.Pants=id end
function clothing.removeShirt()clothes.Shirt=0 end
function clothing.removePants()clothes.Pants=0 end
local http={}
function http:JSONEncode(v)return v end
function http:JSONDecode(v)return v end
local extraTypes={};local productCalls={}
game={GetService=function(_,name)if name=="HttpService"then return http end;if name=="MarketplaceService"then return {GetProductInfo=function(_,id)productCalls[id]=(productCalls[id] or 0)+1;return {Name="Asset"..id,AssetTypeId=extraTypes[id] or ({[101]=11,[202]=12,[301]=17,[302]=18,[303]=27,[304]=29,[305]=28,[306]=30,[307]=31,[308]=2})[id] or 8}end}end end}
Enum={InfoType={Asset={}},HumanoidRigType={R6={},R15={}}};Color3={fromRGB=function(r,g,b)return color(r,g,b)end};humanoid.RigType=Enum.HumanoidRigType.R15
local posted;local command={version=1,userId="7",revision=1,definition={assets={},bodyColors={headColor="ff0000",torsoColor="00ff00",leftArmColor="0000ff",rightArmColor="ffff00",leftLegColor="ff00ff",rightLegColor="00ffff"},scales={},playerAvatarType={playerAvatarType="R15"}},items={{id=11,name="Original Hat",itemType="Asset",assetType=8},{id=13,name="New Hat",itemType="Asset",assetType=8},{id=101,name="Shirt",itemType="Asset",assetType=11}}}
function request(o)if o.Method=="GET" and o.Url:find("status")then return {StatusCode=200,Body={version=1,connected=true}}end;if o.Method=="GET"then return {StatusCode=200,Body=command}end;posted=o.Body;return {StatusCode=200,Body={}}end
local jobs={};task={spawn=function(f)jobs[#jobs+1]=f end,delay=function()end,wait=function()end}

settings.body=nil;settings.bodyParts.RightLeg=139607718;extraTypes[139607718]=31
local skinCalls=0
function avatar.setSkin(value,region)
 skinCalls=skinCalls+1;body[region.."Color3"]=value
 settings.colors[region]={value.R,value.G,value.B}
end
for key in pairs(command.definition.bodyColors)do command.definition.bodyColors[key]="123456"end
local timers={};task.defer=task.spawn
task.delay=function(seconds,fn)timers[#timers+1]={seconds=seconds,fn=fn}end
local function drain()while #jobs>0 do local batch=jobs;jobs={};for _,fn in ipairs(batch)do fn()end end end
local function tick()local batch=timers;timers={};for _,timer in ipairs(batch)do if timer.seconds<20 then timer.fn()end end;drain()end
local available=false
request=function()assert(available,"desktop is restarting");return {StatusCode=200,Body={instanceId="test",code=string.rep("a",32)}}end
local connections=0
local latest
WebSocket={connect=function()
 connections=connections+1
 local socket={OnClose={},OnMessage={}}
 function socket.OnClose:Connect(fn)self.fn=fn end
 function socket.OnMessage:Connect(fn)self.fn=fn end
 function socket:Send(raw)if raw.type=="auth"then self.OnMessage.fn({type="ready",instanceId="test"})end end
 function socket:Close()if self.OnClose.fn then self.OnClose.fn()end end
 latest=socket;return socket
end}
local create=dofile("game_browser_sync.lua")
local sync=create(player,function()return avatar end,function()return clothing end,function()return true end,function()end)
drain();assert(connections==0,"desktop starts unavailable")
tick();available=true;tick()
assert(connections==1 and sync.isConnected(),"startup automatically reconnects when desktop becomes available")
available=false;latest:Close();drain();tick()
available=true;tick()
assert(connections==2 and sync.isConnected(),"dropped connection retries through a desktop restart")
latest:Close();sync.disconnect();tick()
assert(connections==2 and not sync.isConnected(),"manual disconnect cancels automatic reconnect")
print("Browser connection recovers from startup failure and desktop restart, and respects disconnect.")

