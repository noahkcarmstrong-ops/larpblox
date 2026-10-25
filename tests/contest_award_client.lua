-- Run in a Roblox client with contest_award.lua loaded as the factory argument.
-- All characters and parts are detached fixtures; this never uses the live player.
return function(factory)
    assert(type(getconnections) == "function", "This client test requires getconnections(signal).")

    local character = Instance.new("Model")
    character.Name = "ContestAwardFixture"
    local humanoid = Instance.new("Humanoid")
    humanoid.Parent = character

    local hat = Instance.new("Accessory")
    hat.Name = "SparklingHat"
    local originalHandle = Instance.new("Part")
    originalHandle.Name = "Handle"
    originalHandle.Size = Vector3.new(1, 1, 1)
    originalHandle.Parent = hat
    local unsafeScript = Instance.new("LocalScript")
    unsafeScript.Name = "MustNotClone"
    unsafeScript.Parent = originalHandle
    hat.Parent = character

    local backpack = Instance.new("Folder")
    backpack.Name = "Backpack"
    local playerGui = Instance.new("Folder")
    playerGui.Name = "PlayerGui"
    local characterAdded = Instance.new("BindableEvent")
    local mouse = { Icon = "fixture-cursor" }
    local player = {
        Character = character,
        Backpack = backpack,
        CharacterAdded = characterAdded.Event,
        FindFirstChildOfClass = function(self, className)
            if className == "Backpack" then return self.Backpack end
            if className == "PlayerGui" then return self.PlayerGui end
        end,
        GetMouse = function() return mouse end,
        PlayerGui = playerGui,
    }

    local fixtures = {}
    local api
    local ok, result = xpcall(function()
        api = factory(player)
        assert(api and type(api.setEnabled) == "function" and type(api.refresh) == "function" and type(api.destroy) == "function", "Factory must return the award API")
        assert(#backpack:GetChildren() == 0, "Award must start disabled")

        api.setEnabled(true)
        api.refresh()
        local tools = backpack:GetChildren()
        assert(#tools == 1, "Enabling with a matching hat and living Humanoid must create one award")
        local tool = tools[1]
        assert(tool:IsA("Tool") and tool.Name == "Contest Winner Award", "Award tool name must match")
        assert(tool.RequiresHandle and not tool.CanBeDropped, "Award must require a handle and be non-droppable")
        local held = CFrame.Angles(math.pi/2,0,0) * tool.Grip:Inverse()
        assert(held.UpVector:Dot(Vector3.yAxis)>0.999, "Native hand grip must hold the trophy upright instead of sideways")
        local handle = tool:FindFirstChild("Handle")
        assert(handle and handle:IsA("BasePart"), "Award must contain its cloned handle")
        assert(not handle:FindFirstChildWhichIsA("LuaSourceContainer", true), "Cloned handle must not contain scripts")
        assert(handle.CanTouch and not handle.CanCollide and not handle.Anchored and handle.Massless, "Award handle must be touchable, safe, and massless")
        local clap = handle:FindFirstChild("ClapSound")
        assert(clap and clap.SoundId == "rbxassetid://57908388", "Award must include the clap sound")
        assert(#backpack:GetChildren() == 1, "Refresh must not create duplicate awards")

        local function fire(signal, ...)
            local count = 0
            for _, connection in ipairs(getconnections(signal)) do
                local callback = connection.Function
                if typeof(callback) == "function" then
                    callback(...)
                    count = count + 1
                end
            end
            assert(count > 0, "Expected a connected handler for fixture signal")
        end

        tool.Parent = character
        fire(tool.Equipped, mouse)
        assert(mouse.Icon == "rbxasset://textures/GunCursor.png", "Equipped award must show its cursor")
        fire(tool.Activated)
        assert(not tool.Enabled, "Activation must disable the award during its burst")
        assert(mouse.Icon == "rbxasset://textures/GunWaitCursor.png", "Active burst must show the wait cursor")
        local sparkles = handle:FindFirstChild("ContestAwardSparkles")
        assert(sparkles and sparkles:IsA("Sparkles") and sparkles.SparkleColor == Color3.fromRGB(255, 215, 0), "Activation must add gold sparkles")
        assert(clap.IsPlaying, "Unmuted activation must play the clap")
        fire(tool.Activated)
        assert(not tool.Enabled and handle:FindFirstChild("ContestAwardSparkles") == sparkles, "Repeated activation must not start another burst")

        local eligible = {}
        for i = 1, 33 do
            local part = Instance.new("Part")
            part.Name = "Eligible" .. i
            part.Size = Vector3.new(1, 1, 1)
            part.Color = Color3.fromRGB(20, 40, 60)
            part.Material = Enum.Material.Wood
            fixtures[#fixtures + 1] = part
            eligible[i] = part
            fire(handle.Touched, part)
        end
        local oversized = Instance.new("Part")
        oversized.Size = Vector3.new(6, 1, 1)
        fixtures[#fixtures + 1] = oversized
        local selfPart = Instance.new("Part")
        selfPart.Parent = character
        local humanoidModel = Instance.new("Model")
        Instance.new("Humanoid", humanoidModel)
        local otherCharacterPart = Instance.new("Part")
        otherCharacterPart.Parent = humanoidModel
        fixtures[#fixtures + 1] = humanoidModel
        fire(handle.Touched, oversized)
        fire(handle.Touched, selfPart)
        fire(handle.Touched, otherCharacterPart)
        local gildedCount = 0
        for _, part in ipairs(eligible) do
            if part.Color == Color3.fromRGB(255, 215, 0) and part.Material == Enum.Material.Ice then
                gildedCount = gildedCount + 1
            end
        end
        assert(gildedCount == 32, "Only the first 32 eligible parts may be gilded")
        assert(eligible[33].Color == Color3.fromRGB(20, 40, 60), "The 33rd eligible part must remain unchanged")
        assert(oversized.Material == Enum.Material.Plastic and selfPart.Material == Enum.Material.Plastic and otherCharacterPart.Material == Enum.Material.Plastic, "Oversized and character parts must remain unchanged")

        task.wait(5.2)
        assert(tool.Enabled, "Award must re-enable when its five-second burst ends")
        assert(handle:FindFirstChild("ContestAwardSparkles") == nil, "Sparkles must be removed when the burst ends")
        assert(mouse.Icon == "rbxasset://textures/GunCursor.png", "Cursor must return to the equipped idle cursor")
        for _, part in ipairs(eligible) do
            assert(part.Color == Color3.fromRGB(20, 40, 60) and part.Material == Enum.Material.Wood, "Gilded part must restore its original appearance")
        end

        playerGui:SetAttribute("HoneyBunCosmeticUI_HatSounds", false)
        clap:Stop()
        fire(tool.Activated)
        assert(not clap.IsPlaying, "Muted activation must not play the clap")
        fire(tool.Unequipped)
        assert(tool.Enabled and mouse.Icon == "fixture-cursor", "Unequip must finish the burst and restore the prior cursor")
        assert(handle:FindFirstChild("ContestAwardSparkles") == nil, "Unequip must remove active sparkles")
        for _, part in ipairs(eligible) do part:Destroy() end
        selfPart:Destroy()

        tool.Parent = backpack
        api.setEnabled(false)
        assert(#backpack:GetChildren() == 0, "Disabling must remove the award")

        api.setEnabled(true)
        assert(#backpack:GetChildren() == 1, "Re-enabling must recreate the award")
        hat.Parent = nil
        api.refresh()
        assert(#backpack:GetChildren() == 0, "Removing the matching hat must remove the award")
        hat.Parent = character
        api.refresh()
        assert(#backpack:GetChildren() == 1, "Restoring the matching hat must recreate the award")
        humanoid.Health = 0
        fire(humanoid.Died)
        assert(#backpack:GetChildren() == 0, "A dead Humanoid must not retain the award")
        return "Contest award tool, sanitization, effects, cooldown, touch limits, and cleanup passed."
    end, debug.traceback)

    if api then pcall(api.destroy) end
    character:Destroy()
    for _, fixture in ipairs(fixtures) do pcall(function() fixture:Destroy() end) end
    backpack:Destroy()
    playerGui:Destroy()
    characterAdded:Destroy()
    assert(ok, result)
    return result
end



