local Jungle, jungle = ...
local GetPlayerClass = jungle.GetPlayerClass
local Perf = jungle.Perf
local DebugProfileStop = debugprofilestop

local Engine = {}
jungle.Engine = Engine

Engine.rotation = nil
Engine.pixel = nil
Engine.pixelReset = nil
Engine.activeThread = 0 
Engine.initialized = false
Engine.rotationSets = nil

local housekeepingElapsed = 0
local HOUSEKEEPING_INTERVAL = 1.0

function Engine:Initialize()
    if self.initialized then return end
    self.rotation = jungle.Rotation:new()
    self.pixel = jungle.Pixel:new()
    self.pixelReset = jungle.Pixel:new({0,0,0}, 1)
    -- Routine modules load after Engine.lua, so capture their function references
    -- here, once the full addon has finished loading.
    self.rotationSets = {
        fishing = {jungle.Fishing},
        druidUniversal = {jungle.dispellSet, jungle.universalHealSetV6},
        warriorArmsPveMaintenance = {jungle.warriorArmsPveMaintenance},
        warriorArms = {jungle.warriorArms},
        warriorThread3AoE = {jungle.warriorThread3AoE},
        follower = {jungle.followerSet},
        druidBuff = {jungle.buffSet},
        druidPvP = {jungle.universalPvPMatrix},
        druidHeal = {jungle.universalHealSetV6},
        druidDispel = {jungle.dispellSet},
        druidRaid = {jungle.tankRollSet2, jungle.raidHealSet2},
        druidDps = {jungle.druid_interrupt, jungle.dpsSet},
        warriorUniversal = {jungle.warriorUniversal},
        warriorTank = {jungle.warriorTank},
        rogueDps = {jungle.rogueDpsSet},
    }
    if jungle.Arena then
        jungle.Arena:Initialize()
    end
    self.initialized = true
    print("|cff00FF00[OliaEyes]|r Engine Initialized.")
end

function Engine:SetThread(threadID)
    self.activeThread = threadID
end

function Engine:ProcessRotation()
    if not self.initialized then self:Initialize() end
    self.pixelReset:clear()
    
    local engClass = GetPlayerClass()
    local rot = self.rotation
    local sets = self.rotationSets

    -- ==========================================
    -- GLOBAL INTERCEPTORS
    -- ==========================================
    if engClass == "DRUID" then
        local castingName = UnitCastingInfo("player")
        if castingName then
            -- We pass 1 and 10 as priority bounds (safely covers our rotation sizes)
            if jungle.CurrentCastStop(castingName, 1, 10) then
                return jungle.Cast:CastSpell("Stopcasting", "player", 1)
            end
            -- If we are casting and shouldn't stop, we return early so we don't start a new cast
            return true 
        end
    end

    -- ==========================================
    -- THREAD 7: UNIVERSAL DISPATCHER
    -- ==========================================
    if self.activeThread == 7 then
        if IsEquippedItemType("Fishing Poles") then
            if rot:rotate(sets.fishing, 1) then return end
        else
            if engClass == "DRUID" then
                local isDrinking = jungle.unitCacheBuff("player", "Drink") or jungle.unitCacheBuff("player", "Refreshment")
                local manaPercent = UnitPowerMax("player", 0) > 0 and (UnitPower("player", 0) / UnitPowerMax("player", 0)) or 1
                if isDrinking and manaPercent < 0.8 then
                    return true -- Skip thread 7 actions to not interrupt drinking
                end
            end
            
            -- 1. Class-specific Support/Combat (PRIORITY)
            if engClass == "DRUID" then
                if rot:rotate(sets.druidUniversal, 1) then return true end
            elseif engClass == "WARRIOR" then
                if rot:dpsRotate(sets.warriorArmsPveMaintenance, 1) then return true end
                if rot:dpsRotate(sets.warriorArms, 1) then return true end
            end
            
            -- 2. Follower movement and mounting, after urgent class support.
            if rot:rotate(sets.follower, 1) then return true end

            -- Druid follower buffs are the final priority in this thread.
            -- Reuse the same routine exposed by the dedicated buff thread (6).
            if engClass == "DRUID" then
                if rot:rotate(sets.druidBuff, 1) then return true end
            end
        end
        return true -- Thread 7 complete
    end
    
    -- ==========================================
    -- CLASS SPECIFIC THREADS
    -- ==========================================
    if engClass == "DRUID" then
		if self.activeThread == 1 then
			if rot:rotate(sets.druidPvP, 1) then return true end
		elseif self.activeThread == 2 then
			if rot:rotate(sets.druidHeal, 1) then return true end
		elseif self.activeThread == 3 then
			if rot:rotate(sets.druidDispel, 1) then return true end
		elseif self.activeThread == 4 then
			if rot:rotate(sets.druidRaid, 1) then return true end
		elseif self.activeThread == 5 then -- Baseline DPS Thread
			if rot:dpsRotate(sets.druidDps, 1) then return true end
		elseif self.activeThread == 6 then 
			if rot:rotate(sets.druidBuff, 1) then return true end
		end
    elseif engClass == "WARRIOR" then
        if self.activeThread == 1 then
            if rot:dpsRotate(sets.warriorArmsPveMaintenance, 1) then return true end
            if rot:dpsRotate(sets.warriorUniversal, 1) then return true end        
		elseif self.activeThread == 2 then
            if rot:dpsRotate(sets.warriorUniversal, 1) then return true end
        elseif self.activeThread == 3 then
            local threadTarget = nil
            if UnitExists('target') and UnitCanAttack('player', 'target') and not UnitIsDeadOrGhost('target') then
                threadTarget = 'target'
            elseif UnitExists('softenemy') and UnitCanAttack('player', 'softenemy') and not UnitIsDeadOrGhost('softenemy') then
                threadTarget = 'softenemy'
            end

            if threadTarget and jungle.WarriorThread3OwnsTarget(threadTarget) then
                if rot:dpsRotate(sets.warriorThread3AoE, 1) then return true end
                return true -- Hold the tick while Thread 3 is intentionally pooling.
            end
            if rot:dpsRotate(sets.warriorUniversal, 1) then return true end
        elseif self.activeThread == 5 then
            if rot:dpsRotate(sets.warriorTank, 1) then return true end
        end
    elseif engClass == "ROGUE" then
        if self.activeThread == 5 then
            if rot:dpsRotate(sets.rogueDps, 1) then return true end
        end
    end
end

function Engine:OnUpdateProfiled(sinceLastUpdate)
    local frameStart = DebugProfileStop()
    jungle.currentTick = (jungle.currentTick or 0) + 1

    local sectionStart = DebugProfileStop()
    jungle.updateUnitsData()
    Perf:Record("units", DebugProfileStop() - sectionStart)

    -- Expiry checks remain time-aware at query time. This sweep only reclaims
    -- stale cache entries and therefore does not need to run every frame.
    housekeepingElapsed = housekeepingElapsed + (sinceLastUpdate or 0)
    if housekeepingElapsed >= HOUSEKEEPING_INTERVAL then
        local housekeepingStart = DebugProfileStop()
        housekeepingElapsed = housekeepingElapsed - HOUSEKEEPING_INTERVAL
        local now = GetTime()
        if jungle.Los then
            jungle.Los:OnUpdate(now)
        end
        jungle.subTableTimerRemove(Controlled_Root_table, 18)
        jungle.subTableTimerRemove(Controlled_Stun_table, 18)
        jungle.subTableTimerRemove(Disorient_table, 18)
        jungle.subTableTimerRemove(Incapacitate_table, 18)
        jungle.subTableTimerRemove(Silence_table, 18)
        Perf:Record("housekeeping", DebugProfileStop() - housekeepingStart)
    end

    if jungle.Arena then
        local arenaStart = DebugProfileStop()
        jungle.Arena:OnUpdate()
        Perf:Record("arena", DebugProfileStop() - arenaStart)
    end

    sectionStart = DebugProfileStop()
    self:ProcessRotation()
    local frameEnd = DebugProfileStop()
    Perf:Record("rotation", frameEnd - sectionStart)
    Perf:Record("engine", frameEnd - frameStart)
end

function Engine:OnUpdate(sinceLastUpdate)
    if Perf.enabled then
        return self:OnUpdateProfiled(sinceLastUpdate)
    end

    jungle.currentTick = (jungle.currentTick or 0) + 1
    jungle.updateUnitsData()

    -- Expiry checks remain time-aware at query time. This sweep only reclaims
    -- stale cache entries and therefore does not need to run every frame.
    housekeepingElapsed = housekeepingElapsed + (sinceLastUpdate or 0)
    if housekeepingElapsed >= HOUSEKEEPING_INTERVAL then
        housekeepingElapsed = housekeepingElapsed - HOUSEKEEPING_INTERVAL
        local now = GetTime()
        if jungle.Los then
            jungle.Los:OnUpdate(now)
        end
        jungle.subTableTimerRemove(Controlled_Root_table, 18)
        jungle.subTableTimerRemove(Controlled_Stun_table, 18)
        jungle.subTableTimerRemove(Disorient_table, 18)
        jungle.subTableTimerRemove(Incapacitate_table, 18)
        jungle.subTableTimerRemove(Silence_table, 18)
    end
    
    if jungle.Arena then
        jungle.Arena:OnUpdate()
    end
    
    self:ProcessRotation()
end

-- ==========================================
-- MACROS
-- ==========================================
function _G.tsmAuto()
    -- 3. run buy command if item is already selected & buy button is enabled
    if _G.TSMSniperBtn and _G.TSMSniperBtn:IsVisible() and _G.TSMSniperBtn:IsEnabled() then
        _G.TSMSniperBtn:Click()
        return true
    end
    if _G.TSMShoppingBuyoutBtn and _G.TSMShoppingBuyoutBtn:IsVisible() and _G.TSMShoppingBuyoutBtn:IsEnabled() then
        _G.TSMShoppingBuyoutBtn:Click()
        return true
    end

    -- Use the known global TSMSniperBtn to locate the local UI components efficiently
    if _G.TSMSniperBtn and _G.TSMSniperBtn:IsVisible() then
        local bottomFrame = _G.TSMSniperBtn:GetParent()
        if bottomFrame then
            -- 4. Resume Scan if Paused
            local isPaused = false
            local isConfirming = false
            local pauseBtn = nil
            for _, child in ipairs({bottomFrame:GetChildren()}) do
                local width = child:GetWidth() or 0
                if child:IsObjectType("Button") and width > 20 and width < 28 then
                    pauseBtn = child
                end
                
                -- Check regions of the child for Progress text
                if child.GetRegions then
                    for _, region in ipairs({child:GetRegions()}) do
                        if region:IsObjectType("FontString") and region:IsVisible() then
                            local t = region:GetText() or ""
                            if string.find(t, "Paused") or string.find(t, "Pause Scan") then
                                isPaused = true
                            end
                            if string.find(t, "Confirming") then
                                isConfirming = true
                            end
                        end
                    end
                end
            end
            
            -- If TSM is actively waiting on the AH to confirm the bid/buyout, do NOT click the row again (deselects it and crashes TSM)
            if isConfirming then return true end

            if isPaused and pauseBtn and pauseBtn:IsEnabled() then
                pauseBtn:Click()
                return true
            end
            
            -- 2. Select item in search box if exists
            local scanFrame = bottomFrame:GetParent()
            if scanFrame then
                local function findAndClickRow(f)
                    if not f or f:IsForbidden() then return false end
                    if f:IsObjectType("Button") and f:IsVisible() and f:IsEnabled() then
                        local w = f:GetWidth() or 0
                        local h = f:GetHeight() or 0
                        -- rows span the table (wide) and are thin
                        if w > 300 and h > 10 and h < 45 then
                            local hasText = false
                            local isActionButton = false
                            if f.GetRegions then
                                for _, r in ipairs({f:GetRegions()}) do
                                    if r:IsObjectType("FontString") and r:IsVisible() then
                                        local t = r:GetText() or ""
                                        if t ~= "" then
                                            if string.find(t, "Run Buyout") or string.find(t, "Run Bid") then
                                                isActionButton = true
                                            else
                                                hasText = true
                                            end
                                        end
                                    end
                                end
                            end
                            if hasText and not isActionButton then
                                f:Click()
                                return true
                            end
                        end
                    end
                    if f.GetNumChildren then
                        for _, child in ipairs({f:GetChildren()}) do
                            if findAndClickRow(child) then return true end
                        end
                    end
                    return false
                end
                
                if findAndClickRow(scanFrame) then
                    return true
                end
            end
        end
    end

    -- 1. run sniper scan if not runned
    local function findSniperStart(f)
        if not f or f:IsForbidden() then return false end
        if f:IsObjectType("Button") and f:IsVisible() and f:IsEnabled() then
            if f.GetRegions then
                for _, r in ipairs({f:GetRegions()}) do
                    if r:IsObjectType("FontString") and r:IsVisible() then
                        local text = r:GetText() or ""
                        if string.find(text, "Run Buyout Sniper") or string.find(text, "Run Bid Sniper") then
                            f:Click()
                            return true
                        end
                    end
                end
            end
        end
        if f.GetNumChildren then
            for _, child in ipairs({f:GetChildren()}) do
                if findSniperStart(child) then return true end
            end
        end
        return false
    end

    return findSniperStart(_G.UIParent)
end
