local AddonName, jungle = ...
jungle.RoutineAllows = jungle.RoutineAllows or function() return true end
jungle.GetRoutineThread = jungle.GetRoutineThread or function() return jungle.Engine and jungle.Engine.activeThread end

-- Independent Arms core planning with retained Original PvP utilities.
-- API/build references and model assumptions: docs/WARRIOR_ADAPTIVE.md.
local context = jungle.WarriorAdaptiveContext
local Adaptive = { state = {} }
jungle.WarriorAdaptive = Adaptive
local state = Adaptive.state
local defaultState, boundEntry = state, nil
local rows = {{'Adaptive Arms', '', false}}
local empty = {}
local gapCloser = {} -- Scratch only; no placement-owned prospective decisions.
local plates, history, seen = {}, {}, {}
local lastSample, lastSweep = -1, 0
local lastSlamSwing, sweepingGrace = 0, 0
local pendingSupport, pendingSupportGUID, supportUntil
local lastMode, lastTarget
local lastDiagnosticAt = -1
local trinketAttemptAt
local max, min = math.max, math.min
local spellNames = {'Slam', 'Mortal Strike', 'Whirlwind', 'Execute'}
local baseCosts = {['Slam']=15, ['Mortal Strike']=30, ['Whirlwind']=25,
    ['Execute']=15, ['Heroic Strike']=15, ['Cleave']=20, ['Sweeping Strikes']=30}
local spells = {}
local costRefreshAt = -1
for name, cost in pairs(baseCosts) do spells[name] = {cost=cost, cd=0, known=false} end
-- Original utility positions remain relative to the selected planned core.
local pvpCorePriority = {Slam=8, ['Mortal Strike']=12, Execute=13,
    ['Heroic Strike']=17, Cleave=17, ['Sweeping Strikes']=18, ['Victory Rush']=19, Whirlwind=20}
local pvpDisabled = {Bloodrage=true, ['Berserker Rage']=true, ['Death Wish']=true, Trinkets=true}
local fallbackWeights = {['Slam']=1.2, ['Mortal Strike']=1.25, ['Whirlwind']=1.0, ['Execute']=1.15}

local adaptiveOptionActions = {sunder_initial="Sunder Armor", sunder_stack="Sunder Armor", thunder_clap="Thunder Clap", demo="Demoralizing Shout", sweeping="Sweeping Strikes", berserker_rage="Berserker Rage", recklessness="Recklessness"}
-- Each compiled placement owns prospective decisions. Observed swing/aura facts,
-- spell costs, nameplates and enemy history remain shared and event-driven.
local function BindState()
    local entry=jungle.RoutineContext
    entry=entry and entry.state and entry or nil
    if entry==boundEntry then return end
    state._pendingSupport,state._pendingSupportGUID,state._supportUntil=pendingSupport,pendingSupportGUID,supportUntil
    state._lastSample,state._lastTarget,state._lastMode,state._trinketAttempt=lastSample,lastTarget,lastMode,trinketAttemptAt
    boundEntry=entry;state=entry and entry.state or defaultState;Adaptive.state=state
    pendingSupport,pendingSupportGUID,supportUntil=state._pendingSupport,state._pendingSupportGUID,state._supportUntil
    lastSample,lastTarget,lastMode,trinketAttemptAt=state._lastSample or -1,state._lastTarget,state._lastMode,state._trinketAttempt
end
local function InvalidateSamples(clearSupport)
    lastSample=-1
    if clearSupport then pendingSupport=nil end
    local plans=jungle.RoutineConfig and jungle.RoutineConfig.plans
    for _,plan in pairs(plans or empty) do
        for _,entry in ipairs(plan) do
            if entry.state then
                entry.state._lastSample=-1
                if clearSupport then entry.state._pendingSupport=nil end
            end
        end
    end
end
local function Option(key)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if adaptiveOptionActions[key] and not (not routineActions or routineActions[adaptiveOptionActions[key]] ~= false) then return false end
    return jungle.Options:IsEnabled('adaptive_' .. key, 'WARRIOR')
end

function Adaptive:Owns(target)
    BindState()
    if not jungle.Engine or not jungle.GetWarriorRoutineBehavior().allowsAdaptive then return false end
    local mode = jungle.Options:GetArmsPveMode()
    if mode ~= lastMode then
        pendingSupport, lastSample, lastMode, trinketAttemptAt = nil, -1, mode, nil
    end
    if mode ~= 'adaptive'
        or not context.capabilities.hasMortalStrike or context.capabilities.hasBloodthirst then return false end
    return true
end

function Adaptive:HoldPlacement()
    BindState()
    return state.ownsTick and jungle.Options:GetArmsPveMode() == 'adaptive'
        and (UnitAffectingCombat('player') or UnitCastingInfo('player') or UnitChannelInfo('player'))
end

local function IsPvp(target)
    local _, instanceType = IsInInstance()
    return instanceType == 'arena' or instanceType == 'pvp'
        or (target and UnitExists(target) and (UnitIsPlayer(target) or UnitPlayerControlled(target))) or false
end

local function Enemy(unit)
    return unit and UnitExists(unit) and UnitCanAttack('player', unit) and not UnitIsDeadOrGhost(unit)
end

local function Cooldown(name)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not (not routineActions or routineActions[name] ~= false) then return math.huge end
    local info = C_Spell.GetSpellCooldown(name)
    if not info or info.isEnabled == false then return math.huge end
    local start, duration = info.startTime or 0, info.duration or 0
    -- Matching the GCD is a guarded project heuristic, not an API guarantee.
    if state.gcdStart > 0 and math.abs(start - state.gcdStart) < 0.01
        and math.abs(duration - state.gcdDuration) < 0.01 then return 0 end
    return max(0, start + duration - state.now)
end

local function Ready(name, unit, offGCD)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not (not routineActions or routineActions[name] ~= false) then return false end
    if state.pvp and pvpDisabled[name] then return false end
    if not offGCD and state.gcd > 0.01 then return false end
    if not GetSpellBookItemInfo(name) or Cooldown(name) > 0.01 then return false end
    local usable, insufficient = C_Spell.IsSpellUsable(name)
    if usable ~= true or insufficient then return false end
    if unit and jungle.actionHasRange[name] and C_Spell.IsSpellInRange(name, unit) ~= true then return false end
    return true
end

local function Select(name, reason)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    local metadata = reason == 'pvp_utility' and state.pvpUtilityMetadata or nil
    if state.pvp then
        if pvpDisabled[name] then name, reason = nil, 'pvp_disabled' end
        local priority = name == 'Execute' and state.pvpExecutePriority or pvpCorePriority[name]
        if state.pvpUtilityAction and ((priority and state.pvpUtilityPriority < priority)
            or (not name and (reason == 'pool_rage'
                or reason == 'out_of_range'
                or ((reason == 'wait_swing' or reason == 'gcd') and state.pvpUtilityPriority <= 9)))) then
            name, reason, metadata = state.pvpUtilityAction, 'pvp_utility', state.pvpUtilityMetadata
        end
    end
    rows[1][4] = metadata
    state.action, state.reason = name, reason
    if OliaArmsLog and OliaArmsLog.enabled and state.diagnosticReady
        and (name == 'Slam' or state.now - lastDiagnosticAt >= 0.1) then
        lastDiagnosticAt = state.now
        context.recordDiagnostics({
            now=state.now, rage=state.rage, stance=state.stance, mode='adaptive_' .. (state.pvp and 'pvp_' or '') .. state.mode,
            inMelee=state.melee, gcdRemaining=state.gcd, selected=name,
            blockCoreForSlam=reason == 'wait_swing', useSlamWindow=name == 'Slam',
            slamRecommended=name == 'Slam', slamRageThreshold=spells.Slam.cost,
            slamBlocker=name ~= 'Slam' and reason or nil,
            core={
                ['Mortal Strike']={due=state.melee and spells['Mortal Strike'].cd == 0, ready=Ready('Mortal Strike', state.target, true)},
                ['Whirlwind']={due=state.melee and not state.unsafeAoE and spells.Whirlwind.cd == 0, ready=Ready('Whirlwind', nil, true)},
                ['Sweeping Strikes']={due=state.aoe and Option('sweeping') and not state.sweeping and spells['Sweeping Strikes'].cd == 0,
                    ready=Ready('Sweeping Strikes', nil, true)},
            },
        })
    end
    if jungle.RaidTrace.enabled then
        jungle.RaidTrace.rotationState = 'adaptive_' .. (state.pvp and 'pvp_' or '') .. state.mode .. '_' .. reason
    end
    if not name then return empty end
    rows[1][1], rows[1][2], rows[1][3] = 'Adaptive ' .. reason, name, (not routineActions or routineActions[name] ~= false)
    return rows
end

local function Life(unit)
    local guid = UnitGUID(unit)
    if not guid then return nil end
    local hp = UnitHealth(unit)
    local entry = history[guid]
    if not entry then
        entry = {hp=hp, startHP=hp, start=state.now, at=state.now}
        history[guid] = entry
    end
    local elapsed = state.now - entry.start
    if hp > entry.hp or elapsed > 8 then
        entry.start, entry.startHP = entry.at, entry.hp
        elapsed = state.now - entry.start
    end
    if state.now - entry.at >= 0.1 then
        entry.hp, entry.at = hp, state.now
        local loss = entry.startHP - hp
        entry.ttd = elapsed >= 1.5 and loss > 0 and min(300, hp * elapsed / loss) or nil
    end
    entry.seen = state.now
    return entry.ttd
end

local function Observe(unit)
    if not Enemy(unit) then return end
    local guid = UnitGUID(unit)
    local controlled = UnitIsPlayer(unit) or UnitPlayerControlled(unit)
    if state.pvp then
        -- Count players/pets, plus an ordinary NPC only when it is selected.
        if not controlled and guid ~= state.guid then return end
    elseif controlled then return end
    if not guid or seen[guid] then return end
    seen[guid] = true
    local life = Life(unit)
    -- Conservative melee coverage. This does NOT claim an exact 8-yard WW count.
    if C_Spell.IsSpellInRange('Hamstring', unit) ~= true then return end
    if jungle.IsTotemUnit(unit) then return end
    if not jungle.IsEnemyNameplateEligibleForAoE(unit) then
        state.unsafeAoE = true
        return
    end
    state.enemies = state.enemies + 1
    if not life or life > 1.5 then state.durableEnemies = state.durableEnemies + 1 end
    if life then state.packLife = max(state.packLife or 0, life) else state.packUnknown = true end
end

local function ObserveEnemies(target)
    local guid = target and UnitGUID(target)
    if state.now - lastSample < 0.1 and guid == lastTarget and state.samplePvp == state.pvp then return end
    lastSample, lastTarget, state.samplePvp = state.now, guid, state.pvp
    for key in pairs(seen) do seen[key] = nil end
    state.enemies, state.durableEnemies = 0, 0
    state.unsafeAoE, state.packUnknown, state.packLife = false, false, nil
    if target then Observe(target) end
    for unit in pairs(plates) do Observe(unit) end
    if state.packUnknown then state.packLife = nil end
    if state.now - lastSweep > 5 then
        lastSweep = state.now
        for guid, entry in pairs(history) do
            if state.now - (entry.seen or 0) > 10 then history[guid] = nil end
        end
    end
end

local function RefreshSpells()
    for name, spell in pairs(spells) do
        spell.known = GetSpellBookItemInfo(name) ~= nil
        spell.cd = spell.known and Cooldown(name) or math.huge
        if spell.known and state.now >= costRefreshAt then
            local costs = C_Spell.GetSpellPowerCost(name)
            for _, cost in ipairs(costs or empty) do
                if cost.type == 1 and (not cost.requiredAuraID or cost.requiredAuraID == 0 or cost.hasRequiredAura) then
                    spell.cost = max(0, name == 'Execute' and cost.minCost or cost.cost)
                    break
                end
            end
        end
    end
    if state.now >= costRefreshAt then costRefreshAt = state.now + 0.2 end
end

-- Two-action lookahead in normalized weapon-damage units. These weights are
-- explicit heuristics, not simulated/guaranteed damage or a kill prediction.
local function Value(name, rage, at)
    if state.life and at >= state.life then return 0 end
    local value = fallbackWeights[name]
    if name == 'Whirlwind' then
        local coverage = at >= 1.5 and min(state.enemies, max(1, state.durableEnemies)) or state.enemies
        value = value * min(coverage, 4)
    end
    if name == 'Execute' then
        value = value + min(1.4, max(0, rage - spells.Execute.cost) * 0.02)
    end
    if state.sweeping and state.aoe then value = value * 1.65 end
    return value
end

local function Allowed(name, at, rage, swing, previous)
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    if not (not routineActions or routineActions[name] ~= false) then return false end
    local spell = spells[name]
    if not spell.known or spell.cd > at or rage < spell.cost then return false end
    if name == 'Mortal Strike' and previous == name then return false end
    if name == 'Whirlwind' then
        return previous ~= name and state.stance == 3 and state.enemies > 0 and not state.unsafeAoE
    end
    if name == 'Execute' then
        -- Preserve sustained core attacks; unload at the end of target lifetime.
        return state.execute and (state.dying or
            ((previous == 'Mortal Strike' or spells['Mortal Strike'].cd > at + 1.5)
            and (previous == 'Whirlwind' or spells.Whirlwind.cd > at + 1.5)))
    end
    if name == 'Slam' then
        if not state.canSlam or state.moving then return false end
        if previous == 'Slam' and at < swing then return false end
        local since = at >= swing and at - swing or state.sinceSwing + at
        local pending = at >= swing or state.pendingSlam
        return pending and since >= 0 and since + state.inputMargin <= 1.15
            and (not state.life or state.life > at + state.castTime + state.inputMargin)
    end
    return true
end

local function Plan()
    local bestName, bestScore, bestReserve = nil, -math.huge, 0
    local firstDelay = 0
    -- Consider a short wait only for an actual imminent swing. No speculative
    -- indefinite ownership; movement/unreliable timing disables the wait candidate.
    local wait = state.canSlam and not state.moving and state.swing <= 0.30 and state.swing > 0.02
        and state.swing or nil
    for pass = 1, (wait and 2 or 1) do
        local at = pass == 2 and wait or 0
        for _, name in ipairs(spellNames) do
            -- Reserve an existing next-swing payment even when it lands after this GCD.
            local rage = max(0, state.rage - state.queuedCost)
            if at >= state.swing then rage = min(100, rage + state.swingIncome) end
            if Allowed(name, at, rage, state.swing) and (pass == 2 or Ready(name, name ~= 'Whirlwind' and state.target or nil)) then
                local spent = name == 'Execute' and rage or spells[name].cost
                local nextRage = rage - spent
                local nextSwing = name == 'Slam' and (at + state.castTime + state.speed) or state.swing
                local nextAt = at + 1.5
                local firstValue = Value(name, rage, at)
                local swingLoss = name == 'Slam' and max(0, nextSwing - state.swing) / state.speed or 0
                if nextSwing > at and nextSwing <= nextAt then
                    nextRage = min(100, nextRage + state.swingIncome)
                end
                nextRage = max(0, nextRage)
                local nextValue, reserve = 0, 0
                for _, nextName in ipairs(spellNames) do
                    if Allowed(nextName, nextAt, nextRage, nextSwing, name) then
                        local value = Value(nextName, nextRage, nextAt)
                        if nextName == 'Slam' then
                            value = value - max(0, nextAt + state.castTime + state.speed - nextSwing) / state.speed
                        end
                        if value > nextValue then nextValue, reserve = value, spells[nextName].cost end
                    end
                end
                -- Keep the future resource value when nothing fits the next GCD.
                -- The value vanishes at the end of a short target's lifetime.
                local resourceValue = state.dying and 0 or min(nextRage, 45) * 0.012
                local score = firstValue + 0.8 * nextValue + resourceValue - swingLoss - at * 0.6
                if score > bestScore then
                    bestName, bestScore, bestReserve, firstDelay = name, score, reserve, at
                end
            end
        end
    end
    state.planScore, state.planReserve = bestScore, bestReserve
    if firstDelay > 0 then return nil, 'wait_swing' end
    return bestName, bestName and 'damage' or 'pool_rage'
end

local function Support()
    if not state.target or not state.melee or not context.canDebuff(state.target) then return end
    local durable = state.boss or (state.life and state.life >= 12)
    local sunder, stacks, expose = context.armorDebuff(state.target)
    if expose <= 0 then
        if Option('sunder_initial') and stacks == 0 and durable and Ready('Sunder Armor', state.target) then
            return 'Sunder Armor', 'assigned_initial_sunder'
        end
        if Option('sunder_stack') and stacks > 0 and Ready('Sunder Armor', state.target)
            and ((sunder <= 3 and (not state.life or state.life > sunder))
                or (stacks < 5 and durable and not state.pendingSlam)) then
            return 'Sunder Armor', 'assigned_sunder'
        end
    end
    if Option('thunder_clap') and not state.unsafeAoE and (durable or state.aoe)
        and context.debuffRemaining(state.target, 'Thunder Clap') <= 3 then
        if state.stance == 1 and Ready('Thunder Clap') then return 'Thunder Clap', 'assigned_thunder_clap' end
        if state.stance ~= 1 and state.rage <= 25 and Ready('Battle Stance', nil, true)
            and Cooldown('Thunder Clap') == 0 and not state.pendingSlam then
            return 'Battle Stance', 'prepare_thunder_clap'
        end
    end
    -- Enabled Demo applies to ordinary NPCs immediately; lifetime sampling is not eligibility.
    -- Only a currently usable stationary Slam protects its pending swing window.
    if Option('demo') and not state.unsafeAoE
        and not context.hasOtherAttackPowerDebuff(state.target)
        and context.debuffRemaining(state.target, 'Demoralizing Shout') <= 5
        and Ready('Demoralizing Shout')
        and not (state.pendingSlam and state.canSlam and not state.moving
            and Ready('Slam', state.target)) then return 'Demoralizing Shout', 'assigned_demo' end
end

function Adaptive:Evaluate(target)
    BindState()
    local routineActions = jungle.RoutineContext and not jungle.RoutineContext.allEnabled and jungle.RoutineContext.actions
    rows[1][3] = false
    state.now, state.action, state.reason = GetTime(), nil, nil
    state.ownsTick, state.diagnosticReady = true, false
    state.gcdStart, state.gcdDuration = jungle.GetGCDValues()
    state.gcd = max(0, state.gcdStart + state.gcdDuration - state.now)
    state.rage, state.stance = UnitPower('player', 1), GetShapeshiftForm()
    state.mode = 'single'
    state.target = Enemy(target) and target or nil
    local pvp = IsPvp(state.target)
    if pvp ~= state.pvp then pendingSupport, lastSample, trinketAttemptAt = nil, -1, nil end
    state.pvp = pvp
    state.pvpUtilityAction, state.pvpUtilityPriority, state.pvpUtilityMetadata = nil, nil, nil
    state.pvpExecutePriority = 13
    if UnitIsDeadOrGhost('player') then return Select(nil, 'inactive') end
    if IsMounted() then
        -- Mounted travel permits only an eligible gap closer and its stance preparation.
        -- Use the same readiness as the corresponding Original Arms branch.
        if UnitCastingInfo('player') or UnitChannelInfo('player') then return Select(nil, 'casting') end
        if state.target then
            context.gapCloser(state.target, state.pvp and jungle.ReadyCastSpell or nil, gapCloser)
            if gapCloser.useCharge then return Select('Charge', 'charge') end
            if gapCloser.useBattleStanceForCharge then return Select('Battle Stance', 'charge_stance') end
            if gapCloser.useIntercept then return Select('Intercept', 'intercept') end
            if gapCloser.useBerserkerStanceForIntercept then return Select('Berserker Stance', 'intercept_stance') end
        end
        return Select(nil, 'inactive')
    end
    if state.pvp and state.target then
        local utilities, lethal = context.pvpUtilities(state.target)
        state.pvpExecutePriority = lethal and 11 or 13
        for i = 1, #utilities do
            local row = utilities[i]
            if row[3] then
                state.pvpUtilityAction, state.pvpUtilityPriority, state.pvpUtilityMetadata = row[2], i, row[4]
                break
            end
        end
        -- Demo is a spare-global fallback after all core actions, before Sunder/shout.
        if (not state.pvpUtilityPriority or state.pvpUtilityPriority > 20.5)
            and context.pvpDemo(state.target) then
            state.pvpUtilityAction, state.pvpUtilityPriority, state.pvpUtilityMetadata = "Demoralizing Shout", 20.5, nil
        end
        -- Interrupt/cancel-Slam and gap closers precede casting/equipment guards.
        -- Slows compete at their original positions, below an immediate Slam.
        if state.pvpUtilityPriority and state.pvpUtilityPriority <= 7 then
            return Select(state.pvpUtilityAction, 'pvp_utility')
        end
    end
    if UnitCastingInfo('player') or UnitChannelInfo('player') then return Select(nil, 'casting') end
    if not context.hasTwoHand() then
        if not (not routineActions or routineActions["Equip2H"] ~= false) then state.ownsTick = false; return empty end
        if jungle.CanSwapWeapons() then return Select('Equip2H', 'equipment') end
        return Select(nil, 'equipment_gcd')
    end
    state.target = Enemy(target) and target or nil
    state.guid = state.target and UnitGUID(state.target)
    state.melee = state.target and jungle.inMeleeRange(state.target)
    ObserveEnemies(state.target)
    state.aoe = state.enemies >= 2 and not state.unsafeAoE
    state.boss = state.target and (UnitClassification(state.target) == 'worldboss' or UnitLevel(state.target) == -1) or false
    for i = 1, 5 do
        if state.target and UnitExists('boss' .. i) and UnitIsUnit('boss' .. i, state.target) then state.boss = true end
    end
    state.mode = state.aoe and 'aoe' or (state.boss and 'boss' or 'single')
    state.life = state.target and Life(state.target) or nil
    state.dying = state.life and state.life <= 3 or false
    local maxHP = state.target and UnitHealthMax(state.target) or 0
    state.execute = (not routineActions or routineActions["Execute"] ~= false) and maxHP > 0 and UnitHealth(state.target) / maxHP < 0.2
    local inCombat = UnitAffectingCombat('player')
    if state.target then context.markDiagnostics(state.target, inCombat) end
    -- Keep self maintenance available without inventing an enemy.
    local shout, needsShout = jungle.GetWarriorDpsShout(state.pvp and 5 or 3)
    if not state.target then
        if needsShout and Ready(shout) then return Select(shout, 'shout') end
        return Select(nil, 'no_enemy')
    end
    if not state.melee then
        if not state.pvp then
            -- PvP already consumes this helper through the Original utility projection.
            -- Match Original Arms PvE readiness, stance preparation and re-engagement rules.
            context.gapCloser(state.target, nil, gapCloser)
            if gapCloser.useCharge then return Select('Charge', 'charge') end
            if gapCloser.useBattleStanceForCharge then return Select('Battle Stance', 'charge_stance') end
            if gapCloser.useIntercept then return Select('Intercept', 'intercept') end
            if gapCloser.useBerserkerStanceForIntercept then return Select('Berserker Stance', 'intercept_stance') end
        end
        if not state.pvp and needsShout and Ready(shout) then return Select(shout, 'shout') end
        return Select(nil, 'out_of_range')
    end
    if not state.pvp and (not routineActions or routineActions["Attack"] ~= false) and not C_Spell.IsCurrentSpell(6603) then return Select('Attack', 'start_attack') end
    if not state.pvp and (not routineActions or routineActions["Pummel"] ~= false) and jungle.checkPveInterrupt(state.target) then
        if state.stance == 3 and Ready('Pummel', state.target, true) then return Select('Pummel', 'interrupt') end
        if state.stance ~= 3 and Cooldown('Pummel') == 0 and Ready('Berserker Stance', nil, true) then
            return Select('Berserker Stance', 'interrupt_stance')
        end
    end
    if pendingSupport and (state.guid ~= pendingSupportGUID or state.now > supportUntil or not Option('thunder_clap')) then
        pendingSupport = nil
    end
    if pendingSupport and state.stance == 1 then
        if context.debuffRemaining(state.target, 'Thunder Clap') > 3 then pendingSupport = nil
        elseif Ready('Thunder Clap') then return Select('Thunder Clap', 'assigned_thunder_clap')
        else return Select(nil, 'support_gcd') end
    end
    local hs, cleave = C_Spell.IsCurrentSpell('Heroic Strike'), C_Spell.IsCurrentSpell('Cleave')
    RefreshSpells()
    state.queuedCost = cleave and spells.Cleave.cost or (hs and spells['Heroic Strike'].cost or 0)
    state.speed = max(0.5, UnitAttackSpeed('player') or 3.5)
    local tracker = jungle.SwingTimer
    local reliable = tracker:IsMainhandTimingReliable()
    state.swing = reliable and tracker:GetMainhandTimeRemaining() or math.huge
    local lastSwing = tracker:GetLastConfirmedMainhandSwingTime() or 0
    state.sinceSwing = lastSwing > 0 and state.now - lastSwing or math.huge
    state.pendingSlam = (not routineActions or routineActions['Slam'] ~= false) and reliable and lastSwing > lastSlamSwing and state.sinceSwing <= 1.15
        and tracker:GetLastConfirmedMainhandSwingTargetGUID() == state.guid
    state.moving = (GetUnitSpeed('player') or 0) > 0.1
    state.canSlam = (not routineActions or routineActions['Slam'] ~= false) and context.canSlam() and reliable
    local info = C_Spell.GetSpellInfo('Slam')
    state.castTime = info and info.castTime and info.castTime > 0 and info.castTime / 1000 or 0.5
    local _, _, home, world = GetNetStats()
    state.inputMargin = max(0.05, (world or home or 0) / 1000)
    -- Future income is deliberately conservative; a queued replacement produces none.
    state.swingIncome = (hs or cleave) and 0 or 10
    state.sweeping = jungle.unitCacheBuff('player', 'Sweeping Strikes') or state.now < sweepingGrace
    state.diagnosticReady = true
    local queueReserve = state.pendingSlam and not state.moving and spells.Slam.cost or 0
    if spells['Mortal Strike'].cd <= 1.5 then queueReserve = max(queueReserve, spells['Mortal Strike'].cost) end
    if spells.Whirlwind.cd <= 1.5 then queueReserve = max(queueReserve, spells.Whirlwind.cost) end
    if (hs or cleave) and ((cleave and not state.aoe) or (hs and state.aoe)
        or state.rage < state.queuedCost + queueReserve
        or state.dying) then return Select('Stopcasting', 'cancel_queue') end
    if not state.pvp and (not routineActions or routineActions['Overpower'] ~= false) and not state.aoe and not pendingSupport and context.overpower(state.guid)
        and not (state.pendingSlam and not state.moving and state.rage >= spells.Slam.cost)
        and spells.Whirlwind.cd > 1.5 then
        if state.stance == 1 and Ready('Overpower', state.target) then return Select('Overpower', 'dodge_proc') end
        if state.stance == 3 and state.rage >= 5 and state.rage <= 10
            and GetSpellBookItemInfo('Overpower') and Cooldown('Overpower') == 0
            and Ready('Battle Stance', nil, true) then return Select('Battle Stance', 'overpower_stance') end
    end
    if not state.pvp and state.stance ~= 3 and not pendingSupport then
        if Ready('Berserker Stance', nil, true) then return Select('Berserker Stance', 'damage_stance') end
    end
    if not state.pvp and inCombat and state.rage < 70 and Ready('Bloodrage', nil, true) then return Select('Bloodrage', 'rage') end
    if not state.pvp and needsShout and Ready(shout) and (not state.pendingSlam or not jungle.unitCacheBuff('player', shout)) then
        return Select(shout, 'shout')
    end
    local support, supportReason
    if not state.pvp then support, supportReason = Support() end
    if support then
        if supportReason == 'prepare_thunder_clap' then
            pendingSupport, pendingSupportGUID, supportUntil = true, state.guid, state.now + 3
        end
        return Select(support, supportReason)
    end
    local burstLife = state.aoe and state.packLife or state.life
    local shortPack = state.aoe and burstLife and burstLife < 5
    -- A cheap short-pack activation is useful only when an imminent white hit
    -- can actually consume it before the pack dies. Otherwise fund WW as well.
    local cheapSweeping = shortPack and reliable and state.swing <= 0.5
        and burstLife > state.swing + state.inputMargin
    if state.aoe and Option('sweeping') and not state.sweeping and spells['Sweeping Strikes'].known
        and state.rage >= spells['Sweeping Strikes'].cost + ((cheapSweeping or not (not routineActions or routineActions["Whirlwind"] ~= false)) and 0 or spells.Whirlwind.cost)
        and (not burstLife or burstLife > state.inputMargin + 0.5)
        and Ready('Sweeping Strikes', nil, true) then return Select('Sweeping Strikes', 'cleave_burst') end
    local burstWindow = not state.pvp and inCombat and (not burstLife or burstLife > 4 or shortPack)
    if burstWindow and Option('cooldowns') and Ready('Death Wish') and state.rage >= 40 then
        return Select('Death Wish', 'cooldown')
    end
    local useTrinkets = (state.aoe and Option('aoe_trinkets')) or (not state.aoe and Option('cooldowns'))
    if (not routineActions or routineActions["Trinkets"] ~= false) and burstWindow and useTrinkets then
        if jungle.AreTrinketsReady() then
            -- Intent is not success. Bound an unusable item's ability to occupy
            -- this priority, while retaining a full second of action dwell.
            if not trinketAttemptAt or state.now - trinketAttemptAt >= 5 then trinketAttemptAt = state.now end
            if state.now - trinketAttemptAt <= 1 then return Select('Trinkets', 'cooldown') end
        else trinketAttemptAt = nil end
    end
    if not state.pvp and inCombat and Option('recklessness') and state.boss and state.stance == 3
        and (jungle.unitCacheBuff('player', 'Bloodlust') or jungle.unitCacheBuff('player', 'Heroism')
            or (state.life and state.life <= 15)) and Ready('Recklessness') then
        return Select('Recklessness', 'boss_cooldown')
    end
    local selected, reason
    if state.gcd <= 0.01 then selected, reason = Plan() else reason = 'gcd' end
    -- Queue management is off-GCD, but never consumes a funded immediate Slam window.
    local queue = state.aoe and 'Cleave' or 'Heroic Strike'
    local coreReserve = selected and spells[selected].cost or
        (spells['Mortal Strike'].cd <= 1.5 and spells['Mortal Strike'].cost or 0)
    if selected == 'Execute' then coreReserve = state.rage end
    if state.aoe and spells.Whirlwind.cd <= state.swing + 1.5 then coreReserve = max(coreReserve, spells.Whirlwind.cost) end
    local followupReserve = selected and max(0, (state.planReserve or 0) - 10) or 0
    local budget = spells[queue].cost + coreReserve + followupReserve
        + (state.pendingSlam and spells.Slam.cost or 0)
    if not hs and not cleave and not state.dying and selected ~= 'Slam'
        and reliable and state.swing <= 0.6 and state.rage >= budget
        and (state.rage >= budget + 10 or state.rage >= 90) and Ready(queue, state.target, true) then
        return Select(queue, 'funded_queue')
    end
    if selected then return Select(selected, reason) end
    if state.pvp and reason ~= 'wait_swing' and Ready('Victory Rush', state.target) then
        return Select('Victory Rush', 'free_filler')
    end
    if not state.pvp and reason ~= 'wait_swing' and not state.pendingSlam and Ready('Victory Rush', state.target) then
        return Select('Victory Rush', 'free_filler')
    end
    -- TBC Berserker Rage spends a global. Reserve the next Slam swing and
    -- affordable core cooldowns; unknown swing timing cannot certify a safe gap.
    local utilityWindow = 1.5 + state.inputMargin
    local slamGap = not (not routineActions or routineActions["Slam"] ~= false) or state.moving or not context.canSlam()
        or (reliable and not state.pendingSlam and state.swing > utilityWindow)
    local coreGap = (not spells['Mortal Strike'].known or state.rage < spells['Mortal Strike'].cost
            or spells['Mortal Strike'].cd > utilityWindow)
        and (state.unsafeAoE or not spells.Whirlwind.known or state.rage < spells.Whirlwind.cost
            or spells.Whirlwind.cd > utilityWindow)
    if not state.pvp and inCombat and Option('berserker_rage') and state.stance == 3 and reason ~= 'wait_swing'
        and slamGap and coreGap and not jungle.unitCacheBuff('player', 'Berserker Rage')
        and Ready('Berserker Rage') then
        return Select('Berserker Rage', 'utility_gap')
    end
    return Select(nil, reason)
end

local events = CreateFrame('Frame')
for _, event in ipairs({'PLAYER_ENTERING_WORLD', 'NAME_PLATE_UNIT_ADDED', 'NAME_PLATE_UNIT_REMOVED',
    'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_SUCCEEDED', 'PLAYER_REGEN_ENABLED'}) do events:RegisterEvent(event) end
events:SetScript('OnEvent', function(_, event, unit, _, spellID)
    if event == 'NAME_PLATE_UNIT_ADDED' then plates[unit]=true;InvalidateSamples()
    elseif event == 'NAME_PLATE_UNIT_REMOVED' then plates[unit]=nil;InvalidateSamples()
    elseif event == 'PLAYER_ENTERING_WORLD' then
        for key in pairs(plates) do plates[key] = nil end
        -- Bootstrap verified unit tokens after /reload; never infer identity from frame-array position.
        for i = 1, 40 do local token = 'nameplate' .. i; if UnitExists(token) then plates[token] = true end end
        InvalidateSamples()
    elseif event == 'PLAYER_REGEN_ENABLED' then
        for key in pairs(history) do history[key] = nil end
        InvalidateSamples(true)
    elseif unit == 'player' and spellID then
        local info = C_Spell.GetSpellInfo(spellID)
        local name = info and info.name
        if name == 'Slam' then lastSlamSwing = jungle.SwingTimer:GetLastConfirmedMainhandSwingTime() or 0 end
        if event == 'UNIT_SPELLCAST_SUCCEEDED' and name == 'Sweeping Strikes' then sweepingGrace = GetTime() + 0.6 end
        if event == 'UNIT_SPELLCAST_SUCCEEDED' and name == 'Thunder Clap' then
            local owner=jungle.GetRoutineEntry and jungle.GetRoutineEntry()
            if owner and owner.state then
                owner.state._pendingSupport=nil
                if owner==boundEntry then pendingSupport=nil end
            else pendingSupport=nil end
        end
    end
end)
jungle.SwingTimer:RegisterResetCallback(function() lastSlamSwing = 0 end)
jungle.SwingTimer:RegisterSlamCompletionCallback(function()
    lastSlamSwing = jungle.SwingTimer:GetLastConfirmedMainhandSwingTime() or 0
end)

-- An independently registered algorithm. Ineligible contexts release this
-- placement; only the explicit thread list can select another placement.
-- On-demand only: report saved/compiled switches and the last actual decision.
-- Never call an evaluator or emit an action from a diagnostic command.
function Adaptive:PrintDemoDiagnostics()
    local config=jungle.RoutineConfig
    local thread=jungle.Engine and jungle.Engine.activeThread or 0
    local plan=config and config.plans[thread]
    local found=false
    for _,entry in ipairs(plan or empty) do
        if entry.definition.mode=='adaptive' then
            found=true
            local saved=config:GetEntry(entry.thread,entry.index)
            local savedOption=saved and type(saved.options)=='table' and saved.options.adaptive_demo
            local current=entry.state
            print('[Olia Demo profile-import-1] thread='..thread..' placement='..entry.index
                ..' action='..tostring(entry.actions['Demoralizing Shout'])
                ..' option='..tostring(entry.options.adaptive_demo)
                ..' savedOption='..tostring(savedOption)..' pending='..tostring(config.pending==true))
            print('[Olia Demo] selected='..tostring(current.action)..' reason='..tostring(current.reason)
                ..' PvP='..tostring(current.pvp)..' melee='..tostring(current.melee)
                ..' rage='..tostring(current.rage)..' GCD='..tostring(current.gcd)
                ..' age='..(current.now and string.format('%.2f',GetTime()-current.now) or 'unevaluated'))
        end
    end
    if not found then print('[Olia Demo profile-import-1] No compiled Adaptive placement on active thread '..thread) end
end

function jungle.warriorAdaptive(target)
    if Adaptive:Owns(target) then return Adaptive:Evaluate(target) end
    BindState()
    state.ownsTick = false
    return empty
end

function Adaptive:ResetConfiguration()
    boundEntry=nil;state=defaultState;Adaptive.state=state
    pendingSupport, pendingSupportGUID, supportUntil = nil, nil, nil
    lastSample, lastMode, trinketAttemptAt = -1, nil, nil
    state.ownsTick, state.pendingSlam = false, false
end
