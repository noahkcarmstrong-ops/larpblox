-- Focused regression for stale saved clothing settings versus native templates.
-- Run from this directory with: npx --offline --package=fengari-node-cli fengari tests/clothing-sync.lua
math.clamp=function(v,a,b)return math.max(a,math.min(b,v))end
table.clear=function(t)for k in pairs(t)do t[k]=nil end end

local body={HeadColor3={R=1,G=1,B=1},TorsoColor3={R=1,G=1,B=1},LeftArmColor3={R=1,G=1,B=1},RightArmColor3={R=1,G=1,B=1},LeftLegColor3={R=1,G=1,B=1},RightLegColor3={R=1,G=1,B=1}}
local function signal()return {Connect=function()return {Disconnect=function()end}end}end
local scales={}
local humanoid={Health=100,RigType={Name="R15"}}
for _,name in ipairs({"BodyHeightScale","BodyWidthScale","BodyDepthScale","HeadScale","BodyTypeScale","BodyProportionScale"})do scales[name]={Value=1,IsA=function(_,k)return k=="NumberValue"end}end
function humanoid:FindFirstChild(name)return scales[name]end
local desc={Shirt=101,Pants=202,GraphicTShirt=0,Head=0,Face=0,Torso=0,LeftArm=0,RightArm=0,LeftLeg=0,RightLeg=0}
function desc:GetAccessories()return {}end
function humanoid:GetAppliedDescription()return desc end
local character={BodyColors=body,humanoid=humanoid}
character.DescendantAdded=signal();character.DescendantRemoving=signal();function character:GetDescendants()return {}end
function character:FindFirstChildOfClass(k)return k=="Humanoid" and humanoid or k=="BodyColors" and body end
function character:FindFirstChild()return nil end
humanoid.Parent=character
local player={UserId=7,Character=character}
function player:FindFirstChildOfClass()return nil end

local settings={accessories={},hideOriginals=false,colors={},bodyParts={},scales={},face=0}
local avatar={}
function avatar.getSettings()return settings end
function avatar.listAccessories()return {}end
function avatar.listGear()return {}end
function avatar.removeCurrentAccessories()end
function avatar.equipAccessory()end
function avatar.applyBodyPart()end
function avatar.applyFace()end
function avatar.restoreFace()end
function avatar.restore()end

local visual={ShirtTemplate="native-shirt",PantsTemplate="native-pants"}
local clothesState={Shirt=101,Pants=0}
local clothes={}
function clothes.getSettings()return clothesState end
function clothes.equipShirt(id)assert(id==101);clothesState.Shirt=id;visual.ShirtTemplate="desired-shirt"end
function clothes.equipPants(id)clothesState.Pants=id;visual.PantsTemplate="desired-pants"end
function clothes.removeShirt()clothesState.Shirt=0;visual.ShirtTemplate=""end
function clothes.removePants()clothesState.Pants=0;visual.PantsTemplate=""end
function clothes.restore()visual.ShirtTemplate="native-shirt";visual.PantsTemplate="native-pants";clothesState.Shirt=101;clothesState.Pants=202 end

local http={}
function http:JSONEncode(v)return v end
function http:JSONDecode(v)return v end
game={GetService=function(_,name)
    if name=="HttpService"then return http end
    if name=="MarketplaceService"then return {GetProductInfo=function(_,id)return {Name="Asset"..id,AssetTypeId=id==101 and 11 or id==202 and 12 or 8}end}end
end}
Enum={HumanoidRigType={R6={},R15={}},InfoType={Asset={}}}
local command={version=1,userId="7",revision=1,definition={assets={},bodyColors={headColor="ffffff",torsoColor="ffffff",leftArmColor="ffffff",rightArmColor="ffffff",leftLegColor="ffffff",rightLegColor="ffffff"},scales={},playerAvatarType={playerAvatarType="R15"}},items={{id=101,name="Selected shirt",itemType="Asset",assetType=11}}}
local jobs={}
task={spawn=function(f)jobs[#jobs+1]=f end,defer=function(f)jobs[#jobs+1]=f end,delay=function()end,wait=function()end}
function request(o)
    if o.Method=="GET" and o.Url:find("status")then return {StatusCode=200,Body={version=1,connected=true}}end
    return {StatusCode=200,Body={}}
end
local ws={}
ws.OnMessage={Connect=function(self,f)ws.onMessage=f end};ws.OnClose={Connect=function(self,f)ws.onClose=f end}
function ws:Send(value)
    if value.type=="auth" then
        ws.onMessage({type="ready",instanceId="clothes-test"})
        ws.onMessage({type="state",channel="names",value={version=1,userId="7",enabled=true,name="TestUser"}})
        ws.onMessage({type="state",channel="browser",value=command})
    end
end
function ws:Close()end
WebSocket={connect=function(url)assert(url=="ws://127.0.0.1:38261/v1/socket");return ws end}

local create=dofile("game_browser_sync.lua")
local sync=create(player,function()return avatar end,function()return clothes end,function()return true end,function()end)
sync.connect(string.rep("a",32))
while #jobs>0 do local job=table.remove(jobs,1);job()end
assert(visual.ShirtTemplate=="desired-shirt","selected shirt replaces a stale native shirt even when saved ID matches")
assert(visual.PantsTemplate=="","absent pants are cleared even when saved settings already say removed")
ws.onMessage({type="state",channel="names",value={version=1,userId="7",enabled=false,name=""}})
while #jobs>0 do local job=table.remove(jobs,1);job()end
assert(visual.ShirtTemplate=="native-shirt" and visual.PantsTemplate=="native-pants","clothing owner restores native clothing when Larp is disabled")
sync.disconnect()
print("Focused stale classic clothing sync regression passed.")
