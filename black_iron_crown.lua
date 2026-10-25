-- Recreates the crown's original greeting without its obsolete RenderHooksService call.
return function(player,onStatus,sharing)
    sharing=sharing or {}
    local remote=sharing.remote==true
    local alive,enabled,announced=true,false,false
    local character,hat,visibilityConnection
    local connections,characterConnections={},{}
    local function disconnect(list)
        for _,connection in ipairs(list)do connection:Disconnect()end
        table.clear(list)
    end
    local refresh
    refresh=function()
        if not alive then return end
        local nextHat
        if character==player.Character then
            for _,item in ipairs(character and character:GetChildren()or {})do
                if (item:IsA("Accessory")or item:IsA("Hat"))and
                    (item.Name=="BlackIronCrownOfPwnage"or item.SourceAssetId==1078202)then nextHat=item;break end
            end
        end
        if nextHat~=hat then
            if visibilityConnection then visibilityConnection:Disconnect();visibilityConnection=nil end
            hat=nextHat;announced=false
            local handle=hat and hat:FindFirstChild("Handle")
            if handle then visibilityConnection=handle:GetPropertyChangedSignal("Transparency"):Connect(refresh)end
        end
        local handle=hat and hat:FindFirstChild("Handle")
        local wearing=enabled and hat and handle and handle.Transparency<1
        if wearing and not announced then print("Hello John")end
        announced=not not wearing
    end
    local function bind(nextCharacter)
        disconnect(characterConnections);character=nextCharacter
        if character then
            for _,signal in ipairs({character.ChildAdded,character.ChildRemoved})do
                characterConnections[#characterConnections+1]=signal:Connect(refresh)
            end
        end
        refresh()
    end
    connections[#connections+1]=player.CharacterAdded:Connect(bind)
    bind(player.Character)
    return {
        refresh=refresh,
        setEnabled=function(value)enabled=value==true;refresh()end,
        destroy=function()
            alive=false;disconnect(connections);disconnect(characterConnections)
            if visibilityConnection then visibilityConnection:Disconnect()end
            character=nil;hat=nil
        end,
    }
end
