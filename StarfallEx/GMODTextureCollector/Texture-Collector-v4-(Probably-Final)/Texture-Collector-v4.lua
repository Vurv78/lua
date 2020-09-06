--@name Texture Collector v4
--@author Vurv
--@client
--@include modules/png.txt

-- Texture Collector v4 by Vurv on Discord (363590853140152321)
-- Allows you to customize the pixel saving / file saving much more easily with a PNG example.
-- PNG File will be included
-- Source: https://github.com/Vurv78/starfallex-creations/

-- TODO: Find out what causes some textures to return a weird getWidth and getHeight that doesn't match with their actual size.

if player() ~= owner() then return end

local CPUMax = 0.9 -- 0-1 as a percentage. Higher is more unstable without extra quota checks.
local Extension = ".png" -- What to save the file extension as, in this case we can save as .png

local encode = require("modules/png.txt")
local FindMatFunc = function(mat) -- Needs to return width and height
    local w,h = 512,512 -- For some reason getWidth and getHeight are returning 256..??
    Png = encode(w,h)
    return w,h
end
local PixelFunc = function(r,g,b) -- PNG Pixel saving function
    Png:write{r,g,b}
    return false -- Return false to not save the in the "Pixels" array (Unrelated to pngs, so we don't need to save)
end
local SaveFunc = function(Pixels,Path) -- PNG File saving Function
    local F = file.open(Path,"wb")
        F:write(table.concat(Png.output))
    F:close()
end

local Materials = {}
local Png -- Not assigned until a texture is found

-- locals
local readPixel = render.readPixel
local format = string.format

-- init
file.createDir("textures")
render.createRenderTarget("rt")

local function canRun()
    return quotaTotalAverage()<quotaMax()*CPUMax
end

local function quotaCheck()
    if not canRun() then coroutine.yield() end
end

local usemat = material.create("UnlitGeneric")
usemat:setInt("$flags",0)

local function main()
    local Started = timer.curtime()
    local SurfaceInfo = find.byClass("worldspawn")[1]:getBrushSurfaces()
    for K,V in pairs(SurfaceInfo) do
        local N = V:getMaterial():getName() -- Locked materials fucking useless !!!! omg!!
        quotaCheck()
        if not Materials[N] then Materials[N] = true end
    end
    print(Color(50,255,255),format("Successfully found [%d] materials!!",table.count(Materials)))
    print(Color(255,255,50),"Starting to load textures, look in console for more details")
    for Name in next,Materials do
        printMessage(2,"Loading mat"..Name.."\n")
        local Path = format("textures/%s"..(Extension or ".txt"),string.replace(Name,"/","_"))
        quotaCheck()
        if file.exists(Path) then print(Color(255,50,50),"Failed to load mat "..Name..", it already exists!") continue end
        usemat:setTexture("$basetexture",material.getTexture(Name,"$basetexture"))
        render.setMaterial(usemat)
        render.selectRenderTarget("rt")
            render.drawTexturedRect(0,0,512,512)
            render.capturePixels()
        render.selectRenderTarget()
        local Pixels = {}
        local Width,Height = FindMatFunc(usemat)
        for Y = 0,Height-1 do -- This does Y,X so our PNG's don't end up sideways, change to be reverse if you want to do your own filetype.
            for X = 0,Width-1 do
                quotaCheck()
                local C = readPixel(X,Y)
                local V = PixelFunc(C.r,C.g,C.b)
                if V then Pixels[X+Y*512+1] = V end
                quotaCheck()
            end
        end
        SaveFunc(Pixels,Path)
        print(Color(50,255,50),"Successfully saved file "..Path)
        Pixels = nil
        quotaCheck()
    end
    print("Finished in "..tostring(timer.curtime()-Started).."s")
    return true
end

co = coroutine.create(main)

hook.add("renderoffscreen","",function()
    if coroutine.status(co) ~= "dead" then
        if canRun() then
            coroutine.resume(co)
        end
    end
end)
