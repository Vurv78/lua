# Simple UI Library

This is a library I made to accompany creating bigger projects in StarfallEx.
It should be useful to you if you want to create games or just don't want to deal with
managing your own interface (It gets messy fast)

##Current Exposed Functions:

```lua
module.createButton = function(...) -- Creates a button class
    local b = uibutton:new()
    b:init(...)
    return b
end

module.reloadUI = function() -- Refreshes the UI outside of a render hook.
    uiReload = true
end

module.setRT = function(S) -- Set the name of the rendertarget that the UI will use. Destroys and creates the RT for you.
    -- Set the rendertarget that the UI will use.
    render.destroyRenderTarget(uiRT)
    render.createRenderTarget(S)
    uiRT = S
end

module.drawUI = function() -- Call this in a render hook to draw the separate UI rendertarget.
    render.setRenderTargetTexture(uiRT)
    render.setRGBA(255,255,255,255)
    render.drawTexturedRect(0,0,512,512)
end

module.btnOverlap = function(t) -- Set whether to be able to trigger multiple buttons in one press.
    uiBtnOverlap = t
end
```

## Current middleclasses
```lua
-- Args: X,Y (Float pos) SX,SY (Float size) C (Color color) TXT (String text) FONT (Optional Font Class)
function uibutton:init(x,y,sx,sy,c,txt,font) -- Initializes a button class
    uiobject.init(self,x,y)
    self.sx = sx self.sy = sy
    self.c = c self.txt = txt
    self.font = font self.button = true
end

function uibutton:whenPressed(f) -- Creates a callback that when a user interacts with a ui element, the function will be called (OUTSIDE OF A RENDER HOOK, WILL BE EXECUTED ONCE). Args given: Btn object
    self.pressedFunc = f
    table.insert(uiWaitKey,self)
end

function uibutton:whenPressedRender(f) -- Creates a callback that when a user interacts with a ui element, the function will be called. (THIS IS IN A RENDER HOOK.) Args given: Btn object, Bool changed
    self.pressedFunc = f
    uiWaitKeyRender[self] = true -- Set to true to say that it's changed
end
```
I also intend to make a sort of game engine at some point.

StarfallEx SimpleUI Library by Vurv on Discord(363590853140152321)