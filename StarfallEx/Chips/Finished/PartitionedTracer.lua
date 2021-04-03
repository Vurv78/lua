--@name Raytracer Partitioning
--@author Vurv
--@shared
--@model models/maxofs2d/camera.mdl

-- Don't remember if I broke this.
-- It divides the screen into n of players on the server and makes them all raytrace that part of the screen.
-- As they render, their data is sent to the rest of the clients to sync together.

local Res = 256
local SendPixelSpeed = 0.8 -- Interval between sending pixels to clients
local CPU_CL = 0.1 -- 1-0
local CPU_SV = 0.5
local RAM_MAX_PIXELS = 500 -- Max pixels to save on your client while waiting for them to network. [ 511 Max ]
local Blacklist = {}
-- Blacklist people if they disable SF / have bad pcs.
--Blacklist[find.playersByName("lame",false,false)[1]] = true
local Plys = find.allPlayers(function(p) return (not p:isBot() and not Blacklist[p]) end)
local format = string.format

local function canContinue()
    return quotaTotalAverage()<quotaMax()*(CLIENT and CPU_CL or CPU_SV)
end

if SERVER then
    local SavedPixels = {} -- Can just have a general table
    for K,Ply in pairs(SavedPixels) do SavedPixels[Ply] = {} end
    timer.create("sendPixels_cl",SendPixelSpeed,0,function() 
        -- Writing Color costs 32 bits
        -- Writing X and Y costs 22 bits total (11 each)
        -- Need 54 bits
        for Sender,Tab in pairs(SavedPixels) do
            if #Tab<1 then continue end
            local bitsLeft = net.getBitsLeft()
            if bitsLeft<54 then return end
            local pixelsCanSend = math.min(bitsLeft/54,RAM_MAX_PIXELS/#Plys)
            local pixelsToDo = math.min(#Tab,pixelsCanSend)
            net.start("getPixels_cl")
                net.writeUInt(pixelsToDo,9) -- 511 Max
                for _ = 1,pixelsToDo do
                    local T = table.remove(Tab,1)
                    -- {X,Y,Color}
                    net.writeUInt(T[1],10)
                    net.writeUInt(T[2],10)
                    net.writeColor(T[3])
                end
            local t = {unpack(Plys)}
            table.removeByValue(t,Sender)
            net.send(t)
        end
    end)
    net.receive("sendPixels_sv",function(len,ply)
        local Count = net.readUInt(9)
        --print(format("Received [%d] pixels from %s!",Count,ply:getName()))
        for K = 1,Count do
            local T = {net.readUInt(10),net.readUInt(10),net.readColor()}
            local PlyTab = SavedPixels[ply] or {}
            table.insert(PlyTab,T)
            SavedPixels[ply] = PlyTab
        end
    end)
    
    hook.add("Removed","Cleanup",function()
        SavedPixels = nil
        Plys = nil
    end)
else
    if Blacklist[player()] then return end
    HasInitScreen = false
    render.createRenderTarget("rt")
    local ID = 0
    for K,Ply in pairs(Plys) do
        if Ply==player() then ID = K-1 end
    end
    local PartitionScale = Res/#Plys
    local PartitionYMin = ID*PartitionScale
    local PartitionYMax = (ID+1)*PartitionScale
    
    local RenderReceive = {}
    local RenderToSend = {}
    local ScaleMatrix = Matrix()
    ScaleMatrix:setScale(Vector(1024/Res))
    
    net.receive("getPixels_cl",function()
        local Count = net.readInt(9) -- Max 255
        for K = 1,Count do
            table.insert(RenderReceive,{net.readInt(11),net.readInt(11),net.readColor()})
        end
        --print(format("Received [%d] pixels!",Count))
    end)
    
    local Pos = chip():getPos()
    local SunDir = game.getSunInfo()
    local function toWorldAxis(Ent,Dir)
        return Ent:worldToLocal(Dir)-Ent:getPos()
    end
    local function doPartition()
        for X = 0,Res do
            for Y = PartitionYMin,PartitionYMax do
                if #RenderToSend>RAM_MAX_PIXELS then coroutine.yield() end -- Don't keep too many elements to save ram
                if not canContinue() then coroutine.yield() end
                local Dir = Vector(0.1,X/Res-0.5,-Y/Res-0.5):getRotated(chip():getAngles())
                --if player() == owner() then holograms.create(Pos+Dir*30,Angle(),"models/holograms/cube.mdl",Vector(1)) end
                local Trace = trace.trace(Pos,Pos+Dir*60000,{chip()})
                --if player() == owner() then holograms.create(Trace.HitPos,Angle(),"models/holograms/cube.mdl",Vector(1)) end
                local Col = Trace.HitSky and Color(0,0,255) or Color(255,255,255)*(Trace.HitNormal:dot(SunDir)+1)/2
                Col[4] = 255
                render.selectRenderTarget("rt")
                    render.setColor(Col)
                    render.drawRectFast(X,Y,1,1)
                render.selectRenderTarget()
                if not canContinue() then coroutine.yield() end
                table.insert(RenderToSend,{X,Y,Col})
            end
        end
        return true
    end
    local doOwnPartition = coroutine.create(doPartition)
    
    timer.create("sendPixels_sv",SendPixelSpeed,0,function() 
        -- Writing Color costs 32 bits
        -- Writing X and Y costs 22 bits total (11 each)
        -- Need 54 bits
        if #RenderToSend<1 then return end
        local bitsLeft = net.getBitsLeft()
        if bitsLeft<54 then return end
        local pixelsCanSend = math.min(bitsLeft/54,255)
        local pixelsToDo = math.min(#RenderToSend,pixelsCanSend)
        net.start("sendPixels_sv")
            net.writeInt(pixelsToDo,9)
            for _ = 1,pixelsToDo do
                local T = table.remove(RenderToSend,1)
                -- {X,Y,Color}
                net.writeInt(T[1],11)
                net.writeInt(T[2],11)
                net.writeColor(T[3])
            end
        net.send()
    end)
    
    hook.add("renderoffscreen","initRT",function()
        HasInitScreen = true
        render.selectRenderTarget("rt")
            local ColRatio = 360/#Plys
            for K,Ply in pairs(Plys) do
                K = K - 1
                render.setColor(Color(K*ColRatio,1,1):hsvToRGB())
                render.drawRectOutline(0,K*PartitionScale,Res,PartitionScale+1)
                render.setColor(Color(255,255,255))
                render.drawText(Res/2,(K+0.5)*PartitionScale,Ply:getName(),1)
            end
        render.selectRenderTarget()
        hook.remove("renderoffscreen","initRT")
    end)
    
    hook.add("renderoffscreen","doOwnPartition",function()
        if not HasInitScreen then return end
        if coroutine.status(doOwnPartition) ~= "dead" then
            if canContinue() then
                local res = coroutine.resume(doOwnPartition)
                if res then hook.remove("renderoffscreen","doOwnPartition") end
            end
        end
    end)
    
    hook.add("renderoffscreen","pushPixels",function()
        if #RenderReceive<1 then return end
        render.selectRenderTarget("rt")
        for K,Pix in pairs(RenderReceive) do
            render.setColor(Pix[3])
            render.drawRectFast(Pix[1],Pix[2],1,1)
            RenderReceive[K] = nil
        end
        render.selectRenderTarget()
    end)
    hook.add("render","",function()
        render.setFilterMag(1)
        render.pushMatrix(ScaleMatrix)
        render.setRenderTargetTexture("rt")
        render.drawTexturedRect(0,0,512,512)
    end)
    hook.add("EntityRemoved","CL_Cleanup",function(e)
        if e~=chip() then return end
        RenderReceive = nil
        doOwnPartition = nil
        RenderToSend = nil
        Plys = nil
        PartitionScale = nil
        ScaleMatrix = nil
        PartitionYMin = nil
        PartitionYMax = nil
    end)
end