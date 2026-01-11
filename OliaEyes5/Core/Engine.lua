local Jungle, jungle = ...

local Engine = {}
jungle.Engine = Engine

-- Singleton Storage: Created ONCE, used forever.
Engine.rotation = nil
Engine.pixel = nil
Engine.pixelReset = nil
Engine.activeThread = 0 -- 0=None, 1=Burst, 2=Heal, 3=.., 4=DPS
Engine.initialized = false

function Engine:Initialize()
    if self.initialized then return end
    
    -- 1. Create Heavy Objects ONCE (The Fix)
    self.rotation = jungle.Rotation:new()
    self.pixel = jungle.Pixel:new()
    
    -- Pre-allocate a specific pixel for resetting
    self.pixelReset = jungle.Pixel:new({0,0,0}, 1)
    
    self.initialized = true
    print("|cff00FF00[OliaEyes]|r Engine Initialized.")
end

function Engine:SetThread(threadID)
    self.activeThread = threadID
    print("|cff00FF00[OliaEyes]|r Active Thread: " .. threadID)
end

function Engine:ProcessRotation()
    -- Safety Check
    if not self.initialized then self:Initialize() end

    -- Reset Pixel at start of frame
    self.pixelReset:clear()
    
    -- Context Checks
    local _, engClass = UnitClass('player')
    
    -- DRUID LOGIC (Moved from Main.lua)
    if engClass == "DRUID" then
        if C_Spell.GetSpellInfo('Lifebloom') then
            local rot = self.rotation -- Use cached instance
            
            if self.activeThread == 1 then
                return -- Placeholder for Thread 1 logic
            elseif self.activeThread == 2 then
                -- The Main Healing Loop
                if rot:rotate({jungle.druidBurstHeal,}, 1) then return end
                if rot:arenaRotate({jungle.druidAntiCcSelf,}, 1) then return end
                if rot:rotate({jungle.druidSelfDef,}, 1) then return end
                if rot:rotate({jungle.druidDispell,}, 1) then return end                
                if rot:rotate({jungle.druidHealBasic,}, 1) then return end
                if rot:arenaRotate({jungle.druidCCHealer}, 1) then return end
                if rot:rotate({jungle.druidDefaultAssist,}, 1) then return end
                if rot:rotate({jungle.druidPreHot,}, 1) then return end
            elseif self.activeThread == 3 then
                return -- Placeholder
            elseif self.activeThread == 4 then
                if rot:dpsRotate({jungle.druidManualCC,}, 1) then return end
            end
        end
    
    -- PRIEST / PALADIN (Placeholders preserved from Main.lua)
    elseif engClass == "PRIEST" then
        if C_Spell.GetSpellInfo('Shadowform') then return end
    elseif engClass == "PALADIN" then
        if C_Spell.GetSpellInfo('Templar\'s Verdict') then return end
    end
end

-- The Main Loop (Replaces f:onUpdate content)
function Engine:OnUpdate(dt)
    -- Global Tick (From Phase 1)
    jungle.currentTick = (jungle.currentTick or 0) + 1

    -- Update Data
    jungle.updateUnitsData()
    
    -- Timer Maintenance
    local _, instanceType = IsInInstance()
    jungle.TableTimerRemove(LoSTable, 1)
    jungle.TableTimerRemove(UnitBehindTable, 1)
    jungle.TableTimerRemove(UnitInFrontTable, 1)
    
    if (instanceType == 'pvp' or instanceType == 'arena') and GetNumGroupMembers() <= 15 then
        jungle.subTableTimerRemove(Controlled_Root_table, 18)
        jungle.subTableTimerRemove(Controlled_Stun_table, 18)
        jungle.subTableTimerRemove(Disorient_table, 18)
        jungle.subTableTimerRemove(Incapacitate_table, 18)
        jungle.subTableTimerRemove(Silence_table, 18)
    end
    
    -- Run Rotation
    self:ProcessRotation()
end