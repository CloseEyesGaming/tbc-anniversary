local Jungle, jungle = ...

local EventFrame = CreateFrame("Frame")
function EventFrame:OnEvent(event, ...) 
	self[event](self, ...) 
end
EventFrame:SetScript("OnEvent", EventFrame.OnEvent)

EventFrame:RegisterEvent("PLAYER_LOGIN")

local HelloWorld1 = CreateFrame("Frame", nil, UIParent) 

function EventFrame:PLAYER_LOGIN() 
	HelloWorld1:SetFrameStrata("BACKGROUND")
	HelloWorld1:SetWidth(1) 
	HelloWorld1:SetHeight(1) 
	HelloWorld1.texture = HelloWorld1:CreateTexture(nil,"BACKGROUND")
	HelloWorld1.texture:SetAllPoints(HelloWorld1)
	HelloWorld1:SetPoint("TOPLEFT",0,0)
	HelloWorld1:Show()
end 

local Pixel = {};
function Pixel:new(color, pix)
	local self = {};
	self.color = color
	self.pix = pix
	-- <Create variables as above here>
	self.set = function()
		if pix == 1 then
			HelloWorld1.texture:SetColorTexture(self.color[1], self.color[2], self.color[3])
			return true
		end
	end
	self.clear = function()
		if pix == 1 then
			HelloWorld1.texture:SetColorTexture(0, 0, 0)
			return true
		end
	end
	return self;
end
jungle.Pixel = Pixel