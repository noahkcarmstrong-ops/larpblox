-- Bounded, cosmetic hat state. No frame-by-frame transforms or executable payloads.
return function(options)
    local clock=options.clock or os.time
    local positionKinds={['doom-satellite']=true,['doom-beam']=true,['doom-vanish']=true,['award-gild']=true}
    local kinds={['turret-fire']=true,['doom-satellite']=true,['doom-beam']=true,['doom-vanish']=true,['doom-stop']=true,['award-burst']=true,['award-gild']=true}
    local function integer(n)return type(n)=='number' and n>0 and n%1==0 and n<9007199254740992 end
    local function position(p)
        if type(p)~='table' or #p~=3 then return false end
        for i=1,3 do if type(p[i])~='number' or p[i]~=p[i] or math.abs(p[i])>1000000 then return false end end
        return true
    end
    local function copyPoint(p)return p and {p[1],p[2],p[3]} or nil end
    local function copyEvent(e)return {id=e.id,kind=e.kind,at=e.at,target=e.target,position=copyPoint(e.position)} end
    local function valid(state)
        if type(state)~='table' or state.version~=1 or type(state.session)~='string' or #state.session~=36
            or not state.session:match('^[%x%-]+$') or (state.held~='' and state.held~='award' and state.held~='doom')
            or type(state.events)~='table' or #state.events>16 or (state.satellite~=nil and not position(state.satellite))then return false end
        local seen={}
        for _,e in ipairs(state.events)do
            if type(e)~='table' or not integer(e.id) or seen[e.id] or not integer(e.at) or not kinds[e.kind] then return false end
            if e.kind=='turret-fire' and (type(e.target)~='string' or not e.target:match('^%d+$') or not integer(tonumber(e.target)))then return false end
            if positionKinds[e.kind] and not position(e.position)then return false end
            seen[e.id]=true
        end
        return true
    end
    local alive,scheduled=true,false
    local events,listeners,sequence,satellite={},{},0,nil
    local runtimes={}
    local function changed()
        if not alive or scheduled then return end
        scheduled=true
        options.delay(0.15,function()
            scheduled=false;if not alive then return end
            for callback in pairs(listeners)do pcall(callback)end
        end)
    end
    local api={valid=valid,changed=changed}
    function api.attach(value)runtimes=value end
    function api.emit(kind,payload)
        if not alive or not kinds[kind]then return end
        payload=payload or {}
        if positionKinds[kind] and not position(payload.position)then return end
        if kind=='turret-fire' and (type(payload.target)~='string' or not integer(tonumber(payload.target)))then return end
        sequence=sequence+1
        local event={id=sequence,kind=kind,at=clock(),position=copyPoint(payload.position),target=payload.target}
        if kind=='doom-satellite'then satellite=copyPoint(payload.position)end
        events[#events+1]=event
        while #events>16 do table.remove(events,1)end
        changed()
    end
    function api.snapshot()
        local now=clock();local recent={}
        for _,e in ipairs(events)do if now-e.at<=10 then recent[#recent+1]=copyEvent(e)end end
        local held=''
        if runtimes.contest and runtimes.contest.isHeld()then held='award'
        elseif runtimes.doombringer and runtimes.doombringer.isHeld()then held='doom'end
        return {version=1,session=options.session,held=held,events=recent,satellite=copyPoint(satellite)}
    end
    function api.onChanged(callback)
        listeners[callback]=true
        return function()listeners[callback]=nil end
    end
    function api.receiver(remote,allow)
        local session,lastId,satelliteKey=nil,0,nil
        local function replay(kind,payload)
            local runtime=kind:match('^turret') and remote.turret or kind:match('^award') and remote.contest or remote.doombringer
            if runtime and runtime.replay then pcall(runtime.replay,kind,payload)end
            if kind=='doom-stop' and remote.turret then pcall(remote.turret.replay,kind,payload)end
        end
        return function(state)
            if not valid(state)then return false end
            if state.session~=session then
                session=state.session;lastId=0;satelliteKey=nil
                replay('doom-stop',{})
                if remote.contest then remote.contest.setHeld(false)end
            end
            if remote.contest then remote.contest.setHeld(state.held=='award')end
            if remote.doombringer then remote.doombringer.setHeld(state.held=='doom')end
            if state.satellite then
                local key=table.concat(state.satellite,':')
                if key~=satelliteKey then replay('doom-satellite',{position=state.satellite});satelliteKey=key end
            end
            local now=clock()
            local ordered={}
            for _,e in ipairs(state.events)do ordered[#ordered+1]=e end
            table.sort(ordered,function(a,b)return a.id<b.id end)
            for _,e in ipairs(ordered)do
                if e.id>lastId then
                    lastId=e.id
                    if e.at<=now+2 and now-e.at<=5 and (e.kind=='doom-stop' or not allow or allow(e))then
                        replay(e.kind,copyEvent(e))
                    end
                end
            end
            return true
        end
    end
    function api.destroy()alive=false;listeners={};events={};runtimes={}end
    return api
end
