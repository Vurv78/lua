--@name SF Traceback Function
--@author Vurv
--@shared

-- Adds a proper lua only debug library.
-- Small SF implementation of debug traceback is included with an example at the bottom. Not a perfect clone of traceback tho.
-- Replace stringstream use with a table of strings or just string concat if you want to use this outside of SF. (Stringstreams are way more efficient)

debug = {}
debug.getinfo = debugGetInfo
debug.getlocal = debugGetLocal

local function unwrap_type(checktype, val)
    return type(val) == checktype and val or nil
end

local string_format = string.format

-- Acts like pushfuncname
-- https://github.com/lua/lua/blob/cf23a93d820558acdb8b1f0db85fdb94e709fee2/lauxlib.c#L100
local function get_func_name(debug_info)
    local buf = bit.stringstream()
    local what, name_what = debug_info.what, debug_info.namewhat
    if name_what and name_what ~= "" then
        buf:write( string_format("%s '%s'", name_what, debug_info.name) )
    elseif debug_info.what == "m" then
        buf:write("main chunk")
    elseif what ~= "C" then
        buf:write( string_format("function <%s:%d>", debug_info.short_src, debug_info.linedefined) )
    end
    return buf:getString()
end

local function traceback(message, level)
    local buf = bit.stringstream()
    if message then
        buf:write(message)
        buf:write("\n")
    end
    buf:write("stack traceback:")
    local lev = lev or 0
    repeat
        local data = debug.getinfo(lev, "Sln")
        if data then
            if (data.currentline <= 0) then
                buf:write( string_format("\n\t%s: in ", data.short_src) )
            else
                local s = string_format("\n\t%s:%d: in ", data.short_src, data.currentline)
                buf:write(s)
            end
            buf:write( get_func_name(data) )
            if data.istailcall then
                buf:write("\n\t(...tail calls...)")
            end
        end
        lev = lev + 1
    until not data
    return buf:getString()
end

-- Acts like db_traceback
-- https://github.com/lua/lua/blob/cf23a93d820558acdb8b1f0db85fdb94e709fee2/ldblib.c#L435
debug.traceback = function(thread, message, level)
    local arg = 0 -- Int
    local msg = unwrap_type("string", message)
    if msg==nil and message~=nil then
        -- Message isn't valid
        return message
    else
        local level = level or 0
        return traceback( nil, thread, "hi", level )
    end
end

--[[
--@name Example
--@server
function a()
    print( debug.traceback(0) )
end

a()

]]--