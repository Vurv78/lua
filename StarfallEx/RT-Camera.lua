--@name RT Camera
--@author Vurv
--@client
--@model models/dav0r/camera.mdl

--[[
    Source: https://github.com/Vurv78/lua
    Desc:
        Better quality and higher FPS RT Camera than actual addons, even with the overhead that SF has.

        Disabled for anyone but owner by default to prevent lag.
        Although this only uses ~500us even with 60fps 1024x1024.
        
        Hyperoptimized, most of these optimizations are unrealistic but if you want to see how far you can optimize an SF chip,
        here's your example.
]]

-- Configs --
local FPS = 60
local FOV = 130
local Res = Vector(1024, 1024)           -- Default = 1024,1024 (This is the highest res you can get)
local AntiAliasing = true               -- Whether to use anti-aliasing in the render
local Enabled = true                    -- Whether to see the camera by default when Enabled (for owner)
local ZeroUs = true                     -- Whether to show the disabled screen or not. (If not, the chip will use 0 us when disabled)
-- Configs --


-- Local vars to optimize stuff.
local localplayer = player() if localplayer ~= owner() then Enabled = false end
local deltatime = 0
local fpsdelta = 1/FPS
local fpstime = timer.curtime()
local Chip = chip()
local ScaleMatrix = Matrix()
ScaleMatrix:setScale(1024/Res)

-- Localized functions for functions that'll be called often
local selectRenderTarget = render.selectRenderTarget
local renderViewsLeft = render.renderViewsLeft
local floor = math.floor
local min = math.min
local curtime = timer.curtime
local drawTexturedRect = render.drawTexturedRect
local pushMatrix = render.pushMatrix
local setRGBA = render.setRGBA
local drawSimpleText = render.drawSimpleText
local setMaterial = render.setMaterial
local renderView = render.renderView
local isInRenderView = render.isInRenderView
local popMatrix = render.popMatrix
local setFilterMag = render.setFilterMag

render.createRenderTarget("rt")
-- We need a separate material so that the screen doesn't go black sometimes.
local rtMat = material.create("gmodscreenspace")
rtMat:setTextureRenderTarget("$basetexture", "rt")

local RequestingFrames = true -- So we only render the camera when we are looking at the screen

local RViewTbl = {
    x = 0, y = 0,
    w = Res.x,
    h = Res.y,
    fov = FOV,
    drawviewer = true
}

local SLIGHTLY_FORWARD = Vector(10, 0, 0)

local ENT_METHODS = getMethods("Entity")
local getAngles = ENT_METHODS.getAngles
local localToWorld = ENT_METHODS.localToWorld

local function renderScene(origin, angles, fov)
    -- Additional check so that people don't die from quota
    local time = curtime()
    if time < fpstime + fpsdelta then return end
    deltatime = time - fpstime
    fpstime = time

    selectRenderTarget("rt")        
        RViewTbl.angles = getAngles( Chip )
        RViewTbl.origin = localToWorld( Chip, SLIGHTLY_FORWARD )
        renderView ( RViewTbl )
    selectRenderTarget()
end

local function enabledRender()
    setMaterial(rtMat)
    pushMatrix(ScaleMatrix)
        setFilterMag(AntiAliasing and 0 or 1)
        drawTexturedRect(0, 0, 512, 512)
    popMatrix()

    drawSimpleText(0, 0, "FPS: " .. min( floor(1 / deltatime), FPS) .. "/" .. FPS )
end

local disabledRender
if not ZeroUs then
    function disabledRender()
        -- This single function call costs ~120 us :)
        drawSimpleText(256, 256, "Press E to See RT Camera", 1, 1)
    end
end

if Enabled then
    hook.add("renderscene", "", renderScene)
    hook.add("render", "", enabledRender)
elseif not ZeroUs then
    hook.add("render", "", disabledRender)
end

hook.add("starfallUsed","",function(ply)
    if localplayer ~= ply then return end

    Enabled = not Enabled
    if Enabled then
        hook.add("renderscene", "", renderScene) 
        hook.add("render", "", enabledRender)
    else
        hook.remove("renderscene", "")
        
        if ZeroUs then
            hook.remove("render", "")
        else
            hook.add("render", "", disabledRender)
        end
    end
end)
