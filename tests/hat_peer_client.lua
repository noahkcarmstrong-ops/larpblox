-- Detached Roblox fixture: runs the loader's actual peer adapter and global budget.
return function(loaderSource,busFactory)
    local first=assert(loaderSource:find('function accessoryRuntime.forPeer(player)',1,true))
    local last=assert(loaderSource:find('local lightingSchema=',first,true))
    local own,other=Instance.new('Model'),Instance.new('Model')
    for _,model in ipairs({own,other})do
        local root=Instance.new('Part');root.Name='HumanoidRootPart';root.Parent=model
    end
    local created,played,destroyed=0,0,0
    local channel=busFactory({session='12345678-1234-1234-1234-123456789abc',clock=function()return 1000 end,delay=function()end})
    local runtime={channel=function()return channel end,factory=function()
        return function()
            created=created+1
            return {setEnabled=function()end,setHeld=function()end,
                replay=function(kind)if kind=='turret-fire'then played=played+1 end end,
                destroy=function()destroyed=destroyed+1 end}
        end
    end}
    local environment=setmetatable({accessoryRuntime=runtime,Players={LocalPlayer={Character=own}},playerGui={},os={clock=function()return 100 end}},{__index=getfenv()})
    local chunk=assert(loadstring(loaderSource:sub(first,last-1)));setfenv(chunk,environment);chunk()
    local peer={Character=other}
    local state=channel.snapshot()
    local empty=runtime.forPeer(peer)
    empty.update(state,{items={}})
    assert(created==0,'peers without a scripted hat must allocate no controllers')
    empty.destroy()
    for i=1,16 do channel.emit('turret-fire',{target='3'})end
    state=channel.snapshot()
    local adapters={}
    local started=os.clock()
    for i=1,100 do
        local adapter=runtime.forPeer(peer);adapters[#adapters+1]=adapter
        adapter.update(state,{items={{id=1055299}}})
    end
    assert(created==100,'each peer creates only its worn hat controller')
    assert(played==32,'100 simultaneous peers share one 32-effect burst budget')
    for _,adapter in ipairs(adapters)do adapter.update(state)end
    assert(played==32 and created==100,'duplicate events allocate and render nothing')
    for _,adapter in ipairs(adapters)do adapter.destroy()end
    assert(destroyed==100,'all controllers clean up')
    own:Destroy();other:Destroy();channel.destroy()
    return {result='PASS: lazy controllers, global effect budget, duplicate suppression and cleanup',
        attemptedActions=1600,renderedActions=played,elapsedMs=math.floor((os.clock()-started)*1000)}
end
