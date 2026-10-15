local AddonName, jungle = ...

-- Independent PvE DW Arms policy. Model/build evidence: docs/WARRIOR_KEBAB.md.
-- This bridge contains utility observations only; no other damage evaluator runs.
local utility = jungle.WarriorAdaptiveContext
local Kebab = {}
jungle.WarriorKebab = Kebab
local empty, plates, seen, gap = {}, {}, {}, {}
local idleState = {}
-- Queue observations are shared facts; decision resets never manufacture removal.
local observedHS, observedCleave = false, false
local CANCEL_LEAD, QUEUE_OPEN = 0.6, 0.9
local rows = {
    {'Cancel obsolete queue', 'Stopcasting', false},
    {'Start autoattack', 'Attack', false},
    {'Interrupt stance', 'Berserker Stance', false},
    {'Interrupt', 'Pummel', false},
    {'Charge stance', 'Battle Stance', false},
    {'Charge', 'Charge', false},
    {'Intercept stance', 'Berserker Stance', false},
    {'Intercept', 'Intercept', false},
    {'Damage stance', 'Berserker Stance', false},
    {'Proactive Bloodrage', 'Bloodrage', false},
    {'Battle Shout', 'Battle Shout', false},
    {'Commanding Shout', 'Commanding Shout', false},
    {'Assigned Sunder', 'Sunder Armor', false},
    {'Assigned Demo', 'Demoralizing Shout', false},
    {'Death Wish', 'Death Wish', false},
    {'Recklessness', 'Recklessness', false},
    {'On-use trinkets', 'Trinkets', false},
    {'Funded / MH-window Heroic Strike', 'Heroic Strike', false},
    {'Mortal Strike', 'Mortal Strike', false},
    {'Whirlwind', 'Whirlwind', false},
    {'Execute', 'Execute', false},
    {'Funded Hamstring filler', 'Hamstring', false},
    {'Free Victory Rush', 'Victory Rush', false},
    {'Spare Berserker Rage', 'Berserker Rage', false},
    {'Funded Sweeping Strikes', 'Sweeping Strikes', false},
    {'Funded AoE Cleave', 'Cleave', false},
}
local costs = {['Mortal Strike']=30, Whirlwind=25, Execute=15, ['Sweeping Strikes']=30,
    ['Heroic Strike']=15, Cleave=20, Hamstring=10, ['Sunder Armor']=15,
    ['Demoralizing Shout']=10, ['Battle Shout']=10, ['Commanding Shout']=10, ['Death Wish']=10}
local costAt = -1
local state = idleState
local function Allows(name) return jungle.RoutineAllows(name) end
local function Option(key) return jungle.RoutineOption(key) == true end
local function Enemy(unit)
    return unit and UnitExists(unit) and UnitCanAttack('player', unit) and not UnitIsDeadOrGhost(unit)
end
local function Cooldown(name)
    if not Allows(name) or not GetSpellBookItemInfo(name) then return math.huge end
    local info = C_Spell.GetSpellCooldown(name)
    if not info or info.isEnabled == false then return math.huge end
    local start, duration = info.startTime or 0, info.duration or 0
    -- Matching the GCD is a guarded project heuristic, not an API contract.
    if state.gcdStart > 0 and math.abs(start-state.gcdStart)<0.01
        and math.abs(duration-state.gcdDuration)<0.01 then return 0 end
    return math.max(0, start+duration-state.now)
end
local function Ready(name, target, offGCD)
    if not offGCD and state.gcd > 0.01 then return false end
    if Cooldown(name)>0.01 then return false end
    local usable, short = C_Spell.IsSpellUsable(name)
    if usable ~= true or short then return false end
    if target and jungle.actionHasRange[name] and C_Spell.IsSpellInRange(name,target) ~= true then return false end
    return true
end
local function Select(index, reason)
    state.action, state.reason = index and rows[index][2] or nil, reason
    if index then rows[index][3] = Allows(rows[index][2]) end
    if jungle.RaidTrace and jungle.RaidTrace.enabled then jungle.RaidTrace.rotationState = 'kebab_'..reason end
    return index and rows or empty
end
local function Release(reason)
    if not state.casting and (observedHS and C_Spell.IsCurrentSpell('Heroic Strike')
        or observedCleave and C_Spell.IsCurrentSpell('Cleave')) then
        state.cancelCycle = state.queueCycle
        return Select(1,'cancel_queue_'..reason)
    end
    return Select(nil,reason)
end
local function RefreshCosts()
    if state.now < costAt then return end
    costAt = state.now + 0.2
    for name in pairs(costs) do
        local records = C_Spell.GetSpellPowerCost(name)
        for _, cost in ipairs(records or empty) do
            if cost.type == 1 and (not cost.requiredAuraID or cost.requiredAuraID == 0 or cost.hasRequiredAura) then
                costs[name] = math.max(0, name=='Execute' and cost.minCost or cost.cost)
                break
            end
        end
    end
end
local function Observe(unit)
    if not Enemy(unit) or UnitIsPlayer(unit) or UnitPlayerControlled(unit) then return end
    local guid = UnitGUID(unit)
    if not guid or seen[guid] or C_Spell.IsSpellInRange('Hamstring',unit) ~= true or jungle.IsTotemUnit(unit) then return end
    seen[guid] = true
    if jungle.IsEnemyNameplateEligibleForAoE(unit) then state.enemies=state.enemies+1
    else
        state.unsafeArea=true
        -- Immunity-only exclusions reduce the AoE count but do not veto WW.
        -- Control, including control combined with immunity, still protects it.
        if not jungle.IsEnemyNameplateEligibleForAoE(unit,true) then state.unsafeWW=true end
    end
end
local function ObserveEnemies(target)
    for key in pairs(seen) do seen[key]=nil end
    state.enemies, state.unsafeArea, state.unsafeWW = 0, false, false
    Observe(target)
    for unit in pairs(plates) do Observe(unit) end
end
local function NextCoreReserve(horizon)
    local ms, ww = state.msCD, state.wwCD
    if state.aoe and ww < math.huge and ww <= horizon then return costs.Whirlwind end
    if ms < math.huge and ms <= ww and ms <= horizon then return costs['Mortal Strike'] end
    if ww < math.huge and ww <= horizon then return costs.Whirlwind end
    return 0
end

-- Reserve independently by cooldown, including both ready/closely due cores.
-- A shared GCD must not push the second core out of the funding window.
local function UpcomingCoreReserve(horizon)
    local ms, ww = state.msCD, state.wwCD
    local reserve=0
    if ms<math.huge and ms<=horizon then reserve=reserve+costs['Mortal Strike'] end
    if ww<math.huge and ww<=horizon then reserve=reserve+costs.Whirlwind end
    return reserve
end

function jungle.warriorKebab(target)
    local entry = jungle.RoutineContext
    state = entry and entry.state or idleState
    for i=1,#rows do rows[i][3]=false end
    state.eligible, state.action, state.reason, state.aoe = false, nil, nil, false
    state.optionalReserve,state.utilityGap=nil,nil
    state.now, state.rage = GetTime(), UnitPower('player',1)
    state.gcdStart, state.gcdDuration = jungle.GetGCDValues()
    state.gcdStart, state.gcdDuration = state.gcdStart or 0, state.gcdDuration or 0
    state.gcd = math.max(0,state.gcdStart+state.gcdDuration-state.now)
    if not entry or entry.definition.id ~= 'warrior.kebab' then return Select(nil,'ineligible') end
    local queueObserved = C_Spell.IsCurrentSpell('Heroic Strike')
    observedCleave = C_Spell.IsCurrentSpell('Cleave') and true or false
    observedHS = queueObserved and true or false
    -- Stopcasting also stops a cast/channel: never use queue cleanup during one.
    state.casting = UnitCastingInfo('player') or UnitChannelInfo('player')
    local _, instance = IsInInstance()
    local mainhand, offhand = UnitAttackSpeed('player')
    if not offhand or utility.hasTwoHand()
        or not GetSpellBookItemInfo('Mortal Strike') or GetSpellBookItemInfo('Bloodthirst')
        or UnitIsDeadOrGhost('player') or IsMounted() or instance=='pvp' or instance=='arena'
        or (target and UnitExists(target) and (UnitIsPlayer(target) or UnitPlayerControlled(target))) then
        return Release('ineligible')
    end
    local hasEnemy = Enemy(target) and not jungle.IsTotemUnit(target)
    if not hasEnemy then target=nil end
    state.target = target
    if not target then
        if observedHS or observedCleave then return Release('no_enemy') end
        if state.casting then return Select(nil,'casting') end
        local shout, needs = jungle.GetWarriorDpsShout(5)
        if needs and Ready(shout) then return Select(shout=='Commanding Shout' and 12 or 11,'shout') end
        return Select(nil,'no_enemy')
    end
    ObserveEnemies(target)
    state.aoe = state.enemies >= 2 and not state.unsafeArea
    local combat = UnitAffectingCombat('player')
    state.eligible = combat and true or false
    if state.casting then return Select(nil,'casting') end
    local melee = jungle.inMeleeRange(target)
    if not melee then
        if observedHS or observedCleave then return Release('out_of_range') end
        utility.gapCloser(target,nil,gap)
        if gap.useCharge then return Select(6,'charge') end
        if gap.useBattleStanceForCharge then return Select(5,'charge_stance') end
        if gap.useIntercept then return Select(8,'intercept') end
        if gap.useBerserkerStanceForIntercept then return Select(7,'intercept_stance') end
        state.eligible=false
        return Select(nil,'out_of_range')
    end
    RefreshCosts()
    local maxHP = UnitHealthMax(target)
    local hp = maxHP>0 and UnitHealth(target)/maxHP or 1
    state.execute = hp<=0.2 and Allows('Execute') and GetSpellBookItemInfo('Execute') ~= nil
    state.phase = state.aoe and (state.execute and 'aoe_execute' or 'aoe') or (state.execute and 'execute' or 'normal')
    local stance = GetShapeshiftForm()
    local hs, cleave = queueObserved, C_Spell.IsCurrentSpell('Cleave')
    state.msCD = (not state.execute or Option('execute_ms')) and Cooldown('Mortal Strike') or math.huge
    state.wwCD = not state.unsafeWW and (not state.execute or Option('execute_ww')) and Cooldown('Whirlwind') or math.huge
    local tracker = jungle.SwingTimer
    local reliable = tracker and tracker:IsMainhandTimingReliable()
    state.swing = reliable and tracker:GetMainhandTimeRemaining() or math.huge
    local horizon = reliable and state.swing+1.5 or 1.5
    state.reserve = NextCoreReserve(horizon)
    if state.execute then
        -- If a core is due, fund its Execute-phase admission too, not just its base cost.
        state.reserve=state.reserve>0 and state.reserve+costs.Execute+5 or costs.Execute
    end
    local sweeping = state.aoe and combat and not jungle.unitCacheBuff('player','Sweeping Strikes')
        and Cooldown('Sweeping Strikes')<=0.01
    if sweeping then
        local usable, short = C_Spell.IsSpellUsable('Sweeping Strikes')
        sweeping = usable == true or short == true
    end
    -- Pool for a ready Sweeping Strikes plus the enabled imminent core, never
    -- wait for its future cooldown or keep AoE ownership after the count drops.
    if sweeping then state.reserve=state.reserve+costs['Sweeping Strikes'] end
    local allowCleave = state.aoe and combat and Allows('Cleave') and GetSpellBookItemInfo('Cleave')
        and (not state.execute or Option('execute_cleave'))
    -- Context permits keeping a factual queue. Ready() separately checks
    -- cooldown/usability for a new queue; transient readiness is not cleanup.
    state.queuedCost = cleave and costs.Cleave or (hs and costs['Heroic Strike'] or 0)
    -- Queued cost is an observation for diagnostics, not rage already spent.
    -- Current abilities use UnitPower; core/filler and new-queue budgets are prospective.
    local normal = not state.aoe and not state.execute
    local timed = normal
    local managesQueue = timed
    local cycle = timed and reliable and tracker:GetLastConfirmedMainhandSwingTime() or nil
    local guid = timed and UnitGUID(target) or nil
    local matching = timed and reliable and cycle ~= nil and guid ~= nil
        and tracker:GetLastConfirmedMainhandSwingTargetGUID()==guid
    if matching and (state.queueCycle~=cycle or state.queueTarget~=guid) then
        state.queueCycle,state.queueTarget,state.cancelCycle=cycle,guid,nil
    end
    local window = timed and matching and combat and not state.execute and stance==3
        and Allows('Heroic Strike') and C_Spell.IsCurrentSpell(6603)
    -- Missing/unmatched timing uses both enabled cores for paid admission;
    -- temporary admission still needs a confirmed matching cycle and headroom.
    state.hsHorizon = matching and mainhand and mainhand>0 and state.swing+mainhand or math.huge
    state.hsReserve = normal and UpcomingCoreReserve(state.hsHorizon) or state.reserve
    state.hsThreshold = normal and costs['Heroic Strike']+state.hsReserve
        or math.max(40,costs['Heroic Strike']+state.reserve+5)
    local paid = not state.aoe and combat and (not state.execute or Option('execute_hs'))
        and state.rage>=state.hsThreshold
    state.cancelLead,state.paidHS,state.queueWindow=CANCEL_LEAD,paid,window and true or false
    local executeReserve = state.execute and costs.Execute+5 or 0
    local temporary = hs and window and not paid and state.swing>CANCEL_LEAD
    local readyCoreCost, readyCore = 0, nil
    if not state.aoe and (normal or hs) then
        if state.msCD<=0.01 and state.rage>=costs['Mortal Strike']+executeReserve and Ready('Mortal Strike',target) then
            readyCoreCost,readyCore=costs['Mortal Strike'],19
        elseif stance==3 and state.wwCD<=0.01 and state.rage>=costs.Whirlwind+executeReserve and Ready('Whirlwind') then
            readyCoreCost,readyCore=costs.Whirlwind,20
        elseif state.execute and state.rage>=costs.Execute and Ready('Execute',target) then
            readyCoreCost,readyCore=costs.Execute,21
        end
    end
    state.temporaryHS,state.readyCoreCost=temporary and true or false,readyCoreCost
    local cancelReason
    if (cleave and not allowCleave)
        or (hs and (state.aoe or not Allows('Heroic Strike') or (state.execute and not Option('execute_hs')))) then cancelReason='cancel_queue'
    -- No Stopcasting just to make core rage available, or solely because HS is
    -- unaffordable. Do not manufacture queue removal: keep observing the client.
    elseif normal and hs and not paid and not readyCore and state.rage>=costs['Heroic Strike']
        and (not window or state.swing<=CANCEL_LEAD) then cancelReason='cancel_mh_window' end
    -- In timed mode the cancellation deadline precedes interrupts/utility intents.
    if cancelReason and managesQueue then
        state.cancelCycle=state.queueCycle
        return Select(1,cancelReason)
    end
    if Allows('Pummel') and jungle.checkPveInterrupt(target) then
        if stance==3 and Ready('Pummel',target,true) then return Select(4,'interrupt') end
        if stance~=3 and Cooldown('Pummel')<=0.01 and Ready('Berserker Stance',nil,true) then return Select(3,'interrupt_stance') end
    end
    if cancelReason then return Select(1,cancelReason) end
    if stance~=3 and Ready('Berserker Stance',nil,true) then return Select(9,'damage_stance') end
    if Allows('Attack') and not C_Spell.IsCurrentSpell(6603) then return Select(2,'attack') end
    -- Assigned debuff maintenance precedes every damage/core/queue decision,
    -- including Execute and an already queued HS. Readiness uses current rage.
    if Option('demo') and not state.unsafeArea and Ready('Demoralizing Shout')
        and utility.canDebuff(target)
        and not utility.hasOtherAttackPowerDebuff(target)
        and utility.debuffRemaining(target,'Demoralizing Shout')<=5 then return Select(14,'assigned_demo') end
    local stackSunder = false
    if Allows('Sunder Armor') and (Option('sunder_initial') or Option('sunder_stack'))
        and Ready('Sunder Armor',target) and utility.canDebuff(target) then
        local sunder, stacks, expose = utility.armorDebuff(target)
        if expose<=0 then
            if stacks==0 or sunder<=3 then
                return Select(13,'assigned_sunder')
            end
            stackSunder = Option('sunder_stack') and stacks>0 and stacks<5 and sunder>3
        end
    end
    local coreGap = math.min(state.msCD,state.wwCD)
    -- Include any remaining GCD tolerated by Ready(), so the next full GCD fits.
    local safeGap = coreGap>=1.5+(normal and state.gcd or 0)
    -- Optional spending preserves the next core even outside the HS horizon.
    -- A factually queued, funded HS is an additional prospective payment here;
    -- it still never subtracts rage from an immediately usable core/assignment.
    state.optionalReserve = normal and math.max(NextCoreReserve(math.huge),state.hsReserve) or 0
    if normal and hs and paid then state.optionalReserve=state.optionalReserve+costs['Heroic Strike'] end
    state.utilityGap = not normal or (state.gcd<=0.01 and safeGap)
    -- After assigned maintenance, Normal cores precede all new queues/buffs.
    -- Queued cost never reduces the actual rage available to an ability.
    if readyCore and (normal or hs) then
        return Select(readyCore,readyCore==19 and 'mortal_strike' or readyCore==20 and 'whirlwind' or 'execute')
    end
    if combat and state.rage<=90 and Ready('Bloodrage',nil,true) then return Select(10,'bloodrage') end
    local shout, needs = jungle.GetWarriorDpsShout(5)
    if needs and state.utilityGap and Ready(shout)
        and state.rage>=costs[shout]+state.optionalReserve then return Select(shout=='Commanding Shout' and 12 or 11,'shout') end
    local burst = combat and (not Option('burst_lust') or jungle.unitCacheBuff('player','Bloodlust') or jungle.unitCacheBuff('player','Heroism'))
    if burst and state.utilityGap and Option('cooldowns')
        and state.rage>=costs['Death Wish']+(normal and state.optionalReserve or NextCoreReserve(1.5))
        and Ready('Death Wish') then return Select(15,'death_wish') end
    local boss = UnitClassification(target)=='worldboss' or UnitLevel(target)==-1
    if burst and state.utilityGap and Option('recklessness') and boss and stance==3 and Ready('Recklessness') then return Select(16,'recklessness') end
    if burst and Option('cooldowns') and Allows('Trinkets') then
        if jungle.AreTrinketsReady() then
            if not state.trinketAttempt or state.now-state.trinketAttempt>=5 then state.trinketAttempt=state.now end
            if state.now-state.trinketAttempt<=0.15 then return Select(17,'trinkets') end
        else state.trinketAttempt=nil end
    end
    local fillerReserve = normal and state.optionalReserve or NextCoreReserve(math.huge)
    local fillerBuffer = normal and 0 or 5
    if combat and not normal and not state.execute and Option('berserker_rage') and coreGap>=1.5 and stance==3
        and not jungle.unitCacheBuff('player','Berserker Rage') and Ready('Berserker Rage') then return Select(24,'berserker_rage') end
    if sweeping and state.rage>=costs['Sweeping Strikes']+NextCoreReserve(1.5)+5
        + (state.execute and costs.Execute+5 or 0) and Ready('Sweeping Strikes',nil,true) then
        return Select(25,'aoe_sweeping')
    end
    if sweeping then return Select(nil,'pool_aoe_sweeping') end
    -- Cleave is a paid dump, including during the GCD. Protect ready SS/WW.
    if allowCleave and not hs and not cleave
        and state.rage>=math.max(40,costs.Cleave+state.reserve+5)
        and Ready('Cleave',target,true) then return Select(26,'aoe_cleave') end
    -- Paid admission uses exact core costs. Temporary admission uses MH facts only.
    if not hs and not cleave then
        if paid and Ready('Heroic Strike',target,true) then return Select(18,'funded_hs') end
        if window and state.swing>QUEUE_OPEN and state.cancelCycle~=cycle and readyCoreCost==0
            and Ready('Heroic Strike',target,true) then
            return Select(18,'temporary_mh_queue')
        end
    end
    if combat and normal and Option('berserker_rage') and safeGap and stance==3
        and not jungle.unitCacheBuff('player','Berserker Rage') and Ready('Berserker Rage') then return Select(24,'berserker_rage') end
    if state.aoe and stance==3 and state.wwCD<=0.01
        and state.rage>=costs.Whirlwind+executeReserve and Ready('Whirlwind') then
        return Select(20,'aoe_whirlwind')
    end
    -- Protect imminent WW, not a Cleave that has not spent any rage.
    -- New Cleave admission above already checks its own funding.
    local aoeMSReserve = state.aoe and state.wwCD<=horizon and costs.Whirlwind or 0
    if state.msCD<=0.01 and state.rage>=costs['Mortal Strike']+executeReserve+aoeMSReserve
        and Ready('Mortal Strike',target) then return Select(19,'mortal_strike') end
    if stance==3 and state.wwCD<=0.01 and state.rage>=costs.Whirlwind+executeReserve
        and Ready('Whirlwind') then return Select(20,'whirlwind') end
    if state.execute and state.rage>=costs.Execute and Ready('Execute',target) then return Select(21,'execute') end
    if safeGap and Ready('Victory Rush',target) then return Select(23,'victory_rush') end
    -- Healthy Sunder gets extra stacks only as a funded filler after damage cores
    -- and free Victory Rush, before paid Hamstring. Never spends imminent core rage.
    if stackSunder and safeGap and state.rage>=costs['Sunder Armor']+fillerReserve+fillerBuffer
        and Ready('Sunder Armor',target) then return Select(13,'stack_sunder') end
    if normal and safeGap and state.rage>=costs.Hamstring+fillerReserve
        and Ready('Hamstring',target) then return Select(22,'safe_filler') end
    return Select(nil,state.gcd>0.01 and 'gcd' or 'pool_rage')
end
function Kebab:Hold()
    local entry = jungle.RoutineContext
    return entry and entry.state.eligible and entry.enabledCount>0 or false
end
function Kebab:Reset()
    for key in pairs(idleState) do idleState[key]=nil end
    costAt=-1
end
local observer = CreateFrame('Frame')
observer:RegisterEvent('PLAYER_ENTERING_WORLD')
observer:RegisterEvent('NAME_PLATE_UNIT_ADDED')
observer:RegisterEvent('NAME_PLATE_UNIT_REMOVED')
observer:SetScript('OnEvent',function(_,event,unit)
    if event=='NAME_PLATE_UNIT_ADDED' then plates[unit]=true
    elseif event=='NAME_PLATE_UNIT_REMOVED' then plates[unit]=nil
    else
        for key in pairs(plates) do plates[key]=nil end
        -- Verify explicit tokens after reload; never derive identity from frame-array order.
        for i=1,40 do local token='nameplate'..i; if UnitExists(token) then plates[token]=true end end
    end
end)

-- On-demand observations only. Never evaluate, mutate placement state, or cast.
function Kebab:PrintDiagnostics()
    local config=jungle.RoutineConfig
    local thread=jungle.Engine and jungle.Engine.activeThread or 0
    local plan=config and config.plans[thread]
    local found=false
    local now=GetTime()
    local target=Enemy('target') and 'target' or Enemy('softenemy') and 'softenemy' or nil
    for _,entry in ipairs(plan or empty) do
        if entry.definition.id=='warrior.kebab' then
            found=true
            local saved=config:GetEntry(entry.thread,entry.index)
            local options=saved and type(saved.options)=='table' and saved.options or empty
            local current=entry.state
            print('[Kebab check-1] thread='..thread..' placement='..entry.index
                ..' pending='..tostring(config.pending==true))
            print('[Kebab] last='..tostring(current.action)..' reason='..tostring(current.reason)
                ..' phase='..tostring(current.phase)..' eligible='..tostring(current.eligible)
                ..' age='..(current.now and string.format('%.2f',now-current.now) or 'unevaluated'))
            print('[Kebab] target='..tostring(target)..' melee='..tostring(target and jungle.inMeleeRange(target))
                ..' combat='..tostring(UnitAffectingCombat('player'))..' stance='..GetShapeshiftForm()
                ..' casting='..tostring(UnitCastingInfo('player') or UnitChannelInfo('player')))
            print('[Kebab] MS='..tostring(current.msCD)..' WW='..tostring(current.wwCD)
                ..' GCD='..tostring(current.gcd)..' rage='..UnitPower('player',1)
                ..' queuedCost='..tostring(current.queuedCost)..' newQueueReserve='..tostring(current.reserve)
                ..' hsReserve='..tostring(current.hsReserve)..' hsThreshold='..tostring(current.hsThreshold)
                ..' hsHorizon='..tostring(current.hsHorizon)
                ..' optionalReserve='..tostring(current.optionalReserve)..' utilityGap='..tostring(current.utilityGap)
                ..' HS='..tostring(C_Spell.IsCurrentSpell('Heroic Strike'))
                ..' Cleave='..tostring(C_Spell.IsCurrentSpell('Cleave'))
                ..' unsafe='..tostring(current.unsafeArea)..' unsafeWW='..tostring(current.unsafeWW))
            if target then
                print('[Kebab] Demo remaining='..tostring(utility.debuffRemaining(target,'Demoralizing Shout'))
                    ..' otherAP='..tostring(utility.hasOtherAttackPowerDebuff(target))
                    ..' canDebuff='..tostring(utility.canDebuff(target)))
            end
            for _,name in ipairs({'Demoralizing Shout','Berserker Rage'}) do
                local key=name=='Demoralizing Shout' and 'demo' or 'berserker_rage'
                local cd=C_Spell.GetSpellCooldown(name)
                local usable,short=C_Spell.IsSpellUsable(name)
                local button
                for _,binding in ipairs(jungle.Hotkeys and jungle.Hotkeys.DynamicButtons or empty) do
                    if binding.spell==name then button=binding;break end
                end
                print('[Kebab] '..name..' action='..tostring(entry.actions[name])
                    ..' preference='..tostring(entry.options[key])..' saved='..tostring(options[key])
                    ..' learned='..tostring(GetSpellBookItemInfo(name)~=nil)
                    ..' usable='..tostring(usable)..' short='..tostring(short)
                    ..' CD='..tostring(cd and math.max(0,(cd.startTime or 0)+(cd.duration or 0)-now))
                    ..' CDenabled='..tostring(cd and cd.isEnabled))
                print('[Kebab] '..name..' aura='..tostring(jungle.unitCacheBuff('player',name))
                    ..' key='..tostring(button and button.key)
                    ..' macro='..tostring(button and button.frame:GetAttribute('macrotext')))
            end
        end
    end
    if not found then print('[Kebab check-1] No compiled Kebab on active thread '..thread) end
end
_G.SLASH_OLIAEYES6_KEBABCHECK1='/kebabcheck'
SlashCmdList.OLIAEYES6_KEBABCHECK=function() Kebab:PrintDiagnostics() end
