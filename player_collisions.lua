-- Local-only player collision opt-out. It never changes part properties or world collision settings.
local FOLDER_NAME = "LarpbloxPlayerNoCollision"

return function(players, workspace)
    local enabled = false
    local destroyed = false
    local localPlayer = players.LocalPlayer
    local folder
    local allConnections = {}
    local playerStates = {}
    local partRecords = {}

    local function connect(signal, callback)
        if not signal then return nil end
        local connection = signal:Connect(callback)
        allConnections[#allConnections + 1] = connection
        return connection
    end

    local function isPart(value)
        return value and ((value.IsA and value:IsA("BasePart")) or value.ClassName == "BasePart")
    end

    local function removePair(first, second)
        local peers = first and partRecords[first] and partRecords[first].peers
        local constraint = peers and peers[second]
        if constraint then
            peers[second] = nil
            if second and partRecords[second] then partRecords[second].peers[first] = nil end
            constraint:Destroy()
        end
    end

    local function addPair(first, second)
        if first == second or not enabled or not first or not second
            or not partRecords[first] or not partRecords[second]
            or partRecords[first].owner == partRecords[second].owner
            or ((partRecords[first].owner.player == localPlayer) == (partRecords[second].owner.player == localPlayer))
            or not first.CanCollide or not second.CanCollide then return end
        if not partRecords[first].peers[second] then
            local constraint = Instance.new("NoCollisionConstraint")
            constraint.Name = "LarpbloxPlayerNoCollision"
            constraint.Part0 = first
            constraint.Part1 = second
            constraint.Parent = folder
            partRecords[first].peers[second] = constraint
            partRecords[second].peers[first] = constraint
        end
    end

    local function refreshPart(part)
        local record = partRecords[part]
        if not record then return end
        if not part.CanCollide then
            for peer in pairs(record.peers) do removePair(part, peer) end
            return
        end
        for other in pairs(partRecords) do addPair(part, other) end
    end

    local function removePart(part)
        local record = partRecords[part]
        if not record then return end
        if record.connection then record.connection:Disconnect() end
        for peer in pairs(record.peers) do removePair(part, peer) end
        partRecords[part] = nil
    end

    local function addPart(state, part)
        if not isPart(part) or partRecords[part] then return end
        local record = {owner = state, peers = {}}
        partRecords[part] = record
        record.connection = part:GetPropertyChangedSignal("CanCollide"):Connect(function()
            refreshPart(part)
        end)
        for other in pairs(partRecords) do addPair(part, other) end
    end

    local function clearCharacter(state)
        if not state then return end
        if state.added then state.added:Disconnect() end
        if state.removing then state.removing:Disconnect() end
        for part in pairs(state.parts) do removePart(part) end
        state.parts = {}
    end

    local function watchCharacter(state, character)
        clearCharacter(state)
        state.character = character
        if not character then return end
        state.parts = {}
        for _, descendant in ipairs(character:GetDescendants()) do addPart(state, descendant); if isPart(descendant) then state.parts[descendant] = true end end
        state.added = character.DescendantAdded:Connect(function(descendant)
            addPart(state, descendant)
            if isPart(descendant) then state.parts[descendant] = true end
        end)
        state.removing = character.DescendantRemoving:Connect(function(descendant)
            if isPart(descendant) then state.parts[descendant] = nil; removePart(descendant) end
        end)
    end

    local function watchPlayer(player)
        if playerStates[player] then return end
        local state = {player = player, parts = {}}
        playerStates[player] = state
        state.characterAdded = player.CharacterAdded:Connect(function(character) watchCharacter(state, character) end)
        if player.CharacterRemoving then
            state.characterRemoving = player.CharacterRemoving:Connect(function(character)
                if state.character == character then watchCharacter(state, nil) end
            end)
        end
        watchCharacter(state, player.Character)
    end

    local function unwatchPlayer(player)
        local state = playerStates[player]
        if not state then return end
        if state.characterAdded then state.characterAdded:Disconnect() end
        if state.characterRemoving then state.characterRemoving:Disconnect() end
        clearCharacter(state)
        playerStates[player] = nil
    end

    local function disable()
        if not enabled then return end
        enabled = false
        for player in pairs(playerStates) do unwatchPlayer(player) end
        for _, connection in ipairs(allConnections) do connection:Disconnect() end
        allConnections = {}
        if folder then folder:Destroy(); folder = nil end
    end

    local api = {}
    function api.setEnabled(value)
        if destroyed then return end
        value = value == true
        if value == enabled then return end
        if not value then disable(); return end
        enabled = true
        folder = Instance.new("Folder")
        folder.Name = FOLDER_NAME
        folder.Parent = workspace
        connect(players.PlayerAdded, watchPlayer)
        connect(players.PlayerRemoving, unwatchPlayer)
        for _, player in ipairs(players:GetPlayers()) do watchPlayer(player) end
    end
    function api.destroy()
        if destroyed then return end
        disable()
        destroyed = true
    end
    function api.isEnabled() return enabled end
    return api
end
