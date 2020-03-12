--@name functions.textbox
--@author Vurv
--@client

// Basic Textbox library for starfall, could definitely be improved which I hopefully will do over time.
// TODO: Add aligning, make this more efficient. Remove bad coding practices (making several var names for essentially the same thing.)

libs_textbox = {}
libs_textbox.strings = {}
libs_textbox.fixfit = function(txt,Width,Height)
    for I = 1,#txt-1 do
        local TxtModified = string.sub(txt,1,(#txt-I))
        local SizeX,SizeY = render.getTextSize(TxtModified)
        local Fits2 = (SizeX <= Width and SizeY <= Height)
        if Fits2 then
            local TxtModified2 = string.sub(txt,(#TxtModified),#txt)
            libs_textbox.strings[#libs_textbox.strings+1] = TxtModified
            SizeX,SizeY = render.getTextSize(TxtModified2)
            local Fits3 = (SizeX <= Width and SizeY <= Height)
            if not Fits3 then libs_textbox.fixfit(TxtModified2,Width,Height) else libs_textbox.strings[#libs_textbox.strings+1] = TxtModified2 end
            break
        end
    end
end

render.drawTextBox = function(x,y,xw,yw,txt)
    local Font = render.getDefaultFont()
    render.setFont(Font)
    local Sz_X,Sz_Y = render.getTextSize(txt)
    local Fits = (Sz_X <= xw and Sz_Y <= yw)
    // uncomment this if you want to see the actual textbox.
    // render.drawRectFast(x,y,xw,yw)
    if not Fits then
        libs_textbox.strings = {}
        libs_textbox.fixfit(txt,xw,yw)
        for K,Str in pairs(libs_textbox.strings) do
            render.drawText(x,y+Sz_Y*(K-1),Str,0)
        end
    else
        render.drawText(x,y,txt,0)
    end
end
hook.add("render","",function()
    render.drawTextBox(0,0,256,256,"gamer")
end)
