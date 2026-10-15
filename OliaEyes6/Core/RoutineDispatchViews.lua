local AddonName, jungle = ...
local Config = jungle.RoutineConfig
-- Static projections of authored dispatch branches. Never run evaluators here.
local shared = "Preview the routine's own branches. A checkbox controls that action in every branch of this placement. Conditions still determine eligibility and priority."
local function Section(label, when, steps, description)
    return {label=label,when=when,steps=steps or {},description=description or shared}
end
local function View(id,label,sections,options,description)
    return {id=id,label=label,sections=sections,options=options,description=description or shared}
end
local function Range(first,last)
    local list={};for i=first,last do list[#list+1]=i end;return list
end
local function Join(a,b)
    local result={};for _,v in ipairs(a) do result[#result+1]=v end;for _,v in ipairs(b) do result[#result+1]=v end;return result
end
local function Indices(name,omit)
    local result={}
    for i,row in ipairs(Config.rows[name].rows) do if not omit or not omit[row[2]] then result[#result+1]=i end end
    return result
end
local function Action(def,id,onlySchema)
    local descriptions={}
    for _,name in ipairs(def.rowSets) do
        if not onlySchema or name==onlySchema then
            local schema=Config.rows[name]
            for i,row in ipairs(schema.rows) do if row[2]==id then descriptions[#descriptions+1]=row[1]..": "..schema.descriptions[i] end end
        end
    end
    for _,step in ipairs(def.extraSteps or {}) do if step.id==id then descriptions[#descriptions+1]=step.description or "" end end
    return {id=id,description=table.concat(descriptions,"\n")}
end
local function Project(def,label,name,indices,when,extras,description)
    local schema=Config.rows[name];local steps={}
    for _,key in ipairs(indices or Indices(name)) do
        local step
        if type(key)=="number" then
            local row=assert(schema.rows[key],"Missing display row "..name..":"..key)
            if row[2]~="" then step={id=row[2],description=row[1]..": "..schema.descriptions[key]} end
        else
            step=Action(def,type(key)=="table" and key.id or key,name)
            if type(key)=="table" then for field,value in pairs(key) do step[field]=value end end
        end
        if step then steps[#steps+1]=step end
    end
    for _,step in ipairs(extras or {}) do steps[#steps+1]=step end
    return Section(label,when,steps,description)
end
local function Equipment(def,prefix,when)
    local sections={}
    for _,name in ipairs(def.rowSets) do
        if name:find(prefix,1,true)==1 then
            local condition=when
            if name=="Warrior.equipCacheFastOffHand" then condition="PvE Fury; fewer than 2 eligible enemies; fast off-hand available"
            elseif name=="Warrior.equipCacheSlowOffHand" then condition="PvE Fury; 2+ eligible enemies; slow off-hand available" end
            sections[#sections+1]=Project(def,"Equipment / "..Config.rows[name].rows[1][2],name,nil,condition)
        end
    end
    return sections
end
local function DruidDPS(def)
    local function Forms(pvp)
        local sections={}
        if pvp then
            sections[#sections+1]=Project(def,"Caster / Moving","Druid.dpsPvPCasterCache",{1,2,3,6},"PvP-flagged enemy; caster form and moving",{
                {id="Moonfire",summary="Moving: apply; refresh after debuff setup"},
                {id="Insect Swarm",summary="Moving: apply a missing effect"},
                {id="Faerie Fire",summary="After both damage-over-time effects"},
            })
            sections[#sections+1]=Project(def,"Caster / Stationary","Druid.dpsPvPCasterCache",{4,5,6},"PvP-flagged enemy; caster form and stationary")
        else
            sections[#sections+1]=Project(def,"Moonkin / Moving","Druid.dpsCasterCache",{3,4,5,8},"Moonkin form; PvE enemy; moving")
            sections[#sections+1]=Project(def,"Moonkin / Stationary","Druid.dpsCasterCache",{3,4,6,7,8},"Moonkin form; PvE enemy; stationary",nil,
                "Moonweaving chooses Wrath/Starfire from melee attackers, tracked fallback, confirmed-swing windows and damage-school immunity. Faerie Fire uses the boss/skull Improved-debuff rule.")
            sections[#sections+1]=Project(def,"Caster / Moving","Druid.dpsCasterCache",{4,5,8},"Other caster form; PvE enemy; moving")
            sections[#sections+1]=Project(def,"Caster / Stationary","Druid.dpsCasterCache",{4,6,7,8},"Other caster form; PvE enemy; stationary")
        end
        sections[#sections+1]=Project(def,"Cat / Stealth","Druid.dpsCatStealthCache",nil,"Cat form and stealthed; shared across target counts")
        sections[#sections+1]=Project(def,"Cat / Mangle","Druid.dpsCatCache",nil,"Cat form, visible; Mangle learned and enabled")
        sections[#sections+1]=Project(def,"Cat / Claw","Druid.dpsCatCache",{1,2,3,4,5,"Claw",7,8,9},"Cat form, visible; Mangle unavailable or disabled")
        for _,aoe in ipairs({false,true}) do
            local label=aoe and "Bear / AoE" or "Bear / Single target"
            local when=aoe and "Bear form; 2+ eligible melee enemies" or "Bear form; fewer than 2 eligible melee enemies"
            local first=aoe and {1,2} or {2}
            sections[#sections+1]=Project(def,label.." / Mangle","Druid.dpsBearCache",Join(first,{3,4,5,6,7}),when.."; Mangle learned and enabled")
            sections[#sections+1]=Project(def,label.." / Lacerate","Druid.dpsBearCache",Join(first,{"Lacerate",4,6,7}),when.."; Mangle unavailable or disabled")
        end
        sections[#sections+1]=Project(def,"Powershift return","Druid.dpsPowershiftCache",nil,"Caster form inside the active Cat return window")
        sections=Join(sections,Equipment(def,"Druid.dpsWeapon","Form-based FAT or Moonkin battery/velocity prepass; before damage"))
        return sections
    end
    return {View("pve","PvE",Forms(false)),View("pvp","PvP",Forms(true))}
end
local function Arms(def,pvp)
    local name=pvp and "Warrior.warriorArmsPvPCache" or "Warrior.warriorArmsCache"
    if pvp then
        local extras={{id="Shield Bash",after="Pummel",summary="Shield interrupt when already equipped"},
            {id="Slam",before="Hamstring",summary="Eligible after-swing Slam replaces the slow row"},{id="Commanding Shout"}}
        local single=Project(def,"Arms / Single target",name,Indices(name,{["Sweeping Strikes"]=true}),"Fewer than 2 nearby hostile players/pets",extras)
        -- AoE uses the dynamic Slam alternative; its single-target Hamstring is ineligible.
        local area=Project(def,"Arms / AoE",name,Join(Range(1,7),Join({"Slam"},Range(9,26))),"2+ nearby hostile players/pets",{
            {id="Shield Bash",after="Pummel",summary="Shield interrupt when already equipped"},{id="Commanding Shout"},
        })
        return {single,area}
    end
    local common={1,2,"Thunder Clap","Battle Stance","Overpower","Stopcasting",4,5,6,7,8,9,10,11,12,14,15,16,"Commanding Shout",17,18,19,20,21,22}
    local sections={Project(def,"Arms / Single target",name,common,"Fewer than 2 eligible nearby enemies")}
    if def.behavior.coreFirstAoE then
        local tail={"Execute",11,12,14,15,18,19,20,21,22}
        sections[#sections+1]=Project(def,"Arms / AoE / Sweeping inactive",name,
            Join({1,2,"Demoralizing Shout","Slam","Sweeping Strikes","Whirlwind","Stopcasting","Cleave","Mortal Strike"},tail),
            "2+ enemies; core-first behavior; Sweeping Strikes not active",nil,
            "AoE slots become Slam, Sweeping Strikes, Whirlwind, queue cleanup/Cleave, Mortal Strike. Early Demo and lethal Execute may preempt; all normal cast/resource guards remain.")
        sections[#sections+1]=Project(def,"Arms / AoE / Sweeping active",name,
            Join({1,2,"Demoralizing Shout","Slam","Whirlwind","Stopcasting","Cleave","Mortal Strike"},tail),
            "2+ enemies; core-first behavior; Sweeping Strikes active")
    else
        sections[#sections+1]=Project(def,"Arms / AoE",name,Join({3,13},common),"2+ enemies; this definition uses the general AoE priority")
    end
    return sections
end
local function Fury(def,pvp)
    local name=pvp and "Warrior.warriorFuryPvPCache" or "Warrior.warriorFuryCache"
    local sections={}
    for _,aoe in ipairs({false,true}) do for _,bt in ipairs({true,false}) do
        local label="Fury / "..(aoe and "AoE" or "Single target").." / "..(bt and "Bloodthirst" or "Mortal Strike")
        local when=(aoe and "2+ eligible nearby enemies" or "Exactly 1 eligible nearby enemy").."; "..(bt and "Bloodthirst build" or "Mortal Strike learned; no Bloodthirst")
        local indices
        if pvp then
            indices=Join(Range(1,19),aoe and {20,21,24,25,26,27,28} or {22,23,24,25,27,28})
            if not aoe then for i=#indices,1,-1 do if indices[i]==16 then table.remove(indices,i) end end end
            if not bt then for i,key in ipairs(indices) do if key==9 or key==21 or key==22 then indices[i]="Mortal Strike" end end end
        else
            local first=aoe and (bt and {1,5,34,6,7,8,10} or {1,5,34,6,7,8,9,"Mortal Strike"})
                or (bt and {1,2,3,5,34} or {1,"Whirlwind","Execute","Mortal Strike",5,34})
            indices=Join(first,Range(11,33))
            if not bt then for i,key in ipairs(indices) do if key==21 then indices[i]="Mortal Strike" end end end
        end
        sections[#sections+1]=Project(def,label,name,indices,when,{{id="Commanding Shout"}},
            "Own heavy-hitter selection and single-target/AoE queue/core priority. Lethal Execute, stance preparation, queue cancellation and swing desynchronization can preempt normal damage.")
    end end
    return sections
end
local function Warrior(def)
    local algorithm=def.algorithm;local pve,pvp={},{}
    if algorithm=="original" or algorithm=="arms" or algorithm=="fury" then
        if algorithm~="fury" then pve=Arms(def,false);pvp=Arms(def,true) end
        if algorithm~="arms" then pve=Join(pve,Fury(def,false));pvp=Join(pvp,Fury(def,true)) end
        pve=Join(pve,Equipment(def,"Warrior.equip","Spec equipment prepass; Fury also selects fast/slow off-hand by enemy count"))
        for _,name in ipairs(def.rowSets) do
            if name=="Warrior.equipCache2H" or name=="Warrior.equipCacheDW" then
                pvp[#pvp+1]=Project(def,"Equipment / "..Config.rows[name].rows[1][2],name,nil,"Equipment prepass before this spec's damage")
            end
        end
    elseif algorithm=="kebab" then
        local name="Warrior.kebab"
        -- The evaluator selects early returns, not the reusable row-array order.
        -- Merge repeated stance rows into one switch; document conditional priority.
        local summaries={
            Stopcasting="Clear unwanted queue; never interrupt a cast",
            Attack="Start autoattack on the melee enemy",
            ["Berserker Stance"]="Prepare Pummel, Intercept or melee damage",
            Pummel="Interrupt the selected melee NPC",
            ["Battle Stance"]="Prepare an eligible enabled Charge",
            Charge="Guarded gap closer outside melee",
            Intercept="Guarded gap closer outside melee",
            Bloodrage="In combat, at 90 rage or below",
            ["Battle Shout"]="Selected shout missing or <=5s left",
            ["Commanding Shout"]="Selected shout missing or <=5s left",
            ["Sunder Armor"]="Init/Stack: missing or <=3s first; extra stacks as filler",
            ["Demoralizing Shout"]="Preference on: missing or <=5s before damage",
            ["Death Wish"]="Automatic cooldown; fund imminent core",
            Recklessness="Opt-in boss burst in Berserker Stance",
            Trinkets="Automatic on-use burst; bounded retries",
            ["Heroic Strike"]="Normal queue: HS + due MS/WW costs; Execute opt-in",
            ["Mortal Strike"]="ST first core; AoE spare rage; Execute opt-in",
            Whirlwind="Safe area; AoE first core; Execute preference",
            Execute="Target <=20%; spend after enabled cores",
            Hamstring="Normal: full 1.5s gap; protect cores and funded HS",
            ["Victory Rush"]="Free melee filler in >=1.5s core gap",
            ["Berserker Rage"]="Opt-in Normal combat utility; >=1.5s gap",
            ["Sweeping Strikes"]="Safe AoE; fund now or pool for ready SS",
            Cleave="Off GCD; fund new queue; Execute opt-in",
        }
        local common="Queued HS/Cleave uses no GCD and has not spent rage: abilities use current rage. GCD abilities still need a ready global. Assigned Demo, then missing/<=3s Sunder maintenance run before damage, including Execute and queued HS/Cleave. After maintenance, ready Normal single-target cores run before Bloodrage, self buffs, burst and new HS queues; permitted Execute cores have this early priority with HS queued. Healthy Sunder stacking is a later funded filler after cores/free Victory Rush; its single switch appears here beside urgent maintenance. Timed cleanup precedes interrupts; ordinary cleanup follows them. Shared action switches apply throughout this placement."
        pve={
            Project(def,"PvE Single target",name,{1,3,4,5,6,7,8,9,2,14,13,19,20,10,11,12,15,16,17,18,24,21,23,22},
                "PvE DW Arms; fewer than 2 safe eligible melee enemies, or area blocked; includes Execute",nil,
                common.." Normal: MS before WW, both before new HS. Keep HS queued while pooling; allow payment only with exact upcoming core costs retained, no rage buffer. Shared GCD never removes the second ready/closely due core from funding. Normal ordinary GCD buffs wait for a ready GCD and >=1.5s core gap after any current GCD remainder; trinkets remain off GCD without this hold; optional spending also retains any already funded queued HS payment. Temporary queues use confirmed MH timing; affordable unpaid HS cancels at the MH deadline. HS admission precedes optional Berserker Rage and paid fillers. Execute at <=20%: MS opt-in, WW follows its preference, HS opt-in; Hamstring/Berserker Rage only outside Execute; assigned debuff maintenance continues. Excluded enemies block WW and Demo. No enemy: only queue cleanup and selected shout maintenance. Gap closers require an enemy outside melee."),
            Project(def,"PvE AoE",name,{1,3,4,5,6,7,8,9,2,14,13,10,11,12,15,16,17,24,25,26,20,19,21,23},
                "PvE DW Arms; 2+ observed eligible melee enemies and no excluded enemy; includes Execute",nil,
                common.." Fund ready Sweeping Strikes, admit a funded new Cleave, then WW before spare-rage MS. Existing Cleave does not withhold rage or cancel just for low rage. Execute: MS opt-in, WW follows its preference, Cleave separately opt-in; Berserker Rage only outside Execute; assigned debuff maintenance continues. No HS or Hamstring. Count drop or excluded enemy resumes single target after obsolete queue cleanup."),
        }
        pvp={Section("Unavailable","PvP, player-controlled enemy, missing Mortal Strike, Bloodthirst, missing DW, dead or mounted",Project(def,"Queue cleanup",name,{1},"Only an already observed HS or Cleave queue").steps,
            "Kebab releases these contexts after required cleanup of an observed HS or carried Cleave queue. Only an explicitly later placement can run.")}
        for _,sections in ipairs({pve,pvp}) do
            for _,section in ipairs(sections) do
                for _,step in ipairs(section.steps) do
                    step.summary=assert(summaries[step.id],"Missing Kebab step summary")
                    if step.id=="Stopcasting" then step.label="Queue cleanup"
                    elseif step.id=="Mortal Strike" then
                        step.summary=section.label=="PvE AoE" and "After WW; protect imminent WW; Execute opt-in"
                            or "Normal: first core; Execute: preference required"
                    elseif step.id=="Whirlwind" then
                        step.summary=section.label=="PvE AoE" and "First damage core; Execute follows preference"
                            or "Safe area; Normal after MS; Execute preference"
                    end
                end
            end
        end
    elseif algorithm=="wowsims" then
        pve={Project(def,"WoWSims single target","Warrior.rows",nil,"Eligible PvE Arms; fewer than 2 eligible enemies",{{id="Commanding Shout"},{id="Stopcasting"}}),
            Project(def,"WoWSims AoE","Warrior.wowsimsAoE",nil,"Eligible PvE Arms; 2+ eligible enemies",{{id="Commanding Shout"},{id="Stopcasting"}})}
        pvp={Section("Unavailable","PvP or player-controlled target",{},"WoWSims returns no action here; it does not select another algorithm.")}
    elseif algorithm=="adaptive" then
        local planner="The planner chooses current/follow-up damage and deliberate waits; this is not a fixed numbered rotation. Boss recognition and AoE coverage affect resource and cooldown decisions."
        pve={Project(def,"Adaptive / Single target","Warrior.adaptivePve",Indices("Warrior.adaptivePve",{["Sweeping Strikes"]=true,Cleave=true,Recklessness=true}),"AoE inactive; no recognized boss; safe enemy observations",nil,planner),
            Project(def,"Adaptive / Boss","Warrior.adaptivePve",Indices("Warrior.adaptivePve",{["Sweeping Strikes"]=true,Cleave=true}),"AoE inactive; recognized boss; safe enemy observations",nil,planner),
            Project(def,"Adaptive / AoE","Warrior.adaptivePve",Indices("Warrior.adaptivePve",{["Heroic Strike"]=true,Overpower=true}),"2+ eligible enemies; safe area; includes bosses with adds",nil,planner)}
        pve[#pve+1]=Project(def,"Adaptive / AoE blocked","Warrior.adaptivePve",Indices("Warrior.adaptivePve",{["Sweeping Strikes"]=true,Cleave=true,Whirlwind=true,["Demoralizing Shout"]=true}),"Nearby excluded enemy blocks area damage; single/boss planner",nil,planner)
        pve[#pve+1]=Section("No selected enemy","No live enemy; player shout maintenance only",{Action(def,"Battle Shout"),Action(def,"Commanding Shout")})
        pvp={Project(def,"Adaptive / Single target","Warrior.adaptivePvp",Indices("Warrior.adaptivePvp",{["Sweeping Strikes"]=true,Cleave=true}),"PvP context; AoE inactive; safe enemy observations",nil,planner),
            Project(def,"Adaptive / AoE","Warrior.adaptivePvp",Indices("Warrior.adaptivePvp",{["Heroic Strike"]=true}),"PvP context; 2+ eligible enemies; safe area",nil,planner),
            Project(def,"Adaptive / AoE blocked","Warrior.adaptivePvp",Indices("Warrior.adaptivePvp",{["Sweeping Strikes"]=true,Cleave=true,Whirlwind=true}),"PvP context; nearby excluded enemy blocks area damage",nil,planner),
            Section("No selected enemy","PvP instance without live enemy; player shout maintenance only",{Action(def,"Battle Shout"),Action(def,"Commanding Shout")}),
            Section("Equipment","Two-hand weapon missing; interrupts/gap closers may precede",{Action(def,"Equip2H")})}
    elseif algorithm=="tank" then
        local name="Warrior.warriorTankCache"
        return {View("shared","Steps",{
            Project(def,"Tank / Single target",name,Indices(name,{Cleave=true}),"Exactly 1 observed melee enemy",{{id="Sunder Armor",after="Devastate"},{id="Bloodthirst",after="Shield Slam"},{id="Mortal Strike",after="Bloodthirst"},{id="Commanding Shout"},{id="Stopcasting",before="Trinkets"}},
                "Shared PvE/PvP table. Heavy hitter: learned/enabled Shield Slam, else Bloodthirst, else Mortal Strike. Armor action: Devastate when learned, otherwise Sunder Armor."),
            Project(def,"Tank / AoE",name,nil,"2+ observed melee enemies",{{id="Sunder Armor",after="Devastate"},{id="Bloodthirst",after="Shield Slam"},{id="Mortal Strike",after="Bloodthirst"},{id="Commanding Shout"},{id="Stopcasting",before="Trinkets"}}),
            Project(def,"Tank / No selected enemy",name,{6,7,8,9,10,11,12,14,20,21,"Stopcasting"},"No selected enemy; self/observed-area guards still apply",{{id="Commanding Shout"}}),
            Project(def,"Equipment","Warrior.equipCacheShield",nil,"Shield missing; before tank rows"),
        })}
    elseif algorithm=="sweeping" then
        local function Phases(scheduled,pvp)
            local name="Warrior.warriorThread3Cache";local prefix=scheduled and "Arms schedule" or "Unscheduled"
            local scope=scheduled and "PvE Arms" or (pvp and "PvP target; schedule disabled" or "PvE Fury build; schedule disabled")
            return {
                Project(def,prefix.." / Single overflow",name,{1,2,3,4,5,11,"Mortal Strike",15,16},scope.."; Sweeping inactive; fewer than 2 enemies"),
                Project(def,prefix.." / AoE pooling",name,{1,2,3,4,5,6,7,8,9,"Stopcasting",11,15,16,17},scope.."; Sweeping inactive; 2+ enemies"),
                Project(def,prefix.." / Burst",name,{1,2,3,4,5,6,7,8,10,"Stopcasting",11,12,13,14,"Mortal Strike",15,16,17},scope.."; Sweeping active, including enemy-count drops"),
            }
        end
        pve=Join(Phases(true),Phases(false));pvp=Phases(false,true)
    else return end
    local pveOptions,pvpOptions={},{}
    for _,option in ipairs(def.options or {}) do
        pveOptions[#pveOptions+1]=option.key
        if algorithm~="wowsims" and algorithm~="kebab" and (not option.key:find("^adaptive_") or option.key=="adaptive_sweeping") then pvpOptions[#pvpOptions+1]=option.key end
    end
    return {View("pve","PvE",pve,pveOptions),View("pvp","PvP",pvp,pvpOptions)}
end
local function V6(def,scheduler)
    local name="Druid.univHealCacheV6";local sections={}
    if scheduler then
        sections={Project(def,"Raid scheduler / Emergency",name,Join({1,2,3,4,"Regrowth"},{7,8,9,11,12,13,16,19,20,21}),"In combat with Lifebloom learned; emergency or actual HP <=35%"),
            Project(def,"Raid scheduler / Maintenance",name,{3,5,6,10,13,14,15,16,17,18},"After emergencies; due blooms and tank maintenance"),
            Project(def,"Raid scheduler / Additional healing",name,{7,8,9,11,12,13,16,19,20,21,"Regrowth"},"After maintenance; compare people by actual HP"),
            Project(def,"Raid scheduler / Filler",name,{22,27},"After all higher stages; remaining Lifebloom opportunities")}
    end
    local scope=scheduler and "Outside combat or Lifebloom not learned" or "Legacy unit selection; no raid-stage dispatcher"
    sections[#sections+1]=Project(def,"Unit selection / Emergency",name,{1,2,3,4,"Regrowth"},scope.."; emergency thresholds")
    sections[#sections+1]=Project(def,"Unit selection / Boss tank",name,{5,10,13,14,15,"Rejuvenation"},scope.."; actively tanking a boss")
    sections[#sections+1]=Project(def,"Unit selection / Trash tank",name,{6,10,16,17,18,"Rejuvenation"},scope.."; actively tanking other enemies")
    sections[#sections+1]=Project(def,"Unit selection / Raid",name,{7,8,9,11,12,19,20,21,22},scope.."; non-tank healing and bloom filler")
    sections[#sections+1]=Project(def,"Unit selection / Out of combat",name,{23,24,25,26,27},"Out of combat; maintained tank/raid rules")
    return sections
end
function jungle.RoutineDispatchViews(def)
    local id=def.legacyBase or def.id
    if id=="druid.dps" then return DruidDPS(def) end
    if id=="druid.idle" then return {View("shared","Steps",{
        Project(def,"Cat / Bear equipment","Druid.dpsIdleWeaponCache",{1},"Player context; Cat/Bear form; no live DPS enemy; request FAT"),
        Project(def,"Moonkin equipment","Druid.dpsIdleWeaponCache",{1,2},"Player context; Moonkin form; no live DPS enemy; Battery/Velocity hysteresis and melee observations"),
    })} end
    if def.class=="WARRIOR" then return Warrior(def) end
    if id=="druid.v6" or id=="druid.v6Legacy" then return {View("shared","Steps",V6(def,id=="druid.v6"))} end
    if id=="druid.dispelHeal" then return {View("shared","Steps",Join({Project(def,"Dispel","Druid.dispellCache",nil,"Friendly unit with poison/curse")},V6(def,false)))} end
    if id=="druid.legacyHeal" then
        return {View("pve","PvE",{Project(def,"PvE healing","Druid.pveHealCache",nil,"Outside battleground/arena instances",def.extraSteps)}),
            View("pvp","PvP",{Project(def,"PvP healing","Druid.pvpHealCache",nil,"Battleground or arena instance")})}
    end
    if id=="druid.raidCombined" then return {View("shared","Steps",{
        Project(def,"Tank healing","Druid.tankRollCache2",nil,"Tank-marked friendly unit; joint row priority"),
        Project(def,"Raid healing","Druid.raidHealCache2",nil,"Non-tank friendly unit; joint row priority",def.extraSteps),
    })} end
    if id=="rogue.dps" then return {View("shared","Steps",{
        Project(def,"Stealth","Rogue.dpsRogueCache",{2},"Stealthed; dagger, behind and combo-point/readiness conditions"),
        Project(def,"Visible / Dagger behind","Rogue.dpsRogueCache",{1,2,3,4},"Not stealthed; dagger and behind target",{{id="Sinister Strike",summary="Only when Backstab is disabled"}}),
        Project(def,"Visible / Other weapon or position","Rogue.dpsRogueCache",{1,3,4},"Not stealthed; no dagger or not behind"),
    })} end
    if id=="support.follower" then return {View("shared","Steps",{
        Project(def,"Rest","Follower.followerCache",{1,2,3},"Low mana outside combat; food/drink and movement guards"),
        Project(def,"Druid / Tree of Life","Follower.followerCache",{4},"Druid; combat healing needed; form known; not resting/mounted/casting"),
        Project(def,"Travel / Flying","Follower.followerCache",{5,6,7},"Flying mount mode: flyable Outland zone and class-specific level; mount mirrors driver. Follow/stop also work when mounting is blocked"),
        Project(def,"Travel / Ground","Follower.followerCache",{5,6,7},"Ground mount mode: flying mode unavailable; mount mirrors driver. Follow/stop also work when mounting is blocked"),
        Project(def,"Driverless self maintenance","Follower.followerCache",{1,2,3,4},"No valid friendly driver; self context; no follow or mirrored mount"),
    })} end
    if id=="support.fishing" then return {View("shared","Steps",{
        Section("Casting wait","Player already casting",{},"Returns no action and records the existing lure grace/attempt state."),
        Section("Lure missing","No main-hand enchant and no grace/retry/channel block",{Action(def,"Lure"),Action(def,"Fishing")}),
        Section("Lure present or suppressed","Enchant, 15-second grace, bounded retry or channel gate",{Action(def,"Fishing")}),
    })} end
end
