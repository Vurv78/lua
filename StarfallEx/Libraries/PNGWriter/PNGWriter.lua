--@name pnglib v1.1
--@author wyozi (+ Vurv)
-- Original Source: https://github.com/wyozi/lua-pngencoder, which was transpiled from https://www.nayuki.io/page/tiny-png-output
-- Edited by Vurv to add all of the helper functions, PNG type enums, localization efficiency, SF specifics.
-- Please see his license on this work (GNU Lesser Public License)

-- Breaks if you pass floating point numbers in pixel data.

local DEFLATE_MAX_BLOCK_SIZE = 65535

-- Public ENUMS
PNG_INVALID = 0
PNG_RGB = 1
PNG_RGBA = 2

-- Local Functions for efficiency
local char, ceil, floor, insert = string.char, math.ceil, math.ceil, table.insert
local rshift, lshift, bxor, bor, band, bnot = bit.rshift, bit.lshift, bit.bxor, bit.bor, bit.band, bit.bnot

local png_meta = {}
png_meta.__index = png_meta

local function putBigUint32(val, tbl, index)
    for i=0,3 do tbl[index + i] = band(rshift(val, (3 - i) * 8), 0xFF) end
end

-- Internal function, don't use this.
function png_meta:writeBytes(data, index, len)
    index = index or 1
    len = len or #data
    for i=index,index+len-1 do
        insert(self.output, char(data[i]))
    end
end

-- You may use this, it's a bit complex though without vector handholding or anything.
function png_meta:write(pixels)
    local count = #pixels  -- Byte count
    assert(count == self.bytes_per_pixel, "Writing an incorrect amount of bytes per pixel. You might be writing RGB data to an RGBA Image, or vice versa.")
    local pixelPointer = 1
    while count > 0 do
        if self.positionY >= self.height then
            error("All image pixels already written")
        end
        if self.deflateFilled == 0 then -- Start DEFLATE block
            local size = DEFLATE_MAX_BLOCK_SIZE
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
        assert(self.positionX < self.lineSize and self.deflateFilled < DEFLATE_MAX_BLOCK_SIZE)

        if (self.positionX == 0) then  -- Beginning of line - write filter method byte
            local b = {0}
            self:writeBytes(b)
            self:crc32(b, 1, 1)
            self:adler32(b, 1, 1)
            self.positionX = self.positionX + 1
            self.uncompRemain = self.uncompRemain - 1
            self.deflateFilled = self.deflateFilled + 1
        else -- Write some pixel bytes for current line
            local n = DEFLATE_MAX_BLOCK_SIZE - self.deflateFilled
            if (self.lineSize - self.positionX < n) then
                n = self.lineSize - self.positionX
            end
            if (count < n) then
                n = count
            end
            assert(n > 0)
            self:writeBytes(pixels, pixelPointer, n)
            self:crc32(pixels, pixelPointer, n)
            self:adler32(pixels, pixelPointer, n)
            count = count - n
            pixelPointer = pixelPointer + n
            self.positionX = self.positionX + n
            self.uncompRemain = self.uncompRemain - n
            self.deflateFilled = self.deflateFilled + n
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

function png_meta:crc32(data, index, len)
    self.crc = bnot(self.crc)
    for i = index,index + len - 1 do
        local byte = data[i]
        for j=0,7 do
            local nbit = band(bxor(self.crc, rshift(byte, j)), 1)
            self.crc = bxor(rshift(self.crc, 1), band((-nbit), 0xEDB88320))
        end
    end
    self.crc = bnot(self.crc)
end

function png_meta:adler32(data, index, len)
    local s1 = band(self.adler, 0xFFFF)
    local s2 = rshift(self.adler, 16)
    for i=index,index+len-1 do
        s1 = (s1 + data[i]) % 65521
        s2 = (s2 + s1) % 65521
    end
    self.adler = bor(lshift(s2, 16), s1)
end


-- Helper functions by Vurv
-- All non "Fast" functions automatically floor their components to avoid image corruption.

-- RGBA
function png_meta:writeColor(col)
    local r, g, b, a = col.r, col.g ,col.b, col.a
    return self:write{ r and floor(r) or 255, g and floor(g) or 255, b and floor(b) or 255, a and floor(a) or 255 }
end
png_meta.writeColorFast = png_meta.write

-- RGBA
function png_meta:writeVector(vec)
    local r, g, b, a = vec[1], vec[2] ,vec[3], vec[4]
    return self:write{ r and floor(r) or 255, g and floor(g) or 255, b and floor(b) or 255, a and floor(a) or 255 }
end

function writeVectorFast(vec)
    self:write{ vec[1] or 255, vec[2] or 255, vec[3] or 255, vec[4] or 255 }
end

function png_meta:writeColorRGB(col)
    local r, g, b = col.r, col.g ,col.b
    return self:write{ r and floor(r) or 255, g and floor(g) or 255, b and floor(b) or 255}
end

function png_meta:writeColorRGBFast(col)
    self:write{ col.r or 255, col.g or 255, col.b or 255 }
end

function png_meta:writeVectorRGB(vec)
    local r, g, b = vec[1], vec[2] ,vec[3]
    return self:write{ r and floor(r) or 255, g and floor(g) or 255, b and floor(b) or 0, a and floor(a) or 255 }
end

function png_meta:writeVectorRGBFast(vec)
    self:write{ vec[1] or 255, vec[2] or 255, vec[3] or 255 }
end

function png_meta:writeRGB(r, g, b)
    return self:write{ r and floor(r) or 255, g and floor(g) or 255, b and floor(b) or 255 }
end

function png_meta:writeRGBFast(r, g, b)
    return self:write{ r or 255, g or 255, b or 255 }
end

function png_meta:writeRGBA(r, g, b, a)
    return self:write{ r and floor(r) or 255, g and floor(g) or 255, b and floor(b) or 255, a and floor(a) or 255 }
end

function png_meta:writeRGBAFast(r, g, b, a)
    return self:write{ r or 255, g or 255, b or 255, a or 255 }
end

function png_meta:export(file_name)
    assert(CLIENT, "You can't write files on the SERVER realm.")
    assert(self.done,"This image is not filled with pixel data!")
    return file.write(file_name, table.concat(self.output))
end

local function createPNG(width, height, color_mode)
    color_mode = color_mode or "rgb"

    local img_type = ( (color_mode=="rgb") and PNG_RGB or (color_mode=="rgba" and PNG_RGBA or PNG_INVALID) )
    assert(img_type~=PNG_INVALID, "PNG was created with an invalid color mode. Please give \"rgb\" or \"rgba\"")

    local bytes_per_pixel, colorType = 3, 2
    if img_type == PNG_RGBA then
        bytes_per_pixel, colorType = 4, 6
    end

    local instance = setmetatable({
        width = width,
        height = height,
        done = false, -- Whether the image is full or not.
        output = {}, -- PNG Data
        type = img_type,
        bytes_per_pixel = bytes_per_pixel
    }, png_meta)

    instance.lineSize = width * bytes_per_pixel + 1
    instance.uncompRemain = instance.lineSize * height
    local numBlocks = ceil(instance.uncompRemain / DEFLATE_MAX_BLOCK_SIZE)
    local idatSize = numBlocks * 5 + 6
    idatSize = idatSize + instance.uncompRemain
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
    instance.crc = 0
    instance:crc32(header, 13, 17)
    putBigUint32(instance.crc, header, 30)
    instance:writeBytes(header)
    instance.crc = 0
    instance:crc32(header,38,6)
    instance.adler = 1
    instance.positionX = 0
    instance.positionY = 0
    instance.deflateFilled = 0
    return instance
end

return createPNG