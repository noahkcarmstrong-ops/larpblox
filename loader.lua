-- Larpblox: standalone cosmetic menu.
local launchOptions = ...
if type(launchOptions) ~= "table" then launchOptions = {} end
local sourceBranch = launchOptions.branch or "main"
local startupComplete=false
local diagnostics
local function trace(stage)
    if diagnostics and not stage:match("^Loading module:") and not stage:match("^Loaded module:")
        and not stage:match("^Avatar: Restoring ") then diagnostics.log("status",{detail=stage})end
    if not startupComplete and type(launchOptions.trace)=="function" then launchOptions.trace(stage)end
end
local function resolveRevision()
    if launchOptions.readSource then return "local" end
    if launchOptions.revision then return launchOptions.revision end
    local http = game:GetService("HttpService")
    local stamp = tostring(DateTime.now().UnixTimestampMillis)
    local revision = http:JSONDecode(game:HttpGet(
        "https://api.github.com/repos/noahkcarmstrong-ops/larpblox/commits/" .. http:UrlEncode(sourceBranch) .. "?refresh=" .. stamp, false))
    local sha = revision and revision.sha
    assert(type(sha) == "string" and #sha == 40 and sha:match("^%x+$"), "Could not find the selected Larpblox branch.")
    return sha
end
local function readSource(file, revision)
    trace("Loading module: "..file)
    local source
    if launchOptions.readSource then source=launchOptions.readSource(file)
    else source=game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/larpblox/" .. revision .. "/" .. file, false)end
    trace("Loaded module: "..file)
    return source
end
trace("Waiting for client player")
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
assert(RunService:IsClient(), "Run Larpblox from the Roblox client.")
local localPlayer = Players.LocalPlayer
while not localPlayer do
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    localPlayer = Players.LocalPlayer
end
-- Classic Roblox chrome: blue title bar, pale panels, bordered controls.
local theme={blue=Color3.fromRGB(0,112,192),blueHover=Color3.fromRGB(0,133,220),
    paper=Color3.fromRGB(240,242,245),ink=Color3.fromRGB(42,48,56),muted=Color3.fromRGB(91,100,110),
    button=Color3.fromRGB(224,229,235),hover=Color3.fromRGB(207,224,240),edge=Color3.fromRGB(166,178,190)}
local TweenService
pcall(function() TweenService=game:GetService("TweenService") end)
local tweens=setmetatable({},{__mode="k"})
local function smooth(object,properties,duration,done)
    local previous=tweens[object]
    if previous then previous:Cancel();tweens[object]=nil end
    if not TweenService then
        for key,value in pairs(properties) do object[key]=value end
        if done then done() end
        return
    end
    local tween=TweenService:Create(object,TweenInfo.new(duration or 0.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties)
    tweens[object]=tween
    tween.Completed:Connect(function(state)
        if tweens[object]~=tween then return end
        tweens[object]=nil
        if done and state==Enum.PlaybackState.Completed then done() end
    end)
    tween:Play()
end
local isMM2 = game.GameId == 66654135 or game.PlaceId == 142823291
local moduleRuntime={}
local accessoryRuntime={}
local mm2Enabled=false
local mm2EmotesShown=false
local playerGui = localPlayer:WaitForChild("PlayerGui")
local loadGeneration=(playerGui:GetAttribute("LarpbloxLoadGeneration") or 0)+1
playerGui:SetAttribute("LarpbloxLoadGeneration",loadGeneration)
trace("Loading Prism controls")
local moduleRevision = resolveRevision()
local diagnosticOk,diagnosticResult=pcall(function()
    local factory,err=loadstring(readSource("diagnostics.lua",moduleRevision));assert(factory,err)
    return factory()({revision=moduleRevision,playerId=localPlayer.UserId,placeId=game.PlaceId})
end)
if diagnosticOk then diagnostics=diagnosticResult end
local function logDiagnostic(event,fields,checkpoint)
    if diagnostics then
        diagnostics.log(event,fields)
        if checkpoint and diagnostics.flush then diagnostics.flush()end
    end
end
local prismChunk, prismError = loadstring(readSource("prism.lua", moduleRevision))
assert(prismChunk, prismError)
local prismRuntime = prismChunk()(function(file) return readSource(file, moduleRevision) end)
local uiChunk,uiError=loadstring(readSource("ui.lua",moduleRevision))
assert(uiChunk,uiError)
local previousMenus={}
for _,old in ipairs(playerGui:GetChildren()) do
    if old.Name=="HoneyBunCosmeticHub" then
        for _,key in ipairs({"HoneyBunCosmeticGuns","HoneyBunCosmeticEffects"}) do
            local value=old:GetAttribute(key)
            if value and not playerGui:GetAttribute(key) then playerGui:SetAttribute(key,value) end
        end
        previousMenus[#previousMenus+1]=old
    end
end

local persistence,view
trace("Restoring saved settings")
local persistenceNotice="Auto-save: session only. Saved-settings support could not load."
pcall(function()
    local sha=moduleRevision
    local source=readSource("storage.lua", sha)
    local chunk,message=loadstring(source);assert(chunk,message)
    persistence=chunk()(playerGui,Players.LocalPlayer.UserId,function(message)
        if view then view.setPersistence(message) end
    end)
end)

if playerGui:GetAttribute("LarpbloxLoadGeneration")~=loadGeneration then
    if persistence then persistence.destroy() end
    return
end
local gui = Instance.new("ScreenGui")
trace("Building menu")
gui.Name = "HoneyBunCosmeticHubPending"
gui:SetAttribute("LarpbloxIgnoreNameOverride", true)
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui
gui:SetAttribute("LarpbloxRevision",moduleRevision)

local panel = Instance.new("CanvasGroup")
panel.Visible=false
panel.GroupTransparency=0
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -24, 0.5, 0)
panel.Size = UDim2.new(1, -48, 0.9, 0)
panel.BackgroundColor3 = theme.paper
panel.BorderSizePixel = 0
panel.Parent = gui
local limits = Instance.new("UISizeConstraint", panel)
limits.MaxSize = Vector2.new(600, 880)
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 3)
-- Draw the edge inside the fading canvas, not on its clipped outer boundary.
local outline=Instance.new("Frame",panel)
outline.Name="MenuOutline";outline.BackgroundTransparency=1;outline.BorderSizePixel=0
outline.Position=UDim2.fromOffset(1,1);outline.Size=UDim2.new(1,-2,1,-2)
outline.ZIndex=10;outline.Active=false
Instance.new("UICorner",outline).CornerRadius=UDim.new(0,2)
local border = Instance.new("UIStroke", outline)
border.Thickness=1
border.Color = Color3.fromRGB(55,80,105)
local header=Instance.new("Frame",panel)
header.Name="ClassicTitleBar";header.Size=UDim2.new(1,0,0,56)
header.BackgroundColor3=theme.blue;header.BorderSizePixel=0
local headerGradient=Instance.new("UIGradient",header)
headerGradient.Color=ColorSequence.new(Color3.fromRGB(0,132,215),Color3.fromRGB(0,91,164))
headerGradient.Rotation=90
local panelScale=Instance.new("UIScale",panel);panelScale.Scale=1

local function text(parent, value, position, size, fontSize, shade)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = position
    label.Size = size
    label.Font = Enum.Font.SourceSans
    label.Text = value
    label.TextSize = fontSize
    label.TextColor3 = theme.ink
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local brandFallback = text(panel, "LARPBLOX", UDim2.fromOffset(18, 8), UDim2.new(1, -120, 0, 40), 28, 240)
brandFallback.Font = Enum.Font.SourceSansBold
brandFallback.TextColor3=Color3.fromRGB(255,255,255)
local customAsset = getcustomasset or getsynasset
if type(customAsset)=="function" and type(writefile)=="function" and moduleRevision then
    task.spawn(function()
        pcall(function()
            local file = "Larpblox-logo.png"
            local bytes = readSource("assets/larpblox-logo.png", moduleRevision)
            assert(bytes:sub(1,8)=="\137PNG\13\10\26\10", "Invalid logo image")
            writefile(file, bytes)
            local logo = Instance.new("ImageLabel")
            logo.Name = "LarpbloxLogo"
            logo.BackgroundTransparency = 1
            logo.Position = UDim2.fromOffset(18, 8)
            logo.Size = UDim2.fromOffset(220, 40)
            logo.ScaleType = Enum.ScaleType.Fit
            logo.Image = customAsset(file)
            logo.Parent = panel
            brandFallback.Visible = false
        end)
    end)
end

local hide = Instance.new("Frame")
hide.Name="HideHost"
hide.Position = UDim2.new(1, -46, 0, 12)
hide.Size = UDim2.fromOffset(32, 32)
hide.BackgroundTransparency = 1
hide.BorderSizePixel = 0
hide.Parent = panel

local line = Instance.new("Frame", panel)
line.Position = UDim2.fromOffset(18, 56)
line.Size = UDim2.new(1, -36, 0, 1)
line.BackgroundColor3 = theme.edge
line.BorderSizePixel = 0
local tabs = Instance.new("ScrollingFrame")
tabs.Name = "Tabs"
tabs.Position = UDim2.fromOffset(18, 66)
tabs.Size = UDim2.new(1, -36, 0, 36)
tabs.BackgroundTransparency = 1
tabs.BorderSizePixel=0;tabs.ScrollBarThickness=2
tabs.CanvasSize=UDim2.fromOffset(0,0);tabs.AutomaticCanvasSize=Enum.AutomaticSize.X
tabs.ScrollingDirection=Enum.ScrollingDirection.X
tabs.Parent = panel
local tabLayout = Instance.new("UIListLayout", tabs)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
local content = Instance.new("ScrollingFrame")
content.Name = "CosmeticsPage"
content.Position = UDim2.fromOffset(18, 112)
content.Size = UDim2.new(1, -36, 1, -154)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 2
content.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 90)
content.CanvasSize = UDim2.fromOffset(0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.Parent = panel
local connectionPill=Instance.new("Frame",panel)
connectionPill.Name="DesktopConnectionStatus"
connectionPill.AnchorPoint=Vector2.new(1,1)
connectionPill.Position=UDim2.new(1,-18,1,-8)
connectionPill.Size=UDim2.fromOffset(154,26)
connectionPill.BorderSizePixel=0
Instance.new("UICorner",connectionPill).CornerRadius=UDim.new(1,0)
local connectionBorder=Instance.new("UIStroke",connectionPill)
connectionBorder.Thickness=1
local connectionDot=Instance.new("Frame",connectionPill)
connectionDot.Position=UDim2.fromOffset(11,9)
connectionDot.Size=UDim2.fromOffset(8,8)
connectionDot.BorderSizePixel=0
Instance.new("UICorner",connectionDot).CornerRadius=UDim.new(1,0)
local connectionStatus=text(connectionPill,"",UDim2.fromOffset(26,0),UDim2.new(1,-34,1,0),14)
connectionStatus.Font=Enum.Font.SourceSansSemibold
local function setConnectionStatus(connected)
    local foreground,background,edge
    if connected==true then
        connectionStatus.Text="Desktop connected"
        foreground=Color3.fromRGB(31,112,83)
        background=Color3.fromRGB(227,241,234)
        edge=Color3.fromRGB(185,216,199)
    elseif connected==false then
        connectionStatus.Text="Desktop disconnected"
        foreground=Color3.fromRGB(156,57,57)
        background=Color3.fromRGB(249,233,233)
        edge=Color3.fromRGB(230,194,194)
    else
        connectionStatus.Text="Desktop connecting"
        foreground=theme.muted
        background=Color3.fromRGB(232,237,242)
        edge=Color3.fromRGB(206,215,225)
    end
    connectionPill.Size=UDim2.fromOffset(connected==false and 174 or 154,26)
    connectionStatus.TextColor3=foreground
    connectionDot.BackgroundColor3=foreground
    connectionPill.BackgroundColor3=background
    connectionBorder.Color=edge
end
setConnectionStatus(nil)
local layout = Instance.new("UIListLayout", content)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 6)
local avatarAPI,motionAPI,animationAPI,clothesAPI,previewsAPI,gameBrowserSyncAPI,sharedLarpAPI
local avatarFactory,animationFactory,clothesFactory,nameFactory
local avatarAssetReader
local previewFactory,portraitFactory,inspectionRouter
local corpseAPI
local fetchSharedProfiles
local refreshing = false
local function refreshMenu()
    if refreshing then return end
    refreshing = true
    view.setRefreshLabel("Refreshing...")
    local ok, message = pcall(function()
        launchOptions.revision = nil
        launchOptions.readSource = nil
        local sha = resolveRevision()
        local source = readSource("loader.lua", sha)
        local chunk, compileError = loadstring(source)
        assert(chunk, compileError)
        chunk({branch=sourceBranch, revision=sha})
    end)
    if not ok then
        warn("Larpblox: refresh failed", message)
        if gui.Parent then
            view.setRefreshLabel("Retry refresh")
        end
    end
    refreshing = false
end

local menuVisible=true
local function showMenu(visible)
    menuVisible=visible
    if visible then
        panel.Visible=true
        smooth(panelScale,{Scale=1},0.32)
        smooth(panel,{GroupTransparency=0,Position=UDim2.new(1,-24,0.5,0)},0.32)
    else
        smooth(panelScale,{Scale=0.975},0.24)
        smooth(panel,{GroupTransparency=1,Position=UDim2.new(1,-12,0.5,0)},0.24,function() if not menuVisible then panel.Visible=false end end)
    end
end
local function uiSetting(key,default)
    local value=playerGui:GetAttribute("HoneyBunCosmeticUI_"..key)
    return type(value)==type(default) and value or default
end
local hideOnStart=uiSetting("hideOnStart",false)
local noPlayerCollisions=uiSetting("noPlayerCollisions",false)
local openingKey=Enum.KeyCode.RightShift
local savedOpeningKey=uiSetting("openingKey","RightShift")
for _,key in ipairs(Enum.KeyCode:GetEnumItems())do
    if key.Name==savedOpeningKey and key~=Enum.KeyCode.Unknown and key~=Enum.KeyCode.Escape then openingKey=key;break end
end
local capturingOpeningKey=false
local function openingKeyLabel()
    return (openingKey.Name:gsub("(%l)(%u)","%1 %2"))
end
local copyPlayerInput=uiSetting("copyPlayer","")
mm2EmotesShown=uiSetting("mm2EmotesShown",false)
local knifeSide=uiSetting("mm2KnifeSide",false)
local crosshairImage=uiSetting("mm2Crosshair","")
local crosshairSize=uiSetting("mm2CrosshairSize",40)
if crosshairSize~=crosshairSize or crosshairSize<8 or crosshairSize>200 then crosshairSize=40 end
local crosshairInput=crosshairImage
local alive, busy, activePage = true, false, uiSetting("page","Animations")
if activePage=="Atmosphere"then activePage="Lighting"end
local animationSection=activePage=="Emotes" and "Emotes" or "Animations"
local backgroundId=uiSetting("backgroundId",-1)
local backgroundChoices
local savedBackgrounds=uiSetting("backgrounds","")
if savedBackgrounds~="" then
    local ok,value=pcall(function()return game:GetService("HttpService"):JSONDecode(savedBackgrounds)end)
    if ok and type(value)=="table" then backgroundChoices=value end
end
local previewType="walk"
local previewRevision=0
local customAnimationType
local animationPreviewFactory
local actionRunning=false
local statusText = "Local avatar editor. Saved selections reapply automatically."
local render,lastRenderedPage
local renderAnimationPage
local accessoryInput, bundleInput = uiSetting("accessory",""), uiSetting("bundle","")
local function savedSkies()
    local raw=uiSetting("savedSkyboxes","")
    if raw=="" then return {} end
    local entries=game:GetService("HttpService"):JSONDecode(raw)
    assert(type(entries)=="table" and #entries<=30,"Saved atmospheres are invalid.")
    for _,entry in ipairs(entries) do
        assert(type(entry)=="table" and type(entry.name)=="string" and #entry.name<=40
            and type(entry.asset)=="string" and #entry.asset<=512 and type(entry.daylight)=="boolean"
            and (entry.image==nil or type(entry.image)=="string" and #entry.image<=512),"Saved skybox is invalid.")
        if entry.environment~=nil then
            local e=entry.environment
            assert(type(e)=="table" and type(e.time)=="number" and e.time==e.time and e.time>=0 and e.time<=24
                and (e.fog=="Off" or e.fog=="Light" or e.fog=="Thick")
                and (e.color=="Natural" or e.color=="Warm" or e.color=="Cool" or e.color=="Pink"),"Saved atmosphere is invalid.")
        end
    end
    return entries
end
local function storeSkies(entries)
    local raw=game:GetService("HttpService"):JSONEncode(entries)
    assert(#raw<=131072,"Preset library is full. Delete a saved preset first.")
    playerGui:SetAttribute("HoneyBunCosmeticUI_savedSkyboxes",raw)
end
local emoteInput,animationInput=uiSetting("emote",""),uiSetting("animationBundle","")
local shirtInput,pantsInput=uiSetting("shirt",""),uiSetting("pants","")
local bodyPartRegions={"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"}
local bodyPartNames={"Head","Torso","Left arm","Right arm","Left leg","Right leg"}
local bodyPartInputs={}
for _,region in ipairs(bodyPartRegions) do bodyPartInputs[region]=uiSetting("part_"..region,"") end
local bodyPartsOpen=uiSetting("bodyPartsOpen",false)
local emoteSlot=uiSetting("emoteSlot",1)
if emoteSlot<1 or emoteSlot>8 or emoteSlot%1~=0 then emoteSlot=1 end
local rgb = {uiSetting("red","255"),uiSetting("green","204"),uiSetting("blue","153")}
local hexInput = uiSetting("hex","#FFCC99")
local regions = {"All", "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"}
local regionNames = {"Whole body", "Head", "Torso", "Left arm", "Right arm", "Left leg", "Right leg"}
local regionIndex = uiSetting("region",1)
if regionIndex<1 or regionIndex>#regions or regionIndex%1~=0 then regionIndex=1 end
local paletteOpen=uiSetting("palette",false)
local function saveUI()
    local values={page=activePage,accessory=accessoryInput,bundle=bundleInput,red=rgb[1],green=rgb[2],blue=rgb[3],hex=hexInput,region=regionIndex,palette=paletteOpen,emote=emoteInput,animationBundle=animationInput,emoteSlot=emoteSlot,shirt=shirtInput,pants=pantsInput}
    values.hideOnStart=hideOnStart
    values.noPlayerCollisions=noPlayerCollisions
    values.openingKey=openingKey.Name
    values.animationSection=animationSection
    values.backgroundId=backgroundId
    if backgroundChoices then values.backgrounds=game:GetService("HttpService"):JSONEncode(backgroundChoices) end
    values.bodyPartsOpen=bodyPartsOpen
    values.copyPlayer=copyPlayerInput
    values.mm2KnifeSide=knifeSide
    values.mm2Crosshair=crosshairImage
    values.mm2CrosshairSize=crosshairSize
    values.mm2EmotesShown=mm2EmotesShown
    for _,region in ipairs(bodyPartRegions) do values["part_"..region]=bodyPartInputs[region] end
    for key,value in pairs(values) do playerGui:SetAttribute("HoneyBunCosmeticUI_"..key,value) end
end
local connection=Input.InputBegan:Connect(function(input,processed)
    if Input:GetFocusedTextBox() then return end
    if capturingOpeningKey then
        if input.UserInputType~=Enum.UserInputType.Keyboard or input.KeyCode==Enum.KeyCode.Unknown then return end
        capturingOpeningKey=false
        if input.KeyCode~=Enum.KeyCode.Escape then openingKey=input.KeyCode;saveUI() end
        if render then render() end
        return
    end
    if not processed and input.KeyCode==openingKey then showMenu(not menuVisible) end
end)
-- Exact RGB samples from the user's 5-column, 6-row Roblox palette reference.
local robloxColors={
    {90,76,66},{124,92,70},{175,148,131},{204,142,105},{234,184,146},
    {86,66,54},{105,64,40},{188,155,93},{199,172,120},{215,197,154},
    {149,121,119},{163,75,75},{218,134,122},{255,201,201},{255,152,220},
    {116,134,157},{82,124,174},{128,187,220},{177,167,255},{167,94,155},
    {0,143,156},{91,154,76},{124,156,107},{161,196,140},{226,155,64},
    {245,205,48},{248,217,109},{99,95,98},{205,205,205},{248,248,248},
}
local function module(file)
    local chunk,message=loadstring(readSource(file,moduleRevision),"="..file);assert(chunk,message)
    return chunk()
end
function accessoryRuntime.factory(file)
    accessoryRuntime.factories=accessoryRuntime.factories or {}
    if not accessoryRuntime.factories[file]then accessoryRuntime.factories[file]=module(file)end
    return accessoryRuntime.factories[file]
end
function accessoryRuntime.channel()
    if not accessoryRuntime.sharing then
        accessoryRuntime.sharing=module("hat_sharing.lua")({session=game:GetService("HttpService"):GenerateGUID(false),delay=task.delay})
        accessoryRuntime.sharing.attach(accessoryRuntime)
    end
    return accessoryRuntime.sharing
end
function accessoryRuntime.forPeer(player)
    local options={remote=true,viewerGui=playerGui}
    local runtimes,lastSnapshot={},nil
    local scripts={turret={1055299,"teapot_turret.lua"},doombringer={4640898,"doombringer.lua"},
        contest={92719239,"contest_award.lua"},crown={1078202,"black_iron_crown.lua"}}
    local receive=accessoryRuntime.channel().receiver(runtimes,function(event)
        local own=Players.LocalPlayer.Character
        local source=player.Character
        local ownRoot=own and own:FindFirstChild("HumanoidRootPart")
        local sourceRoot=source and source:FindFirstChild("HumanoidRootPart")
        if not ownRoot or not sourceRoot then return false end
        if (ownRoot.Position-sourceRoot.Position).Magnitude>250 then return false end
        -- One budget for all peers; crowded servers cannot multiply particle work.
        local now=os.clock()
        local budget=accessoryRuntime.effectBudget or {at=now,tokens=32}
        accessoryRuntime.effectBudget=budget
        budget.tokens=math.min(32,budget.tokens+(now-budget.at)*24);budget.at=now
        if budget.tokens<1 then return false end
        budget.tokens=budget.tokens-1;return true
    end)
    return {
        update=function(state,snapshot)
            if snapshot and snapshot~=lastSnapshot then
                lastSnapshot=snapshot
                local assets={}
                for _,item in ipairs(snapshot.items)do assets[item.id]=true end
                -- Most peers need no scripted-hat controllers at all.
                for key,entry in pairs(scripts)do
                    if assets[entry[1]]then
                        if not runtimes[key]then runtimes[key]=accessoryRuntime.factory(entry[2])(player,nil,options)end
                    elseif runtimes[key]then runtimes[key].destroy();runtimes[key]=nil end
                end
                local hasSounds=false
                for _,item in ipairs(player.Character and player.Character:GetChildren()or {})do
                    if (item:IsA("Accessory")or item:IsA("Hat"))and item:FindFirstChildWhichIsA("Sound",true)then hasSounds=true;break end
                end
                if hasSounds and not runtimes.sounds then runtimes.sounds=accessoryRuntime.factory("accessory_sounds.lua")(player,playerGui,options)
                elseif not hasSounds and runtimes.sounds then runtimes.sounds.destroy();runtimes.sounds=nil end
            end
            local enabled=state~=nil
            for _,runtime in pairs(runtimes)do runtime.setEnabled(enabled)end
            if enabled then receive(state)else
                if runtimes.contest then runtimes.contest.setHeld(false)end
                if runtimes.doombringer then runtimes.doombringer.setHeld(false)end
            end
        end,
        destroy=function()for _,runtime in pairs(runtimes)do pcall(runtime.destroy)end end,
    }
end
local lightingSchema=module("lighting_schema.lua")
local function playerCollisions()
    if not moduleRuntime.playerCollisionsAPI then moduleRuntime.playerCollisionsAPI=module("player_collisions.lua")(Players,workspace) end
    return moduleRuntime.playerCollisionsAPI
end
local gamePages={}
local pages={"Animations","Emotes","Lighting"}
for _,descriptor in ipairs(module("game_pages.lua"))do
    if descriptor.matches(game)then gamePages[descriptor.id]=descriptor;table.insert(pages,descriptor.label)end
end
local pageComponents={}
local function pageComponent(file)
    if not pageComponents[file]then pageComponents[file]=module(file)(view)end
    return pageComponents[file]
end
table.insert(pages,"Settings")
if not table.find(pages,activePage)then activePage="Animations"end
view=uiChunk()(prismRuntime,theme,gui,content,tabs,hide,{
    save=saveUI,
    hide=function()capturingOpeningKey=false;showMenu(false)end,
    refresh=refreshMenu,
    selectPage=function(page)
        if busy then return end
        capturingOpeningKey=false;activePage=page;saveUI();render()
    end,
})
gui:SetAttribute("LarpbloxUI","Prism")
local children,order,inputRefs={},0,{}
local function append(component,props,nodes)
    order=order+1
    props.layoutOrder=order
    children["Row"..order]=view.e(component,props,nodes)
end
local function caption(value,height,props)
    props=props or {}
    props.text=value;props.height=height or 36
    append(view.Text,props)
end
local function button(value,callback,name)
    append(view.Button,{label=value,name=name,disabled=busy,onPress=function()
        if not busy then callback() end
    end})
end
local function input(placeholder,value,changed,props)
    props=props or {}
    local key=activePage..":"..(order+1)
    local ref=inputRefs[key]
    if not ref then ref=view.React.createRef();inputRefs[key]=ref end
    props.placeholder=placeholder;props.value=value;props.onChange=changed
    props.inputRef=ref;props.disabled=busy
    append(view.Input,props)
    return ref
end
local function api()
    if avatarAPI then return avatarAPI end
    local sha=moduleRevision
    if not sha then
        sha=resolveRevision()
    end
    moduleRevision=sha
    local source=readSource("avatar.lua", sha)
    local chunk,message=loadstring(source);assert(chunk,message)
    local create=chunk();assert(type(create)=="function","Avatar editor failed to load.")
    assert(alive,"Menu was closed.")
    local assetSerial=0
    local assetSession=game:GetService("HttpService"):GenerateGUID(false)
    local function readAssetInner(path)
        local catalog=type(path)=="number"
        assert(catalog and path>0 and path%1==0 and path<9007199254740992 or path=="assets/dominus-azurelight.rbxm","Unsupported avatar asset.")
        local function checkpoint(phase)
            logDiagnostic("avatar_asset_load",{asset=tostring(path),phase=phase},true)
        end
        local function assetCall(operation,callback)
            if diagnostics and diagnostics.run then
                return diagnostics.run(operation,{asset=tostring(path),generation=loadGeneration},callback)
            end
            return callback()
        end
        local function decodeAsset(uri)
            -- On Volt, HTTP after a native catalog decode in the same thread
            -- reproduced a hang. Isolate native decoding; wait for completion
            -- through an event rather than a retry timer or frame listener.
            local completed=Instance.new("BindableEvent")
            local result
            task.defer(function()
                result=table.pack(pcall(function()
                    assert(alive,"Menu was closed before asset decoding.")
                    return assetCall("asset.decode",function()return game:GetObjects(uri)end)
                end))
                completed:Fire()
            end)
            completed.Event:Wait()
            completed:Destroy()
            if not alive then
                if result[1] and type(result[2])=="table" then
                    for _,object in ipairs(result[2])do object:Destroy()end
                end
                error("Menu was closed during asset decoding.")
            end
            if not result[1]then error(result[2],0)end
            return result[2]
        end
        local native=function()
            checkpoint("native_decode")
            local objects=decodeAsset("rbxassetid://"..string.format("%.0f",path))
            checkpoint("ready")
            return objects
        end
        local requestAsset=request or http_request or (syn and syn.request)
        if catalog and (type(requestAsset)~="function" or type(writefile)~="function" or type(customAsset)~="function")then
            return native()
        end
        if not catalog then assert(type(writefile)=="function" and type(customAsset)=="function",
            "This executor cannot load Dominus Azurelight's visual effects locally.") end
        local bytes
        if catalog then
            local localOk,localObjects=pcall(function()
                -- Remote GetObjects blocks rendering on some executors. Download
                -- with the yielding request API, then let Roblox decode locally.
                checkpoint("download")
                local response=assetCall("asset.httpRequest",function()
                    return requestAsset({Url="https://assetdelivery.roblox.com/v1/asset/?id="..string.format("%.0f",path),Method="GET"})
                end)
                logDiagnostic("asset_http_response",{asset=tostring(path),status=response and tonumber(response.StatusCode or response.Status),bytes=response and type(response.Body)=="string" and #response.Body or 0},true)
                assert(alive,"Menu was closed during asset download.")
                assert(response and tonumber(response.StatusCode or response.Status)==200,"Catalog asset download failed.")
                bytes=response.Body
                assert(type(bytes)=="string" and #bytes<=64*1024*1024,"Invalid catalog asset response.")
                assetSerial=assetSerial+1
                local file="larpblox-avatar-asset-"..assetSession.."-"..assetSerial..".rbxm"
                local wrote,writeError=pcall(function()return assetCall("asset.writeFile",function()return writefile(file,bytes)end)end)
                local assetOk,assetUri=false,nil
                local loaded,objects=false,nil
                if wrote then
                    assetOk,assetUri=pcall(function()return assetCall("asset.registerFile",function()return customAsset(file)end)end)
                    if assetOk and assetUri then
                        checkpoint("local_decode")
                        loaded,objects=pcall(function()return decodeAsset(assetUri)end)
                    end
                end
                if type(delfile)=="function"then pcall(delfile,file)end
                assert(wrote and assetOk and assetUri and loaded and type(objects)=="table" and #objects>0,writeError or "Local catalog asset decoding failed.")
                return objects
            end)
            if localOk then checkpoint("ready");return localObjects end
            logDiagnostic("asset_local_load_failed",{asset=tostring(path),error=tostring(localObjects)},true)
            assert(alive,"Menu was closed during asset preparation.")
            return native()
        else
            bytes=readSource(path,sha)
            assert(bytes:sub(1,8)=="<roblox!","Invalid Dominus Azurelight visual asset.")
        end
        assetSerial=assetSerial+1
        local file="larpblox-avatar-asset-"..assetSession.."-"..assetSerial..".rbxm"
        local wrote,writeError=pcall(function()return assetCall("asset.writeFile",function()return writefile(file,bytes)end)end)
        assert(wrote,writeError)
        local assetOk,assetUri=pcall(function()return assetCall("asset.registerFile",function()return customAsset(file)end)end)
        local loaded,objects=false,nil
        if assetOk and assetUri then loaded,objects=pcall(function()return decodeAsset(assetUri)end)end
        if type(delfile)=="function"then pcall(delfile,file)end
        assert(assetOk and assetUri,"This executor could not prepare the avatar asset.")
        assert(loaded and type(objects)=="table" and #objects>0,"This executor could not load the avatar asset.")
        return objects
    end
    local function readAsset(path)
        assert(alive,"Menu was closed before loading asset.")
        if diagnostics and diagnostics.run then
            return diagnostics.run("avatar.readAsset",{asset=tostring(path),generation=loadGeneration},readAssetInner,path)
        end
        return readAssetInner(path)
    end
    avatarAssetReader=readAsset
    local function createAvatar(player,onStatus,assetReader,managedRespawn)
        return create(player,onStatus,assetReader or readAsset,managedRespawn,diagnostics)
    end
    avatarFactory=createAvatar
    avatarAPI=create(Players.LocalPlayer,function(message,working)
        if not alive then return end
        trace("Avatar: "..message)
        busy=working or actionRunning;statusText=message
        if render then render() end
    end,readAsset,true,diagnostics)
    return avatarAPI
end
local function atmosphere()
    if moduleRuntime.atmosphereAPI then return moduleRuntime.atmosphereAPI end
    local source=readSource("atmosphere.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    moduleRuntime.atmosphereAPI=chunk()(game,lightingSchema)
    return moduleRuntime.atmosphereAPI
end
local function motion()
    if motionAPI then return motionAPI end
    api()
    local source=readSource("motion.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    motionAPI=chunk()(Players.LocalPlayer,function(message)
        if not alive then return end
        trace("Emote: "..tostring(message))
        statusText=message
        if view then view.setStatus(message) end
    end,true)
    return motionAPI
end
local function animations()
    if animationAPI then return animationAPI end
    api()
    local source=readSource("animations.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    animationFactory=chunk()
    animationAPI=animationFactory(Players.LocalPlayer,function(message)
        if not alive then return end
        statusText=message
        if view then view.setStatus(message) end
    end,true,avatarAssetReader)
    return animationAPI
end
local function clothes()
    if clothesAPI then return clothesAPI end
    api()
    local source=readSource("clothes.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    clothesFactory=chunk()
    clothesAPI=clothesFactory(Players.LocalPlayer,function(message)
        if not alive then return end
        trace("Clothing: "..message)
        statusText=message
        if view then view.setStatus(message) end
    end,true,avatarAssetReader)
    return clothesAPI
end
local function localNames()
    if moduleRuntime.localNamesAPI then return moduleRuntime.localNamesAPI end
    local source=readSource("local_names.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    nameFactory=chunk()
    moduleRuntime.localNamesAPI=nameFactory(Players.LocalPlayer,playerGui)
    return moduleRuntime.localNamesAPI
end
local gameBrowserSync
local function presentationFactories()
    if not previewFactory then
        local source=readSource("previews.lua", moduleRevision)
        local chunk,message=loadstring(source);assert(chunk,message);previewFactory=chunk()
    end
    if not portraitFactory then
        local source=readSource("native_avatar_views.lua", moduleRevision)
        local chunk,message=loadstring(source);assert(chunk,message);portraitFactory=chunk()
    end
end
local function sharedInspection()
    if inspectionRouter then return inspectionRouter end
    local source=readSource("native_inspection.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message);local inspection=chunk()
    source=readSource("native_inspection_router.lua", moduleRevision)
    chunk,message=loadstring(source);assert(chunk,message)
    inspectionRouter=chunk()(Players.LocalPlayer,inspection.create)
    inspectionRouter.description=inspection.description
    return inspectionRouter
end
local function peerViews(player)
    presentationFactories()
    local preview=previewFactory(player)
    local portraits=portraitFactory.create(player,function()return preview end,sharedInspection().description)
    local inspection=sharedInspection().forPlayer(player,function()return preview end)
    return {
        update=function(options)portraits.update(options);inspection.update(options)end,
        destroy=function()inspection.destroy();portraits.destroy();preview.destroy()end,
    }
end
local function corpseController()
    if corpseAPI then return corpseAPI end
    local factory=module("corpse_appearance.lua")
    corpseAPI=factory(function(userId)
        if userId==Players.LocalPlayer.UserId then
            if not gameBrowserSyncAPI or not gameBrowserSyncAPI.isLarpEnabled() or not avatarAPI then return nil end
            local source=avatarAPI.corpseSource()
            if source then source.originalClothes=clothes().corpseOriginalClothes()end
            return source
        end
        return sharedLarpAPI and sharedLarpAPI.corpseSource(userId) or nil
    end,logDiagnostic,function(userId)
        if userId==Players.LocalPlayer.UserId then return gameBrowserSyncAPI and gameBrowserSyncAPI.isLarpEnabled() end
        return sharedLarpAPI and sharedLarpAPI.hasSharedAppearance(userId)
    end)
    return corpseAPI
end
local function sharedLarp()
    if sharedLarpAPI then return sharedLarpAPI end
    api();clothes();animations();localNames()
    local source=readSource("shared_larp.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    local create=chunk();assert(type(create)=="function","Shared Larp sync failed to load.")
    sharedLarpAPI=create(Players.LocalPlayer,function()return gameBrowserSync().snapshotForSharing()end,function()return localNames().getSettings()end,
        function(player,onStatus)return avatarFactory(player,onStatus,nil,true)end,
        function(player,onStatus)return clothesFactory(player,onStatus,true,avatarAssetReader)end,
        function(player,onStatus)return animationFactory(player,onStatus,true,avatarAssetReader)end,
        function(player,gui)return nameFactory(player,gui)end,
        function()return alive end,function(message)
            if not alive then return end
            statusText=message
            if view then view.setStatus(message) end
            end,{describeSnapshot=sharedInspection().description,onAppearanceApplied=function(userId)corpseController().refresh(tonumber(userId))end,log=logDiagnostic,getImageUrl=function()return gameBrowserSync().sharedImageUrl()end,createViews=peerViews,transport=gameBrowserSync(),
            createHatScripts=accessoryRuntime.forPeer,getHatScripts=function()return accessoryRuntime.channel().snapshot()end,
            validHatScripts=function(value)return accessoryRuntime.channel().valid(value)end,
            onHatScriptsChanged=accessoryRuntime.channel().onChanged,
            fetchProfiles=function(ids)
                if not fetchSharedProfiles then
                    local chunk,message=loadstring(readSource("shared_profiles.lua",moduleRevision));assert(chunk,message)
                    fetchSharedProfiles=chunk()
                end
                return fetchSharedProfiles(ids)
            end})
    return sharedLarpAPI
end
local function previews()
    if previewsAPI then return previewsAPI end
    api()
    presentationFactories()
    assert(alive,"Menu was closed.")
    previewsAPI=previewFactory(Players.LocalPlayer)
    return previewsAPI
end
local function nativeViews()
    if moduleRuntime.nativeViewsAPI then return moduleRuntime.nativeViewsAPI end
    api()
    presentationFactories()
    local portraits=portraitFactory.create(Players.LocalPlayer,function()
        return previews()
    end,sharedInspection().description)
    local inspection=sharedInspection().forPlayer(Players.LocalPlayer,function()
        return previews()
    end)
    moduleRuntime.nativeViewsAPI={}
    function moduleRuntime.nativeViewsAPI.update(options)
        portraits.update(options);inspection.update(options)
    end
    function moduleRuntime.nativeViewsAPI.destroy()
        portraits.destroy();inspection.destroy()
        if inspectionRouter then inspectionRouter.destroy();inspectionRouter=nil end
    end
    return moduleRuntime.nativeViewsAPI
end
gameBrowserSync=function()
    if gameBrowserSyncAPI then return gameBrowserSyncAPI end
    local names=localNames()
    local source=readSource("game_browser_sync.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    local create=chunk();assert(type(create)=="function","Game browser sync failed to load.")
    local lookup
    local function accountAvatar(target)
        if not lookup then
            local factory,reason=loadstring(readSource("avatar_lookup.lua",moduleRevision));assert(factory,reason)
            lookup=factory()(Players)
        end
        return lookup(target,Players.LocalPlayer.UserId)
    end
    gameBrowserSyncAPI=select(1,create(Players.LocalPlayer,function()return api()end,function()return clothes()end,function()return alive end,function(message)
        if alive then trace("Browser: "..message);statusText=message;if view then view.setStatus(message) end end
    end,function()return animations()end,function()return names end,nativeViews,{
        describeSnapshot=function(snapshot)return sharedInspection().description(snapshot)end,
        log=logDiagnostic,
        isReady=function()return startupComplete end,
        lookupAvatar=accountAvatar,
        clientRequest=function(method,params)
            assert(method=="avatar.lookup","Unsupported client request.")
            local target=tonumber(params.targetUserId)
            return {targetUserId=tostring(params.targetUserId),snapshot=accountAvatar(target)}
        end,
        onConnectionState=function(connected)
            if not alive then return end
            setConnectionStatus(connected)
            logDiagnostic("desktop_connection",{connected=connected})
        end,
        getMotion=function()return motion()end,
        getBackgroundState=function()return backgroundId>=0 and backgroundId or nil,backgroundChoices end,
        setBackgroundState=function(id,choices)
            if id~=nil then backgroundId=id end
            if choices~=nil then backgroundChoices=choices end
            saveUI()
        end,
        onChanged=function()
            previewRevision=previewRevision+1
            if alive and not busy then render() end
        end,
        setEnabled=function(enabled)
            if enabled then sharedLarp().setEnabled(true)
            elseif sharedLarpAPI then sharedLarpAPI.setEnabled(false)end
        end,
    }))
    gameBrowserSyncAPI.onSnapshot(function()
        corpseController().refresh()
        if accessoryRuntime.turret then accessoryRuntime.turret.setEnabled(gameBrowserSyncAPI.isLarpEnabled()) end
        if accessoryRuntime.doombringer then accessoryRuntime.doombringer.setEnabled(gameBrowserSyncAPI.isLarpEnabled()) end
        if accessoryRuntime.crown then accessoryRuntime.crown.setEnabled(gameBrowserSyncAPI.isLarpEnabled()) end
        if accessoryRuntime.contest then accessoryRuntime.contest.setEnabled(gameBrowserSyncAPI.isLarpEnabled()) end
    end)
    corpseController().refresh()
    return gameBrowserSyncAPI
end
local function reapplyAll(editor,expectedCharacter)
    assert(not expectedCharacter or Players.LocalPlayer.Character==expectedCharacter,"Your character changed while preparing the avatar.")
    if gameBrowserSyncAPI and gameBrowserSyncAPI.prepareSavedAppearance then
        local warmed,reason=pcall(gameBrowserSyncAPI.prepareSavedAppearance)
        if not warmed then logDiagnostic("local_native_source_failed",{detail=tostring(reason)})end
    end
    local failures={}
    for _,step in ipairs({
        {"avatar",function() if editor.prepareSaved then editor.prepareSaved()end;return editor.reapplySaved() end},
        {"emote wheel",function() return motion().reapplySaved() end},
        {"movement animations",function() local controller=animations();if controller.prepareSaved then controller.prepareSaved()end;return controller.reapplySaved() end},
        {"clothing",function() local controller=clothes();if controller.prepareSaved then controller.prepareSaved()end;return controller.reapplySaved() end},
    }) do
        assert(not expectedCharacter or Players.LocalPlayer.Character==expectedCharacter,"Your character changed while restoring the avatar.")
        trace("Restoring "..step[1])
        local ok,message=pcall(step[2])
        trace("Finished restoring "..step[1]..(ok and "" or ": "..tostring(message)))
        if not ok then failures[#failures+1]=tostring(message):gsub("^.-:%d+:%s*","") end
        if ok and type(message)=="string" and message:find("some could not load",1,true) then failures[#failures+1]=message end
    end
    return #failures==0 and "Saved selections restored." or ("Some saved selections could not load: "..failures[1]),#failures==0
end
local actionFinished=Instance.new("BindableEvent")
local function action(callback,independent)
    if busy or not alive then return end
    actionRunning=true;busy=true
    statusText="Working..."
    if view then view.setStatus(statusText) end
    if render then render() end
    task.spawn(function()
        local ok,message=pcall(function()
            if independent then return callback() end
            return callback(api())
        end)
        actionRunning=false;busy=false
        actionFinished:Fire()
        if not alive then return end
        previewRevision=previewRevision+1
        statusText=ok and (message or "Done.") or ("Could not apply: "..tostring(message):gsub("^.-:%d+:%s*",""))
        render()
    end)
end
local function persistLighting()
    if moduleRuntime.atmosphereAPI then
        local configuration=moduleRuntime.atmosphereAPI.configuration()
        -- Retain legacy presets until the user changes a direct editor control.
        local legacy=moduleRuntime.atmosphereAPI.environment()
        if legacy then configuration={version=1,asset=moduleRuntime.atmosphereAPI.currentAsset()or "",daylight=moduleRuntime.atmosphereAPI.daylightEnabled(),environment=legacy}end
        playerGui:SetAttribute("HoneyBunCosmeticUI_activeAtmosphere",game:GetService("HttpService"):JSONEncode(configuration))
    end
end
local function reapplyAtmosphere()
    local raw=uiSetting("activeAtmosphere","")
    if raw==""then return end
    local saved=game:GetService("HttpService"):JSONDecode(raw)
    assert(type(saved)=="table","Saved lighting is invalid.")
    local active=atmosphere()
    if saved.version==2 then active.loadConfiguration(saved);return end
    assert(saved.version==1 and type(saved.asset)=="string"and #saved.asset<=512 and type(saved.daylight)=="boolean","Saved lighting is invalid.")
    active.setDaylight(saved.daylight)
    if saved.environment then local ok,message=active.applyEnvironment(saved.environment);assert(ok,message)end
    if saved.asset~=""then local ok,message=active.apply(saved.asset);assert(ok,message)end
end
local function hatSounds()
    if accessoryRuntime.sounds then return accessoryRuntime.sounds end
    api()
    local source=readSource("accessory_sounds.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    accessoryRuntime.sounds=chunk()(Players.LocalPlayer,playerGui)
    return accessoryRuntime.sounds
end
local function customCrosshair()
    assert(isMM2,"Custom sheriff crosshairs are available in MM2.")
    if moduleRuntime.crosshairAPI then return moduleRuntime.crosshairAPI end
    local source=readSource("crosshair.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    moduleRuntime.crosshairAPI=chunk()(game)
    moduleRuntime.crosshairAPI.setSize(crosshairSize)
    return moduleRuntime.crosshairAPI
end
local function mm2()
    assert(isMM2,"This menu is only available in MM2.")
    if moduleRuntime.mm2API then return moduleRuntime.mm2API end
    api()
    local librarySource=readSource("gun_library.lua", moduleRevision)
    local libraryChunk,libraryError=loadstring(librarySource);assert(libraryChunk,libraryError)
    moduleRuntime.mm2GunLibraryAPI=libraryChunk()(game,playerGui)
    local source=readSource("mm2.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    assert(alive,"Larpblox was refreshed; the older weapon controller was cancelled.")
    moduleRuntime.mm2API=chunk()(game,nil,moduleRuntime.mm2GunLibraryAPI)
    moduleRuntime.mm2API.setKnifeSide(knifeSide)
    return moduleRuntime.mm2API
end
local function nativeMM2()
    if moduleRuntime.mm2NativeAPI then return moduleRuntime.mm2NativeAPI end
    local catalog=mm2()
    local source=readSource("native_inventory.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    assert(alive,"Larpblox was refreshed; the older weapon controller was cancelled.")
    moduleRuntime.mm2NativeAPI=chunk()(playerGui,catalog,function(message)
        if not alive then return end
        statusText=message
        if view then view.setStatus(message) end
    end)
    return moduleRuntime.mm2NativeAPI
end
local function savedNativeMM2()
    if moduleRuntime.mm2SavedNativeAPI then return moduleRuntime.mm2SavedNativeAPI end
    local backend=mm2()
    local source=readSource("native_inventory.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    assert(alive,"Larpblox was refreshed; the older weapon controller was cancelled.")
    local function openWeaponEditor(entry,mode)
        if not moduleRuntime.mm2WeaponEditorAPI then
            local editorSource=readSource("weapon_editor.lua", moduleRevision)
            local editorChunk,editorError=loadstring(editorSource);assert(editorChunk,editorError)
            moduleRuntime.mm2WeaponEditorAPI=editorChunk()(playerGui,{
                getEditorScene=backend.getWeaponEditorScene,
                setWeaponAdjustment=backend.setSavedWeaponAdjustment
            },function(message)if alive then statusText=message;view.setStatus(message) end end)
        end
        for _,saved in ipairs(backend.savedInventory(entry.kind)) do
            if saved.id==entry.id then entry=saved;break end
        end
        moduleRuntime.mm2WeaponEditorAPI.open(entry,mode)
    end
    local savedCatalog={list=backend.savedInventory,equip=backend.equip,getEquipped=backend.getEquipped,remove=backend.removeSavedWeapon,rename=backend.renameSavedWeapon,openEditor=openWeaponEditor}
    moduleRuntime.mm2SavedNativeAPI=chunk()(playerGui,savedCatalog,function(message)
        if alive then statusText=message;view.setStatus(message) end
    end,"saved")
    return moduleRuntime.mm2SavedNativeAPI
end
local function effectsMM2()
    assert(isMM2,"This menu is only available in MM2.")
    if moduleRuntime.mm2EffectsAPI then return moduleRuntime.mm2EffectsAPI end
    api()
    local source=readSource("mm2_effects.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    local librarySource=readSource("effect_library.lua", moduleRevision)
    local libraryChunk,libraryError=loadstring(librarySource);assert(libraryChunk,libraryError)
    moduleRuntime.mm2EffectsLibraryAPI=libraryChunk()(game,playerGui)
    moduleRuntime.mm2EffectsAPI=chunk()(game,function(message)
        if alive then statusText=message;if view then view.setStatus(message) end end
    end,moduleRuntime.mm2EffectsLibraryAPI)
    return moduleRuntime.mm2EffectsAPI
end
local function nativeEffectsMM2()
    if moduleRuntime.mm2EffectsNativeAPI then return moduleRuntime.mm2EffectsNativeAPI end
    local catalog=effectsMM2()
    local source=readSource("native_inventory.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    moduleRuntime.mm2EffectsNativeAPI=chunk()(playerGui,catalog,function(message)
        if alive then statusText=message;if view then view.setStatus(message) end end
    end,"saved-effects")
    return moduleRuntime.mm2EffectsNativeAPI
end
local function emoteBarMM2()
    if moduleRuntime.mm2EmoteBarAPI then return moduleRuntime.mm2EmoteBarAPI end
    local source=readSource("emote_bar.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    local backend=mm2()
    moduleRuntime.mm2EmoteBarAPI=chunk()(playerGui,{list=backend.list,preview=backend.preview},function(message)
        if alive then statusText=message;if view then view.setStatus(message) end end
    end,game)
    return moduleRuntime.mm2EmoteBarAPI
end
local function nativeEmotesMM2()
    if moduleRuntime.mm2EmotesNativeAPI then return moduleRuntime.mm2EmotesNativeAPI end
    local source=readSource("native_inventory.lua", moduleRevision)
    local chunk,message=loadstring(source);assert(chunk,message)
    local backend=mm2()
    moduleRuntime.mm2EmotesNativeAPI=chunk()(playerGui,{list=backend.list,preview=backend.preview},function(message)
        if alive then statusText=message;if view then view.setStatus(message) end end
    end,"emotes")
    return moduleRuntime.mm2EmotesNativeAPI
end
local function enableMM2Emotes()
    local ok,message=nativeEmotesMM2().enable()
    assert(ok~=false,message)
    local barOk,barMessage=emoteBarMM2().enable()
    assert(barOk~=false,barMessage)
    return barMessage
end
local animationKinds={{"idle","Idle",51},{"walk","Walk",55},{"run","Run",53},{"jump","Jump",52},{"fall","Fall",50},{"climb","Climb",48},{"swim","Swim",54}}
local animationPresets={{id=82,name="Robot"},{id=75,name="Ninja"},{id=83,name="Stylish"}}
local function shortAnimationName(name)
    return tostring(name or "Custom"):gsub(" Animation Package$",""):gsub(" Animation Pack$","")
end
local function updateAnimation(callback,kind)
    action(function()
        local message=callback()
        previewType=kind or previewType;previewRevision=previewRevision+1
        return message
    end)
end
local previewHovered,previewRefresh
local function startAnimationPreview(viewport,onError)
    if not animationPreviewFactory then
        local chunk,message=loadstring(readSource("animation_preview.lua",moduleRevision))
        assert(chunk,message);animationPreviewFactory=chunk()
    end
    local section,kind,slot=activePage,previewType,emoteSlot
    local emoteIds={}
    local cleanup,refresh=animationPreviewFactory(viewport,localPlayer,function()
        if section=="Emotes" and motionAPI and previewHovered then
            local item=motionAPI.getSlots()[previewHovered]
            if item then
                if emoteIds[item.id] then return emoteIds[item.id] end
                local roots=game:GetObjects("rbxassetid://"..item.id)
                local ids={}
                for _,root in ipairs(roots) do
                    local all=root:GetDescendants();table.insert(all,1,root)
                    for _,node in ipairs(all) do if node:IsA("Animation") and node.AnimationId~="" then ids[#ids+1]=node.AnimationId end end
                    root:Destroy()
                end
                emoteIds[item.id]=#ids>0 and ids or {"rbxassetid://"..item.id}
                return emoteIds[item.id]
            end
        end
        if animationAPI then return animationAPI.getPreviewIds(section=="Emotes" and "idle" or kind),section=="Emotes" or kind=="idle" end
        return {}
    end,onError)
    previewRefresh=refresh
    return function()if previewRefresh==refresh then previewRefresh=nil end;cleanup()end
end
renderAnimationPage=function()
    animationSection=activePage
    if animationSection=="Animations" then
        local settings=animationAPI and animationAPI.getSettings() or {}
        local function choose(kind)customAnimationType=kind;render()end
        local function choiceRow(name,label,value,kind,width)
            return view.e(view.Prism.Box,{width=width or UDim.new(1,-8),height=40},{
                Label=view.e(view.Text,{text=label,width=100,height=38,size=16,color=theme.ink}),
                Choose=view.e(view.Button,{name=name,label=value,width=UDim.new(1,-108),height=38,position=UDim2.fromOffset(108,0),disabled=busy,onPress=function()choose(kind)end}),
            })
        end
        append(view.Prism.Box,{width=UDim.new(1,-8),height=40},{
            Bundle=choiceRow("AnimationBundle","Bundle",settings.name and shortAnimationName(settings.name) or settings.assets and #settings.assets>0 and "Custom" or "Current avatar","bundle",UDim.new(1,-86)),
            Restore=view.e(view.Button,{name="RestoreAnimations",label="Restore",width=78,height=38,position=UDim2.new(1,-78,0,0),disabled=busy,onPress=function()updateAnimation(function()return animations().restore()end)end}),
        })
        for _,entry in ipairs(animationKinds)do
            local kind,label,assetType=entry[1],entry[2],entry[3]
            local value="Current avatar"
            for _,item in ipairs(settings.assets or {})do if item.assetType==assetType then value=shortAnimationName(settings.labels and settings.labels[kind]);break end end
            append(view.Prism.Box,{width=UDim.new(1,-8),height=40},{Choice=choiceRow("Animation_"..kind,label,value,kind,UDim.new(1,0))})
        end
        if customAnimationType then
            local kind=customAnimationType
            local title=kind=="bundle" and "Animation bundles" or (kind:sub(1,1):upper()..kind:sub(2).." animations")
            local function changed()
                customAnimationType=nil;previewType=kind=="bundle" and "walk" or kind;previewRevision=previewRevision+1;render()
            end
            append(view.EmotePicker,{title=title,noun=title:lower(),confirmLabel="Apply",linkPlaceholder=kind=="bundle" and "Roblox bundle link or ID" or "Roblox animation link or ID",
                loadEmotes=function(query,page,sort)return animations().searchChoices(kind,query,page,sort)end,
                onAssign=function(_,value)
                    if kind=="bundle" then animations().equipBundle(value)else animations().equipType(kind,value)end
                    changed()
                end,
                onRestore=function()if kind=="bundle"then animations().restore()else animations().restoreType(kind)end;changed()end,
                onClose=function()customAnimationType=nil;render()end,
            })
        end
    else
        local slots=motionAPI and motionAPI.getSlots() or {}
        append(view.EmoteWheel,{slots=slots,selected=emoteSlot,disabled=busy,loadEmotes=function(query,page,sort)return motion().searchEmotes(query,page,sort)end,onHover=function(index)
            previewHovered=index;if previewRefresh then previewRefresh() end
        end,onAssign=function(index,value)
            local message=motion().setEmote(index,value)
            emoteSlot=index;previewRevision=previewRevision+1;saveUI();render()
            return message
        end,onSelect=function(index)
            if busy then return end
            emoteSlot=index;saveUI()
        end})

    end
    local previewHeight=math.max(180,content.AbsoluteSize.Y-(animationSection=="Emotes" and 398 or customAnimationType and 462 or 416))
    append(view.AvatarPreview,{sourceKey=animationSection..":"..previewType..":"..emoteSlot..":"..previewRevision,height=previewHeight,backgroundId=math.max(0,backgroundId),start=startAnimationPreview})
end
local gamePageProps={}
gamePageProps.MM2=function()
        local function updateWeapons()
            if mm2Enabled then nativeMM2().disable();local ok=nativeMM2().enable();if ok==false then mm2Enabled=false end end
            savedNativeMM2().enable();savedNativeMM2().refreshSaved()
        end
        local function refreshEffects()
            nativeEffectsMM2().enable();nativeEffectsMM2().refreshSaved();effectsMM2().collectOriginals()
            return "Saved effects refreshed."
        end
        local function invoke(callback)return function(...)local arguments=table.pack(...);action(function()return callback(table.unpack(arguments,1,arguments.n))end,true)end end
        local saved=moduleRuntime.mm2API and moduleRuntime.mm2API.savedInventory()or {}
        return {
            loadSaved=function()return mm2().savedInventory()end,
            busy=busy,player=copyPlayerInput,saved=saved,crosshair=crosshairImage,crosshairSize=crosshairSize,knifeSide=knifeSide,allWeapons=mm2Enabled,emotes=mm2EmotesShown,persist=saveUI,
            capture=invoke(function(username,kinds)
                assert(type(username)=="string"and username~="","Choose a player.")
                copyPlayerInput=username;saveUI()
                local messages={}
                for _,kind in ipairs({"Gun","Knife","Effect"})do
                    if kinds[kind]then
                        local ok,message=pcall(function()
                            if kind~="Effect"then local result=mm2().collectPlayerWeapon(username,kind);updateWeapons();return result end
                            effectsMM2();local result,ids=moduleRuntime.mm2EffectsLibraryAPI.capturePlayer(username);moduleRuntime.mm2EffectsAPI.reloadLibrary()
                            if ids and ids[1]then result=result.." "..mm2EffectsAPI.equip(ids[1],"Effect")end
                            nativeEffectsMM2().enable();nativeEffectsMM2().refreshSaved();return result
                        end)
                        messages[#messages+1]=ok and message or tostring(message):gsub("^.-:%d+:%s*","")
                    end
                end
                return table.concat(messages,"\n")
            end),
            equip=invoke(function(entry)return mm2().equip(entry.id,entry.kind)end),
            rename=invoke(function(entry,name)local result=mm2().renameSavedWeapon(entry.id,name);updateWeapons();return result end),
            remove=invoke(function(entry)local result=mm2().removeSavedWeapon(entry.id);updateWeapons();return result end),
            applyCrosshair=invoke(function(value)
                crosshairInput=value:match("^%s*(.-)%s*$")
                local id=crosshairInput:match("^(%d+)$") or crosshairInput:match("^rbxassetid://(%d+)$")
                if not id and crosshairInput:match("^https?://[^/]*roblox.com/") then
                    id=crosshairInput:match("[?&]id=(%d+)") or crosshairInput:match("/asset/(%d+)") or crosshairInput:match("/catalog/(%d+)") or crosshairInput:match("/library/(%d+)")
                end
                assert(id and tonumber(id) and tonumber(id)>0,"Enter a Roblox image ID or image link.")
                local info=game:GetService("MarketplaceService"):GetProductInfo(tonumber(id))
                local image="rbxassetid://"..id
                if info.AssetTypeId==13 then
                    local objects=game:GetObjects(image)
                    local ok,texture=pcall(function()
                        for _,root in ipairs(objects) do
                            local items={root}
                            for _,item in ipairs(root:GetDescendants()) do items[#items+1]=item end
                            for _,item in ipairs(items) do
                                if item:IsA("Decal") and item.Texture~="" then
                                    local textureId=item.Texture:match("^rbxassetid://(%d+)$") or item.Texture:match("[?&]id=(%d+)")
                                    if textureId then return "rbxassetid://"..textureId end
                                end
                            end
                        end
                        error("This decal's image could not load. Try its image/texture ID directly.")
                    end)
                    for _,root in ipairs(objects) do root:Destroy() end
                    assert(ok,texture)
                    image=texture
                else
                    assert(info.AssetTypeId==1,"That ID is not an image or decal. Choose a crosshair image or decal.")
                end
                customCrosshair().set(image)
                crosshairImage=image;saveUI()

                return "Crosshair saved."
            end),
            resizeCrosshair=function(value)
                if busy then return false end
                local ok=pcall(function()customCrosshair().setSize(value)end)
                if ok then crosshairSize=value end;return ok
            end,
            resetCrosshair=invoke(function()if moduleRuntime.crosshairAPI then moduleRuntime.crosshairAPI.set("")end;crosshairImage="";saveUI();return "Default crosshair restored."end),
            setKnifeSide=invoke(function(value)local _,message=mm2().setKnifeSide(value);assert(message==nil,message);knifeSide=value;saveUI();return "Knife position updated."end),
            refreshWeapons=invoke(function()updateWeapons();return "Saved weapons refreshed."end),
            restoreWeapons=invoke(function()return mm2().restore()end),
            identify=invoke(function(name,kind)local message=mm2().identifySavedWeapon(name,kind);updateWeapons();return message end),
            toggleEmotes=invoke(function(enabled)
                if enabled then enableMM2Emotes()
                else nativeEmotesMM2().disable();if moduleRuntime.mm2EmoteBarAPI then moduleRuntime.mm2EmoteBarAPI.disable()end;mm2().stopEmote()end
                mm2EmotesShown=enabled;saveUI();return "MM2 emotes updated."
            end),
            toggleWeapons=invoke(function(enabled)
                if enabled then local ok,message=nativeMM2().enable();assert(ok~=false,message or "MM2 inventory could not be detected.")
                else nativeMM2().disable()end
                mm2Enabled=enabled;savedNativeMM2().enable();savedNativeMM2().refreshSaved();saveUI();return "Inventory display updated."
            end),
            refreshEffects=invoke(refreshEffects),
            collectEffects=invoke(function(username)
                effectsMM2();local result=moduleRuntime.mm2EffectsLibraryAPI.captureServer(username);moduleRuntime.mm2EffectsAPI.reloadLibrary();nativeEffectsMM2().enable();nativeEffectsMM2().refreshSaved();return result
            end),
            stopEmote=invoke(function()return mm2().stopEmote()end),
            report=invoke(function()
                local report=mm2().report().."\n"..nativeMM2().report()
                if moduleRuntime.mm2SavedNativeAPI then report=report.."\n"..mm2SavedNativeAPI.report() end
                if moduleRuntime.mm2EffectsAPI then report=report.."\n"..mm2EffectsAPI.report() end
                if moduleRuntime.mm2EffectsLibraryAPI then report=report.."\n"..mm2EffectsLibraryAPI.report() end
                if moduleRuntime.mm2EmotesNativeAPI then report=report.."\n"..mm2EmotesNativeAPI.report() end
                if moduleRuntime.mm2EmoteBarAPI then report=report.."\n"..mm2EmoteBarAPI.report() end
                if moduleRuntime.mm2EffectsNativeAPI then report=report.."\n"..mm2EffectsNativeAPI.report() end
                if type(setclipboard)=="function" then
                    setclipboard(report)
                    return "MM2 report copied. Paste it into chat if a preview cannot load."
                end
                return report

            end),
        }
end
render=function()
    if not alive then return end
    local savedScroll=(activePage=="Lighting"or gamePages[activePage]~=nil) and lastRenderedPage==activePage and content.CanvasPosition
    local pageChanged=lastRenderedPage~=activePage
    lastRenderedPage=activePage
    if pageChanged then
        content.Position=UDim2.fromOffset(18,112)
        smooth(content,{Position=UDim2.fromOffset(18,112)},0.18)
    end
    children={}
    if not savedScroll then content.CanvasPosition=Vector2.new(0,0) end
    order=0
    limits.MaxSize=Vector2.new(600,880)
    view.setStatus(statusText)
    view.setPersistence(persistence and persistence.status() or persistenceNotice)
    if statusText:lower():find("could not",1,true) or statusText:lower():find("failed",1,true) then
        append(view.StatusNotice,{message=statusText})
    end
    if activePage=="Settings" then
        caption("Preview",28,{size=18,color=theme.ink})
        local backgrounds={{value="0",label="None"}}
        for _,item in ipairs(backgroundChoices or {})do backgrounds[#backgrounds+1]={value=tostring(item.id),label=item.name}end
        append(view.SelectRow,{name="CollectedBackground",label="Background",options=backgrounds,value=tostring(math.max(0,backgroundId)),disabled=busy,onChange=function(value)
            backgroundId=tonumber(value) or 0;saveUI();render()
        end})
        caption("General",28,{size=18,color=theme.ink})
        append(view.KeybindRow,{name="OpeningKey",label="Open / close menu",value=openingKeyLabel(),capturing=capturingOpeningKey,disabled=busy,onPress=function()
            capturingOpeningKey=not capturingOpeningKey;render()
        end})
        button("Hide on start: "..(hideOnStart and "On" or "Off"),function()hideOnStart=not hideOnStart;saveUI();render()end,"HideOnStart")
        button("No player collisions: "..(noPlayerCollisions and "On" or "Off"),function()
            action(function()
                local enabled=not noPlayerCollisions
                playerCollisions().setEnabled(enabled)
                noPlayerCollisions=enabled;saveUI()
                return enabled and "Player collisions disabled locally." or "Normal player collisions restored."
            end)
        end,"NoPlayerCollisions")
        button("Reload interface",refreshMenu)
        button("Reapply cosmetics",function()action(reapplyAll)end)
        caption("Emotes",28,{size=18,color=theme.ink})
        append(view.Button,{name="EmoteWhileWalking",label="Emote while walking: "..((motionAPI and motionAPI.getEmoteWhileWalking()) and "On" or "Off"),height=32,disabled=busy,onPress=function()
            action(function()
                local enabled=motion().setEmoteWhileWalking(not motion().getEmoteWhileWalking())
                return "Emote while walking "..(enabled and "enabled." or "disabled.")
            end)
        end})
        append(view.Button,{name="EmoteWhileJumping",label="Emote while jumping: "..((motionAPI and motionAPI.getEmoteWhileJumping()) and "On" or "Off"),height=32,disabled=busy,onPress=function()
            action(function()
                local enabled=motion().setEmoteWhileJumping(not motion().getEmoteWhileJumping())
                return "Emote while jumping "..(enabled and "enabled." or "disabled.")
            end)
        end})
        append(view.Button,{name="IsolateEmote",label="Only animate the emote: "..((motionAPI and motionAPI.getIsolateEmote()) and "On" or "Off"),height=32,disabled=busy,onPress=function()
            action(function()
                local enabled=motion().setIsolateEmote(not motion().getIsolateEmote())
                return "Emote animation isolation "..(enabled and "enabled." or "disabled.")
            end)
        end})
    elseif gamePages[activePage]then
        limits.MaxSize=Vector2.new(1050,850)
        local descriptor=gamePages[activePage]
        local props=gamePageProps[descriptor.id]and gamePageProps[descriptor.id]()or {}
        append(pageComponent(descriptor.source),props)
    elseif activePage=="Accessories" then
        caption("ACCESSORIES",24)
        local soundsEnabled=playerGui:GetAttribute("HoneyBunCosmeticUI_HatSounds")~=false
        button(soundsEnabled and "Hat sounds: ON" or "Hat sounds: OFF",function() action(function()
            local sounds=hatSounds();return sounds.setEnabled(not sounds.isEnabled())
        end) end)
        button("Play hat sounds now",function() action(function()return hatSounds().playNow()end)end)
        caption("Original hat audio, heard by you. Witches Brew laughs randomly every 5–15 seconds. Some audio may be restricted by Roblox.",56)
        caption("Wear several hats, masks, or hair items together. Paste links or IDs separated by spaces, commas, or new lines (20 items maximum).",60)
        local field=input("Paste accessory links or IDs here",accessoryInput,function(value) accessoryInput=value end,{multiline=true,height=72})
        button("Add accessories",function()
            if busy then return end
            accessoryInput=field.current.Text
            saveUI()
            local submitted=accessoryInput
            action(function(editor)
                local addedCount,failed,firstError=0,{},nil
                for value in submitted:gmatch("[^%s,;]+") do
                    local ok,message=pcall(editor.equipAccessory,value)
                    if ok then addedCount=addedCount+1
                    else
                        failed[#failed+1]=value
                        firstError=firstError or tostring(message):gsub("^.-:%d+:%s*","")
                    end
                end
                accessoryInput=table.concat(failed,"\n");saveUI()
                if #failed>0 then
                    return string.format("Added %d. %d could not load; left in the box to retry. %s",addedCount,#failed,firstError)
                end
                if addedCount==0 then return "Paste at least one accessory link or ID first." end
                return string.format("Added %d. Your other accessories stay on. Paste more to add another.",addedCount)
            end)
        end)
        local accessories=avatarAPI and avatarAPI.listAccessories and avatarAPI.listAccessories() or {}
        caption(string.format("YOUR ADDED ACCESSORIES (%d / 20)",#accessories),24)
        if #accessories==0 then caption("Nothing added yet. Add an item above to start.",32) end
        if avatarAPI and avatarAPI.listAccessories then
            for index,entry in ipairs(accessories) do
                local key=entry.key
                button(index..". "..entry.name.."  |  Remove",function() action(function(editor) return editor.removeAccessory(key) end) end)
            end
        end
        button("Remove added accessories",function() action(function(editor) return editor.clearAccessories() end) end)
        button("Remove current Roblox accessories",function() action(function(editor) return editor.removeCurrentAccessories() end) end)
        button("Copy accessory report",function() action(function(editor)
            local report=editor.accessoryReport()
            if type(setclipboard)=="function" then setclipboard(report);return "Accessory report copied. Paste it into chat if hats still stay on." end
            return report
        end) end)
        caption("Remove current Roblox accessories hides your original hats and accessories. Restore original appearance brings them back.",48)
    elseif activePage=="Clothes" then
        caption("CLASSIC CLOTHES",24)
        caption("Paste classic 2D shirt and pants catalog links. Equip each separately; your other cosmetics stay on. Layered 3D clothing is not supported.",64)
        caption("SHIRT",22)
        local shirt=input("Classic shirt catalog link or ID",shirtInput,function(value) shirtInput=value end)
        button("Equip shirt",function()
            shirtInput=shirt.current.Text;saveUI()
            action(function() return clothes().equipShirt(shirtInput) end)
        end)
        button("Restore original shirt",function() action(function() return clothes().restoreShirt() end) end)
        caption("PANTS",22)
        local pants=input("Classic pants catalog link or ID",pantsInput,function(value) pantsInput=value end)
        button("Equip pants",function()
            pantsInput=pants.current.Text;saveUI()
            action(function() return clothes().equipPants(pantsInput) end)
        end)
        button("Restore original pants",function() action(function() return clothes().restorePants() end) end)
        caption("Shirts and pants save through resets, Refresh, and rejoining when file auto-save is on.",48)
    elseif activePage=="Skin" then
        caption("SKIN COLOR",24)
        button("Restore original skin",function() action(function(editor) return editor.restoreSkin() end) end)
        button("Apply to: "..regionNames[regionIndex].."  >",function()
            if busy then return end
            regionIndex=regionIndex%#regions+1;saveUI();render()
        end)
        button(paletteOpen and "Roblox colors  v" or "Roblox colors  >",function()
            if busy then return end
            paletteOpen=not paletteOpen;saveUI();render()
        end)
        if paletteOpen then
            for rowIndex=1,6 do
                local shades={}
                for column=1,5 do shades[column]=robloxColors[(rowIndex-1)*5+column] end
                append(view.PaletteRow,{colors=shades,rgb=rgb,disabled=busy,onPick=function(r,g,b)
                    if busy then return end
                    rgb={tostring(r),tostring(g),tostring(b)}
                    hexInput=string.format("#%02X%02X%02X",r,g,b)
                    saveUI()
                    action(function(editor)return editor.setSkin(Color3.fromRGB(r,g,b),regions[regionIndex])end)
                end})
            end
        end
        caption("Custom RGB color (each number from 0 to 255)",30)
        local fields={}
        for index,name in ipairs({"Red", "Green", "Blue"}) do
            local i=index
            caption(name,20)
            fields[i]=input(name.." 0–255",rgb[i],function(value) rgb[i]=value end)
        end
        button("Apply RGB color",function()
            for i,field in ipairs(fields) do rgb[i]=field.current.Text end
            saveUI()
            action(function(editor)
                local channels={}
                for i,value in ipairs(rgb) do
                    local n=tonumber(value)
                    assert(n and n==n and n>=0 and n<=255 and n%1==0,"Enter whole RGB numbers from 0 to 255.")
                    channels[i]=n
                end
                local message=editor.setSkin(Color3.fromRGB(channels[1],channels[2],channels[3]),regions[regionIndex])
                hexInput=string.format("#%02X%02X%02X",channels[1],channels[2],channels[3]);saveUI()
                return message
            end)
        end)
        local hex=input("Hex color, for example #FFCC99",hexInput,function(value) hexInput=value end)
        button("Apply hex color",function()
            hexInput=hex.current.Text
            saveUI()
            action(function(editor)
                local value=hexInput:match("^%s*#?(%x%x%x%x%x%x)%s*$")
                assert(value,"Enter six hex characters, for example #FFCC99.")
                local r,g,b=tonumber(value:sub(1,2),16),tonumber(value:sub(3,4),16),tonumber(value:sub(5,6),16)
                local message=editor.setSkin(Color3.fromRGB(r,g,b),regions[regionIndex])
                rgb={tostring(r),tostring(g),tostring(b)};saveUI()
                return message
            end)
        end)
    elseif activePage=="Animations" or activePage=="Emotes" then
        renderAnimationPage()
    elseif activePage=="Lighting"then
        limits.MaxSize=Vector2.new(1050,850)
        append(pageComponent("lighting_page.lua"),{backend=atmosphere,schema=lightingSchema,saved=savedSkies,store=storeSkies,persist=persistLighting})
    else
        caption("BODY PACKAGES",24)
        caption("Choose a classic body or paste a Roblox bundle link. Packages keep your current avatar rig.",44)
        for _,name in ipairs({"Blocky", "Girl", "Robloxian 2.0"}) do
            local preset=name
            button(preset,function() action(function(editor) return editor.applyBody(preset) end) end)
        end
        local field=input("roblox.com/bundles/123/... or bundle ID",bundleInput,function(value) bundleInput=value end)
        button("Apply body package",function()
            bundleInput=field.current.Text
            saveUI()
            action(function(editor) return editor.applyBody(bundleInput) end)
        end)
        button(bodyPartsOpen and "Custom body parts  v" or "Custom body parts  >",function()
            if busy then return end
            bodyPartsOpen=not bodyPartsOpen;saveUI();render()
        end)
        if bodyPartsOpen then
            caption("Mix different packages on an R15 avatar. Paste a body package link for a region, or use that individual body part's catalog link / asset ID.",64)
            for index,region in ipairs(bodyPartRegions) do
                local part,label=region,bodyPartNames[index]
                caption(string.upper(label),22)
                local partField=input(label.." catalog or bundle link / asset ID",bodyPartInputs[part],function(value) bodyPartInputs[part]=value end)
                button("Equip "..string.lower(label),function()
                    bodyPartInputs[part]=partField.current.Text;saveUI()
                    action(function(editor) return editor.applyBodyPart(part,bodyPartInputs[part]) end)
                end)
            end
            caption("Arms and legs include their matching hand or foot. A new full body package replaces your mixed part selections.",48)
        end
        button("Restore original body",function() action(function(editor) return editor.restoreBody() end) end)
        caption("R6 and R15 use different body parts. Unsupported packages show a message instead of changing your avatar rig.",48)
    end
    append(view.PersistenceError,{})
    view.render(children,{pages=pages,page=activePage,busy=busy})
    if savedScroll then
        local page=activePage
        task.defer(function()if alive and activePage==page then content.CanvasPosition=savedScroll end end)
    end
end
local respawnGeneration=0
local readyConnections={}
local function clearReadiness()
    for _,connection in ipairs(readyConnections)do connection:Disconnect()end
    readyConnections={}
end
local respawn=Players.LocalPlayer.CharacterAdded:Connect(function(character)
    logDiagnostic("local_respawn")
    respawnGeneration=respawnGeneration+1
    local ticket=respawnGeneration
    clearReadiness()
    if not alive then return end
    statusText="Preparing avatar...";render()
    local pending,finished=false,false
    local function ready()
        if pending or finished then return end
        pending=true
        task.defer(function()
            pending=false
            if not alive or ticket~=respawnGeneration or Players.LocalPlayer.Character~=character then return end
            local humanoid=character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health<=0 or not character:FindFirstChild("Head") or busy
                or not Players.LocalPlayer:HasAppearanceLoaded()then return end
            finished=true;clearReadiness()
            action(function()
                local message=reapplyAll(api(),character)
                if alive and Players.LocalPlayer.Character==character and gameBrowserSyncAPI then
                    gameBrowserSyncAPI.resumeAppearance(true)
                end
                return message
            end,true)
        end)
    end
    local function watch(object)
        if object:IsA("Humanoid")then readyConnections[#readyConnections+1]=object.HealthChanged:Connect(ready)end
    end
    readyConnections[#readyConnections+1]=character.DescendantAdded:Connect(function(object)watch(object);ready()end)
    for _,object in ipairs(character:GetDescendants())do watch(object)end
    readyConnections[#readyConnections+1]=Players.LocalPlayer.CharacterAppearanceLoaded:Connect(ready)
    readyConnections[#readyConnections+1]=actionFinished.Event:Connect(ready)
    ready()
end)

gui.Destroying:Connect(function()
    alive=false
    logDiagnostic("interface_destroying",{generation=loadGeneration},true)
    if diagnostics then diagnostics.close()end
    pcall(view.destroy)
    connection:Disconnect()
    for object,tween in pairs(tweens) do tween:Cancel();tweens[object]=nil end
    respawn:Disconnect();clearReadiness();actionFinished:Destroy()
    if moduleRuntime.atmosphereAPI then pcall(moduleRuntime.atmosphereAPI.destroy) end
    if moduleRuntime.mm2EmoteBarAPI then pcall(moduleRuntime.mm2EmoteBarAPI.destroy) end
    if moduleRuntime.mm2EmotesNativeAPI then pcall(moduleRuntime.mm2EmotesNativeAPI.destroy) end
    if moduleRuntime.mm2EffectsNativeAPI then pcall(moduleRuntime.mm2EffectsNativeAPI.destroy) end
    if moduleRuntime.mm2EffectsAPI then pcall(moduleRuntime.mm2EffectsAPI.destroy) end
    if moduleRuntime.mm2EffectsLibraryAPI then pcall(moduleRuntime.mm2EffectsLibraryAPI.destroy) end
    if moduleRuntime.mm2WeaponEditorAPI then pcall(moduleRuntime.mm2WeaponEditorAPI.destroy) end
    if moduleRuntime.mm2SavedNativeAPI then pcall(moduleRuntime.mm2SavedNativeAPI.destroy) end
    if moduleRuntime.mm2NativeAPI then pcall(moduleRuntime.mm2NativeAPI.destroy) end
    if moduleRuntime.mm2API then pcall(moduleRuntime.mm2API.destroy) end
    if moduleRuntime.crosshairAPI then pcall(moduleRuntime.crosshairAPI.destroy) end
    if accessoryRuntime.sounds then pcall(accessoryRuntime.sounds.destroy) end
    if accessoryRuntime.turret then pcall(accessoryRuntime.turret.destroy) end
    if accessoryRuntime.doombringer then pcall(accessoryRuntime.doombringer.destroy) end
    if accessoryRuntime.crown then pcall(accessoryRuntime.crown.destroy) end
    if accessoryRuntime.contest then pcall(accessoryRuntime.contest.destroy) end
    if accessoryRuntime.sharing then pcall(accessoryRuntime.sharing.destroy)end
    if corpseAPI then pcall(corpseAPI.destroy) end
    if sharedLarpAPI then pcall(sharedLarpAPI.destroy) end
    if gameBrowserSyncAPI then pcall(gameBrowserSyncAPI.destroy) end
    if moduleRuntime.nativeViewsAPI then pcall(moduleRuntime.nativeViewsAPI.destroy) end
    if moduleRuntime.localNamesAPI then pcall(moduleRuntime.localNamesAPI.destroy) end
    if moduleRuntime.playerCollisionsAPI then pcall(moduleRuntime.playerCollisionsAPI.destroy) end
    if persistence then pcall(persistence.destroy) end
    if avatarAPI then pcall(avatarAPI.destroy) end
    if motionAPI then pcall(motionAPI.destroy) end
    if animationAPI then pcall(animationAPI.destroy) end
    if clothesAPI then pcall(clothesAPI.destroy) end
    if previewsAPI and previewsAPI.destroy then pcall(previewsAPI.destroy) end
end)
trace("Rendering menu")
local mounted,renderError=pcall(render)
if mounted and (not content:FindFirstChildWhichIsA("GuiObject") or not tabs:FindFirstChildOfClass("TextButton")) then
    mounted=false;renderError="Prism did not finish mounting the menu controls."
end
if not mounted then
    pcall(function()gui:Destroy()end)
    error("Larpblox UI could not mount: "..tostring(renderError),0)
end
trace("Replacing previous menu")
-- Keep this cleanup index-based: the loader's top-level scope is close to
-- Luau's 200-register limit, and a transient loop local here can make the
-- whole chunk fail to compile on current clients.
while #previousMenus>0 do table.remove(previousMenus):Destroy() end
gui.Name="HoneyBunCosmeticHub"
trace("Showing menu")
panelScale.Scale=0.975
panel.GroupTransparency=1
panel.Position=UDim2.new(1,-12,0.5,0)
showMenu(not hideOnStart)
trace("Menu rendered; starting saved cosmetics")
if noPlayerCollisions then
    local ok,message=pcall(function()playerCollisions().setEnabled(true)end)
    if not ok then
        noPlayerCollisions=false;saveUI()
        warn("Larpblox: player collisions could not load: "..tostring(message))
    end
end
-- Connect before asset restoration so peer identity is available immediately.
-- The bridge defers changes to our own body until restoration has completed.
trace("Starting browser connection")
local syncOk,syncError=pcall(gameBrowserSync)
if not syncOk then
    trace("Browser startup error: "..tostring(syncError))
    warn("Larpblox: browser startup failed: "..tostring(syncError))
end
action(function()
    trace("Restoring atmosphere")
    if isMM2 and crosshairImage~="" then pcall(function()customCrosshair().set(crosshairImage)end) end
    local atmosphereLoaded,atmosphereError=pcall(reapplyAtmosphere)
    local editor=api()
    trace("Restoring accessory sounds")
    local soundsLoaded=pcall(hatSounds)
    for _,entry in ipairs({{"turret","teapot_turret.lua","Teapot Turret"},{"doombringer","doombringer.lua","Doombringer"},{"crown","black_iron_crown.lua","Black Iron Crown"},{"contest","contest_award.lua","Contest Winner Award"}})do
        local loaded,err=pcall(function()
            accessoryRuntime[entry[1]]=accessoryRuntime.factory(entry[2])(Players.LocalPlayer,function(message)
                if alive then statusText=message;if view then view.setStatus(message)end end
            end,{emit=accessoryRuntime.channel().emit,changed=accessoryRuntime.channel().changed,viewerGui=playerGui})
            accessoryRuntime[entry[1]].setEnabled(not gameBrowserSyncAPI or gameBrowserSyncAPI.isLarpEnabled())
        end)
        if not loaded then warn("Larpblox: "..entry[3].." could not load: "..tostring(err))end
    end
    trace("Restoring saved cosmetics")
    local restored,message=pcall(reapplyAll,editor)
    if not restored then message="Could not prepare saved avatar: "..tostring(message)end
    if isMM2 and mm2EmotesShown then
        local ok,err=pcall(enableMM2Emotes)
        if not ok then message=message.." Saved MM2 emotes could not load: "..tostring(err) end
    end
    if not atmosphereLoaded then message=message.." Your saved atmosphere could not fully load: "..tostring(atmosphereError) end
    if not soundsLoaded then message=message.." Hat sounds could not load; try their control in Accessories." end
    if isMM2 and playerGui:GetAttribute("HoneyBunCosmeticGuns") then mm2();savedNativeMM2().enable() end
    if isMM2 and playerGui:GetAttribute("HoneyBunCosmeticEffects") then effectsMM2();nativeEffectsMM2().enable() end
    trace("Startup complete")
    startupComplete=true
    if gameBrowserSyncAPI then gameBrowserSyncAPI.resumeAppearance()end
    return message
end,true)
