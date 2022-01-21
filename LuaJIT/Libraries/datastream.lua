--[=[
	-- Medium-sized streams library by Vurv78
	-- Credit to RPFeltz (https://stackoverflow.com/questions/14416734/lua-packing-ieee754-single-precision-floating-point-numbers) for the floating point number implementation.
	-- Rest is by me.
	-- Fully documented with EmmyLua annotations.

	Features:
		Reading & Writing:
			Null terminated strings
			Signed Integers (8, 16, 32, 64)
			Unsigned Integers (8, 16, 32, 64)
			Set length strings

		Custom Structure system:
			There are custom structures you can create using the DataStruct type.
			This type abstracts the DataStream type by allowing you to form structs in a nice,
			visual pattern similar to C structs or whever else you'd normally use structs.

			See an example below.
]=]

local I8_MAX = 128
local I16_MAX = 32768
local I32_MAX = 2147483648
local I64_MAX = 9223372036854775808

local U8_MAX = 256
local U16_MAX = 65536
local U32_MAX = 4294967296
local U64_MAX = 18446744073709551616

local MAX = {
	[8] = I8_MAX,
	[16] = I16_MAX,
	[32] = I32_MAX,
	[64] = I64_MAX,
}

local UMAX = {
	[8] = U8_MAX,
	[16] = U16_MAX,
	[32] = U32_MAX,
	[64] = U64_MAX,
}

--- Internal class used by the DataStruct.  
--- Much better for lightweight data structures, or for missing features of the Datastruct (e.g. set length strings)  
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

function DataStream:__tostring()
	return "DataStream"
end

---@return number u8
function DataStream:readU8()
	self.ptr = self.ptr + 1
	return string.byte(self.content, self.ptr)
end

--- Reads an unsigned integer from the stream
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

--- Reads a signed 8 bit integer (-128, 128) from the stream
---@return number Int8 at this position
function DataStream:readI8()
	local x = self:readU8()
	if x >= I8_MAX then x = x - U8_MAX end
	return x
end

--- Reads a signed 8 bit integer (-128, 128) from the stream
---@return number Int8 at this position
function DataStream:readI16()
	local x = self:readU(16)
	if x >= I16_MAX then x = x - U16_MAX end
	return x
end

--- Reads a signed 8 bit integer (-128, 128) from the stream
---@param n integer # 8, 16, 32, 64 ...
---@return number Int8 at this position
function DataStream:readI(n)
	local val = self:readU(n)
	if val >= MAX[n] then val = val - UMAX[n] end
	return val
end

---@return string
function DataStream:readString()
	return self:readUntil(0)
end

--- Reads a IEEE754 Float32 from the stream and returns it
---@return number float
function DataStream:readF32()
	local b1, b2, b3, b4 = string.byte(self.content, self.ptr + 1, self.ptr + 4)
	self.ptr = self.ptr + 4

	local exponent = (b1 % 0x80) * 0x02 + math.floor(b2 / 0x80)
	local mantissa = math.ldexp(((b2 % 0x80) * 0x100 + b3) * 0x100 + b4, -23)
	if exponent == 0xFF then
		if mantissa > 0 then
			return 0 / 0
		else
			mantissa = math.huge
			exponent = 0x7F
		end
	elseif exponent > 0 then
		mantissa = mantissa + 1
	else
		exponent = exponent + 1
	end
	if b1 >= 0x80 then
		mantissa = -mantissa
	end
	return math.ldexp(mantissa, exponent - 0x7F)
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

---@param str string
---@param not_terminated boolean # Whether to append a null char to the end, to make this able to be read with readString. (Else, will need to be self:read())
function DataStream:writeString(str, not_terminated)
	self.index = self.index + 1
	self.parts[self.index] = str

	if not not_terminated then
		self:writeU8(0)
	end
end

--- Writes vararg bytes to the stream, connecting them with table.concat and string.char
function DataStream:write(...)
	self.index = self.index + 1
	self.parts[self.index] = table.concat {string.char(...)}
end

-- Packs a IEEE754 Float32 into 4 U8s and writes it into the buffer
---@param float number
function DataStream:writeF32(float)
	if float == 0 then
		self:write(0, 0, 0, 0)
	elseif float ~= float then
		self:write(0xFF, 0xFF, 0xFF, 0xFF)
	else
		local sign = 0x00
		if float < 0 then
			sign = 0x80
			float = -float
		end
		local mantissa, exponent = math.frexp(float)
		exponent = exponent + 0x7F
		if exponent <= 0 then
			mantissa = math.ldexp(mantissa, exponent - 1)
			exponent = 0
		elseif exponent > 0 then
			if exponent >= 0xFF then
				self:write(sign + 0x7F, 0x80, 0x00, 0x00)
			elseif exponent == 1 then
				exponent = 0
			else
				mantissa = mantissa * 2 - 1
				exponent = exponent - 1
			end
		end
		mantissa = math.floor(math.ldexp(mantissa, 23) + 0.5)

		self:write(
			sign + math.floor(exponent / 2),
			(exponent % 2) * 0x80 + math.floor(mantissa / 0x10000),
			math.floor(mantissa / 0x100) % 0x100,
			mantissa % 0x100
		)
	end
end

---@param byte integer
function DataStream:writeU8(byte)
	self.index = self.index + 1
	self.parts[self.index] = string.char(byte)
end

---@param n integer
function DataStream:writeU16(n)
	self:writeU8( n % U8_MAX )
	self:writeU8( math.floor(n / U8_MAX) )
end

---@param n integer
function DataStream:writeU32(n)
	self:writeU16( n % U16_MAX )
	self:writeU16( math.floor(n / U16_MAX) )
end

---@param n integer
function DataStream:writeU64(n)
	self:writeU32( n % U32_MAX )
	self:writeU32( math.floor(n / U32_MAX) )
end

--- Writes a signed byte to the buffer.
--- Note this will not handle cases where the number is infinity or nan.
---@param n integer
function DataStream:writeI8(n)
	if n < 0 then n = n + U8_MAX end
	self:writeU8(n % U8_MAX)
end

--- Writes a signed 16 bit integer to the buffer.
--- Note this will not handle cases where the number is infinity or nan.
---@param n integer
function DataStream:writeI16(n)
	if n < 0 then n = n + U16_MAX end

	self:write(
		n % U8_MAX,
		bit.rshift(n, 8) % U8_MAX
	)
end

--- Writes a signed 32 bit integer to the buffer.
--- Note this will not handle cases where the number is infinity or nan.
---@param n integer
function DataStream:writeI32(n)
	if n < 0 then n = n + U32_MAX end

	self:write(
		n % U8_MAX,
		bit.rshift(n, 8) % U8_MAX,
		bit.rshift(n, 16) % U8_MAX,
		bit.rshift(n, 24) % U8_MAX
	)
end

--- Writes a signed 64 bit integer to the buffer.
--- Note this will not handle cases where the number is infinity or nan.
---@param n integer
function DataStream:writeI64(n)
	if n < 0 then n = n + U64_MAX end

	self:write(
		n % U8_MAX,
		bit.rshift(n, 8) % U8_MAX,
		bit.rshift(n, 16) % U8_MAX,
		bit.rshift(n, 24) % U8_MAX,
		bit.rshift(n, 32) % U8_MAX,
		bit.rshift(n, 40) % U8_MAX,
		bit.rshift(n, 48) % U8_MAX,
		bit.rshift(n, 56) % U8_MAX
	)
end

---@return string
function DataStream:getBuffer()
	return table.concat(self.parts)
end

--- End of DataStream class, now for the DataStruct helper.

--- Helper Struct class to Read and Write structs from a struct definition
--- ## Example code
--- 	```lua
--- 		local Message = DataStruct [[
---				// Comments (C or Lua style.)
---				sender_id: u32,
---				message: cstr,
---
---				// Variable length array / Explicit vector.
---				n_reactions: u32,
---				reactions: [u8, $n_reactions]
--- 		]]
---
--- 		local msg = Message:encode {
---				sender_id = 55,
---				message = "Foobar",
---
---				n_reactions = 3,
---				reactions = { 2, 5, 23 }
--- 		}
---
--- 		local bytes = msg:getBuffer()
--- 		-- Ready to be used.
--- 	```
---@class DataStruct
---@field fields table<number, { key: string, rtype: string, count: string }>
---@field data table<number, any>
---@field n integer # Number of fields in the struct
---@field stream DataStream # Internal data stream used for encoding types to bytes.
local DataStruct = {}
DataStruct.__index = DataStruct

function DataStruct:__tostring()
	return "DataStruct #" .. self.n
end

---@type table<string, fun(self: DataStruct): number|string>
local Handlers = {
	["i8"] = function(self) return self:readI(8) end,
	["i16"] = function(self) return self:readI(16) end,
	["i32"] = function(self) return self:readI(32) end,

	["u8"] = function(self)  return self:readU(8) end,
	["u16"] = function(self) return self:readU(16) end,
	["u32"] = function(self) return self:readU(32) end,

	["cstr"] = function(self) return self:readString() end,

	["f32"] = function(self) return self:readF32() end,
	["f64"] = function(self) error("Not implemented") end
}

local WriteHandlers = {
	["i8"] = function(self, value) self:writeI8(value) end,
	["i16"] = function(self, value) self:writeI16(value) end,
	["i32"] = function(self, value) self:writeI32(value) end,
	["u8"] = function(self, value) self:writeU8(value) end,
	["u16"] = function(self, value) self:writeU16(value) end,
	["u32"] = function(self, value) self:writeU32(value) end,
	["cstr"] = function(self, value) self:writeString(value) end,
	["f32"] = function(self, value) self:writeF32(value) end,
	["f64"] = function(self, value) error("Not implemented") end
}

---@param definition string
local function parse(definition)
	local nocomments = string.gsub(definition, "[-/]+.-\n", "\n")

	local struct, n = {}, 1
	for line in nocomments:gmatch("[^\n\r,]+") do
		local key, rtype, count = line:match("%s*([%w_]+)%s*[:=]%s*%[?%s*([uifcstr]+%d*);?%s*%$?([%w_%d]*)%]?")

		-- Check if key exists, because an empty line being passed here would break it otherwise.
		-- Comments cause this.
		if key then
			if struct[key] then
				error("Repeated key [" .. key .. "] found at line " .. n .. " in SSBuilder")
			end

			local handler = Handlers[rtype]
			if not handler then error("Unknown or invalid type [".. rtype .. "] in SSBuilder") end

			-- "count" is the number of times to read the type.
			-- This is for array types [f32; 3].
			-- It may be a string, in case of variable length. [f32; $n]

			local t = { key, n, rtype, tonumber(count) or (count == "" and 1 or count) }
			struct[key], struct[n] = t, t
			n = n + 1
		end
	end
	return struct, n
end

setmetatable(DataStruct, {
	__call = function(_, str)
		local def, n = parse(str)
		return setmetatable({
			fields = def,
			n = n,
			stream = DataStream.new(),

			-- Read data
			data = {},
		}, DataStruct)
	end
})

--- Encodes data into bytes, from a DataStruct template.
---@param data table<string|number, any>
---@return DataStream writer # Writing stream, use :getBuffer() to get the bytes.
function DataStruct:encode(data)
	local out, writer = {}, DataStream.new()
	for k, v in pairs(self.fields) do
		local idx = v[1]
		assert(data[idx], "Missing field [" .. idx .. "] in DataStruct:encode")
	end

	for k, v in pairs(data) do
		local field = self.fields[k]
		if field then
			if type(k) == "number" then
				out[k] = v
			else
				local idx = field[2]
				out[idx] = v
			end
		end
	end

	for k, v in ipairs(out) do
		local field = self.fields[k]
		local ty, count = field[3], field[4]

		if type(count) == "number" then
			if count > 1 then
				for i = 1, count do
					WriteHandlers[ty](writer, v[i])
				end
			else
				WriteHandlers[ty](writer, v)
			end
		else
			-- Variable length
			local count = assert(data[count], "Missing variable reference [" .. count .. "] in DataStruct:encode")
			for i = 1, count do
				WriteHandlers[ty](writer, v[i])
			end
		end
	end
	return writer
end

--- Decodes data given a string of bytes.
---@param stream string
---@return table<string, any>
function DataStruct:decode(stream)
	local reader = DataStream.new(stream)
	local out = {}
	for nidx, v in ipairs(self.fields) do
		local idx, ty, count = v[1], v[3], v[4]
		if type(count) == "number" then
			if count > 1 then
				local t = {}
				for i = 1, count do
					t[i] = Handlers[ty](reader)
				end
				out[idx] = t
			else
				out[idx] = Handlers[ty](reader)
			end
		elseif count then
			-- Variable length
			local v = self.fields[count][1]
			assert(out[v], "Variable length field [" .. count .. "] not found at runtime")
			local count = out[v]
			assert(type(count) == "number", "Variable length field [" .. count .. "] is not a number")

			if count > 1 then
				local t = {}
				for i = 1, count do
					t[i] = Handlers[ty](reader)
				end
				out[idx] = t
			else
				out[idx] = Handlers[ty](reader)
			end
		end
	end
	return out
end

---@return string?
function DataStruct:getBuffer()
	return self.stream:getBuffer()
end

local Message = DataStruct [[
	// Comments (C or Lua style.)
	sender_id: u32,
	message: cstr,
	---
	// Variable length array / Explicit vector.
	n_reactions: u32,
	reactions: [u8, $n_reactions]
]]

local msg = Message:encode {
	sender_id = 55,
	message = "Foobar",

	n_reactions = 3,
	reactions = { 2, 5, 23 }
}

local bytes = msg:getBuffer()

return DataStream, DataStruct