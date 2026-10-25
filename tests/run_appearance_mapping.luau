-- Offline event/lifecycle regressions: lune run tests/run_appearance_mapping.luau
-- Real Roblox datatypes with an observable Instance fixture; no player/network access.
local fs=require("@lune/fs")
local luau=require("@lune/luau")
local roblox=require("@lune/roblox")
local jobs={}
local function signal()
    local connections={}
    return {Connect=function(_,callback)
        local connection={Connected=true,callback=callback}
        function connection:Disconnect()self.Connected=false end
        connections[#connections+1]=connection;return connection
    end,Fire=function(_,...)
        for _,connection in ipairs(table.clone(connections))do if connection.Connected then connection.callback(...)end end
    end}
end
local parents={Part="BasePart",MeshPart="BasePart",SpecialMesh="DataModelMesh",Accessory="Accoutrement",Hat="Accoutrement",
    Shirt="Clothing",Pants="Clothing",Motor6D="JointInstance",Weld="JointInstance",Script="LuaSourceContainer",LocalScript="LuaSourceContainer"}
local methods={}
function methods:IsA(class)
    local actual=self.ClassName
    while actual do if actual==class then return true end;actual=parents[actual]end
    return class=="Instance"
end
function methods:GetChildren()return table.clone(self._children)end
function methods:GetDescendants()
    local result={}
    local function walk(object)for _,child in ipairs(object._children)do result[#result+1]=child;walk(child)end end
    walk(self);return result
end
function methods:IsDescendantOf(parent)
    local node=self.Parent
    while node do if node==parent then return true end;node=node.Parent end
    return false
end
function methods:FindFirstChild(name,recursive)
    for _,child in ipairs(recursive and self:GetDescendants()or self._children)do if child.Name==name then return child end end
end
function methods:FindFirstChildOfClass(class)
    for _,child in ipairs(self._children)do if child.ClassName==class then return child end end
end
function methods:FindFirstChildWhichIsA(class,recursive)
    for _,child in ipairs(recursive and self:GetDescendants()or self._children)do if child:IsA(class)then return child end end
end
function methods:GetPropertyChangedSignal(name)
    self._signals[name]=self._signals[name]or signal();return self._signals[name]
end
function methods:GetAttribute(name)return self._attributes[name]end
function methods:SetAttribute(name,value)self._attributes[name]=value end
function methods:GetAttributes()return table.clone(self._attributes)end
function methods:Destroy()
    if self._destroyed then return end
    self._destroyed=true;self.Destroying:Fire()
    self.Parent=nil
    for _,child in ipairs(self:GetChildren())do child:Destroy()end
end
function methods:GetFullName()return self.Parent and self.Parent:GetFullName().."."..self.Name or self.Name end
function methods:SetAccessories(entries)self._accessories=table.clone(entries)end
function methods:GetAccessories()return self._accessories or {}end
local new
function methods:Clone()
    if self.Archivable==false then return nil end
    local references={}
    local function copy(object)
        local result=new(object.ClassName);references[object]=result
        for name,value in pairs(object._values)do if name~="Parent"then result._values[name]=value end end
        result._attributes=table.clone(object._attributes)
        for _,child in ipairs(object:GetChildren())do local cloned=copy(child);if cloned then cloned.Parent=result end end
        return result
    end
    local result=copy(self)
    for _,object in pairs(references)do for name,value in pairs(object._values)do if references[value]then object._values[name]=references[value]end end end
    return result
end
local function ancestryEvent(parent,name,object)
    while parent do parent[name]:Fire(object);parent=parent.Parent end
end
new=function(class)
    local object={_values={ClassName=class,Name=class,Archivable=true},_children={},_signals={},_attributes={}}
    for _,name in ipairs({"DescendantAdded","DescendantRemoving","ChildAdded","ChildRemoved","Destroying","AncestryChanged","HealthChanged"})do object[name]=signal()end
    local v=object._values
    if class=="BindableEvent"then object.Event=signal();object.Fire=function(self,...)self.Event:Fire(...)end end
    if class=="Part"or class=="MeshPart"then
        v.Size=roblox.Vector3.new(4,1.2,2);v.Color=roblox.Color3.fromRGB(163,162,165);v.CFrame=roblox.CFrame.new()
        v.Transparency=0;v.LocalTransparencyModifier=0;v.Shape=roblox.Enum.PartType.Block;v.MeshId="";v.TextureID=""
    elseif class=="SpecialMesh"then
        v.Name="Mesh";v.MeshId="";v.TextureId="";v.Scale=roblox.Vector3.one;v.Offset=roblox.Vector3.zero;v.VertexColor=roblox.Vector3.one;v.MeshType=roblox.Enum.MeshType.Head
    elseif class=="Humanoid"then v.Health=100;v.HipHeight=2;v.RigType=roblox.Enum.HumanoidRigType.R15
    elseif class=="CharacterMesh"then v.MeshId=0;v.BaseTextureId=0;v.OverlayTextureId=0;v.BodyPart=roblox.Enum.BodyPart.Head
    elseif class=="Decal"then v.Texture="";v.Color3=roblox.Color3.new(1,1,1);v.Transparency=0;v.Face=roblox.Enum.NormalId.Front
    elseif class=="Accessory"then v.AccessoryType=roblox.Enum.AccessoryType.Unknown
    elseif class=="Attachment"then v.CFrame=roblox.CFrame.new()
    elseif class=="Vector3Value"then v.Value=roblox.Vector3.zero
    elseif class=="StringValue"then v.Value=""
    elseif class=="NumberValue"then v.Value=0 end
    if class=="BodyColors"or class=="HumanoidDescription"then
        for _,region in ipairs({"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg"})do
            v[region..(class=="BodyColors"and "Color3"or "Color")]=roblox.Color3.fromRGB(163,162,165)
            if class=="HumanoidDescription"then v[region]=0 end
        end
        if class=="HumanoidDescription"then
            for _,field in ipairs({"HeightScale","WidthScale","DepthScale","HeadScale"})do v[field]=1 end
            v.BodyTypeScale=0;v.ProportionScale=0;v.Face=0
        end
    end
    return setmetatable(object,{__index=function(self,name)return methods[name]or self._values[name]or self:FindFirstChild(name)end,
        __newindex=function(self,name,value)
            if name:sub(1,1)=="_"then rawset(self,name,value);return end
            local previous=self._values[name]
            if previous==value then return end
            if name=="Parent"then
                local descendants=self:GetDescendants();table.insert(descendants,1,self)
                if previous then
                    for _,node in ipairs(descendants)do ancestryEvent(previous,"DescendantRemoving",node)end
                    table.remove(previous._children,table.find(previous._children,self));previous.ChildRemoved:Fire(self)
                end
                self._values.Parent=value
                if value then value._children[#value._children+1]=self;value.ChildAdded:Fire(self);for _,node in ipairs(descendants)do ancestryEvent(value,"DescendantAdded",node)end end
                self.AncestryChanged:Fire(self,value)
            else self._values[name]=value end
            local event=self._signals[name];if event then event:Fire()end
        end})
end
local function drain()
    local count=0
    while #jobs>0 do count+=1;assert(count<10000,"event feedback loop");table.remove(jobs,1)()end
end
local environment=setmetatable({workspace=new("Model"),Instance={new=new},Enum=roblox.Enum,Vector3=roblox.Vector3,CFrame=roblox.CFrame,Color3=roblox.Color3,
    task={defer=function(callback,...)local args=table.pack(...);jobs[#jobs+1]=function()callback(table.unpack(args,1,args.n))end end,
        spawn=function(callback,...)local args=table.pack(...);jobs[#jobs+1]=function()callback(table.unpack(args,1,args.n))end end,wait=drain},
    game={Clone=methods.Clone,GetService=function(_,name)assert(name=="HttpService");return {}end},
},{__index=getfenv()})
environment.loadstring=function(source)return luau.load(source,{environment=environment})end
local mapping=fs.readFile("appearance_mapping.lua")
local avatar=fs.readFile("avatar.lua")
local test=luau.load(fs.readFile("tests/appearance_mapping.luau"),{environment=environment})()
print(test(mapping))
local integration=luau.load(fs.readFile("tests/avatar_mapping.luau"),{environment=environment})()
print(integration(avatar,mapping))
local sharing=luau.load(fs.readFile("tests/shared_mapping.luau"),{environment=environment})()
print(sharing(fs.readFile("shared_larp.lua"),avatar,mapping))
local clothing=luau.load(fs.readFile("tests/clothing_mapping.luau"),{environment=environment})()
print(clothing(mapping,fs.readFile("clothes.lua")))
