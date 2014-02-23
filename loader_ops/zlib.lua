--- An implementation of zlib, mostly adapted from [here](https://github.com/devongovett/png.js/blob/master/zlib.js).

--[[
From the original:

/*
 * Extracted from pdf.js
 * https://github.com/andreasgal/pdf.js
 *
 * Copyright (c) 2011 Mozilla Foundation
 *
 * Contributors: Andreas Gal <gal@mozilla.com>
 *               Chris G Jones <cjones@mozilla.com>
 *               Shaon Barman <shaon.barman@gmail.com>
 *               Vivien Nicolas <21@vingtetun.org>
 *               Justin D'Arcangelo <justindarc@gmail.com>
 *               Yury Delendik
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
]]

-- Standard library imports --
local assert = assert
local byte = string.byte
local max = math.max
local min = math.min
local setmetatable = setmetatable

-- Modules --
local lut = require("loader_ops.zlib_lut")
local operators = require("bitwise_ops.operators")

-- Forward references --
local band

if operators.HasBitLib() then -- Bit library available
	band = operators.band
else -- Otherwise, make equivalent for zlib purposes
	function band (a, n)
		return a % (n + 1)
	end
end

-- Imports --
local band_strict = operators.band
local bnot = operators.bnot
local bor = operators.bor
local lshift = operators.lshift
local rshift = operators.rshift

-- Exports --
local M = {}
local ttt, oc = TTT, os.clock
ttt.rb=0
-- --
local DecodeStream = {}

DecodeStream.__index = DecodeStream

--
local function Slice (t, from, to, into)
	local slice, j = into or {}, 1

	for i = from, to do
		slice[j], j = t[i], j + 1
	end

	return slice, j - 1
end

--
local function DefYieldFunc () end

--- DOCME
function DecodeStream:GetBytes (opts)
	local yfunc = (opts and opts.yfunc) or DefYieldFunc
	local pos, up_to = self.m_pos, 1 / 0

	if opts and opts.length then
		up_to = pos + opts.length

		while not self.m_eof and #self < up_to do
			self:ReadBlock(yfunc)
		end
	else
		while not self.m_eof do
			self:ReadBlock(yfunc)
		end
	end

	up_to = min(#self, up_to)

	self.m_pos = up_to

	return (Slice(self, pos, up_to - 1))
end

--
local function AuxNewStream (mt)
	return setmetatable({ m_pos = 1, m_eof = false }, mt)
end

--- DOCME
function M.NewDecodeStream ()
	return AuxNewStream(DecodeStream)
end

-- --
local HuffmanCheckDist = 50

-- --
local Lengths = {}

--
local function GenHuffmanTable (codes, from, yfunc, n)
	-- Find max code length, culling 0 lengths as an optimization.
	local max_len, nlens = 0, 0

	for i = 1, n or #from do
		local len = from[i]

		if len > 0 then
			Lengths[nlens + 1] = i - 1
			Lengths[nlens + 2] = len

			max_len, nlens = max(len, max_len), nlens + 2
		end
	end

	-- Build the table.
	local code, skip, step, cword, size, check = 0, 2, 1, 2^16, 2^max_len, HuffmanCheckDist

	codes.max_len, codes.mask = max_len, size - 1

	for i = 1, max_len do
		for j = 1, nlens, 2 do
			if i == Lengths[j + 1] then
				-- Bit-reverse the code.
				local code2, t = 0, code

				for _ = 1, i do
					local bit = t % 2

					code2, t = 2 * code2 + bit, (t - bit) / 2
				end

				-- Fill the table entries.
				local entry = cword + Lengths[j]

				for k = code2 + 1, size, skip do
					codes[k] = entry
				end

				code, step = code + 1, step + 1

				--
			--	if step == check then
			--		check = check + HuffmanCheckDist

				--	yfunc("huff")
			--	end
			end
		end

		code, skip, cword = code + code, skip + skip, cword + 2^16
	end

	return codes
end

-- --
local FlateStream = {}

FlateStream.__index = FlateStream

setmetatable(FlateStream, { __index = DecodeStream })

--
local function AuxGet (FS, n)
	local buf, size, bytes, pos = FS.m_code_buf, FS.m_code_size, FS.m_bytes, FS.m_bytes_pos
local a=2^size
	while size < n do
		buf = buf + byte(bytes, pos) * a--bor(buf, byte(bytes, pos) * 2^size)
		a=a*256
		size, pos = size + 8, pos + 1
	end

	FS.m_bytes_pos = pos

	return buf, size
end

--- DOCME
function FlateStream:GetBits (bits)
	local buf, size = AuxGet(self, bits)
	local bval = band(buf, 2^bits - 1)

	self.m_code_buf = rshift(buf, bits)
	self.m_code_size = size - bits

	return bval
end

--- DOCME
function FlateStream:GetCode (codes)
	local buf, size = AuxGet(self, codes.max_len)

	local code = codes[band(buf, codes.mask) + 1]
	local cval = band(code, 0xFFFF)
	local clen = (code - cval) / 2^16

	assert(size ~= 0 and size >= clen and clen ~= 0, "Bad encoding in flate stream")

	self.m_code_buf = rshift(buf, clen)
	self.m_code_size = size - clen

	return cval
end

--
local function Repeat (stream, array, i, len, offset, what)
	for _ = 1, stream:GetBits(len) + offset do
		array[i], i = what, i + 1
	end

	return i
end

-- --
local CompressedCheckDist = 50

-- --
local LitSlice, DistSlice = {}, {}

-- --
local LHT, DHT = {}, {}

--
local function Compressed (FS, fixed_codes, yfunc)
	if fixed_codes then
		return lut.FixedLitCodeTab, lut.FixedDistCodeTab
	else
		local num_lit_codes = FS:GetBits(5) + 257
		local num_dist_codes = FS:GetBits(5) + 1

		-- Build the code lengths code table.
		local map, clc_lens, clc_tab = lut.CodeLenCodeMap, LHT, DHT
		local count, n = FS:GetBits(4) + 4, #map

		for i = 1, count do
			clc_lens[map[i] + 1] = FS:GetBits(3)
		end

		for i = count + 1, n do
			clc_lens[map[i] + 1] = 0
		end

		GenHuffmanTable(clc_tab, clc_lens, yfunc, n)

		-- Build the literal and distance code tables.
		local i, len, codes, code_lens, check = 1, 0, num_lit_codes + num_dist_codes, LHT, CompressedCheckDist

		while i <= codes do
			local code = FS:GetCode(clc_tab)

			if code == 16 then
				i = Repeat(FS, code_lens, i, 2, 3, len)
			elseif code == 17 then
				len, i = 0, Repeat(FS, code_lens, i, 3, 3, 0)
			elseif code == 18 then
				len, i = 0, Repeat(FS, code_lens, i, 7, 11, 0)
			else
				len, i, code_lens[i] = code, i + 1, code
			end

			--
		--	if i >= check then
		--		check = check + CompressedCheckDist

			--	yfunc("codes")
		--	end
		end

		local _, lj = Slice(code_lens, 1, num_lit_codes, LitSlice)
		local _, dj = Slice(code_lens, num_lit_codes + 1, codes, DistSlice)

		GenHuffmanTable(LHT, LitSlice, yfunc, lj)
		GenHuffmanTable(DHT, DistSlice, yfunc, dj)

		return LHT, DHT
	end
end

--
local function Uncompressed (FS)
	local bytes, pos = FS.m_bytes, FS.m_bytes_pos
	local b1, b2, b3, b4 = byte(bytes, pos, pos + 3)
	local block_len = bor(b1, lshift(b2, 8))
	local check = bor(b3, lshift(b4, 8))

	assert(check == band(bnot(block_len), 0xFFFF), "Bad uncompressed block length in flate stream")

	pos = pos + 4

	FS.m_code_buf, FS.m_code_size = 0, 0

	for _ = 1, block_len do
		-- EOF?
		FS[#FS + 1], pos = byte(bytes, pos), pos + 1
	end

	FS.m_bytes_pos = pos
end

--
local function GetAmount (FS, t, code)
	code = t[code + 1]

	local low = band(code, 0xFFFF)
	local code2 = (code - low) / 2^16

	if code2 > 0 then
		code2 = FS:GetBits(code2)
	end

	return low + code2
end

--- DOCME
function FlateStream:ReadBlock (yfunc)
local t1=oc()
	-- Read block header.
	local hdr = self:GetBits(3)

	if band(hdr, 1) ~= 0 then
		self.m_eof, hdr = true, hdr - 1
	end

	hdr = hdr / 2

	assert(hdr < 3, "Unknown block type in flate stream")

	-- Uncompressed block.
	if hdr == 0 then
		return Uncompressed(self, yfunc)
	end

	-- Compressed block.
	local lit_ct, dist_ct = Compressed(self, hdr == 1, yfunc)
	local ld, dd, pos = lut.LengthDecode, lut.DistDecode, #self + 1

	while true do
		local code = self:GetCode(lit_ct)

		if code > 256 then
			local len = GetAmount(self, ld, code - 257)
			local dist = GetAmount(self, dd, self:GetCode(dist_ct)) + 1
			local from = pos - dist

			for i = from + 1, from + len do
				self[pos], pos = self[i], pos + 1
			end

		--	yfunc("read")

		elseif code < 256 then
			self[pos], pos = code, pos + 1
		else
ttt.rb=ttt.rb+oc()-t1
			return
		end
	end
end

--- DOCME
function M.NewFlateStream (bytes)
	local cmf, flg = byte(bytes, 1, 2)

	assert(cmf ~= -1 and flg ~= -1, "Invalid header in flate stream")
    assert(band(cmf, 0x0f) == 0x08, "Unknown compression method in flate stream")
    assert((lshift(cmf, 8) + flg) % 31 == 0, "Bad FCHECK in flate stream")
    assert(band_strict(flg, 0x20) == 0, "FDICT bit set in flate stream")

	local fs = AuxNewStream(FlateStream)

	fs.m_bytes = bytes
	fs.m_bytes_pos = 3
	fs.m_code_size = 0
	fs.m_code_buf = 0

	return fs
end

-- Export the module.
return M