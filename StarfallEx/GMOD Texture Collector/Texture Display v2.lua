--@name Texture Displayer V2
--@author Vurv
--@client

-- Source: https://github.com/Vurv78/starfallex-creations
-- A chip to display textures saved by the Texture Collector v2 chip.
-- Edit as you see fit

if player() ~= owner() then return end

local PATH = "textures/de_cbble_grassfloor01.txt"
local QUOTA = 0.2 -- 20% of your clientside quota

render.createRenderTarget("rt")

local function canRun()
    return quotaTotalAverage()<quotaMax()*QUOTA
end

local function main()
    if not canRun() then coroutine.yield() end
    local Data = string.split(file.read(PATH),",")
    for K = 0,#Data/3 do
        local X = (K)%512
        local Y = (K)/512
        local C = Color( tonumber(Data[K*3+1]) , tonumber(Data[K*3+2]) , tonumber(Data[K*3+3]) )
        if not canRun() then coroutine.yield() end
        render.selectRenderTarget("rt")
            render.setColor(C)
            render.drawRectFast(X,Y,1,1)
        render.selectRenderTarget()
    end
end

co = coroutine.create(main)

hook.add("renderoffscreen","",function()
    if coroutine.status(co) ~= "dead" then
        if canRun() then
            res = coroutine.resume(co)
            if res then hook.remove("renderoffscreen","") end
        end
    end    
end)

hook.add("render","",function()
    render.setRenderTargetTexture("rt")
    render.setRGBA(255,255,255,255)
    render.setFilterMag(1)
    render.drawTexturedRect(128,128,512,512)
end)
