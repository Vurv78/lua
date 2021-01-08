--@name Texture Collector v4.5
--@author Vurv
--@client

-- Texture Collector v4.5 by Vurv on Discord (363590853140152321)
-- Allows you to customize the pixel saving / file saving much more easily with an example of a compressed texture, that is ~200kb per 512x512 texture.
-- Takes ~80 seconds to save all of the textures in bigcity as these compressed 200kb text files (512x512 res). (~60MB)

if player() ~= owner() then return end

local CPUMax = 0.9 -- 0-1 as a percentage. Higher is more unstable without extra quota checks.
local FilePath = "textures/@.txt" -- @ will be replaced with the texture name.

local FindMatFunc = function(mat) -- Needs to return width and height
    return 512,512
end

-- locals for optimization
local render = render
local readPixel = render.readPixel
local format = string.format

local PixelFunc = function(r,g,b) -- Returns a string representing the r,g,b pixel. This will be pushed to the current pixels table which will be saved in the SaveFunc (unless you return false)
    return format("%c%c%c",r,g,b)
end

local SaveFunc = function(Pixels,Path) -- File saving function
    local data = fastlz.compress( table.concat(Pixels) )
    file.write(Path,data)
end

local Materials = {}

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
    local Started = timer.systime()
    local SurfaceInfo = find.byClass("worldspawn")[1]:getBrushSurfaces()
    local MaterialsFound = 0
    for K,V in pairs(SurfaceInfo) do
        local N = V:getMaterial():getName() -- Locked materials fucking useless !!!! omg!!
        quotaCheck()
        if not Materials[N] then Materials[N] = true MaterialsFound = MaterialsFound + 1 end
    end
    print(Color(50,255,255),format("Successfully found [%d] materials!!",MaterialsFound))
    print(Color(255,255,50),"Starting to load textures, look in console for more details")
    for Name in next,Materials do
        printMessage(2,"Loading mat"..Name.."\n")
        local FixedName = string.replace(Name,"/","_") -- We have to replace /'s since lua's file system uses forward slashes :v
        local Path = string.replace(FilePath,"@",FixedName)
        quotaCheck()
        if file.exists(Path) then print(Color(255,50,50),"Failed to load mat "..Name..", it already exists!") continue end
        usemat:setTexture("$basetexture",material.getTexture(Name,"$basetexture"))
        render.setMaterial(usemat)
        local Width,Height = FindMatFunc(usemat)
        render.selectRenderTarget("rt")
            render.drawTexturedRect(0,0,Width,Height)
            render.capturePixels()
        render.selectRenderTarget()
        local Pixels = {}
        for Y = 0,Height-1 do
            for X = 0,Width-1 do
                quotaCheck()
                local C = readPixel(X,Y)
                local V = PixelFunc(C.r,C.g,C.b)
                if V then Pixels[X+Y*Height+1] = V end
                quotaCheck()
            end
        end
        SaveFunc(Pixels,Path)
        print(Color(50,255,50),"Successfully saved file "..Path)
        Pixels = nil
        quotaCheck()
    end
    print("Finished in "..tostring(timer.systime()-Started).."s")
    return true
end

co = coroutine.create(main)

local coroutine = coroutine
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status

hook.add("renderoffscreen","",function()
    if coroutine_status(co) ~= "dead" then
        if canRun() then
            coroutine_resume(co)
        end
    end
end)
