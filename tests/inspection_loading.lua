-- Roblox-shaped fixture for the supported local Avatar Inspect Menu bridge.
local function signal()
 local listeners={}
 return {Connect=function(_,fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;listeners[#listeners+1]={c,fn};return c end,
 Fire=function(_,...)for _,entry in ipairs(listeners)do if entry[1].Connected then entry[2](...)end end end}
end
local function node(class,name,parent)
    local x={ClassName=class,Name=name or class,Visible=true,Enabled=true,Text="",children={},destroyed=false,DescendantAdded=signal(),AncestryChanged=signal(),Destroying=signal(),signals={}}
    function x:IsA(k)return k==self.ClassName or k=="GuiObject" and (self.ClassName=="Frame" or self.ClassName=="ImageButton" or self.ClassName=="ImageLabel" or self.ClassName=="ViewportFrame" or self.ClassName=="TextLabel")end
    function x:GetDescendants()
        local out={};local function walk(v)for _,c in ipairs(v.children)do out[#out+1]=c;walk(c)end end;walk(self);return out
    end
    function x:GetPropertyChangedSignal(key)self.signals[key]=self.signals[key] or signal();return self.signals[key]end
    function x:Destroy()self.destroyed=true;self.Parent=nil end
    return setmetatable(x,{__index=function(t,k)if k=="Parent"then return rawget(t,"parent")end;return rawget(t,k)end,__newindex=function(t,k,v)
        if k=="Parent"then rawset(t,"parent",v);if v then v.children[#v.children+1]=t end else rawset(t,k,v)end
    end})
end
local function child(parent,class,name)local x=node(class,name);x.Parent=parent;return x end

local old={task=task,Instance=Instance,Enum=Enum,Color3=Color3,game=game,UDim2=UDim2,Vector2=Vector2}
local descriptions,inspectCalls,restoreCalls= {},{},{}
local deferred,recoveryQueue={},{}
local originalClock=os.clock;local clock=0;os.clock=function()return clock end
task={defer=function(f)deferred[#deferred+1]=f end,delay=function(_,f)recoveryQueue[#recoveryQueue+1]=f end}
local function advanceRecovery(seconds)
 clock=clock+seconds;local pending=recoveryQueue;recoveryQueue={};for _,f in ipairs(pending)do f()end
end
local function flushDeferred()local pending=deferred;deferred={};for _,f in ipairs(pending)do f()end end
Instance={new=function(class)
    local x=node(class,class)
    function x:SetAccessories(v,includeRigid)self.accessories=v;self.includeRigid=includeRigid end
    function x:GetAccessories()return self.accessories or {}end
    function x:Destroy()self.destroyed=true;self.Parent=nil end
    return x
end}
Enum={AccessoryType={Hat="Hat",Hair="Hair",Back="Back",Jacket="Jacket",Face="Face"},HumanoidRigType={R6="R6",R15="R15"}}
Color3={fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}
local http={JSONEncode=function(_,v)return v.version..":"..(v.items[1] and v.items[1].id or "")end}
local gui={InspectPlayerFromHumanoidDescription=function(_,desc,name)
    inspectCalls[#inspectCalls+1]={description=desc,name=name}
end,InspectPlayerFromUserId=function(_,id)restoreCalls[#restoreCalls+1]=id end}
local renderStepped=signal()
local boundGuard,unbound=function()end,false
local run={RenderStepped=renderStepped,
 BindToRenderStep=function(_,name,priority,callback)assert(priority>=2000);boundGuard=callback end,
 UnbindFromRenderStep=function()unbound=true;boundGuard=false end}
local core=node("CoreGui","CoreGui")
-- Current Roblox mounts a Folder and places the entire panel beneath it.
local mount=child(core,"Folder","InspectAndBuy")
local inspect=child(mount,"Frame","ItemDetails")
local closeButton=child(inspect,"ImageButton","CloseButton")
local title=child(inspect,"TextLabel","Title");title.Text="Original's Avatar";title.Visible=false
local viewport=child(inspect,"ViewportFrame","AvatarViewport");viewport.ImageTransparency=0.2;viewport.AnchorPoint={0,0};viewport.Position={0.2,0.3};viewport.Size={0.8,0.7};viewport.AbsolutePosition={X=111,Y=222};viewport.AbsoluteSize={X=200,Y=250}
local firstPanel=child(inspect,"Frame","FirstPanel")
local nativeList=child(firstPanel,"ScrollingFrame","List")
local skeleton=child(nativeList,"Frame","Skeleton1")
local itemContent=child(inspect,"Frame","ItemDetails");local itemLabel=child(itemContent,"TextLabel","ItemName");itemLabel.Text="Original item"
local loadingContainer=child(inspect,"Frame","ViewportContainer")
local loadingImage=child(loadingContainer,"ImageLabel","AvatarLoadingImage");loadingImage.ImageTransparency=0.3
local world=child(viewport,"WorldModel","WorldModel")
local model=child(world,"Model","Avatar")
local renderedHumanoid=child(model,"Humanoid","Humanoid")
local modelDescription
function renderedHumanoid:GetAppliedDescription()return modelDescription end
local other=child(core,"Frame","OtherInspectAndBuy");local otherTitle=child(other,"TextLabel","Title");otherTitle.Text="Other's Avatar"
local hidden=child(core,"Frame","HiddenInspectAndBuy");hidden.Visible=false;local hiddenTitle=child(hidden,"TextLabel","Title");hiddenTitle.Text="Original's Avatar"
game={GetService=function(_,name)
    if name=="RunService"then return run elseif name=="CoreGui"then return core elseif name=="GuiService"then return gui elseif name=="HttpService"then return http end
end}
local module=dofile("native_inspection.lua")
local player={Name="Original",UserId=123}
UDim2={fromScale=function(x,y)return {x,y}end,fromOffset=function(x,y)return {x,y}end,new=function(...)return {...}end}
Vector2={new=function(x,y)return {X=x,Y=y}end}
local captures,shows=0,0
local failRender=false
local livePreview={version=1,records={{class="MeshPart",name="LiveLarpHat"}}}
local api=module.create(player,function()return {
 captureDescription=function(description,rigType)
  captures=captures+1
  assert(description and rigType,"the viewport renderer receives the generated outfit description")
  return livePreview
 end,
 show=function(frame,data)
  assert(viewport.ImageTransparency==1,"the real avatar stays hidden while local rendering runs")
  assert(frame.Visible==false and data==livePreview,"only the captured live character is rendered while hidden")
  shows=shows+1;return not failRender
 end,
}end)
local function previewGui()
 for _,object in ipairs(core.children)do if object.Name=="LarpbloxOwnPreview" and not object.destroyed then return object end end
end
local function liveOverlay()
 local parent=previewGui();if not parent then return end
 for _,object in ipairs(core:GetDescendants())do if object.Name=="LarpbloxInspectPreview" and not object.destroyed then return object end end
end
local snapshot={version=1,definition={assets={{id=100,meta=nil},{id=200,meta={order=3,puffiness=0.35}}},scales={height=1.1,width=0.9,depth=1.05,head=1.2,proportion=0.4,bodyType=0.7},bodyColors={headColor="#112233",torsoColor="445566"}},items={{id=100,assetType=11,name="Larp Shirt"},{id=200,assetType=67},{id=301,assetType=8},{id=302,assetType=41},{id=303,assetType=42},{id=304,assetType=79},{id=305,assetType=12},{id=306,assetType=8}}}
inspect.Visible=false
title.Text="LarpAlias's Avatar"
api.update({enabled=true,name="LarpAlias"})
assert(not viewport.Visible and not loadingImage.Visible,"own avatar content is quarantined before the inspector shell opens")
inspect.Visible=true;inspect:GetPropertyChangedSignal("Visible"):Fire()
assert(inspect.Visible and closeButton.Visible and not title.Visible and not itemContent.Visible,"missing outfit data leaves the page open while account content stays hidden")
-- local_names can rewrite the own title before the native redirect starts.
title.Visible=true;title:GetPropertyChangedSignal("Visible"):Fire()
title.Text="LarpAlias's Avatar";title:GetPropertyChangedSignal("Text"):Fire()
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(#inspectCalls==1 and inspectCalls[1].name=="LarpAlias","local native inspection is requested with the alias")
assert(viewport.ImageTransparency==1 and loadingImage.ImageTransparency==1,"both native loading thumbnail and 3D account preview are hidden before loading")
assert(closeButton.Visible,"close control stays usable while Larp content loads")
assert(inspect.Visible==true and not title.Visible and not itemContent.Visible and title.Text=="LarpAlias's Avatar","the native shell stays visible while old avatar and item content are quarantined")
inspect.Visible=true;inspect:GetPropertyChangedSignal("Visible"):Fire()
assert(inspect.Visible==true and not title.Visible and not itemContent.Visible,"native visibility updates cannot reveal quarantined content during loading")
local d=inspectCalls[1].description
assert(not d.destroyed,"native inspector must retain the description while asynchronous avatar and item loading use it")
assert(d.Head==304 and d.Pants==305 and #d.accessories==5,"head, pants and every equipped accessory reach the native description")
local nativeIds={};for _,item in ipairs(d.accessories)do nativeIds[item.AssetId]=true end
assert(nativeIds[200] and nativeIds[301] and nativeIds[302] and nativeIds[303] and nativeIds[306],"the full Larp accessory set survives native conversion")
assert(d.Shirt==100 and d.accessories[1].AssetId==200 and d.accessories[1].IsLayered and d.accessories[1].Order==3 and d.accessories[1].Puffiness==0.35,"clothing and layered accessory metadata are preserved")
assert(d.HeightScale==1.1 and d.WidthScale==0.9 and d.DepthScale==1.05 and d.HeadScale==1.2 and d.ProportionScale==0.4 and d.BodyTypeScale==0.7,"body scales are preserved")
assert(d.HeadColor.R==17/255 and d.HeadColor.G==34/255 and d.HeadColor.B==51/255,"body colors are converted")
title.Text="LarpAlias's Avatar";itemLabel.Text="Larp Shirt";title:GetPropertyChangedSignal("Text"):Fire();flushDeferred()
assert(liveOverlay() and liveOverlay().Visible,"the alias-ready signal renders the preview without waiting for another relay poll")
assert(skeleton.Visible and #nativeList.children==1,"native loading cards remain untouched; no custom item list is injected")
api.update({enabled=true,name="LarpAlias",snapshot=snapshot});assert(#inspectCalls==1,"adopting the redirected title does not reopen in a loop")
assert(inspect.Visible==true,"the panel reveals only after its Larp title and local preview are ready")
assert(title.Visible and itemContent.Visible,"the redirected title and refreshed item content appear only after adoption")
inspect.Visible=false
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
inspect.Visible=true
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(#inspectCalls==1,"temporary hiding during native remount must not restart inspection")
-- React can replace the heading instance without changing the inspected player.
local oldTitle=title;oldTitle.Parent=nil;oldTitle.Visible=false
for i,v in ipairs(inspect.children)do if v==oldTitle then table.remove(inspect.children,i);break end end
title=child(inspect,"TextLabel","HeaderText");title.Text="LarpAlias's Avatar";core.DescendantAdded:Fire(title)
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(liveOverlay() and liveOverlay().Visible and previewGui().Enabled,"a remounted alias heading must keep the own avatar rendering")

assert(liveOverlay().Parent==previewGui() and liveOverlay().Position[1]==111 and liveOverlay().Position[2]==222,"local preview matches native screen bounds outside its layout")
-- Roblox can hide the whole native 3D container while its model loads.
local nativeContainer=child(inspect,"Frame","ViewportContainer");nativeContainer.Visible=false;nativeContainer.AbsolutePosition={X=100,Y=200}
inspect.AbsolutePosition={X=100,Y=200}
for i,v in ipairs(inspect.children)do if v==viewport then table.remove(inspect.children,i);break end end
viewport.Parent=nativeContainer;nativeContainer.children[#nativeContainer.children+1]=viewport
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(liveOverlay().Parent==previewGui() and liveOverlay().Visible,"the replacement must escape Roblox's hidden 3D container")
assert(liveOverlay().Position[1]==111 and liveOverlay().Position[2]==222,"the replacement keeps the native screen position")
local inner=child(inspect,"Frame","InnerView")
local thumbSlot=child(inner,"Frame","Thumbnail");thumbSlot.AbsolutePosition={X=400,Y=300};thumbSlot.AbsoluteSize={X=250,Y=250}
local thumbImage=child(thumbSlot,"ImageLabel","ImageLabel");thumbImage.ImageTransparency=0
previewGui().AbsolutePosition={X=0,Y=-58}
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(liveOverlay().Position[1]==400 and liveOverlay().Position[2]==358 and liveOverlay().Size[1]==250,"native thumbnail bounds include the CoreGui inset correction")
assert(thumbImage.ImageTransparency==1,"the native account thumbnail stays masked")
-- Item-card visibility is owned by the current native inspection bridge.
itemLabel.Text="Larp Shirt";boundGuard()
local assetThumb=child(itemContent,"ImageLabel","Thumbnail");assetThumb.Image="rbxthumb://type=Asset&id=100&w=150&h=150"
itemLabel.Text="Catalog name differs from local accessory name";boundGuard()
assert(itemContent.Visible,"owned asset IDs reveal cards even when their catalog names differ")
assetThumb.Image="rbxthumb://type=Asset&id=999&w=150&h=150";boundGuard()
assetThumb.Image="";itemLabel.Text="Larp Shirt";boundGuard()

-- Reopening an already-mounted native inspector must mask its viewport in the
-- Visible signal itself, before the render-step guard gets a chance to run.
inspect.Visible=false;inspect:GetPropertyChangedSignal("Visible"):Fire()
viewport.ImageTransparency=0;inspect.Visible=true;inspect:GetPropertyChangedSignal("Visible"):Fire()
assert(viewport.ImageTransparency==1,"opening an existing inspector masks the native avatar synchronously")
-- Native normalized descriptions must not keep the live Larp preview blank.
-- The focused regression below verifies the snapshot route directly.
api.update({enabled=true,name="LarpAlias",snapshot=snapshot})
assert(viewport.ImageTransparency==1,"the native account model remains hidden")
-- A ready item card must remain mounted while Roblox replaces its metadata.
assert(itemContent.Visible, 'matching item content begins visible')
local requestsBeforeLoading=#inspectCalls
for _,text in ipairs({'','Loading item','Catalog item','Larp Shirt'})do
 itemLabel.Text=text;itemLabel:GetPropertyChangedSignal('Text'):Fire();flushDeferred()
 assert(itemContent.Visible, 'ready item content must not flicker off during progressive metadata')
 advanceRecovery(0.3);flushDeferred()
 assert(#inspectCalls==requestsBeforeLoading, 'incomplete metadata must not reopen the inspector')
end
-- An explicit unrelated asset must still be hidden, rather than preserved.
local foreignImage=child(itemContent,'ImageLabel','Thumbnail')
foreignImage.Image='rbxthumb://type=Asset&id=999&w=150&h=150'
core.DescendantAdded:Fire(foreignImage)
itemLabel.Text='Foreign Hat';itemLabel:GetPropertyChangedSignal('Text'):Fire();flushDeferred()
assert(not itemContent.Visible, 'confirmed foreign assets must still be quarantined')
api.destroy()
print('PASS: progressive metadata preserves ready cards, avoids inspector reloads, and still hides foreign assets.')
