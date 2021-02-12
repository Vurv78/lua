--@name PNG Library Example 2
--@author Vurv
--@client
--@include pnglib.txt

if player() ~= owner() then return end

local createPNG = require("pnglib.txt")

local function canRun()
    return quotaTotalAverage() < quotaMax()*0.4
end

local main_routine = coroutine.create(function()
    render.createRenderTarget("rt")
    render.selectRenderTarget("rt")
    local png = createPNG(512, 512, "rgb") -- Create the png
    local to_col = 255/512
    -- Make sure you don't write RGB that goes over 255. At worst it might break the image, best it'll just write black pixels.
    for Y = 0,511 do
        for X = 0,511 do
            render.setRGBA(X * to_col,Y * to_col,0,255)
            png:writeRGB(X * to_col,Y * to_col,0)
            render.drawRectFast(X,Y,1,1)
            if not canRun() then
                coroutine.yield()
                render.selectRenderTarget("rt") -- Re-select the RT when we continue
            end
        end
    end
    print("Finished drawing.")
    png:export("bruh.png")
end)

hook.add("renderoffscreen","",function()
    if canRun() then
        if coroutine.status(main_routine) ~= "dead" then
            coroutine.resume(main_routine)
        end
    end
end)

hook.add("render","",function()
    render.setRenderTargetTexture("rt")
    render.drawTexturedRect(0,0,1024,1024)
end)