local methods = {"InitLines","Attach","Show","MatchSize","Release","NeedsRefresh"}
local scripts = {"OnShow","OnSizeChanged"}
local numTips = 0
local class = {}

local addLine,addDoubleLine,show = GameTooltip.AddLine,GameTooltip.AddDoubleLine,GameTooltip.Show

local line_mt = {
    __index = function(t,k)
        local v = getglobal(t.name..k)
        rawset(t,k,v)
        return v
    end
}

function EnhTooltip:NewEnhTTObject()
    return class:new()
end

function class:new()
    local n = numTips + 1
    numTips = n
    local o = CreateFrame("GameTooltip","EnhancedTooltip"..n,UIParent,"GameTooltipTemplate")

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
	p:SetClampRectInsets(l,r,t,-h) -- should that be b-h?  Is playing nice even needed? Anyone who needs to mess with the bottom will probably interfere with us anyway, right?
	self:NeedsRefresh(true)	
end

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


function class:MatchSize()  -- TODO: Tweak this to use an OnUpdate and a dirty flag
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

function class:OnShow()
    self:InitLines()
end

function class:Show()
    show(self)
	self:InitLines()
end
