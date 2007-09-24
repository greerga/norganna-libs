--[[
	ScrollSheet
	Version: <%version%> (<%codename%>)
	Revision: $Id$
	URL: http://auctioneeraddon.com/dl/

	License:
		This library is free software; you can redistribute it and/or
		modify it under the terms of the GNU Lesser General Public
		License as published by the Free Software Foundation; either
		version 2.1 of the License, or (at your option) any later version.

		This library is distributed in the hope that it will be useful,
		but WITHOUT ANY WARRANTY; without even the implied warranty of
		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
		Lesser General Public License for more details.

		You should have received a copy of the GNU Lesser General Public
		License along with this library; if not, write to the Free Software
		Foundation, Inc., 51 Franklin Street, Fifth Floor,
		Boston, MA  02110-1301  USA

	Additional:
		Regardless of any other conditions, you may freely use this code
		within the World of Warcraft game client.
--]]

local LIBRARY_VERSION_MAJOR = "ScrollSheet"
local LIBRARY_VERSION_MINOR = 1

do -- LibStub
	-- LibStub is a simple versioning stub meant for use in Libraries.  http://www.wowace.com/wiki/LibStub for more info
	-- LibStub is hereby placed in the Public Domain
	-- Credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke
	local LIBSTUB_MAJOR, LIBSTUB_MINOR = "LibStub", 2  -- NEVER MAKE THIS AN SVN REVISION! IT NEEDS TO BE USABLE IN ALL REPOS!
	local LibStub = _G[LIBSTUB_MAJOR]

	-- Check to see is this version of the stub is obsolete
	if not LibStub or LibStub.minor < LIBSTUB_MINOR then
		LibStub = LibStub or {libs = {}, minors = {} }
		_G[LIBSTUB_MAJOR] = LibStub
		LibStub.minor = LIBSTUB_MINOR

		-- LibStub:NewLibrary(major, minor)
		-- major (string) - the major version of the library
		-- minor (string or number ) - the minor version of the library
		--
		-- returns nil if a newer or same version of the lib is already present
		-- returns empty library object or old library object if upgrade is needed
		function LibStub:NewLibrary(major, minor)
			assert(type(major) == "string", "Bad argument #2 to `NewLibrary' (string expected)")
			minor = assert(tonumber(strmatch(minor, "%d+")), "Minor version must either be a number or contain a number.")

			local oldminor = self.minors[major]
			if oldminor and oldminor >= minor then return nil end
			self.minors[major], self.libs[major] = minor, self.libs[major] or {}
			return self.libs[major], oldminor
		end

		-- LibStub:GetLibrary(major, [silent])
		-- major (string) - the major version of the library
		-- silent (boolean) - if true, library is optional, silently return nil if its not found
		--
		-- throws an error if the library can not be found (except silent is set)
		-- returns the library object if found
		function LibStub:GetLibrary(major, silent)
			if not self.libs[major] and not silent then
				error(("Cannot find a library instance of %q."):format(tostring(major)), 2)
			end
			return self.libs[major], self.minors[major]
		end

		-- LibStub:IterateLibraries()
		--
		-- Returns an iterator for the currently registered libraries
		function LibStub:IterateLibraries()
			return pairs(self.libs)
		end

		setmetatable(LibStub, { __call = LibStub.GetLibrary })
	end
end -- LibStub

local lib = LibStub:NewLibrary(LIBRARY_VERSION_MAJOR, LIBRARY_VERSION_MINOR)
if not lib then return end

local GSC_GOLD="ffd100"
local GSC_SILVER="e6e6e6"
local GSC_COPPER="c8602c"

local GSC_3 = "|cff%s%d|cff000000.|cff%s%02d|cff000000.|cff%s%02d|r"
local GSC_2 = "|cff%s%d|cff000000.|cff%s%02d|r"
local GSC_1 = "|cff%s%d|r"

local function coins(money)
	money = math.floor(tonumber(money) or 0)
	local g = math.floor(money / 10000)
	local s = math.floor(money % 10000 / 100)
	local c = money % 100

	if (g>0) then
		return (GSC_3):format(GSC_GOLD, g, GSC_SILVER, s, GSC_COPPER, c)
	elseif (s>0) then
		return (GSC_2):format(GSC_SILVER, s, GSC_COPPER, c)
	end
	return (GSC_1):format(GSC_COPPER, c)
end


local kit = {}

function kit:SetData(data)
	self.data = data
	self.panel.vSize = #data
	self.panel:Update()
end

function kit:Render()
	local vPos = math.floor(self.panel.vPos)
	for i = 1, #self.rows do
		local cells = self.rows[i]
		local datarow = self.data[vPos+i]
		if datarow then
			for j=1, #cells do
				if cells[j].layout == "COIN" then
					cells[j]:SetText(coins(datarow[j]))
				else
					cells[j]:SetText(datarow[j])
				end
			end
		else
			for j=1, #cells do
				cells[j]:SetText("")
			end
		end
	end
end

local PanelScroller = LibStub:GetLibrary("PanelScroller")

function lib:Create(frame, layout)
	local name = (frame:GetName() or "").."ScrollSheet"
	local id = 1
	while (getglobal(name..id)) do
		id = id + 1
	end
	name = name..id

	local parentHeight = frame:GetHeight()
	local content = CreateFrame("Frame", name.."Content", frame)
	content:SetHeight(parentHeight - 30)

	local panel = PanelScroller:Create(name.."ScrollPanel", frame)
	panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 5,-5)
	panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -25,25)
	panel:SetScrollChild(name.."Content")
	panel:SetScrollBarVisible("VERTICAL","FAUX")
	panel.vSize = 0

	local totalWidth = 0;

	local labels = {}
	for i = 1, #layout do
		local texture = content:CreateTexture(nil, "ARTWORK")
		texture:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		texture:SetTexCoord(0.1, 0.8, 0, 1)
		if i == 1 then
			texture:SetPoint("TOPLEFT", content, "TOPLEFT", 5,0)
			totalWidth = totalWidth + 5
		else
			texture:SetPoint("TOPLEFT", labels[i-1].texture, "TOPRIGHT", 3,0)
			totalWidth = totalWidth + 3
		end
		local colWidth = layout[i][3]
		totalWidth = totalWidth + colWidth
		texture:SetWidth(colWidth)
		texture:SetHeight(16)

		local background = content:CreateTexture(nil, "ARTWORK")
		background:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		background:SetTexCoord(0.2, 0.9, 0, 0.9)
		background:SetPoint("TOPLEFT", texture, "BOTTOMLEFT", 0,0)
		background:SetPoint("TOPRIGHT", texture, "BOTTOMRIGHT", 0,0)
		background:SetPoint("BOTTOM", content, "BOTTOM", 0,0)
		background:SetAlpha(0.2)

		local label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		label:SetPoint("TOPLEFT", texture, "TOPLEFT", 0,0)
		label:SetPoint("BOTTOMRIGHT", texture, "BOTTOMRIGHT", 0,0)
		label:SetJustifyH("CENTER")
		label:SetJustifyV("TOP")
		label:SetText(layout[i][1])
		label:SetTextColor(0.8,0.8,0.8)

		label.texture = texture
		label.background = background
		labels[i] = label
	end
	totalWidth = totalWidth + 5

	local rows = {}
	local rowNum = 1
	local maxHeight = content:GetHeight()
	local totalHeight = 16
	while (totalHeight + 14 < maxHeight) do
		local row = {}
		for i = 1, #layout do
			local cell = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			if rowNum == 1 then
				cell:SetPoint("TOPLEFT", labels[i], "BOTTOMLEFT", 0,0)
				cell:SetPoint("TOPRIGHT", labels[i], "BOTTOMRIGHT", 0,0)
			else
				cell:SetPoint("TOPLEFT", rows[rowNum-1][i], "BOTTOMLEFT", 0,0)
				cell:SetPoint("TOPRIGHT", rows[rowNum-1][i], "BOTTOMRIGHT", 0,0)
			end
			cell:SetHeight(14)
			cell:SetJustifyV("CENTER")
			if (layout[i][2] == "TEXT") then
				cell:SetJustifyH("LEFT")
			elseif (layout[i][2] == "INT") then
				cell:SetJustifyH("RIGHT")
			elseif (layout[i][2] == "COIN") then
				cell:SetJustifyH("RIGHT")
			end
			cell.layout = layout[i][2]
			cell:SetTextColor(0.9, 0.9, 0.9)
			row[i] = cell
		end
		rows[rowNum] = row
		rowNum = rowNum + 1
		totalHeight = totalHeight + 14
	end

	content:SetWidth(totalWidth)
	panel:UpdateScrollChildRect()
	panel:Update()

	local sheet = {
		name = name,
		content = content,
		panel = panel,
		labels = labels,
		rows = rows,
		data = {},
	}
	for k,v in pairs(kit) do
		sheet[k] = v
	end
	panel.callback = function() sheet:Render() end

	return sheet
end


