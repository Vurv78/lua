-- Mini Streams library

---@class DataStream
---@field content string # Reader only
---@field ptr integer # Reader only
---@field len number # Reader only
---@field index number # Writer only
---@field parts string # Writer only
local DataStream = {}
DataStream.__index = DataStream

---@param str string
---@return DataStream
function DataStream.new(str)
	return setmetatable({
		content = str,
		ptr = 0,
		len = str and #str or 0,

		parts = {},
		index = 0
	}, DataStream)
end

---@return number u8
function DataStream:readU8()
	self.ptr = self.ptr + 1
	return string.byte(self.content, self.ptr)
end

---@param n integer # 8, 16, 32, 64 ...
---@return number
function DataStream:readU(n)
	local bytes = n / 8
	local out = 0
	for i = 0, bytes - 1 do
		local b = self:readU8()
		out = out + bit.lshift(b, 8 * i)
	end
	return out
end

---@return string
function DataStream:readString()
	return self:readUntil(0)
end

---@param len integer
function DataStream:read(len)
	local ret = string.sub(self.content, self.ptr, self.ptr + len)
	self.ptr = self.ptr + len
	return ret
end

---@param byte integer
---@return string
function DataStream:readUntil(byte)
	self.ptr = self.ptr + 1
	local ed = string.find(self.content, string.char(byte), self.ptr, true)
	local ret = string.sub(self.content, self.ptr, ed)
	self.ptr = ed
	return ret
end

---@param byte integer
function DataStream:writeU8(byte)
	self.index = self.index + 1
	self.parts[self.index] = string.char(byte)
end

---@param str string
---@param not_terminated boolean # Whether to append a null char to the end, to make this able to be read with readString. (Else, will need to be self:read())
function DataStream:writeString(str, not_terminated)
	self.index = self.index + 1
	self.parts[self.index] = str

	if not not_terminated then
		self:writeU8(0)
	end
end

---@param n integer
function DataStream:writeU16(n)
	self:writeU8( n % 256 )
	self:writeU8( math.floor(n / 256) )
end

---@param n integer
function DataStream:writeU32(n)
	self:writeU16( n % 65536 )
	self:writeU16( math.floor(n / 65536) )
end

---@param n integer
function DataStream:writeU64(n)
	self:writeU32( n % 4294967296 )
	self:writeU32( math.floor(n / 4294967296) )
end

---@return string
function DataStream:getBuffer()
	return table.concat(self.parts)
end

--[[
local Example = DataStream.new()
Example:writeU64(125421)
Example:writeU32(22)
Example:writeU16(222)

local s = "foo bar!"
Example:writeU16(#s)
Example:writeString(s, true)

Example:writeU32(352)

local content = Example:getBuffer()
local Reader = DataStream.new(content)
print(content)
print("----")
print( Reader:readU(64) )
print( Reader:readU(32) )
print( Reader:readU(16) )
print( Reader:read(Reader:readU(16)) )
print( Reader:readU(32) )
]]

return DataStream