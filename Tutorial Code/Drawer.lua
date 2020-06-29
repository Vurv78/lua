--@name Tiny Drawer
--@author Vurv
--@client

Res = 512
X,Y = 0,0

function canRun()
    return quotaTotalAverage()<quotaMax()*0.05
end

render.createRenderTarget("rt")
function loadRender()
    while canRun() do
        render.selectRenderTarget("rt")
        if not canRun() then return end -- Return nil, which will make the coroutine wait for the next render tick
        render.setRGBA(math.random(1,255),math.random(1,255),math.random(1,255),255)
        render.drawRectFast(X,Y,1,1)
        X = (X+1)%Res
        if X==0 then Y = (Y+1)%Res if Y==0 then return true end end
        render.selectRenderTarget()
    end
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
            if res then finishRender() hook.remove("renderoffscreen","") end
        end
    else
        co = coroutine.create(loadRender)
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