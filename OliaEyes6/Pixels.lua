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
    setmetatable(self, Pixel)
    self.color = color
    self.pix = pix
    return self;
end

function Pixel:set()
    if self.pix == 1 then
        if HelloWorld1.texture then
            HelloWorld1.texture:SetColorTexture(self.color[1], self.color[2], self.color[3])
            return true
        end
    end
end

-- [CRITICAL FIX] Smart Clear Logic + Debug Reset
function Pixel:clear()
    if self.pix == 1 then
        if HelloWorld1.texture then
            local r, g, b = 0, 0, 0
            local actionMsg = "Idle"
            local targetMsg = "None"

            -- 1. Check State (Focus Logic)
            if UnitExists("focus") then
                -- IDLE + FOCUS: Show Green (Key 7)
                r, g, b = 0.0863, 0.2549, 0.0392
                actionMsg = "Clear Focus"
                targetMsg = UnitName("focus") or "Focus"
            end
            
            -- 2. Apply Visual Pixel (For Python)
            HelloWorld1.texture:SetColorTexture(r, g, b)

            -- 3. [DEBUG FIX] Reset the Panel
            -- We force the panel to show "Idle" right now.
            -- If a spell is cast later in this same frame, it will overwrite this with "Cast: X".
            if jungle.Debug then
                jungle.Debug:UpdateCast(actionMsg, targetMsg, {r, g, b})
            end

            return true
        end
    end
end

jungle.Pixel = Pixel