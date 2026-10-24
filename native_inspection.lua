-- Reopens the selected player's native avatar inspector with local cosmetic data.
local fields={[2]="GraphicTShirt",[11]="Shirt",[12]="Pants",[17]="Head",[79]="Head",[18]="Face",[27]="Torso",[28]="RightArm",[29]="LeftArm",[30]="LeftLeg",[31]="RightLeg",[48]="ClimbAnimation",[50]="FallAnimation",[51]="IdleAnimation",[52]="JumpAnimation",[53]="RunAnimation",[54]="SwimAnimation",[55]="WalkAnimation",[78]="MoodAnimation"}
local accessoryTypes={[8]="Hat",[41]="Hair",[42]="Face",[43]="Neck",[44]="Shoulder",[45]="Front",[46]="Back",[47]="Waist",[64]="TShirt",[65]="Shirt",[66]="Pants",[67]="Jacket",[68]="Sweater",[69]="Shorts",[70]="LeftShoe",[71]="RightShoe",[72]="DressSkirt",[76]="Eyebrow",[77]="Eyelash"}
local scales={height="HeightScale",width="WidthScale",depth="DepthScale",head="HeadScale",proportion="ProportionScale",bodyType="BodyTypeScale"}
local colors={headColor="HeadColor",torsoColor="TorsoColor",leftArmColor="LeftArmColor",rightArmColor="RightArmColor",leftLegColor="LeftLegColor",rightLegColor="RightLegColor"}
local function description(snapshot)
    assert(type(snapshot)=="table" and type(snapshot.definition)=="table" and type(snapshot.items)=="table","Local outfit is not ready.")
    local desc=Instance.new("HumanoidDescription")
    local ok,err=pcall(function()
        local metadata={}
        for _,asset in ipairs(snapshot.definition.assets or {})do metadata[asset.id]=asset.meta end
        local accessories={}
        for _,item in ipairs(snapshot.items)do
            local field=fields[item.assetType]
            if field then desc[field]=item.id
            elseif accessoryTypes[item.assetType]then
                local kind=Enum.AccessoryType[accessoryTypes[item.assetType]]
                assert(kind,"Roblox does not support this accessory type.")
                local meta=metadata[item.id]
                local layered=item.assetType>=64 and item.assetType<=72
                local entry={AssetId=item.id,AccessoryType=kind,IsLayered=layered}
                if layered then entry.Order=meta and meta.order or #accessories;entry.Puffiness=meta and meta.puffiness or 0 end
                accessories[#accessories+1]=entry
            end
        end
        desc:SetAccessories(accessories,true)
        for name,field in pairs(scales)do local value=snapshot.definition.scales and snapshot.definition.scales[name];if value~=nil then desc[field]=value end end
        for name,field in pairs(colors)do
            local value=snapshot.definition.bodyColors and snapshot.definition.bodyColors[name]
            if value then
                value=value:gsub("^#","")
                assert(value:match("^%x%x%x%x%x%x$"),"Local skin color is invalid.")
                desc[field]=Color3.fromRGB(tonumber(value:sub(1,2),16),tonumber(value:sub(3,4),16),tonumber(value:sub(5,6),16))
            end
        end
    end)
    if not ok then desc:Destroy();error(err)end
    return desc
end
local M={description=description}
function M.create(player,getPreviews)
    local core,gui
    pcall(function() core=game:GetService("CoreGui");gui=game:GetService("GuiService")end)
    local active=false
    local alive=true
    local modeEnabled,currentName=false,player.Name
    local masked,connections,knownLabels={},{},{}
    local panels,inspectRoots={},{}
    local rootVisibility={}
    local guardingVisibility=false
    local mutatingPanel=false
    local changingMask=false
    local currentSnapshot,currentImage,previewData,previewKey,previewCharacter
    local previewBuild
    local warmedItems,refreshQueued=nil,false
    local quarantineUnknownPanels,maskPreview
    local overlayName="LarpbloxInspectPreview"
    local fallbackGui,fallbackEntry,previewLabel
    local presentationAnchor,presentationRevision=nil,0
    local presentationConnections={}
    local schedulePreview
    local activeDescription
    local function releaseDescription()
        if activeDescription then activeDescription:Destroy();activeDescription=nil end
    end
    local lastSignature,lastLabel,adopting,lastName,status=nil,nil,false,nil,"Inspector is waiting."
    local lastMismatchKey,itemStateKey,recoveryPending
    local itemCheckRevision=0
    local function visible(object)
        local current=object
        while current do
            if current:IsA("GuiObject") and not current.Visible and not (panels[current] and not panels[current].ready) then return false end
            if current:IsA("ScreenGui") and not current.Enabled then return false end
            if current==core then return true end
            current=current.Parent
        end
        return false
    end
    local function hidePresentation()
        presentationRevision=presentationRevision+1
        if fallbackGui then fallbackGui.Enabled=false end
        if fallbackEntry and fallbackEntry.overlay then fallbackEntry.overlay.Visible=false end
    end
    local function releasePresentation()
        hidePresentation()
        for _,connection in ipairs(presentationConnections)do connection:Disconnect()end
        presentationConnections={};presentationAnchor=nil
    end
    local function bindPresentation(anchor)
        if presentationAnchor==anchor then return end
        releasePresentation()
        presentationAnchor=anchor
        local function changed()
            if not alive or mutatingPanel then return end
            -- The preview has its own ScreenGui, so native ancestor visibility
            -- and removal must dismiss it explicitly, including during loading.
            if not visible(anchor) then hidePresentation()
            else schedulePreview()end
        end
        local ancestor=anchor
        while ancestor and ancestor~=core do
            if ancestor:IsA("GuiObject") or ancestor:IsA("ScreenGui") then
                local property=ancestor:IsA("ScreenGui") and "Enabled" or "Visible"
                presentationConnections[#presentationConnections+1]=ancestor:GetPropertyChangedSignal(property):Connect(changed)
            end
            presentationConnections[#presentationConnections+1]=ancestor.AncestryChanged:Connect(function()
                releasePresentation()
                if alive and modeEnabled then schedulePreview()end
            end)
            presentationConnections[#presentationConnections+1]=ancestor.Destroying:Connect(releasePresentation)
            ancestor=ancestor.Parent
        end
    end
    local function ownTitle(alias,knownOnly)
        local objects={}
        if knownOnly then
            for object in pairs(knownLabels)do objects[#objects+1]=object end
        else pcall(function()objects=core:GetDescendants()end)end
        for _,object in ipairs(objects)do
            if object.Parent and object:IsA("TextLabel") and visible(object.Parent) then
                local text=object.Text
                local scoped=false
                local scopeRoot
                local ancestor=object.Parent
                while ancestor do
                    if ancestor.Name:find("InspectAndBuy",1,true) or ancestor.Name=="AvatarInspectMenu" then scoped=true;scopeRoot=ancestor end
                    ancestor=ancestor.Parent
                end
                if scoped then knownLabels[object]=true end
                if scoped and (text==player.Name.."'s Avatar" or text==alias.."'s Avatar" or (active and (object==lastLabel or adopting) and (text==alias.."'s Avatar" or (lastName and text==lastName.."'s Avatar"))))then
                    return object,text,scopeRoot
                end
            end
        end
    end
    local function nativeAvatarVisual(object)
        if object.Name==overlayName then return false end
        if object:IsA("ViewportFrame") then return true end
        if not (object:IsA("ImageLabel") or object:IsA("ImageButton")) then return false end
        local ancestor=object.Parent
        while ancestor do
            if ancestor.Name==overlayName then return false end
            if ancestor.Name=="ViewportContainer" or (ancestor.Name=="Thumbnail" and ancestor.Parent and ancestor.Parent.Name=="InnerView") then return true end
            if ancestor.Name:find("InspectAndBuy",1,true) then break end
            ancestor=ancestor.Parent
        end
        return false
    end
    local function panelVisibility(root,show)
        local outfitKey=currentSnapshot and game:GetService("HttpService"):JSONEncode(currentSnapshot) or ""
        local targets={}
        local itemNames,itemIds={},{}
        local function normalized(value)return tostring(value or ""):match("^%s*(.-)%s*$"):lower()end
        local function itemLabel(object)
            local name=string.lower(object.Name or "")
            return name=="itemname" or name=="itemcardfootertitle"
        end
        local function modernCard(object)
            local name=string.lower(object.Name or "")
            if not name:match("^item%d+$") then return false end
            for _,child in ipairs(object:GetDescendants())do
                if child:IsA("TextLabel") and itemLabel(child) then return true end
            end
            return false
        end
        for _,item in ipairs(currentSnapshot and currentSnapshot.items or {})do
            if type(item.name)=="string" then itemNames[normalized(item.name)]=true end
            itemIds[tostring(item.id)]=true
        end
        local function larpItems(object)
            local labels={object}
            for _,child in ipairs(object:GetDescendants())do labels[#labels+1]=child end
            local found=false
            for _,label in ipairs(labels)do
                if label:IsA("TextLabel") and itemLabel(label) then
                    found=true
                    if not itemNames[normalized(label.Text)] then
                        local matched,hasAssetIdentity=false,false
                        local card=label.Parent
                        for depth=1,4 do
                            if not card then break end
                            local images,labels={},0
                            for _,child in ipairs(card:GetDescendants())do
                                if child:IsA("TextLabel") and itemLabel(child) then labels=labels+1 end
                                if child:IsA("ImageLabel") or child:IsA("ImageButton") then
                                    local image=tostring(child.Image or "")
                                    local id=image:match("^rbxthumb://type=Asset&id=(%d+)[&]")
                                    if id then images[#images+1]=id end
                                end
                            end
                            if labels>1 then break end
                            if #images>0 then
                                hasAssetIdentity=true
                                matched=true;for _,id in ipairs(images)do if not itemIds[id] then matched=false end end
                                break
                            end
                            if card==object then break end
                            card=card.Parent
                        end
                        if not matched then return false,hasAssetIdentity end
                    end
                end
            end
            return found
        end
        -- Keep the native panel shell (including close/back navigation) alive.
        -- Only quarantine avatar/item content until the redirected inspector is ready.
        for _,object in ipairs(root:GetDescendants())do
            if object:IsA("GuiObject")then
                local name=string.lower(object.Name or "")
                local itemContent=name=="itemdetails" or name=="itemcontent" or name=="itemname" or name=="itemcardfootertitle" or modernCard(object)
                if itemContent and not object:IsA("TextLabel") then
                    -- A layout may reuse an item-related name for the whole page.
                    -- Never hide a container that also owns the avatar or navigation.
                    local hasItem=false
                    for _,child in ipairs(object:GetDescendants())do
                        local childName=string.lower(child.Name or "")
                        if childName=="itemname" or childName=="itemcardfootertitle" then hasItem=true end
                        if child:IsA("ViewportFrame") or (child:IsA("TextLabel") and child.Text:match("'s Avatar$")) or childName=="close" or childName=="closebutton" or childName=="back" or childName=="backbutton" then itemContent=false;break end
                    end
                    itemContent=itemContent and hasItem
                    if not itemContent and panels[object] then
                        local entry=panels[object]
                        if entry.connection then entry.connection:Disconnect()end
                        mutatingPanel=true;object.Visible=entry.original;mutatingPanel=false
                        panels[object]=nil
                    end
                end
                if nativeAvatarVisual(object) or (object:IsA("TextLabel") and object.Text:match("'s Avatar$")) or itemContent then
                    targets[#targets+1]={object=object,itemContent=itemContent}
                end
            end
        end
        local mismatches,matchedItems={},false
        for _,target in ipairs(targets)do
            local object=target.object
            local entry=panels[object]
            local matches,foreignAsset
            if target.itemContent then matches,foreignAsset=larpItems(object) end
            -- Roblox updates card names/thumbnails in separate steps. A card
            -- already accepted for this outfit stays mounted during that gap.
            local reveal=show and (not target.itemContent or matches or (entry and entry.ready and entry.outfitKey==outfitKey and not foreignAsset))
            if show and target.itemContent and not reveal and foreignAsset then
                local identities={}
                local descendants=object:GetDescendants();descendants[#descendants+1]=object
                for _,child in ipairs(descendants)do
                    if child:IsA("TextLabel") and itemLabel(child) then identities[#identities+1]=child.Text
                    elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then identities[#identities+1]=child.Image end
                end
                table.sort(identities);mismatches[#mismatches+1]=table.concat(identities,"|")
            end
            if show and target.itemContent and reveal then matchedItems=true end
            if not entry then
                entry={original=object.Visible,root=root,ready=false};panels[object]=entry
                pcall(function()entry.connection=object:GetPropertyChangedSignal("Visible"):Connect(function()
                    if modeEnabled and not mutatingPanel then
                        if object.Visible then entry.original=true end
                        if not entry.ready then mutatingPanel=true;object.Visible=false;mutatingPanel=false end
                    end
                end)end)
            end
            entry.ready=reveal;entry.outfitKey=outfitKey
            mutatingPanel=true;object.Visible=reveal and entry.original or false;mutatingPanel=false
        end
        table.sort(mismatches)
        local mismatchKey=table.concat(mismatches,"\n")
        if show and matchedItems then adopting=false end
        local stateKey=mismatchKey.."|"..tostring(matchedItems)
        if show and active and stateKey~=itemStateKey then
            itemStateKey=stateKey;itemCheckRevision=itemCheckRevision+1
            local revision=itemCheckRevision
            -- Catalog cards arrive in pieces. Wait for a quiet result before
            -- deciding whether Roblox loaded the account outfit again.
            task.delay(0.2,function()
                if not alive or not modeEnabled or revision~=itemCheckRevision then return end
                if not ownTitle(currentName,true) then itemStateKey=nil;recoveryPending=false;adopting=false;lastMismatchKey=nil;return end
                if recoveryPending then
                    if matchedItems then recoveryPending=false;lastMismatchKey=mismatchKey end
                    return
                end
                if #mismatches==0 then
                    if matchedItems then lastMismatchKey=nil end
                    return
                end
                if adopting or mismatchKey==lastMismatchKey then return end
                lastMismatchKey=mismatchKey;recoveryPending=true
                local desc=description(currentSnapshot)
                local ok,err=pcall(function()gui:InspectPlayerFromHumanoidDescription(desc,currentName)end)
                if ok then
                    releaseDescription();activeDescription=desc;adopting=true;status="Refreshing local outfit inspection."
                    itemStateKey=nil;schedulePreview()
                else
                    recoveryPending=false;desc:Destroy();status="Roblox blocked the local avatar inspector: "..tostring(err)
                end
            end)
        end
    end
    local function restorePanels(root)
        for object,entry in pairs(panels)do
            if not root or entry.root==root then
                if entry.connection then entry.connection:Disconnect()end
                pcall(function()object.Visible=entry.original end)
                panels[object]=nil
            end
        end
    end
    function quarantineUnknownPanels()
        if not modeEnabled then return end
        for root in pairs(inspectRoots)do
            if not root.Parent then inspectRoots[root]=nil
            else
                local identified,own=false,false
                for _,object in ipairs(root:GetDescendants())do
                    if object:IsA("TextLabel") and object.Text:match("'s Avatar$")then
                        identified=true
                        if object.Text==player.Name.."'s Avatar" or object.Text==currentName.."'s Avatar" then own=true end
                    end
                end
                local ready=active and fallbackGui and fallbackGui.Enabled and fallbackEntry and fallbackEntry.overlay and fallbackEntry.overlay.Visible
                -- Mask own content while its shell is still hidden, before opening animation starts.
                if not identified or (own and not ready) then panelVisibility(root,false)end
            end
        end
    end
    local function restoreMasks()
        releasePresentation()
        restorePanels()
        if fallbackEntry and fallbackEntry.overlay then fallbackEntry.overlay:Destroy()end
        if fallbackGui then fallbackGui:Destroy();fallbackGui=nil;fallbackEntry=nil end
        for viewport,entry in pairs(masked)do
            if entry.connection then entry.connection:Disconnect()end
            if entry.overlay then entry.overlay:Destroy()end
            pcall(function()viewport.ImageTransparency=entry.original end)
        end
        masked={}
    end
    local function renderPreview(entry,parent,isCurrent)
        if (currentSnapshot or currentImage) then
                    -- A browser portrait is optional; gear must not block the local 3D fallback.
                    local key=(currentSnapshot and game:GetService("HttpService"):JSONEncode(currentSnapshot) or "").."|"..tostring(currentImage or "")
                    local ok,err=pcall(function()
                        local previews=getPreviews and getPreviews() or nil
                        if not currentImage and (key~=previewKey or not previewData) then
                            if previewBuild and previewBuild.key==key then return end
                            local ticket={key=key};previewBuild=ticket
                            local snapshot=currentSnapshot
                            local desc=description(snapshot)
                            local avatarType=snapshot.definition.playerAvatarType
                            if type(avatarType)=="table" then avatarType=avatarType.playerAvatarType end
                            local rigType=avatarType=="R6" and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15
                            local captured,data=pcall(previews.captureDescription,desc,rigType)
                            desc:Destroy()
                            if previewBuild~=ticket then return end
                            previewBuild=nil
                            if not captured then error(data) end
                            if not modeEnabled or not currentSnapshot or (game:GetService("HttpService"):JSONEncode(currentSnapshot).."|"..tostring(currentImage or ""))~=key then return end
                            previewData=data;previewKey=key
                        end
                        if not isCurrent() then return end
                        local overlayClass=currentImage and "ImageLabel" or "ViewportFrame"
                        if entry.overlay and not entry.overlay.Parent then entry.overlay=nil;entry.key=nil end
                        if entry.overlay and entry.overlay.ClassName~=overlayClass then
                            entry.overlay:Destroy();entry.overlay=nil;entry.key=nil
                        end
                        if not entry.overlay then
                            local overlay=Instance.new(overlayClass)
                            overlay.Name=overlayName;overlay.BackgroundTransparency=1;overlay.BorderSizePixel=0
                            overlay.Size=UDim2.fromScale(1,1);overlay.Position=UDim2.fromScale(0,0)
                            overlay.Visible=false;overlay.ZIndex=10
                            entry.overlay=overlay;overlay.Parent=parent
                            overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                                if modeEnabled and overlay.Parent and overlay:IsA("ViewportFrame") and previews.frameThumbnail then
                                    previews.frameThumbnail(overlay,{includeAccessories=true,padding=1.25})
                                end
                            end)
                        end
                        entry.overlay.Parent=parent
                        if entry.key~=key then
                            if currentImage then entry.overlay.Image=currentImage;entry.overlay.ScaleType=Enum.ScaleType.Fit
                            elseif waitingForPose then
                                entry.overlay.Text="Loading profile pose..."
                                entry.overlay.TextSize=16
                                entry.overlay.TextColor3=Color3.new(1,1,1)
                                entry.overlay.TextWrapped=true
                            else
                                assert(previews and previews.show(entry.overlay,previewData)~=false,"Local avatar preview could not render.")
                                if previews.poseThumbnail then previews.poseThumbnail(entry.overlay) end
                                if previews.frameThumbnail then previews.frameThumbnail(entry.overlay,{includeAccessories=true,padding=1.25}) end
                            end
                            entry.key=key
                        end
                        if isCurrent() and (entry==fallbackEntry or masked[parent]==entry) then entry.overlay.Visible=true end
                    end)
                    if not ok then status="Local inspection preview is loading: "..tostring(err)end
                end
    end
    function maskPreview(allowReady,preserveLive)
        if fallbackGui and not preserveLive then fallbackGui.Enabled=false end
        if not modeEnabled then return end
        quarantineUnknownPanels()
        local label,title,root=ownTitle(currentName,preserveLive)
        previewLabel=label
        if not label or not root then
            releasePresentation()
            if fallbackGui then fallbackGui.Enabled=false;if fallbackEntry and fallbackEntry.overlay then fallbackEntry.overlay.Visible=false end end
            -- Return shared native containers to normal when another player is inspected.
            for object,entry in pairs(panels)do
                local other=false
                for _,candidate in ipairs(entry.root:GetDescendants())do
                    if candidate:IsA("TextLabel") and candidate.Text:match("'s Avatar$") and candidate.Text~=player.Name.."'s Avatar" and candidate.Text~=currentName.."'s Avatar" and candidate.Text~=(lastName or "").."'s Avatar"then other=true;break end
                end
                if other then restorePanels(entry.root)end
            end
            -- Roblox can reuse the same viewport when inspecting a different player.
            for viewport,entry in pairs(masked)do
                local ancestor=viewport.Parent
                while ancestor and not ancestor.Name:find("InspectAndBuy",1,true) and ancestor.Name~="AvatarInspectMenu"do ancestor=ancestor.Parent end
                if ancestor then
                    for _,object in ipairs(ancestor:GetDescendants())do
                        if object:IsA("TextLabel") and object.Text:match("'s Avatar$") and object.Text~=player.Name.."'s Avatar" and object.Text~=currentName.."'s Avatar" and object.Text~=(lastName or "").."'s Avatar"then
                            if entry.connection then entry.connection:Disconnect()end
                            if entry.overlay then entry.overlay:Destroy()end
                            viewport.ImageTransparency=entry.original;masked[viewport]=nil;break
                        end
                    end
                end
            end
            return
        end
        bindPresentation(label.Parent)
        local revision=presentationRevision
        local function isCurrent()
            return alive and modeEnabled and presentationRevision==revision and presentationAnchor==label.Parent
                and label.Parent~=nil and visible(label.Parent)
        end
        local larpTitle=title==currentName.."'s Avatar"
        local ready=active and larpTitle and fallbackGui and fallbackGui.Enabled and fallbackEntry and fallbackEntry.overlay and fallbackEntry.overlay.Visible
        panelVisibility(root,preserveLive and ready==true)
        if not ready and fallbackGui then fallbackGui.Enabled=false end
        local objects=root:GetDescendants()
        local nativeViewport,nativeThumbnail
        for _,viewport in ipairs(objects)do
            if nativeAvatarVisual(viewport) then
                if viewport:IsA("ViewportFrame") then nativeViewport=nativeViewport or viewport
                elseif viewport.Parent and viewport.Parent.Name=="Thumbnail" then nativeThumbnail=viewport.Parent end
                local entry=masked[viewport]
                if not entry then
                    entry={original=viewport.ImageTransparency or 0};masked[viewport]=entry
                    pcall(function()entry.connection=viewport:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
                        if modeEnabled and not changingMask then
                            changingMask=true;viewport.ImageTransparency=1;changingMask=false
                        end
                    end)end)
                end
                -- The native model can normalize body IDs/scales or fail to generate.
                -- Show the actual local character through the existing preview renderer.
                changingMask=true;viewport.ImageTransparency=1;changingMask=false
                if entry.overlay then entry.overlay.Visible=false end
            end
        end
        if allowReady and currentSnapshot then
            if not fallbackGui then
                fallbackGui=Instance.new("ScreenGui")
                fallbackGui.Name="LarpbloxOwnPreview";fallbackGui.ResetOnSpawn=false
                fallbackGui.IgnoreGuiInset=true;fallbackGui.DisplayOrder=1000
                fallbackGui.Enabled=false;fallbackGui.Parent=core
                fallbackEntry={}
            end
            -- The native layout hides/repositions the 3D container while loading.
            -- Render outside its UIListLayout, aligned with the visible thumbnail slot.
            renderPreview(fallbackEntry,fallbackGui,isCurrent)
            if not isCurrent() then
                -- A close/reopen can overtake model loading. Let that new
                -- presentation use the completed cache without reviving this one.
                if alive and modeEnabled and label.Parent and visible(label.Parent) then schedulePreview()end
                return
            end
            local overlay=fallbackEntry.overlay
            if overlay then
                local bounds=nativeThumbnail or nativeViewport
                if bounds then
                    overlay.AnchorPoint=Vector2.new(0,0)
                    local origin=fallbackGui.AbsolutePosition or Vector2.new(0,0)
                    overlay.Position=UDim2.fromOffset(bounds.AbsolutePosition.X-origin.X,bounds.AbsolutePosition.Y-origin.Y)
                    overlay.Size=UDim2.fromOffset(bounds.AbsoluteSize.X,bounds.AbsoluteSize.Y)
                    fallbackGui.Enabled=overlay.Visible==true and larpTitle
                else
                    -- Older layouts expose no usable viewport bounds; use the title as a fallback.
                    local titleY=label.AbsolutePosition and label.AbsolutePosition.Y or 340
                    if titleY<120 then titleY=340 end
                    local height=math.min(300,math.max(0,titleY-84))
                    overlay.AnchorPoint=Vector2.new(0.5,0)
                    overlay.Position=UDim2.new(0.5,0,0,math.max(64,titleY-height-12))
                    overlay.Size=UDim2.fromOffset(math.min(320,height),height)
                    fallbackGui.Enabled=height>0 and overlay.Visible==true and larpTitle
                end
                panelVisibility(root,fallbackGui.Enabled)
            end
        end
    end
    schedulePreview=function()
        if refreshQueued or not alive or not modeEnabled or not currentSnapshot then return end
        refreshQueued=true
        local function refresh()
            refreshQueued=false
            if alive and modeEnabled and currentSnapshot then maskPreview(true,true)end
        end
        if task and task.defer then task.defer(refresh)else refreshQueued=false end
    end
    local function watchTitle(object)
        if object.Name==overlayName then return false end
        local ancestor=object
        local scoped,root=false,nil
        while ancestor do
            if ancestor.Name:find("InspectAndBuy",1,true) or ancestor.Name=="AvatarInspectMenu"then scoped=true;root=ancestor end
            ancestor=ancestor.Parent
        end
        if root then
            inspectRoots[root]=true
            -- InspectAndBuy can be a Folder; observe the actual GUI objects,
            -- including the reused shell whose Visible changes when reopened.
            if object:IsA("GuiObject") and not rootVisibility[object] then
                pcall(function() rootVisibility[object]=object:GetPropertyChangedSignal("Visible"):Connect(function()
                    if modeEnabled and object.Visible and not guardingVisibility and not mutatingPanel then
                        if panels[object] then panels[object].original=true end
                        guardingVisibility=true
                        local ok,message=pcall(function()quarantineUnknownPanels();maskPreview(false,true)end)
                        guardingVisibility=false
                        if not ok then status="Inspection visibility guard: "..tostring(message) end
                        schedulePreview()
                    end
                end);connections[#connections+1]=rootVisibility[object] end)
            end
        end
        if scoped and object:IsA("TextLabel")then
            knownLabels[object]=true
            local wasTitle=object.Text:match("'s Avatar$")~=nil
            pcall(function()connections[#connections+1]=object:GetPropertyChangedSignal("Text"):Connect(function()
                local isTitle=object.Text:match("'s Avatar$")~=nil
                if wasTitle or isTitle then maskPreview(false);schedulePreview()
                elseif object.Name:lower()=="itemname" or object.Name:lower()=="itemcardfootertitle" then schedulePreview()end
                wasTitle=isTitle
            end)end)
        end
        if scoped and (object:IsA("ImageLabel") or object:IsA("ImageButton")) then
            connections[#connections+1]=object:GetPropertyChangedSignal("Image"):Connect(schedulePreview)
        end
        return scoped
    end
    if core then
        pcall(function()
            for _,object in ipairs(core:GetDescendants())do watchTitle(object)end
            connections[#connections+1]=core.DescendantAdded:Connect(function(object)
                local scoped=watchTitle(object)
                if scoped and modeEnabled then quarantineUnknownPanels()end
                local name=string.lower(object.Name or "")
                local modernItem= name=="itemcardfootertitle" or name:match("^item%d+$")
                if scoped and (nativeAvatarVisual(object) or (object:IsA("TextLabel") and object.Text:match("'s Avatar$")))then
                    maskPreview(false,true);schedulePreview()
                elseif scoped and modernItem then schedulePreview()end
            end)
        end)
    end
    local api={}
    function api.update(options)
        if not alive then return end
        local enabled=options.enabled==true
        modeEnabled=enabled
        currentSnapshot=options.snapshot
        if enabled and currentSnapshot and task and task.spawn then
            local thumbs={};for _,item in ipairs(currentSnapshot.items or {})do thumbs[#thumbs+1]="rbxthumb://type=Asset&id="..tostring(item.id).."&w=150&h=150"end
            local key=table.concat(thumbs,"|")
            if warmedItems~=key then
                warmedItems=key
                task.spawn(function()pcall(function()game:GetService("ContentProvider"):PreloadAsync(thumbs)end)end)
            end
        end
        -- The browser publishes Roblox's original posed render without a
        -- background. Keep its held-gear pose; the model is only a fallback.
        currentImage=type(options.image)=="string" and options.image~="" and options.image or nil
        if not currentSnapshot then previewData=nil;previewKey=nil end
        local alias=tostring(options.name or "")
        local name=alias~="" and alias or player.Name
        currentName=name
        local label,title=ownTitle(name,true)
        if not enabled then
            if active and label and not options.preserveNative then pcall(function()gui:InspectPlayerFromUserId(player.UserId)end)end
            restoreMasks()
            releaseDescription()
            active=false;lastLabel=nil;lastSignature=nil;adopting=false;lastName=nil;lastMismatchKey=nil;itemStateKey=nil;recoveryPending=false;itemCheckRevision=itemCheckRevision+1
            return
        end
        if not label then maskPreview(false);return end
        maskPreview(false,true)
        if not options.snapshot then status="Waiting for the local outfit.";return end
        local signature=game:GetService("HttpService"):JSONEncode(options.snapshot)..name
        if lastSignature~=signature then lastMismatchKey=nil;itemStateKey=nil;recoveryPending=false;itemCheckRevision=itemCheckRevision+1 end
        if active and lastSignature==signature then
            if title==name.."'s Avatar" then lastLabel=label;adopting=false;maskPreview(true,true);return end
            if adopting then maskPreview(false);return end
        end
        local desc=description(options.snapshot)
        local ok,err=pcall(function()gui:InspectPlayerFromHumanoidDescription(desc,name)end)
        -- Roblox loads preview models and AccessoryDescription children asynchronously.
        -- Keep the source alive until Larp mode stops or a newer inspection replaces it.
        if ok then releaseDescription();activeDescription=desc;active=true;lastLabel=label;lastSignature=signature;adopting=true;lastName=name;status="Native local outfit inspection requested."
        else desc:Destroy();status="Roblox blocked the local avatar inspector: "..tostring(err)end
    end
    function api.report()return status end
    function api.destroy(preserveNative)
        previewData=nil;previewKey=nil;currentImage=nil
        api.update({enabled=false,name="",preserveNative=preserveNative==true})
        alive=false;previewBuild=nil
        for _,connection in ipairs(connections)do connection:Disconnect()end
        connections={}
    end
    return api
end
return M
