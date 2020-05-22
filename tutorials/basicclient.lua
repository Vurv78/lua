--@name Client Example
--@author Vurv
--@client

if player() == owner() then return end

Font = render.createFont("Times New Roman",50-#player():getName())
mat = material.create("UnlitGeneric")
mat:setTextureURL("$basetexture","https://i.imgur.com/73tiLww.jpeg",function(mat,_,wid,height,layout)
    layout(0,0,512,512)
end)
hook.add("render","",function()
    render.setMaterial(mat)
    render.drawTexturedRectFast(0,0,1024,1024)
    render.setFont(Font)
    render.drawText(256,256,tostring(player():getName()).." is gay",1)
end)
