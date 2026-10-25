local now,jobs,notifications=1000,{},0
local create=dofile('hat_sharing.lua')
local bus=create({session='12345678-1234-1234-1234-123456789abc',clock=function()return now end,
    delay=function(seconds,fn)assert(seconds==0.15);jobs[#jobs+1]=fn end})
local held=true
bus.attach({contest={isHeld=function()return held end}})
local disconnect=bus.onChanged(function()notifications=notifications+1 end)
for i=1,25 do bus.emit('doom-beam',{position={i,0,0}})end
assert(#jobs==1,'bursts must coalesce, not publish per effect/frame')
local state=bus.snapshot()
assert(bus.valid(state) and #state.events==16 and state.held=='award','bounded latest state')
jobs[1]();jobs={};assert(notifications==1)
local played,remoteHeld={},false
local remote={contest={setHeld=function(v)remoteHeld=v end,replay=function(kind,payload)played[#played+1]=kind end},
    doombringer={setHeld=function()end,replay=function(kind,payload)played[#played+1]=kind end}}
local receive=bus.receiver(remote)
receive(state);assert(remoteHeld and #played==17,'first live state plays bounded fresh effects plus reset')
receive(state);assert(#played==17,'duplicate snapshots never replay effects')
bus.emit('doom-satellite',{position={1,2,3}})
assert(#state.events==16 and state.satellite==nil,'published state cannot be mutated by later actions')
local moved=bus.snapshot();assert(moved.satellite[2]==2)
receive(moved);local before=#played;receive(moved);assert(#played==before,'satellite state is not rebuilt on each update')
now=1020;held=false
local expired=bus.snapshot();assert(#expired.events==0 and expired.held=='','old effects expire while held state stays current')
receive(expired);assert(not remoteHeld)
local malformed={version=1,session=state.session,held='',events={{id=1,kind='doom-beam',at=now,position={0,0,math.huge}}}}
assert(not bus.valid(malformed) and not receive(malformed),'unbounded coordinates rejected')
malformed.events={{id=1,kind='execute-code',at=now}};assert(not bus.valid(malformed),'only known cosmetic actions')
local allow=false;local limited=bus.receiver(remote,function()return allow end)
bus.emit('doom-beam',{position={0,0,0}});local fresh=bus.snapshot()
local baseline=#played;limited(fresh);assert(#played==baseline+2,'culled effects still apply reset and persistent satellite only')
allow=true;limited(fresh);assert(#played==baseline+2,'culled effects must not replay later as a backlog')
disconnect();bus.destroy();local count=#jobs;bus.emit('doom-stop');assert(#jobs==count,'destroy stops publication')
print('PASS: batched hat state, bounded events, duplicate/stale suppression, culling, validation and cleanup')
