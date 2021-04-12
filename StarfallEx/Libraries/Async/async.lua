--@name asynclib
--@author Vurv
--@client

if player() ~= owner() then return end


local type = type
local errorf = function(level, ...) error(string.format(...), level) end

--- throwTypeError and checkluatype are modified from StarfallEx source code.
-- These should be exposed to sf tbh.
local function throwTypeError(expected, got, level, msg)
    local level = 1 + (level or 1)
    local funcname = debugGetInfo(level-1, "n").name or "<unnamed>"
    errorf( level, "Type mismatch (Expected %s, got %s) in function %s", expected, got, funcname)
end

local function checkluatype(val, expected)
    local _type = type(val)
    if _type ~= expected then
        -- Failed, throw error
        level = (level or 1) + 3
        throwTypeError(expected, _type, level, msg)
    end
end

-- Async type.
local async = class("Async")

--- Async:new(f)
-- @param function runtime
-- @return Async Async runtime object
function async:initialize(runtime)
    self.thread = coroutine.create( runtime )
    self.original = runtime
end

local async_running = false
--- Whether an async function is currently running.
-- @return boolean Whether an async function is running.
function async.running()
    return async_running
end

--- Resumes the async state.
-- @param ... args Anything to pass to the state
-- @return ...
function async:resume(...)
    -- Like async.__call but doesn't pass 'self'
    async_running = true
    return coroutine.resume(self.thread, ...)
end

--- Same as doing coroutine.yield except makes sure "async_running" is correct.
-- @param ... args Args to pass
function async:yield(...)
    async_running = false
    return coroutine.yield(...)
end

--- Resumes the async state, passing 'self' [Async] as the first argument
-- This is meant to be used to start async states out of async.
-- @param ... args Any arguments to pass to the state.
function async:__call(...)
    coroutine.resume(self.thread, self, ...)
end

--- Await call
-- @param function rhs Asynchronous function to await for the result.
function async:__mul(rhs)
    checkluatype(rhs, "function")
    assert(async.running(), "Must be inside an async function")
    local ret = {rhs(self)}
    if #ret > 0 then
        return unpack(ret)
    else
        return {async:yield()}
    end
end

-- Static metatable
local async_meta = getmetatable(async)

--- Like __mul, but does not immediately call it, and instead returns the async state.
-- @param function runtime Code to run in an async state
-- @return Async Async object.
async_meta.__add = function(self, runtime)
    checkluatype(runtime, "function")
    return async:new(runtime)
end

--- Creates an async state, immediately calling it and returning the value returned.
-- @return ... Anything prematurely returned.
async_meta.__mul = function(self, runtime)
    checkluatype(runtime, "function")
    return async:new(runtime)()
end

-- Static metatable.

local function httpGET(url, headers)
    return function(async)
        http.get(url, function(...)
            async:resume(...)
        end, function(...)
            throw(...)
        end, headers)
    end
end

local function sleep(n)
    checkluatype(n, "number")
    return function(async)
        timer.simple(n, function()
            async:resume()
        end)
    end
end


local _ = async* function(await, ...)
    -- Metamethods can't return multiple values so we have to unpack.
    -- Very amazing.
    local data = await* httpGET("https://google.com")
    local a, b, c = unpack(data)
    -- local a, b, c = httpGET("https://google.com").await() TODO Rust/Java syntax that doesn't need unpacking.
    -- print(a, b, c)
    
    local _ = await* sleep(5)
end

return {
    httpGET = httpGET,
    sleep = sleep
}