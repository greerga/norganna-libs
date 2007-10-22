--[[

	Psychler.lua
       A table recycling embeddable library.
       Released into the Public Domain without warranty. Use at your own peril!
	Credits: Norganna, MentalPower.

]]

local LIBRARY_VERSION_MAJOR = "Psychler"
local LIBRARY_VERSION_MINOR = 1

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

local lib = LibStub:NewLibrary(LIBRARY_VERSION_MAJOR, LIBRARY_VERSION_MINOR)
if not lib then return end

-- Create the recylebin (if it doesn't exist)
if not lib.recyclebin then lib.recyclebin = {} end

-- Store the following variables/functions locally to save on lookups.
local tremove = table.remove
local tinsert = table.insert
local recyclebin = lib.recyclebin
local n, v, tbl, key, item

-- Define a local function so we can do the nested subcalls without lookups.
local function recycle(...)
	-- Get the passed parameter/s
	n = select("#", ...)
	if n <= 0 then
		return
	elseif n == 1 then
		item = ...
	else
		tbl, key = ...
		item = tbl[key]
	end

	-- We can only clean tables
	if type(item) ~= 'table' then return end

	-- Clean out any values from this table
	for k,v in pairs(item) do
		if type(v) == 'table' then
			-- Recycle this table too
			recycle(item, k)
		else
			item[k] = nil
		end
	end

	-- If we are to clean the input value
	if tbl and key then
		-- Place the husk of a table in the recycle bin
		tinsert(recyclebin, item)

		-- Clean out the original table entry too
		tbl[key] = nil
	end
end
lib.Recycle = recycle

function lib.Acquire(...)
	-- Get a recycled table or create a new one.
	if #recyclebin > 0 then
		item = tremove(recyclebin)
	end
	if not item then
		item = {}
	end

	-- And populate it if there's any args
	n = select("#", ...)
	for i = 1, n do
		v = select(i, ...)
		item[i] = v
	end
	return item
end

