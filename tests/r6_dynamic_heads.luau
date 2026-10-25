-- Native Roblox coverage for dynamic heads on an R6 rig.
local Players=game:GetService('Players')
local defaultDescription=Instance.new('HumanoidDescription')
local defaultModel=Players:CreateHumanoidModelFromDescriptionAsync(defaultDescription,Enum.HumanoidRigType.R6)
defaultDescription:Destroy()
local defaultHead=defaultModel:FindFirstChild('Head')
assert(defaultHead and defaultHead:IsA('BasePart'),'Native R6 model has no Head part')
local defaultMesh=defaultHead:FindFirstChildOfClass('SpecialMesh')
assert(defaultMesh,'Native R6 default head has no SpecialMesh')

local heads={15093053680,86019983967406}
local passed=0
local ok,err=pcall(function()
 for _,headId in ipairs(heads) do
  local description=Instance.new('HumanoidDescription')
  local model
  local applied
  local success,message=pcall(function()
   description.Head=headId
   model=Players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R6)
   local humanoid=model:FindFirstChildOfClass('Humanoid')
   assert(humanoid and humanoid.RigType==Enum.HumanoidRigType.R6,'Dynamic head did not produce an R6 rig')
   applied=humanoid:GetAppliedDescription()
   assert(applied.Head==headId,'R6 applied description lost dynamic head '..tostring(headId))
   local head=model:FindFirstChild('Head')
   assert(head and head:IsA('BasePart'),'Dynamic R6 model has no Head part')
   local mesh=head:FindFirstChildOfClass('SpecialMesh')
   assert(mesh,'Dynamic R6 head has no native SpecialMesh')
   assert(mesh.MeshId~=defaultMesh.MeshId or mesh.TextureId~=defaultMesh.TextureId,'Dynamic R6 head kept the default native mesh')
  end)
  if applied then applied:Destroy() end
  if model then model:Destroy() end
  description:Destroy()
  assert(success,message)
  passed=passed+1
 end
end)
defaultModel:Destroy()
assert(ok,err)
return {passed=passed,message='Both dynamic heads generate native R6 rigs with their applied IDs and distinct native head meshes.'}
