-- Focused copy of the production definitionKey helper; Fengari's sandbox has
-- no file I/O, so the test stays runnable offline.
local function definitionKey(definition)
    local ids,styles,values={},{},{}
    for _,asset in ipairs(definition.assets or {})do
        ids[#ids+1]=asset.id
        styles[asset.id]=asset.meta and asset.meta.smokestackStyle or ""
    end
    table.sort(ids)
    for _,id in ipairs(ids)do values[#values+1]=tostring(id);values[#values+1]=tostring(styles[id] or "")end
    return table.concat(values,"|")
end

local function key(style,reverse)
    local assets={
        {id=169444515,meta=style and {smokestackStyle=style} or nil},
        {id=42,meta={}},
    }
    if reverse then assets[1],assets[2]=assets[2],assets[1] end
    return definitionKey({assets=assets,bodyColors={},scales={}})
end

assert(key("halloween")~=key("christmas"),"seasonal style changes the definition key")
assert(key("halloween")==key("halloween"),"same seasonal style keeps a stable definition key")
assert(key("halloween")==key("halloween",true),"asset order does not change the definition key")
assert(key(nil)~=key("halloween"),"default and seasonal styles remain distinct")
print("Smokestack definition key metadata checks passed.")
