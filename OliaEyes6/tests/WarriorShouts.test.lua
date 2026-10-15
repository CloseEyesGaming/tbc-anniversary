-- Standalone Lua 5.1 checks of all six DPS shout paths, with the real cache reader.
-- Game APIs are mocked; this file is not loaded by the addon TOC.
local function Read(path)
    local f = assert(io.open(path)); local s = f:read('*a'); f:close(); return s
end
local function Prefix(path, boundary, result)
    local s = Read(path)
    return assert(loadstring(s:sub(1, assert(s:find(boundary, 1, true)) - 1) .. '\nreturn ' .. result))()
end
local Context = Prefix('tests/WarriorOptions.test.lua', 'local function Snapshot(rows)', 'Context')
local Wowsims = Prefix('tests/WarriorWowsims.test.lua', '-- Default-off is identical', 'Fixture')
local Adaptive = Prefix('tests/WarriorAdaptive.test.lua', 'for count=1,10 do', 'Fixture')
local cacheSource = Read('UnitsData.lua')
cacheSource = cacheSource:sub(assert(cacheSource:find('local function unitCacheBuff(', 1, true)),
    assert(cacheSource:find('jungle.unitCacheBuff = unitCacheBuff', 1, true)) - 1)
local CacheReader = assert(loadstring('return function(unitCache, GetTime)\n' .. cacheSource .. '\nreturn unitCacheBuff end'))()
local checks = 0
local function Check(ok, why) assert(ok, why); checks = checks + 1 end
local function Eligible(rows)
    local action
    for _, row in ipairs(rows) do
        if row[3] and (row[2] == 'Battle Shout' or row[2] == 'Commanding Shout') then
            Check(action == nil, 'only one shout eligible'); action = row[2]
        end
    end
    return action
end
local function Fixture(kind, aoe)
    local s, j, e, evaluate
    if kind == 'wowsims' then
        s, j, e = Wowsims({cd={['Mortal Strike']=4, Whirlwind=4}, enemies=aoe and 3 or 1})
        evaluate = function() return s:rows() end
    elseif kind == 'adaptive' then
        s, j, e = Adaptive({lost=true, learned={['Commanding Shout']=true}})
        evaluate = function() return j.warriorAdaptive(nil) end
    else
        s = {thread=2, fury=kind:find('fury') ~= nil, pvp=kind:find('pvp') ~= nil}
        j, e = Context(s)
        evaluate = function() return (s.fury and j.warriorFury or j.warriorArms)('target') end
    end
    local cached = CacheReader(j.unitCache, e.GetTime)
    local otherBuffs = j.unitCacheBuff
    j.unitCacheBuff = function(unit, name, owner, expires, stacks)
        if name == 'Battle Shout' or name == 'Commanding Shout' then
            return cached(unit, name, owner, expires, stacks)
        end
        return otherBuffs(unit, name, owner, expires, stacks)
    end
    local function Auras(list)
        local buffs = {player={}, nonplayer={}}
        j.unitCache.player = {auras={buffs=buffs}}
        for _, a in ipairs(list) do
            buffs[a[2] == 'player' and 'player' or 'nonplayer'][a[1]] = {
                isActive=a[4] ~= false, count=0, source=a[2], expirationTime=e.GetTime()+a[3],
            }
        end
    end
    return s, j, e, evaluate, Auras
end
local B, C = 'Battle Shout', 'Commanding Shout'
for _, kind in ipairs({'arms', 'arms_pvp', 'fury', 'fury_pvp', 'wowsims', 'adaptive'}) do
    local s, j, e, evaluate, Auras = Fixture(kind)
    local window = kind == 'wowsims' and 10 or kind == 'adaptive' and 3 or 5
    -- Run transitions on the same loaded routine to detect stale action/condition rows.
    local cases = {
        {{}, B},
        {{{B,'party1',30}}, C},
        {{{C,'party1',30}}, B},
        {{{B,'party1',30},{C,'party2',30}}, nil},
        {{{B,'party1',1},{C,'party2',1}}, nil},
        {{{B,'player',30}}, nil},
        {{{B,'player',window-0.1}}, B},
        {{{B,'player',window-0.1},{C,'party1',30}}, B},
        {{{C,'player',30}}, nil},
        {{{C,'player',window-0.1}}, C},
        {{{C,'player',window-0.1},{B,'party1',30}}, C},
        {{{C,'player',window-0.1},{C,'party1',30},{B,'party2',30}}, C},
        {{{C,'player',window}}, nil},
        {{{B,'player',window}}, nil},
        {{{B,'party1',-1}}, B},
        {{{B,'party1',30,false}}, B},
        {{{B,'party1',30},{C,'player',-1}}, C},
        {{{C,'player',-1}}, B},
    }
    for i, case in ipairs(cases) do
        Auras(case[1])
        Check(Eligible(evaluate()) == case[2], kind .. ' ownership/expiry case ' .. i)
    end
    Auras({{B,'party1',30}})
    s.blocked = {[C]=true}
    Check(Eligible(evaluate()) == nil, kind .. ' respects selected shout readiness')
    s.blocked = nil
    Check(Eligible(evaluate()) == C, kind .. ' selected shout becomes ready')
    Check(rawget(e,'useBattleShout') == nil, kind .. ' does not leak old local as global')
    -- Runtime changes affect every DPS caller without overriding current ownership.
    -- Suppress UI refresh in this game-API fixture; Options.test covers real row clicks.
    j.Options.Refresh = function() end
    Check(j.Options:SetEnabled('default_shout_commanding', true, 'WARRIOR'), kind .. ' accepts default')
    Auras({})
    Check(Eligible(evaluate()) == C, kind .. ' uses configured Commanding default')
    Auras({{C,'party1',30}})
    Check(Eligible(evaluate()) == B, kind .. ' complements foreign Commanding despite default')
    Auras({{B,'player',window-0.1}})
    Check(Eligible(evaluate()) == B, kind .. ' preserves own Battle despite default')
    Auras({{B,'party1',30},{C,'party2',30}})
    Check(Eligible(evaluate()) == nil, kind .. ' both foreign buffs override default')
    Auras({})
    j.Options:SetEnabled('default_shout_battle', true, 'WARRIOR')
    Check(Eligible(evaluate()) == B, kind .. ' observes default changed back to Battle')
end

local s, j, e, evaluate, Auras = Fixture('wowsims', true)
Auras({{B,'party1',30}})
Check(Eligible(evaluate()) == C, 'WoWSims AoE shares adaptive shout row')
s.cd = {}
Check(Eligible(evaluate()) == nil, 'WoWSims still waits for core cooldown gap')

-- No-target Arms/Fury refresh and selected spell cooldown remain independent of enemies.
for _, kind in ipairs({'arms','fury'}) do
    local s, j, e, evaluate, Auras = Fixture(kind)
    Auras({{B,'party1',30}})
    local routine = kind == 'arms' and j.warriorArms or j.warriorFury
    Check(Eligible(routine(nil)) == C, kind .. ' targetless complementary shout')
    s.cooldowns = {[C]=true}
    Check(Eligible(routine(nil)) == nil, kind .. ' targetless cooldown guard')
end
print('Warrior shouts: ' .. checks .. ' ownership, expiry, readiness and integration checks passed (mocked APIs).')
