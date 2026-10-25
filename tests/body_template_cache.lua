-- Exercise the actual template preparation path without network timing noise.
local generated,preloaded=0,0
local function model(id)
    return {id=id,Destroy=function(self)self.destroyed=true end,Clone=function(self)return model(self.id)end}
end
local environment=setmetatable({
    Instance={new=function()return {Destroy=function()end}end},
    Players={CreateHumanoidModelFromDescriptionAsync=function(_,description)
        generated=generated+1;return model(description.RightLeg)
    end},
    game={GetService=function()return {PreloadAsync=function()preloaded=preloaded+1 end}end},
    validScales=function()return true end,valid=function()return true end,
    check=function()end,strip=function()end,descriptionScales={height='HeightScale'},
}, {__index=_G})
local prepare=assert(loadfile(assert(arg[1]),'t',environment))()
local ctx={humanoid={RigType='R15'}}
local original=prepare(ctx,{}, {height=1})
local korblox=prepare(ctx,{RightLeg=139607718},{height=1})
assert(korblox.id==139607718)
local restored=prepare(ctx,{}, {height=1})
assert(generated==2 and preloaded==2,'unequip must reuse the previous body without another Roblox generation or preload wait')
assert(restored==original and not restored.destroyed and restored.id==0,'cached default leg remains usable')
prepare(ctx,{}, {height=1.1})
assert(generated==3,'different scales require their own template')
ctx.humanoid.RigType='R6';prepare(ctx,{}, {height=1})
assert(generated==4,'different rig types must not reuse an incompatible body')
for id=1,8 do prepare(ctx,{RightLeg=id},{height=1})end
assert(original.destroyed,'cache evicts old models instead of growing without bound')
print('PASS: body unequip avoids repeated generation/preload; scales, rig isolation and bounded eviction')
