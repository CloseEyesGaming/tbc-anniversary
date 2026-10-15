-- Compare actual compiled Warrior placements to an exact checkpoint. Lua 5.1.
local baseline=assert(...,'Pass the exact pre-behavior checkpoint directory')
local checks,evaluations=0,0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local function Read(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function Copy(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=Copy(x) end;return out end
local originalLoadfile,originalOpen=loadfile,io.open
local function WithSource(root,fn,...)
    if root then
        loadfile=function(path) return originalLoadfile(root..'/'..path) end
        io.open=function(path,mode) return originalOpen(root..'/'..path,mode) end
    end
    local ok,a,b,c=pcall(fn,...)
    loadfile,io.open=originalLoadfile,originalOpen
    assert(ok,a);return a,b,c
end
local function Build()
    local source=Read('tests/WarriorAdaptive.test.lua');local stop=assert(source:find('for count=1,10 do',1,true))
    local Fixture=assert(loadstring(source:sub(1,stop-1)..'\nreturn Fixture'))()
    local Attach=assert(loadfile('tests/RoutineConfigFixture.lua'))()
    local hotkeys=Read('Core/Hotkeys.lua');hotkeys=hotkeys:sub(1,assert(hotkeys:find('function Hotkeys:CreateStaticBar()',1,true))-1)
    return function(case,id,mode,policy,physical)
        local input=Copy(case);input.thread=2;input.mode=mode
        local s,j,e=Fixture(input);e.IsEquippedItemType=function() return false end
        setfenv(assert(loadstring(hotkeys)),e)('OliaEyes6',j)
        local threads={{},{},{},{},{},{},{}}
        threads[physical]={{id=id,enabled=true,policy=policy,mode=mode,steps=case.steps or {},options=case.options or {}}}
        e.OliaEyes6_Settings={schemaVersion=1,characters={['Fixture - Realm']='comparison'},profiles={comparison={classes={WARRIOR={threads=threads,migrated=true,options=case.legacy or {}}}}}}
        local c=Attach(j,e,'WARRIOR');local engine=j.Engine;engine.activeThread=physical
        local rows,actions={},{}
        engine.rotation={dpsRotate=function(_,functions)
            for _,fn in ipairs(functions) do
                local target=not s.lost and 'target' or nil
                local result=fn(target);Check(type(result)=='table','evaluator row result')
                local snapshot={};local action
                for index,row in ipairs(result) do
                    local metadata=type(row[4])=='function' and 'function' or tostring(row[4])
                    snapshot[#snapshot+1]=index..':'..tostring(row[1])..':'..tostring(row[2])..':'..tostring(not not row[3])..':'..metadata
                    if not action and row[3] and j.RoutineAllows(row[2]) then
                        if not j.RoutineContext.definition.stepByID[row[2]] then j.RoutineContext.invalid='undeclared';break end
                        action=row[2]
                    end
                end
                rows[#rows+1]=table.concat(snapshot,'\n')
                if j.RoutineContext.invalid then return false end
                if action then actions[#actions+1]=action;return true end
            end
            actions[#actions+1]='<no eligible row>';return false
        end}
        local held={};local eligible=true;local retired=#c.plans[physical]==0
        for tick=1,3 do
            s.now=100+(tick-1)*.2
            if case.sequence and case.sequence[tick] then for key,value in pairs(case.sequence[tick]) do s[key]=Copy(value) end end
            local entry=c.plans[physical][1]
            if entry then
                j.RoutineContext=entry
                if entry.definition.algorithm=='wowsims' then eligible=eligible and j.WarriorWowsimsOwns(not s.lost and 'target' or nil)
                elseif entry.definition.algorithm=='adaptive' then eligible=eligible and j.WarriorAdaptive:Owns(not s.lost and 'target' or nil) end
                j.RoutineContext=nil
            end
            held[tick]=tostring(not not c:Run(engine));evaluations=evaluations+1
            Check(j.RoutineContext==nil,'dispatch clears context')
        end
        local diagnostic=c.errors[physical..':1'] or ''
        return table.concat(rows,'\n---\n'),table.concat(actions,' -> ')..' / '..table.concat(held,',')..' / '..diagnostic,eligible,retired
    end
end
local old=WithSource(baseline,Build);local new=Build()
local cases={
    {name='single',rage=80}, {name='aoe',rage=80,enemies=3},
    {name='sweeping-active',enemies=3,buffs={['Sweeping Strikes']=true}},
    {name='core-cooldown',cooldowns={['Mortal Strike']=true,Whirlwind=true}},
    {name='moving',moving=true}, {name='battle-stance',stance=1},
    {name='pvp',pvp=true}, {name='fury',fury=true}, {name='missing-enemy',lost=true},
    {name='disabled-slam',steps={Slam=false}}, {name='disabled-sweeping',enemies=3,steps={['Sweeping Strikes']=false}},
    {name='target-transitions',sequence={{lost=false},{lost=true},{lost=false,moving=true}}},
    {name='old-false-preferences',legacy={thread1_thunder_clap=false,thread1_demoralizing_shout=false,thread2_sweeping_strikes=false,thread3_sunder_fallback=false}},
}
for _,case in ipairs(cases) do
    for _,mode in ipairs({'original','wowsims','adaptive'}) do
        for _,policy in ipairs({1,2,3,5}) do
            local id='warrior.'..mode
            local oldRows,oldChoice=WithSource(baseline,old,case,id,mode,policy,2)
            local newRows,newChoice,eligible,retired=new(case,id,mode,policy,2)
            if retired then
                Check(newRows=='' and newChoice:find('false,false,false',1,true),'retired fallback never evaluates: '..mode..'/'..policy)
            elseif eligible then
                Check(oldRows==newRows,'owned ordered rows preserved: '..case.name..'/'..mode..'/'..policy)
                Check(oldChoice==newChoice,'owned action/wait outcome preserved: '..case.name..'/'..mode..'/'..policy)
            else
                -- Intentional removal of Original/Fury substitutions is checked by
                -- RoutineIsolation; do not compare with the removed algorithm.
                Check(newRows=='' or newChoice:find('<no eligible row>',1,true),'ineligible algorithm does not select damage')
            end
            for _,physical in ipairs({1,3,4,5,6}) do
                local movedRows,movedChoice=new(case,id,mode,policy,physical)
                Check(movedRows==newRows and movedChoice==newChoice,'definition behavior independent of thread: '..case.name..'/'..mode..'/'..policy..'/'..physical)
            end
        end
    end
end
-- Every old definition/policy/mode combination must retain its evaluator/hold behavior.
for _,id in ipairs({'warrior.arms','warrior.fury','warrior.tank','warrior.maintenance','warrior.sweeping'}) do
    for _,mode in ipairs({'original','wowsims','adaptive'}) do
        for policy=1,7 do
            local case={name='all-imports',enemies=3,rage=80}
            local a,b=WithSource(baseline,old,case,id,mode,policy,4)
            local x,y=new(case,id,mode,policy,4)
            local redirectedAdaptive=mode=='adaptive' and (id=='warrior.arms' or id=='warrior.maintenance' or id=='warrior.sweeping') and (policy<=3 or policy==7)
            local coupledWowsims=mode=='wowsims' and id=='warrior.maintenance' and policy<=3
            if not redirectedAdaptive and not coupledWowsims then
                Check(a==x and b==y,'independent specialized import parity: '..id..'/'..mode..'/'..policy)
            end
            local fixedRows,fixedChoice=new(case,id,'original',policy,4)
            Check(x==fixedRows and y==fixedChoice,'specialized algorithm cannot be redirected by saved mode: '..id..'/'..mode..'/'..policy)
        end
    end
end
print('RoutineBehaviorParity: '..checks..' checks; '..evaluations..' compiled routine evaluations checked for owned parity, retirement and routing independence (mocked client).')
