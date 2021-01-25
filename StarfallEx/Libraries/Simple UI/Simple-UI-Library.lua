--@name Simple UI Library
--@author Vurv
--@client

local module = {}

local uiobject = class("uiobject")
local uibutton = class("uibutton",uiobject)
local uiObjs = {}
local uiRT = "uiRT"
local uiReload = false

-- Button detection
local uiWaitKey = {} -- Buttons to check when pressing e.
local uiWaitKeyRender = {} -- Buttons to check when pressing e. Returns IN a render hook.
local uiPressKey = KEY.E
local uiBtnOverlap = false -- Whether to execute multiple buttons if the cursor overlaps each of em, if false, then gets the first created button.

-- Cursor
local uiCursor = Vector()
local uiHovering = false
print("ACTIVATED")

render.createRenderTarget(uiRT)

function uiobject:init(x,y)
    self.id = #uiObjs
    self.x = x
    self.y = y
    table.insert(uiObjs,self)
end

function uibutton:init(x,y,sx,sy,c,txt,font)
    uiobject.init(self,x,y)
    self.sx = sx self.sy = sy
    self.c = c self.txt = txt
    self.font = font self.button = true
end

function uibutton:whenPressed(f)
    self.pressedFunc = f
    table.insert(uiWaitKey,self)
end

function uibutton:whenPressedRender(f)
    self.pressedFunc = f
    uiWaitKeyRender[self] = true -- Set to true to say that it's changed
end

local function loadUI()
    render.selectRenderTarget(uiRT)
    render.clear(Color(0,0,0,0)) -- Make UI Transparent so the user can use a separate RT for other stuff.
    for K,Obj in pairs(uiObjs) do
        if Obj.hidden then return end
        if Obj.button then
            render.setColor(Obj.c)
            render.drawRect(Obj.x,Obj.y,Obj.sx,Obj.sy)
            render.setRGBA(255,255,255,255)
            if Obj.font then render.setFont(Obj.font) end
            render.drawText(Obj.x+Obj.sx/2,Obj.y+Obj.sy/2,Obj.txt,1)
        else
            -- Invalid object
        end
    end
    render.selectRenderTarget()
end

local function inrange2d(V,VMin,VMax)
    return (V.x > VMin.x and V.y > VMin.y and V.x < VMax.x and V.y < VMax.y)
end

hook.add("renderoffscreen","ui_reload",function()
    if not uiReload then return end
    loadUI()
    uiReload = false
end)

hook.add("render","ui_getCursor",function()
    local C = render.cursorPos()
    uiHovering = C and true or false
    if C then uiCursor = Vector(C) end
end)

hook.add("render","ui_keyHandlerRender",function()
    local waitObjCount = table.count(uiWaitKeyRender)
    if waitObjCount<1 then return end
    if not input.isKeyDown(uiPressKey) then
        for Btn in pairs(uiWaitKeyRender) do
            uiWaitKeyRender[Btn] = true 
        end
        return
    end
    for Btn,Ch in pairs(uiWaitKeyRender) do
        if not Btn.pressedFunc then continue end
        if inrange2d(uiCursor*2,Vector(Btn.x,Btn.y),Vector(Btn.x+Btn.sx,Btn.y+Btn.sy)) then
            if Btn.pressedFunc then Btn.pressedFunc(Btn,Ch) end
            uiWaitKeyRender[Btn] = false
            if not uiBtnOverlap then break end
        end
    end
end)

hook.add("inputPressed","ui_keyHandler",function(key)
    if #uiWaitKey<1 then return end
    if not uiHovering then return end
    if key == uiPressKey then
        for K,Btn in pairs(uiWaitKey) do
            if not Btn.pressedFunc then continue end
            if inrange2d(uiCursor*2,Vector(Btn.x,Btn.y),Vector(Btn.x+Btn.sx,Btn.y+Btn.sy)) then
                if Btn.pressedFunc then Btn.pressedFunc(Btn) end
                if not uiBtnOverlap then break end
            end
        end
    end
end)

-- Exposed

module.createButton = function(...)
    local b = uibutton:new()
    b:init(...)
    return b
end

module.reloadUI = function()
    uiReload = true
end

module.setRT = function(S)
    -- Set the rendertarget that the UI will use.
    render.destroyRenderTarget(uiRT)
    render.createRenderTarget(S)
    uiRT = S
end

module.drawUI = function()
    render.setRenderTargetTexture(uiRT)
    render.setRGBA(255,255,255,255)
    render.drawTexturedRect(0,0,512,512)
end

module.btnOverlap = function(t)
    uiBtnOverlap = t
end

return module