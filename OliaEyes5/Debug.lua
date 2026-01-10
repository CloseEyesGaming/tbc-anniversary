local Jungle, jungle = ...

local isDebug = true
jungle.isDebug = isDebug
local f1 = CreateFrame("Frame",nil,UIParent)
f1:SetWidth(1) 
f1:SetHeight(1) 
f1:SetAlpha(.7);
f1:SetPoint("CENTER",0,0)
f1.text = f1:CreateFontString(nil,"ARTWORK") 
f1.text:SetFont("Fonts\\ARIALN.ttf", 20, "OUTLINE")
-- f1.text:SetTextColor(1, 1, 1)
f1.text:SetPoint("CENTER",0,-100)
f1:Hide()
 
local f2 = CreateFrame("Frame",nil,UIParent)
f2:SetWidth(1) 
f2:SetHeight(1) 
f2:SetAlpha(.7);
f2:SetPoint("CENTER",0,-200)
f2.text = f2:CreateFontString(nil,"ARTWORK") 
f2.text:SetFont("Fonts\\ARIALN.ttf", 20, "OUTLINE")
f2.text:SetPoint("CENTER",0,0)
f2:Hide()
 
local function debugAction(show, r, g, b, message)
	if isDebug then
		if show == 1 then
			f1.text:SetText(message)
			f1.text:SetTextColor(r, g, b)
			f1:Show()
			f2:Hide()
		elseif show == 2 then
			f2.text:SetText(message)
			f2.text:SetTextColor(r, g, b)
			f2:Show()
			f1:Hide()
		else
			f1:Hide()
			f2:Hide()
		end
	end
end
jungle.debugAction = debugAction
 
-- debugShow(1, "|cffffffffmyobjective1")
-- --or 
-- debugShow(2, "|cffffffffmyobjective2")
-- --or 
-- debugShow() -- to just hide both
-- --or possibly display both objectives in the one fontstring
-- debugShow(1, "myobjective1\nmyobjective2")
 
--To use variables:
-- local objective1 = "myobjective1"
-- local objective2 = "myobjective2"
-- debugShow(1, objective1.."\n"..objective2)
