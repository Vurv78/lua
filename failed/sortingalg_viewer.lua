--@name Sorting Algorithm Viewer
--@author Vurv
--@client

render.createRenderTarget("rt")

//SortingTable = {8,3,2,1,5,8,9,12,16,20,6,9,2,25,30,0}
SortingTable = {}
Sorted = {}
Finished = false

for I = 1,256 do
    SortingTable[I] = math.random(1,200)
end

HighestNum = -1
for K,T in ipairs(SortingTable) do
    if T > HighestNum then HighestNum = T end
end

local RatioX = 512/#SortingTable
local RatioY = 512/HighestNum
function update()
    hook.add("renderoffscreen","",function()
        render.selectRenderTarget("rt")
            for K,T in ipairs(SortingTable) do
                render.setColor(Color(360/#SortingTable*K,1,1):hsvToRGB())
                //if Sorted[K]==true then render.setColor(Color(0,255,0)) else render.setColor(Color(255,255,255)) end
                render.drawRectFast((K-1)*RatioX,512,RatioX,-T*RatioY)
            end
        render.selectRenderTarget()
        hook.remove("renderoffscreen","")
    end)
end


// Initial update

hook.add("render","",function()
    render.setFilterMin(1)
    render.setFilterMag(1)
    render.setRenderTargetTexture("rt")
    //ender.setColor(Finished and Color(0,255,0) or Color(255,255,255))
    render.drawTexturedRect(0,0,1024,1024)
end)

-- Sorting

FPS = 60

function swap(a, b, T)
    if T[a] == nil or T[b] == nil then
        return false
    end
    if T[a] > T[b] then
        T[a], T[b] = T[b], T[a]
        return true
    end
    return false
end


function sort()
    local T = SortingTable
    local n = #T
    for i=1,table.maxn(SortingTable) do
        local ci = i
        ::redo::
        if swap(ci, ci+1, SortingTable) then
            ci = ci - 1
            update()
            coroutine.yield()
            goto redo
        end
    end
    return true
end

co = coroutine.create(sort)

timer.create("sort",1/FPS,0,function()
    if coroutine.status(co) ~= "dead" then
        if quotaAverage()<quotaMax()*0.1 then
            local res = coroutine.resume(co)
            if res then Finished = true update() timer.remove("sort") end
        end
    end
end)

-- Sorting
