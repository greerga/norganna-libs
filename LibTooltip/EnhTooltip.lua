EnhTooltip = {embedMode = false}
local tooltipMethods

local function OnTooltipSetItem(tooltip)
	local self = EnhTooltip
	local reg = self.tooltipRegistry[tooltip]
	
	if self.sortedCallbacks and #self.sortedCallbacks > 0 then
		tooltip:Show()
		local _,item = tooltip:GetItem()
		if item then 
			local name,link,quality,ilvl,minlvl,itype,isubtype,stack,equiploc,texture = GetItemInfo(item)
			if name then        
				if self.embedMode == false then
					local enhTT = self:GetFreeEnhTTObject()
					reg.enhTT = enhTT
					enhTT:Attach(tooltip)
					enhTT:AddLine(ITEM_QUALITY_COLORS[quality].hex .. name)
				end
				
				local quantity = reg.quantity
				for i,callback in ipairs(self.sortedCallbacks) do
					callback(tooltip,item,quantity,name,link,quality,ilvl,minlvl,itype,isubtype,stack,equiploc,texture)
				end
				tooltip:Show()
				if reg.enhTT then reg.enhTT:Show() end
			end
		end
	end
	if reg.OnTooltipSetItem then reg.OnTooltipSetItem(tooltip) end
end

local function OnTooltipCleared(tooltip)
	local self = EnhTooltip
	local reg = self.tooltipRegistry[tooltip]
	if reg.enhTT then
		table.insert(self.enhTTpool,reg.enhTT)
		reg.enhTT:Hide()
		reg.enhTT:Release()
		reg.enhTT = nil
	end
	reg.minWidth = 0
	reg.quantity = nil
	if reg.OnHide then reg.OnHide(tooltip) end
end

local function OnSizeChanged(tooltip,w,h)
	local self = EnhTooltip
	local reg = self.tooltipRegistry[tooltip]
	local enhTT = reg.enhTT
	if enhTT then
		enhTT:NeedsRefresh(true)
	end
	
	if reg.OnSizeChanged then reg.OnSizeChanged(tooltip,w,h) end
end

function EnhTooltip:GetFreeEnhTTObject()
	if not self.enhTTpool then self.enhTTpool = {} end
	return table.remove(self.enhTTpool) or self:NewEnhTTObject()
end

local function hook(tip,method,hook)  -- TODO, make these hooks a bit friendlier since they have to stay :(
	local orig = tip[method]
	tip[method] = function(...)
		hook(...)
		return orig(...)
	end
end

function EnhTooltip:RegisterTooltip(tooltip)
	if not tooltip or type(tooltip) ~= "table" or type(tooltip.GetObjectType) ~= "function" or tooltip:GetObjectType() ~= "GameTooltip" then return end

	if not self.tooltipRegistry then 
		self.tooltipRegistry = {} 
		self:GenerateTooltipMethodTable()
	end

	if not self.tooltipRegistry[tooltip] then
		local reg = {}
		self.tooltipRegistry[tooltip] = reg

		reg.OnTooltipSetItem = tooltip:GetScript("OnTooltipSetItem")
		reg.OnHide = tooltip:GetScript("OnHide")
		reg.OnSizeChanged = tooltip:GetScript("OnSizeChanged")
		
		tooltip:SetScript("OnTooltipSetItem",OnTooltipSetItem)
		tooltip:SetScript("OnTooltipCleared",OnTooltipCleared)
		tooltip:SetScript("OnSizeChanged",OnSizeChanged)

		for k,v in pairs(tooltipMethods) do
			--hooksecurefunc(tooltip,k,v)
			hook(tooltip,k,v)
		end
	end
end

local sortFunc
function EnhTooltip:AddCallback(callback,priority)
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

function EnhTooltip:RemoveCallback(callback)
	if not (self.callbacks and self.callbacks[callback]) then return end
	self.callbacks[callback] = nil
	for i,c in ipairs(self.sortedCallbacks) do
		if c == callback then
			table.remove(self.sortedCallbacks,i)
			break
		end
	end
end

function EnhTooltip:AddLine(tooltip,text,r,g,b,embed)
	if self.embedMode == false and not embed then
		self.tooltipRegistry[tooltip].enhTT:AddLine(text,r,g,b)
	else
		tooltip:AddLine(text,r,g,b)
	end
end

function EnhTooltip:AddDoubleLine(tooltip,textLeft,textRight,lr,lg,lb,rr,rg,rb,embed)
	if self.embedMode == false and not embed then
		self.tooltipRegistry[tooltip].enhTT:AddDoubleLine(textLeft,textRight,lr,lg,lb,rr,rg,rb)
	else
		tooltip:AddDoubleLine(textLeft,textRight,lr,lg,lb,rr,rg,rb)
	end
end

function EnhTooltip:AddMoneyLine(tooltip,text,money,r,g,b,embed)
	local scale,width = .9
	local reg = self.tooltipRegistry[tooltip]
	local t = tooltip
	if self.embedMode == false and not embed then
		t = reg.enhTT
		scale = 0.7
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
	EnhTooltip.moneyPool[self] = true
	self:Hide()
end

local moneyCount = 0

local function createMoney()
	local n = moneyCount + 1
	moneyCount = n
	local name = "EnhTooltipMoneyFrame"..n
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


function EnhTooltip:GetFreeMoneyFrame(parent,scale)
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


function EnhTooltip:GenerateTooltipMethodTable()
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

EnhTooltip:RegisterTooltip(GameTooltip)
EnhTooltip:RegisterTooltip(ItemRefTooltip)

--~ EnhTooltip:AddCallback(function(tip,item,quantity,name,link,quality,ilvl) EnhTooltip:AddDoubleLine(tip,"Item Level:",ilvl,nil,nil,nil,1,1,1) end,0)

--~ EnhTooltip:AddCallback(function(tip,item,quantity)
--~ 	quantity = quantity or 1
--~ 	local price = GetSellValue(item)
--~ 	if price then
--~ 		price = price * quantity
--~ 		EnhTooltip:AddMoneyLine(tip,"Sell to vendor"..(quantity and quantity > 1 and "("..quantity..")" or "") .. ":",price)
--~ 	end
--~ end)
