--@name libs.tracer
--@author Vurv
--@shared
if SERVER then
    // to do
else
    local DoDebug
    libs_tracer = { data = { rts = {} } }
    libs_tracer.setDebug = function(Mode)
        // Mode 0 = off, 1 = functions being called , 2 = all/intense
        DoDebug = Mode or 0
    end
    libs_tracer.createTrace = function(Index,Res,Tracing,Done)
        // Does not need a tracing function, you can call it yourself.
        assert(type(Done)=="function","Needs a finish trace function.")
        local rttab = libs_tracer.data.rts
        local def_entity = chip()
        Index = type(Index)=="Number" and Index or (#rttab+1)
        local traceobj = {
            res = type(Res)=="Vector" and Res or Vector(512,512),
            index = Index,
            ent = def_entity,
            ang = def_entity:getAngles(),
            pos = def_entity:getPos(),
            tracefunc = Tracing,
            donefunc = Done,
            tracing = false,
            finished = false,
            showing = false,
            scale = Res/1024,
            x = 0,
            y = 0,
        }
        traceobj.trace = function(InputColor)
            local X = traceobj.x
            local Y = traceobj.y
            if X >= (Res.x-1) then
                if Y >= Res.y-1 then finished = true donefunc() end
                traceobj.y = (Y + 1)%Res.y
            end
            traceobj.x = (X + 1)%Res.x
            local Pos = traceobj.pos
            local Dir = Vector(100,-X+Res.x/2,-Y+Res.y/2 ):getRotated(traceobj.ang):getNormalized()
            local ActualTrace = trace.trace(Pos,Pos+Dir*60000,{traceobj.ent})
            render.setColor(InputColor)
            local Scale = traceobj.scale
            render.drawRectFast(X*Scale.x,Y*Scale.y,Scale.x,Scale.y)
        end
        render.createRenderTarget("libs.tracer_"..Index)
        rttab[Index] = traceobj
        return true
    end
    
    libs_tracer.setCamera = function(Ind,Ent)
        // Sets an indexed raytrace to a 'camera' object. Returns true/false whether this went through successfully.
        if not Ind then return false end
        local loctab = libs_tracer.data.rts[Ind]
        if loctab==nil then return false end
        if not Ent:isValid() then return false end
        loctab.ent = Ent
        loctab.ang = Ent:getAngles()
        loctab.pos = Ent:getPos()
        return true
    end
    libs_tracer.toggleTrace = function(Ind,Bool)
        if not Ind then return false end
        libs_tracer.data.rts[Ind].tracing = (Bool or false)
        return true
    end
    
    libs_tracer.showTrace = function(Ind,Bool)
        if not Ind then return false end
        libs_tracer.data.rts[Ind].showing = (Bool or false)
    end
    
    libs_tracer.callTrace = function(Ind)
        // Calls a trace to be rendered. If you want to use while loops etc.
        // Returns: success or failure (bool)
        local TraceData = libs_tracer.data.rts[Ind]
        if TraceData == nil then return false end
        if TraceData.finished then return false end
        local Res = TraceData.res
        local ScaleFactor = (1024/Res)
        render.selectRenderTarget("libs.tracer_"..Ind)
            local X = TraceData.x
            local Y = TraceData.y
            if X >= (Res.x-1) then
                if Y >= Res.y-1 then TraceData.finished = true TraceData.donefunc(Object) end
                TraceData.y = (Y + 1)%Res.y
            end
            TraceData.x = (X + 1)%Res.x
            local Pos = TraceData.pos
            local Dir = Vector(100,-X+Res.x/2,-Y+Res.y/2 ):getRotated(TraceData.ang):getNormalized()
            local ActualTrace = trace.trace(Pos,Pos+Dir*60000,{TraceData.ent})
            render.setColor(dotrace(TraceData,ActualTrace))
            render.drawRectFast(X*ScaleFactor.x,Y*ScaleFactor.y,ScaleFactor.x,ScaleFactor.y)
        render.selectRenderTarget()
        return true
    end
    
    hook.add("renderoffscreen","libs.tracer_renderoffscreen",function()
        local Traces = libs_tracer.data.rts
        for K,TraceData in pairs(Traces) do
            Executions = 0
            if TraceData.finished then continue end
            if not TraceData.tracing then continue end
            local Res = TraceData.res
            local Scale = (1024/Res)
            libs_tracer.callTrace(K)
        end
    end)
    
    hook.add("render","libs.tracer_render",function()
        local Traces = libs_tracer.data.rts
        for K,TraceData in pairs(Traces) do
            if TraceData.showing then
                // Only show the first result, as showing multiple kinda lame..
                render.setRenderTargetTexture("libs.tracer_"..K)
                render.drawTexturedRectFast(0,0,512,512)
                break
            end
        end
    end)
    return libs_tracer
end
