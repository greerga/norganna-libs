local MAJOR,MINOR = "LibTooltip-Beta1", 1
local LIBSTRING = MAJOR.."-"..MINOR -- a string unique to this version to prevent frame name conflicts between revisions
local lib = LibStub:NewLibrary(MAJOR,MINOR)
if not lib then return end

-- housekeeping upgrade stuff...
if lib.Deactivate then lib:Deactivate() end -- calls the OLD version of this function.  NOT the one defined in this file's scope

-- Forward definition of a few locals that get defined at the bottom of the file
local tooltipMethods
local EnhTTClass

local function OnTooltipSetItem(tooltip)
	local self = lib
	local reg = self.tooltipRegistry[tooltip]

	if self.sortedCallbacks and #self.sortedCallbacks > 0 then
		tooltip:Show()
		local _,item = tooltip:GetItem()
		if item then
			local name,link,quality,ilvl,minlvl,itype,isubtype,stack,equiploc,texture = GetItemInfo(item)
			if name then
				local enhTT = self:GetFreeEnhTTObject()
				reg.enhTT = enhTT
				enhTT:Attach(tooltip)
				enhTT:AddLine(ITEM_QUALITY_COLORS[quality].hex .. name)

				local quantity = reg.quantity
				for i,callback in ipairs(self.sortedCallbacks) do
					callback(tooltip,item,quantity,name,link,quality,ilvl,minlvl,itype,isubtype,stack,equiploc,texture)
				end
				tooltip:Show()
				if reg.enhTTUsed then reg.enhTT:Show() end
			end
		end
	end
end

local function OnTooltipCleared(tooltip)
	local self = lib
	local reg = self.tooltipRegistry[tooltip]
	if reg.enhTT then
		table.insert(self.enhTTpool,reg.enhTT)
		reg.enhTT:Hide()
		reg.enhTT:Release()
		reg.enhTT = nil
	end
	reg.enhTTUsed = nil
	reg.minWidth = 0
	reg.quantity = nil
end

local function OnSizeChanged(tooltip,w,h)
	local self = lib
	local reg = self.tooltipRegistry[tooltip]
	local enhTT = reg.enhTT
	if enhTT then
		enhTT:NeedsRefresh(true)
	end
end

function lib:GetFreeEnhTTObject()
	if not self.enhTTpool then self.enhTTpool = {} end
	return table.remove(self.enhTTpool) or EnhTTClass:new()
end

local hooks = {}

local function hook(tip,method,hook)
	local orig = tip[method]
	hooks[tip] = hooks[tip] or {origs = {}, hooks = {}}
	hooks[tip].origs[method] = orig
	local h = function(...)
		if hooks[tip].hooks[method] then
			hook(...)
		end
		return orig(...)
	end
	hooks[tip].hooks[method] = h
	tip[method] = h
end

local function unhook(tip,method)
	if tip[method] == hooks[tip].hooks[method] then -- We still own the top of the hook stack, just pop off
		tip[method] = hooks[tip].origs[method]
	else -- We don't own the top so deactivate our hook
		hooks[tip].hooks[method] = nil
	end
end

local function hookscript(tip,script,hook)
	local orig = tip:GetScript(script)
	hooks[tip] = hooks[tip] or {origs = {}, hooks = {}}
	hooks[tip].origs[script] = orig
	local h = function(...)
		if hooks[tip].hooks[script] then
			hook(...)
		end
		if orig then orig(...) end
	end
	hooks[tip].hooks[script] = h
	tip:SetScript(script,h)
end

local function unhookscript(tip,script)
	if tip:GetScript(script) == hooks[tip].hooks[script] then
		tip:SetScript(script,hooks[tip].origs[script])
	else
		hooks[tip].hooks[script] = nil
	end
end

function lib:RegisterTooltip(tooltip)
	if not tooltip or type(tooltip) ~= "table" or type(tooltip.GetObjectType) ~= "function" or tooltip:GetObjectType() ~= "GameTooltip" then return end

	if not self.tooltipRegistry then
		self.tooltipRegistry = {}
		self:GenerateTooltipMethodTable()
	end

	if not self.tooltipRegistry[tooltip] then
		local reg = {}
		self.tooltipRegistry[tooltip] = reg

		hookscript(tooltip,"OnTooltipSetItem",OnTooltipSetItem)
		hookscript(tooltip,"OnTooltipCleared",OnTooltipCleared)
		hookscript(tooltip,"OnSizeChanged",OnSizeChanged)

		for k,v in pairs(tooltipMethods) do
			hook(tooltip,k,v)
		end
		return true
	end
end

local sortFunc
function lib:AddCallback(callback,priority) -- Lower priority gets called before higher priority.  Default is 200.
	if not callback or type(callback) ~= "function" then return end

	if not self.callbacks then
		self.callbacks = {}
		self.sortedCallbacks = {}
		local callbacks = self.callbacks
		sortFunc = function(a,b)
			return callbacks[a] < callbacks[b]
		end
	end

	self.callbacks[callback] = priority or 200
	table.insert(self.sortedCallbacks,callback)
	table.sort(self.sortedCallbacks,sortFunc)
end

function lib:RemoveCallback(callback)
	if not (self.callbacks and self.callbacks[callback]) then return end
	self.callbacks[callback] = nil
	for i,c in ipairs(self.sortedCallbacks) do
		if c == callback then
			table.remove(self.sortedCallbacks,i)
			break
		end
	end
end

function lib:SetEmbedMode(flag)
	self.embedMode = flag and true or false
end

function lib:AddLine(tooltip,text,r,g,b,embed)
	if r and not g then embed = r r = nil end
	embed = embed ~= nil and embed or self.embedMode
	if not embed then
		self.tooltipRegistry[tooltip].enhTT:AddLine(text,r,g,b)
		self.tooltipRegistry[tooltip].enhTTUsed = true
	else
		tooltip:AddLine(text,r,g,b)
	end
end

function lib:AddDoubleLine(tooltip,textLeft,textRight,lr,lg,lb,rr,rg,rb,embed)
	if lr and not lg and not rr then embed = lr lr = nil end
	if lr and lg and rr and not rg then embed = rr rr = nil end
	embed = embed ~= nil and embed or self.embedMode
	if not embed then
		self.tooltipRegistry[tooltip].enhTT:AddDoubleLine(textLeft,textRight,lr,lg,lb,rr,rg,rb)
		self.tooltipRegistry[tooltip].enhTTUsed = true
	else
		tooltip:AddDoubleLine(textLeft,textRight,lr,lg,lb,rr,rg,rb)
	end
end

function lib:AddMoneyLine(tooltip,text,money,r,g,b,embed)
	if r and not g then embed = r r = nil end
	embed = embed ~= nil and embed or self.embedMode

	local scale,width = .9
	local reg = self.tooltipRegistry[tooltip]
	local t = tooltip
	if not embed then
		t = reg.enhTT
		scale = 0.7
		reg.enhTTUsed = true
	end
	local moneyFrame = self:GetFreeMoneyFrame(t,scale)

	t:AddLine(text,r,g,b)
	local n = t:NumLines()
	local left = getglobal(t:GetName().."TextLeft"..n)
	moneyFrame:SetPoint("RIGHT",t,"RIGHT")
	moneyFrame:SetPoint("LEFT",left,"RIGHT")
	MoneyFrame_Update(moneyFrame:GetName(),money)
	width = left:GetWidth() + moneyFrame:GetWidth() * moneyFrame:GetEffectiveScale() / t:GetEffectiveScale()

	if t == tooltip and width > reg.minWidth then
		reg.minWidth = width
		t:SetMinimumWidth(width)
	elseif t.minWidth and width > t.minWidth then
		t.minWidth = width
		t:SetMinimumWidth(width)
	end
	t:Show()
end

local function moneyFrameOnHide(self)
	lib.moneyPool[self] = true
	self:Hide()
end

local moneyCount = 0

local function createMoney()
	local n = moneyCount + 1
	moneyCount = n
	local name = LIBSTRING.."MoneyFrame"..n
	m = CreateFrame("Frame",name,nil,"SmallMoneyFrameTemplate")
	m:UnregisterAllEvents()
	m:Show()
	m:SetScript("OnHide",moneyFrameOnHide)
	m:SetFrameStrata("TOOLTIP")
	m.info = MoneyTypeInfo["STATIC"]

	m.gold = getglobal(name .. "GoldButton")
	m.silver = getglobal(name .. "SilverButton")
	m.copper = getglobal(name .. "CopperButton")

	m.gold:EnableMouse(false)
	m.silver:EnableMouse(false)
	m.copper:EnableMouse(false)

	return m
end


function lib:GetFreeMoneyFrame(parent,scale)
	if not self.moneyPool then
		self.moneyPool = {}
	end
	local m = next(self.moneyPool) or createMoney()
	m:SetScale(scale)
	m:SetParent(parent)
	m:Show()
	self.moneyPool[m] = nil

	local level = parent:GetFrameLevel() + 1
	m.gold:SetFrameLevel(level)
	m.silver:SetFrameLevel(level)
	m.copper:SetFrameLevel(level)

	return m
end

function lib:Deactivate()
	if self.tooltipRegistry then
		for tooltip in self.tooltipRegistry do
			unhookscript(tooltip,"OnTooltipSetItem")
			unhookscript(tooltip,"OnTooltipCleared")
			unhookscript(tooltip,"OnSizeChanged")
			for k,v in pairs(tooltipMethods) do
				unhook(tooltip,k)
			end
		end
	end
end

function lib:Activate()
	if self.tooltipRegistry then
		local oldreg = self.tooltipRegistry
		self.tooltipRegistry = nil
		for tooltip in oldreg do
			self:RegisterTooltip(tooltip)
		end
	end
end

function lib:GenerateTooltipMethodTable() -- Sets up hooks to give the quantity of the item
	local reg = self.tooltipRegistry
	tooltipMethods = {
		SetBagItem = function(self,bag,slot)
			local _,q = GetContainerItemInfo(bag,slot) reg[self].quantity = q
		end,

		SetAuctionItem = function(self,type,index)
			local _,_,q = GetAuctionItemInfo(type,index) reg[self].quantity = q
		end,

		SetInboxItem = function(self,index)
			local _,_,q = GetInboxItem(index) reg[self].quantity = q
		end,

		SetLootItem = function(self,index)
			local _,_,q = GetLootSlotInfo(index) reg[self].quantity = q
		end,

		SetMerchantItem = function(self,index)
			local _,_,_,q = GetMerchantItemInfo(index) reg[self].quantity = q
		end,

		SetQuestLogItem = function(self,type,index)
			local _,_,q = GetQuestLogChoiceInfo(type,index) reg[self].quantity = q
		end,

		SetQuestItem = function(self,type,index)
			local _,_,q = GetQuestItemInfo(type,index) reg[self].quantity = q
		end,

		SetTradeSkillItem = function(self,index,reagentIndex)
			if reagentIndex then
				local _,_,q = GetTradeSkillReagentInfo(index,reagentIndex) reg[self].quantity = q
			else
				reg[self].quantity = GetTradeSkillNumMade(index)
			end
		end,

		SetCraftItem = function(self,index,reagentIndex)
			local _
			if reagentIndex then
				_,_,reg[self].quantity = GetCraftReagentInfo(index,reagentIndex)
			else
				-- Doesn't look like there is a way to get quantity info for crafts
			end
		end
	}
end

do -- EnhTT "class" definition
	local methods = {"InitLines","Attach","Show","MatchSize","Release","NeedsRefresh"}
	local scripts = {"OnShow","OnSizeChanged"}
	local numTips = 0
	EnhTTClass = {}
	local class = EnhTTClass

	local addLine,addDoubleLine,show = GameTooltip.AddLine,GameTooltip.AddDoubleLine,GameTooltip.Show

	local line_mt = {
		__index = function(t,k)
			local v = getglobal(t.name..k)
			rawset(t,k,v)
			return v
		end
	}

	function class:new()
		local n = numTips + 1
		numTips = n
		local o = CreateFrame("GameTooltip",LIBSTRING.."Tooltip"..n,UIParent,"GameTooltipTemplate")

		for _,method in pairs(methods) do
			o[method] = self[method]
		end

		for _,script in pairs(scripts) do
			o:SetScript(script,self[script])
		end

		o.left = setmetatable({name = o:GetName().."TextLeft"},line_mt)
		o.right = setmetatable({name = o:GetName().."TextRight"},line_mt)
		return o
	end

	function class:Attach(tooltip)
		self.parent = tooltip
		self:SetParent(tooltip)
		self:SetOwner(tooltip,"ANCHOR_NONE")
		self:SetPoint("TOP",tooltip,"BOTTOM")
	end

	function class:Release()
		self.parent = nil
		self:SetParent(nil)
		self.minWidth = 0
		--self:SetWidth(0)
	end

	--[[
	function class:AddMoneyLine(text,r,g,b,moneyValue)
		self:AddLine(text,r,g,b)
		local n = self:NumLines()
		local left = self.left[n]
		local moneyFrame = EnhTooltip:GetFreeMoneyFrame()
		moneyFrame:SetPoint("RIGHT",self,"RIGHT")
		moneyFrame:SetPoint("LEFT",left,"RIGHT")
		MoneyFrame_Update(moneyFrame:GetName(),moneyValue)
		return moneyFrame:GetWidth()*moneyFrame:GetScale() + left:GetWidth()
	end
	]]
	function class:InitLines()
		local n = self:NumLines()
		local changedLines = self.changedLines
		if not changedLines or changedLines < n then
			for i = changedLines or 1,n do
				local left,right = self.left[i],self.right[i]
				local font
				if i == 1 then
					font = GameFontNormal
				else
					font = GameFontNormalSmall
				end
				left:SetFontObject(font)
				right:SetFontObject(font)
			end
			self.changedLines = n
		end
	end

	local function refresh(self)
		self:NeedsRefresh(false)
		self:MatchSize()
	end

	function class:NeedsRefresh(flag)
		if flag then
			self:SetScript("OnUpdate",refresh)
		else
			self:SetScript("OnUpdate",nil)
		end
	end

	function class:OnSizeChanged(w,h)
		local p = self.parent
		if not p then return end
		local l,r,t,b = p:GetClampRectInsets()
		p:SetClampRectInsets(l,r,t,-h) -- should that be b-h?  Is playing nice even needed? Anyone who needs to mess with the bottom clamping inset will probably interfere with us anyway, right?
		self:NeedsRefresh(true)
	end

	-- The right-side text is statically positioned to the right of the left-side text.
	-- As a result, manually changing the width of the tooltip causes the right-side text to not be in the right place.
	local function fixRight(tooltip,lefts,rights)
		local name,rn,ln,left,right
		local getglobal = getglobal
		if not lefts then
			name = tooltip:GetName()
			rn = name .. "TextRight"
			ln = name .. "TextLeft"
		end
		for i=1,tooltip:NumLines() do
			if not lefts then
				left = getglobal(ln..i)
				right = getglobal(rn..i)
			else
				left = lefts[i]
				right = rights[i]
			end
			if right:IsVisible() then
				right:ClearAllPoints()
				right:SetPoint("LEFT",left,"RIGHT")
				right:SetPoint("RIGHT",-10,0)
				right:SetJustifyH("RIGHT")
			end
		end
	end

	function class:MatchSize()
		local p = self.parent
		local pw = p:GetWidth()
		local w = self:GetWidth()
		local d = pw - w
		if d > .2 then
			self.sizing = true
			self:SetWidth(pw)
			fixRight(self,self.left,self.right)
			--ChatFrame1:AddMessage("match size: SMALLER")
		elseif d < -.2 then
			self.sizing = true
			p:SetWidth(w)
			fixRight(p)
			--ChatFrame1:AddMessage("match size: LARGER")
		end
	end

--[[	function class:OnShow()
		self:InitLines()
	end
]]
	function class:Show()
		show(self)
		self:InitLines()
	end

end

-- More housekeeping upgrade stuff
lib:SetEmbedMode(lib.embedMode)
lib:Activate()

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Test Code
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------
--local LT = LibStub("LibTooltip-Beta1")

--LT:RegisterTooltip(GameTooltip)
--LT:RegisterTooltip(ItemRefTooltip)

--LT:AddCallback(function(tip,item,quantity,name,link,quality,ilvl)
--	LT:AddDoubleLine(tip,"Item Level:",ilvl,nil,nil,nil,1,1,1,0)
--	LT:AddDoubleLine(tip,"Item Level:",ilvl,1,1,1,0)
--	LT:AddDoubleLine(tip,"Item Level:",ilvl,0)
--end,0)

--~ LT:AddCallback(function(tip,item,quantity)
--~ 	quantity = quantity or 1
--~ 	local price = GetSellValue(item)
--~ 	if price then
--~ 		price = price * quantity
--~ 		LT:AddMoneyLine(tip,"Sell to vendor"..(quantity and quantity > 1 and "("..quantity..")" or "") .. ":",price)
--~ 	end
--~ end)
