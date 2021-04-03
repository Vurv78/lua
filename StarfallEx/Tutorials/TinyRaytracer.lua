--@name Tiny Tracer
--@author Vurv
--@model models/dav0r/camera.mdl
--@client

local Res = 64
local X,Y = 0,0
local Filter = {chip()}

-- Local variables so we don't have to access the global table a lot
local render = render
local trace = trace
local Color = Color
local selectRenderTarget = render.selectRenderTarget
local traceline = trace.trace
local setColor = render.setColor
local drawRectFast = render.drawRectFast

function canRun()
    return quotaTotalAverage()<quotaMax()*0.4
end

render.createRenderTarget("rt")
function loadRender()
    local Pos = chip():getPos()
    local SunDir = game.getSunInfo()
    local Ang = chip():getAngles()
    for Y=0,Res-1 do
        for X=0,Res-1 do
            -- We must select the rt in here because we will exit the coroutine and select other rts when actually rendering the scene to the screen
            local Dir = Vector(1,1-(X/Res)-0.5,1-(Y/Res)-0.5):getRotated(Ang):getNormalized()
            local Trace = traceline(Pos,Pos+Dir*60000,Filter)
            local Shading = Trace.HitNormal:dot(SunDir)
            local Col = Color(255,255,255)*Shading
            Col[4] = 255
            selectRenderTarget("rt") -- Select RT
                setColor(Col)
                drawRectFast(X,Y,1,1)
            selectRenderTarget() -- Unselect RT
            if not canRun() then coroutine.yield() end
        end
    end
    finishRender()
    return true
end

function finishRender()
    print("Finished Render!")
    X,Y = 0,0
end

co = coroutine.create(loadRender)

hook.add("renderoffscreen","",function()
    if coroutine.status(co) ~= "dead" then
        if canRun() then
            local res = coroutine.resume(co) -- Result of the function
            if res then hook.remove("renderoffscreen","") end
        end
    else
        hook.remove("renderoffscreen","")
    end
end)

local ScaleMatrix = Matrix()
ScaleMatrix:setScale(Vector(1024/Res))

hook.add("render","",function()
    render.setFilterMag(1)
    render.pushMatrix(ScaleMatrix)
    render.setRenderTargetTexture("rt")
    render.drawTexturedRect(0,0,512,512)
end)
