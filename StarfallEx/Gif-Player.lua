--@name Gif Player 2
--@author Vurv
--@client

-- Source -- https://github.com/Vurv78/starfallex-creations
-- Created Nov. 2020
-- Only works with whitelisted pythonanywhere links.
-- Also needs you to disable your url whitelist because it uses my website...
-- My website limits the gifs to be 200 frames.
-- Doesn't have dynamic frames, but the website does provide the frame timestamps / ms between them, so you can do it yourself

-- As of sometime around January, Gif saving / playing functionality has been removed from my website, not sure if i'll add it again. See https://github.com/Vurv78/Website
-- If I do add it again, I need to know how to automatically clean files so you guys can't save bad stuff to my website :v

if player() ~= owner() then return end

local CurrentGifData
local FrameCounter = 1
local Session = "poggers"
local GifUrl = "https://media1.giphy.com/media/ToMjGpxfgCJQeVgO9NK/200w.gif"

local function retrieveGifData(url)
    http.get("https://vurv.pythonanywhere.com/setgif?session="..Session.."&url="..url,function(body,len,headers)
        if string.find(body,"PythonAnywhere: something went wrong :%-%(") then return error("This gif is not whitelisted w/ pythonanywhere!") end
        CurrentGifData = json.decode(body)
        print("Retrieved gif data for url "..url)
    end)
end

local function getGifFrame(n)
    local n = n or FrameCounter
    FrameCounter = ((FrameCounter + 1) % CurrentGifData.frames)
    return "https://vurv.pythonanywhere.com/getgif/"..Session.."/"..n
end

local screenMat = material.create("UnlitGeneric")

local fpsdelta = 1/70
local fpstime = timer.curtime()
local deltatime

retrieveGifData(GifUrl)

hook.add("renderoffscreen","",function()
    if not CurrentGifData then return end
    local time = timer.curtime()
    if time < fpstime + fpsdelta then return end
    deltatime = time-fpstime
    fpstime = time
    screenMat:setTextureURL("$basetexture",getGifFrame(),function(mat,w,h,u,lay)
        lay(0,0,1024,1024)
    end)
end)

hook.add("render","",function()
    render.setMaterial(screenMat)
    render.drawTexturedRect(0,0,512,512)
end)
