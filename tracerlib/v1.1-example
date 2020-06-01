--@name Tracerlib V1.1 Example
--@author Vurv
--@client
--@include libs.tracer.txt
--@model models/dav0r/camera.mdl

Holo = holograms.create(Vector(),Angle(),"models/holograms/cube.mdl",Vector(0.5,0.5,0.5))
libs_tracer = require("libs.tracer.txt")
function dotrace(TraceObj,T)
    local X = TraceObj.x
    local Y = TraceObj.y
    local InitPos = TraceObj.pos
    local Dist = InitPos:getDistance(T.HitPos)/1000
    local SunDir,_ = game.getSunInfo()
    local Shading = T.HitNormal:dot(SunDir)
    Holo:setPos(T.HitPos)
    return (T.HitSky and Color(0,0,255) or (Color(255,255,255)*Shading))
end
function dofinish()
    print("finished!")
end

Active = false
libs_tracer.createTrace(1,Vector(64,64),dotrace,dofinish)
libs_tracer.setCamera(1,chip())
libs_tracer.showTrace(1,true)

hook.add("starfallUsed","",function(ply)
    if ply ~= player() then return end
    Active = not Active
    libs_tracer.toggleTrace(1,Active)
end)

hook.add("render","",function()
    if Active then
        while quotaTotalAverage()<quotaMax()*0.1 do
            libs_tracer.callTrace(1)
        end
    else
        render.drawText(256,256,"Press E To Render",1)
    end
end)
