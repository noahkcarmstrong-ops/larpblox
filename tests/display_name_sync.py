"""Execute the real game sync with a simulated desktop socket using Luau."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
harness = r'''
local jobs, nameCalls, viewCalls = {}, {}, {}
task = {
    spawn=function(f) jobs[#jobs+1]=f end,
    defer=function(f) jobs[#jobs+1]=f end,
    delay=function() end,
}
local function flush()
    while #jobs>0 do local job=table.remove(jobs,1);job() end
end
local http={JSONEncode=function(_,v)return v end,JSONDecode=function(_,v)return v end}
game={GetService=function(_,name) if name=="HttpService" then return http end;return {} end}
local function signal()return {Connect=function()return {Disconnect=function()end}end}end
local player={UserId=7,Character=nil,CharacterAdded=signal(),CharacterAppearanceLoaded=signal(),CharacterRemoving=signal(),FindFirstChildOfClass=function()end}
request=function() return {StatusCode=200,Body={instanceId="test"}} end
local receive
WebSocket={connect=function()return {
    OnMessage={Connect=function(_,f)receive=f end},OnClose=signal(),
    Close=function()end,Send=function()end,
}end}
local create=(function()
-- SOURCE
end)()
local names={
    set=function(username,displayName)nameCalls[#nameCalls+1]={username,displayName}end,
    setEnabled=function(enabled)nameCalls[#nameCalls+1]={enabled=enabled}end,
    setVerified=function()end,
}
local empty={restore=function()end}
local sync=create(player,function()return empty end,function()return empty end,function()return true end,nil,nil,function()return names end,function()return {update=function(value)viewCalls[#viewCalls+1]=value end}end)
jobs={}
assert(sync.connect(string.rep("a",32)))
receive({type="ready",instanceId="test"});flush()
local function publish(username,displayName,enabled)
    receive({type="state",channel="names",value={version=1,userId="7",enabled=enabled~=false,name=username,displayName=displayName}})
    flush()
end
publish("Pilot_7","Captain Seven")
assert(nameCalls[#nameCalls][1]=="Pilot_7" and nameCalls[#nameCalls][2]=="Captain Seven","name pair must stay separate")
assert(viewCalls[#viewCalls].name=="Pilot_7" and viewCalls[#viewCalls].displayName=="Captain Seven","native views must receive the correct fields")
publish("Pilot_7","New Captain")
assert(nameCalls[#nameCalls][2]=="New Captain","display-only changes must trigger an update")
local before=#nameCalls
sync.resumeAppearance(true);flush()
assert(#nameCalls>before and nameCalls[#nameCalls][2]=="New Captain","respawn restoration must reapply the pair")
publish("Legacy_7",nil)
assert(nameCalls[#nameCalls][1]=="Legacy_7" and nameCalls[#nameCalls][2]=="Legacy_7","older payloads must remain valid")
publish("Legacy_7",nil,false)
assert(nameCalls[#nameCalls].enabled==false and viewCalls[#viewCalls].enabled==false,"mode off must restore native names")
sync.destroy();flush()
print("PASS: real game sync preserves separate names through socket updates, native views, respawn, legacy payloads, and mode off")
'''
with tempfile.TemporaryDirectory(prefix="larpblox-display-") as folder:
    fixture = Path(folder) / "display.lua"
    fixture.write_text(harness.replace("-- SOURCE", (root / "game_browser_sync.lua").read_text(encoding="utf-8")), encoding="utf-8")
    subprocess.run([os.environ.get("LUAU", "luau"), str(fixture)], check=True)
