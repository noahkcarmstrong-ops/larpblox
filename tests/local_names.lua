-- Small Roblox-shaped fixture for the local name override.
local function signal()
    local s = {listeners = {}}
    function s:Connect(fn) local c={fn=fn,Connected=true};self.listeners[#self.listeners+1]=c;return {Disconnect=function() c.Connected=false end} end
    function s:Fire(...) for _,c in ipairs(self.listeners) do if c.Connected then c.fn(...) end end end
    return s
end
local function node(class,name)
    local x={ClassName=class,Name=name,children={},signals={},attrs={},DescendantAdded=signal()}
    setmetatable(x,{__index=function(t,k) if k=="Parent" then return rawget(t,"parent") end end,__newindex=function(t,k,v)
        if k=="Parent" then local old=rawget(t,"parent");if old then for i,c in ipairs(old.children) do if c==t then table.remove(old.children,i)break end end end;rawset(t,"parent",v);if v then v.children[#v.children+1]=t end else rawset(t,k,v) end
    end})
    function x:IsA(k) return k==self.ClassName or (k=="GuiObject" and (self.ClassName=="TextLabel" or self.ClassName=="TextButton")) end
    function x:GetChildren() return self.children end
    function x:FindFirstChildOfClass(k) for _,c in ipairs(self.children) do if c:IsA(k) then return c end end end
    function x:GetDescendants() local out={};local function walk(v) for _,c in ipairs(v.children) do out[#out+1]=c;walk(c) end end;walk(self);return out end
    function x:FindFirstChild(n,recurse) for _,c in ipairs(self.children) do if c.Name==n then return c end;if recurse then local f=c:FindFirstChild(n,true);if f then return f end end end end
    function x:GetPropertyChangedSignal(k) self.signals[k]=self.signals[k] or signal();return self.signals[k] end
    function x:GetAttribute(k) return self.attrs[k] end;function x:SetAttribute(k,v) self.attrs[k]=v end
    function x:Destroy() self.Parent=nil end
    return x
end
local http={JSONEncode=function(_,v)return v end,JSONDecode=function(_,v)return v end}
local core=node("CoreGui","CoreGui");local gui=node("PlayerGui","PlayerGui");local character=node("Model","Character");local humanoid=node("Humanoid","Humanoid");humanoid.DisplayName="Original Display";humanoid.Parent=character
local added=signal();local player={Name="OriginalUser",DisplayName="Original Display",UserId=123,Character=character,CharacterAdded=added}
function player:FindFirstChildOfClass(k) return k=="PlayerGui" and gui end
game={Workspace=node("Workspace","Workspace"),GetService=function(_,name)if name=="HttpService"then return http end;if name=="CoreGui"then return core end end}
local make=dofile("local_names.lua")
local row=node("Frame","PlayerEntry_123");row.Parent=core;local label=node("TextLabel","Name");label.Text="OriginalUser";label.RichText=true;label.Parent=row
local other=node("Frame","999");other.Parent=core;local otherLabel=node("TextLabel","Name");otherLabel.Text="OriginalUser";otherLabel.Parent=other
local conflictingRank=node("TextLabel","Username");conflictingRank.Text="#3 - OriginalUser";conflictingRank:SetAttribute("UserId",999);conflictingRank.Parent=other
local native=node("TextLabel","PlayerName");native.Text="Combined Service Name";native.Parent=row
local rankedDisplay=node("TextLabel","DisplayName");rankedDisplay.Text="#2 - Original Display";rankedDisplay.Parent=row
local rankedUsername=node("TextLabel","Username");rankedUsername.Text="#2 - OriginalUser";rankedUsername.Parent=row
local shared=node("TextLabel","PlayerName");shared.Text="Original Display";shared.Parent=other
local list=node("Frame","PlayerList");list.Parent=core
local title=node("Frame","TitlePlayer");title.Parent=list
local titleName=node("TextLabel","PlayerName");titleName.Text="Mobile Combined Name";titleName.Parent=title
local people=node("Frame","People");people.Parent=core
local menuRow=node("Frame","UnidentifiedReactRow");menuRow.Parent=people
local menuDisplay=node("TextLabel","Text");menuDisplay.Text="Original Display";menuDisplay.Parent=menuRow
local menuUser=node("TextLabel","Text");menuUser.Text="@OriginalUser";menuUser.Parent=menuRow
local otherRow=node("Frame","OtherReactRow");otherRow.Parent=people
local otherDisplay=node("TextLabel","Text");otherDisplay.Text="Original Display";otherDisplay.Parent=otherRow
local otherUser=node("TextLabel","Text");otherUser.Text="@OtherUser";otherUser.Parent=otherRow
local profileName=node("TextLabel","Username");profileName.Text="OriginalUser (You)";profileName.Parent=row
local weaponsName=node("TextLabel","Section");weaponsName.Text="OriginalUser's Weapons";weaponsName.Parent=row
local displayWeapons=node("TextLabel","Section");displayWeapons.Text="Original Display's Weapons";displayWeapons.Parent=row
local richWeapons=node("TextLabel","Section");richWeapons.Text='<font color="#fff">OriginalUser\'s</font> Weapons';richWeapons.RichText=true;richWeapons.Parent=row
local otherWeapons=node("TextLabel","Section");otherWeapons.Text="OriginalUser's Weapons";otherWeapons.Parent=other
local api=make(player,gui)
api.set("Local_User","Local Display")
assert(rankedDisplay.Text=="#2 - Local Display" and rankedUsername.Text=="#2 - Local_User","ranked leaderboard names replace only the semantic suffix")
assert(conflictingRank.Text=="#3 - OriginalUser","conflicting ranked identity stays untouched")
assert(profileName.Text=="Local_User (You)","own MM2 profile heading keeps You suffix and shows the Larp name")
assert(weaponsName.Text=="Local_User's Weapons" and displayWeapons.Text=="Local Display's Weapons","own possessive section headings replace username and display name")
assert(richWeapons.Text=='<font color="#fff">Local_User\'s</font> Weapons',"possessive replacement preserves RichText tags")
assert(otherWeapons.Text=="OriginalUser's Weapons","other player's possessive heading stays untouched")
assert(label.Text=="Local_User" and otherLabel.Text=="OriginalUser","only the local player's native row changes")
assert(menuDisplay.Text=="Local Display" and menuUser.Text=="@Local_User","People menu own display and username update without row ID")
assert(otherDisplay.Text=="Original Display" and otherUser.Text=="@OtherUser","People menu shared display name stays untouched")
assert(humanoid.DisplayName=="Local Display","humanoid display name changes locally")
assert(titleName.Text=="Local Display","native local mobile title row changes")
assert(native.Text=="Local Display" and shared.Text=="Original Display","native combined name changes only in own user-ID row")
native.Text="Refreshed Service Name";native:GetPropertyChangedSignal("Text"):Fire()
assert(native.Text=="Local Display","native redraw reapplies")
local late=node("TextLabel","PlayerName");late.Text="";late.Parent=row;core.DescendantAdded:Fire(late)
late.Text="Original Display";late:GetPropertyChangedSignal("Text"):Fire()
assert(late.Text=="Local Display","text assigned after creation is replaced")
api.set("Other_User","A < B & 50%")
assert(native.Text=="A < B & 50%","plain names preserve literal characters")
label.Text='<font face="OriginalUser">Original Display</font>';label:GetPropertyChangedSignal("Text"):Fire()
assert(label.Text=='<font face="OriginalUser">A &lt; B &amp; 50%</font>',"RichText replacement preserves tag attributes and escapes the alias")
api.set("Local_User","Local Display")
label.Text="<font color=\"#fff\">OriginalUser</font>";label:GetPropertyChangedSignal("Text"):Fire()
assert(label.Text=="<font color=\"#fff\">Local_User</font>","RichText tags remain intact")
api.setEnabled(false)
assert(menuDisplay.Text=="Original Display" and menuUser.Text=="@OriginalUser","People menu restores original name")
assert(weaponsName.Text=="OriginalUser's Weapons" and displayWeapons.Text=="Original Display's Weapons","disable restores possessive section headings")
assert(richWeapons.Text=='<font color="#fff">OriginalUser\'s</font> Weapons',"disable restores RichText possessive heading")
assert(native.Text=="Refreshed Service Name","disable restores latest native service name")
assert(label.Text=="<font color=\"#fff\">OriginalUser</font>" and humanoid.DisplayName=="Original Display","disable restores originals")
api.setEnabled(true);assert(label.Text=="<font color=\"#fff\">Local_User</font>","enable reapplies after an update")
local fresh=node("Model","Fresh");local freshHumanoid=node("Humanoid","Humanoid");freshHumanoid.DisplayName="Original Display";freshHumanoid.Parent=fresh;player.Character=fresh;added:Fire(fresh)
assert(freshHumanoid.DisplayName=="Local Display","respawn reapplies display name")
api.restore();assert(api.getSettings().username=="" and label.Text=="<font color=\"#fff\">OriginalUser</font>","restore clears settings and text")
api.set("Final_User","Final Display")
api.set("Again_User","Again Display")
api.destroy()
assert(freshHumanoid.DisplayName=="Original Display","repeated settings preserve original humanoid name")
local blockedGame=game
local savedService=game.GetService
game.GetService=function(_,name)if name=="CoreGui"then error("blocked")end;return savedService(game,name)end
local blocked=make(player,gui)
assert(blocked.report():find("unavailable",1,true),"unavailable CoreGui is reported")
blocked.destroy();game.GetService=savedService
print("Local name override fixture passed.")
