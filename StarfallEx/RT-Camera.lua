--@name RT Camera
--@author Vurv
--@client
--@model models/dav0r/camera.mdl

-- Author -- Vurv
-- Source -- https://github.com/Vurv78/starfallex-creations
-- Purpose -- This is a starfall chip that works just like an RT camera, except you can configure the resolution, field of view/zooming, frames per second and more.
-- Tbh, It feels less laggier than actual RT Cameras and has better quality. You can have multiple of these placed down, they will share cpu but not really well after the second camera.


-- Disabled by default to prevent lag

-- Configs --
local FPS = 60                          -- Frames per second
local FOV = 130
local Res = Vector(1024,1024)           -- Default = 1024,1024 (This is the highest res you can get)
local AntiAliasing = true               -- Whether to use anti-aliasing in the render
local Enabled = false                   -- Whether to see the camera by default when Enabled
-- Configs --


-- Local vars to optimize stuff.
local localplayer = player() if localplayer ~= owner() then Enabled = false end
local framesRendered = 0
local deltatime = 0
local fpsdelta = 1/FPS
local fpstime = timer.curtime()
local Chip = chip()
local Screen
local ScaleMatrix = Matrix()
ScaleMatrix:setScale(1024/Res)

-- Localized functions for functions that'll be called often
local math = math
local render = render
local selectRenderTarget = render.selectRenderTarget
local renderViewsLeft = render.renderViewsLeft
local floor = math.floor
local min = math.min
local curtime = timer.curtime
local drawTexturedRect = render.drawTexturedRect
local pushMatrix = render.pushMatrix
local setRGBA = render.setRGBA
local drawText = render.drawText
local setMaterial = render.setMaterial
local renderView = render.renderView
local isInRenderView = render.isInRenderView
local getScreenEntity = render.getScreenEntity
local popMatrix = render.popMatrix
local setFilterMag = render.setFilterMag

render.createRenderTarget("rt")
-- We need a separate material so that the screen doesn't go black sometimes.
local rtMat = material.create("gmodscreenspace")
rtMat:setTextureRenderTarget("$basetexture", "rt")

hook.add("renderscene","",function(origin,angles,fov)
    -- Fps checking
    if not Enabled then return end
    if not Screen then return end
    if quotaTotalAverage()>quotaMax()*0.5 then return end -- Additional check so that people don't die from quota
    local time = curtime()
    if time < fpstime + fpsdelta then return end
    deltatime = time-fpstime
    fpstime = time
    
    if renderViewsLeft()<1 then print("No renderviews left") return end
    framesRendered = framesRendered + 1
    
    selectRenderTarget("rt")
        if isInRenderView() then
            drawText(256,256,"Nope",1)
            return
        end
        renderView{
            origin = Chip:localToWorld(Vector(10,0,0)),
            x = 0,
            y = 0,
            w = Res.x,
            h = Res.y,
            fov=FOV,
            angles=Chip:getAngles(),
            drawviewer = true,
        }
    selectRenderTarget()
end)

hook.add("starfallUsed","",function(ply)
    if localplayer ~= ply then return end
    Enabled = not Enabled
end)

hook.add("render","",function()
    setRGBA(0,255,255,255)
    Screen = getScreenEntity()
    drawText(256,256,"No infinite loop pl0x",1)
    setMaterial(rtMat)
    pushMatrix(ScaleMatrix)
    setRGBA(255,255,255,255)
    setFilterMag(AntiAliasing and 0 or 1)
    drawTexturedRect(0,0,512,512)
    popMatrix()
    if not Enabled then
        -- It's not in the beginning so we can still see the frame before atleast.
        setRGBA(255,255,0,255)
        drawText(256,256,"Press E to See RT Camera",1)
        return
    end
    drawText(0,0,"FPS: " .. min(floor(1/deltatime),60) .. "/" .. FPS)
end)
