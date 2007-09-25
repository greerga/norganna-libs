--[[
	Configator - A library to help you create a gui config
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

--------------------------------------------------------------------------

USAGE:

	Stub   Configator = LibStub:GetLibrary("Configator")
	Call   myCfg = Configator:Create(setterFunc, getterFunc)
	Call   tabId = myCfg:AddTab(TabName)
	Call   myCfg:AddControl(tabId, controlType, leftPct, ...)
	Wait   for callbacks on your getters and setters

	Your setter will be called with (variableName, value) for you to set
	Your getter will be called with (variableName) for your to return the current value

	The AddControl function's ... varies depending on the controlType:
	"Header" == text
	"Subhead" == text
	"Checkbox" == level, setting, label
	"Slider" == level, setting, min, max, step, label, fmtfunc
	"Text" = level, setting, label
	"NumberBox" == level, setting, minVal, maxVal, label
	"MoneyFrame" = level, setting, label
	"MoneyFramePinned" = level, setting, minVal, maxVal, label

	Settings and configuration system.
]]

local LIBRARY_VERSION_MAJOR = "Configator"
local LIBRARY_VERSION_MINOR = 2

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

local kit = {}

if not lib.frames then lib.frames = {} end
if not lib.tmpId then lib.tmpId = 0 end


function lib:CreateAnonName()
	lib.tmpId = lib.tmpId + 1
	return "ConfigatorAnon"..lib.tmpId
end

function lib:Create(setter, getter, w,h)
	local id = #(lib.frames) + 1
	local name = "ConfigatorDialog_"..id

	local gui = CreateFrame("Frame", name, UIParent)
	table.insert(lib.frames, gui)
	gui.Done = CreateFrame("Button", nil, gui, "OptionsButtonTemplate")
	gui.setter = setter
	gui.getter = getter

	local top = getter("configator.top")
	local left = getter("configator.left")
	if (top and left) then
		gui:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT", left, top)
	else
		gui:SetPoint("CENTER", "UIParent", "CENTER")
	end
	gui:Hide()
	gui:SetFrameStrata("DIALOG")
	gui:SetToplevel(true)
	gui:SetMovable(true)
	gui:EnableMouse(true)
	gui:SetWidth(w or 800)
	gui:SetHeight(h or 450)
	gui:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 32, edgeSize = 16,
		insets = { left = 5, right = 5, top = 5, bottom = 5 }
	})
	gui:SetBackdropColor(0, 0, 0, 0.9)
	table.insert(UISpecialFrames, name) -- make frames Esc Sensitive by default

	gui.Drag = CreateFrame("Button", nil, gui)
	gui.Drag:SetPoint("TOPLEFT", gui, "TOPLEFT", 10,-5)
	gui.Drag:SetPoint("TOPRIGHT", gui, "TOPRIGHT", -10,-5)
	gui.Drag:SetHeight(6)
	gui.Drag:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")

	gui.Drag:SetScript("OnMouseDown", function() gui:StartMoving() end)
	gui.Drag:SetScript("OnMouseUp", function() gui:StopMovingOrSizing() setter("configator.left", gui:GetLeft()) setter("configator.top", gui:GetTop()) end)

	gui.Done:SetPoint("BOTTOMRIGHT", gui, "BOTTOMRIGHT", -10, 10)
	gui.Done:SetScript("OnClick", function() gui:Hide() end)
	gui.Done:SetText(DONE)

	gui.tabs = {
		pos = 0,
		count = 0,
	}
	gui.elements = {}

	for k,v in pairs(kit) do
		gui[k] = v
	end

	return gui
end

-- Create a special tooltip just for us
if not lib.tooltip then
	lib.tooltip = CreateFrame("GameTooltip", "ConfigatorTipTooltip", UIParent, "GameTooltipTemplate")
	local function hide_tip()
		lib.tooltip:Hide()
	end
	lib.tooltip.fadeInfo = {}
	function lib:SetTip(frame, ...)
		local n = select("#", ...)
		if n == 1 then
			-- Allow passing of tip lines as a single table
			local tip = select(1, ...)
			if type(tip) == "table" then
				lib:SetTip(frame, unpack(tip))
				return
			end
		end

		if not frame or n == 0 then
			lib.tooltip.fadeInfo.finishedFunc = hide_tip
			local curAlpha = lib.tooltip:GetAlpha()
			UIFrameFadeOut(lib.tooltip, 0.25, curAlpha, 0)
			lib.tooltip:SetAlpha(curAlpha)
			lib.tooltip.schedule = nil
			return
		end

		if lib.tooltip:GetAlpha() > 0 then
			-- Speed up this fade
			UIFrameFadeOut(lib.tooltip, 0.01, 0, 0)
			lib.tooltip:SetAlpha(0)
		end

		lib.tooltip:SetOwner(frame, "ANCHOR_NONE")
		lib.tooltip:ClearLines()

		local tip
		for i=1, n do
			tip = select(i, ...)
			lib.tooltip:AddLine(tostring(tip) or "", 1,1,0.5, 1)
		end
		lib.tooltip:Show()
		lib.tooltip:SetAlpha(0)
		lib.tooltip:SetBackdropColor(0,0,0, 1)
		lib.tooltip:SetPoint("TOP", frame, "BOTTOM", 10, -5)
		lib.tooltip.schedule = GetTime() + 1
	end
	lib.tooltip:SetScript("OnUpdate", function()
		if lib.tooltip.schedule and GetTime() > lib.tooltip.schedule then
			local curAlpha = lib.tooltip:GetAlpha()
			UIFrameFadeIn(lib.tooltip, 0.33, curAlpha, 1)
			lib.tooltip:SetAlpha(curAlpha) -- Tooltips set alpha when they are shown, and UIFrameFadeIn does a :Show()
			lib.tooltip.schedule = nil
		end
	end)
	lib.tooltip:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Glues/Common/Glue-Tooltip-Border",
		tile = false, tileSize = 32, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	lib.tooltip:SetBackdropColor(0,0,0.3, 1)
	lib.tooltip:SetClampedToScreen(true)
end

-- Create our help window
if not lib.help then
	lib.help = CreateFrame("Frame", "ConfigatorHelpFrame", UIParent)
	lib.help:SetBackdrop({
		bgFile = "Interface/Stationery/StationeryTest1",
		edgeFile = "Interface/TUTORIALFRAME/TUTORIALFRAMEBORDER",
		tile = false, tileSize = 32, edgeSize = 32,
		insets = { left = 4, right = 4, top = 22, bottom = 4 }
	})
	lib.help:SetBackdropColor(0.15,0.15,0.15, 0.98)
	lib.help:SetToplevel(true)
	lib.help:SetPoint("CENTER")
	lib.help:SetWidth(450)
	lib.help:SetHeight(500)
	lib.help:SetMovable(true)
	lib.help:EnableMouse(true)
	lib.help:SetScript("OnUpdate", function() if lib.help.refresh then lib.help.Update() end end)
	lib.help:SetScript("OnEvent", function() if lib.help:IsVisible() then lib.help.Update() end end)
	lib.help:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
	lib.help:Hide()

	lib.help.title = CreateFrame("Button", nil, lib.help)
	lib.help.title:SetScript("OnMouseDown", function() lib.help:StartMoving() end)
	lib.help.title:SetScript("OnMouseUp", function() lib.help:StopMovingOrSizing() end)
	lib.help.title:SetPoint("TOPLEFT", lib.help, "TOPLEFT", 3,-3)
	lib.help.title:SetPoint("BOTTOMRIGHT", lib.help, "TOPRIGHT", -28,-20)
	lib.help.title:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
	lib.help.title:SetTextFontObject("GameFontNormal")
	lib.help.title:SetText("Help Window")

	lib.help.close = CreateFrame("Button", nil, lib.help, "UIPanelCloseButton")
	lib.help.close:SetPoint("TOPRIGHT", lib.help, "TOPRIGHT", 3, 5)
	lib.help.close:SetHeight(32)
	lib.help.close:SetWidth(32)
	lib.help.close:SetScript("OnClick", function () lib.help:Hide() end)

	lib.help.content = CreateFrame("Frame", "ConfigatorHelpContent", lib.help)
	lib.help.content:SetWidth(420)
	lib.help.content:SetHeight(100)
	lib.help.content.totalHeight = 0

	lib.help.rows = {}
	lib.help.fontcache = {}
	function lib.help:AddHelp(question, answer)
		lib.help:AddRow(question, 14, 1,0.9,0, 8)
		lib.help:AddRow(answer, 12, 1,1,1)
	end
	function lib.help:AddRow(text, size, r,g,b, pad)
		if not size then size = 12 end
		if not (r and g and b) then r,g,b = 1,1,1 end
		if not pad then pad = 0 end

		local font
		local remain = #lib.help.fontcache
		if remain > 0 then
			font = lib.help.fontcache[remain]
			table.remove(lib.help.fontcache)
		else
			font = lib.help.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		end
		local file = font:GetFont()

		font:SetFont(file, size)
		font:SetTextColor(r,g,b,1)
		font:SetText(text)
		font.pad = pad

		table.insert(lib.help.rows, font)

		font:SetPoint("TOPLEFT", lib.help.content, "TOPLEFT", 5, -5)
		font:SetPoint("TOPRIGHT", lib.help.content, "TOPRIGHT", -5, -5)
		font:SetWidth(lib.help.content:GetWidth()-10)

		font:SetJustifyV("TOP")
		font:SetJustifyH("LEFT")

		font:Show()

		lib.help.refresh = true
		return n, font, height
	end
	function lib.help:ClearAllLines()
		lib.help.content.totalHeight = 0
		for i=#lib.help.rows, 1, -1 do
			lib.help.rows[i]:Hide()
			lib.help.rows[i]:ClearAllPoints()
			table.insert(lib.help.fontcache, lib.help.rows[i])
			table.remove(lib.help.rows, i)
		end
		lib.help.refresh = true
	end
	function lib.help:Update()
		local height, top = 0, 0

		for i = 1, #lib.help.rows do
			local font = lib.help.rows[i]
			if i == 1 then
				top = -5
				height = height + 5
			else
				top = -height - 2
				height = height + 2
			end

			top = top - font.pad
			height = height + font.pad

			font:SetPoint("TOPLEFT", lib.help.content, "TOPLEFT", 5, top)
			font:SetPoint("TOPRIGHT", lib.help.content, "TOPRIGHT", -5, top)
			font:SetWidth(lib.help.content:GetWidth()-10)

			height = height + font:GetHeight()
		end
		lib.help.content:SetHeight(height+10)
		lib.help.scroll:Update()
		lib.help.refresh = nil
	end

	function lib.help:Activate()
		local qlist = self.qlist
		local faq = self.faq
		local faa = self.faa
		local qid

		lib.help:ClearAllLines()
		for i = 1, #qlist do
			qid = qlist[i]
			lib.help:AddHelp(faq[qid], faa[qid])
		end
		lib.help:SetFrameStrata(self:GetFrameStrata())
		lib.help.refresh = true
		lib.help:Show()
	end

	local PanelScroller = LibStub:GetLibrary("PanelScroller")
	lib.help.scroll = PanelScroller:Create(lib.CreateAnonName(), lib.help)
	lib.help.scroll:SetPoint("TOPLEFT", lib.help, "TOPLEFT", 10,-25)
	lib.help.scroll:SetPoint("BOTTOMRIGHT", lib.help, "BOTTOMRIGHT", -25,5)
	lib.help.scroll:SetScrollChild(lib.help.content:GetName())
	lib.help.scroll:SetScrollBarVisible("HORIZONTAL", "NO")
end

nConf = lib


-- Local function to get the UI object type
local function isGuiObject(obj)
	if not obj then return false end
	if type(obj) ~= "table" then return false end
	if not obj[0] or type(obj[0]) ~= "userdata" then return false end
	if not obj.GetObjectType then return false end
	return obj:GetObjectType()
end


function kit:ZeroFrame()
	assert(isGuiObject(self), "Must be called on a valid object")
	local id = 0
	local frame
	frame = CreateFrame("Frame", nil, self)
	frame.id = id
	frame:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -10)
	frame:SetPoint("BOTTOMRIGHT", self.Done, "TOPRIGHT", 0, 5)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 32, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	frame:SetBackdropColor(0,0,0, 0.5)
	frame.contentWidth = 740
	self.tabs[id] = {}
	self.tabs[id][2] = frame
	return id
end

function kit:AddTab(tabName)
	assert(isGuiObject(self), "Must be called on a valid object")
	local button, frame, content, id

	local myName = lib.CreateAnonName()
	button = CreateFrame("Button", myName, self, "OptionsButtonTemplate")
	frame = CreateFrame("Frame", myName.."Frame", self)
	content = CreateFrame("Frame", myName.."Content", frame)

	table.insert(self.tabs, { button, frame, content })
	id = table.getn(self.tabs)
	button.id = id
	frame.id = id
	self.tabs.count = id
	self.tabs.pos = id
	if (not self.tabs.active) then
		self.tabs.active = id
	else
		frame:Hide()
	end
	if (id == 1) then
		button:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -10)
	else
		button:SetPoint("TOPLEFT", self.tabs[id-1][1], "BOTTOMLEFT", 0, 0)
	end
	button:SetWidth(120)
	button:SetScript("OnClick", kit.ActivateTab)
	frame:SetPoint("TOPLEFT", self.tabs[1][1], "TOPRIGHT", 0, 0)
	frame:SetPoint("BOTTOMRIGHT", self.Done, "TOPRIGHT", 0, 5)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/ChatBubble-Background",
		edgeFile = "Interface/Tooltips/ChatBubble-BackDrop",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 32, right = 32, top = 32, bottom = 32 }
	})
	frame:SetBackdropColor(0,0,0, 1)
	content:SetPoint("TOPLEFT", frame, "TOPLEFT", 5,-5)
	content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5,5)
	button:SetText(tabName)
	frame.contentWidth = 620
	return id
end

function kit:AddCat(catName)
	assert(isGuiObject(self), "Must be called on a valid object")
	local button, frame, id
	button = CreateFrame("Button", nil, self)
	frame = {}
	table.insert(self.tabs, { button, frame })
	id = table.getn(self.tabs)
	self.tabs.count = id
	self.tabs.pos = id
	button.id = id
	frame.id = id
	if (id == 1) then
		button:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -10)
	else
		button:SetPoint("TOPLEFT", self.tabs[id-1][1], "BOTTOMLEFT", 0, 0)
	end
	button:Disable()
	button:SetWidth(120)
	button:SetHeight(22)
	button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	button.Text:SetJustifyH("LEFT")
	button.Text:SetJustifyV("BOTTOM")
	button.Text:SetPoint("TOPLEFT", button, "TOPLEFT", 5,0)
	button.Text:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
	button.Text:SetText(catName)
	frame.contentWidth = 0
	return id
end

local function anchorPoint(frame, el, last, indent, width, height, yofs)
	local clearance = 0
	if (last and last.clearance) then clearance = last.clearance end

	el:SetPoint("LEFT", frame, "LEFT", indent or 15, 0)
	if (width == nil) then
		el:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
	elseif (type(width) == "number") then
		el:SetWidth(width)
	end
	if (type(height) == "number") then
		el:SetHeight(height)
	end
	if (last) then
		el:SetPoint("TOP", last, "BOTTOM", 0, -5 + (yofs or 0) - clearance)
	else
		el:SetPoint("TOP", frame, "TOP", 0, -5 - clearance)
	end
end

function kit:Unfocus()
	assert(isGuiObject(self), "Must be called on a valid object")
	self:Hide()
	self:ClearFocus()
	self:Show()
end

function kit:SetControlWidth(width)
	assert(isGuiObject(self), "Must be called on a valid object")
	self.scalewidth = width
end

function kit:MakeScrollable(id)
	assert(isGuiObject(self), "Must be called on a valid object")
	if (self.tabs[id][4]) then return end
	local frame = self.tabs[id][2]
	local content = self.tabs[id][3]
	local oldwidth = content:GetWidth()
	content:ClearAllPoints()
	content:SetWidth(oldwidth)
	content:SetHeight(250)
	local PanelScroller = LibStub:GetLibrary("PanelScroller")
	local scroll = PanelScroller:Create(lib.CreateAnonName(), frame)
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 5,-7)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -25,9)
	scroll:SetScrollChild(content:GetName())
	scroll:UpdateScrollChildRect()
	self.tabs[id][4] = scroll
	GSC = scroll
end

function kit:AddTip(id, tip)
	assert(isGuiObject(self), "Must be called on a valid object")
	local control
	local idType = type(id)
	if idType == "number" and self.tabs then
		control = self:GetLast(id)
	elseif idType == "string" then
		control = _G[id]
	elseif idType == "table" and type(id[0]) == "userdata" then
		control = id
	end
	assert(isGuiObject(control), "Usage: ConfigatorGui:AddTip(tabId|controlName|control, tip)")
	if control.button and isGuiObject(control.button) then
		control = control.button
	elseif control.control and isGuiObject(control.control) then
		control = control.control
	end

	local old_enter = control:GetScript("OnEnter")
	local old_leave = control:GetScript("OnLeave")
	local function help_enter(self, ...)
		if old_enter then old_enter(self, ...) end
		if tip then lib:SetTip(self, tip) end
	end
	local function help_leave(self, ...)
		if old_enter then old_leave(self, ...) end
		if tip then lib:SetTip() end
	end
	control:SetScript("OnEnter", help_enter)
	control:SetScript("OnLeave", help_leave)
end

function kit:AddHelp(id, qid, question, answer)
	assert(isGuiObject(self), "Must be called on a valid object")
	local content
	local idType = type(id)
	if idType == "number" and self.tabs then
		content = self.tabs[id][2]
	elseif idType == "string" then
		content = _G[id]
	elseif idType == "table" and type(id[0]) == "userdata" then
		content = id
	end
	assert(isGuiObject(content), "Usage: ConfigatorGui:AddHelp(tabId|controlName|control, question, answer)")
	assert(question and answer, "Usage: ConfigatorGui:AddHelp(tabId|controlName|control, question, answer)")

	if question and answer then
		if content and not content.HelpButton then
			content.HelpButton = CreateFrame("BUTTON", content:GetName().."HelpButton", content)
			content.HelpButton:SetPoint("TOPRIGHT", content, "TOPRIGHT", -20,0)
			content.HelpButton:SetWidth(42)
			content.HelpButton:SetHeight(42)
			content.HelpButton:SetNormalTexture("Interface\\TUTORIALFRAME\\TutorialFrame-QuestionMark")
			content.HelpButton:SetHighlightTexture("Interface\\TUTORIALFRAME\\TutorialFrame-QuestionMark")
			content.HelpButton:SetScript("OnClick", lib.help.Activate)
			content.HelpButton.text = content.HelpButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			content.HelpButton.text:SetText("Help")
			content.HelpButton.text:SetPoint("TOP", content.HelpButton, "BOTTOM", 0,5)
			content.HelpButton.qlist = {}
			content.HelpButton.faq = {}
			content.HelpButton.faa = {}
		end
		content.HelpButton.faq[qid] = question
		content.HelpButton.faa[qid] = answer

		for i = 1, #content.HelpButton.qlist do
			if content.HelpButton.qlist[i] == qid then
				return
			end
		end
		table.insert(content.HelpButton.qlist, qid)
	end
end

function kit:AddControl(id, cType, column, ...)
	assert(isGuiObject(self), "Must be called on a valid object")
	local frame = self.tabs[id][2]
	if (frame.contentWidth == 0) then
		error("Attempting to add a control to a non-existent frame")
	end
	if (not frame.ctrls) then
		frame.ctrls = { pos = 0 }
	end
	local cpos = frame.ctrls.pos + 1
	frame.ctrls.pos = cpos
	local ctrl = { kids = {} }
	frame.ctrls[cpos] = ctrl

	local last = frame.ctrls.last
	local control

	local kids = ctrl.kids
	local kpos = 0

	local framewidth = frame:GetWidth() - 20
	column = (column or 0) * framewidth
	local colwidth = nil
	if (self.scalewidth) then
		colwidth = math.min(framewidth-column, (self.scalewidth or 1) * framewidth)
	end

	local content = self.tabs[id][3]

	local el
	if (cType == "Header") then
		el = content:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last)
		local text = ...
		el:SetText(text)
		last = el
	elseif (cType == "Subhead") then
		el = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		el:SetJustifyH("LEFT")
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last, column+15, colwidth, nil, -10)
		local text = ...
		el:SetText(text)
		last = el
	elseif (cType == "Note") then
		local level, width, height, text = ...
		local indent = 10 * (level or 1)
		el = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		el:SetJustifyH("LEFT")
		el:SetJustifyV("TOP")
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last, column+indent+15, width, height, nil)
		el:SetText(text)
		control = el
		last = el
	elseif (cType == "Label") then
		local level, setting, text = ...
		local indent = 10 * (level or 1)
		el = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		el:SetJustifyH("LEFT")
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last, column+indent+15, colwidth)
		el:SetText(text)
		if (setting) then
			el.hit = CreateFrame("Button", nil, content)
			el.hit.parent = el
			el.hit:SetAlpha(0.3)
			el.hit:SetPoint("TOPLEFT", el, "TOPLEFT", -2, 2)
			el.hit:SetPoint("BOTTOMRIGHT", el, "BOTTOMRIGHT", 2, -2)
			--el.hit:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			el.hit:SetHighlightTexture("Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar")
			el.hit.setting = setting
			el.hit.stype = "Button";
			el.hit:SetScript("OnClick", function(...) self:ChangeSetting(...) end)
			el.hit:Show()
		end
		control = el
		last = el
	elseif (cType == "Custom") then
		local level, el = ...
		local indent = 10 * (level or 1)
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last, column + indent + 15, colwidth)
		control = el
		last = el
	elseif (cType == "Text") then
		local level, setting, label = ...
		local indent = 10 * (level or 1)
		-- FontString
		el = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		el:SetJustifyH("LEFT")
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last, 10 + column + indent)
		el:SetText(label)
		last = el
		-- Editbox
		el = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last, 20 + column + indent, colwidth or 160, 32, 4)
		el.setting = setting
		el.stype = "EditBox"
		el:SetAutoFocus(false)
		self:GetSetting(el)
		el:SetScript("OnEditFocusLost", function(...) self:ChangeSetting(...) end)
		el:SetScript("OnEscapePressed", kit.Unfocus)
		el:SetScript("OnEnterPressed", kit.Unfocus)
		self.elements[setting] = el
		el.textEl = last

		control = el
		last = el
	elseif (cType == "Selectbox") then
		local level, list, setting, text = ...
		local indent = 10 * (level or 1)
		-- Selectbox
		local tmpName = lib.CreateAnonName()

		if (type(list) ~= "function") then
			local listVar = list
			if (type(list) == "table") then
				list = function() return listVar end
			else
				list = function() return self.getter(listVar) end
			end
		end

		local SelectBox = LibStub:GetLibrary("SelectBox")
		el = SelectBox:Create(tmpName, content, 140, function(...) self:ChangeSetting(...) end, list, "Default")
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last, column+indent - 5, colwidth or 140, 22, 4)
		el.list = list
		el.setting = setting
		el.stype = "SelectBox";
		el.clearance = 10
		self.elements[setting] = el
		self:GetSetting(el)
		control = el
		last = el

	elseif (cType == "Button") then
		local level, setting, text = ...
		local indent = 10 * (level or 1)
		-- Button
		el = CreateFrame("Button", nil, content, "OptionsButtonTemplate")
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last, 10 + column + indent, colwidth or 80, 22, 4)
		el.setting = setting
		el.stype = "Button";
		el:SetScript("OnClick", function(...) self:ChangeSetting(...) end)
		el:SetText(text)
		el:SetWidth(math.max(el:GetWidth(), el:GetFontString():GetStringWidth() + 16))
		control = el
		last = el
	elseif (cType == "Checkbox") then
		local level, setting, text, singleLine, maxLabelLength = ...
		if ( maxLabelLength and maxLabelLength <= 1 ) then
			maxLabelLength = maxLabelLength * framewidth - 25
		end
		local indent = 10 * (level or 1)
		-- CheckButton
		el = CreateFrame("CheckButton", nil, content, "OptionsCheckButtonTemplate")
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last, 10 + column + indent, 22, 22, 4)
		el.setting = setting
		el.stype = "CheckButton"
		self:GetSetting(el)
		el:SetScript("OnClick", function(...) self:ChangeSetting(...) end)
		self.elements[setting] = el
		control = el
		-- FontString
		el = control:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		el:SetJustifyH("LEFT")
		kpos = kpos+1 kids[kpos] = el
		if (colwidth) then colwidth = colwidth - 15 end
		anchorPoint(content, el, last, 35+column+indent, (colwidth or maxLabelLength), (singleLine and 14))
		el:SetText(text)
		local textWidth = el:GetStringWidth()+25
		control:SetHitRectInsets(-2,-textWidth, -2,-2)
		control.textEl = el
		last = el
	elseif (cType == "Slider" or cType == "WideSlider") then
		local swidth = 140
		if (cType == "WideSlider") then swidth = 260 end
		local level, setting, min, max, step, text, fmtfunc = ...
		local indent = 10 * (level or 1)
		-- FontString
		el = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		el:SetJustifyH("LEFT")
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last, swidth + 20 + column+indent)
		el:SetText(text)
		local textElement = el
		-- Slider
		local tmpName = lib.CreateAnonName()
		el = CreateFrame("Slider", tmpName, content, "OptionsSliderTemplate")
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last, 13 + column + indent, swidth, 20, 4)
		getglobal(tmpName.."Low"):SetText("")
		getglobal(tmpName.."High"):SetText("")
		el.setting = setting
		el.textFmt = text
		el.fmtFunc = fmtfunc
		el.textEl = textElement
		el.stype = "Slider";
		el:SetMinMaxValues(min, max)
		el:SetValueStep(step)
		self:GetSetting(el)
		el:SetHitRectInsets(0,0,0,0)
		el:SetScript("OnValueChanged", function(...) self:ChangeSetting(...) end)
		self.elements[setting] = el
		control = el
		last = textElement
	elseif (cType == "NumberBox") then
		local level, setting, minVal, maxVal, label = ...
		local indent = 10 * (level or 1)
		-- FontString
		el = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		el:SetJustifyH("LEFT")
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last, 10+column+indent)
		el:SetText(label)
		last = el
		-- Editbox
		el = CreateFrame("EditBox", "", content, "InputBoxTemplate")
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last, 20+column+indent, colwidth or 160, 32, 4)
		el.setting = setting
		el.stype = "EditBox"
		el:SetAutoFocus(false)
		el:SetNumeric(true);
		el.minValue = minVal;
		el.maxValue = maxVal;
		el.Numeric = true;
		self:GetSetting(el)
		el:SetScript("OnEditFocusLost", function(...) self:ChangeSetting(...) end)
		el:SetScript("OnEscapePressed", kit.Unfocus)
		el:SetScript("OnEnterPressed", kit.Unfocus)
		self.elements[setting] = el
		el.textEl = last
		control = el
		last = el
	elseif (cType == "MoneyFrame" or cType == "MoneyFramePinned") then
		local level, setting, minVal, maxVal, label  = ...
		if (cType == "MoneyFrame") then
			label, minVal, maxVal = minVal, nil, nil
		end
		local indent = 10 * (level or 1)
		-- FontString
		if label then
			el = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			el:SetJustifyH("LEFT")
			kpos = kpos+1 kids[kpos] = el
			anchorPoint(content, el, last, 10+column+indent)
			el:SetText(label)
			last = el
		end
		-- MoneyFrame
		frameName = lib.CreateAnonName();
		el = CreateFrame("Frame", frameName, content, "MoneyInputFrameTemplate")
		local cur = el
		MoneyInputFrame_SetOnvalueChangedFunc(el, function() self:ChangeSetting(cur) end);
		kpos = kpos+1 kids[kpos] = el
		anchorPoint(content, el, last, 20+column+indent, colwidth or 160, 32, 4)
		el.frameName = frameName;
		el.setting = setting;
		el.stype = cType
		el.clearance = -10
		el.minValue = minVal;
		el.maxValue = maxVal;
		self:GetSetting(el)
		self.elements[setting] = el
		el.textEl = last
		control = el
		last = el
	end

	if last ~= control then
		last.control = control
	end

	self:SetLast(id, last)
	return control
end

function kit:GetLast(id)
	assert(isGuiObject(self), "Must be called on a valid object")
	if (self.tabs[id] and self.tabs[id][2].ctrls) then
		return self.tabs[id][2].ctrls.last
	end
end

function kit:SetLast(id, last)
	assert(isGuiObject(self), "Must be called on a valid object")
	if (self.tabs[id] and self.tabs[id][2].ctrls) then
		self.tabs[id][2].ctrls.last = last
	end
end

function kit:ActivateTab(id)
	assert(isGuiObject(self), "Must be called on a valid object")
	id = tonumber(id)
	if not id then id = self.id end

	if not self.tabs then self = self:GetParent() end
	if not self.tabs then
		return error("Must call ActivateTab from a valid Configator object")
	end

	if (self.tabs.active) then
		self.tabs[self.tabs.active][2]:Hide()
	end
	self.tabs.active = id
	self.tabs[id][2]:Show()
end

function kit:Refresh()
	assert(isGuiObject(self), "Must be called on a valid object")
	for name, el in pairs(self.elements) do
		self:GetSetting(el)
	end
end

function kit:Resave()
	assert(isGuiObject(self), "Must be called on a valid object")
	for name, el in pairs(self.elements) do
		self:ChangeSetting(el)
	end
end

function kit:GetSetting(element)
	assert(isGuiObject(self), "Must be called on a valid object")
	assert(isGuiObject(element), "You must pass a valid element")
	local setting = element.setting
	local value = self.getter(setting)
	if (element.stype == "CheckButton") then
		element:SetChecked(value or false)
	elseif (element.stype == "EditBox") then
		if (element.Numeric) then
			oldvalue = value or 0;
			value = oldvalue;
			if (element.minValue) then
				value = math.max( value, element.minValue );
			end
			if (element.maxValue) then
				value = math.min( value, element.maxValue );
			end
			element:SetNumber(value);
			-- notify that we have pinned the value
			if (value ~= oldvalue) then
				self.setter(setting, value);
			end
		else
			element:SetText(value or "")
		end
	elseif (element.stype == "SelectBox") then
		element.value = value
		element:UpdateValue()
	elseif (element.stype == "Button") then
	elseif (element.stype == "Slider") then
		value = value or 0
		element:SetValue(value)
		if (element.fmtFunc) then
			element.textEl:SetText(string.format(element.textFmt, element.fmtFunc(value)))
		else
			element.textEl:SetText(string.format(element.textFmt, value))
		end
	elseif (element.stype == "MoneyFrame") then
		MoneyInputFrame_ResetMoney(element)
		MoneyInputFrame_SetCopper(element, tonumber(value) or 0);
	elseif (element.stype == "MoneyFramePinned") then
		oldvalue = tonumber(value) or 0;
		value = oldvalue;
		if (element.minValue) then
			value = math.max( value, element.minValue );
		end
		if (element.maxValue) then
			value = math.min( value, element.maxValue );
		end
		MoneyInputFrame_ResetMoney(element)
		MoneyInputFrame_SetCopper( element, value );
		-- update with pinned value
		if (oldvalue ~= value) then
			self.setter(setting, value);
		end
	else
		value = element:GetValue()
	end
end

function kit:ChangeSetting(element, ...)
	assert(isGuiObject(self), "Must be called on a valid object")
	assert(isGuiObject(element), "You must pass a valid element")
	assert(element.stype, "You must pass a valid Configator settings object")
	local setting = element.setting
	local value
	if (element.stype == "CheckButton") then
		value = element:GetChecked()
		if (value) then value = true else value = false end
	elseif (element.stype == "EditBox") then
		if (element.Numeric) then
			oldvalue = element:GetNumber() or 0;
			value = oldvalue;
			if (element.minValue) then
				value = math.max( value, element.minValue );
			end
			if (element.maxValue) then
				value = math.min( value, element.maxValue );
			end
			-- update the text field with pinned value
			if (oldvalue ~= value) then
				element:SetNumber(value);
			end
		else
			value = element:GetText() or ""
		end
	elseif (element.stype == "SelectBox") then
		value = select(2, ...)
	elseif (element.stype == "Button") then
		value = true
	elseif (element.stype == "Slider") then
		value = element:GetValue() or 0
		if (element.fmtFunc) then
			element.textEl:SetText(string.format(element.textFmt, element.fmtFunc(value)))
		else
			element.textEl:SetText(string.format(element.textFmt, value))
		end
	elseif (element.stype == "MoneyFrame") then
		value = MoneyInputFrame_GetCopper( element );
	elseif (element.stype == "MoneyFramePinned") then
		oldvalue = MoneyInputFrame_GetCopper( element );
		value = oldvalue;
		if (element.minValue) then
			value = math.max( value, element.minValue );
		end
		if (element.maxValue) then
			value = math.min( value, element.maxValue );
		end
		-- update with pinned value
		if (oldvalue ~= value) then
			MoneyInputFrame_SetCopper( element, value );
		end
	elseif element.GetValue then
		value = element:GetValue()
	else
		return
	end
	self.setter(setting, value)
end

function kit:ColumnCheckboxes(id, cols, options)
	assert(isGuiObject(self), "Must be called on a valid object")
	local last, cont, el, setting, text
	last = self:GetLast(id)
	local optc = table.getn(options)
	local rows = math.ceil(optc / cols)
	local row, col = 0, 0
	cont = nil
	for pos, option in ipairs(options) do
		setting, text = unpack(option)
		col = math.floor(row / rows)
		el = self:AddControl(id, "Checkbox", col/cols, 1, setting, text, true, 1/cols)
		row = row + 1
		if (row % rows == 0) then
			if (col == 0) then
				cont = el
			end
			self:SetLast(id, last)
		end
	end
	self:SetLast(id, cont)
end

function kit:SetEscSensitive(setting)
	assert(isGuiObject(self), "Must be called on a valid object")
	local name = self:GetName()
	for i = #UISpecialFrames, 1, -1 do
		if (name == UISpecialFrames[i]) then
			table.remove(UISpecialFrames, i)
		end
	end
	if (setting) then
		table.insert(UISpecialFrames[i], name)
	end
end


