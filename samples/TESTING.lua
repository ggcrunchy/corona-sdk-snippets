--- Staging area.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Corona modules --
local composer = require("composer")

-- --
local Scene = composer.newScene()

--
function Scene:create ()
	--
end

Scene:addEventListener("create")

--
function Scene:show (e)
	if e.phase == "will" then return end
--	require("mobdebug").start()
---[=[
	local svd = require("linear_algebra_ops.svd")
	local fftc = require("signal_ops.fft_convolution")
	local mat = {}
	local mm, nn, ii = 25, 25, 1
	for i = 1, nn do
		for j = 1, mm do
			mat[ii], ii = 1--[[math.random(22)]], ii + 1
		end
	end
	local s, u, v = svd.SVD_Square(mat, mm)--svd.SVD(mat, mm, nn)
s,u = u,s
if mm == 4 then
	vdump(s)
	vdump(u)
	vdump(v)
end
do
	local utils = require("signal_ops.utils")
	local fft_utils = require("dft_ops.utils")
	local real_fft=require("dft_ops.real_fft")
	local tt1=os.clock()
	local uu={}
	local vv={}
	local nu, nv = #u / #s, #v / #s
	local ulen, up = utils.LenPower(mm, nu)
	local vlen, vp = utils.LenPower(nn, nv)
	local k1, arr1={},{}
	for i = 1, #u, nu do
		local out = {}
		for j = 0, nu - 1 do
			k1[j + 1] = u[i + j]
		end
		utils.PrecomputeKernel_1D(out, up, k1, nu)
		arr1[#arr1+1]=out
	end
	local k2,arr2={},{}
	for i = 1, #v, nv do
		local out = {}
		for j = 0, nv - 1 do
			k2[j + 1] = v[i + j]
		end
		utils.PrecomputeKernel_1D(out, up, k2, nv)
		arr2[#arr2+1]=out
	end
	local tt2=os.clock()
	-- In signal, do same for rows on startup...
	local lhs,ss = {}, {}
	for i = 1, #u, nu do
		local out = {}
		for j = 0, nu - 1 do
			ss[j + 1] = mat[i + j]
		end
		utils.PrecomputeKernel_1D(out, up, ss, nu)
		lhs[#lhs + 1] = out
	end
	-- Then do just multiply / IFFT on left
	local sss,ttt,uuu={},{},{}
	local pk = utils.MakePrecomputedKernelFunc_1D(ttt)
	for rank = 1, mm do
		local u,v=arr1[rank],arr2[rank]
		for i = 1, #lhs do
			fft_utils.Multiply_1D(lhs[i], u, up, sss)

			-- ...transform back to the time domain...
			real_fft.RealIFFT_1D(sss, .5 * up)

			-- ...and get the requested part of the result.
--			for i = 1, ulen do
--				uuu[i] = sss[i]
--			end

			pk(vp, sss, ulen, v)

			real_fft.RealIFFT_1D(sss, .5 * vp)
--[[
Convolve_1D(signal, kernel, opts)
		end

		count, from, size, offset, signal, opts, kernel = len, Columns, offset, 0, RowVector, RowOpts, v
]]
		end
		if rank == 15 then
		break
		end
	end
	-- On right, still need to do FFT first, then multiply and IFFT
	print("TIME", tt2-tt1, os.clock()-tt2)
--	if true then return end
end
	local dim, num = 25, 25
local tt0=os.clock()
	for NUM = 1, num do
		local sum = {}
	--	print("MATRIX", NUM)
		for j = 1, dim^2 do
			mat[j] = math.random(256)
			sum[j] = 0
		end
		local u, _, v = svd.SVD_Square(mat, dim)
		local n = #u
		for rank = 1, dim do
			local fnorm, j = 0, 1
			for ci = rank, n, dim do
				local cval = u[ci]

				for ri = rank, n, dim do
					sum[j] = sum[j] + cval * v[ri]
					fnorm, j = fnorm + (mat[j] - sum[j])^2, j + 1
				end
			end
		--	print("Approximation for rank " .. rank, fnorm)
		end
	--	print("")
	end
print("TTTT", (os.clock() - tt0) / num)
--if true then return end
--]=]
	local oc=os.clock
	local abs,floor,random,sqrt=math.abs,math.floor,math.random,math.sqrt
	local overlap=require("signal_ops.overlap")
	local t1=oc()
	local A={}
	local B={}
	local M, N = 81, 25
	local ii,jj=random(256), random(256)
	for i = 1, M^2 do
		A[i]=ii
		ii=ii+random(16)-8
	end
	for i = 1, N^2 do
		B[i]=jj
		jj=jj+random(16)-8
	end
	local t2 = oc()
	local separable = require("signal_ops.separable")
	local kd = separable.DecomposeKernel(B, N)
	local fopts = { into = {} }
	local sopts = { into = {}, max_rank = math.ceil(N / 5 - 1) }
	NN=N+20
	for i = 1, 20 do
	--	fftc.Convolve_2D(A, B, M, N, fopts)
		separable.Convolve_2D(A, M, kd, sopts)
	end
	local t3 = oc()
	print("VVV", t2 - t1, (t3 - t2) / 20, sopts.max_rank)
	local o1 = fftc.Convolve_2D(A, B, M, N, fopts)
	local rank = sopts.max_rank
	for i = 1, N do
		sopts.max_rank = i
		local t4=oc()
		local o2 = separable.Convolve_2D(A, M, kd, sopts)
		local sum, sum2 = 0, 0
		for j = 1, #o2 do
			local diff = abs(o2[j] - o1[j])
			sum, sum2 = sum + diff, sum2 + --[[floor]] (sqrt(diff))
		end
		print("APPROX", i, sum, sum / #o2, oc() - t4)
		print("SQRTAPX", sum2, sum2 / #o2)
	end
--[==[
	local t2=oc()
	local opts={into = {}}
	overlap.OverlapAdd_2D(A, B, M, N, opts)
	local t3=oc()
	--[[
	local tt=0
	for i = 1, 40 do
		overlap.OverlapAdd_2D(A, B, M, N, opts)
		local t4=oc()
		tt=tt+t4-t3
		t3=t4
	end
	print("T", t2-t1, t3-t2, tt / 41)
	]]
	local abs=math.abs
	local max=0
	local out = require("signal_ops.fft_convolution").Convolve_2D(A, B, M, N)
	print("N", #opts.into, #out)
	local into,n=opts.into,0
	for i = 1, #into do
		local d = abs(into[i]-out[i])
		if d > 1 then
			print(i, into[i], out[i])
			n=n+1
			if n == N then
				break
			end
		end
	end
	local t4=oc()
	local AA={}
	for i = 1, 2 * N do
		AA[i] = math.random(256)
	end
	local t5=oc()
--	require("signal_ops.fft_convolution").Convolve_2D(A, B, N, 2)
	local t6=oc()
	overlap.OverlapAdd_2D(A, B, 8, N)
	local t7=oc()
	print("OK", t3-t2,t4-t3,t5-t4,t6-t5,t7-t6)
]==]
end

Scene:addEventListener("show")

--[[
	Near / not-too-far future TODO list:

	- Finish off seams sample, including dealing with device-side problems (PARTIAL)
	- Do the colored corners sample (PARTIAL)

	- Proceed with editor, finally implement some things like the background view
	- Refine link system, make more linkables (FSM's? All those things I was making before...)
	- Editor-wise, generally just make everything prettier, cleaner
	- Improve custom widgets (Bitmap, Grid1D, Grid2D, Keyboard, Link, LinkGroup, etc.)
	- Make some dialogs to stress-test the section feature
	- Decouple dialogs from the editor
	- Decouple links / tags from editor? Instancing?
	- Some sort of stuff for recurring UI tasks: save / load dialogs, listbox, etc. especially ones that recur outside the editor (PARTIAL)
	- Kill off redundant widgets (button, checkbox)

	- Play with input devices

	- Fix formatting, which is rather off on tablets and probably more high-definition phones
	- To that end, do a REAL objects helper module, that digs in and deals with anchors and such (PROBATION)

	- The Great Migration! (i.e. move much of snippets into CrownJewels and Tektite submodules) (PARTIAL)
	- Might even be worth making the submodules even more granular
	- Kick off a couple extra programs to stress-test submodule approach

	- Deprecate DispatchList? (perhaps add some helpers to main)

	- Make the resource system independent of Corona, then start using it more pervasively

	- Figure out if quaternions ARE working, if so promote them
	- Figure out what's wrong with some of the code in collisions module (probably only practical from game side)

	- Embedded free list / ID-occupied array ops modules
	- Finally finish mesh ops / Delaunay
	- Finish up the dart-throwing stuff
	- Finish up the union-find-delete, some of those other data structures
	- Do a CMV or Poisson MVC sample?
	- Start something with geometric algebra, a la Lengyel
]]

return Scene