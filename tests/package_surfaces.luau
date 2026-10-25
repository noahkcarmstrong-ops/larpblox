-- Run in Roblox with the avatar module factory passed as the first argument.
-- Disposable rigs stay outside Workspace; the real player's avatar is untouched.
local create=...
local Players=game:GetService("Players")
local passed=0
for _,outfit in ipairs({0,131929545,131929576})do
    local description=outfit==0 and Instance.new("HumanoidDescription") or Players:GetHumanoidDescriptionFromOutfitIdAsync(outfit)
    local model=Players:CreateHumanoidModelFromDescriptionAsync(description,Enum.HumanoidRigType.R15)
    description:Destroy()
    local event=Instance.new("BindableEvent")
    local player={Character=model,CharacterAdded=event.Event}
    function player:FindFirstChildOfClass()return nil end
    local originals={}
    for _,part in ipairs(model:GetChildren())do
        if part:IsA("MeshPart")then
            for _,child in ipairs(part:GetChildren())do if child:IsA("SurfaceAppearance")then child:Destroy()end end
            local surface=Instance.new("SurfaceAppearance");surface.ColorMap="rbxassetid://123";surface.Parent=part
            originals[part.Name]={part=part,mesh=part.MeshId,size=part.Size}
        end
    end
    local api=create(player,nil,nil,true)
    local ok,err=pcall(function()
        for _,body in ipairs({"Girl","Robloxian 2.0","Blocky"})do
            api.applyBody(body)
            for name,original in pairs(originals)do
                local part=model:FindFirstChild(name)
                assert(part==original.part,"Body update replaced a live limb")
                for _,child in ipairs(part:GetChildren())do
                    assert(not child:IsA("SurfaceAppearance") or child.ColorMap~="rbxassetid://123","Old package surface survived: "..name)
                end
            end
            passed=passed+1
        end
        api.restoreBody()
        for name,original in pairs(originals)do
            local part=model:FindFirstChild(name)
            assert(part==original.part and part.MeshId==original.mesh and part.Size==original.size,"Original package geometry not restored: "..name)
            assert(part:FindFirstChildOfClass("SurfaceAppearance").ColorMap=="rbxassetid://123","Original package surface not restored: "..name)
        end
        passed=passed+1
    end)
    api.destroy();event:Destroy();model:Destroy()
    assert(ok,err)
end
return {passed=passed,message="Real Roblox package swaps clear old surfaces and restore original limbs, geometry, and surfaces."}
