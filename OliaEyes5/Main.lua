local Jungle, jungle = ...

-- Global Interface for Thread Switching (Mapped to Engine)
function run_thread1() jungle.Engine:SetThread(1) end
function run_thread2() jungle.Engine:SetThread(2) end
function run_thread3() jungle.Engine:SetThread(3) end
function run_thread4() jungle.Engine:SetThread(4) end

-- Initialize Global Tick
jungle.currentTick = 0

-- Main Event Loop
local f = CreateFrame("Frame");
function f:onUpdate(sinceLastUpdate)
    self.sinceLastUpdate = (self.sinceLastUpdate or 0) + sinceLastUpdate;
    if ( self.sinceLastUpdate >= 0.05 ) then -- 20Hz Tick
        
        -- Delegate to Singleton Engine
        if jungle.Engine then
            jungle.Engine:OnUpdate(self.sinceLastUpdate)
        end
        
        self.sinceLastUpdate = 0;
    end
end

-- Start
f:SetScript("OnUpdate", f.onUpdate)
-- Force initialization on load
if jungle.Engine then jungle.Engine:Initialize() end