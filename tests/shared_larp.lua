-- Shared appearance transport is local, event-driven, and incremental.
local calls,jobs={},{}
local self={UserId=1,Name='Self',DisplayName='Self'}
function self:FindFirstChildOfClass()return nil end
local peer={UserId=2,Name='Other',DisplayName='Other',Character={}}
local function signal()return {Connect=function()return {Disconnect=function()end}end}end
local scaleValues={
 BodyHeightScale={Name='BodyHeightScale',Value=1,Parent=true,IsA=function(_,kind)return kind=='NumberValue'end},
 BodyWidthScale={Name='BodyWidthScale',Value=1,Parent=true,IsA=function(_,kind)return kind=='NumberValue'end},
 BodyDepthScale={Name='BodyDepthScale',Value=1,Parent=true,IsA=function(_,kind)return kind=='NumberValue'end},
 HeadScale={Name='HeadScale',Value=1,Parent=true,IsA=function(_,kind)return kind=='NumberValue'end},
 BodyProportionScale={Name='BodyProportionScale',Value=0,Parent=true,IsA=function(_,kind)return kind=='NumberValue'end},
 BodyTypeScale={Name='BodyTypeScale',Value=0,Parent=true,IsA=function(_,kind)return kind=='NumberValue'end},
}
local humanoid={Health=100,RigType='R15',FindFirstChild=function(_,name)return scaleValues[name]end}
function humanoid:IsA(kind)return kind=='Humanoid'end
function peer.Character:FindFirstChildOfClass()return humanoid end
function peer.Character:FindFirstChild()return {IsA=function(_,kind)return kind=='BasePart'end}end
function peer.Character:GetChildren()return {}end
peer.Character.ChildAdded=signal();peer.CharacterAdded=signal();peer.CharacterAppearanceLoaded=signal()
peer.CharacterRemoving=signal();peer.Character.DescendantRemoving=signal();peer.Character.DescendantAdded=signal()
humanoid.HealthChanged=signal();function humanoid:GetPropertyChangedSignal()return signal()end
Enum={HumanoidRigType={R15='R15',R6='R6'}}
local players={GetPlayers=function()return {self,peer}end,GetPlayerByUserId=function(_,id)return id==2 and peer end}
game={PlaceId=123,JobId='abc-123',GetService=function(_,name)return name=='Players' and players or {}end}
Color3={fromRGB=function(r,g,b)return {r,g,b}end}
request=function()error('Shared appearances must not call a public HTTP endpoint from the game')end
task={spawn=function(fn)jobs[#jobs+1]=fn end,defer=function(fn)jobs[#jobs+1]=fn end}
local function drain()while #jobs>0 do table.remove(jobs,1)()end end
local destroyed,equipped=0,{}
local batchedScales
local function avatar()
 return {destroy=function()destroyed=destroyed+1 end,removeCurrentAccessories=function()calls[#calls+1]='hide' end,
 listAccessories=function()local out={}for id in pairs(equipped)do out[#out+1]={id=id,key=id}end;return out end,
 equipAccessory=function(id)equipped[id]=true;calls[#calls+1]='equip:'..id end,
 removeAccessory=function(id)equipped[id]=nil;calls[#calls+1]='remove:'..id end,
 applyBodyPart=function()calls[#calls+1]='body' end,applyBodyParts=function(parts,scales)
  batchedScales=scales
  calls[#calls+1]='bodyparts'
 end,restoreBodyPart=function()end,
 setSkin=function()end,applyFace=function()end,restoreFace=function()end,removeGear=function()end}
end
local function clothes()return {destroy=function()destroyed=destroyed+1 end,equipShirt=function()calls[#calls+1]='shirt'end,equipPants=function()end,equipTShirt=function()end,removeShirt=function()end,removePants=function()end,removeTShirt=function()end}end
local function animations()return {destroy=function()destroyed=destroyed+1 end,restore=function()end,equipAssets=function()end}end
local function names()return {destroy=function()destroyed=destroyed+1 end,restore=function()end,set=function()calls[#calls+1]='name'end}end
local receive,onSnapshot,published
local transport={setSharing=function(value)published=value end,onShared=function(fn)receive=fn;return function()receive=nil end end,onSnapshot=function(fn)onSnapshot=fn;return function()onSnapshot=nil end end}
local setting={enabled=false,username='',displayName=''}
local function snapshot(user,id)return {version=1,userId=user,items={{id=id,name='Hat',assetType=8,itemType='Asset'}},definition={assets={{id=id}},bodyColors={},scales={}}}end
local hatUpdates,hatDestroyed,hatChanged={},0,nil
local hats=dofile('hat_sharing.lua')({session='12345678-1234-1234-1234-123456789abc',delay=function()end,clock=function()return 1000 end})
local sync=dofile('shared_larp.lua')(self,function()return snapshot('1',10)end,function()return setting end,avatar,clothes,animations,names,function()return true end,function()end,{
 transport=transport,getHatScripts=hats.snapshot,validHatScripts=hats.valid,
 onHatScriptsChanged=function(fn)hatChanged=fn;return function()hatChanged=nil end end,
 createHatScripts=function()return {update=function(state)hatUpdates[#hatUpdates+1]=state or false end,destroy=function()hatDestroyed=hatDestroyed+1 end}end,
})
drain()
sync.setEnabled(true)
assert(published.enabled and published.placeId=='123' and published.jobId=='abc-123','sharing uses local desktop transport')
assert(#jobs==0,'enabling creates no polling loop')
assert(published.record.hatScripts.session==hats.snapshot().session,'local hat state travels with initial shared appearance')
local record={version=1,userId='2',snapshot=snapshot('2',20),name={enabled=true,username='OtherAlias',displayName='Other Alias'}}
receive({type='snapshot',players={record}});drain()
assert(equipped[20] and destroyed==0,'initial peer appearance applies')
local action=hats.snapshot();action.held='award';action.events={{id=1,kind='award-burst',at=1000}}
local callsBefore=#calls
receive({type='hat-scripts',userId='2',hatScripts=action})
assert(hatUpdates[#hatUpdates]==action and #calls==callsBefore and #jobs==0,'hat action takes a direct path without avatar or thumbnail rebuild')
receive({type='hat-scripts',userId='1',hatScripts=action});assert(#calls==callsBefore,'remote actions cannot apply to local player')
local invalid={version=1,session=action.session,held='award',events={{id=1,kind='run-code',at=1000}}}
local count=#hatUpdates;receive({type='hat-scripts',userId='2',hatScripts=invalid});assert(#hatUpdates==count,'malformed hat action never reaches runtime')
hats.emit('doom-stop');hatChanged();assert(published.record.hatScripts.events[1].kind=='doom-stop','runtime event publishes through existing sharing connection')
local before=#calls;receive({type='upsert',record=record});drain();assert(#calls==before,'identical push does no rendering work')
local changed={version=1,userId='2',snapshot=snapshot('2',21),name=record.name}
receive({type='upsert',record=changed});drain()
assert(equipped[21] and not equipped[20] and destroyed==0,'changed accessories update without teardown')
local scaleRecord={version=1,userId='2',snapshot=snapshot('2',21),name=record.name}
scaleRecord.snapshot.definition.scales={height=1.6,width=0.8}
local bodyCalls=#calls
receive({type='upsert',record=scaleRecord});drain()
assert(#calls>bodyCalls and calls[#calls]=='bodyparts','scale-only peer updates use the batched body path')
assert(batchedScales==scaleRecord.snapshot.definition.scales,'scale-only geometry rebuild receives the new scales')
assert(scaleValues.BodyHeightScale.Value==1.6 and scaleValues.BodyWidthScale.Value==0.8,'scale-only peer updates reach the humanoid scales')
setting={enabled=true,username='Valid_Name',displayName='Display'};onSnapshot(snapshot('1',11))
assert(published.record.snapshot.items[1].id==11 and published.record.name.enabled,'appearance events publish immediately')
receive({type='remove',userId='2'});drain();assert(destroyed==4,'peer removal cleans the local overlay')
assert(scaleValues.BodyHeightScale.Value==1 and scaleValues.BodyWidthScale.Value==1,'peer removal restores original humanoid scales')
assert(hatUpdates[#hatUpdates]==false and hatDestroyed==1,'peer departure clears held tools and effects')
sync.setEnabled(false);assert(published.enabled==false,'disabling tells desktop to disconnect')
sync.destroy();assert(receive==nil and onSnapshot==nil,'destroy disconnects event subscriptions')
assert(hatChanged==nil,'destroy disconnects hat event publication')
print('Shared desktop transport, push updates, incremental application and cleanup passed.')
