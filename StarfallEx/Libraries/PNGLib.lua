--@name Lua PngLib by wyozi (Edited by Vurv)
--@author wyozi
-- Original Source: https://github.com/wyozi/lua-pngencoder
-- I (Vurv) do not claim any ownership of this code, I only edited it a little to make it more efficient in terms of global function calls.
-- Please see his license on this work (GNU Lesser Public License)

-- Lua libs
local bit = bit
local table = table
local string = string

local insert = table.insert

local char = string.char

local rshift = bit.rshift
local lshift = bit.lshift
local bxor = bit.bxor
local bor = bit.bor
local band = bit.band
local bnot = bit.bnot

local ceil = math.ceil

local Png = {}
Png.__index = Png
local DEFLATE_MAX_BLOCK_SIZE = 65535
local function putBigUint32(val, tbl, index)
    for i=0,3 do tbl[index + i] = band(rshift(val, (3 - i) * 8), 0xFF) end
end
function Png:writeBytes(data, index, len)
    index = index or 1
    len = len or #data
    for i=index,index+len-1 do
        insert(self.output, char(data[i]))
    end
end
function Png:write(pixels)
    local count = #pixels  -- Byte count
    local pixelPointer = 1
    while count > 0 do
        if self.positionY >= self.height then
            error("All image pixels already written")
        end
        if self.deflateFilled == 0 then -- Start DEFLATE block
            local size = DEFLATE_MAX_BLOCK_SIZE;
            if (self.uncompRemain < size) then
                size = self.uncompRemain
            end
            local header = {  -- 5 bytes long
                band((self.uncompRemain <= DEFLATE_MAX_BLOCK_SIZE and 1 or 0), 0xFF),
                band(rshift(size, 0), 0xFF),
                band(rshift(size, 8), 0xFF),
                band(bxor(rshift(size, 0), 0xFF), 0xFF),
                band(bxor(rshift(size, 8), 0xFF), 0xFF),
            }
            self:writeBytes(header)
            self:crc32(header, 1, #header)
        end
        assert(self.positionX < self.lineSize and self.deflateFilled < DEFLATE_MAX_BLOCK_SIZE);

        if (self.positionX == 0) then  -- Beginning of line - write filter method byte
            local b = {0}
            self:writeBytes(b)
            self:crc32(b, 1, 1)
            self:adler32(b, 1, 1)
            self.positionX = self.positionX + 1
            self.uncompRemain = self.uncompRemain - 1
            self.deflateFilled = self.deflateFilled + 1
        else -- Write some pixel bytes for current line
            local n = DEFLATE_MAX_BLOCK_SIZE - self.deflateFilled;
            if (self.lineSize - self.positionX < n) then
                n = self.lineSize - self.positionX
            end
            if (count < n) then
                n = count;
            end
            assert(n > 0)
            self:writeBytes(pixels, pixelPointer, n)
            self:crc32(pixels, pixelPointer, n);
            self:adler32(pixels, pixelPointer, n);
            count = count - n;
            pixelPointer = pixelPointer + n;
            self.positionX = self.positionX + n;
            self.uncompRemain = self.uncompRemain - n;
            self.deflateFilled = self.deflateFilled + n;
        end

        if (self.deflateFilled >= DEFLATE_MAX_BLOCK_SIZE) then
            self.deflateFilled = 0
        end

        if (self.positionX == self.lineSize) then
            self.positionX = 0
            self.positionY = self.positionY + 1
            if (self.positionY == self.height) then
                local footer = {
                    0, 0, 0, 0,
                    0, 0, 0, 0,
                    0x00, 0x00, 0x00, 0x00,
                    0x49, 0x45, 0x4E, 0x44,
                    0xAE, 0x42, 0x60, 0x82,
                }
                putBigUint32(self.adler, footer, 1)
                self:crc32(footer, 1, 4)
                putBigUint32(self.crc, footer, 5)
                self:writeBytes(footer)
                self.done = true
            end
        end
    end
end

function Png:crc32(data, index, len)
    self.crc = bnot(self.crc)
    for i=index,index+len-1 do
        local byte = data[i]
        for j=0,7 do
            local nbit = band(bxor(self.crc, rshift(byte, j)), 1);
            self.crc = bxor(rshift(self.crc, 1), band((-nbit), 0xEDB88320));
        end
    end
    self.crc = bnot(self.crc)
end
function Png:adler32(data, index, len)
    local s1 = band(self.adler, 0xFFFF)
    local s2 = rshift(self.adler, 16)
    for i=index,index+len-1 do
        s1 = (s1 + data[i]) % 65521
        s2 = (s2 + s1) % 65521
    end
    self.adler = bor(lshift(s2, 16), s1)
end

local function begin(width, height)
    local bytesPerPixel, colorType = 3,2
    local state = setmetatable({ width = width, height = height, done = false, output = {} }, Png)
    state.lineSize = width * bytesPerPixel + 1
    state.uncompRemain = state.lineSize * height
    local numBlocks = ceil(state.uncompRemain / DEFLATE_MAX_BLOCK_SIZE)
    local idatSize = numBlocks * 5 + 6
    idatSize = idatSize + state.uncompRemain;
    local header = {
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0x08, colorType, 0x00, 0x00, 0x00,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0x49, 0x44, 0x41, 0x54,
        0x08, 0x1D,
    }
    putBigUint32(width, header, 17)
    putBigUint32(height, header, 21)
    putBigUint32(idatSize, header, 34)
    state.crc = 0
    state:crc32(header, 13, 17)
    putBigUint32(state.crc, header, 30)
    state:writeBytes(header)
    state.crc = 0
    state:crc32(header,38,6)
    state.adler = 1
    state.positionX = 0
    state.positionY = 0
    state.deflateFilled = 0
    return state
end

return begin