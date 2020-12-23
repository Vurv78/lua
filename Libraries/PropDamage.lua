--@name Prop Health Manager
--@author Vurv
--@server

-- This basically just acts like the addon Extended Prop Damage, which can be found here: https://steamcommunity.com/sharedfiles/filedetails/?id=944542795
-- You can register any prop (that you have toolgun perms on) so that it has health points that are deduced whenever it's shot at, it also slowly makes the prop go from white to red.
-- It'll take physics damage and everything, and you can disable whether the prop color fades to red (which currently doesn't support the prop color already set.)

local Vector = Vector
local Color = Color

local ent_meta = getMethods("Entity")

local prop_list = { count = 0 }
function ent_meta:setHealth(n)
    assert(n and n>0,"Give an unsigned number for the health of the entity!")
    assert(self.phc_managed==nil,"This prop is already registered with phc.")
    assert(hasPermission("entities.canTool",self),"You don't have toolgun perms on this prop!")
    
    prop_list.count = prop_list.count + 1
    prop_list[self] = n
    
    self.phc_managed = true
    self.phc_hp = n
    self.phc_mhp = n
end

function ent_meta:setHealthDisplay(b)
    self.phc_dontdisplay = not b
end

-- This is awful, ik
local lerpV = math.lerpVector
local function mixRed(ratio,col)
    local v = lerpV( ratio, Vector(255,0,0), Vector(255,255,255) )
    return Color(v[1],v[2],v[3])
end

hook.add("EntityTakeDamage","",function(ent,_,_,amount)
    if prop_list[ent] then
        local final = ent.phc_hp - amount
        if final <= 0 then
            ent:remove()
        else
            local r = final / ent.phc_mhp
            ent.phc_hp = final
            if not ent.phc_dontdisplay then
                ent:setColor( mixRed( r, ent:getColor() ) )
            end
        end
    end
end)

hook.add("EntityRemoved","phc_remove",function(ent)
    if prop_list[ent] then
        prop_list[ent] = nil
        prop_list.count = prop_list.count - 1
    end
end)

--@name Example Chip
--@server
--@include libs/phc.txt

--require("libs/phc.txt") Require the library in this chip

for I=1,4 do
    local p = prop.create(chip():localToWorld(Vector(0,0,50)),Angle(),"models/hunter/blocks/cube1x1x1.mdl",false)
    p:applyForceCenter( Vector( math.random(-1,1)*1000, math.random(-1,1)*1000, math.random(-1,1)*1000 ) )
    p:setHealth(500)
end
