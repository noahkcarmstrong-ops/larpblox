-- Shows the saved Larp appearance in Roblox's native avatar thumbnails.
-- Restores native images when its local preview is disabled.
local function read(object, key)
    local ok, value = pcall(function() return object and object[key] end)
    return ok and value or nil
end

local function ancestors(object)
    local result, current = {}, object
    while current do result[#result + 1] = current; current = read(current, "Parent") end
    return result
end

local function attr(object, key)
    local ok, value = pcall(function() return object:GetAttribute(key) end)
    return ok and value or nil
end

local function hasOwnId(object, player)
    local id = tostring(read(player, "UserId") or "")
    if id == "" then return false end
    for _, item in ipairs(ancestors(object)) do
        local name = tostring(read(item, "Name") or "")
        if name == id or name == "PlayerEntry_" .. id or name == "p_" .. id
            or name == "PlayerLabel" .. tostring(read(player, "Name") or "") then return true end
        for _, key in ipairs({"UserId", "UserID", "PlayerId", "playerId"}) do
            if tostring(attr(item, key) or "") == id then return true end
        end
    end
    return false
end

local function plainText(value)
    return tostring(value or ""):gsub("<[^>]->", "")
end

local function uniquePeopleRow(object, player, options)
    local username = tostring(options and options.name or "")
    local realUsername = tostring(read(player, "Name") or "")
    local accepted = {}
    if username ~= "" then accepted["@" .. username] = true end
    if realUsername ~= "" then accepted["@" .. realUsername] = true end
    if next(accepted) == nil then return false end
    local path = ancestors(object)
    local inPeople=false
    for _,ancestor in ipairs(path)do
        if tostring(read(ancestor,"Name") or ""):lower():find("people",1,true)then inPeople=true;break end
    end
    if not inPeople then return false end
    for depth=2,math.min(#path,6)do
        local row=path[depth]
        local class=read(row,"ClassName")
        if class=="CoreGui" or class=="PlayerGui" or class=="ScreenGui" then break end
        local descendants=read(row,"GetDescendants") and row:GetDescendants() or {}
        if #descendants>120 then break end
        local found,other,texts=false,false,0
        local portraits=0
        for _,child in ipairs(descendants)do
            local class=read(child,"ClassName")
            local name=tostring(read(child,"Name")or ""):lower()
            if (class=="ImageLabel"or class=="ImageButton")and
                (name=="avatar"or name=="avatarimage"or name=="headshot"or name=="avatarthumbnail"or name=="thumbnail")then
                portraits=portraits+1
                -- Never resolve one card from a sibling card's username.
                if portraits>1 then return false end
            end
            if class=="TextLabel" or class=="TextButton" then
                texts=texts+1
                local text=plainText(read(child,"Text"))
                if accepted[text] then found=true
                elseif text:sub(1,1)=="@"then other=true end
            end
        end
        if found or other then return found and not other and texts<=8 end
    end
    return false
end

local nativeImageSources=setmetatable({}, {__mode="k"})
local function thumbnailUserId(image)
    local lower = image:lower()
    local kind=lower:match("^rbxthumb://type=([^&]+)")or lower:match("[?&]type=([^&]+)")
    if lower:match("^rbxthumb://")and (kind=="avatar"or kind=="avatarheadshot"or kind=="avatarbust")then
        return lower:match("[?&]id=(%d+)&")or lower:match("[?&]id=(%d+)$")
    end
    local host = lower:match("^https?://([^/]+)/")
    local robloxHost = host and (host == "roblox.com" or host:match("%.roblox%.com$") or host:match("%.rbxcdn%.com$"))
    if not robloxHost then return nil end
    local bust = lower:match("/bust%-thumbnail/image%?") ~= nil
    local headshot = lower:match("/headshot%-thumbnail/image%?") ~= nil
    local avatar = lower:match("/thumbs/avatar%.ashx%?") ~= nil
    if not bust and not headshot and not avatar then return nil end
    return lower:match("[?&]userid=(%d+)&")or lower:match("[?&]userid=(%d+)$")
end

local function profileOwnImage(object, player, options)
    local name = tostring(read(object, "Name") or ""):lower()
    if name ~= "charactericon" and name ~= "icon" then return false end
    if tostring(read(object, "Image") or "") == "" then return false end
    if name == "icon" then
        local parent, grandparent = read(object, "Parent"), read(read(object, "Parent"), "Parent")
        if tostring(read(parent, "Name") or ""):lower() ~= "profile"
            or tostring(read(grandparent, "Name") or ""):lower() ~= "nav" then return false end
    end
    local accepted = {}
    local function add(value)
        value = tostring(value or ""); value = value:gsub("%s*%(You%)%s*$", "")
        if value ~= "" then accepted[value] = true end
    end
    add(read(player, "Name")); add(read(player, "DisplayName")); add(options and options.name)
    add(options and options.displayName); add(options and options.larpName)
    local path = ancestors(object); local profile
    for depth = 1, math.min(#path, 9) do
        local itemName = tostring(read(path[depth], "Name") or ""):lower()
        if itemName == "profile" or itemName == "viewprofile" then profile = path[depth]; break end
    end
    if not profile then return false end
    local descendants = read(profile, "GetDescendants") and profile:GetDescendants() or {}
    if #descendants > 240 then return false end
    local labels = 0
    for _, child in ipairs(descendants) do
        local class = read(child, "ClassName")
        if class == "TextLabel" or class == "TextButton" then
            labels = labels + 1; if labels > 24 then return false end
            local text = plainText(read(child, "Text")):gsub("%s*%(You%)%s*$", "")
            if accepted[text] then return true end
        end
    end
    return false
end

local function isAvatarImage(object, player, options)
    local class = read(object, "ClassName")
    if class ~= "ImageLabel" and class ~= "ImageButton" then return false end
    local name = tostring(read(object, "Name") or ""):lower()
    local namedThumbnail = name == "avatar" or name == "avatarimage" or name == "headshot"
        or name == "avatarthumbnail" or name == "thumbnail"
    local explicit=thumbnailUserId(tostring(nativeImageSources[object]or read(object,"Image")or ""))
    -- An explicit foreign thumbnail must not fall through to text matching
    -- while React is reusing a card or has not inserted its labels yet.
    if explicit then return explicit==tostring(read(player,"UserId")or "")end
    if profileOwnImage(object, player, options) then return true end
    if namedThumbnail and hasOwnId(object, player) then return true end
    return namedThumbnail and uniquePeopleRow(object, player, options)
end

local function signature(value, seen)
    if type(value) ~= "table" then return tostring(value) end
    seen = seen or {}; if seen[value] then return "<cycle>" end; seen[value] = true
    local keys = {}; for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}; for _, key in ipairs(keys) do out[#out + 1] = tostring(key) .. "=" .. signature(value[key], seen) end
    return "{" .. table.concat(out, ";") .. "}"
end

local function appearanceSignature(snapshot)
    if type(snapshot)~="table" then return tostring(snapshot)end
    local types={}
    for _,item in ipairs(snapshot.items or {})do types[#types+1]={id=item.id,assetType=item.assetType}end
    return signature({definition=snapshot.definition,types=types})
end

-- Index native UI once for all subjects; keep it current through lifecycle events.
local rootIndexes={}
local function retainRoot(root)
    local index=rootIndexes[root]
    if index then index.users=index.users+1;return end
    index={users=1,objects=setmetatable({}, {__mode="k"})}
    rootIndexes[root]=index
    local function add(object)
        if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("ImageLabel") or object:IsA("ImageButton")then index.objects[object]=true end
    end
    index.added=root.DescendantAdded:Connect(add)
    index.removed=root.DescendantRemoving:Connect(function(object)index.objects[object]=nil end)
    for _,object in ipairs(root:GetDescendants())do add(object)end
end
local function releaseRoot(root)
    local index=rootIndexes[root]
    if not index then return end
    index.users=index.users-1
    if index.users==0 then index.added:Disconnect();index.removed:Disconnect();rootIndexes[root]=nil end
end

local M = {isAvatarImage = isAvatarImage, hasOwnId = hasOwnId}
-- All subjects share the native image's authored transparency. A second
-- renderer must never save the first renderer's masking value as its baseline.
local imageStates = setmetatable({}, {__mode="k"})
-- A refresh can load a new copy of this module. Keep renderer ownership across
-- module copies so the old instance is retired before a new one starts.
local rendererOwners={}
if type(getgenv)=="function" then
    local environment=getgenv()
    if type(environment.__LarpbloxPortraitOwners)~="table" then environment.__LarpbloxPortraitOwners={} end
    rendererOwners=environment.__LarpbloxPortraitOwners
end
local function authoredTransparency(image)
    local current=read(image,"ImageTransparency")
    if current~=1 then return current end
    local saved=attr(image,"LarpbloxPortraitTransparency")
    if type(saved)=="number" then return saved end
    -- Recover a legacy masked value from the matching authored GUI template.
    -- Resolve the relative path generically; no game or element names are known.
    local path,ancestor={},image
    while ancestor and read(ancestor,"ClassName")~="PlayerGui" do
        table.insert(path,1,read(ancestor,"Name"));ancestor=read(ancestor,"Parent")
    end
    if ancestor then
        local ok,template=pcall(function() return game:GetService("StarterGui") end)
        if ok then
            for _,name in ipairs(path) do template=template and template:FindFirstChild(name) end
            if template and read(template,"ClassName")==read(image,"ClassName") then
                return read(template,"ImageTransparency")
            end
        end
    end
    return current
end

function M.create(player, getPreviews, describeSnapshot)
    assert(player, "player is required"); assert(type(getPreviews) == "function", "getPreviews is required")
    local ownerKey=tostring(read(player,"UserId"))
    local previousOwner=rendererOwners[ownerKey]
    if previousOwner and type(previousOwner.destroy)=="function" then pcall(previousOwner.destroy) end
    local alive, enabled, currentName, currentDisplayName, verified, currentImage, previewSnapshot, effectiveKey = true, false, "", "", false, nil, nil, nil
    local overlays, overlayKeys, hiddenImages, connections, scanCount, renderedCount = {}, {}, {}, {}, 0, 0
    local transparencyConnections,backgroundConnections,textConnections,geometryConnections={},{},{},{}
    local pending = {}
    local directImages={}
    local ownedOverlays={}
    local failedImages={}
    local verificationBadges={}
    local verificationGeometry={}
    local renderingVerification=false
    local verificationCharacterConnections={}
    local stagingFolder
    local outfitSnapshot,outfitKey,previewBuild,previewKey
    local ensurePreview
    local imageCandidates=setmetatable({}, {__mode="k"})
    local indexed=false
    local coreGui, playerGui, roots, available
    local status = "Native avatar thumbnails are disabled."

    local function removeVerification(label)
        for _,connection in ipairs(verificationGeometry[label] or {}) do connection:Disconnect() end
        verificationGeometry[label]=nil
        local badge=verificationBadges[label]
        if badge then pcall(function() badge:Destroy() end) end
        verificationBadges[label]=nil
    end
    local function clearVerification()
        for label,badge in pairs(verificationBadges) do
            removeVerification(label)
        end
    end
    local function verificationText(object)
        local text=plainText(read(object,"Text")):gsub("%s*%(You%)%s*$","")
        if text:sub(1,1)=="@" then return false end
        return (currentName~="" and text==currentName) or text==tostring(read(player,"Name") or "")
            or text==tostring(read(player,"DisplayName") or "") or (currentDisplayName~="" and text==currentDisplayName)
    end
    local function verifiedRosterRow(object)
        local ancestor=object
        while ancestor do
            local name=tostring(read(ancestor,"Name") or ""):lower()
            if name:find("leaderboard",1,true) or name:find("scoreboard",1,true) or name:find("roster",1,true) then return true end
            ancestor=read(ancestor,"Parent")
        end
        return false
    end
    local function positionVerification(object,badge)
        local card,row=false,false
        for _,ancestor in ipairs(ancestors(object)) do
            local name=read(ancestor,"Name")
            if name=="CardContent" then card=true;break end
            if name=="PersonRow" then row=true;break end
        end
        badge.Position=UDim2.new(1,2,0.5,0)
        if not card and not row then return end
        local bounds,size=read(object,"TextBounds"),read(object,"AbsoluteSize")
        if bounds and size then
            local width=math.min(bounds.X,size.X)
            -- Rows keep the original right-edge anchor. Roblox can retain a
            -- wider name slot after alias replacement; remove that empty space.
            badge.Position=card and UDim2.new(0,width+2,0.5,0)
                or UDim2.new(1,width-size.X+2,0.5,0)
        end
    end
    local function renderVerification()
        if renderingVerification then return end
        renderingVerification=true
        for label,badge in pairs(verificationBadges) do
            if not read(label,"Parent") then removeVerification(label) end
        end
        if not alive or not enabled or not verified then clearVerification();renderingVerification=false;return end
        local seen={}
        for _,root in ipairs(roots) do
            local index=rootIndexes[root]
            for object in pairs(index and index.objects or {}) do
                local class=read(object,"ClassName")
                local textObject=class=="TextLabel" or class=="TextButton"
                local rosterText=textObject and plainText(read(object,"Text")):gsub("%s*%(You%)%s*$","") or ""
                if textObject and
                    ((verificationText(object) and (hasOwnId(object,player) or uniquePeopleRow(object,player,{name=currentName})))
                        or (rosterText=="@"..currentName and verifiedRosterRow(object))) then
                    seen[object]=true
                    if not verificationBadges[object] then
                        local badge=Instance.new("ImageLabel");badge.Name="LarpbloxVerifiedBadge";badge.BackgroundTransparency=1
                        badge.Size=UDim2.fromOffset(16,16);badge.AnchorPoint=Vector2.new(0,0.5)
                        badge.Position=UDim2.new(1,2,0.5,0);badge.ZIndex=(tonumber(read(object,"ZIndex")) or 1)+1
                        badge.Image="rbxasset://textures/ui/VerifiedBadgeNameIcon.png";badge.Parent=object
                        verificationBadges[object]=badge
                        local bindings={}
                        verificationGeometry[object]=bindings
                        local queued=false
                        local function settledPosition()
                            if queued then return end
                            queued=true
                            task.defer(function()
                                -- Roblox replaces/sizes the native name over the
                                -- current frame. Reading bounds inside its signal
                                -- can still return the previous account name width.
                                task.wait()
                                queued=false
                                if verificationBadges[object]==badge then positionVerification(object,badge) end
                            end)
                        end
                        for _,property in ipairs({"Text","TextBounds","AbsoluteSize"}) do
                            local ok,signal=pcall(function() return object:GetPropertyChangedSignal(property) end)
                            if ok and signal then bindings[#bindings+1]=signal:Connect(settledPosition) end
                        end
                        settledPosition()
                    end
                    positionVerification(object,verificationBadges[object])
                end
            end
        end
        for label,badge in pairs(verificationBadges) do
            if not seen[label] then removeVerification(label) end
        end
        renderingVerification=false
    end
    local verificationQueued=false
    local function queueVerification(object)
        if not alive or not enabled or not verified or verificationQueued then return end
        if object then
            local class=read(object,"ClassName")
            local rosterText=plainText(read(object,"Text")):gsub("%s*%(You%)%s*$","")
            local rosterMatch=rosterText=="@"..currentName and verifiedRosterRow(object)
            if (class~="TextLabel" and class~="TextButton") or (not verificationText(object) and not rosterMatch) then return end
        end
        verificationQueued=true
        task.defer(function()
            verificationQueued=false
            if alive and enabled and verified then renderVerification() end
        end)
    end
    local function bindVerificationCharacter(character)
        for _,connection in ipairs(verificationCharacterConnections) do pcall(function() connection:Disconnect() end) end
        verificationCharacterConnections={}
        clearVerification()
        if not character then return end
        -- Badges belong to UI labels, not the character's body/accessories.
        -- UI text/addition events already refresh them; scanning for every
        -- spawned limb or accessory multiplies full UI work during respawns.
        if enabled and verified then queueVerification() end
    end

    local function restoreImage(image)
        if hiddenImages[image] then
            hiddenImages[image] = nil
            local state=imageStates[image]
            if state then
                state.owners[hiddenImages]=nil
                if next(state.owners)==nil then
                    state.writing=true
                    pcall(function()
                        image.ImageTransparency=state.transparency
                        image.BackgroundTransparency=state.backgroundTransparency
                    end)
                    state.writing=false
                end
            end
        end
    end
    local function hideImage(image)
        local state=imageStates[image]
        if not state then
            state={transparency=authoredTransparency(image),backgroundTransparency=read(image,"BackgroundTransparency"),owners={}}
            imageStates[image]=state
            pcall(function() image:SetAttribute("LarpbloxPortraitTransparency",state.transparency) end)
        end
        hiddenImages[image]=true;state.owners[hiddenImages]=true
        state.writing=true
        pcall(function() image.ImageTransparency = 1;image.BackgroundTransparency=1 end)
        state.writing=false
    end
    local function restoreAllImages()
        for image in pairs(hiddenImages) do restoreImage(image) end
    end
    local function destroyOverlay(image, restore)
        if directImages[image] then
            directImages[image]=nil
            local source=nativeImageSources[image]
            nativeImageSources[image]=nil
            if source then pcall(function() image.Image=source end) end
        end
        local staged = pending[image]
        if staged then
            pending[image] = nil
            if staged.connection then staged.connection:Disconnect() end
            pcall(function() staged.overlay:Destroy() end)
        end
        local overlay = overlays[image]
        overlays[image] = nil; overlayKeys[image] = nil
        if overlay then pcall(function() overlay:Destroy() end) end
        if restore ~= false then restoreImage(image) end
    end
    local bodyParts={Head=true,Torso=true,UpperTorso=true,LowerTorso=true,
        ["Left Arm"]=true,["Right Arm"]=true,["Left Leg"]=true,["Right Leg"]=true,
        LeftUpperArm=true,LeftLowerArm=true,LeftHand=true,RightUpperArm=true,RightLowerArm=true,RightHand=true,
        LeftUpperLeg=true,LeftLowerLeg=true,LeftFoot=true,RightUpperLeg=true,RightLowerLeg=true,RightFoot=true}
    local function fullPortrait(image)
        local source=tostring(nativeImageSources[image] or read(image,"Image") or ""):lower()
        if source:find("avatarheadshot",1,true) or source:find("avatarbust",1,true)
            or source:find("bust-thumbnail",1,true) or source:find("headshot-thumbnail",1,true) then return false end
        -- CDN URLs omit the thumbnail kind. Use the native portrait slot too,
        -- so peers and our own avatar share the same headshot camera.
        local name=tostring(read(image,"Name") or ""):lower()
        if name=="headshot" or name=="avatarheadshot" then return false end
        local imageSize=read(image,"AbsoluteSize")
        for depth,ancestor in ipairs(ancestors(image)) do
            if depth>6 then break end
            local ancestorName=tostring(read(ancestor,"Name") or ""):lower()
            if ancestorName=="cardcontent" then return true end
            if ancestorName=="personrow" or ancestorName=="playerlist" or ancestorName=="playerlistmaster" then return false end
            local size=read(ancestor,"AbsoluteSize")
            if depth==1 or (size and imageSize and math.abs(size.X-imageSize.X)<=1 and math.abs(size.Y-imageSize.Y)<=1) then
                local find=read(ancestor,"FindFirstChildOfClass")
                local corner=find and ancestor:FindFirstChildOfClass("UICorner")
                local radius=read(corner,"CornerRadius")
                if radius and radius.Scale>=0.5 then return false end
            end
        end
        return true
    end
    local function posePortrait(frame,image)
        if not fullPortrait(image) then return end
        local ok,previews=pcall(getPreviews)
        if ok and previews and previews.poseThumbnail then previews.poseThumbnail(frame) end
    end
    local function frameCamera(frame, image)
        local world=frame:FindFirstChild("CharacterPreview")
        local model=world and world:FindFirstChild("Avatar")
        local camera=frame.CurrentCamera
        if not (model and camera) then return end
        local source=tostring(read(image,"Image") or ""):lower()
        local full=fullPortrait(image)
        if full then
            local ok,previews=pcall(getPreviews)
            if ok and previews and previews.frameThumbnail then previews.frameThumbnail(frame);return end
        end
        local bust=source:find("avatarbust",1,true) or source:find("bust-thumbnail",1,true)
            or tostring(read(image,"Name") or ""):lower()=="charactericon"
        local min,max
        local points={}
        for _,part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency<1
                and ((bodyParts[part.Name] and (full or part.Name=="Head" or (bust and (part.Name=="Torso" or part.Name=="UpperTorso"))))
                    or part:GetAttribute("LarpbloxPreviewHeadAccessory")==true) then
                for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
                    local point=part.CFrame:PointToWorldSpace(Vector3.new(part.Size.X*x/2,part.Size.Y*y/2,part.Size.Z*z/2))
                    points[#points+1]=point
                    min=min and Vector3.new(math.min(min.X,point.X),math.min(min.Y,point.Y),math.min(min.Z,point.Z)) or point
                    max=max and Vector3.new(math.max(max.X,point.X),math.max(max.Y,point.Y),math.max(max.Z,point.Z)) or point
                end end end
            end
        end
        if not min then return end
        local center=(min+max)/2
        local absolute=read(image,"AbsoluteSize")
        local aspect=absolute and absolute.Y>0 and math.max(absolute.X/absolute.Y,0.1) or 1
        camera.FieldOfView=35
        local direction=full and Vector3.new(math.sin(math.rad(18)),0.06,-math.cos(math.rad(18))).Unit or Vector3.new(0,0,-1)
        local basis=CFrame.lookAt(center,center-direction)
        local tangent=math.tan(math.rad(camera.FieldOfView/2))
        local distance=0.5
        for _,point in ipairs(points)do
            local relative=basis:PointToObjectSpace(point)
            -- Fit headwear inside the circular portrait, including perspective
            -- depth, rather than fitting just the head to a square viewport.
            local radius=math.sqrt((relative.X/aspect)^2+relative.Y^2)
            distance=math.max(distance,relative.Z+radius/tangent*1.06)
        end
        camera.CFrame=CFrame.lookAt(center+direction*distance,center)
    end
    local function matchPortraitMask(image,overlay)
        local native=image:FindFirstChildOfClass("UICorner")
        -- Native thumbnails may put their mask on a same-sized wrapper.
        local ancestor=image.Parent
        for _=1,3 do
            if native or not ancestor or not ancestor:IsA("GuiObject") then break end
            local size=ancestor.AbsoluteSize
            local imageSize=image.AbsoluteSize
            if math.abs(size.X-imageSize.X)>1 or math.abs(size.Y-imageSize.Y)>1 then break end
            native=ancestor:FindFirstChildOfClass("UICorner")
            ancestor=ancestor.Parent
        end
        local corner=overlay:FindFirstChildOfClass("UICorner")
        local peopleHeadshot=false
        if not native and not fullPortrait(image) then
            local parent=image.Parent
            while parent do
                if tostring(parent.Name):lower()=="peoplelist" then peopleHeadshot=true;break end
                parent=parent.Parent
            end
        end
        if native or peopleHeadshot then
            if not corner then corner=Instance.new("UICorner");corner.Parent=overlay end
            corner.CornerRadius=native and native.CornerRadius or UDim.new(0.5,0)
        elseif corner then corner:Destroy() end
    end
    local function updateGeometry(image)
        for _,overlay in pairs({overlays[image],pending[image] and pending[image].overlay}) do
            matchPortraitMask(image,overlay)
            local viewport=overlay:IsA("ViewportFrame") and overlay or overlay:FindFirstChild("Viewport")
            if viewport then frameCamera(viewport,image) end
        end
    end
    local function makeOverlay(image, imageSource)
        local class = imageSource and "ImageLabel" or "CanvasGroup"
        local overlay = Instance.new(class)
        ownedOverlays[overlay]=true
        overlay.Destroying:Connect(function() ownedOverlays[overlay]=nil end)
        overlay.Name = "LarpbloxOwnAvatarPreview"
        overlay:SetAttribute("LarpbloxPortraitUserId",ownerKey)
        overlay.Position = UDim2.fromScale(0, 0); overlay.Size = UDim2.fromScale(1, 1)
        overlay.BackgroundTransparency = 1; overlay.BorderSizePixel = 0
        overlay.ClipsDescendants = true
        overlay.Visible = false
        overlay.ZIndex = read(image, "ZIndex") or 1
        if imageSource then overlay.Image = imageSource;overlay.ScaleType=read(image,"ScaleType") or Enum.ScaleType.Fit end
        if not imageSource then
            local viewport=Instance.new("ViewportFrame")
            viewport.Name="Viewport";viewport.Size=UDim2.fromScale(1,1)
            viewport.BackgroundTransparency=1;viewport.BorderSizePixel=0
            viewport.ZIndex=overlay.ZIndex;viewport.Parent=overlay
        end
        return overlay
    end
    local render
    local visibilityConnections={}
    local function releaseVisibility(image)
        local group=visibilityConnections[image]
        if not group then return end
        visibilityConnections[image]=nil
        for _,connection in ipairs(group)do connection:Disconnect()end
    end
    local function watchVisibility(image)
        if visibilityConnections[image]then return end
        local group={};visibilityConnections[image]=group
        local function changed()
            if alive and enabled and read(image,"Parent")then render(image)end
        end
        local ancestor=image
        while ancestor do
            local property=ancestor:IsA("GuiObject") and "Visible" or ancestor:IsA("ScreenGui") and "Enabled"
            if property then group[#group+1]=ancestor:GetPropertyChangedSignal(property):Connect(changed)end
            ancestor=ancestor.Parent
        end
        group[#group+1]=image.AncestryChanged:Connect(function()
            releaseVisibility(image)
            if alive and enabled and read(image,"Parent")then watchVisibility(image);changed()end
        end)
    end
    local function visibleImage(image)
        local ancestor=image
        while ancestor do
            if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
            if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return false end
            ancestor=ancestor.Parent
        end
        return true
    end
    render=function(image)
        watchVisibility(image)
        if not visibleImage(image)then return end
        if fullPortrait(image)and not currentImage then
            destroyOverlay(image);status="Waiting for the Roblox-rendered avatar image.";return
        end
        if not previewSnapshot and not currentImage then ensurePreview();return end
        if directImages[image] and overlayKeys[image]==effectiveKey then return end
        local existing=overlays[image]
        if existing and read(existing,"Parent")~=image then
            overlays[image]=nil;overlayKeys[image]=nil;restoreImage(image)
        elseif existing and overlayKeys[image] == effectiveKey then updateGeometry(image);return end
        local staged = pending[image]
        if staged and staged.key == effectiveKey then return end
        if staged then
            pending[image]=nil
            if staged.connection then staged.connection:Disconnect() end
            staged.overlay:Destroy()
        end
        -- Native full-body slots use the Roblox-rendered PNG. Headshots need
        -- a distinct crop/render, so never squeeze a full-body image into them.
        local imageSource, snapshot = fullPortrait(image) and currentImage and not failedImages[currentImage] and currentImage or nil, previewSnapshot
        if fullPortrait(image)and not imageSource then
            destroyOverlay(image);status="Waiting for the Roblox-rendered avatar image.";return
        end
        if not imageSource and (not snapshot or previewKey~=outfitKey) then ensurePreview();return end
        local overlay = makeOverlay(image, imageSource)
        if imageSource then
            -- Keep preload images outside the styled native GUI. Image children
            -- can alter the intrinsic size used by Roblox's automatic layout.
            if not stagingFolder then
                stagingFolder=Instance.new("Folder")
                stagingFolder.Name="LarpbloxPortraitPreloads"
                stagingFolder.Parent=coreGui or playerGui
            end
        end
        staged = {key=effectiveKey, overlay=overlay}
        pending[image] = staged
        -- Reused game UI can remove our child without destroying the ImageLabel.
        -- Drop the stale cache entry and reveal the original before rebuilding.
        overlay.AncestryChanged:Connect(function(_,parent)
            if parent==image or (imageSource and parent==stagingFolder) then return end
            local lost=false
            if overlays[image]==overlay then
                overlays[image]=nil;overlayKeys[image]=nil
                restoreImage(image);lost=true
            elseif pending[image]==staged then
                pending[image]=nil;lost=true
            end
            if lost and alive and enabled then
                task.defer(function()
                    if alive and enabled and read(image,"Parent") and isAvatarImage(image,player,{name=currentName}) then render(image) end
                end)
            end
        end)
        overlay.Parent=imageSource and stagingFolder or image
        local function discard()
            if staged.connection then staged.connection:Disconnect(); staged.connection=nil end
            if pending[image]==staged then pending[image]=nil end
            pcall(function() overlay:Destroy() end)
        end
        local function commit()
            if pending[image]~=staged or not alive or not enabled or staged.key~=effectiveKey
                or not isAvatarImage(image,player,{name=currentName}) then discard();return end
            local previous=overlays[image]
            pending[image]=nil
            if staged.connection then staged.connection:Disconnect();staged.connection=nil end
            if imageSource then
                nativeImageSources[image]=nativeImageSources[image] or read(image,"Image")
                directImages[image]=imageSource
                overlayKeys[image]=staged.key;overlays[image]=nil
                restoreImage(image)
                image.Image=imageSource
                overlay:Destroy()
                if previous then previous:Destroy() end
                renderedCount=renderedCount+1
                return
            end
            if directImages[image] then
                directImages[image]=nil
                local source=nativeImageSources[image];nativeImageSources[image]=nil
                if source then image.Image=source end
            end
            -- Roblox can clone/reuse a thumbnail carrying an old preview child.
            -- Such copies are outside our ownership tables and must not stack.
            for _,child in ipairs(image:GetChildren())do
                if child~=overlay and child~=previous and child.Name=="LarpbloxOwnAvatarPreview" then
                    if ownedOverlays[child]or not attr(child,"LarpbloxPortraitUserId")then child:Destroy()end
                end
            end
            overlays[image]=overlay;overlayKeys[image]=staged.key
            -- Claim the mask before exposing the new portrait. Visibility
            -- listeners must never observe both the fallback and replacement.
            hideImage(image);overlay.Visible=true
            if previous then previous:Destroy() end
            renderedCount=renderedCount+1
        end
        if imageSource then
            matchPortraitMask(image,overlay)
            staged.connection=overlay:GetPropertyChangedSignal("IsLoaded"):Connect(function()
                if overlay.IsLoaded then commit() end
            end)
            if overlay.IsLoaded then commit() end
            task.spawn(function()
                local loaded=false
                local ok=pcall(function()
                    game:GetService("ContentProvider"):PreloadAsync({overlay},function(_,result)
                        if result==Enum.AssetFetchStatus.Success then loaded=true end
                    end)
                end)
                if pending[image]~=staged then return end
                if ok and (loaded or overlay.IsLoaded)then commit()
                else
                    failedImages[imageSource]=true
                    discard()
                    if alive and enabled then render(image)end
                end
            end)
            return
        end
        local ok, previews = pcall(getPreviews)
        if not ok or not previews or type(previews.show) ~= "function" then status = "Preview renderer unavailable.";discard();return end
        local viewport=overlay:FindFirstChild("Viewport") or overlay
        local shown, result = pcall(function() return previews.show(viewport, snapshot) end)
        if shown and result ~= false and pending[image]==staged then
            matchPortraitMask(image,overlay)
            posePortrait(viewport,image)
            frameCamera(viewport,image)
            commit()
        else discard() end
    end
    local watch
    local function watchableImage(object)
        local class = read(object, "ClassName")
        if class ~= "ImageLabel" and class ~= "ImageButton" then return false end
        local name = tostring(read(object, "Name") or ""):lower()
        if name == "avatar" or name == "avatarimage" or name == "headshot" or name == "avatarthumbnail" or name == "thumbnail" or name == "charactericon" then return true end
        -- Games often parent an empty Icon before assigning its thumbnail.
        -- Observe its Image, but only replace an explicit avatar identity match.
        if name == "icon" then return true end
        local image = tostring(nativeImageSources[object] or read(object, "Image") or ""):lower()
        return image:match("^rbxthumb://") ~= nil or image:find("/bust-thumbnail/image?", 1, true) ~= nil
            or image:find("/headshot-thumbnail/image?", 1, true) ~= nil
            or image:find("/thumbs/avatar.ashx?", 1, true) ~= nil
    end
    local function scan()
        if not alive or not enabled or not available then return end
        scanCount = scanCount + 1
        local seen = {}
        for object in pairs(imageCandidates) do
            if isAvatarImage(object, player, {name = currentName}) then seen[object] = true;if watch then watch(object)end;render(object) end
        end
        for image in pairs(hiddenImages) do if not seen[image] then destroyOverlay(image) end end
        for image in pairs(directImages) do if not seen[image] then destroyOverlay(image) end end
    end
    watch=function(object)
        if not watchableImage(object) then return end
        imageCandidates[object]=true
        if not geometryConnections[object] and isAvatarImage(object,player,{name=currentName}) then
            local group={}
            geometryConnections[object]=group
            local function changed() if alive and enabled then updateGeometry(object) end end
            group[#group+1]=object:GetPropertyChangedSignal("AbsoluteSize"):Connect(changed)
            local function watchCorner(child)
                if child:IsA("UICorner") then
                    group[#group+1]=child:GetPropertyChangedSignal("CornerRadius"):Connect(changed)
                    changed()
                end
            end
            group[#group+1]=object.ChildAdded:Connect(watchCorner)
            group[#group+1]=object.ChildRemoved:Connect(function(child) if child:IsA("UICorner") then changed() end end)
            for _,child in ipairs(object:GetChildren()) do watchCorner(child) end
        end
        if not connections[object] then
            local ok, signal = pcall(function() return object:GetPropertyChangedSignal("Image") end)
            if ok and signal then
                local connection
                local connected = pcall(function() connection = signal:Connect(function()
                    if not alive or not enabled then return end
                    if directImages[object] and read(object,"Image")~=directImages[object] then
                        nativeImageSources[object]=read(object,"Image")
                        overlayKeys[object]=nil
                    end
                    if isAvatarImage(object, player, {name = currentName}) then watch(object);render(object)
                    else destroyOverlay(object) end
                end) end)
                if connected and connection then connections[object] = connection end
            end
            local okTransparency, transparencySignal = pcall(function() return object:GetPropertyChangedSignal("ImageTransparency") end)
            if okTransparency and transparencySignal then
                local transparencyConnection
                pcall(function() transparencyConnection = transparencySignal:Connect(function()
                    if not alive then return end
                    local state=imageStates[object]
                    if state and state.writing then return end
                    local transparency=read(object,"ImageTransparency")
                    -- Our deferred masking notification is always 1. A game
                    -- fade or reveal must update the value restored on removal.
                    if state and transparency~=1 then
                        state.transparency=transparency
                        pcall(function() object:SetAttribute("LarpbloxPortraitTransparency",transparency) end)
                    end
                    if not enabled then return end
                    if isAvatarImage(object, player, {name = currentName}) then
                        if overlays[object] then hideImage(object) end
                    else destroyOverlay(object) end
                end) end)
                if transparencyConnection then transparencyConnections[object] = transparencyConnection end
            end
            local backgroundConnection=object:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
                if not alive then return end
                local state=imageStates[object]
                if not state or state.writing then return end
                local value=read(object,"BackgroundTransparency")
                if value~=1 then state.backgroundTransparency=value end
                if enabled and overlays[object]then hideImage(object)end
            end)
            backgroundConnections[object]=backgroundConnection
        end
    end
    local function watchPeopleText(object)
        local class = read(object, "ClassName")
        if class ~= "TextLabel" and class ~= "TextButton" then return end
        local people = false
        local scope
        for _, item in ipairs(ancestors(object)) do
            local name = tostring(read(item, "Name") or ""):lower()
            if name:find("people",1,true) or name == "profile" or name == "viewprofile" then people = true; scope = item; break end
        end
        if not people or textConnections[object] then return end
        local ok, signal = pcall(function() return object:GetPropertyChangedSignal("Text") end)
        if not ok or not signal then return end
        local connection
        pcall(function() connection = signal:Connect(function()
            if not alive or not enabled then return end
            -- A profile name change only affects portraits inside that profile/list.
            for image in pairs(imageCandidates) do
                if image:IsDescendantOf(scope) then
                    if isAvatarImage(image, player, {name = currentName}) then watch(image); render(image)
                    elseif hiddenImages[image]or directImages[image]or pending[image]then destroyOverlay(image) end
                end
            end
            if verified then queueVerification(object) end
        end) end)
        if connection then textConnections[object] = connection end
    end
    local ok = pcall(function() coreGui = game:GetService("CoreGui") end)
    -- Portraits of every player are rendered in the viewing client's UI.
    -- The subject player supplies identity/appearance, not the GUI root.
    local viewer = player
    pcall(function() viewer = game:GetService("Players").LocalPlayer or player end)
    pcall(function() playerGui = viewer:FindFirstChildOfClass("PlayerGui") end)
    roots = {}
    if ok and coreGui then roots[#roots + 1] = coreGui end
    if playerGui then roots[#roots + 1] = playerGui end
    for _,root in ipairs(roots)do retainRoot(root)end
    available = #roots > 0
    if not available then status = "Roblox CoreGui is unavailable; native avatar thumbnails could not be inspected." end
    pcall(function()
        connections.verificationCharacterAdded=player.CharacterAdded:Connect(bindVerificationCharacter)
        bindVerificationCharacter(player.Character)
    end)
    if available then
        for index, root in ipairs(roots) do pcall(function() connections["root" .. index] = root.DescendantAdded:Connect(function(object)
            watch(object); watchPeopleText(object)
            if enabled and isAvatarImage(object,player,{name=currentName}) then render(object) end
            queueVerification(object)
        end) end) end
        for index,root in ipairs(roots)do
            pcall(function()connections["removed"..index]=root.DescendantRemoving:Connect(function(object)
                imageCandidates[object]=nil
                releaseVisibility(object)
                if overlays[object] or directImages[object] or hiddenImages[object] or pending[object] then destroyOverlay(object)end
                if geometryConnections[object] then
                    for _,connection in ipairs(geometryConnections[object]) do connection:Disconnect() end
                    geometryConnections[object]=nil
                end
                for _,group in ipairs({connections,transparencyConnections,backgroundConnections,textConnections})do
                    if group[object]then group[object]:Disconnect();group[object]=nil end
                end
            end)end)
        end
    end

    ensurePreview=function()
        if not alive or not enabled or not outfitSnapshot or type(describeSnapshot)~="function" then return end
        local key=outfitKey
        if previewKey==key or (previewBuild and previewBuild.key==key)then return end
        local ticket={key=key};previewBuild=ticket
        local selected=outfitSnapshot
        task.spawn(function()
            local desc
            local ok,captured=pcall(function()
                desc=describeSnapshot(selected)
                local rig=selected.definition.playerAvatarType
                local rigType=rig and rig.playerAvatarType=="R6" and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
                return getPreviews().captureDescription(desc,rigType)
            end)
            if desc then desc:Destroy()end
            if previewBuild~=ticket then return end
            previewBuild=nil
            if not alive or not enabled or outfitKey~=key then return end
            if not ok then status="Waiting for the saved avatar preview.";return end
            previewSnapshot=captured;previewKey=key
            scan()
        end)
    end
    local api = {}
    function api.update(options)
        if not alive then return api.report() end
        options = options or {}; local wasEnabled=enabled; local previousName=currentName
        local previousDisplayName,previousVerified=currentDisplayName,verified
        enabled = options.enabled == true; currentName = tostring(options.name or "")
        currentDisplayName=tostring(options.displayName or "")
        verified=options.verified==true
        currentImage = type(options.image)=="string" and options.image~="" and options.image or nil
        local effectiveSnapshot = options.snapshot
        outfitSnapshot=effectiveSnapshot
        outfitKey=appearanceSignature(effectiveSnapshot)
        local nextKey = outfitKey .. "|" .. tostring(currentImage or "")
        if enabled and wasEnabled and previousName==currentName and nextKey==effectiveKey and (currentImage or previewSnapshot) then
            if previousDisplayName~=currentDisplayName or previousVerified~=verified then renderVerification()end
            return api.report()
        end
        if enabled and not indexed then
            local preflight = {}
            for _, root in ipairs(roots) do
                local index=rootIndexes[root]
                for object in pairs(index and index.objects or {})do preflight[#preflight+1]=object end
            end
            for _, object in ipairs(preflight) do watch(object); watchPeopleText(object) end
            indexed=true
        end
        if enabled and effectiveSnapshot == nil and not currentImage then
            renderVerification();status="Waiting for avatar data.";return api.report()
        end
        effectiveKey = nextKey
        if not enabled then
            for image in pairs(visibilityConnections)do releaseVisibility(image)end
            previewSnapshot = nil;previewKey=nil;previewBuild=nil
            for image in pairs(directImages) do destroyOverlay(image) end
            for image in pairs(overlays) do destroyOverlay(image) end
            for image in pairs(pending) do destroyOverlay(image) end
            restoreAllImages();clearVerification()
            status = "Native avatar thumbnails are disabled."; return api.report()
        end
        scan()
        -- Appearance-only updates do not change badge ownership or placement.
        -- UI additions/text/geometry changes already have their own listeners.
        if not wasEnabled or previousName~=currentName or previousDisplayName~=currentDisplayName or previousVerified~=verified then renderVerification()end
        status = available and "Native avatar thumbnails active." or status; return api.report()
    end
    function api.report() return status .. " Scans: " .. tostring(scanCount) .. "; rendered: " .. tostring(renderedCount) .. "." end
    function api.destroy()
        if not alive then return end
        alive = false;previewBuild=nil
        for image in pairs(visibilityConnections)do releaseVisibility(image)end
        for _,root in ipairs(roots)do releaseRoot(root)end
        if rendererOwners[ownerKey]==api then rendererOwners[ownerKey]=nil end
        for _, connection in pairs(connections) do pcall(function() connection:Disconnect() end) end
        for _,group in ipairs({transparencyConnections,backgroundConnections,textConnections})do
            for _,connection in pairs(group)do pcall(function()connection:Disconnect()end)end
        end
        for _,group in pairs(geometryConnections) do
            for _,connection in ipairs(group) do pcall(function() connection:Disconnect() end) end
        end
        connections = {};transparencyConnections={};backgroundConnections={};textConnections={};geometryConnections={}
        for _,connection in ipairs(verificationCharacterConnections) do pcall(function() connection:Disconnect() end) end
        verificationCharacterConnections={}
        for image in pairs(directImages) do pcall(destroyOverlay,image) end
        for image in pairs(overlays) do pcall(destroyOverlay,image) end
        for image in pairs(pending) do pcall(destroyOverlay,image) end
        -- The ownership set also catches previews no longer referenced by a slot
        -- after a cancelled render or a partially completed replacement.
        for overlay in pairs(ownedOverlays) do pcall(function() overlay:Destroy() end) end
        ownedOverlays={}
        for image in pairs(hiddenImages) do pcall(restoreImage,image) end
        clearVerification()
        if stagingFolder then pcall(function() stagingFolder:Destroy() end);stagingFolder=nil end
    end
    rendererOwners[ownerKey]=api
    return api
end

return M
