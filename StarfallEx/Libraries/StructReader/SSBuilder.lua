--@name StringStreamParser
--@author Vurv
--@shared

-- Builds a table struct from type data with stringstreams.
-- Useful especially for the ability to read arrays of any type.
-- One usecase may be for reading file types like .vvd or something.
local SSBuilder = class("SSBuilder")

-- Beware there's no 'float' or 'double' concepts for this.
-- Use Rust-like types. Aka float = f32, double = f64.
-- Note using a 'big' stream while reading regular sizes (f32, etc) will break stuff.
local Handlers = {
    ["i8"] = function(self)
        return self:readInt8()
    end,

    ["i16"] = function(self)
        return self:readInt16()
    end,
    
    -- I32. This is simply 'Int' in most languages.
    ["i32"] = function(self)
        return self:readInt32()
    end,
    
    -- UInt8
    ["u8"] = function(self)
        return self:readUInt8()
    end,
    
    -- UInt16
    ["u16"] = function(self)
        return self:readUInt16()
    end,
    
    -- UInt32
    ["u32"] = function(self)
        return self:readUInt32()
    end,
    
    -- Null terminated string \0
    ["cstr"] = function(self)
        return self:readString()
    end,
    
    -- Float
    ["f32"] = function(self)
        return self:readFloat()
    end,
    
    -- Double. Needs parseBig (This is the default lua number type in 5.1)
    ["f64"] = function(self, big)
        if not big then throw("SSBuilder tried to serialize double but was not 'big'. Use SSBuilder:parseBig") end
        return self:readDouble()
    end
}

function SSBuilder:initialize(definition)
    assert(type(definition)=="string", "SSBuilder must be used with a string")
    
    local nocomments = definition:gsub("[-/]+.-\n", "\n")
    
    local used_keys = {}
    local struc, n = {}, 1
    for line in nocomments:gmatch("[^\n\r,]+") do
        local key, rtype, count = line:match("%s*([%w_]+)%s*[:=]%s*%[?%s*([uifcstr]+%d*);?%s*(%d*)%]?")
        count = count=="" and 1 or tonumber(count)
        
        -- Check if key exists, because an empty line being passed here would break it otherwise.
        -- Comments cause this.
        if key then
            if used_keys[key] then
                -- Key already exists. Why do you do this?
                throw("Repeated key [" .. key .. "] found at line " .. n .. " in SSBuilder")
            end
            local handler = Handlers[rtype]
            if not handler then throw("Unknown or invalid type [".. rtype .. "] in SSBuilder") end
            struc[n] = { key, rtype, count }
            used_keys[key] = true
            n = n + 1
        end
    end
    
    self.nfields = n
    self.struc = struc
    self.data = {}
end

-- This function may error with some cryptic 'bit' library error.
-- In this case, your serialization is wrong and the struct is trying to read values that don't exist or are different types.
function SSBuilder:parse(raw, big)
    local struc, stream = self.struc, bit.stringstream(raw, 1, big and "big" or "little")
    local data = self.data
    
    for _, field_data in ipairs(struc) do
        local key, rtype, count = unpack(field_data)
        local handler = Handlers[rtype]
        
        if count > 1 then
            -- We found an array.
            local arr = {}
            for i = 1, count do
                arr[i] = handler(stream, big)
            end
            data[key] = arr
        else
            data[key] = handler(stream, big)
        end
    end
    return data
end

function SSBuilder:parseBig(raw)
    return self:parse(raw, true)
end

-- See the example at Example.lua

return SSBuilder