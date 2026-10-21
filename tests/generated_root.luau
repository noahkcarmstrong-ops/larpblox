-- Run with: lune run tests/generated_root.luau
-- Reuse the strict avatar fixture, isolating body fitting from disabled gear APIs.
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local test=fs.readFile('tests/avatar.lua')
local first=assert(test:find('local create=dofile',1,true))
local setup=[[local getService=game.GetService;game.GetService=function(self,n) if n=="ContentProvider" then return {PreloadAsync=function()end} end return getService(self,n) end
]]
local checks=[[
root.Size={X=2,Y=2,Z=1}
local templateRoot=node('Part','HumanoidRootPart');templateRoot.CFrame=cf();templateRoot.Size={X=1.4,Y=1.8,Z=0.85};templateRoot.Parent=template
local h=body:FindFirstChildOfClass('Humanoid');h.HipHeight=2
local th=hum();th.HipHeight=1.5;th.Parent=template
local a=node('Attachment','RootRigAttachment');a.CFrame=cf(0,-0.1,0);a.Parent=root
local b=node('Attachment','RootRigAttachment');b.CFrame=cf(0,-0.3,0);b.Parent=templateRoot
local orig=node('Vector3Value','OriginalSize');orig.Value=root.Size;orig.Parent=root
local gen=node('Vector3Value','OriginalSize');gen.Value=templateRoot.Size;gen.Parent=templateRoot
local lower=body:FindFirstChild('LowerTorso')
local la=node('Attachment','RootRigAttachment');la.CFrame=cf();la.Parent=lower
local ga=node('Attachment','RootRigAttachment');ga.CFrame=cf();ga.Parent=template:FindFirstChild('LowerTorso')
local joint=node('Motor6D','RootJoint');joint.Part0=root;joint.Part1=lower;joint.C0=a.CFrame;joint.C1=cf();joint.Parent=root
local api=create(player)
local function applied()
 assert(body:FindFirstChild('HumanoidRootPart')==root and root.Size.Y==1.8 and a.CFrame.y==-0.3 and joint.C0.y==-0.3 and h.HipHeight==1.5,'generated root and hip alignment')
 assert(root:FindFirstChild('OriginalSize').Value.Y==1.8,'native root scaling baseline')
end
local function restored()
 assert(root.Size.Y==2 and a.CFrame.y==-0.1 and joint.C0.y==-0.1 and h.HipHeight==2,'original root and hip alignment restored')
 assert(root:FindFirstChild('OriginalSize').Value.Y==2,'original scaling baseline restored')
end
api.applyBody('Girl');applied();api.restoreBody();restored()
local ids={Head=0,Torso=0,LeftArm=0,RightArm=0,LeftLeg=0,RightLeg=0}
api.applyBodyParts(ids,{height=0.9});applied();api.restoreBody();restored()
api.applyBodyParts(ids,{height=0.9});applied();api.restoreBody();restored()
h.failName='LeftHand';assert(not pcall(api.applyBody,'Girl'));h.failName=nil;restored()
api.applyBodyPart('LeftArm','https://www.roblox.com/bundles/555');restored();api.restoreBody()
api.applyBody('Girl');applied();api.destroy();restored()
print('PASS generated body root dimensions, root attachment/joint, scaling baseline, shared/cache path, rollback, partial body isolation, restore and destroy')
]]
luau.load(test:sub(1,first-1)..setup..'local create=(function()\n'..fs.readFile('avatar.lua')..'\nend)()\n'..checks)()
