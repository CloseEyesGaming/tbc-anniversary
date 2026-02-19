local Jungle, jungle = ...

local Engine = {}
jungle.Engine = Engine

Engine.rotation = nil
Engine.pixel = nil
Engine.pixelReset = nil
Engine.activeThread = 0 
Engine.initialized = false

function Engine:Initialize()
    if self.initialized then return end
    self.rotation = jungle.Rotation:new()
    self.pixel = jungle.Pixel:new()
    self.pixelReset = jungle.Pixel:new({0,0,0}, 1)
    self.initialized = true
    print("|cff00FF00[OliaEyes]|r Engine Initialized.")
end

function Engine:SetThread(threadID)
    self.activeThread = threadID
end

function Engine:ProcessRotation()
    if not self.initialized then self:Initialize() end
    self.pixelReset:clear()
    
    local _, engClass = UnitClass('player')
    if engClass == "DRUID" then
        local rot = self.rotation
-- Inside Engine:ProcessRotation() for DRUID
		if self.activeThread == 1 then
			if rot:rotate({jungle.universalHealSetV3}, 1) then return true end
		elseif self.activeThread == 2 then
			if rot:rotate({jungle.universalHealSet}, 1) then return true end
		elseif self.activeThread == 3 then
			if rot:rotate({jungle.dispellSet}, 1) then return true end
		elseif self.activeThread == 4 then
			if rot:rotate({jungle.tankRollSet2, jungle.raidHealSet2}, 1) then return true end
		elseif self.activeThread == 5 then -- MOVED: Baseline DPS Thread
			if rot:dpsRotate({jungle.dpsSet}, 1) then return true end
		elseif self.activeThread == 6 then 
			if rot:rotate({jungle.buffSet}, 1) then return true end
		elseif self.activeThread == 7 then
            if rot:rotate({jungle.Fishing,}, 1) then return end
		end
    end
end

function Engine:OnUpdate(sinceLastUpdate)
    jungle.currentTick = (jungle.currentTick or 0) + 1
    jungle.updateUnitsData()
    
	if jungle.Los then
        jungle.Los:OnUpdate()
    end
    
    local _, instanceType = IsInInstance()
    if (instanceType == 'pvp' or instanceType == 'arena') and GetNumGroupMembers() <= 15 then
        jungle.subTableTimerRemove(Controlled_Root_table, 18)
        jungle.subTableTimerRemove(Controlled_Stun_table, 18)
        jungle.subTableTimerRemove(Disorient_table, 18)
        jungle.subTableTimerRemove(Incapacitate_table, 18)
        jungle.subTableTimerRemove(Silence_table, 18)
    end
    
    self:ProcessRotation()
end