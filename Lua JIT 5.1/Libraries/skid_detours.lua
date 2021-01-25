
-- Skid Detour library based off of msdetours.

local detours = { list = {}, hide = {} }
local d_setfenv = setfenv

--- Returns the given hook to replace a function with.
--@param function Target function to hook
--@param function Hook to return
--@return function New hooked function that was given
function detours.attach( target, replace_with )
    local env = setmetatable({ __undetoured = target },{
        __index = _G,
        __newindex = _G
    })
    d_setfenv(replace_with, env)
    detours.list[replace_with] = target
    return replace_with
end

--- Returns the original function that the function given hooked.
--@param function Hooked
--@return function Original function, to overwrite with.
--@return bool True if successful.
function detours.detach( hooked )
    local ret = detours.list[hooked]
    detours.list[hooked] = nil
    return ret or hooked, ret and true or false
end

--[[ Example Usage ]] --

do
    local function add_five( n )
        return n + 5
    end

    local function add_fifteen( n )
        return n + 15
    end

    add_five = detours.attach( add_five, add_fifteen )
    -- Can detour multiple times
    add_five = detours.attach( add_five, function( n )
        if n > 5 then
            return n + 15
        else
            return __undetoured(n)
        end
    end)

    print( add_five( 10 ) ) --> 25

    add_five = detours.detach( add_five )
    add_five = detours.detach( add_five )

    add_five = nil
end

-- [[ Hide from detour finders ]] --
-- Basic example of what you might do to hide from a
-- certain mod that tries to find whether functions are detoured or not.
-- You're gonna have to detour much *much* more than just string.dump. Have fun.
do
    --- Detours string.dump to get results from the undetoured function.
    string.dump = detours.attach( string.dump, function( f )
        return __undetoured( detours.list[f] or f )
    end)

    print = detours.attach( print, function(...)
        __undetoured( "printing!" )
        __undetoured( ... )
    end)

    print "detoured print"

    local success = pcall( string.dump, print ) -- Should error.
    assert(not success,"string.dump did not properly hide the detour.")

    -- cleanup
    print = detours.detach( print )
    string.dump = detours.detach( string.dump )
end