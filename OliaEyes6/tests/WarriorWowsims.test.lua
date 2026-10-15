-- Lua 5.1, standalone only. These are policy/control-flow tests, not live WoW proof.
local baselinePath = ...
local f = assert(io.open('tests/WarriorOptions.test.lua'))
local source = f:read('*a'); f:close()
local boundary = assert(source:find('local function Snapshot(rows)', 1, true))
local contextSource = source:sub(1, boundary - 1)
local loadWarrior = '    setfenv(assert(loadfile(path or "Routines/Warrior.lua")), env)("OliaEyes6", jungle)'
local realEligibility = [=[
    if s.realAoEEligibility then
        local utility = {unitCache=jungle.unitCache, RaidTrace=jungle.RaidTrace}
        env.UnitCreatureType=function(unit)
            if s.totem or (s.excluded and s.excluded[unit]=='totem') then return 'Totem',11 end
            return 'Humanoid',7
        end
        env.C_UnitAuras={GetAuraDataByIndex=function(unit,index,filter)
            local name=s.excluded and s.excluded[unit]
            if index==1 and name and ((filter=='HELPFUL' and name=='Divine Shield')
                or (filter=='HARMFUL' and name~='Divine Shield')) then return {name=name} end
        end}
        setfenv(assert(loadfile('GameData.lua')),env)('OliaEyes6',utility)
        setfenv(assert(loadfile('Core/Unit.lua')),env)('OliaEyes6',utility)
        jungle.IsEnemyNameplateEligibleForAoE=utility.IsEnemyNameplateEligibleForAoE
        jungle.IsTotemUnit=utility.IsTotemUnit
    end
]=]
local start = assert(contextSource:find(loadWarrior,1,true))
contextSource=contextSource:sub(1,start-1)..realEligibility..contextSource:sub(start)
local Context = assert(loadstring(contextSource .. '\nreturn Context'))()
local checks = 0
local function Check(value, why) assert(value, why); checks = checks + 1 end
local function First(rows)
    for _, row in ipairs(rows) do if row[3] then return row[2] end end
end
local function Has(rows, spell)
    for _, row in ipairs(rows) do if row[2] == spell and row[3] then return true end end
    return false
end
local function Snapshot(rows)
    local result = {}
    for i, row in ipairs(rows) do
        result[#result + 1] = i .. ':' .. row[1] .. ':' .. row[2] .. ':' .. tostring(row[3])
    end
    return table.concat(result, '|')
end
local function Fixture(s)
    s = s or {}
    s.realSwingTimer, s.thread = true, s.thread or 2
    s.rage, s.now = s.rage or 90, 100
    s.auras = s.auras or {{'Sunder Armor', 5, 25}, {'Demoralizing Shout', 0, 25}}
    local settings = {universal_arms_wowsims_st = s.enabled ~= false}
    for key, value in pairs(s.options or {}) do settings[key] = value end
    local j, e, frames = Context(s, nil, settings)
    e.GetTime = function() return s.now end
    e.UnitAttackSpeed = function() return s.speed or 3.5, s.fury and 2.5 or nil end
    e.GetNetStats = function() return 0, 0, 40, s.latency or 50 end
    e.UnitAffectingCombat = function() return not s.outOfCombat end
    e.UnitExists = function(unit) return unit and unit ~= 'missing' and not (s.lost and unit ~= 'player') and not (s.excluded and s.excluded[unit]=='missing') end
    e.UnitCanAttack = function(_, unit) assert(unit, 'absent enemy read'); return not s.friendly and not (s.excluded and s.excluded[unit]=='friendly') end
    e.UnitIsDeadOrGhost = function(unit) return s.dead or (s.excluded and s.excluded[unit]=='dead') or false end
    e.GetSpellCooldown = function(spell)
        if s.disabledCD == spell then return 0, 0, 0 end
        local cd = s.cd and s.cd[spell] or 0
        if cd > 0 then return s.now + cd - 10, 10, 1 end
        if (s.gcd or 0) > 0 and spell ~= 'Bloodrage' and spell ~= 'Heroic Strike' then
            return s.now + s.gcd - 1.5, 1.5, 1
        end
        return 0, 0, 1
    end
    j.GetGCDValues = function() return (s.gcd or 0) > 0 and s.now + s.gcd - 1.5 or 0, 1.5 end
    local costs = {Slam=15, ['Mortal Strike']=30, Whirlwind=25, Execute=15, ['Heroic Strike']=15,
        ['Sunder Armor']=15, ['Sweeping Strikes']=30, Cleave=20, Hamstring=10, Overpower=5, ['Battle Shout']=10}
    e.IsUsableSpell = function(spell)
        if spell == 'Death Wish' and not s.deathWish then return false, false end
        if s.blocked and s.blocked[spell] then return false, false end
        if spell == 'Whirlwind' and (s.stance or 3) ~= 3 then return false, false end
        local short = s.rage < (costs[spell] or 0)
        return not short, short
    end
    e.IsCurrentSpell = function(spell)
        return (spell == 6603 and not s.noAttack) or (spell == 'Heroic Strike' and s.hs)
            or (spell == 'Cleave' and s.queued) or false
    end
    e.C_Spell.IsCurrentSpell = e.IsCurrentSpell
    j.unitCacheBuff = function(_, name, _, expires)
        if name == 'Bloodlust' or name == 'Heroism' then return s.lust == name end
        if name == 'Sweeping Strikes' then return s.sweepingActive or false end
        if name == 'Battle Shout' then return (s.shoutRemaining or 30) >= (expires or 0) end
        return false
    end
    j.AreTrinketsReady = function() return s.trinket or false end
    j.checkPveInterrupt = function() return s.interrupt or false end
    local function Event(name, ...)
        for _, frame in ipairs(frames) do
            if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, name, ...) end
        end
    end
    e.CombatLogGetCurrentEventInfo = function() end
    if s.dwArms then
        e.IsPlayerSpell = function(id) return id == 12294 or id == 12328 or id == 1464 end
        e.IsSpellKnown = e.IsPlayerSpell
        Event('PLAYER_TALENT_UPDATE')
    end
    function s:event(name, ...) Event(name, ...) end
    function s:swing(ago, targetGUID)
        self.now = 100 - (ago or 0.2)
        e.CombatLogGetCurrentEventInfo = function()
            return self.now, 'SWING_DAMAGE', false, 'player', nil, nil, nil, targetGUID or 'enemy1'
        end
        Event('COMBAT_LOG_EVENT_UNFILTERED')
        self.now = 100
    end
    function s:rows(target) return j.warriorWowsims(target or 'target') end
    if not s.noSwing then s:swing(s.ago) end
    return s, j, e
end

-- Default-off is identical through the actual dispatcher, including explicit false.
if baselinePath then
    for _, thread in ipairs({0,1,2,3,5,7}) do
        for _, fury in ipairs({false,true}) do
            for _, pvp in ipairs({false,true}) do
                for _, rage in ipairs({10,45,90}) do
                    for _, enemies in ipairs({1,3}) do
                        local args = {thread=thread, fury=fury, pvp=pvp, rage=rage, enemies=enemies}
                        local old = Context(args, baselinePath)
                        local new = Context(args, nil, {universal_arms_wowsims_st=false})
                        Check(Snapshot(old.warriorUniversal('target')) == Snapshot(new.warriorUniversal('target')),
                            'off preserves exact universal rows')
                    end
                end
            end
        end
    end
end

local s,j,e = Fixture()
Check(First(s:rows()) == 'Slam', 'source prioritizes after-swing Slam over ready MS/WW')
s.ago=0.4; s:swing(s.ago)
Check(First(s:rows()) == 'Mortal Strike', 'outside narrow window MS wins')
s.cd={['Mortal Strike']=4}
Check(First(s:rows()) == 'Whirlwind', 'WW follows MS')
s.cd.Whirlwind=4; s.execute=true
Check(First(s:rows()) == 'Execute', 'execute after unavailable cores')
s:swing(0.2)
Check(First(s:rows()) == 'Slam', 'execute without lust retains Slam')
for _, lust in ipairs({'Bloodlust','Heroism'}) do
    s.lust=lust
    Check(not Has(s:rows(),'Slam') and First(s:rows())=='Execute', 'execute lust skips Slam: '..lust)
end
s.lust=nil; s.execute=false; s.cd={}
for _, flag in ipairs({'moving','casting'}) do
    s[flag]=true
    Check(not Has(s:rows(),'Slam'), 'Slam blocked: '..flag)
    s[flag]=false
end
s.casting=true
Check(First(s:rows()) == nil, 'casting owns empty tick without fallback')
s.casting=false; s:swing(0.2,'enemy2')
Check(not Has(s:rows(),'Slam'), 'previous enemy swing cannot authorize Slam')
s:swing(0.2); s.gcd=0.8
Check(not Has(s:rows(),'Slam') and not Has(s:rows(),'Mortal Strike'), 'no early GCD queue')
Check(Has(s:rows(),'Heroic Strike'), 'off-GCD queue remains available')
s.gcd=0; s.rage=14
Check(not Has(s:rows(),'Slam'), 'Slam needs rage now')
s.rage=15
Check(First(s:rows())=='Slam', 'source Slam needs only its own cost')
s = Fixture({noSwing=true})
Check(not Has(s:rows(),'Slam'), 'unknown swing fails closed')
s = Fixture({speed=0.6, ago=0.2})
Check(Has(s:rows(),'Slam'), 'full interval qualifies even with less than half-second remaining')
s = Fixture({speed=0.5, ago=0.2, latency=150})
Check(Has(s:rows(),'Slam'), 'half-second full interval qualifies without latency subtraction')
s = Fixture({speed=0.499, ago=0.2})
Check(not Has(s:rows(),'Slam'), 'full interval below half-second rejected')
s,j,e = Fixture({speed=0.6, ago=0.2})
s.speed=0.49; s:event('UNIT_ATTACK_SPEED','player')
Check(not Has(s:rows(),'Slam'), 'haste gain uses current interval instead of speed at last attack')
s.speed=0.5; s:event('UNIT_ATTACK_SPEED','player')
Check(Has(s:rows(),'Slam'), 'haste loss restores eligibility at half-second boundary')
s,j,e = Fixture({speed=0.6, ago=0.2})
s.speed=0.49
Check(not Has(s:rows(),'Slam'), 'current speed is read even without an attack-speed event')
s = Fixture({speed=0.6, ago=0.4, latency=50})
Check(not Has(s:rows(),'Slam'), 'qualifying full interval does not bypass the after-swing window')
s = Fixture({ago=0.4, latency=150})
Check(Has(s:rows(),'Slam'), 'source delay plus 300ms window')
s = Fixture({ago=1.2, latency=1000})
Check(not Has(s:rows(),'Slam'), 'hard cap bounds latency proxy')
s = Fixture({disabledCD='Slam'})
Check(not Has(s:rows(),'Slam'), 'disabled cooldown fails closed')
s = Fixture({blocked={Slam=true}})
Check(not Has(s:rows(),'Slam'), 'explicit false usability fails closed')

-- A confirmed completion consumes a swing; intent alone must not consume it.
s,j,e=Fixture()
Check(Has(s:rows(),'Slam') and Has(s:rows(),'Slam'),'repeated intent retains window until observed cast')
s:event('UNIT_SPELLCAST_SUCCEEDED','player','slam-completed',25242)
Check(not Has(s:rows(),'Slam'),'one Slam per confirmed swing after completion')
s:swing(0.1)
Check(Has(s:rows(),'Slam'),'next confirmed swing reopens window')
e.UnitHealthMax=function() return 0 end
Check(not Has(s:rows(),'Execute'),'unknown maximum health is not execute phase')
s,j,e=Fixture({deathWish=true})
Check(not Has(s:rows(),'Death Wish') and First(s:rows())=='Slam','Death Wish never auto-used')
s.trinket=true
Check(not Has(s:rows(),'Trinkets') and First(s:rows())=='Slam','trinkets never auto-used')
s.interrupt=true
Check(First(s:rows())=='Pummel','platform interrupt preempts damage')
s.stance=1
Check(First(s:rows())=='Berserker Stance','interrupt stance preparation')

-- Source queue thresholds and execute policy; no spurious cancel after spending.
s = Fixture({ago=0.5,rage=79,cd={['Mortal Strike']=5,Whirlwind=5}})
Check(not Has(s:rows(),'Heroic Strike'),'2H HS below 80')
s.rage=80
Check(Has(s:rows(),'Heroic Strike'),'2H HS at 80')
s.hs=true; s.rage=50
Check(not Has(s:rows(),'Heroic Strike') and not Has(s:rows(),'Stopcasting'),'existing HS not requeued/cancelled at queue threshold')
s.hs=false; s.execute=true; s.rage=100
Check(not Has(s:rows(),'Heroic Strike'),'no HS queue in execute')
s.queued=true
Check(Has(s:rows(),'Stopcasting'),'cancel carried AoE queue')
s.casting=true
Check(not Has(s:rows(),'Stopcasting'),'never cancel active Slam to clear queue')

-- DW Arms is selected by MS capability even though legacy maps DW to Fury.
s,j,e=Fixture({fury=true,dwArms=true,rage=40})
Check(s:rows()[1][1]=='WoWSims Attack','DW Arms reaches new mode')
Check(not Has(s:rows(),'Slam') and Has(s:rows(),'Heroic Strike'),'DW no Slam and HS at 40')
s.rage=39
Check(not Has(s:rows(),'Heroic Strike'),'DW HS below 40')
s.execute=true; s.cd={Whirlwind=1.5}
Check(not Has(s:rows(),'Mortal Strike') and not Has(s:rows(),'Execute'),'DW execute pools for WW at 1.5')
s.cd.Whirlwind=1.6
Check(Has(s:rows(),'Execute'),'DW execute with enough WW gap')
s.execute=false; s.rage=40; s.cd={['Mortal Strike']=2,Whirlwind=2}
Check(Has(s:rows(),'Hamstring'),'DW filler in core gap')
s.cd.Whirlwind=1
Check(not Has(s:rows(),'Hamstring'),'DW filler cannot clip core')
s.cd.Whirlwind=2
s.now=99.9
e.CombatLogGetCurrentEventInfo=function() return s.now,'SWING_MISSED',false,'player',nil,nil,nil,'enemy1',nil,nil,nil,'DODGE' end
s:event('COMBAT_LOG_EVENT_UNFILTERED'); s.now=100
Check(First(s:rows())=='Battle Stance','DW Overpower weaving after target dodge')
s.stance=1
Check(First(s:rows())=='Overpower','DW Overpower in Battle')

-- All maintenance requires independent, explicit WoWSims preferences.
s,j=Fixture({auras={},options={wowsims_sunder_initial=true,wowsims_sunder_stack=true,wowsims_sunder_refresh=true}})
Check(First(s:rows())=='Sunder Armor','initial Sunder before core')
s.auras={{'Sunder Armor',2,20}}
Check(First(s:rows())=='Sunder Armor','build Sunder to five')
s.auras={{'Sunder Armor',5,9}}
Check(First(s:rows())=='Slam','refresh waits for core gap')
s.cd={['Mortal Strike']=2,Whirlwind=2}
Check(First(s:rows())=='Sunder Armor','refresh at <=10 seconds in gap')
s.auras={{'Expose Armor',0,20}}
Check(not Has(s:rows(),'Sunder Armor'),'active Expose suppresses Sunder')
s.auras={}
j.Options.Refresh=function() end
Check(j.Options:SetEnabled('thread2_sunder_routine',false,'WARRIOR'),'existing preference writable')
Check(Has(s:rows(),'Sunder Armor'),'legacy Sunder toggle does not control WoWSims')
j.Options:SetEnabled('wowsims_sunder_initial',false,'WARRIOR')
Check(not Has(s:rows(),'Sunder Armor'),'new initial toggle applies immediately')
s.rage=89
Check(Has(s:rows(),'Bloodrage'),'Bloodrage below 90')
s.rage=90
Check(not Has(s:rows(),'Bloodrage'),'Bloodrage threshold 90')
s.shoutRemaining=9
Check(Has(s:rows(),'Battle Shout'),'shout refresh in gap')
s.cd.Whirlwind=1
Check(not Has(s:rows(),'Battle Shout'),'shout waits for cores')

-- Independent Sunder phases, Expose suppression, and default-off Demo.
local optionKeys = {'wowsims_sunder_initial','wowsims_sunder_stack','wowsims_sunder_refresh','wowsims_demoralizing_shout'}
for _, thread in ipairs({1,2,3}) do
    s,j,e=Fixture({thread=thread,auras={},cd={['Mortal Strike']=2,Whirlwind=2},trinket=true,deathWish=true})
    for _, key in ipairs(optionKeys) do Check(not j.Options:IsEnabled(key,'WARRIOR'),'new option defaults off: '..key) end
    Check(not Has(s:rows(),'Sunder Armor') and not Has(s:rows(),'Demoralizing Shout'),'maintenance off by default')
    Check(not Has(s:rows(),'Death Wish') and not Has(s:rows(),'Trinkets'),'no automatic cooldowns on any universal thread')
    j.Options.Refresh=function() end
    for _, key in ipairs(optionKeys) do
        for _, clear in ipairs(optionKeys) do j.Options:SetEnabled(clear,false,'WARRIOR') end
        j.Options:SetEnabled(key,true,'WARRIOR')
        for _, count in ipairs({0,1,4,5}) do
            for _, remaining in ipairs({9,11}) do
                s.auras=count==0 and {} or {{'Sunder Armor',count,remaining}}
                local expected = (key=='wowsims_sunder_initial' and count==0)
                    or (key=='wowsims_sunder_stack' and count>0 and count<5)
                    or (key=='wowsims_sunder_refresh' and count>0 and remaining<=10)
                Check(Has(s:rows(),'Sunder Armor')==expected,'independent Sunder phase '..key..' stacks '..count)
                s.auras[#s.auras+1]={'Expose Armor',0,20}
                Check(not Has(s:rows(),'Sunder Armor'),'every phase suppressed by Expose')
            end
        end
    end
end
s,j=Fixture({auras={{'Sunder Armor',5,10}},options={wowsims_sunder_refresh=true},cd={['Mortal Strike']=1.5,Whirlwind=1.5}})
Check(Has(s:rows(),'Sunder Armor'),'refresh at exact 10s and 1.5s boundaries')
s.cd.Whirlwind=1.49
Check(not Has(s:rows(),'Sunder Armor'),'refresh waits for both cooldown gaps')
s.cd.Whirlwind=2; s.auras={{'Sunder Armor',5}}
Check(not Has(s:rows(),'Sunder Armor'),'permanent aura is not expiring')
s.auras={}
Check(not Has(s:rows(),'Sunder Armor'),'refresh alone never applies missing aura')
s,j=Fixture({auras={},options={wowsims_demoralizing_shout=true,thread2_demoralizing_shout=false},cd={['Mortal Strike']=2,Whirlwind=2}})
Check(Has(s:rows(),'Demoralizing Shout'),'enabled Demo independent of legacy toggle')
s.auras={{'Demoralizing Shout',0,6}}
Check(not Has(s:rows(),'Demoralizing Shout'),'healthy Demo not refreshed')
s.auras={{'Demoralizing Shout',0,5}}
Check(Has(s:rows(),'Demoralizing Shout'),'Demo refresh at five seconds')
for _, equivalent in ipairs({'Demoralizing Roar','Curse of Weakness','Screech'}) do
    for _, duration in ipairs({1,20,0}) do
        s.auras={{'Demoralizing Shout',0,3},{equivalent,0,duration~=0 and duration or nil}}
        Check(not Has(s:rows(),'Demoralizing Shout'),'equivalent active/permanent debuff suppresses Demo: '..equivalent)
    end
end
s.auras={}; s.cd.Whirlwind=1.49
Check(not Has(s:rows(),'Demoralizing Shout'),'Demo cannot clip core cooldown')
s.cd.Whirlwind=2; s.gcd=0.8
Check(not Has(s:rows(),'Demoralizing Shout'),'Demo respects GCD')
s.gcd=0; s.blocked={['Demoralizing Shout']=true}
Check(not Has(s:rows(),'Demoralizing Shout'),'Demo respects unusability')
s.blocked=nil
Check(Has(s:rows(),'Demoralizing Shout'),'Demo returns after coverage/gates clear')
j.Options.Refresh=function() end
j.Options:SetEnabled('wowsims_demoralizing_shout',false,'WARRIOR')
Check(not Has(s:rows(),'Demoralizing Shout'),'disable clears previously true row')

-- The earlier thread-1 maintenance pass must not bypass these switches or timing.
s,j=Fixture({thread=1,auras={},options={thread1_thunder_clap=false},cd={['Mortal Strike']=2,Whirlwind=2}})
Check(Has(j.warriorArmsPveMaintenance('target'),'Sunder Armor'),'explicit maintenance uses its own settings')
j.Options.Refresh=function() end
j.Options:SetEnabled('wowsims_sunder_initial',true,'WARRIOR')
Check(Has(j.warriorArmsPveMaintenance('target'),'Sunder Armor') and Has(s:rows(),'Sunder Armor'),'independent maintenance and WoWSims settings')
j.Options:SetEnabled('wowsims_sunder_initial',false,'WARRIOR')
j.Options:SetEnabled('wowsims_sunder_refresh',true,'WARRIOR')
s.auras={{'Sunder Armor',5,3}}; s.cd={}
Check(Has(j.warriorArmsPveMaintenance('target'),'Sunder Armor') and not Has(s:rows(),'Sunder Armor'),'explicit maintenance retains its own refresh timing')
j.Options:SetEnabled('thread1_thunder_clap',true,'WARRIOR')
Check(Has(j.warriorArmsPveMaintenance('target'),'Battle Stance'),'T1 Thunder Clap preparation retained')
j.Options:SetEnabled('universal_arms_original',true,'WARRIOR')
s.auras={}
Check(Has(j.warriorArmsPveMaintenance('target'),'Sunder Armor'),'mode off restores original T1 maintenance')

-- Imported multi-target priorities; active SS, affordability and live transitions.
s,j,e=Fixture({enemies=2})
Check(First(s:rows())=='Sweeping Strikes','AoE SS first at two eligible targets')
s.sweepingActive=true
Check(First(s:rows())=='Whirlwind','AoE WW wins over open Slam and ready MS')
s.cd={Whirlwind=4}
Check(First(s:rows())=='Slam','AoE Slam after unavailable WW')
s:swing(0.5)
Check(First(s:rows())=='Mortal Strike','AoE MS after Slam window')
s.cd['Mortal Strike']=4; s.rage=40
Check(First(s:rows())=='Cleave','Cleave at 40 after core spells')
s.rage=39
Check(not Has(s:rows(),'Cleave'),'Cleave threshold is 40')
s.rage=40; s.execute=true
Check(First(s:rows())=='Execute' and Has(s:rows(),'Cleave'),'Execute before Cleave, including execute phase')
s.queued=true; s.rage=20
Check(not Has(s:rows(),'Stopcasting') and not Has(s:rows(),'Cleave'),'funded AoE queue is not cancelled at queue threshold')
s.queued=false; s.hs=true
Check(First(s:rows())=='Stopcasting' and not Has(s:rows(),'Cleave'),'AoE cancels carried Heroic Strike first')
s.hs=false
s,j,e=Fixture({enemies=2,rage=29})
Check(not Has(s:rows(),'Sweeping Strikes') and First(s:rows())=='Whirlwind','SS unaffordable does not pool or block WW')
s.rage=30; s.blocked={['Sweeping Strikes']=true}
Check(First(s:rows())=='Whirlwind','unusable SS fails closed')
s.blocked=nil; s.sweepingActive=true
Check(not Has(s:rows(),'Sweeping Strikes'),'active SS not reapplied')
s.sweepingActive=false; s.cd={['Sweeping Strikes']=4}
Check(First(s:rows())=='Whirlwind','SS on cooldown does not block WW')
s.cd={}; j.Options.Refresh=function() end
j.Options:SetEnabled('thread2_sweeping_strikes',false,'WARRIOR')
Check(not Has(s:rows(),'Sweeping Strikes') and First(s:rows())=='Whirlwind','existing T2 SS switch remains effective')
s.casting=true
Check(First(s:rows())==nil,'AoE cast holds all rows')
s.casting=false
s,j,e=Fixture({enemies=3,options={wowsims_sunder_initial=true,wowsims_sunder_stack=true,wowsims_sunder_refresh=true},auras={}})
Check(not Has(s:rows(),'Sunder Armor') and not Has(s:rows(),'Heroic Strike'),'AoE never runs ST Sunder or Heroic Strike')
s,j,e=Fixture({enemies=2,fury=true,dwArms=true,cd={['Mortal Strike']=4,Whirlwind=4},sweepingActive=true})
s.now=99.9
e.CombatLogGetCurrentEventInfo=function() return s.now,'SWING_MISSED',false,'player',nil,nil,nil,'enemy1',nil,nil,nil,'DODGE' end
s:event('COMBAT_LOG_EVENT_UNFILTERED');s.now=100
Check(not Has(s:rows(),'Overpower') and not Has(s:rows(),'Battle Stance'),'AoE disables DW Overpower weaving')

-- Use the production eligibility helper and actual GameData exclusion lists.
for _, excluded in ipairs({'Polymorph','Sap','Entangling Roots','Banish','Divine Shield','totem','dead','friendly','missing'}) do
    s,j,e=Fixture({enemies=2,realAoEEligibility=true,excluded={nameplate2=excluded}})
    Check(not Has(s:rows(),'Sweeping Strikes') and not Has(s:rows(),'Cleave'),'excluded second enemy does not enter AoE: '..excluded)
    Check(First(s:rows())=='Slam','excluded extra enemy preserves ST priority: '..excluded)
end
s,j,e=Fixture({enemies=3,realAoEEligibility=true,excluded={target='Polymorph',nameplate1='Polymorph'}})
Check(not Has(s:rows(),'Whirlwind') and not Has(s:rows(),'Sweeping Strikes') and not Has(s:rows(),'Cleave'),'selected CC target cannot enable AoE even with two eligible others')
s,j,e=Fixture({enemies=2,realAoEEligibility=true})
e.UnitGUID=function(unit) return unit=='player' and 'player' or 'enemy1' end
Check(not Has(s:rows(),'Sweeping Strikes'),'duplicate GUIDs do not create two enemies')
s,j,e=Fixture({enemies=2,realAoEEligibility=true})
local plates=e.C_NamePlate.GetNamePlates()
Check(First(s:rows())=='Sweeping Strikes','start in AoE')
e.C_NamePlate.GetNamePlates=function() return {plates[1]} end
Check(not Has(s:rows(),'Sweeping Strikes') and First(s:rows())=='Slam','2-to-1 change clears AoE rows immediately')
s.queued=true
Check(First(s:rows())=='Stopcasting','ST cancels carried Cleave')
s.queued=false
e.C_NamePlate.GetNamePlates=function() return plates end
Check(First(s:rows())=='Sweeping Strikes','1-to-2 reacquires AoE')
s.excluded={nameplate2='Sap'}
Check(First(s:rows())=='Slam','new CC removes enemy from live count')
s.excluded=nil
Check(First(s:rows())=='Sweeping Strikes','CC expiry restores eligible count')

s,j,e=Fixture({enemies=2,realAoEEligibility=true})
e.CheckInteractDistance=function(unit) return unit~='nameplate2' end
Check(not Has(s:rows(),'Sweeping Strikes'),'out-of-range second enemy does not enter AoE')
s,j,e=Fixture({enemies=2,realAoEEligibility=true})
j.unitCache.nameplate2={auraInitialized=true,auras={debuffs={enemyNameplateAoEIgnore={Sap={isActive=true}}},buffs={}}}
Check(not Has(s:rows(),'Sweeping Strikes'),'categorized cached CC exclusion respected')
j.unitCache.nameplate2.auras.debuffs.enemyNameplateAoEIgnore.Sap.isActive=false
Check(Has(s:rows(),'Sweeping Strikes'),'cached CC expiry restores eligibility')
s,j,e=Fixture({enemies=2,gcd=0.8})
Check(Has(s:rows(),'Sweeping Strikes') and not Has(s:rows(),'Whirlwind'),'off-GCD SS eligible while WW waits for GCD')
s.sweepingActive=true
Check(not Has(s:rows(),'Sweeping Strikes') and Has(s:rows(),'Cleave'),'queued Cleave remains off GCD')
s,j,e=Fixture({enemies=2})
local known=e.GetSpellBookItemInfo
e.GetSpellBookItemInfo=function(spell) if spell~='Sweeping Strikes' then return known(spell) end end
Check(not Has(s:rows(),'Sweeping Strikes'),'unlearned Sweeping fails closed')
s,j,e=Fixture({enemies=2,thread=1,auras={},options={wowsims_sunder_initial=true}})
Check(Has(j.warriorArmsPveMaintenance('target'),'Sunder Armor') and not Has(s:rows(),'Sunder Armor'),'explicit maintenance remains independent from WoWSims AoE')

-- Selector boundaries: no changes to other contexts, settings apply immediately.
for _, args in ipairs({{pvp=true},{fury=true},{thread=7},{thread=5},{thread=0},
    {outOfCombat=true},{outOfRange=true},{friendly=true},{lost=true},{dead=true},{totem=true}}) do
    s,j,e=Fixture(args)
    Check(First(s:rows())==nil,'specialized mode excludes neighboring context')
end
for _, thread in ipairs({1,2,3}) do
    s,j=Fixture({thread=thread})
    Check(s:rows()[1][1]=='WoWSims Attack','universal thread '..thread)
    j.Options.Refresh=function() end
    j.Options:SetEnabled('universal_arms_original',true,'WARRIOR')
    Check(First(s:rows())==nil,'off applies next tick')
    j.Options:SetEnabled('universal_arms_wowsims_st',true,'WARRIOR')
    Check(s:rows()[1][1]=='WoWSims Attack','on applies next tick')
end
s,j,e=Fixture()
e.C_NamePlate.GetNamePlates=function() return {} end
Check(s:rows()[1][1]=='WoWSims Attack','selected enemy works without nameplates')
Check(not Has(j.warriorUniversal(nil),'Slam'),'nil target cannot reuse cached Slam')
s.lost=true
Check(not Has(s:rows(),'Slam'),'loss cannot reuse cached Slam')
s.lost=false
Check(Has(s:rows(),'Slam'),'reacquisition re-evaluates')

-- Engine owns thread-3 AoE before it ever reaches universal, including empty holds.
local routed={}
j.GetPlayerClass=function() return 'WARRIOR' end
e.IsEquippedItemType=function() return false end
setfenv(assert(loadfile('Core/Engine.lua')),e)('OliaEyes6',j)
local eng=j.Engine
eng.initialized=true; eng.activeThread=3; eng.pixelReset={clear=function() end}
assert(loadfile('tests/RoutineConfigFixture.lua'))()(j,e,'WARRIOR')
Check(j.RoutineConfig.plans[3][1].mode=='wowsims' and j.RoutineConfig.plans[3][1].behavior.name=='sweeping-fallback' and #j.RoutineConfig.plans[3]==1,'migrated maintenance mode and fallback behavior are fixed')
eng.rotation={dpsRotate=function() local def=j.RoutineContext.definition;routed[#routed+1]=def.legacyBase or def.id; return false end}
j.WarriorThread3OwnsTarget=function() return true end
eng:ProcessRotation()
Check(#routed==1 and routed[1]=='warrior.sweeping','dedicated AoE wait owns tick')
routed={}; j.WarriorThread3OwnsTarget=function() return false end
eng:ProcessRotation()
Check(#routed==0,'released AoE does not substitute another routine')
j.Options.Refresh=function() end
Check(j.RoutineConfig:Add(3,'warrior.wowsims'),'explicitly add independent WoWSims placement')
eng:ProcessRotation()
Check(#routed==1 and routed[1]=='warrior.wowsims','explicit later placement remains supported')
print('WoWSims Arms: '..checks..' checks passed (mocked APIs).')
