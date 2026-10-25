-- Local presentation only. Identity comes from real players, never UI paths.
local function trim(value) return tostring(value or ""):match("^%s*(.-)%s*$") end
local function pattern(value) return value:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") end
local function escape(value) return value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;") end
local function plain(value, rich)
    if not rich then return value end
    return value:gsub("<[^>]*>", ""):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&amp;", "&")
end
local controllers, identities, usernames, displays = {}, {}, {}, {}
-- One pass-through hook survives interface reloads. Only explicitly mapped
-- Player objects are keys; never intercept Instance names or child lookups.
local nameReads
if type(getgenv)=="function" then
    nameReads=rawget(getgenv(),"__LarpbloxNameReads")
end
local function originalName(player,key)
    if nameReads then return nameReads.original(player,key) end
    return player[key]
end
local function bindNameReads()
    if nameReads then return true end
    if type(hookmetamethod)~="function" or type(getgenv)~="function" then return false end
    local state={targets=setmetatable({}, {__mode="k"})}
    local original
    local function intercept(object,key)
        if key=="Name" or key=="DisplayName" then
            local mapped=state.targets[object]
            if mapped then
                local value=mapped[key]
                if value and value~="" then return value end
            end
        end
        return original(object,key)
    end
    -- Executor scripts also consume these values (for example ESP labels), so
    -- checkcaller must not bypass this mapping. Internal identity uses original.
    local ok,previous=pcall(hookmetamethod,game,"__index",type(newcclosure)=="function" and newcclosure(intercept) or intercept)
    if not ok or type(previous)~="function" then return false end
    original=previous
    state.original=previous
    getgenv().__LarpbloxNameReads=state
    nameReads=state
    return true
end
local chatAliases={}
local entries = setmetatable({}, {__mode="k"})
local buckets, rootConnections, rosterConnections = {}, {}, {}
local coreGui, players
local chatService
local chatBindings={}
local chatStatus="Chat names are unavailable."
local verifiedGlyph=utf8.char(0xE000)
local function badgePrefix(prefix,controller)
    if not controller or not controller.verified or not controller.settings.enabled or prefix:find(verifiedGlyph,1,true)then return prefix end
    local inTag,lastColon=false,nil
    for index=1,#prefix do
        local char=prefix:sub(index,index)
        if char=="<"then inTag=true elseif char==">"then inTag=false
        elseif char==":" and not inTag then lastColon=index end
    end
    if not lastColon then return prefix end
    return prefix:sub(1,lastColon-1)..verifiedGlyph..prefix:sub(lastColon)
end
pcall(function() coreGui=game:GetService("CoreGui") end)
pcall(function() players=game:GetService("Players") end)

local function addName(index, name, id)
    if index[name] == nil then index[name]=id elseif index[name] ~= id then index[name]=false end
end
local function rememberChatName(id,name,field)
    if not name or name=="" then return end
    chatAliases[id]=chatAliases[id] or {}
    chatAliases[id][name]=field
    -- A UI may cache a mocked read. Retain its alias as an identity so changing
    -- or disabling Larp can also restore labels created while mapping was on.
    addName(field=="username" and usernames or displays,name,id)
end
local function rebuildIdentities(leavingId)
    usernames, displays = {}, {}
    local roster = {}
    if players then pcall(function() roster=players:GetPlayers() end) end
    for _, player in ipairs(roster) do
        if player.UserId~=leavingId and not identities[player.UserId] then
            identities[player.UserId]={username=originalName(player,"Name"), display=originalName(player,"DisplayName")}
        end
    end
    local present={}
    for _, player in ipairs(roster) do if player.UserId~=leavingId then present[player.UserId]=true end end
    for id, identity in pairs(identities) do
        if present[id] or controllers[id] then
            addName(usernames, identity.username, id)
            addName(displays, identity.display, id)
            rememberChatName(id,identity.display,"displayName")
            rememberChatName(id,identity.username,"username")
        else identities[id]=nil end
    end
    for id,aliases in pairs(chatAliases) do
        if present[id] or controllers[id] then
            for name,field in pairs(aliases) do addName(field=="username" and usernames or displays,name,id) end
        end
    end
end
local function chatSpan(entry)
    if not entry.source:find(":",1,true) then return end
    -- Roblox keys native message records by sender ID and message GUID. Use
    -- that identity without depending on any chat window path or game layout.
    local ancestor=entry.object
    local senderId,inCore
    while ancestor do
        if ancestor==coreGui then inCore=true end
        local id=tostring(ancestor.Name):match("^(%d+)%-%{%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x%}$")
        if id then senderId=tonumber(id) end
        ancestor=ancestor.Parent
    end
    if not inCore or not senderId or not identities[senderId] then return end
    local rich=entry.object.RichText==true
    local text=plain(entry.source,rich)
    local offset=1
    -- Role/channel tags precede the sender; they are not part of the name.
    while true do
        local finish=text:sub(offset):match("^%s*%b[]%s*()")
        if not finish then break end
        offset=offset+finish-1
    end
    local leading=text:sub(1,offset-1)
    for name,field in pairs(chatAliases[senderId] or {}) do
        if text:sub(offset,offset+#name)==name..":" then
            local encoded=rich and escape(name) or name
            local cursor=1
            while true do
                local first,last=entry.source:find(encoded..":",cursor,true)
                if not first then break end
                if plain(entry.source:sub(1,first-1),rich)==leading then
                    return senderId,{first=first,last=last-1,field=field}
                end
                cursor=last+1
            end
        end
    end
end
local function resolve(entry)
    local sender,span=chatSpan(entry)
    entry.chatSpan=span
    if sender then return sender end
    local text=plain(entry.source,entry.object.RichText==true):gsub(" %(You%)$", "")
    local semanticField
    local ancestor=entry.object
    while ancestor do
        local objectName=tostring(ancestor.Name or "")
        if objectName=="Username" then semanticField="username";break end
        if objectName=="DisplayName" then semanticField="displayName";break end
        ancestor=ancestor.Parent
    end
    entry.semanticField=semanticField
    -- Fallback for cached/server-supplied identity text. Fresh client UI should
    -- consume the mapped Player properties; do not parse composite stat labels.
    local name=text:match("^@(.+)$") or text:match("^(.-)'s%s") or text
    local ranked=text:match("^#%d+%s*%-%s*(.+)$")
    if ranked and semanticField then name=ranked end
    local id
    if semanticField=="username" then id=usernames[name]
    elseif semanticField=="displayName" then id=displays[name]
    else id=usernames[name];if id==nil then id=displays[name] end end
    if id==nil then return nil end
    -- Explicit conflicting identity wins over coincidentally matching text.
    ancestor=entry.object
    local explicitId
    while ancestor do
        local ok, ignored=pcall(function() return ancestor:GetAttribute("LarpbloxIgnoreNameOverride") end)
        if ok and ignored then return nil end
        for _, key in ipairs({"UserId","UserID","PlayerId","playerId"}) do
            local success,value=pcall(function() return ancestor:GetAttribute(key) end)
            local found=success and tonumber(value)
            if found then
                if explicitId and explicitId~=found then return nil end
                explicitId=found
            end
        end
        ancestor=ancestor.Parent
    end
    if explicitId then
        local identity=identities[explicitId]
        if identity and (name==identity.username or name==identity.display or
            (chatAliases[explicitId] and chatAliases[explicitId][name])) then return explicitId end
        return nil
    end
    return id or nil
end
local notificationEntries=setmetatable({}, {__mode="k"})
local notificationHook
local notificationSources=setmetatable({}, {__mode="k"})
local function isSystemChat(object)
    local ancestor=object
    local system=false
    while ancestor do
        if ancestor==coreGui then return system end
        -- Native TextChat records identify system messages with sender ID 0.
        if tostring(ancestor.Name or ""):match("^0%-%{%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x%}$")then system=true end
        ancestor=ancestor.Parent
    end
    return false
end
local function isNotification(object)
    local ancestor=object.Parent
    for _=1,12 do
        if not ancestor or ancestor==coreGui then break end
        local name=ancestor.Name:lower()
        if name:find("notification",1,true) or name:find("toast",1,true) then
            return coreGui and object:IsDescendantOf(coreGui)
        end
        ancestor=ancestor.Parent
    end
    return false
end
local function notificationText(source,rich)
    local names={}
    for id,controller in pairs(controllers) do
        local identity=identities[id]
        if identity then
            local settings=controller.settings
            local username=settings.enabled and settings.username~="" and settings.username or identity.username
            local display=settings.enabled and settings.displayName~="" and settings.displayName or identity.display
            local items={{identity.username,username,usernames},{identity.display,display,displays}}
            for name,field in pairs(chatAliases[id] or {}) do
                items[#items+1]={name,field=="username" and username or display,field=="username" and usernames or displays}
            end
            for _,item in ipairs(items) do
                if item[1]~="" and item[2]~="" and item[3][item[1]]==id then
                    names[item[1]]=rich and escape(item[2]) or item[2]
                end
            end
        end
    end
    local function segment(text)
        local matches={}
        for name,value in pairs(names) do
            local cursor=1
            while true do
                local first,last=text:find("%f[%w_]"..pattern(name).."%f[^%w_]",cursor)
                if not first then break end
                matches[#matches+1]={first,last,value};cursor=last+1
            end
        end
        table.sort(matches,function(a,b) return a[1]<b[1] or (a[1]==b[1] and a[2]>b[2]) end)
        local out,cursor={},1
        for _,match in ipairs(matches) do
            if match[1]>=cursor then out[#out+1]=text:sub(cursor,match[1]-1);out[#out+1]=match[3];cursor=match[2]+1 end
        end
        out[#out+1]=text:sub(cursor);return table.concat(out)
    end
    if not rich then return segment(source) end
    local out,cursor={},1
    while true do
        local first,last=source:find("<[^>]*>",cursor)
        if not first then out[#out+1]=segment(source:sub(cursor));break end
        out[#out+1]=segment(source:sub(cursor,first-1));out[#out+1]=source:sub(first,last);cursor=last+1
    end
    return table.concat(out)
end
local function bindNotifications()
    if notificationHook or type(hookmetamethod)~="function" or type(getgenv)~="function" then return end
    local environment=getgenv()
    local state=rawget(environment,"__LarpbloxNotificationInterceptor")
    if not state then
        state={}
        local original
        local function intercept(object,key,value)
            if key=="Text" and type(value)=="string" and state.transform then
                local ok,result=pcall(state.transform,object,value)
                if ok then value=result end
            end
            return original(object,key,value)
        end
        local ok,previous=pcall(hookmetamethod,game,"__newindex",type(newcclosure)=="function" and newcclosure(intercept) or intercept)
        if not ok or type(previous)~="function" then return end
        original=previous
        environment.__LarpbloxNotificationInterceptor=state
    end
    local transform=function(object,value)
        if not isNotification(object) then return value end
        local entry=entries[object]
        -- Retain original text for alias changes and disable/restore.
        if entry and value~=entry.written then entry.source=value
        elseif not entry then notificationSources[object]=value end
        local updated=notificationText(value,object.RichText)
        if entry then entry.written=updated end
        return updated
    end
    state.transform=transform
    notificationHook={state=state,transform=transform}
end
local function replacement(entry, controller)
    if isNotification(entry.object) or isSystemChat(entry.object) then return notificationText(entry.source,entry.object.RichText) end
    if entry.chatSpan then
        local span=entry.chatSpan
        local identity=identities[entry.id]
        if not identity then return entry.source end
        local value=span.field=="username" and identity.username or identity.display
        if controller and controller.settings.enabled then
            local configured=controller.settings[span.field]
            if configured and configured~="" then value=configured end
        end
        if entry.object.RichText then value=escape(value) end
        if controller and controller.verified and controller.settings.enabled then value=value..verifiedGlyph end
        return entry.source:sub(1,span.first-1)..value..entry.source:sub(span.last+1)
    end
    if not controller then return entry.source end
    local identity=identities[controller.id]
    local settings=controller.settings
    local username=settings.enabled and settings.username~="" and settings.username or identity.username
    local display=settings.enabled and settings.displayName~="" and settings.displayName or identity.display
    if entry.object.RichText then username,display=escape(username),escape(display) end
    -- Rewrite text segments only, preserving markup and its attributes.
    local function segment(text)
        -- One substitution pass prevents aliases from being substituted again.
        local matches={}
        local replacements=entry.semanticField=="username" and {{identity.username,username}}
            or entry.semanticField=="displayName" and {{identity.display,display}}
            or {{identity.username,username},{identity.display,display}}
        for name,field in pairs(chatAliases[controller.id] or {}) do
            local index=field=="username" and usernames or displays
            if index[name]==controller.id and (not entry.semanticField or entry.semanticField==field)
                and name~=identity.username and name~=identity.display then
                replacements[#replacements+1]={name,field=="username" and username or display}
            end
        end
        for _,pair in ipairs(replacements) do
            local cursor=1
            while true do
                local first,last=text:find("%f[%w_]"..pattern(pair[1]).."%f[^%w_]",cursor)
                if not first then break end
                matches[#matches+1]={first,last,pair[2]};cursor=last+1
            end
        end
        table.sort(matches,function(a,b) return a[1]<b[1] or (a[1]==b[1] and a[2]>b[2]) end)
        local out,cursor={},1
        for _,match in ipairs(matches) do
            if match[1]>=cursor then out[#out+1]=text:sub(cursor,match[1]-1);out[#out+1]=match[3];cursor=match[2]+1 end
        end
        out[#out+1]=text:sub(cursor);return table.concat(out)
    end
    if not entry.object.RichText then return segment(entry.source) end
    local out,cursor={},1
    while true do
        local first,last=entry.source:find("<[^>]*>",cursor)
        if not first then out[#out+1]=segment(entry.source:sub(cursor));break end
        out[#out+1]=segment(entry.source:sub(cursor,first-1));out[#out+1]=entry.source:sub(first,last);cursor=last+1
    end
    return table.concat(out)
end
local function readCallback(service,member)
    if type(getcallbackvalue)=="function" then
        return pcall(getcallbackvalue,service,member)
    end
    return pcall(function() return service[member] end)
end
local function interceptCallback(callback,transform)
    if type(hookfunction)~="function" or type(getgenv)~="function" then return end
    local environment=getgenv()
    local registry=rawget(environment,"__LarpbloxChatInterceptors")
    if type(registry)~="table" or registry.version~=1 then
        registry={version=1,entries=setmetatable({}, {__mode="k"})}
        environment.__LarpbloxChatInterceptors=registry
    end
    local state=registry.entries[callback]
    if not state then
        state={}
        local original
        local installed,trampoline=pcall(hookfunction,callback,function(message)
            local properties=original(message)
            local handler=state.transform
            if handler then return handler(properties,message) end
            return properties
        end)
        if not installed or type(trampoline)~="function" then return end
        original=trampoline
        registry.entries[callback]=state
    end
    state.transform=transform
    return state
end
local function bindChat()
    if next(chatBindings) then return end
    local ok, service=pcall(function() return game:GetService("TextChatService") end)
    if not ok or not service then return end
    local config=service:FindFirstChildOfClass("ChatWindowConfiguration")
    for _,member in ipairs({"OnIncomingMessage","OnChatWindowAdded"}) do
        local member=member
        local readable,previous=readCallback(service,member)
        -- Preserve the game's callback and its filtering/status/formatting.
        if readable and (previous==nil or type(previous)=="function") and (member~="OnChatWindowAdded" or config) then
            local transform=function(properties,message)
                if not message then return properties end
                local source=message.TextSource
                if not source then
                    local text=properties and properties.Text
                    if not text or text=="" then text=message.Text end
                    if type(text)~="string" then return properties end
                    local value=notificationText(text,true)
                    if value==text then return properties end
                    if not properties then
                        properties=member=="OnIncomingMessage" and Instance.new("TextChatMessageProperties") or config:DeriveNewMessageProperties()
                    end
                    properties.Text=value
                    return properties
                end
                local controller=source and controllers[source.UserId]
                if not controller or not controller.settings.enabled then return properties end
                local prefix=properties and properties.PrefixText
                if not prefix or prefix=="" then prefix=message.PrefixText end
                if type(prefix)~="string" or prefix=="" then return properties end
                local value=badgePrefix(replacement({source=prefix,object={RichText=true}},controller),controller)
                if value==prefix then return properties end
                if not properties then
                    properties=member=="OnIncomingMessage" and Instance.new("TextChatMessageProperties") or config:DeriveNewMessageProperties()
                end
                properties.PrefixText=value
                return properties
            end
            -- Only our formatting is optional. Never let it prevent Roblox or
            -- the game's existing callback from displaying a chat message.
            local function safeTransform(properties,message)
                local ok,result=pcall(transform,properties,message)
                if ok then return result end
                return properties
            end
            local state=previous and interceptCallback(previous,safeTransform)
            if state then
                chatBindings[member]={state=state,transform=safeTransform}
            else
                local hook=function(message)
                    return safeTransform(previous and previous(message) or nil,message)
                end
                if pcall(function() service[member]=hook end) then
                    chatBindings[member]={previous=previous,hook=hook}
                end
            end
        end
    end
    chatService=service
    if next(chatBindings) then chatStatus="Chat sender names use Larp names." end
end
local function unbindChat()
    for member,binding in pairs(chatBindings) do
        if binding.state then
            -- Keep one pass-through executor hook per callback across refreshes;
            -- dropping our handler releases this session without stacking hooks
            -- or undoing hooks another script may have installed afterwards.
            if binding.state.transform==binding.transform then binding.state.transform=nil end
        else
            local readable,current=readCallback(chatService,member)
            if readable and current==binding.hook then
                pcall(function() chatService[member]=binding.previous end)
            end
        end
    end
    chatService=nil;chatBindings={}
    chatStatus="Chat names are unavailable."
end
local function render(entry)
    local value=replacement(entry,controllers[entry.id])
    if entry.object.Text==value then return end
    entry.written=value
    pcall(function() entry.object.Text=value end)
end
local function bind(entry)
    notificationEntries[entry]=(isNotification(entry.object) or isSystemChat(entry.object)) or nil
    if entry.id and buckets[entry.id] then buckets[entry.id][entry]=nil end
    entry.id=resolve(entry)
    if entry.id then
        buckets[entry.id]=buckets[entry.id] or setmetatable({}, {__mode="k"})
        buckets[entry.id][entry]=true
    end
    render(entry)
end
local function unwatch(object)
    local entry=entries[object]
    if not entry then return end
    if entry.id and buckets[entry.id] then buckets[entry.id][entry]=nil end
    for _,connection in ipairs(entry.connections) do connection:Disconnect() end
    notificationEntries[entry]=nil
    entries[object]=nil
end
local function watch(object)
    if entries[object] or not (object:IsA("TextLabel") or object:IsA("TextButton")) then return end
    local entry={object=object,source=notificationSources[object] or object.Text,connections={}}
    notificationSources[object]=nil
    entries[object]=entry
    entry.connections[#entry.connections+1]=object:GetPropertyChangedSignal("Text"):Connect(function()
        if object.Text==entry.written then return end
        entry.written=nil;entry.source=object.Text;bind(entry)
    end)
    entry.connections[#entry.connections+1]=object:GetPropertyChangedSignal("RichText"):Connect(function() bind(entry) end)
    bind(entry)
end
local function watchRoot(root)
    if not root or rootConnections[root] then return end
    local ok, descendants=pcall(function() return root:GetDescendants() end)
    if not ok then return end
    local connections={}
    rootConnections[root]=connections
    connections[#connections+1]=root.DescendantAdded:Connect(watch)
    connections[#connections+1]=root.DescendantRemoving:Connect(unwatch)
    for _,object in ipairs(descendants) do watch(object) end
end
local function refreshRoster(leavingId)
    rebuildIdentities(leavingId)
    for _,entry in pairs(entries) do bind(entry) end
end

return function(player, playerGui, gameObject)
    local id=player.UserId
    assert(not controllers[id],"Name presentation already exists for this player")
    local knownIdentity=identities[id]~=nil
    local controller={id=id,verified=false,settings={enabled=false,username="",displayName=""}}
    controllers[id]=controller
    identities[id]=identities[id] or {username=originalName(player,"Name"),display=originalName(player,"DisplayName") or originalName(player,"Name")}
    local originalDisplay=identities[id].display
    local mappedNames={}
    controller.mappedNames=mappedNames
    local readsAvailable=bindNameReads()
    rebuildIdentities()
    bindChat()
    bindNotifications()
    if not knownIdentity then
        -- Only a new identity can change existing labels' resolution.
        for _,entry in pairs(entries) do bind(entry) end
    end
    if #rosterConnections==0 and players then
        rosterConnections[#rosterConnections+1]=players.PlayerAdded:Connect(function() refreshRoster() end)
        rosterConnections[#rosterConnections+1]=players.PlayerRemoving:Connect(function(leaving)
            identities[leaving.UserId]=nil
            -- PlayerRemoving fires before GetPlayers drops the player.
            local identity=controllers[leaving.UserId]
            if identity then
                identity.settings.enabled=false
                if nameReads and nameReads.targets[leaving]==identity.mappedNames then nameReads.targets[leaving]=nil end
            end
            refreshRoster(leaving.UserId)
        end)
    end
    watchRoot(coreGui);watchRoot(playerGui);watchRoot(gameObject);watchRoot(game.Workspace)
    local humanoids={}
    local characterConnections={}
    local verified=false
    local function applyHumanoid(character)
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        if humanoids[humanoid]==nil then humanoids[humanoid]=humanoid.DisplayName end
        local settings=controller.settings
        pcall(function()
            local display=settings.enabled and (settings.displayName~="" and settings.displayName or originalDisplay) or humanoids[humanoid]
            -- Roblox's native verified glyph (DefaultChatMessage.lua); let the
            -- engine place it beside the overhead name, never over the viewer.
            if verified and players and player~=players.LocalPlayer then display=display..utf8.char(0xE000) end
            if humanoid.DisplayName~=display then humanoid.DisplayName=display end
        end)
    end
    local function watchCharacter(character)
        local previous=characterConnections
        for _,connection in ipairs(previous) do pcall(function() connection:Disconnect() end) end
        characterConnections={}
        if not character or not (controller.settings.enabled or verified) then return end
        local function apply()
            if player.Character==character then applyHumanoid(character) end
        end
        -- CharacterAdded can fire before Roblox has inserted its Humanoid.
        -- Retry when it appears, and reapply if the game overwrites the name.
        pcall(function()
            characterConnections[#characterConnections+1]=character.ChildAdded:Connect(function(child)
                if child:IsA("Humanoid") then
                    apply()
                    pcall(function()
                        characterConnections[#characterConnections+1]=child:GetPropertyChangedSignal("DisplayName"):Connect(apply)
                    end)
                end
            end)
        end)
        local humanoid=character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            apply()
            pcall(function()
                characterConnections[#characterConnections+1]=humanoid:GetPropertyChangedSignal("DisplayName"):Connect(apply)
            end)
        end
    end
    local characterConnection=player.CharacterAdded:Connect(watchCharacter)
    watchCharacter(player.Character)
    local function refresh()
        local settings=controller.settings
        if readsAvailable then
            mappedNames.Name=settings.username
            mappedNames.DisplayName=settings.displayName
            if settings.enabled then nameReads.targets[player]=mappedNames
            elseif nameReads.targets[player]==mappedNames then nameReads.targets[player]=nil end
        end
        for entry in pairs(buckets[id] or {}) do render(entry) end
        for entry in pairs(notificationEntries) do render(entry) end
        applyHumanoid(player.Character)
    end
    local api={}
    function api.setVerified(value)
        verified=value==true
        controller.verified=verified
        watchCharacter(player.Character)
        refresh()
    end
    function api.set(username,displayName)
        username,displayName=trim(username),trim(displayName)
        assert(username=="" or (#username>=3 and #username<=20 and username:match("^[A-Za-z0-9_]+$")),"Username must be 3-20 ASCII letters, numbers, or underscores.")
        assert(#displayName<=50 and not displayName:find("[%c]"),"Display name must be 1-50 characters without control characters.")
        rememberChatName(id,username,"username");rememberChatName(id,displayName,"displayName")
        controller.settings={enabled=true,username=username,displayName=displayName};watchCharacter(player.Character);refresh();return api.report()
    end
    function api.setEnabled(value) controller.settings.enabled=value==true;watchCharacter(player.Character);refresh();return api.report() end
    function api.getSettings() local s=controller.settings;return {enabled=s.enabled,username=s.username,displayName=s.displayName} end
    function api.restore()
        verified=false
        controller.verified=false
        for _,connection in ipairs(characterConnections) do pcall(function() connection:Disconnect() end) end
        characterConnections={}
        controller.settings={enabled=false,username="",displayName=""};refresh();return "Original names restored locally."
    end
    function api.report()
        return "Names are local only. "..(controller.settings.enabled and
            ((readsAvailable and "Player name reads mapped locally. " or "Name read hook unavailable; UI fallback only. ")..chatStatus)
            or "Override disabled.")
    end
    function api.destroy()
        if controllers[id]~=controller then return end
        api.restore();characterConnection:Disconnect();controllers[id]=nil
        for _,connection in ipairs(characterConnections) do pcall(function() connection:Disconnect() end) end
        characterConnections={}
        for humanoid,original in pairs(humanoids) do pcall(function() humanoid.DisplayName=original end) end
        if next(controllers)==nil then
            unbindChat()
            if notificationHook and notificationHook.state.transform==notificationHook.transform then notificationHook.state.transform=nil end
            notificationHook=nil
            for object in pairs(entries) do unwatch(object) end
            for _,connections in pairs(rootConnections) do for _,connection in ipairs(connections) do connection:Disconnect() end end
            for _,connection in ipairs(rosterConnections) do connection:Disconnect() end
            rootConnections,rosterConnections,buckets,identities,chatAliases={},{},{},{},{}
        end
    end
    return api
end
