--@name Custom Net Streams
--@author Vurv
--@shared

-- Tiny String Streams Library,
-- Not very good since you can't organize stuff to properly come after string streams, so you'd have to put them at the end of net.start calls.
-- Kind of useless in starfallex, because Sparky added stringstreams in his own implementation
-- Here's my implementation that uses coroutines to make it a pretty smooth experience to use these without a ton of callbacks that sparky's requires.
-- 1415 chars

local PartitionSize = 3000 -- How many chars to split each string by

local Streams = {}
local Streaming

timer.create("streamLoad",0.1,0,function()
    if #Streams==0 then return end
    local info = Streams[1]
    if net.getBitsLeft() < info[1] then return end
    local str = info[2]
    local final = info[3]
    net.start("stringstream")
        net.writeString(str)
        net.writeBool(final)
    net.send()
    table.remove(Streams,1)
end)

net.writeLongString = function(str)
    if Streaming then error("You're already streaming!",0) return end
    local size = string.utf8len(str)
    if size <= PartitionSize then
        Streams[#Streams+1] = {size*8+8,str,true}
    else
        local splits = math.ceil(size/PartitionSize)
        for K = 1,splits do
            local part = string.sub(str,PartitionSize*(K-1),PartitionSize*K)
            local bitsize = string.utf8len(part)*8+8
            Streams[#Streams+1] = {bitsize,part,K==splits}
        end
    end
end

net.readLongString = function()
    local co = coroutine.running()
    local parts = {}
    net.receive("stringstream",function()
        local str = net.readString()
        local final = net.readBool()
        parts[#parts+1] = str
        if final then
            net.receive("stringstream")
            coroutine.resume(co,table.concat(parts))
        end
    end)
    return coroutine.yield()
end

net.receiveBetter = function(name,cb) net.receive(name,coroutine.wrap(cb)) end

-- Example of how to use beyond here

if CLIENT then
    if player() ~= owner() then return end
    
    net.start("cool")
        net.writeLongString(string.rep("bruhhhh",1000))
    net.send()
else
    net.receiveBetter("cool",function()
        local num = net.readUInt(10)
        local mstr = net.readString()
        local time = timer.systime()
        local longstr = net.readLongString()
        local len = string.utf8len(longstr)
        local megabytes = (len*8+8)/8/1e+6
        print(string.format("Took %d seconds to send %d chars aka %.03f mb!",timer.systime() - time,len,megabytes))
    end)
end
