--[[
	LibRecycle.lua
	A table recycling embeddable library.
	Released into the Public Domain without warranty. Use at your own peril!
	Credits: Norganna, MentalPower, Esamynn, Mikk
	
	LibRecycle no longer recycles tables as it actually uses more CPU than to let the GC handle them.
	Its sole purpose now is to watch for callers still using it and check for re-use of supposedly recycled tables.


	Usage:
		local LibRecycle = LibStub("LibRecycle")
		-- then:
		local acquire, recycle, clone, scrub = LibRecycle.All()

		-- DO NOT:  (it's not upgradable!)
		local acquire = LibRecycle.Acquire
		local recycle = LibRecycle.Recycle
		local clone = LibRecycle.Clone
		local scrub = LibRecycle.Scrub

	Functions:
		acquire( one, two, three, ...); Returns { one, two, three, ... }
		recycle( item ); Recycles the table "item" and all subtables. Clears all keys.
		recycle( table, key, key, ...); Recycles given keys in the table. Also clears their entries.
		clone( item, [unsafe] ); Returns a safe-cloned copy of the table (unless unsafe is true.)
		scrub( item ); Cleans the given table, recycling if necessary. Returns an empty table.
	
	
	unit test for reuse of table
		local foobarTable = {}
		foobarTable.test1 = "test1"
		recycle(foobarTable)
		foobarTable.test2 = "test2"

	unit test for recycling a table twice
		local foobarTable = {}
		foobarTable.test1 = "test1"
		recycle(foobarTable)
		recycle(foobarTable)

]]

local LIBRARY_VERSION_MAJOR = "LibRecycle"
local LIBRARY_VERSION_MINOR = 3

--[[-----------------------------------------------------------------

LibStub is a simple versioning stub meant for use in Libraries.
See <http://www.wowwiki.com/LibStub> for more info.
LibStub is hereby placed in the Public Domain.
Credits:
    Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke

--]]-----------------------------------------------------------------
do
	local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2
	local LibStub = _G[LIBSTUB_MAJOR]

	if not LibStub or LibStub.minor < LIBSTUB_MINOR then
		LibStub = LibStub or {libs = {}, minors = {} }
		_G[LIBSTUB_MAJOR] = LibStub
		LibStub.minor = LIBSTUB_MINOR

		function LibStub:NewLibrary(major, minor)
			assert(type(major) == "string", "Bad argument #2 to `NewLibrary' (string expected)")
			minor = assert(tonumber(strmatch(minor, "%d+")), "Minor version must either be a number or contain a number.")

			local oldminor = self.minors[major]
			if oldminor and oldminor >= minor then return nil end
			self.minors[major], self.libs[major] = minor, self.libs[major] or {}
			return self.libs[major], oldminor
		end

		function LibStub:GetLibrary(major, silent)
			if not self.libs[major] and not silent then
				error(("Cannot find a library instance of %q."):format(tostring(major)), 2)
			end
			return self.libs[major], self.minors[major]
		end

		function LibStub:IterateLibraries() return pairs(self.libs) end
		setmetatable(LibStub, { __call = LibStub.GetLibrary })
	end
end
--[End of LibStub]---------------------------------------------------

local oldlib,oldver = LibStub(LIBRARY_VERSION_MAJOR, true)
if oldlib and oldver<3 then
	-- Unfortunately, people take local copies of our methods, so we can't upgrade versions before 3
	ChatFrame1:AddMessage("LibRecycle: Could not upgrade - a pre-version 3 is already loaded.")
	return
end

local lib = LibStub:NewLibrary(LIBRARY_VERSION_MAJOR, LIBRARY_VERSION_MINOR)
if not lib then return end


-- Create a trashcan where tables go to die (weak-keyed to allow GC)
lib.trashcan = setmetatable({}, {__mode="k"})

lib.DEBUG = false

local function onreuse(tbl)
	if lib.trashcan[tbl]==true then
		geterrorhandler()("LibRecycle: An AddOn tried to use a recycled table!")
	else
		geterrorhandler()("LibRecycle: An AddOn tried to use a recycled table!\n- Recycled by: "..
			gsub(lib.trashcan[tbl] or "???", "[\r\n]+", " -- "))
	end
end
lib.recycledmeta = {
	__index = onreuse,
	__newindex = onreuse,
}


local function recycleone(tbl, depth)
	depth=depth or 0
	if type(tbl)=="table" then
		if lib.trashcan[tbl] then
			geterrorhandler()("LibRecycle: An AddOn tried to recycle the same table twice!")
			return
		end
		if lib.DEBUG then
			lib.trashcan[tbl]=debugstack(3+depth,1,0)
		else
			lib.trashcan[tbl]=true
		end
		for k,v in pairs(tbl) do
			if type(v)=="table" then
				if getmetatable(v) then
					geterrorhandler()("LibRecycle: Warning: An AddOn tried to recycle a (sub-)table with a metatable set (maybe a frame?). Not touching it!")
				else
					recycleone(v, depth+1)
				end
			end
			tbl[k]=nil
		end
		setmetatable(tbl, lib.recycledmeta)
	elseif tbl==nil then
		-- ohwell
	else
		geterrorhandler()("LibRecycle: Someone tried to recycle a " .. type(tbl) .."?")
		return
	end
end

function lib.Recycle(...)
	local n = select("#", ...)
	if n==1 then
		recycleone(..., 0)
	elseif n>=2 then
		local tbl=...
		for i=2,n do
			local k=select(i,...)
			recycleone(tbl[k])
			tbl[k]=nil
		end
	end
end

function lib.Acquire(...)
	local item, v

	item = {}

	-- And populate it if there's any args
	n = select("#", ...)
	for i = 1, n do
		v = select(i, ...)
		item[i] = v
	end
	return item
end

local function clone(source, unsafe  --[[ internal only: ]], depth, history)
	if type(source) ~= "table" then
		return source
	end

	if not depth then depth = 0 end
	if depth == 0 and not unsafe then
		history = {}
	end

	-- For all the values herein, perform a deep copy
	local dest = {}
	if history then history[source] = dest end
	for k, v in pairs(source) do
		if type(v) == "table" then
			if history then
				-- We are tracking the clone history.
				if history[v] then
					-- We have already cloned this table once, set a pointer to the previously
					-- cloned copy instead of recloning it.
					dest[k] = history[v]
				else
					-- Do a full clone of this node.
					dest[k] = clone(v, nil, depth+1, history)
				end
			else
				-- Do a full clone of this node.
				dest[k] = clone(v, nil, depth+1)
			end
		else
			dest[k] = v
		end
	end
	if history then
		for k,v in pairs(history) do history[k] = nil end
	end
	return dest
end
lib.Clone = clone

function lib.Scrub(item)
	-- We can only clean tables
	if type(item) ~= 'table' then return end

	-- Clean out any values from this table
	for k,v in pairs(item) do
		if type(v) == 'table' then
			-- Recycle this table
			recycleone(v)
			item[k] = nil
		else
			item[k] = nil
		end
	end
end





-----------------------------------------------------------------------
-- DEBUG STUFF

function lib.CollectGarbage()
	local n1=0
	for k,v in pairs(lib.trashcan) do
		n1=n1+1
	end
	collectgarbage("collect")
	local n2=0
	for k,v in pairs(lib.trashcan) do
		n2=n2+1
	end
	ChatFrame1:AddMessage("LibRecycle: " .. n2 .. " tables remaining in trash after garbage collection. (Had "..n1.." before)")
	-- if there's anything remaining, someone's holding on to a ref after recycling!
end

function lib.Debug(onoff)
	if onoff~=nil then
		lib.DEBUG=onoff
	end
	ChatFrame1:AddMessage("LibRecycle: Debugging is " .. (lib.DEBUG and "ON" or "OFF"))
end

function lib.Stats()
	local report={}
	for k,v in pairs(lib.trashcan) do
		report[v] = (report[v] or 0)+1
	end
	
	ChatFrame1:AddMessage("LibRecycle: Current trashcan contents")
	for k,v in pairs(report) do
		if k==true then
			ChatFrame1:AddMessage(
				format("  %5u from untracked source", v))
		else
			ChatFrame1:AddMessage(
				format("  %5u from: %s", v, gsub(k, "[\r\n]+", " -- ")))
		end
	end
end


-----------------------------------------------------------------------
-- local acquire, recycle, clone, scrub = lib.All()

-- make wrappers so that we can actually upgrade older versions!
local function _acquire(...) return lib.Acquire(...) end
local function _recycle(...) return lib.Recycle(...) end
local function _clone(...) return lib.Clone(...) end
local function _scrub(...) return lib.Scrub(...) end

function lib.All()
	return _acquire, _recycle, _clone, _scrub
end


