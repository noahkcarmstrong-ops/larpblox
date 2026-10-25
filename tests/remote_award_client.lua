-- Real Roblox instances, detached from the live player and world.
return function(factory)
    for _,rig in ipairs({'R6','R15'})do
        local character=Instance.new('Model')
        local humanoid=Instance.new('Humanoid');humanoid.Parent=character
        local hand=Instance.new('Part');hand.Name=rig=='R6' and 'Right Arm' or 'RightHand';hand.CFrame=CFrame.new(2,3,4);hand.Parent=character
        if rig=='R15' then
            local attachment=Instance.new('Attachment');attachment.Name='RightGripAttachment'
            attachment.CFrame=CFrame.new(0,-0.5,0)*CFrame.Angles(math.pi/2,0,0);attachment.Parent=hand
        end
        local hat=Instance.new('Accessory');hat.Name='SparklingHat'
        local original=Instance.new('Part');original.Name='Handle';original.Parent=hat;hat.Parent=character
        local backpack=Instance.new('Folder');local gui=Instance.new('Folder');gui:SetAttribute('HoneyBunCosmeticUI_HatSounds',false)
        local added=Instance.new('BindableEvent')
        local player={Character=character,CharacterAdded=added.Event,
            FindFirstChildOfClass=function(_,class)return class=='Backpack' and backpack or nil end,
            GetMouse=function()error('Remote trophy must not read local input')end}
        local echoed=0
        local api=factory(player,nil,{remote=true,viewerGui=gui,emit=function()echoed=echoed+1 end})
        local ok,err=xpcall(function()
            assert(not character:FindFirstChild('Contest Winner Award'),'remote starts disabled')
            api.setEnabled(true);api.setHeld(true)
            local model=assert(character:FindFirstChild('Contest Winner Award'),'held trophy appears')
            assert(model:IsA('Model') and #backpack:GetChildren()==0,'receiver creates a visual model, never a playable tool')
            local handle=model.Handle
            local grip=assert(hand:FindFirstChild('LarpbloxContestAwardGrip'))
            local expected=hand.CFrame*grip.C0*grip.C1:Inverse()
            assert(handle.CFrame:ToObjectSpace(expected).Position.Magnitude<0.001,'grip placed before display')
            assert(expected.UpVector:Dot(Vector3.yAxis)>0.999,'remote trophy stays upright')
            api.setHeld(true)
            assert(character:FindFirstChild('Contest Winner Award')==model,'unchanged held state allocates nothing')
            assert(api.replay('award-burst',{}),'remote burst activates')
            assert(handle:FindFirstChild('ContestAwardSparkles') and not handle.ClapSound.IsPlaying,'sparkles visible while viewer mute is respected')
            assert(echoed==0,'remote playback cannot echo back into sharing')
            api.setHeld(false)
            assert(not character:FindFirstChild('Contest Winner Award') and not hand:FindFirstChild('LarpbloxContestAwardGrip'),'unequip removes model and joint')
        end,debug.traceback)
        api.destroy();character:Destroy();backpack:Destroy();gui:Destroy();added:Destroy()
        assert(ok,err)
    end
    return 'PASS: R6/R15 remote trophy orientation, cosmetic-only model, no echo/input, mute and cleanup'
end
