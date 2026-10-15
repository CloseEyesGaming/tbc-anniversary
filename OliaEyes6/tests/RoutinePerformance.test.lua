-- Lua 5.1. Dispatch-only allocation/API budget, not a client frame-time benchmark.
local checks=0
local function Check(ok,why) assert(ok,why);checks=checks+1 end
local env=setmetatable({}, {__index=_G});env._G=env
local function Frame() return {RegisterEvent=function() end,SetScript=function() end} end
env.CreateFrame=Frame
env.OliaEyes6_Settings={}
local j={Options={definitions={WARRIOR={}},Refresh=function() end},CurrentCast={}}
local config=assert(loadfile('tests/RoutineConfigFixture.lua'))()(j,env,'WARRIOR')
local engine={activeThread=2,rotation={dpsRotate=function() return false end,rotate=function() return false end}}
for i=1,100 do config:Run(engine) end
-- Runtime dispatch must not discover class/routine data, save, compile, or refresh UI.
env.UnitClass=function() error('dispatch queried class') end
env.UnitFullName=function() error('dispatch queried identity') end
j.Options.Refresh=function() error('dispatch refreshed UI') end
config.Compile=function() error('dispatch compiled configuration') end
config.Available=function() error('dispatch discovered routines') end
collectgarbage('collect');collectgarbage('stop')
local before=collectgarbage('count')
for i=1,10000 do config:Run(engine) end
local delta=collectgarbage('count')-before
collectgarbage('restart')
Check(delta<1,'dispatch allocated per tick: '..delta..' KiB')
Check(j.RoutineContext==nil,'dispatch does not leak routine context')
Check(config.plans[2][1].allEnabled==true,'default plan uses direct all-enabled row path')
print('RoutinePerformance: '..checks..' checks passed; 10000 dispatches allocated '..delta..' KiB')
