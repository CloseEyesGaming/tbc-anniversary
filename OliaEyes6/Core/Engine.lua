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
    self.rotationSets = jungle.RoutineConfig and jungle.RoutineConfig.definitions
    if jungle.Arena then
        jungle.Arena:Initialize()
    end
    self.initialized = true
    print("|cff00FF00[OliaEyes]|r Engine Initialized.")
end

function Engine:SetThread(threadID)
    if type(threadID) ~= "number" or threadID < 0 or threadID > 7 or threadID ~= math.floor(threadID) then return false end
    self.activeThread = threadID
    local config=jungle.RoutineConfig
    if config and config.ready then config:ResetDecisionState()
    else
        if jungle.ResetDruidEquipAttemptState then jungle.ResetDruidEquipAttemptState() end
        if jungle.ResetWarriorRoutineState then jungle.ResetWarriorRoutineState() end
        if jungle.ResetDruidRoutineState then jungle.ResetDruidRoutineState() end
        if jungle.WarriorAdaptive then jungle.WarriorAdaptive:ResetConfiguration() end
        if jungle.CurrentCast then jungle.CurrentCast.configEntry=nil end
    end
    if jungle.RoutineConfig and jungle.RoutineConfig.ready then jungle.RoutineConfig:RefreshUI() end
    return true
end

function Engine:ProcessRotation()
    if not self.initialized then self:Initialize() end
    self.pixelReset:clear()
    
    local engClass = GetPlayerClass()

    -- ==========================================
    -- GLOBAL INTERCEPTORS
    -- ==========================================
    if engClass == "DRUID" then
        local castingName = UnitCastingInfo("player")
        if castingName then
            if jungle.RaidTrace.enabled then jungle.RaidTrace.rotationState = "casting" end
            -- We pass 1 and 10 as priority bounds (safely covers our rotation sizes)
            if jungle.CurrentCastStop(castingName, 1, 10) then
                if jungle.RaidTrace.enabled then jungle.RaidTrace.rotationState = "stopcasting" end
                return jungle.Cast:CastSpell("Stopcasting", "player", 1)
            end
            -- If we are casting and shouldn't stop, we return early so we don't start a new cast
            return true 
        end
    end

    local config = jungle.RoutineConfig
    if config and config.ready then return config:Run(self) end
    return false
end

function Engine:OnUpdateProfiled(sinceLastUpdate)
    local trace = jungle.RaidTrace
    local tracing = trace.enabled and trace:BeginFrame(sinceLastUpdate)
    if not tracing and not Perf.enabled then return self:OnUpdate(sinceLastUpdate) end
    local frameStart = DebugProfileStop()
    jungle.currentTick = (jungle.currentTick or 0) + 1

    local sectionStart = DebugProfileStop()
    jungle.updateUnitsData()
    local unitsTime = DebugProfileStop() - sectionStart
    local housekeepingTime, arenaTime

    housekeepingElapsed = housekeepingElapsed + (sinceLastUpdate or 0)
    if housekeepingElapsed >= HOUSEKEEPING_INTERVAL then
        local housekeepingStart = DebugProfileStop()
        housekeepingElapsed = housekeepingElapsed - HOUSEKEEPING_INTERVAL
        local now = GetTime()
        if jungle.Los then jungle.Los:OnUpdate(now) end
        jungle.subTableTimerRemove(Controlled_Root_table, 18)
        jungle.subTableTimerRemove(Controlled_Stun_table, 18)
        jungle.subTableTimerRemove(Disorient_table, 18)
        jungle.subTableTimerRemove(Incapacitate_table, 18)
        jungle.subTableTimerRemove(Silence_table, 18)
        housekeepingTime = DebugProfileStop() - housekeepingStart
    end

    if jungle.Arena then
        local arenaStart = DebugProfileStop()
        jungle.Arena:OnUpdate()
        arenaTime = DebugProfileStop() - arenaStart
    end

    sectionStart = DebugProfileStop()
    self:ProcessRotation()
    local frameEnd = DebugProfileStop()
    local rotationTime, engineTime = frameEnd - sectionStart, frameEnd - frameStart
    if Perf.enabled then
        Perf:Record("units", unitsTime)
        if housekeepingTime then Perf:Record("housekeeping", housekeepingTime) end
        if arenaTime then Perf:Record("arena", arenaTime) end
        Perf:Record("rotation", rotationTime)
        Perf:Record("engine", engineTime)
    end
    if tracing then trace:EndFrame(engineTime, unitsTime, rotationTime, housekeepingTime, arenaTime) end
end

function Engine:OnUpdate(sinceLastUpdate)
    if Perf.enabled or jungle.RaidTrace.enabled then
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
