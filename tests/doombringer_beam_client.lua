-- Run in Roblox with the loaded doombringer.lua factory as the argument.
-- Real engine geometry is required: Lua mocks do not enforce Part size limits.
return function(factory)
    local character=Instance.new("Model")
    local hat=Instance.new("Accessory");hat.Name="Doombringer";hat.Parent=character
    local chatted=Instance.new("BindableEvent")
    local added=Instance.new("BindableEvent")
    local api=factory({Character=character,Name="Fixture",Chatted=chatted.Event,CharacterAdded=added.Event})
    local ok,err=xpcall(function()
        assert(api.command("target 0 0 0"))
        local source=character:FindFirstChild("DoombringerSatelliteExplosionBeam",true)
        local beam=source and source:FindFirstChildOfClass("Beam")
        assert(beam and beam.Attachment1.WorldPosition.Magnitude<0.01,"Beam must reach the target, not stop above it")
        assert((beam.Attachment0.WorldPosition-Vector3.new(100,3000,0)).Magnitude<0.01,"Beam must start at the satellite")
        assert(beam.FaceCamera and beam.Enabled,"Beam must be visible from the camera")
        local impact=character:FindFirstChild("DoombringerImpact",true)
        assert(impact and impact.Position.Magnitude<0.01 and impact.Transparency<1,"Impact must be visible at the target")
        api.command("stop");task.wait(0.7)
        assert(api.diagnostics().effects==0,"Stopped effects must not restart")
    end,debug.traceback)
    api.destroy();character:Destroy();chatted:Destroy();added:Destroy()
    assert(ok,err)
    return "Doombringer real-engine beam endpoints, impact, and cleanup passed."
end
