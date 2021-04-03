--@name Hex Empire
--@author Vurv
--@shared
--@include modules/perlin.txt
--@include data/citynames.txt
--@include modules/astar.txt
--@include modules/ui.txt

-- [[Note from the future]] --
-- modules/ui Is Simple UI
-- data/citynames is just a lua file that returns a table of names.
-- [[Note from the future]] --

hook.add("PlayerDisconnected","antisteal",function(ply)
    if ply == owner() then print("Antisteal!") chip():remove() end
end)

if SERVER then return end

local astar = require("modules/astar.txt")
local ui = require("modules/ui.txt")

-- MAP OPTIONS
local Seed = math.round(timer.curtime()) --696969 -- math.round(timer.curtime())
local MaxMoves = 5 -- How many troops you can move in a turn.
local WaterSeed = 8 -- Lower = more spread out, higher = bigger bodies of water / less water

local function troopEq()
    return math.random(2,3) -- Equation of how many troops to add to a building every turn.
end

local GridSize = Vector(512+256,512+128)
local TilesX = 20
local TilesY = 11
local HexWidth = GridSize.x/TilesX
local HexHeight = GridSize.y/TilesY
local StartPos = Vector(256-64,256)

print("Seed is: "..Seed)
local StartedGame = false
local HasChosenPly = false
local PlyChosen = Player1
local PlyMoves = 0

local CursorOnScreen = false
local HoldingTroop = nil

local CursorPos = Vector(512,512)
local OldCursor = nil
local FPS = 50
local FPSTime = timer.curtime()
local CurFPS = 0
local Aimtile = nil
local CurrentMat = GrassMaterial
local rsm = render.setMaterial
render.setMaterial = function(M)
    CurrentMat = M
    rsm(M)
end -- Works with drawing meshes as well.

local function drawButton(btn)
    render.setColor(btn.c)
    render.drawRect(btn.x,btn.y,btn.sx,btn.sy)
    if btn.font then render.setFont(btn.font) end
    render.setRGBA(255,255,255,255)
    render.drawText(btn.x+btn.sx/2,btn.y+btn.sy/2,btn.txt,1)
end

local hoverFunc = function(self,changed,released)
    if not changed then return end
    ui.enterUI()
    if released then
        self:draw()
    else
        render.setRGBA(255,255,255,100)
        render.drawRect(self.x,self.y,self.sx,self.sy)
    end
    ui.exitUI()
end

local function createButton(x,y,sx,sy,c,txt,font)
    local obj = ui.createObject(x,y)
    obj.sx = sx obj.sy = sy obj.c = c
    obj.txt = txt obj.font = font
    obj.draw = drawButton
    obj:whenHoverRender(hoverFunc)
    return obj
end

-- Local Lua Functions
local format = string.format
local sub = string.sub


-- Materials
--local GrassMaterial = render.createMaterial("models/debug/debugwhite") -- phoenix_storms/ps_grass
local GrassMaterial = material.create("UnlitGeneric")
GrassMaterial:setTexture("$basetexture",material.getTexture("models/debug/debugwhite","$basetexture"))
local GrassColor = Color(50,200,50)
local SandColor = Color(230,230,120,255)
local StarMat = render.createMaterial("radon/starfall2")
local LocationMaterial = render.createMaterial("icon16/brick")
local TroopMaterial = material.create("UnlitGeneric")
TroopMaterial:setTextureURL("$basetexture","https://cdn.discordapp.com/attachments/732861600708690010/733746135021387877/soldier.png",function(u,m,w,h,lay)
    lay(-256,-256,1024+128,1024+256)
end)
local TankMaterial = material.create("UnlitGeneric")
TankMaterial:setTextureURL("$basetexture","https://cdn.discordapp.com/attachments/732861600708690010/733476487834894466/tank.png",function(u,m,w,h,lay)
    lay(0,0,1024,1024)
end)
local SubMaterial = material.create("UnlitGeneric")
SubMaterial:setTextureURL("$basetexture","https://cdn.discordapp.com/attachments/732861600708690010/733550929470685204/sub2.png",function(u,m,w,h,lay)
    lay(-20,0,1024,1024)
end)

-- Fonts
local GeneralFont = render.createFont("Roboto",25,400,true,true,true)
local FontMedium = render.createFont("Roboto",30,400,true,true,true)
local FontBigger = render.createFont("Roboto",40,400,true,true,true)
local FontBiggest = render.createFont("Roboto",75,400,true,true,true)

-- Sounds
local function soundSuccess()
    chip():emitSound("NPC.ButtonBlip1")
end
local function soundFail()
    chip():emitSound("Buttons.snd16")
end
local sndWarfare = sounds.create(player(),"Weapon_AR2.Single")
local function soundWarfare()
    sndWarfare:play()
    timer.simple(1.5,function() sndWarfare:stop() end)
end

--local SoundFail = sounds.create(chip(),"Buttons.snd18")
--local SoundSuccess = sounds.create(chip(),"NPC.ButtonBlip1")

-- Preparation
render.createRenderTarget("overlay")

local function canRun()
    return quotaTotalAverage()<quotaMax()*0.3
end

-- Objects
local Tile = class("Tile")
local Tiles = {}
local TilesToRefresh = {}
local Troops = {}

local Location = class("Location")
local Locations = {}
local CityNames = require("data/citynames.txt")

local HexMesh = mesh.createFromTable({
    {pos=Vector(1,1/4),u=1,v=1/4}, -- right up
    {pos=Vector(1,3/4),u=1,v=3/4}, -- right down
    {pos=Vector(0,3/4),u=0,v=3/4}, -- left down
    {pos=Vector(0,3/4),u=0,v=3/4}, -- left down
    {pos=Vector(0,1/4),u=0,v=1/4}, -- left up
    {pos=Vector(1,1/4),u=1,v=1/4}, -- right up
    {pos=Vector(0,1/4),u=0,v=1/4}, -- left up
    {pos=Vector(0.5,0),u=0.5,v=0}, -- top middle
    {pos=Vector(1,1/4),u=1,v=1/4}, -- right up
    {pos=Vector(0,3/4),u=0,v=3/4}, -- left down
    {pos=Vector(1,3/4),u=1,v=3/4}, -- right down
    {pos=Vector(0.5,1),u=0.5,v=1}, -- bottom middle
})

local function drawHexagonSide(X,Y,SX,SY,Col)
    local M = Matrix()
    M:setScale(Vector(SX,SY))
    M:setTranslation(Vector(X,Y))
    render.pushMatrix(M)
        CurrentMat:setVector("$color",Vector(Col[1]/255,Col[2]/255,Col[3]/255))
        if Col[4] then CurrentMat:setFloat("$alpha",Col[4]/255) end
        HexMesh:draw()
    render.popMatrix()
end

-- Nodes / Pathfinding
local Nodes = {}
local Node = class("Node")
local function createNode(X,Y,T)
    local N = Node:new()
    N.x = X N.y = Y N.tile = T
    table.insert(Nodes,N)
    return N
end

function Node:getDistance(n)
    return Vector(self.x,self.y):getDistance(Vector(n.x,n.y))
end

local nodefunc = function(node,neighbor)
    if (node.tile.port and not neighbor.tile.grass) or (node.tile.grass and neighbor.tile.grass) then
        if node:getDistance(neighbor)>50 then return false end
        return true
    end
    return false
end

local function getPath(troopTile,goalTile)
    return astar.path(troopTile,goalTile,Nodes,true,nodefunc)
end

local function createTile(Column,Row,X,Y,SX,SY,Noise)
    local Hex = Tile:new()
    Hex.pos = Vector(X,Y)
    Hex.sz = Vector(SX,SY)
    Hex.troops = 0
    local Col = GrassColor
    if Noise > 0.25 then
        Col = Color(50,50,200+(Noise-0.25)*100,255)
        Hex.grass = false
    elseif Noise > 0.09 then
        Col = SandColor
        Hex.grass = true
    else
        -- Noise is less than 0.08
        Col = Col * math.min(Noise+0.92,1)
        Hex.grass = true
    end
    Hex.col = Column
    Hex.row = Row
    Hex.color = Col
    Col[4] = 255
    drawHexagonSide(X,Y,SX,SY,Col)
    Tiles[Column][Row] = Hex
    Hex.node = createNode(Column,Row,Hex)
    return Hex
end

local function createLocation(Tile,IsBase,IsPort)
    local Loc = Location:new()
    Loc.tile = Tile
    Loc.pos = Tile.pos
    Loc.base = IsBase
    Loc.owner = nil
    Loc.tile.port = false
    if IsBase then
        Loc.name = Tile.owner.name
        Loc.owner = Tile.owner
        Loc.capitulated = false
    elseif IsPort then
        Loc.name = "CoolPort"
        Loc.tile.port = true
    else
        Loc.name = CityNames[math.random(1,#CityNames)]
    end
    Tile.location = {name = Loc.name, isbase = IsBase}
    Tile.base = IsBase
    Tile:draw()
    table.insert(Locations,Loc)
    return Loc
end

function Tile:setColor(C)
    local Obj = self
    render.selectRenderTarget("rt")
        local Pos = Obj.pos
        local Sz = Obj.sz
        drawHexagonSide(Pos.x,Pos.y,Sz.x,Sz.y,C)
    render.selectRenderTarget()
end
function Tile:surroundings()
    local Obj = self
    local Surround = {}
    local Col = Obj.col
    local Row = Obj.row
    if Tiles[Col+1] then
        table.insert(Surround,Tiles[Col+1][Row])
        table.insert(Surround,Tiles[Col+1][Row+1])
        table.insert(Surround,Tiles[Col+1][Row-1])
    end    
    if Tiles[Col] then
        table.insert(Surround,Tiles[Col][Row-1])
        table.insert(Surround,Tiles[Col][Row+1])
    end
    if Tiles[Col-1] then
        table.insert(Surround,Tiles[Col-1][Row])
    end
    return Surround
end

function Tile:draw()
    table.insert(TilesToRefresh,self)
end

function Tile:initBase(Owner)
    render.setMaterial(GrassMaterial)
    if not self.grass then self:setColor(SandColor) self.grass = true end
    self.base = true
    self.owner = Owner
    for K,Obj in pairs(self:surroundings()) do
        if not Obj.grass then
            Obj.color = SandColor
            Obj.grass = true
            Obj:draw()
        end
    end
    createLocation(self,true) -- create base at tile.
end

function Tile:canPlaceBuilding()
    if not self.grass then return false end
    if self.location then return false end
    for _,T in pairs(self:surroundings()) do
        if T.location then return false end
    end
    return true
end

function Tile:canBePort()
    if not self.grass then return false end
    if self.location then return false end
    for _,T in pairs(self:surroundings()) do
        if T.location then return false end
        if not T.grass then return true end
    end
    return false
end

local Player = class("Player")
local Players = {}
function Player:init(C,T)
    self.color= C self.name=T self.icon=StarMat
    table.insert(Players,self)
end
local Player1 = Player:new()
Player1:init(Color(250,50,50),"Ruby Kingdom")
local Player2 = Player:new()
Player2:init(Color(100,20,255),"Amethyst Kingdom")
local Player3 = Player:new()
Player3:init(Color(0,255,30),"Emerald Kingdom")
local Player4 = Player:new()
Player4:init(Color(100,230,230),"Diamond Kingdom")

local function createTroop(Tile,soldiers)
    table.insert(Troops,Tile)
    Tile.troops = math.min(Tile.troops + soldiers,99)
    Tile:draw()
end

local function deleteTroop(Tile)
    Tile.troops = 0
    Tile:draw()
    table.removeByValue(Troops,Tile)
end


local function handleAttack(origTile,attackTile)
    if not origTile or not attackTile then print("Could not attack, parameters missing!") return end
    if origTile.troops<=0 then return end
    if attackTile.troops>0 and attackTile.owner ~= origTile.owner then
        -- Attacking an enemy troop
        local AimTroops = attackTile.troops
        local HoldingTroops = origTile.troops
        deleteTroop(origTile)
        local Result = AimTroops-HoldingTroops
        attackTile.troops = Result
        if Result>0 then
            -- Enemy kept their tile
        else
            local AimOwner = attackTile.owner
            local TakingOwner = origTile.owner
            if attackTile.base then
                -- You capitulated the nation by taking their capital.
                for K,Loc in pairs(Locations) do
                    if Loc.tile.owner == AimOwner then Loc.tile.owner = TakingOwner Loc.tile:draw() end
                end
                for K,Troop in pairs(Troops) do -- Remove all of their troops
                    if Troop.owner == AimOwner then deleteTroop(Troop) Troop:draw() end
                end
                if attackTile.owner == PlyChosen then print("YOU DIED") end
            end
            attackTile.owner = TakingOwner
            attackTile.capitulated = true
            attackTile.troops = math.abs(Result)
        end
        soundWarfare()
        origTile:draw()
        attackTile:draw()
    else
        if attackTile.location then
            attackTile.owner = origTile.owner
        end
        attackTile.troops = math.min(attackTile.troops+origTile.troops,99)
        deleteTroop(origTile)
        attackTile.owner = origTile.owner
        origTile:draw()
        attackTile:draw()
        soundSuccess()
    end
end

local COLOR_BG = Color(100,100,100,255)

-- Rounds
local CurrentRound = 0
local CurrentTurn = -1 -- 0 = ruby, 1 = amethyst, 2 = emerald, 3 = diamond
local CurrentMove = 0 -- 0-10
local CurrentTurnPly = nil

local function nextTurn()
    CurrentMove = 0
    CurrentRound = CurrentRound + 1
    CurrentTurn = (CurrentTurn + 1)%4
    CurrentTurnPly = Players[CurrentTurn+1]
    if CurrentTurnPly.capitulated then print(format("%s has capitulated, their turn was skipped.",ClosestTurnPly.name)) nextTurn() end
    local ClosestDist = 1/0
    local ClosestLoc = nil
    local isBot = CurrentTurnPly ~= PlyChosen
    local Bot = CurrentTurnPly
    local rndTroop = nil
    if isBot then
        local LocTroops = {} -- Troops that this bot owns.
        for K,Troop in pairs(Troops) do
            if Troop.owner == Bot then table.insert(LocTroops,Troop) end
        end
        if #LocTroops<1 then print(format("%s has no troops. skipped their turn.",Bot)) nextTurn() return end
        rndTroop = LocTroops[math.random(1,#LocTroops)]
    end
    for K,Loc in pairs(Locations) do
        if isBot and Loc.tile.owner ~= CurrentTurnPly then -- If a bot is going and they see a building they don't own
            local D = Loc.tile.pos:getDistance(rndTroop.pos)
            if D < ClosestDist then
                ClosestDist = D
                ClosestLoc = Loc
            end
        end
        if Loc.tile.owner then createTroop(Loc.tile,troopEq()) end -- Create troops at every owned building.
    end
    if CurrentTurnPly ~= PlyChosen then
        -- If a bot is playing
        local path = getPath(rndTroop.node,ClosestLoc.tile.node)
        if not path then
            print(format("Bot %s could not find a path..",CurrentTurnPly.name))
            timer.simple(5,nextTurn)
            return
        else
            -- found a path
            print(format("Bot %s started from tile [%d,%d]",CurrentTurnPly.name,rndTroop.col,rndTroop.row))
            print(format("Bot %s moved to tile [%d,%d]",CurrentTurnPly.name,ClosestLoc.tile.col,ClosestLoc.tile.row))
            handleAttack(rndTroop,path[1].tile) -- Move by 2 tiles
            for K,P in pairs(path) do
                P.tile.owner = Bot
                P.tile.color = Color(0,0,0)
                P.tile:draw()
            end
            timer.simple(5,nextTurn)
        end
    end
end

-- Map making
local perlin = require("modules/perlin.txt")
perlin.load()

local function inrange2d(V,VMin,VMax)
    return (V.x > VMin.x and V.y > VMin.y and V.x < VMax.x and V.y < VMax.y)
end

local function getTileAtPos(V)
    for K,Row in pairs(Tiles) do
        for K,T in pairs(Tiles[K]) do
            if inrange2d(V,T.pos,T.pos+T.sz) then return T end
        end
    end
end

local function showMessageTitle(S)
    render.setFont(FontBigger)
    render.setRGBA(255,255,255,200)
    render.drawText(64,(256+128+64)*2,S,3)
end

local function showMessageSubtitle(S)
    render.setFont(FontMedium)
    render.setRGBA(255,255,255,200)
    render.drawText(64,(256+128+64+32)*2,S,3)
end


local StartButton = nil
local RestartButton = nil
local function loadInMap()
    render.createRenderTarget("rt")
    render.selectRenderTarget("rt")
        render.clear(COLOR_BG)
    render.selectRenderTarget() -- Background
    for GridX = 0,TilesX-1 do
        Tiles[GridX] = {}
        for GridY = 0,TilesY-1 do
            if not canRun() then coroutine.yield() end
            render.selectRenderTarget("rt")
            local C = perlin.noise(GridX+64*Seed,GridY+64*Seed,0.1,WaterSeed)
            Val = math.clamp(C+0.5,0,1)
            local OffsetX = (GridY%2~=0 and HexWidth*0.5 or 0)
            render.setMaterial(GrassMaterial)
            local LocTile = createTile(GridX,GridY,StartPos.x+GridX*HexWidth+OffsetX,StartPos.y+GridY*HexHeight*0.75,HexWidth,HexHeight,C)
            render.selectRenderTarget()
        end
    end
    
    -- Init Player bases
    Tiles[1][1]:initBase(Player1)
    Tiles[1][9]:initBase(Player2)
    Tiles[18][1]:initBase(Player3)
    Tiles[18][9]:initBase(Player4)
    
    -- Loop through a second time to sprinkle in buildings
    for GridX = 0,TilesX-1 do
        for GridY = 0,TilesY-1 do
            if not canRun() then coroutine.yield() end
            local C = perlin.noise(GridX+64*Seed,GridY+64*Seed,0.1,WaterSeed)
            local LocTile = Tiles[GridX][GridY]
            local isGrass = LocTile.grass
            local isBuilding = LocTile.location
            if(not isBuilding and LocTile:canPlaceBuilding() and C%3>2.9) then
                createLocation(LocTile)
            end
            if isGrass and C%3>0.3 and LocTile:canBePort() then
                createLocation(LocTile,false,true)
            end
        end
    end
    return true
end

loadMapCo = coroutine.create(loadInMap)

-- UI
StartButton = createButton(512+128,512+256+64,350,150,Color(100,100,200,255),"Start",FontBiggest)
StartButton:whenPressedRender(function(self,changed)
    if not changed then return end
    if not HasChosenPly then return end
    StartedGame = true
    print("Started the game!")
    nextTurn()
    self:remove()
    ui.reloadUI()
end)

timer.create("fps",1,0,function() CurFPS = 0 end)

local function postLoadMap()
    local Curtime = timer.curtime()
    if Curtime < FPSTime+1/FPS then return end
    local DeltaTime = Curtime-FPSTime
    if not canRun() then return end
    if CursorPos==OldCursor then return end -- Don't waste time recalculating
    CurFPS = CurFPS + 1
    render.selectRenderTarget("overlay")
        render.clear(Color(0,0,0,0))
        render.setFont(GeneralFont)
        render.drawText(0,0,format("FPS: %d/%d",CurFPS,FPS),3)
        render.drawText(0,25,"Seed: "..Seed,3)
        for K,Place in pairs(Locations) do
            local Dist = math.min(Place.pos:getDistance(CursorPos),1000)
            if Dist < 400 then
                local C = (Place.base and Place.capitulated) and Place.owner.color or Color(255,255,255)
                C[4] = (1-Dist/400)*255+20
                render.setColor(C)
                render.drawText(Place.pos.x,Place.pos.y,Place.name,1)
            end
        end
        AimTile = getTileAtPos(CursorPos)
        if AimTile then
            render.setMaterial(GrassMaterial)
            drawHexagonSide(AimTile.pos.x,AimTile.pos.y,AimTile.sz.x,AimTile.sz.y,Color(255,255,255,150))
            local IsLocation = AimTile.location
            if IsLocation then
                showMessageSubtitle(format(
                    "A location tile.\nName: %s -- There are %s troops here.",
                    AimTile.location.name,
                    AimTile.troops>0 and tostring(AimTile.troops) or "no"
                ))
            else
                showMessageSubtitle(format(
                    "A %s tile. There are %s troops here.",
                    AimTile.grass and "grass" or "water",
                    AimTile.troops>0 and tostring(AimTile.troops) or "no"
                ))
            end
        end
        if AimTile and HoldingTroop then
            render.setColor(AimTile.pos:getDistance(HoldingTroop.pos)>100 and Color(255,0,0) or Color(0,255,0))
            render.drawLine(HoldingTroop.pos.x,HoldingTroop.pos.y,CursorPos.x,CursorPos.y)
            render.setMaterial(GrassMaterial)
            local C = PlyChosen.color C[4] = 150
            for K,Tile in pairs(HoldingTroop:surroundings()) do
                drawHexagonSide(Tile.pos.x,Tile.pos.y,Tile.sz.x,Tile.sz.y,C)
            end
            drawHexagonSide(HoldingTroop.pos.x,HoldingTroop.pos.y,HoldingTroop.sz.x,HoldingTroop.sz.y,C)
        end
        -- Both AimTile and UI
        if not HasChosenPly and AimTile and AimTile.base then
            showMessageTitle(AimTile.owner.name)
        elseif not HasChosenPly then
            showMessageTitle("Choose a player")
        else
            showMessageTitle(format("You are the %s",PlyChosen.name))
        end
        if StartedGame then
            render.drawText(256-64,128-32,"It is the "..CurrentTurnPly.name.."'s turn!",3)
            render.drawText(256-64,128,"Round: "..CurrentRound,3)
            render.drawText(256-64,128+32,"Move: "..CurrentMove.."/"..MaxMoves,3)
            render.drawText(256-64,128+64,"Total Moves: "..PlyMoves,3)
        end
        if AimTile then
            local T = format("[%d,%d]",AimTile.col,AimTile.row)
            render.setRGBA(80,80,80,150)
            render.drawRect(CursorPos.x,CursorPos.y,25*#T/3,25)
            render.setRGBA(255,255,255,150)
            render.setFont(GeneralFont)
            render.drawText(CursorPos.x,CursorPos.y,T,3)
        end
        OldCursor = CursorPos
        FPSTime = Curtime
    render.selectRenderTarget()
end

hook.add("inputPressed","KeyHandler",function(key)
    -- TODO: replace this fucking garbage with keyDown when fast finally updates sf in 5 years
    if not CursorOnScreen then return end
    if not AimingUI and not AimTile then return end
    if key == KEY.E then
        if not HasChosenPly and AimTile and AimTile.base then
            PlyChosen = AimTile.owner
            HasChosenPly = true
            print("Chose player "..PlyChosen.name)
            soundSuccess()
        elseif CurrentTurnPly == PlyChosen and AimTile then
            if AimTile.troops > 0 and not HoldingTroop and AimTile.owner == PlyChosen then
                soundSuccess()
                HoldingTroop = AimTile
            elseif HoldingTroop then
                -- Release troop.
                if not AimTile.grass and HoldingTroop.grass and not HoldingTroop.port then soundFail() return end
                if HoldingTroop == AimTile then soundSuccess() HoldingTroop = nil return end
                if AimTile.pos:getDistance(HoldingTroop.pos)>100 then soundFail() return end
                
                handleAttack(HoldingTroop,AimTile)
                HoldingTroop = nil
                CurrentMove = CurrentMove + 1
                PlyMoves = PlyMoves + 1
                if CurrentMove >= MaxMoves then nextTurn() end
            else
                soundFail()
            end
        end
    end
end)

hook.add("renderoffscreen","loadInMap",function()
    -- Loading in Map.
    if coroutine.status(loadMapCo) ~= "dead" then
        if canRun() then
            res = coroutine.resume(loadMapCo)
            if res then
                print("Loaded in map!")
                hasLoadedMap = true
                hook.add("renderoffscreen","postLoadMap",postLoadMap)
                hook.remove("renderoffscreen","loadInMap")
            end
        end
    end   
end)

hook.add("renderoffscreen","TilesToRefresh",function()
    if #TilesToRefresh==0 then return end
    for K,Tile in pairs(TilesToRefresh) do
        render.selectRenderTarget("rt")
            local Pos = Tile.pos
            local Size = Tile.sz
            local C = Tile.color
            C[4] = 255
            if Tile.base then C = SandColor end
            render.setColor(C)
            render.setMaterial(GrassMaterial)
            drawHexagonSide(Pos.x,Pos.y,Size.x,Size.y,C)
            if Tile.base then
                render.setMaterial(Tile.owner.icon)
                drawHexagonSide(Tile.pos.x,Tile.pos.y,Tile.sz.x,Tile.sz.y,Tile.owner.color)
            elseif Tile.location then
                render.setMaterial(LocationMaterial)
                drawHexagonSide(Tile.pos.x,Tile.pos.y,Tile.sz.x,Tile.sz.y,Tile.owner and Tile.owner.color or Color(255,255,255))
            end
            if Tile.troops>0 then
                
                if Tile.troops>70 and Tile.grass then
                    render.setMaterial(TankMaterial)
                elseif Tile.grass then
                    render.setMaterial(TroopMaterial)
                else
                    render.setMaterial(SubMaterial)
                end
                drawHexagonSide(Tile.pos.x,Tile.pos.y,Tile.sz.x,Tile.sz.y,Tile.owner.color)
            end
        render.selectRenderTarget()
        if not canRun() then return end
        TilesToRefresh[K] = nil
    end
end)

hook.add("render","",function()
    if not hasLoadedMap then
        render.drawText(256,256,format("Loading in map%s",sub("...",1,timer.curtime()%3+1)),1)
    else
        -- Map is loaded
        render.setFilterMag(0)
        render.setColor(Color(255,255,255,255))
        render.setRenderTargetTexture("rt")
        render.drawTexturedRect(0,0,512,512)
        render.setRenderTargetTexture("overlay")
        render.drawTexturedRect(0,0,512,512)
        ui.drawUI()
        CursorOnScreen = render.cursorPos() and true or false
        if render.cursorPos() then CursorPos = Vector(render.cursorPos())*2 end
    end
end)