local Jungle, jungle = ...

-- 1. Setup the Frame (Global)
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:SetScript("OnEvent", function(self, event, ...) 
    self[event](self, ...) 
end)

-- The actual color frame
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

-- 2. Pixel Class Definition
local Pixel = {};
Pixel.__index = Pixel 

function Pixel:new(color, pix)
    local self = {};
    setmetatable(self, Pixel) -- Helper looks up methods in 'Pixel' table
    self.color = color
    self.pix = pix
    return self;
end

function Pixel:set()
    if self.pix == 1 then
        -- Safety check if texture exists (e.g. before login)
        if HelloWorld1.texture then
            HelloWorld1.texture:SetColorTexture(self.color[1], self.color[2], self.color[3])
            return true
        end
    end
end

function Pixel:clear()
    if self.pix == 1 then
        if HelloWorld1.texture then
            if UnitExists("focus") then
                -- IDLE + FOCUS: Show Green (ClearFocus)
                -- This signals the bot to press '7'
                HelloWorld1.texture:SetColorTexture(0.0863, 0.2549, 0.0392)
            else
                -- IDLE + NO FOCUS: Show Black
                -- This signals the bot to do NOTHING
                HelloWorld1.texture:SetColorTexture(0, 0, 0)
            end
            return true
        end
    end
end

jungle.Pixel = Pixel