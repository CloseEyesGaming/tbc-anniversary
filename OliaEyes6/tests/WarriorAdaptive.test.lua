-- Standalone Lua 5.1 scenarios. Never loaded by the production TOC.
-- Actual Options/Warrior/Adaptive code; game APIs are mocked, not live validation.
local file = assert(io.open('tests/WarriorOptions.test.lua'))
local source = file:read('*a'); file:close()
local boundary = assert(source:find('local function Snapshot(rows)', 1, true))
local Context = assert(loadstring(source:sub(1, boundary - 1) .. '\nreturn Context'))()
local checks = 0
local function Check(ok, message) assert(ok, message); checks = checks + 1 end
local function First(rows)
    for _, row in ipairs(rows) do if row[3] then return row[2] end end
end

local function Fixture(s)
    s = s or {}
    s.now, s.rage, s.enemies = 100, s.rage or 80, s.enemies or 1
    s.thread, s.stance = s.thread or 2, s.stance or 3
    local settings = {arms_pve_mode=s.mode or 'adaptive'}
    for key, value in pairs(s.options or {}) do settings[key] = value end
    local j, e, frames = Context(s, nil, settings)
    e.GetTime = function() return s.now end
    e.IsInInstance = function() return true, s.instance or 'raid' end
    e.IsMounted = function() return s.mounted end
    e.UnitExists = function(unit)
        if unit == 'player' then return true end
        if unit == 'target' then return not s.lost end
        local n = unit and tonumber(unit:match('^nameplate(%d+)$'))
        return n and n <= s.enemies or false
    end
    e.UnitCanAttack = function(_, unit)
        assert(unit and e.UnitExists(unit), 'invalid enemy read')
        return unit ~= 'player' and not s.friendly
    end
    e.UnitIsDeadOrGhost = function(unit) return unit == 'player' and s.dead or unit ~= 'player' and s.targetDead or false end
    e.UnitGUID = function(unit)
        assert(unit and e.UnitExists(unit), 'invalid GUID read')
        return (unit == 'target' or unit == 'nameplate1') and (s.guid or 'enemy1') or unit
    end
    e.UnitHealth = function(unit)
        assert(unit and e.UnitExists(unit), 'invalid health read')
        return s.hp or (s.execute and 10000 or 90000)
    end
    e.UnitHealthMax = function(unit) assert(unit and e.UnitExists(unit)); return 100000 end
    e.UnitLevel = function() return s.boss and -1 or 70 end
    e.UnitClassification = function() return s.boss and 'worldboss' or 'normal' end
    e.UnitIsUnit = function(a,b) return e.UnitExists(a) and e.UnitExists(b) and e.UnitGUID(a) == e.UnitGUID(b) end
    e.UnitAffectingCombat = function() return not s.outOfCombat end
    e.UnitAttackSpeed = function() return s.speed or 3.5 end
    e.GetUnitSpeed = function() return s.moving and 7 or 0 end
    e.UnitCastingInfo = function(unit) return unit == 'player' and s.casting and 'Slam' or nil end
    e.UnitChannelInfo = function(unit) return unit == 'player' and s.channel and 'Channel' or nil end
    local costs = {Slam=15, ['Mortal Strike']=30, Whirlwind=25, Execute=15,
        ['Heroic Strike']=15, Cleave=20, ['Sweeping Strikes']=30,
        ['Sunder Armor']=15, ['Battle Shout']=10, ['Thunder Clap']=20, Intercept=10}
    local known = {Slam=true, ['Mortal Strike']=true, Whirlwind=true, Execute=true,
        ['Heroic Strike']=true, Cleave=true, ['Sweeping Strikes']=true,
        ['Sunder Armor']=true, ['Battle Shout']=true, ['Thunder Clap']=true,
        ['Demoralizing Shout']=true, ['Berserker Stance']=true, ['Battle Stance']=true,
        Charge=true, Intercept=true, Pummel=true, Overpower=true}
    e.GetSpellBookItemInfo = function(name)
        if s.unknown and s.unknown[name] then return nil end
        return (known[name] or (s.learned and s.learned[name])) and 'SPELL' or nil
    end
    e.C_Spell.GetSpellInfo = function(name) return {name=name,castTime=name=='Slam' and 500 or 0} end
    e.C_Spell.GetSpellPowerCost = function(name)
        local cost = s.costs and s.costs[name] or costs[name] or 0
        return {{type=1,cost=cost,minCost=cost,requiredAuraID=0}}
    end
    e.C_Spell.GetSpellCooldown = function(name)
        if s.missingCD and s.missingCD[name] then return nil end
        local cd = s.cd and s.cd[name] or 0
        if cd > 0 then return {startTime=s.now+cd-10,duration=10,isEnabled=true} end
        if (s.gcd or 0) > 0 then return {startTime=s.now+s.gcd-1.5,duration=1.5,isEnabled=true} end
        return {startTime=0,duration=0,isEnabled=true}
    end
    e.C_Spell.IsSpellUsable = function(name)
        if s.blocked and s.blocked[name] then return false,false end
        if name == 'Whirlwind' and s.stance ~= 3 then return false,false end
        if name == 'Thunder Clap' and s.stance ~= 1 then return false,false end
        local short = s.rage < (s.costs and s.costs[name] or costs[name] or 0)
        return not short,short
    end
    e.C_Spell.IsSpellInRange = function(name,unit)
        assert(unit and e.UnitExists(unit), 'invalid range read')
        if name == 'Charge' or name == 'Intercept' then return s.outOfRange or false end
        return not s.outOfRange and not (s.far and s.far[unit])
    end
    e.GetSpellCooldown = function(name)
        local info = e.C_Spell.GetSpellCooldown(name)
        if info then return info.startTime, info.duration, info.isEnabled and 1 or 0 end
    end
    e.IsUsableSpell = e.C_Spell.IsSpellUsable
    e.IsSpellInRange = function(name, unit)
        local range = e.C_Spell.IsSpellInRange(name, unit)
        if range ~= nil then return range and 1 or 0 end
    end
    j.SpellOnCD = function(name)
        return not j.RoutineAllows(name) or not e.GetSpellBookItemInfo(name)
            or (s.cd and (s.cd[name] or 0) > 0) or false
    end
    e.C_Spell.IsCurrentSpell = function(name)
        return name == 6603 and not s.noAttack or name == s.queued
    end
    j.inMeleeRange = function(unit) assert(unit); return not s.outOfRange end
    j.IsEnemyNameplateEligibleForAoE = function(unit) return not (s.excluded and s.excluded[unit]) end
    j.IsTotemUnit = function(unit) return s.totems and s.totems[unit] or false end
    j.GetGCDValues = function() return (s.gcd or 0) > 0 and s.now+s.gcd-1.5 or 0, (s.gcd or 0) > 0 and 1.5 or 0 end
    j.unitCacheBuff = function(_, name)
        if name == 'Battle Shout' then return not s.noShout end
        return s.buffs and s.buffs[name] or false
    end
    j.AreTrinketsReady = function() return s.trinket or false end
    j.checkPveInterrupt = function() return s.interrupt or false end
    j.WarriorAdaptiveContext.hasTwoHand = function() return not s.noWeapon end
    j.WarriorAdaptiveContext.canSlam = function() return not s.noSlam and not s.noWeapon end
    j.WarriorAdaptiveContext.armorDebuff = function() return s.sunderRemaining or 0, s.stacks or 0, s.expose or 0 end
    j.WarriorAdaptiveContext.debuffRemaining = function() return s.thunder or 0 end
    j.WarriorAdaptiveContext.hasAttackPowerDebuff = function() return s.demo or false end
    j.WarriorAdaptiveContext.overpower = function() return s.overpower or false end
    j.WarriorAdaptiveContext.markDiagnostics = function() end
    j.WarriorAdaptiveContext.recordDiagnostics = function(data) s.diagnostic=data end
    local completed, resets = {}, {}
    j.SwingTimer = {
        IsMainhandTimingReliable=function() return not s.unreliable end,
        GetMainhandTimeRemaining=function() return s.swing or 3.4 end,
        GetSlamTimeRemaining=function() return s.swing or 3.4 end,
        GetTimeRemaining=function() return s.swing or 3.4 end,
        GetOffhandTimeRemaining=function() return 1 end,
        GetTimeSinceLastSwing=function() return s.since or 0.1 end,
        GetLastConfirmedMainhandSwingTime=function() return s.now-(s.since or 0.1) end,
        GetLastConfirmedMainhandSwingTargetGUID=function() return s.swingGUID or s.guid or 'enemy1' end,
        RegisterResetCallback=function(_,fn) resets[#resets+1]=fn end,
        RegisterSlamCompletionCallback=function(_,fn) completed[#completed+1]=fn end,
    }
    local oldArms, oldUniversal = j.warriorArms, j.warriorUniversal
    s.oldMaintenance,s.oldSweepingOwner=j.warriorArmsPveMaintenance,j.WarriorThread3OwnsTarget
    setfenv(assert(loadfile('Routines/WarriorAdaptive.lua')),e)('OliaEyes6',j)
    local eventFrame = frames[#frames]
    function s:event(event,...)
        eventFrame.scripts.OnEvent(eventFrame,event,...)
    end
    function s:warriorEvent(event,...)
        for _,frame in ipairs(frames) do
            if frame ~= eventFrame and frame.scripts.OnEvent then frame.scripts.OnEvent(frame,event,...) end
        end
    end
    s:event('PLAYER_ENTERING_WORLD')
    function s:action(target)
        return First(j.warriorAdaptive(target or (not self.lost and 'target' or nil)))
    end
    function s:option(key,value) settings[key]=value end
    s.oldArms, s.oldUniversal, s.settings = oldArms, oldUniversal, settings
    return s,j,e
end

for count=1,10 do
    local s,j=Fixture({enemies=count,execute=true})
    s:action()
    Check(j.WarriorAdaptive.state.enemies==count,'deduplicated target/nameplate count '..count)
    Check(j.WarriorAdaptive.state.mode==(count==1 and 'single' or 'aoe'),'automatic count mode '..count)
    if count>=2 then Check(s:action()=='Sweeping Strikes','low-health enemies remain Sweeping eligible '..count) end
end
local s,j=Fixture({boss=true})
s:action(); Check(j.WarriorAdaptive.state.mode=='boss','boss recognized without conflating count')
s,j=Fixture({boss=true,enemies=3}); s:action()
Check(j.WarriorAdaptive.state.mode=='aoe' and j.WarriorAdaptive.state.boss,'boss with adds uses AoE')

for _,thread in ipairs({1,2,3,7}) do
    s,j=Fixture({thread=thread})
    Check(j.WarriorAdaptive:Owns('target'),'adaptive owns intended thread '..thread)
    Check(j.warriorArmsPveMaintenance==s.oldMaintenance,'Adaptive does not replace maintenance '..thread)
    Check(j.WarriorThread3OwnsTarget==s.oldSweepingOwner,'Adaptive does not replace Sweeping ownership '..thread)
    Check(j.warriorArms==s.oldArms and j.warriorUniversal==s.oldUniversal,'Original evaluators stay independent '..thread)
end
for _,args in ipairs({{thread=5},{fury=true}}) do
    s,j=Fixture(args); Check(not j.WarriorAdaptive:Owns('target'),'excluded class/behavior context')
end
for _,args in ipairs({{pvp=true},{instance='arena'},{instance='pvp'}}) do
    s,j=Fixture(args); Check(j.WarriorAdaptive:Owns('target'),'Adaptive now owns Arms PvP context')
end
for _,mode in ipairs({'original','wowsims'}) do
    s,j=Fixture({mode=mode})
    Check(not j.WarriorAdaptive:Owns('target'),'inactive mode falls through '..mode)
    local marker={}
    -- Actual original functions remain exposed separately for baseline tests.
    Check(type(s.oldUniversal)=='function' and type(s.oldArms)=='function','original functions retained')
end

s,j=Fixture({enemies=4,thread=3,rage=100})
Check(s:action()=='Sweeping Strikes','AoE burst begins without 80-rage owner lock')
s.enemies=1; s.now=s.now+0.2
Check(s:action()~='Sweeping Strikes' and j.WarriorAdaptive.state.mode=='single','pack shrinks immediately to single')
Check(s:action()~=nil,'single target still spends damage at full rage')
s,j=Fixture({enemies=3,options={adaptive_sweeping=false}})
Check(s:action()=='Whirlwind','three targets prioritize WW when Sweeping disabled')
s,j=Fixture({enemies=3,buffs={['Sweeping Strikes']=true}})
Check(s:action()=='Whirlwind','active Sweeping converts into WW')
s,j=Fixture({enemies=3,excluded={nameplate3=true}})
Check(s:action()~='Whirlwind' and s:action()~='Sweeping Strikes','observed CC suppresses area attacks')
s,j=Fixture({enemies=3,totems={nameplate2=true,nameplate3=true}})
s:action(); Check(j.WarriorAdaptive.state.enemies==1,'totems excluded from count')
s,j=Fixture({enemies=3,far={nameplate2=true,nameplate3=true}})
s:action(); Check(j.WarriorAdaptive.state.enemies==1,'out of melee observations not counted')

s,j=Fixture({rage=25,cd={['Mortal Strike']=4,Whirlwind=4}})
Check(s:action()=='Slam','affordable early Slam without over-reserving unrelated cooldowns')
s,j=Fixture({moving=true,rage=25,cd={['Mortal Strike']=4,Whirlwind=4}})
Check(s:action()~='Slam' and j.WarriorAdaptive.state.reason~='wait_swing','movement never reserves Slam')
s,j=Fixture({unreliable=true})
Check(s:action()~='Slam','unreliable timing forbids Slam')
s,j=Fixture({since=1.2})
Check(s:action()~='Slam','hard 1.15 second window preserved')
s,j=Fixture({swingGUID='other',rage=20,cd={['Mortal Strike']=4,Whirlwind=4}})
Check(s:action()~='Slam','old target swing cannot open new target window')
s,j=Fixture({rage=20,cd={['Mortal Strike']=4,Whirlwind=4}})
Check(s:action()=='Slam','Slam selected before consumption')
s:event('UNIT_SPELLCAST_START','player','cast1','Slam')
Check(s:action()~='Slam','cast start consumes swing opportunity')
for _,args in ipairs({{casting=true},{channel=true},{dead=true},{mounted=true}}) do
    s,j=Fixture(args); Check(s:action()==nil,'cast/death/mount guards')
end
s,j=Fixture({lost=true,noShout=true})
Check(s:action()=='Battle Shout','targetless self maintenance survives strict enemy guards')
s.noShout=false; Check(s:action()==nil,'target loss clears enemy action')
s,j=Fixture({friendly=true})
Check(s:action()==nil,'friendly target cannot receive offensive action')
s,j=Fixture({targetDead=true})
Check(s:action()==nil,'dead target cannot receive offensive action')
s,j=Fixture({noAttack=true})
Check(s:action()=='Attack','start attack available before damage')
s,j=Fixture({outOfRange=true,outOfCombat=true,stance=1})
Check(s:action()=='Charge','out of combat gap closer')
s,j=Fixture({outOfRange=true})
Check(s:action()=='Intercept','combat gap closer')
s,j=Fixture({interrupt=true,thread=3})
Check(s:action()=='Pummel','new mode handles assigned interrupt on T3')

s,j=Fixture({queued='Heroic Strike',rage=40})
Check(s:action()=='Stopcasting','unfunded HS cancelled before core starvation')
s,j=Fixture({queued='Cleave',enemies=1})
Check(s:action()=='Stopcasting','AoE-to-single cancels rather than forcibly replacing queue')
s,j=Fixture({queued='Heroic Strike',enemies=3})
Check(s:action()=='Stopcasting','single-to-AoE cancels wrong queue')
s,j=Fixture({gcd=1,rage=100,swing=0.4,since=3.1})
Check(s:action()=='Heroic Strike','funded queue available during GCD')
s,j=Fixture({gcd=1,rage=20,swing=0.4,since=3.1})
Check(s:action()==nil,'low rage cannot queue during GCD')
s,j=Fixture({blocked={Slam=true,['Mortal Strike']=true,Whirlwind=true}})
Check(s:action()==nil,'explicit false usability never treated as ready')
s,j=Fixture({missingCD={Slam=true,['Mortal Strike']=true,Whirlwind=true}})
Check(s:action()==nil,'unknown cooldown fails closed')
s,j=Fixture({queued='Heroic Strike',costs={['Heroic Strike']=12},rage=42})
Check(s:action()~='Stopcasting' and j.WarriorAdaptive.state.queuedCost==12,'talent-adjusted queue costs')

s,j=Fixture({boss=true,options={adaptive_sunder_initial=true}})
Check(s:action()=='Sunder Armor','assigned initial boss Sunder')
s.expose=20; Check(s:action()~='Sunder Armor','Expose blocks Sunder')
s,j=Fixture({options={adaptive_sunder_initial=true}})
Check(s:action()~='Sunder Armor','unknown short trash gets no speculative Sunder setup')
s,j=Fixture({boss=true,options={adaptive_sunder_stack=true},stacks=5,sunderRemaining=2})
Check(s:action()=='Sunder Armor','assigned expiring Sunder deadline')
s,j=Fixture({boss=true,options={adaptive_thunder_clap=true},rage=25,since=2})
Check(s:action()=='Battle Stance','assigned TC preparation')
s.stance=1; Check(s:action()=='Thunder Clap','TC follows its stance request')
s.thunder=20; s:event('UNIT_SPELLCAST_SUCCEEDED','player','cast2','Thunder Clap')
Check(s:action()=='Berserker Stance','support finishes and returns to damage stance')
s,j=Fixture({enemies=3,noShout=true,options={adaptive_sweeping=false}})
Check(s:action()=='Battle Shout','shout maintenance remains enabled during AoE')
s,j=Fixture({trinket=true})
Check(s:action()=='Trinkets','damage cooldowns do not require unrelated proc')
s.now=s.now+1.1
Check(s:action()~='Trinkets','failed trinket intent cannot starve damage indefinitely')
s.settings.adaptive_cooldowns=false
Check(s:action()~='Trinkets','cooldown hold switch')
s,j=Fixture({boss=true,learned={Recklessness=true},buffs={Bloodlust=true}})
Check(s:action()~='Recklessness','long cooldown defaults to player control')
s.settings.adaptive_recklessness=true
Check(s:action()=='Recklessness','explicit long cooldown permission')

-- AoE trinkets use the existing two-slot action, with their own hold switch.
for count=2,10 do
    s,j=Fixture({enemies=count,trinket=true,options={adaptive_sweeping=false,adaptive_cooldowns=false}})
    Check(s:action()=='Trinkets','AoE trinkets default on independently '..count)
    s.now=s.now+1.1
    Check(s:action()~='Trinkets','failed AoE trinkets release damage '..count)
    s.now=s.now+4
    Check(s:action()=='Trinkets','AoE trinkets retry after bounded gap '..count)
    s.settings.adaptive_aoe_trinkets=false
    s.settings.adaptive_cooldowns=true
    Check(s:action()~='Trinkets','AoE hold overrides ST cooldown switch '..count)
end
s,j=Fixture({trinket=true,options={adaptive_aoe_trinkets=false}})
Check(s:action()=='Trinkets','AoE hold does not disable single-target trinkets')
s,j=Fixture({trinket=true,enemies=3,outOfCombat=true,options={adaptive_sweeping=false}})
Check(s:action()~='Trinkets','AoE trinkets require combat')

local function RageFixture(extra)
    local args={learned={['Berserker Rage']=true},since=1.3,swing=2.2,
        cd={['Mortal Strike']=4,Whirlwind=4}}
    for key,value in pairs(extra or {}) do args[key]=value end
    return Fixture(args)
end
s,j=RageFixture()
Check(s:action()=='Berserker Rage','Berserker Rage defaults on in a safe filler gap')
s.settings.adaptive_berserker_rage=false
Check(s:action()~='Berserker Rage','Berserker Rage hold switch')
s,j=RageFixture({rage=25,since=0.1,swing=3.4})
Check(s:action()=='Slam','Berserker Rage never replaces an immediate Slam')
s,j=RageFixture({moving=true,rage=20,since=0.1,swing=0.5})
Check(s:action()=='Berserker Rage','moving allows utility when Slam cannot be cast')
for _,args in ipairs({
    {swing=0.5},{swing=0.2},{unreliable=true},{casting=true},{gcd=1},
    {buffs={['Berserker Rage']=true}},{outOfCombat=true},{lost=true},{stance=1},
    {cd={['Mortal Strike']=0,Whirlwind=4}},
    {cd={['Mortal Strike']=1,Whirlwind=4}},
    {cd={['Mortal Strike']=4,Whirlwind=1}},
    {cd={['Mortal Strike']=4,Whirlwind=4,['Berserker Rage']=10}},
    {blocked={['Berserker Rage']=true}},
}) do
    s,j=RageFixture(args)
    Check(s:action()~='Berserker Rage','utility respects timing, readiness and combat guards')
end
s,j=RageFixture({enemies=4,options={adaptive_sweeping=false}})
Check(s:action()=='Berserker Rage','utility also fills a safe AoE gap')

-- Enemy lifetime is learned over time, not inferred from a percentage threshold.
s,j=Fixture({enemies=3,rage=35,hp=90000,swing=0.2,since=3.3})
s:action(); s.now=102; s.hp=50000
Check(s:action()=='Sweeping Strikes','short pack spends affordable burst before an imminent swing')
s,j=Fixture({enemies=3,rage=35,hp=90000})
s:action(); s.now=102; s.hp=20000
Check(s:action()~='Sweeping Strikes','never buy Sweeping with no attack before pack death')
s,j=Fixture({execute=true,rage=80,cd={['Mortal Strike']=3,Whirlwind=3},moving=true})
Check(s:action()=='Execute','execute filler available with unavailable core attacks')
s,j=Fixture({execute=true,rage=80,moving=true})
Check(s:action()~='Execute','execute phase does not replace ready core attacks blindly')

s,j=Fixture({rage=10,overpower=true,cd={Whirlwind=4},since=2})
Check(s:action()=='Battle Stance','low rage Overpower preparation')
s.stance=1; Check(s:action()=='Overpower','Overpower follows stance')

-- Thread 7 now runs registered support only; class ownership cannot preempt it.
local e
s,j,e=Fixture({thread=7,casting=true})
j.GetPlayerClass=function() return 'WARRIOR' end
setfenv(assert(loadfile('Core/Engine.lua')),e)('OliaEyes6',j)
j.Engine.initialized, j.Engine.activeThread = true, 7
j.Engine.pixelReset={clear=function() end}
assert(loadfile('tests/RoutineConfigFixture.lua'))()(j,e,'WARRIOR')
local followed,classCalled=false,false
j.Engine.rotation={
    dpsRotate=function() classCalled=true;return false end,
    rotate=function() followed=true;return true end,
}
j.Engine:ProcessRotation()
Check(followed and not classCalled,'T7 selects support only even with Adaptive selected')
followed=false;s.casting=false;s.rage=0
j.Engine:ProcessRotation()
Check(followed and not classCalled,'class pooling is absent from support-only T7')

s,j,e=Fixture({rage=20,cd={['Mortal Strike']=4,Whirlwind=4}})
e.OliaArmsLog.enabled=true
Check(s:action()=='Slam' and s.diagnostic.slamRecommended,'existing Arms diagnostics receive new-mode recommendations')

for _,speed in ipairs({1.0,1.4,2.0,3.5}) do
    s,j=Fixture({speed=speed,swing=speed-0.1})
    local action=s:action()
    Check(action=='Slam' or action=='Mortal Strike' or action=='Whirlwind','haste retains a funded damage action')
end
s,j=Fixture({rage=0,thread=3})
for i=1,30 do
    s.now=s.now+0.1; s.rage=math.min(100,i*4)
    s:action()
end
Check(s:action()~=nil,'T3 rage recovery cannot remain in legacy indefinite pooling')

local function Snapshot(routine)
    local result={}
    for i,row in ipairs(routine) do result[i]=tostring(row[1])..':'..tostring(row[2])..':'..tostring(row[3]) end
    return table.concat(result,'|')
end
for _,mode in ipairs({'original','wowsims'}) do
    for _,thread in ipairs({1,2,3,7}) do
        for _,count in ipairs({1,3}) do
            s,j=Fixture({mode=mode,thread=thread,enemies=count})
            local before=Snapshot(s.oldUniversal('target'))
            Check(Snapshot(j.warriorUniversal('target'))==before,'inactive wrapper preserves all rows '..mode..' T'..thread..' N'..count)
        end
    end
end

print('Adaptive Arms: '..checks..' scenario checks passed (mocked game APIs).')
