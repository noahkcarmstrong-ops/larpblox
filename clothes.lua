-- Map original classic clothing to its local Larp equivalent in native instances.
local Http=game:GetService("HttpService")
local Players=game:GetService("Players")
local properties={Shirt="ShirtTemplate",Pants="PantsTemplate",ShirtGraphic="Graphic"}
local descriptionFields={Shirt="Shirt",Pants="Pants",ShirtGraphic="GraphicTShirt"}
local kinds={"Shirt","Pants","ShirtGraphic"}
local function content(value)
    return tostring(value):match("[?&]id=(%d+)") or tostring(value):match("rbxassetid://(%d+)") or tostring(value)
end
local function parse(value)
    if type(value)=="number" then
        assert(value>0 and value%1==0 and value<9007199254740992,"Enter a positive numeric ID.")
        return value
    end
    local text=tostring(value or ""):match("^%s*(.-)%s*$")
    local id=text:match("^(%d+)$") or text:match("^rbxassetid://(%d+)$")
    if not id then
        local path=text:match("^https?://www%.roblox%.com/(.+)$") or text:match("^https?://roblox%.com/(.+)$")
        if path then
            local catalog,suffix=path:match("^catalog/(%d+)(.*)$")
            if catalog and (suffix=="" or suffix:match("^[/#?]")) then id=catalog end
        end
    end
    local number=tonumber(id)
    assert(number and number>0 and number<9007199254740992,"Paste a Roblox catalog link, rbxassetid, or positive numeric ID.")
    return number
end

local function dispose(roots)
    for _,root in ipairs(roots or {}) do if root then root:Destroy() end end
end

return function(player,onStatus,managedRespawn)
    local gui=player:FindFirstChildOfClass("PlayerGui")
    local attribute="HoneyBunCosmeticClothes"
    local settings={}
    local alive,generation=true,0
    local templates,requests={},{}
    local accountDescription,descriptionPending
    local originals,replacements={},{}
    local active,characters=nil,{}
    local reconcile,schedule
    if gui then
        local ok,saved=pcall(function()return Http:JSONDecode(gui:GetAttribute(attribute) or "")end)
        if ok and type(saved)=="table" then
            for _,kind in ipairs(kinds)do
                local id=saved[kind]
                if type(id)=="number" and id>=0 and id%1==0 and id<9007199254740992 then settings[kind]=id end
            end
        end
    end
    local function save()
        if gui then gui:SetAttribute(attribute,Http:JSONEncode(settings))end
    end
    local function context()
        local character=player.Character
        local humanoid=character and character:FindFirstChildOfClass("Humanoid")
        assert(alive and character and humanoid and humanoid.Health>0,"Wait for your avatar to finish spawning.")
        return {character=character,generation=generation}
    end
    local function valid(ctx)
        return alive and generation==ctx.generation and player.Character==ctx.character
    end
    local function check(ctx)
        assert(valid(ctx),"Your avatar changed while loading. Try again on the new character.")
    end
    local function report(message)
        if alive and onStatus then onStatus(message)end
    end
    local function resolveTemplate(ctx,kind,value)
        local property=({Shirt="ShirtTemplate",Pants="PantsTemplate",ShirtGraphic="Graphic"})[kind]
        local id=parse(value);local assetId=string.format("%.0f",id);local key=kind..":"..assetId;local template=templates[key]
        if not template then
            local ok,roots=pcall(function() return game:GetObjects("rbxassetid://"..assetId) end)
            assert(ok and type(roots)=="table" and #roots>0,"Roblox could not load that catalog item. It may be private or unavailable.")
            if not valid(ctx) then dispose(roots);check(ctx) end
            local source
            for _,root in ipairs(roots) do
                if root:IsA(kind) then source=root end
                if not source then for _,item in ipairs(root:GetDescendants()) do if item:IsA(kind) then source=item;break end end end
                if source then break end
            end
            if not source then dispose(roots);error("That catalog item is not a classic "..string.lower(kind)..".") end
            template=source[property]
            if type(template)~="string" or template=="" then dispose(roots);error("That classic "..string.lower(kind).." has no usable template.") end
            game:GetService("ContentProvider"):PreloadAsync({template})
            check(ctx)
            templates[key]=template
            dispose(roots)
        end
        return template,id
    end
    local function accountId(ctx,kind)
        if descriptionPending then descriptionPending.Event:Wait();check(ctx)end
        if not accountDescription then
            local completed=Instance.new("BindableEvent");descriptionPending=completed
            local ok,description=pcall(Players.GetHumanoidDescriptionFromUserIdAsync,Players,player.UserId)
            if ok and description then
                accountDescription={}
                for name,field in pairs(descriptionFields)do accountDescription[name]=description[field]end
                description:Destroy()
            end
            descriptionPending=nil;completed:Fire();task.defer(function()completed:Destroy()end)
            check(ctx)
        end
        return accountDescription and accountDescription[kind]
    end
    local function prepareOriginal(ctx,kind)
        if originals[kind]~=nil then return end
        local id=accountId(ctx,kind)
        assert(id~=nil,"Could not identify your original clothing; existing game clothing was preserved.")
        originals[kind]=id==0 and "" or select(1,resolveTemplate(ctx,kind,id))
    end
    local function write(record,value)
        if record.object[record.property]==value then record.written=value;return end
        record.written=value
        record.object[record.property]=value
    end
    local function forget(view,object,restore)
        local record=view.records[object]
        if not record then return end
        view.records[object]=nil
        for _,connection in ipairs(record.connections)do connection:Disconnect()end
        if record.synthetic then
            object:Destroy()
        elseif restore and object[record.property]==record.written then
            object[record.property]=record.source
        end
    end
    local function track(view,object,synthetic)
        if view.records[object] or not properties[object.ClassName]then return end
        local record={object=object,kind=object.ClassName,property=properties[object.ClassName],synthetic=synthetic,connections={}}
        record.source=synthetic and "" or object[record.property]
        record.written=object[record.property]
        view.records[object]=record
        record.connections[1]=object:GetPropertyChangedSignal(record.property):Connect(function()
            local value=object[record.property]
            if value==record.written then return end
            -- The new external value is the source state, regardless of why it changed.
            record.source=value;record.written=value;record.synthetic=false
            schedule(view,record.kind)
        end)
        record.connections[2]=object.AncestryChanged:Connect(function()
            if object.Parent~=view.character then
                -- Read the latest external value even when removal precedes its property event.
                if object[record.property]~=record.written then record.source=object[record.property]end
                forget(view,object,true);schedule(view,record.kind)
            end
        end)
        schedule(view,record.kind)
    end
    reconcile=function(view,kind)
        if not alive or characters[view.character]~=view then return end
        local expected=originals[kind]
        local replacement=replacements[kind]
        if view.retired then
            if replacement==nil then
                local objects={}
                for object,record in pairs(view.records)do
                    if record.kind==kind then objects[#objects+1]=object end
                end
                for _,object in ipairs(objects)do forget(view,object,true)end
            end
            return
        end
        local hasNative=false
        local synthetic
        for object,record in pairs(view.records)do
            if record.kind==kind and object.Parent==view.character then
                local current=object[record.property]
                if current~=record.written then record.source=current;record.written=current;record.synthetic=false;hasNative=true end
                if record.synthetic then synthetic=object else hasNative=true end
                local mapped=expected~=nil and content(record.source)==content(expected) and replacement~=nil
                write(record,mapped and replacement or record.source)
            end
        end
        -- Absence only maps when the original avatar also had no item in this slot.
        -- Do not fill a game-removed original garment or a retired/ragdoll character.
        local needsSynthetic=view==active and not hasNative and expected=="" and replacement~=nil and replacement~=""
        if synthetic and not needsSynthetic then forget(view,synthetic,false);synthetic=nil end
        if needsSynthetic and not synthetic then
            local object=Instance.new(kind);object.Name="HoneyBun"..kind
            object[properties[kind]]=replacement
            track(view,object,true)
            object.Parent=view.character
        end
    end
    schedule=function(view,kind)
        if not alive or view.pending[kind]then return end
        view.pending[kind]=true
        task.defer(function()
            view.pending[kind]=nil
            local ok,message=pcall(reconcile,view,kind)
            if not ok then report("Could not map clothing: "..tostring(message))end
        end)
    end
    local function closeView(view,restore)
        characters[view.character]=nil
        for _,connection in ipairs(view.connections)do connection:Disconnect()end
        if view.destroying then view.destroying:Disconnect()end
        local objects={};for object in pairs(view.records)do objects[#objects+1]=object end
        for _,object in ipairs(objects)do forget(view,object,restore)end
    end
    local function watch(character)
        if active and active.character==character then return end
        if active then
            -- Freeze the previous body's presentation. Native death effects can
            -- keep changing it without waking the new character's mapping.
            active.retired=true
            for _,connection in ipairs(active.connections)do connection:Disconnect()end
            active.connections={}
            for _,record in pairs(active.records)do
                for _,connection in ipairs(record.connections)do connection:Disconnect()end
                record.connections={}
            end
        end
        local view={character=character,records={},connections={},pending={}}
        active=view;characters[character]=view
        view.connections[1]=character.ChildAdded:Connect(function(object)track(view,object,false)end)
        view.destroying=character.Destroying:Connect(function()closeView(view,false)end)
        for _,object in ipairs(character:GetChildren())do track(view,object,false)end
    end
    local function refresh(kind)
        for _,view in pairs(characters)do reconcile(view,kind)end
    end
    local function equip(kind,value)
        local ctx=context()
        requests[kind]=(requests[kind] or 0)+1;local ticket=requests[kind]
        local template,id=resolveTemplate(ctx,kind,value)
        prepareOriginal(ctx,kind);check(ctx)
        assert(requests[kind]==ticket,"Clothing choice changed while loading.")
        settings[kind]=id;replacements[kind]=template;save();refresh(kind)
        return "Mapped classic "..string.lower(kind).." (visible to you)."
    end
    local function remove(kind)
        local ctx=context()
        requests[kind]=(requests[kind] or 0)+1;local ticket=requests[kind]
        prepareOriginal(ctx,kind);check(ctx)
        assert(requests[kind]==ticket,"Clothing choice changed while loading.")
        settings[kind]=0;replacements[kind]="";save();refresh(kind)
        return "Removed original classic "..string.lower(kind).." locally."
    end
    local function restoreKind(kind,clearSaved)
        requests[kind]=(requests[kind] or 0)+1
        replacements[kind]=nil
        if clearSaved then settings[kind]=nil;save()end
        refresh(kind)
        return "Original "..string.lower(kind).." restored."
    end
    local api={}
    function api.equipTShirt(value)return equip("ShirtGraphic",value)end
    function api.removeTShirt()return remove("ShirtGraphic")end
    function api.restoreTShirt()return restoreKind("ShirtGraphic",true)end
    function api.equipShirt(value)return equip("Shirt",value)end
    function api.equipPants(value)return equip("Pants",value)end
    function api.removeShirt()return remove("Shirt")end
    function api.removePants()return remove("Pants")end
    function api.restoreShirt()return restoreKind("Shirt",true)end
    function api.restorePants()return restoreKind("Pants",true)end
    function api.restore()
        for _,kind in ipairs(kinds)do restoreKind(kind,true)end
        return "Original classic clothes restored."
    end
    function api.getSettings()return {Shirt=settings.Shirt,Pants=settings.Pants,ShirtGraphic=settings.ShirtGraphic}end
    function api.prepareSaved()
        local ctx=context()
        for _,kind in ipairs(kinds)do
            if settings[kind]~=nil then
                prepareOriginal(ctx,kind)
                if settings[kind]~=0 then resolveTemplate(ctx,kind,settings[kind])end
            end
        end
    end
    function api.reapplySaved()
        local failures={}
        for _,kind in ipairs(kinds)do
            if settings[kind]~=nil then
                local ok,message=pcall(function()
                    if settings[kind]==0 then remove(kind)else equip(kind,settings[kind])end
                end)
                if not ok then failures[#failures+1]=tostring(message)end
            end
        end
        if #failures>0 then error("Could not reapply saved clothes: "..table.concat(failures,"; "))end
        return "Reapplied saved classic clothes."
    end
    local readyConnection
    local function stopReady()
        if readyConnection then readyConnection:Disconnect();readyConnection=nil end
    end
    local changed=player.CharacterAdded:Connect(function(character)
        generation=generation+1;stopReady();watch(character)
        if managedRespawn then return end
        local function ready()
            local humanoid=character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health<=0 then return end
            stopReady()
            task.defer(function()
                if alive and player.Character==character then
                    local ok,message=pcall(api.reapplySaved)
                    if not ok then report(message)end
                end
            end)
        end
        readyConnection=character.ChildAdded:Connect(ready);ready()
    end)
    if player.Character then watch(player.Character)end
    function api.corpseOriginalClothes()
        local result={}
        for _,kind in ipairs(kinds)do
            local count=0
            if active then for object,record in pairs(active.records)do
                if record.kind==kind and not record.synthetic and object.Parent==active.character and record.source~="" then count=count+1 end
            end end
            result[kind]=count
        end
        return result
    end
    function api.destroy()
        if not alive then return end
        alive=false;generation=generation+1;changed:Disconnect();stopReady()
        local views={};for _,view in pairs(characters)do views[#views+1]=view end
        for _,view in ipairs(views)do closeView(view,true)end
    end
    return api
end
