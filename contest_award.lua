-- Local recreation of the contest prize's historical Minifigure tool.
return function(player,onStatus,sharing)
    local alive,enabled=true,false
    local character,hat,humanoid,watchedHandle,tool,mouse,oldCursor,sparkles,sound,remoteGrip
    local activeBurst=false
    local generation=0
    local connections,characterConnections,appearanceConnections,toolConnections={},{},{},{}
    local gilded={}
    sharing=sharing or {}
    local remote=sharing.remote==true
    local held=false
    local function emit(kind,payload)if not remote and type(sharing.emit)=="function"then pcall(sharing.emit,kind,payload or {})end end
    local function point(v)return {v.X or v.x,v.Y or v.y,v.Z or v.z}end
    local gold=Color3.fromRGB(255,215,0)
    local idleCursor="rbxasset://textures/GunCursor.png"
    local waitCursor="rbxasset://textures/GunWaitCursor.png"
    local function connect(signal,callback,list)list[#list+1]=signal:Connect(callback)end
    local function disconnect(list)for _,c in ipairs(list)do c:Disconnect()end;table.clear(list)end
    local function status(message)if onStatus then pcall(onStatus,message)end end
    local function matches(item)
        return (item:IsA("Accessory")or item:IsA("Hat"))and(item.Name=="SparklingHat"or item.SourceAssetId==92719239)
    end
    local function active()
        local handle=hat and hat:FindFirstChild("Handle")
        return alive and enabled and character==player.Character and hat and hat.Parent==character and handle
            and handle.Transparency<1 and(not humanoid or humanoid.Health>0)
    end
    local function cursor(value)if mouse then pcall(function()mouse.Icon=value end)end end
    local function restoreCursor()
        if mouse then pcall(function()if mouse.Icon==idleCursor or mouse.Icon==waitCursor then mouse.Icon=oldCursor or ""end end)end
        mouse=nil;oldCursor=nil
    end
    local function finish()
        generation=generation+1;activeBurst=false
        if sparkles then sparkles:Destroy();sparkles=nil end
        if sound then sound:Stop()end
        for part,original in pairs(gilded)do
            pcall(function()
                if part.Color==gold then part.Color=original.color end
                if part.Material==Enum.Material.Ice then part.Material=original.material end
            end)
        end
        table.clear(gilded)
        if tool and not remote then tool.Enabled=true end
        cursor(idleCursor)
    end
    local function clearTool()
        local wasHeld=held;held=false
        finish();restoreCursor();disconnect(toolConnections)
        if remoteGrip then remoteGrip:Destroy();remoteGrip=nil end
        local previous=tool;tool=nil;sound=nil
        if previous then previous:Destroy()end
        if wasHeld and sharing.changed then pcall(sharing.changed)end
    end
    local function gild(part)
        if not activeBurst or not active()or not tool or tool.Parent~=character or not part:IsA("BasePart")or part:IsDescendantOf(character)then return end
        if part.Size.X>5 or part.Size.Y>5 or part.Size.Z>5 then return end
        local ancestor=part.Parent
        while ancestor and ancestor~=workspace do
            if ancestor:IsA("Model")and ancestor:FindFirstChildOfClass("Humanoid")then return end
            ancestor=ancestor.Parent
        end
        if gilded[part]then return end
        local count=0;for _ in pairs(gilded)do count=count+1 end;if count>=32 then return end
        gilded[part]={color=part.Color,material=part.Material}
        part.Color=gold;part.Material=Enum.Material.Ice
        if not remote and type(sharing.emit)=="function" and part.Position then
            emit("award-gild",{position=point(part.Position)})
        end
    end
    local function activateBurst()
        if not active()or activeBurst or not tool or tool.Parent~=character then return false end
        activeBurst=true;if not remote then tool.Enabled=false end;generation=generation+1;local token=generation
        cursor(waitCursor)
        sparkles=Instance.new("Sparkles");sparkles.Name="ContestAwardSparkles";sparkles.SparkleColor=gold;sparkles.Parent=tool:FindFirstChild("Handle")
        local gui=sharing.viewerGui or player:FindFirstChildOfClass("PlayerGui")
        if not gui or gui:GetAttribute("HoneyBunCosmeticUI_HatSounds")~=false then sound:Play()end
        emit("award-burst")
        status("Contest award: golden touch active for five seconds.")
        task.delay(5,function()if alive and token==generation then finish()end end)
        return true
    end
    local function createTool()
        if tool and tool.Parent then return end
        clearTool()
        local original=hat:FindFirstChild("Handle")
        local handle=original:Clone()
        -- Keep only geometry and textures; never copy scripts, welds, or constraints.
        for _,child in ipairs(handle:GetChildren())do
            if child:IsA("SpecialMesh")or child:IsA("Decal")or child:IsA("Texture")or child:IsA("SurfaceAppearance")then
                for _,descendant in ipairs(child:GetDescendants())do descendant:Destroy()end
            else child:Destroy()end
        end
        handle.Name="Handle";handle.Anchored=false;handle.CanCollide=false;handle.CanTouch=true;handle.Massless=true;handle.Transparency=0
        tool=Instance.new(remote and "Model" or "Tool");tool.Name="Contest Winner Award"
        if not remote then
            tool.ToolTip="Click for applause, gold sparkles, and five seconds of golden touch."
            -- The hat mesh stands on Y; cancel the native hand's quarter turn.
            tool.Grip=CFrame.Angles(math.pi/2,0,0)
            tool.CanBeDropped=false;tool.RequiresHandle=true
        end
        handle.Parent=tool
        sound=Instance.new("Sound");sound.Name="ClapSound";sound.SoundId="rbxassetid://57908388";sound.Volume=1;sound.Parent=handle
        if not remote then
            connect(tool.Equipped,function(equippedMouse)
                held=true
                restoreCursor();mouse=equippedMouse or player:GetMouse();oldCursor=mouse and mouse.Icon
                cursor(activeBurst and waitCursor or idleCursor)
                if sharing.changed then pcall(sharing.changed)end
            end,toolConnections)
            connect(tool.Unequipped,function()held=false;finish();restoreCursor();if sharing.changed then pcall(sharing.changed)end end,toolConnections)
            connect(tool.Activated,function()activateBurst()end,toolConnections)
            connect(handle.Touched,gild,toolConnections)
            tool.Parent=player:FindFirstChildOfClass("Backpack")or character
        else
            tool.Parent=character
            held=true
            local hand=character:FindFirstChild("RightHand")or character:FindFirstChild("Right Arm")
            if hand then
                remoteGrip=Instance.new("Motor6D");remoteGrip.Name="LarpbloxContestAwardGrip";remoteGrip.Part0=hand;remoteGrip.Part1=handle
                local attachment=hand:FindFirstChild("RightGripAttachment")
                if attachment then remoteGrip.C0=attachment.CFrame;remoteGrip.C1=CFrame.Angles(math.pi/2,0,0)
                else remoteGrip.C0=CFrame.new and CFrame.new(0,-1,0)*CFrame.Angles(math.pi/2,0,0) or CFrame.Angles(math.pi/2,0,0);remoteGrip.C1=CFrame.Angles(math.pi/2,0,0)end
                pcall(function()handle.CFrame=hand.CFrame*remoteGrip.C0*remoteGrip.C1:Inverse()end)
                remoteGrip.Parent=hand
            end
        end
    end
    local refresh
    refresh=function()
        if not alive then return end
        local nextHat,nextHumanoid
        if character and character==player.Character then
            nextHumanoid=character:FindFirstChildOfClass("Humanoid")
            for _,item in ipairs(character:GetChildren())do if matches(item)then nextHat=item;break end end
        end
        local nextHandle=nextHat and nextHat:FindFirstChild("Handle")
        if nextHat~=hat or nextHumanoid~=humanoid or nextHandle~=watchedHandle then
            clearTool();disconnect(appearanceConnections);hat=nextHat;humanoid=nextHumanoid;watchedHandle=nextHandle
            local handle=watchedHandle
            if handle then connect(handle:GetPropertyChangedSignal("Transparency"),refresh,appearanceConnections)end
            if humanoid then connect(humanoid.Died,clearTool,appearanceConnections)end
        end
        if active()and (not remote or held)then createTool()else clearTool()end
    end
    local function bind(nextCharacter)
        clearTool();disconnect(characterConnections);disconnect(appearanceConnections)
        character=nextCharacter;hat=nil;humanoid=nil;watchedHandle=nil
        if character then
            connect(character.DescendantAdded,function(item)if matches(item)or item:IsA("Humanoid")or(item.Name=="Handle"and item.Parent==hat)then refresh()end end,characterConnections)
            connect(character.DescendantRemoving,function(item)if item==hat or item==humanoid then task.defer(refresh)end end,characterConnections)
        end
        refresh()
    end
    connect(player.CharacterAdded,bind,connections);bind(player.Character)
    local api={
        refresh=refresh,
        setEnabled=function(value)enabled=value==true;refresh()end,
        replay=function(kind,payload)
            if not remote or type(payload)~="table" then return false end
            if kind=="award-burst" then return activateBurst() end
            if kind=="award-gild" and activeBurst and type(payload.position)=="table" then
                local p=payload.position;local pos=Vector3.new(tonumber(p[1] or p.X or p.x),tonumber(p[2] or p.Y or p.y),tonumber(p[3] or p.Z or p.z))
                local parts=workspace.GetPartBoundsInBox and workspace:GetPartBoundsInBox(CFrame.new(pos),Vector3.new(2,2,2)) or {}
                for _,part in ipairs(parts)do gild(part)end
                return true
            end
            return false
        end,
        isHeld=function()return held end,
        setHeld=function(value)
            value=value==true;if held==value then return held end;held=value
            if not held then finish();clearTool()else refresh()end
            if sharing.changed then pcall(sharing.changed)end;return held
        end,
        destroy=function()alive=false;clearTool();disconnect(connections);disconnect(characterConnections);disconnect(appearanceConnections);character=nil;hat=nil end,
    }
    return api
end
