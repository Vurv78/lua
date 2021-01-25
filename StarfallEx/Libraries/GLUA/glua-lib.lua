--@name GLUA Library
--@author Vurv
--@shared

-- Attempts to port all of the gmod lua functions (in namesake) to starfall by painfully putting them in a table and applying that to _G

-- All functions will be shared for now, just won't do anything on their non-respective realms

local apply_global = true -- Apply the libraries to _G or keep them exclusively to glua
local dummy_function = function(...) local a = {...} return function() return unpack(a) end end
local dum_vec = Vector()
local wrap_function = function(realm,f) if realm then return f else return dummy_function() end end
local local_format = string.format

local world_spawn = find.byClass("worldspawn")[1]

local glua = {}

-- string meta

-- you can't change string metatable in starfall, scrap this and just change the string table directly :/
-- TODO
local str_meta = getMethods("string")
str_meta.StartWith = function(self,start)
    return self:sub(1,#Start) == start
end
str_meta.EndsWith = function(self,End)
    return End == "" or self:sub(-#End) == End
end

-- util library
local util = {
    AddNetworkString = dummy_function(),
    AimVector = dummy_function(Vector()), -- TODO
    Base64Decode = http.base64Decode,
    Base64Encode = http.base64Encode,
    BlastDamage = dummy_function(),
    BlastDamageInfo = dummy_function(),
    Compress = fastlz.compress,
    CRC = crc,
    DateStamp = function()
        local t = os.date("*t")
        return local_format( "%d-%d-%d %02i-%02i-%02i", t.year, t.month, t.day, t.hour, t.min, t.sec)
    end,
    Decal = trace.decal,
    DecalEx = dummy_function(),
    DecalMaterial = dummy_function("bruh"),
    Decompress = fastlz.decompress,
    DistanceToLine = dummy_function(1,Vector(),1), -- TODO
    Effect = dummy_function(), -- TODO
    GetModelInfo = dummy_function{},
    GetModelMeshes = mesh.getModelMeshes,
    GetPData = wrap_function(CLIENT,function(steamid,name,default)
        name = local_format( "%s[%s]", crc( "gm_" .. steamid .. "_gm" ), name )
        local val = sql.query( "SELECT value FROM playerpdata WHERE infoid = " .. sql.SQLStr( name ) .. " LIMIT 1" )
        return val or default
    end),
    GetPixelVisibleHandle = dummy_function(),
    GetPlayerTrace = function(ply,dir)
        dir = dir or ply:getAimVector()
        local eye = ply:getEyePos()
        return {
            start = eye,
            endpos = eye + dir * 32768,
            filter = ply
        }
    end,
    GetSunInfo = function()
        local t = {}
        t.direction,t.obstruction = game.getSunInfo()
        return t
    end,
    GetSurfaceData = dummy_function{},
    GetSurfaceIndex = dummy_function(1),
    GetSurfacePropName = dummy_function"",
    GetUserGroups = dummy_function{},
    IntersectRayWithOBB = dummy_function(dum_vec,dum_vec,1),
    IntersectRayWithPlane = dummy_function(dum_vec),
    IsInWorld = function(v) return v:isInWorld() end,
    IsModelLoaded = dummy_function(true),
    IsSkyboxVisibleFromPoint = dummy_function(true),
    IsValidModel = function(model) -- TODO MORE
        local bl = string.explode(";","_gestures;_animations;_gst;_pst;_shd;_ss;_anm;.bsp;cs_fix")
        for _,v in pairs(bl) do
            if string.find(model,v) then return false end
        end
        return true
    end,
    IsValidPhysicsObject = function(ent,num)
        if not ent or ( not ent:isValid() and not ent:isWorld() ) then return false end
        if not ent==world_spawn and ent:getMoveType() ~= 6 and not (ent:getModel() and ent:getModel():startsWith("*")) then return false end    
        local Phys = ent:getPhysicsObjectNum( num )
        return Phys:isValid()
    end,
}

glua.util = util

if apply_global then
    for K,V in pairs(glua) do
        _G[K] = V
    end
end
