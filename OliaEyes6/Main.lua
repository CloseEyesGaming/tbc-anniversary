local Jungle, jungle = ...

--fishing interactive bobber
SetCVar( "SoftTargetInteractArc", 2 );
SetCVar( "SoftTargetInteractRange", 30 );
-- Core Gamepad Lockdown (Fixes Camera Lock and PAD5/6 failures)
SetCVar("GamepadEnable", "1")
SetCVar("GamepadOverlapMouseMs", "0")        -- INSTANT mouse priority
SetCVar("GamepadCameraLook", "0")            -- Disable stick camera move
SetCVar("GamepadCursorAutoEnable", "0")      -- Disable virtual mouse
SetCVar("GamepadCursorLeftClick", "NONE")
SetCVar("GamepadCursorRightClick", "NONE")
SetCVar("GamepadCursorCentering", "0")
SetCVar("GamepadCursorSpeed", "0")
		
-- Global Interface for Thread Switching (Mapped to Engine)
function run_thread1() jungle.Engine:SetThread(1) end
function run_thread2() jungle.Engine:SetThread(2) end
function run_thread3() jungle.Engine:SetThread(3) end
function run_thread4() jungle.Engine:SetThread(4) end
function run_thread5() jungle.Engine:SetThread(5) end
function run_thread6() jungle.Engine:SetThread(6) end
function run_thread7() jungle.Engine:SetThread(7) end

-- Initialize Global Tick
jungle.currentTick = 0

-- Main Event Loop
local f = CreateFrame("Frame");
function f:onUpdate(sinceLastUpdate)
    self.sinceLastUpdate = (self.sinceLastUpdate or 0) + sinceLastUpdate;
    if ( self.sinceLastUpdate >= 0.01 ) then -- 20Hz Tick
        
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

-- [COMMAND HANDLER]
SLASH_OLIA1 = "/olia"
SlashCmdList["OLIA"] = function(msg)
    -- ERROR FIXED: '...' line removed here. 'jungle' is already visible.
    local cmd = msg:lower()
    
    if cmd == "debug" then
        if jungle.Hotkeys then
            jungle.Hotkeys:ToggleDebug()
        else
            print("Hotkeys module not loaded.")
        end
    elseif cmd == "dump" then
        if jungle.Hotkeys then
            jungle.Hotkeys:DumpBindings()
        else
            print("Hotkeys module not loaded.")
        end
    else
        print("|cFF00FFFF[OliaEyes]|r Commands: /olia debug, /olia dump")
    end
end