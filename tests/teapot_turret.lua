-- Small offline check for command parsing, hat gating, duplicate suppression, and cleanup.
local function signal()
    local s={listeners={}}
    function s:Connect(fn)local c={live=true};self.listeners[#self.listeners+1]={c,fn};function c:Disconnect()c.live=false end;return c end
    function s:Fire(...)for _,v in ipairs(self.listeners)do if v[1].live then v[2](...)end end end
    return s
end
local methods={};local meta={__index=function(t,k)return methods[k]or t.props[k]end,__newindex=function(t,k,v)
    if k=="Parent"then local old=t.props.Parent;if old then for i,x in ipairs(old.children)do if x==t then table.remove(old.children,i)break end end;old.ChildRemoved:Fire(t)end;t.props.Parent=v;if v then v.children[#v.children+1]=t;v.ChildAdded:Fire(t);local a=v;while a do a.DescendantAdded:Fire(t);a=a.Parent end end else t.props[k]=v end end}
local function node(class,name,parent)local n=setmetatable({props={ClassName=class,Name=name or class,ChildAdded=signal(),ChildRemoved=signal(),DescendantAdded=signal(),DescendantRemoving=signal()},children={}},meta);n.Parent=parent;return n end
function methods:IsA(c)return c==self.ClassName or c=="BasePart"and(self.ClassName=="Part"or self.ClassName=="MeshPart")end
function methods:GetChildren()return self.children end
function methods:FindFirstChild(n)for _,x in ipairs(self.children)do if x.Name==n then return x end end end
function methods:FindFirstChildOfClass(c)for _,x in ipairs(self.children)do if x:IsA(c)then return x end end end
function methods:Destroy()self.destroyed=true;self.Parent=nil end
local function player(name,display)local p=node("Player",name);p.DisplayName=display or name;p.CharacterAdded=signal();p.Chatted=signal();return p end
Vector3={new=function(x,y,z)return{x=x,y=y,z=z}end};Color3={new=function(r,g,b)return{r=r,g=g,b=b}end};CFrame={new=function()return{__mul=function(a,b)return a end}end};BrickColor={new=function(x)return x end};Enum={EasingStyle={Linear=1},PartType={Ball=1},Material={Neon=1}};TweenInfo={new=function()return{}end}
local now=0;os.clock=function()return now end
local timers={};task={delay=function(seconds,fn)timers[#timers+1]={at=now+seconds,fn=fn}end,spawn=function(fn)fn()end,defer=function(fn)fn()end}
local function advance(seconds)
    now=now+seconds
    while true do
        local pick
        for i,t in ipairs(timers)do if t.at<=now and (not pick or t.at<pick.at)then pick={i=i,at=t.at,fn=t.fn}end end
        if not pick then break end
        table.remove(timers,pick.i);pick.fn()
    end
end
local createdParts={};Instance={new=function(c)local item=node(c,c);if c=="Part"then createdParts[#createdParts+1]=item end;return item end}
local me=player("Tester");local other=player("Target","Tea Target");me.Character=node("Model","Character");local humanoid=node("Humanoid","Humanoid",me.Character);humanoid.Health=100;humanoid.Died=signal();local hat=node("Accessory","TeapotTurret",me.Character);node("Part","Handle",hat);node("Part","HumanoidRootPart",me.Character);other.Character=node("Model","Other");node("Part","HumanoidRootPart",other.Character)
local players={LocalPlayer=me,GetPlayers=function()return{me,other}end};local textService={SendingMessage=signal()};game={GetService=function(_,n)return n=="Players"and players or n=="TweenService"and{Create=function()return{Play=function()end}end}or n=="TextChatService"and textService end}
local create=dofile("teapot_turret.lua");local api=create(me);assert(api.refresh(),"a matching hat enables the turret")
me.CharacterAdded:Fire(me.Character);me.Chatted:Fire("Teapot, pwn Tea!");assert(api.diagnostics().rockets==1,"chat input remains connected across character rebinding: active="..tostring(api.diagnostics().active).." rockets="..tostring(api.diagnostics().rockets))
local rocket=createdParts[#createdParts];assert(rocket.Anchored==true and rocket.CanCollide==false and rocket.CanTouch==false and rocket.CanQuery==false,"rockets are anchored and noncolliding cosmetic parts")
assert(not api.command("Teapot, pwn Tea!"),"duplicate chat delivery does not launch a second rocket")
textService.SendingMessage:Fire({Text="Teapot, pwn Tea!"});assert(api.diagnostics().rockets==1,"TextChat duplicate is suppressed")
me.Chatted:Fire("CLOCKWORK INVOKES TEAPOT DOOM!");assert(api.diagnostics().rockets==1,"doom starts with one immediate local volley")
advance(2);assert(api.diagnostics().rockets==1,"doom schedules exactly one bounded volley every two seconds")
me.Chatted:Fire("...");advance(2);assert(api.diagnostics().rockets==0,"stop command cancels future doom and lets old rockets expire")
me.Chatted:Fire("CLOCKWORK INVOKES TEAPOT DOOM!");api.setEnabled(false);advance(2);assert(api.diagnostics().rockets==0 and not api.diagnostics().active,"disabling clears and blocks cosmetic rockets")
api.setEnabled(true);api.refresh();humanoid.Died:Fire();assert(api.diagnostics().rockets==0,"death cleanup removes active rockets")
hat.Parent=nil;assert(not api.refresh() and api.diagnostics().rockets==0,"removing the hat gates and cleans rockets")
assert(not api.command("Teapot, pwn Target!"),"commands while unwearing are ignored")
api.destroy();assert(not api.diagnostics().active,"destroy disables the turret")
print("Teapot turret command gating, prefix targeting, duplicate suppression, and cleanup passed.")
