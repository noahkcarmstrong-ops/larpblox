-- Bounded, event-driven diagnostics in the executor workspace.
local Http=game:GetService("HttpService")
return function(context)
    local folder="logs/larp"
    local stamp=os.date("!%Y-%m-%d_%H-%M-%SZ").."_"..Http:GenerateGUID(false):sub(1,8)
    local latest=folder.."/latest.log"
    local part=1
    local limit=512*1024
    local pending,bytes,queued,closed={},0,false,false
    local size,buffer=0,""
    local warned=false
    local initialized=false
    local environment=type(getgenv)=="function" and getgenv() or _G
    if type(environment.larpblox)~="table" then environment.larpblox={} end
    if type(environment.larpblox.diagnostics)~="table" then environment.larpblox.diagnostics={} end
    if environment.larpblox.diagnostics.verbose==nil then environment.larpblox.diagnostics.verbose=false end
    local function verbose()
        local options=environment.larpblox
        return type(options)=="table" and type(options.diagnostics)=="table" and options.diagnostics.verbose==true
    end
    environment.__LarpbloxLatestLogSession=stamp
    local function initialize()
        if initialized then return end
        assert(type(writefile)=="function" and type(makefolder)=="function","File writing unavailable")
        for _,directory in ipairs({"logs",folder})do
            if type(isfolder)~="function" or not isfolder(directory)then
                local ok,err=pcall(makefolder,directory)
                if not ok and not(type(isfolder)=="function" and isfolder(directory))then error(err)end
            end
        end
        if type(readfile)=="function"then
            local ok,old=pcall(readfile,latest)
            if ok and type(old)=="string" and #old>0 then
                local archiveStamp=stamp
                local decoded,first=pcall(Http.JSONDecode,Http,old:match("[^\n]+") or "")
                if decoded and type(first)=="table" and type(first.at)=="number"then
                    archiveStamp=os.date("!%Y-%m-%d_%H-%M-%SZ",math.floor(first.at/1000)).."_"..Http:GenerateGUID(false):sub(1,8)
                end
                writefile(folder.."/"..archiveStamp..".log",old)
            end
        end
        writefile(latest,"")
        initialized=true
    end
    local function clean(value)
        if type(value)~="string"then return value end
        value=value:gsub("https?://%S+","[url]")
        value=value:gsub("[Bb]earer%s+[%w%._%-]+","Bearer [redacted]")
        return value:sub(1,768)
    end
    local function flush()
        queued=false
        if #pending==0 then return end
        local data=table.concat(pending);pending={};bytes=0
        local ok=pcall(function()
            if environment.__LarpbloxLatestLogSession~=stamp then return end
            initialize()
            if size+#data>limit then
                writefile(folder.."/"..stamp.."_"..tostring(part)..".log",buffer)
                part=part+1
                writefile(latest,"");size=0;buffer=""
            end
            buffer=buffer..data
            if type(appendfile)=="function"then appendfile(latest,data)
            else writefile(latest,buffer)end
            size=size+#data
        end)
        if not ok and not warned then warned=true;warn("Larpblox: diagnostic file could not be written.")end
    end
    local serial,active=0,{}
    local threadOperations=setmetatable({}, {__mode="k"})
    local lastState={}
    local function log(event,fields)
        if closed or type(writefile)~="function"then return end
        local record={at=DateTime.now().UnixTimestampMillis,event=event}
        for key,value in pairs(context or {})do record[key]=clean(value)end
        for key,value in pairs(fields or {})do
            if type(value)=="string" or type(value)=="number" or type(value)=="boolean"then record[key]=clean(value)end
        end
        if event=="status" or event=="desktop_connection"then
            local state=event=="status" and tostring(record.detail) or tostring(record.connected)
            if lastState[event]==state then return end
            lastState[event]=state
        end
        local ok,line=pcall(Http.JSONEncode,Http,record)
        if not ok then return end
        line=line.."\n";pending[#pending+1]=line;bytes=bytes+#line
        if bytes>=16384 then flush()
        elseif not queued then queued=true;task.defer(flush)end
    end
    local function stats(record)
        if not verbose() then return end
        local luaOk,luaMemory=pcall(gcinfo)
        if luaOk then record.luaMemoryKB=luaMemory end
        local ok,memory=pcall(function()return game:GetService("Stats"):GetTotalMemoryUsageMb()end)
        if ok then record.totalMemoryMB=memory end
        local countOk,count=pcall(function()return game:GetService("Stats").InstanceCount end)
        if countOk then record.instanceCount=count end
    end
    local function run(operation,fields,callback,...)
        if not verbose() and (operation=="MeshPart.ApplyMesh" or operation=="Humanoid.AddAccessory") then
            -- Keep normal diagnostics off hot per-part/per-accessory paths.
            -- Slow calls and failures remain useful without two disk flushes
            -- for every successful sub-millisecond mutation.
            local started=os.clock()
            local result=table.pack(pcall(callback,...))
            local elapsedMs=(os.clock()-started)*1000
            if not result[1] or elapsedMs>=16 then
                local record={operation=operation,elapsedMs=elapsedMs,ok=result[1]}
                for key,value in pairs(fields or {})do record[key]=value end
                if not result[1]then record.error=tostring(result[2])end
                log(result[1] and "operation_slow" or "operation_failed",record);flush()
            end
            if not result[1]then error(result[2],0)end
            return table.unpack(result,2,result.n)
        end
        serial=serial+1
        local id=stamp..":"..serial
        local record={operation=operation,operationId=id}
        for key,value in pairs(fields or {})do record[key]=value end
        local thread=coroutine.running()
        local parent=thread and threadOperations[thread]
        record.parentOperationId=parent
        if thread then threadOperations[thread]=id end
        local started=os.clock()
        active[id]={operation=operation,started=started}
        stats(record);log("operation_start",record);flush()
        local result=table.pack(pcall(callback,...))
        active[id]=nil
        if thread then threadOperations[thread]=parent end
        record.elapsedMs=math.floor((os.clock()-started)*1000*100)/100
        record.ok=result[1]
        if not result[1]then record.error=tostring(result[2])end
        stats(record);log("operation_finish",record);flush()
        if not result[1]then error(result[2],0)end
        return table.unpack(result,2,result.n)
    end
    log("session_start",{verbose=verbose(),sessionId=stamp})
    return {log=log,flush=flush,run=run,close=function()
        if closed then return end
        for id,entry in pairs(active)do
            log("operation_cancelled",{operationId=id,operation=entry.operation,elapsedMs=(os.clock()-entry.started)*1000,reason="interface_destroyed"})
        end
        log("session_end");flush();closed=true
    end,path=latest}
end
