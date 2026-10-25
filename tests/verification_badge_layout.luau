-- Real renderer, including deferred native layout events (no replacement layout math).
return function(source)
    local block=assert(source:match("    local function positionVerification%(object,badge%)(.-)    local verificationQueued=false"))
    block="local function positionVerification(object,badge)"..block
    local run=assert(loadstring([[return function(env)
        local verificationBadges,verificationGeometry,renderingVerification={},{},false
        local alive,enabled,verified=true,true,true
        local roots={env.root}
        local rootIndexes={[env.root]={objects={[env.label]=true}}}
        local player={}
        local currentName="Noah"
        local function read(o,k) return o and o[k] end
        local function plainText(t) return t or "" end
        local function verificationText() return true end
        local function hasOwnId() return true end
        local function uniquePeopleRow() return false end
        local function verifiedRosterRow() return false end
        local function clearVerification() end
        local function ancestors(o) return {o,o.Parent} end
        local Instance,UDim2,Vector2,task=env.Instance,env.UDim2,env.Vector2,env.task
    ]]..block..[[
        renderVerification()
        return verificationBadges[env.label],renderVerification
    end]]))()
    for _,card in ipairs({false,true}) do
        local queue,signals={},{}
        local label={ClassName="TextLabel",Text="Noah",Parent={Name=card and "CardContent" or "PersonRow"},AbsoluteSize={X=card and 129 or 72,Y=18},TextBounds={X=83,Y=18},ZIndex=3}
        function label:GetPropertyChangedSignal(name)
            signals[name]={Connect=function(_,callback) signals[name].callback=callback;return {Disconnect=function()end} end}
            return signals[name]
        end
        local badge=run({root={},label=label,
            Instance={new=function() return {} end},
            UDim2={fromOffset=function(x,y)return {X={Scale=0,Offset=x},Y={Scale=0,Offset=y}}end,new=function(xs,x,ys,y)return {X={Scale=xs,Offset=x},Y={Scale=ys,Offset=y}}end},
            Vector2={new=function(x,y)return {X=x,Y=y}end},
            task={defer=function(f)queue[#queue+1]=f end,wait=function()end}})
        -- Name replacement fires while bounds still describe the old account name.
        signals.Text.callback()
        label.TextBounds.X=card and 38 or 37
        for _,f in ipairs(queue) do f() end
        assert(badge.Position.X.Scale==(card and 0 or 1),"row must retain its original anchor")
        assert(badge.Position.X.Offset==(card and 40 or -33),"card must use settled alias bounds; row removes unused native name space")
        assert(badge.Size.X.Offset==16 and badge.Size.Y.Offset==16,"badge size is preserved")
    end
    print("PASS: original row placement and square card after native name/layout settles")
end
