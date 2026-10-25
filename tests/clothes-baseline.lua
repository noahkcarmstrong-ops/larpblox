local function signal()
    local s={};function s:Connect(f)self.f=f;return{Disconnect=function()self.f=nil end}end
    function s:Fire(...)if self.f then self.f(...)end end;return s
end
local function node(class,name)
    local x={ClassName=class,Name=name,children={},signals={}}
    setmetatable(x,{__index=function(t,k)if k=="Parent"then return rawget(t,"parent")end;return t.signals[k]end,__newindex=function(t,k,v)
        if k=="Parent"then local old=rawget(t,"parent");if old then for i,c in ipairs(old.children)do if c==t then table.remove(old.children,i)break end end end;rawset(t,"parent",v);if v then v.children[#v.children+1]=t;v.signals.ChildAdded:Fire(t)end;t.signals.AncestryChanged:Fire(t,v)
        else rawset(t,k,v);if t.signals[k]then t.signals[k]:Fire(v)end end
    end})
    function x:IsA(k)return self.ClassName==k end;function x:GetChildren()return self.children end
    function x:GetDescendants()local out={};local function walk(v)for _,c in ipairs(v.children)do out[#out+1]=c;walk(c)end end;walk(self);return out end
    function x:FindFirstChildOfClass(k)for _,c in ipairs(self.children)do if c:IsA(k)then return c end end end
    function x:GetPropertyChangedSignal(k)self.signals[k]=self.signals[k]or signal();return self.signals[k]end
    function x:Destroy()self.Parent=nil end
    x.signals.ChildAdded=signal();x.signals.AncestryChanged=signal();x.signals.Destroying=signal();return x
end
local character=node("Model","Character");local humanoid=node("Humanoid","Humanoid");humanoid.Health=100;humanoid.Parent=character
local shirt=node("Shirt","Native Shirt");shirt.ShirtTemplate="spawn-shirt";shirt.Parent=character
local pants=node("Pants","Native Pants");pants.PantsTemplate="spawn-pants";pants.Parent=character
local gui=node("PlayerGui","PlayerGui");function gui:SetAttribute(k,v)self[k]=v end;function gui:GetAttribute(k)return self[k]end
local player={Character=character,CharacterAdded=signal(),PlayerGui=gui,UserId=7}
function player:FindFirstChildOfClass(k)return k=="PlayerGui" and gui end
local http={};function http:JSONDecode()return nil end;function http:JSONEncode(v)return v end
local players={GetHumanoidDescriptionFromUserIdAsync=function()error("account description unavailable")end}
local loaded={shirt=node("Shirt","Loaded Shirt"),pants=node("Pants","Loaded Pants")};loaded.shirt.ShirtTemplate="custom-shirt";loaded.pants.PantsTemplate="custom-pants"
game={GetService=function(_,name)if name=="HttpService"then return http elseif name=="Players"then return players elseif name=="ContentProvider"then return{PreloadAsync=function()end}end end,GetObjects=function(_,id)if id=="rbxassetid://100" or id=="rbxassetid://901"then return{loaded.shirt}else return{loaded.pants}end end}
Instance={new=function(class)local x=node(class,class);if class=="BindableEvent"then x.Event=signal();function x:Fire(...)self.Event:Fire(...)end end;return x end};task={defer=function(f)f()end,spawn=function(f)f()end,wait=function()end}
local create=dofile("clothes.lua");local api=create(player)
api.equipShirt(100);assert(shirt.ShirtTemplate=="custom-shirt","saved shirt applies over the spawned game baseline")
shirt:Destroy();local replacement=node("Shirt","Package Shirt");replacement.ShirtTemplate="spawn-shirt";replacement.Parent=character
assert(replacement.ShirtTemplate=="custom-shirt","saved shirt reapplies after a package recreates the native slot")
replacement.ShirtTemplate="game-uniform";replacement.signals.ShirtTemplate:Fire();assert(replacement.ShirtTemplate=="game-uniform","later game uniform changes remain untouched")
api.restoreShirt();assert(replacement.ShirtTemplate=="game-uniform","disabling Larp clothes restores the live baseline")
api.equipShirt(100)
local fresh=node("Model","Fresh Character");local freshHumanoid=node("Humanoid","Humanoid");freshHumanoid.Health=100;freshHumanoid.Parent=fresh
local freshShirt=node("Shirt","Fresh Native Shirt");freshShirt.ShirtTemplate="new-spawn-shirt";freshShirt.Parent=fresh
player.Character=fresh;player.CharacterAdded:Fire(fresh);assert(freshShirt.ShirtTemplate=="custom-shirt","saved clothes reapply over a new character baseline")
api.destroy();print("Clothes spawned-baseline remap passed.")
