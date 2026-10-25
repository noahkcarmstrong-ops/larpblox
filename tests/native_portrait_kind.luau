return function(source)
    local code=assert(source:match("    local function fullPortrait%(image%)(.-)    local function posePortrait"))
    local make=assert(loadstring([[return function()
        local nativeImageSources={}
        local function read(o,k)return o and o[k]end
        local function ancestors(o)local t={} while o do t[#t+1]=o;o=o.Parent end return t end
        local function fullPortrait(image)
    ]]..code..[[
        return fullPortrait
    end]]))()
    local full=make()
    local function image(name,url,parent,circle)
        return {Name=name,Image=url,Parent=parent,AbsoluteSize={X=48,Y=48},FindFirstChildOfClass=function()return circle and {CornerRadius={Scale=0.5}} or nil end}
    end
    assert(not full(image("AvatarThumbnail","https://tr.rbxcdn.com/opaque.png",{Name="PersonRow"})),"native People row CDN must be headshot")
    assert(not full(image("AvatarImage","https://tr.rbxcdn.com/peer.png",nil,true)),"circular peer portrait must be headshot")
    assert(not full(image("AvatarImage","rbxthumb://type=AvatarHeadShot&id=123")),"explicit own headshot retains camera")
    assert(not full(image("AvatarImage","rbxthumb://type=AvatarHeadShot&id=456")),"explicit peer headshot uses same camera")
    assert(full(image("AvatarImage","https://tr.rbxcdn.com/opaque.png",{Name="CardContent"})),"square People card keeps full body")
    assert(full(image("AvatarImage","https://tr.rbxcdn.com/body.png")),"ordinary full-body slot stays full body")
    assert(not full(image("Icon","https://www.roblox.com/headshot-thumbnail/image?userId=123&width=420")),"legacy game headshot URLs retain headshot framing")
    print("PASS: own/peer round portraits use headshot; square full-body slots preserved")
end
