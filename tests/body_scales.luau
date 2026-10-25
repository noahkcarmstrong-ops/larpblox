-- Pass the avatar factory and native inspection module. Uses disposable rigs only.
local create,inspect=...
local Players=game:GetService('Players')
local fields={height='HeightScale',width='WidthScale',depth='DepthScale',head='HeadScale',bodyType='BodyTypeScale',proportion='ProportionScale'}
local initial=Instance.new('HumanoidDescription')
local model=Players:CreateHumanoidModelFromDescriptionAsync(initial,Enum.HumanoidRigType.R15)
initial:Destroy()
local event=Instance.new('BindableEvent')
local player={Character=model,CharacterAdded=event.Event,FindFirstChildOfClass=function()end}
local originals={}
for _,part in ipairs(model:GetChildren())do if part:IsA('BasePart')then originals[part.Name]={part=part,size=part.Size}end end
local api=create(player,nil,nil,true)
local count=0
local ok,err=pcall(function()
 for _,scales in ipairs({{height=1.05,width=0.75,depth=0.8,head=0.95,bodyType=0.5,proportion=0.3},{height=0.9,width=1,depth=1,head=1,bodyType=0,proportion=0}})do
  local description=inspect.description({items={},definition={assets={},scales=scales}})
  for name,field in pairs(fields)do assert(math.abs(description[field]-scales[name])<0.0001,'Inspect lost '..name)end
  local reference=Players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R15)
  description:Destroy()
  api.setScales(scales);api.applyBodyParts({},scales)
  for name,original in pairs(originals)do
   local part=model:FindFirstChild(name)
   assert(part==original.part,'Scale update replaced '..name)
   assert((part.Size-reference[name].Size).Magnitude<0.001,'Scale geometry differs from Roblox: '..name)
  end
  reference:Destroy();count=count+1
 end
 api.restoreBody()
 for name,original in pairs(originals)do assert((model[name].Size-original.size).Magnitude<0.001,'Restore failed: '..name)end
end)
local r6Description=Instance.new('HumanoidDescription')
local r6Model=Players:CreateHumanoidModelFromDescriptionAsync(r6Description,Enum.HumanoidRigType.R6)
r6Description:Destroy()
local r6Originals={}
for _,part in ipairs(r6Model:GetChildren())do if part:IsA('BasePart') then r6Originals[part.Name]={part=part,size=part.Size} end end
local r6Player={Character=r6Model,CharacterAdded=event.Event,FindFirstChildOfClass=function()end}
local r6Api=create(r6Player,nil,nil,true)
assert(r6Api.setScales({height=1.2})=='Avatar proportions require R15.','R6 scales remain explicitly unsupported')
assert(pcall(r6Api.applyBodyParts,{}, {height=1.2,width=0.8,depth=0.9,head=1.1,bodyType=0.7,proportion=0.4}),'R6 body application ignores inapplicable R15 scale fields')
for name,original in pairs(r6Originals)do
 local part=r6Model:FindFirstChild(name)
 assert(part==original.part,'R6 body update replaced '..name)
 assert((part.Size-original.size).Magnitude<0.001,'R6 body shape changed from native dimensions: '..name)
end
r6Api.restoreBody()
for name,original in pairs(r6Originals)do assert((r6Model[name].Size-original.size).Magnitude<0.001,'R6 restore failed: '..name)end
r6Api.destroy();api.destroy();event:Destroy();model:Destroy();r6Model:Destroy()
assert(ok,err)
return {passed=count+1,message='R15 scale changes match native Roblox geometry; R6 body shape and restore remain native while R15 scale fields are ignored.'}
