-- Offline regression for executor hooks; no live player or global interception.
local fs=require('@lune/fs')
local luau=require('@lune/luau')
local function signal()
    local s={listeners={}}
    function s:Connect(callback)
        local c={Connected=true,callback=callback}
        function c:Disconnect()self.Connected=false end
        self.listeners[#self.listeners+1]=c;return c
    end
    function s:Fire(...)
        for _,c in ipairs(table.clone(self.listeners))do if c.Connected then c.callback(...)end end
    end
    return s
end
local hooks,implementations={},{}
local installs=0
local function hookable(implementation)
    local fn
    fn=function(...)return (hooks[fn]or implementation)(...)end
    implementations[fn]=implementation;return fn
end
local invoke=hookable(function(object,...)return object.callback(...)end)
local environment={}
local gui={attributes={}}
function gui:GetAttribute(key)return self.attributes[key]end
function gui:SetAttribute(key,value)self.attributes[key]=value end
local function rig()
    local play={Name='PlayEmote',ClassName='BindableFunction',Invoke=invoke}
    function play:IsA(class)return class==self.ClassName end
    play.callback=hookable(function(...)return 'native',...end)
    local animator={ClassName='Animator'}
    function animator:IsA(class)return class==self.ClassName end
    local humanoid={ClassName='Humanoid',Health=100,StateChanged=signal(),Running=signal(),ApplyDescriptionFinished=signal()}
    function humanoid:IsA(class)return class==self.ClassName end
    function humanoid:FindFirstChildOfClass(class)return class=='Animator'and animator or nil end
    local animate={FindFirstChild=function(_,name)return name=='PlayEmote'and play or nil end}
    local character={DescendantAdded=signal(),DescendantRemoving=signal()}
    function character:FindFirstChildOfClass(class)return class=='Humanoid'and humanoid or nil end
    function character:FindFirstChild(name)return name=='Animate'and animate or nil end
    function character:GetDescendants()return {humanoid,animator,play}end
    return character,play
end
local character,play=rig()
local player={Character=character,CharacterAdded=signal(),FindFirstChildOfClass=function()return gui end}
local env=setmetatable({
    game={GetService=function(_,name)assert(name=='HttpService');return {}end},
    getgenv=function()return environment end,
    getcallbackvalue=function(object,key)assert(key=='OnInvoke');return object.callback end,
    hookfunction=function(fn,replacement)
        assert(implementations[fn],'only demonstrated callback/methods may be hooked')
        local original=hooks[fn]or implementations[fn];hooks[fn]=replacement;installs+=1;return original
    end,
    hookmetamethod=function()error('global property hook is forbidden')end,
    task={defer=function(callback)callback()end},
},{__index=getfenv()})
local function factory()return luau.load(fs.readFile('motion.lua'),{environment=env})()end
local api=factory()(player)
assert(installs==0,'disabled movement must install no hooks at startup')
api.setEmoteWhileWalking(true)
assert(installs==2,'movement owns only Invoke observation and the native callback')
local args=table.pack(play:Invoke('original',nil,3))
assert(args.n==4 and args[1]=='native'and args[2]=='original'and args[3]==nil and args[4]==3,'native callback arguments and nil returns survive')
local other={Invoke=invoke,callback=function(...)return 'unrelated',...end}
assert(other:Invoke(9)=='unrelated'and installs==2,'unrelated BindableFunctions pass through without binding work')
play.callback=hookable(function(...)return 'replacement',...end)
assert(play:Invoke('late')=='replacement'and installs==3,'callback reassignment is observed at its next use')
api.setEmoteWhileWalking(false)
assert(next(environment.__LarpbloxEmoteEvents.callbacks)==nil,'disable releases Invoke observation ownership')
play.callback=hookable(function(...)return 'disabled',...end)
assert(play:Invoke()=='disabled'and installs==3,'disabled movement does not bind late callbacks')
api.setEmoteWhileJumping(true)
local newCharacter,newPlay=rig();player.Character=newCharacter;player.CharacterAdded:Fire(newCharacter)
assert(environment.__LarpbloxEmoteEvents.callbacks[play]==nil,'respawn releases old controls')
assert(newPlay:Invoke()=='native','new character controls retain native behavior')
api.destroy()
assert(next(environment.__LarpbloxEmoteEvents.callbacks)==nil,'destroy releases all method observers')
assert(next(environment.__LarpbloxEmoteEvents.callbackHooks)~=nil,'shared trampolines stay safe across reloads')
local before=installs
local reloaded=factory()(player)
assert(installs==before,'reload reuses existing hooks')
reloaded.destroy()
print('PASS: no idle/global hooks; scoped Invoke, native arguments, late callbacks, disable, respawn and reload')
