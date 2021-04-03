--@name Texture Collector v2
--@author Vurv
--@client
-- Source: https://github.com/Vurv78/starfallex-creations/blob/master/StarfallEx/Texture%20Collector%20v2

-- Chip to save textures in R,G,B format uncompressed.
-- Change it as you see fit

if player() ~= owner() then return end

local CPUMax = 0.3 // 0-1 as a percentage.
local Running

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

local function main()
    local EyeTrace = trace.trace(player():getShootPos(),owner():getShootPos()+eyeVector()*60000,{player()},4294967295)
    -- We need a custom trace so we can define the mask to hit other stuff like water brushes
    local HitTex = EyeTrace.HitTexture
    if HitTex == "**studio**" then return end -- No props
    local Path = format("textures/%s.txt",string.replace(HitTex,"/","_"))
    if file.exists(Path) then print(Color(255,50,50),format("The file %s already exists.",Path)) return end
    Running = HitTex
    print(Color(50,255,50),"Loading texture "..HitTex)
    local mat = material.create("UnlitGeneric")
    mat:setTexture("$basetexture",material.getTexture(HitTex, "$basetexture"))
    mat:setInt("$flags",0) -- Regular version of the texture w/o removing alpha spots, so you see the texture as it actually is
    render.setMaterial(mat)
    render.selectRenderTarget("rt")
        render.drawTexturedRectFast(0,0,512,512)
        render.capturePixels()
        local ColorData = {}
        for X = 0,511 do
            for Y = 0,511 do
                quotaCheck()
                local Col = readPixel(X,Y)
                ColorData[X+Y*512+1] = format("%03d,%03d,%03d,",Col.r,Col.g,Col.b)
                quotaCheck()
            end
        end
        render.clear(Color(1,2,3)) // Transparency code
    mat:destroy()
    file.write(Path,string.sub(table.concat(ColorData,""),1,-2))
    print(Color(50,250,250),format("Saved texture %s to path %s",HitTex,Path))
    ColorData = nil
    Running = nil
end

hook.add("inputPressed","",function(b)
    if b == KEY.E then
        if Running then
            print(Color(250,250,50),format("You are already loading a texture, %s. Please wait!",Running))
        else
            co = coroutine.create(main)
        end
    end
end)

hook.add("renderoffscreen","",function()
    if not co then return end -- Hasn't pressed E yet
    if coroutine.status(co) ~= "dead" then
        if canRun() then
            coroutine.resume(co)
        end
    end
end)
