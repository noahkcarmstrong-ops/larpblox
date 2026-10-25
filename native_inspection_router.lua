-- One native inspector follows the selected player; each source owns its state.
return function(localPlayer,createInspector)
    local core
    pcall(function()core=game:GetService("CoreGui")end)
    local states,connections,watched={},{},{}
    local titleLabels=setmetatable({}, {__mode="k"})
    local active,inspector
    local alive,routing,queued=true,false,false
    local route
    local function scoped(object)
        local current=object
        while current do
            if current.Name:find("InspectAndBuy",1,true) or current.Name=="AvatarInspectMenu" then return true end
            current=current.Parent
        end
        return false
    end
    local function visible(object)
        local current=object.Parent
        while current do
            if current:IsA("GuiObject") and not current.Visible then return false end
            if current:IsA("ScreenGui") and not current.Enabled then return false end
            current=current.Parent
        end
        return true
    end
    local function selected()
        local hasTitle=false
        for object in pairs(titleLabels)do
            if object.Parent and scoped(object) and visible(object) then
                local name=object.Text:match("^(.-)'s Avatar$")
                if name then
                    hasTitle=true
                    local match
                    for _,state in pairs(states)do
                        if state.options.enabled and (name==state.player.Name or (state.options.name~="" and name==state.options.name)) then
                            if match and match~=state then return nil end
                            match=state
                        end
                    end
                    if match then return match end
                end
            end
        end
        if not hasTitle then
            local own=states[localPlayer.UserId]
            if own and own.options.enabled then return own end
        end
    end
    route=function()
        if not alive or routing then return end
        routing=true
        local ok,err=pcall(function()
            local target=selected()
            if target~=active then
                if inspector then inspector.destroy(active and active.options.enabled==true);inspector=nil end
                active=target
                if target then inspector=createInspector(target.player,target.getPreviews) end
            end
            if inspector and active then inspector.update(active.options) end
        end)
        routing=false
        if not ok then error(err)end
    end
    local function schedule()
        if not alive or queued or routing then return end
        queued=true
        local function run()queued=false;if alive then pcall(route)end end
        if task and task.defer then task.defer(run)else run()end
    end
    local function watch(object)
        if watched[object] or not scoped(object) then return end
        watched[object]=true
        if object:IsA("TextLabel") then
            titleLabels[object]=true
            connections[#connections+1]=object:GetPropertyChangedSignal("Text"):Connect(schedule)
        end
        if object:IsA("GuiObject") then
            connections[#connections+1]=object:GetPropertyChangedSignal("Visible"):Connect(schedule)
        end
    end
    if core then pcall(function()
        for _,object in ipairs(core:GetDescendants())do watch(object)end
        connections[#connections+1]=core.DescendantAdded:Connect(function(object)
            if scoped(object)then watch(object);schedule()end
        end)
    end)end
    local api={}
    function api.forPlayer(player,getPreviews)
        local state={player=player,getPreviews=getPreviews,options={enabled=false,name=""}}
        states[player.UserId]=state
        local handle={}
        function handle.update(options)
            if not alive or states[player.UserId]~=state then return end
            local previous=state.options
            state.options=options or {enabled=false,name=""}
            -- An inactive player's outfit/image cannot change which native
            -- inspector is selected. Retain it until selection changes.
            if active==state or previous.enabled~=state.options.enabled
                or previous.name~=state.options.name then route()end
        end
        function handle.report()return active==state and inspector and inspector.report() or "Inspector is waiting."end
        function handle.destroy()
            if states[player.UserId]~=state then return end
            state.options={enabled=false,name=""};states[player.UserId]=nil;route()
        end
        return handle
    end
    function api.destroy()
        alive=false
        if inspector then inspector.destroy();inspector=nil end
        for _,connection in ipairs(connections)do pcall(function()connection:Disconnect()end)end
        states={};connections={};watched={};active=nil
    end
    return api
end
