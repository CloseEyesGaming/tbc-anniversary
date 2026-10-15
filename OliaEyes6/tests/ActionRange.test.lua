-- Standalone Lua 5.1 regression tests; not loaded by the addon TOC.
-- Optional argument: exact pre-edit checkpoint directory for binding comparison.
local baseline = ...
local checks = 0
local function Check(value, why) assert(value, why); checks = checks + 1 end
local function Setup(class, hotkeysPath)
    local s = { combat = false, focus = nil, range = 1, queries = 0, rangeQueries = 0, writes = 0, focusQueries = 0 }
    local ranges = { Lifebloom = true, Rejuvenation = true, Moonfire = true, Pummel = true, Slam = true, Charge = true }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.print = function() end
    env.UnitClass = function() return class, class end
    env.InCombatLockdown = function() return s.combat end
    env.C_Spell = { SpellHasRange = function(id)
        Check(not s.combat, "classification must not run during deferred combat refresh")
        s.queries = s.queries + 1
        return ranges[id] == true
    end }
    env.UIParent = {}
    local function Noop() end
    local methods = {}
    for _, name in ipairs({ "SetSize", "SetPoint", "SetAlpha", "SetAllPoints", "SetColorTexture", "SetTexture", "SetTexCoord", "SetHighlightTexture", "RegisterForClicks" }) do methods[name] = Noop end
    function methods:SetAttribute(key, value)
        Check(not s.combat, "secure attributes cannot change in combat")
        s.writes = s.writes + 1
        self.attributes[key] = value
    end
    function methods:GetAttribute(key) return self.attributes[key] end
    function methods:GetName() return self.name end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:SetScript(name, fn) self.scripts[name] = fn end
    function methods:CreateTexture() return setmetatable({}, { __index = methods }) end
    env.CreateFrame = function(_, name)
        return setmetatable({ name = name, attributes = {}, events = {}, scripts = {} }, { __index = methods })
    end
    env.ClearOverrideBindings, env.SetOverrideBindingClick = Noop, Noop
    env.C_Timer = { After = Noop }
    env.GetTime = function() return 100 end
    env.GetSpellInfo = function(spell) if spell ~= s.unknown then return spell end end
    env.GetSpellBookItemInfo = function(spell) if spell ~= s.unknown then return 1 end end
    env.GetSpellCooldown = function(spell) return 0, (spell ~= 61304 and s.cooldown) and 10 or 0, 1 end
    env.IsUsableSpell = function() return not s.unusable, s.noMana or false end
    env.UnitIsDeadOrGhost = function() return s.dead or false end
    env.IsSpellInRange = function() s.rangeQueries = s.rangeQueries + 1; return s.range end
    env.UnitExists = function(unit)
        s.focusQueries = s.focusQueries + 1
        if unit == "focus" then return s.focus ~= nil end
        return unit ~= nil and unit ~= "softenemy"
    end
    env.UnitIsUnit = function(a, b)
        s.focusQueries = s.focusQueries + 1
        return (a == "focus" and s.focus or a) == b
    end
    local j = { offsets = { GCD_SPELL_ID = 61304 }, RaidTrace = { sample = false, enabled = true } }
    j.RaidTrace.WatchEventFrame = function(_, frame) s.events = frame end
    j.EnemyFocus = { GetActionId = function(_, unit) return unit end }
    j.Debug = { enabled = true, UpdateCast = function(_, action, target) s.debugAction, s.debugTarget = action, target end }
    setfenv(assert(loadfile("Color.lua")), env)("OliaEyes6", j)
    setfenv(assert(loadfile("Core/Spell.lua")), env)("OliaEyes6", j)
    setfenv(assert(loadfile(hotkeysPath or "Core/Hotkeys.lua")), env)("OliaEyes6", j)
    j.Pixel = { new = function(_, color) return { set = function() s.pixel = { unpack(color) }; return true end } end }
    setfenv(assert(loadfile("Cast.lua")), env)("OliaEyes6", j)
    j.Hotkeys.UpdateEquipMacros = Noop
    return j, s, ranges, env
end
local function Button(j, id)
    for _, b in ipairs(j.Hotkeys.DynamicButtons) do if b.spell == id then return b.frame end end
    error("missing button " .. id)
end
local function Event(s, name) s.events.scripts.OnEvent(s.events, name) end
local function Export(j, env)
    j.Hotkeys:DumpBindings()
    local rows = {}
    for _, r in ipairs(env.OliaEyes_Export) do rows[#rows + 1] = table.concat({r.class, r.type, r.id, r.key, r.color}, "|") end
    table.sort(rows)
    return table.concat(rows, "\n")
end

for _, class in ipairs({ "DRUID", "WARRIOR", "ROGUE", "MAGE", "PALADIN", "PRIEST", "SHAMAN", "WARLOCK", "HUNTER" }) do
    local j, s, ranges, env = Setup(class)
    local expected = #j.Hotkeys.GlobalDefaults + #j.Hotkeys.ClassSpells[class]
    Check(s.queries == expected, "one initialization query per registered action")
    Check(j.actionHasRange.Equip2H == false, "custom equipment action follows API false")
    for _, b in ipairs(j.Hotkeys.DynamicButtons) do
        local override = j.Hotkeys.MacroOverrides[b.spell]
        local expectedMacro = override or ((ranges[b.spell] and "/cast [@focus,exists] " or "/cast ") .. b.spell)
        Check(b.frame:GetAttribute("macrotext") == expectedMacro, "initial macro: " .. b.spell)
    end
    local seenKeys = {}
    for _, group in ipairs({ j.Hotkeys.StaticButtons, j.Hotkeys.DynamicButtons }) do
        for _, b in ipairs(group) do
            Check(not seenKeys[b.key], "duplicate assigned key: " .. b.key)
            seenKeys[b.key] = true
        end
    end
    if baseline then
        local old, _, _, oldEnv = Setup(class, baseline .. "/Core/Hotkeys.lua")
        Check(Export(j, env) == Export(old, oldEnv), "export unchanged: " .. class)
        Check(#j.Hotkeys.StaticButtons == #old.Hotkeys.StaticButtons, "static button count unchanged")
        Check(#j.Hotkeys.DynamicButtons == #old.Hotkeys.DynamicButtons, "dynamic button count unchanged")
        for i, b in ipairs(j.Hotkeys.StaticButtons) do
            Check(b.frame:GetAttribute("macrotext") == old.Hotkeys.StaticButtons[i].frame:GetAttribute("macrotext"), "static macro unchanged")
        end
    end
end

local j, s, ranges, env = Setup("DRUID")
local initialQueries = s.queries
Check(j.actionHasRange["Omen of Clarity"] == false, "Omen classified without range")
for _, focus in ipairs({ false, "enemy", "raid2" }) do
    s.focus = focus or nil
    local before = s.focusQueries
    Check(j.Cast:CastSpell("Omen of Clarity", "raid1", 1), "Omen emits with arbitrary focus")
    Check(j.RaidTrace.intentSpell == "Omen of Clarity" and j.RaidTrace.intentStage == "spellIntent", "Omen emits action immediately")
    Check(j.RaidTrace.intentTarget == "raid1" and s.debugTarget == "raid1", "context retained")
    Check(s.focusQueries == before, "targetless action never resolves focus")
end
s.focus = nil
j.Cast:CastSpell("Equip2H", nil, 1)
Check(j.RaidTrace.intentStage == "spellIntent", "equipment works without context or focus")
j.Cast:CastSpell("Lifebloom", "raid2", 1)
Check(j.RaidTrace.intentStage == "focusIntent", "targeted heal acquires missing focus")
s.focus = "enemy"
j.Cast:CastSpell("Lifebloom", "raid2", 1)
Check(j.RaidTrace.intentStage == "focusIntent", "targeted heal replaces unrelated focus")
s.focus = "raid2"
j.Cast:CastSpell("Lifebloom", "raid2", 1)
Check(j.RaidTrace.intentStage == "spellIntent", "targeted heal emits after handshake")
local color = j.Color:new()
local r, g, b = color:getRGB("Lifebloom")
Check(s.pixel[1] == r and s.pixel[2] == g and s.pixel[3] == b, "emitted action color unchanged")

for _, snapshotMode in ipairs({ false, true }) do
    local function Ready(spell, unit)
        return j.ReadyCastSpell(spell, unit, snapshotMode and { ready = {} } or nil)
    end
    s.range = nil
    local before = s.rangeQueries
    Check(Ready("Omen of Clarity", "raid1"), "Omen player alias skips invalid range")
    Check(s.rangeQueries == before, "no redundant targetless range query")
    Check(not Ready("Lifebloom", "raid2"), "invalid targeted range rejected")
    s.range = 0
    Check(not Ready("Lifebloom", "raid2"), "out-of-range heal rejected")
    s.range = 1
    Check(Ready("Lifebloom", "raid2"), "moving back into range accepted")
    before = s.rangeQueries
    Check(Ready("Lifebloom", "player"), "explicit self remains allowed")
    Check(Ready("Lifebloom", nil), "no supplied unit skips generic range")
    Check(s.rangeQueries == before, "self/nil unit skips range query")
    for _, flag in ipairs({ "unusable", "noMana", "dead", "cooldown" }) do
        s[flag] = true
        Check(not Ready("Omen of Clarity", "raid1"), "targetless preserves gate: " .. flag)
        s[flag] = nil
    end
    s.unknown = "Omen of Clarity"
    Check(not Ready("Omen of Clarity", "raid1"), "unknown spell still rejected by readiness")
    s.unknown = nil
end
Check(s.queries == initialQueries, "casting and readiness never query SpellHasRange")

local beforeLookup, beforeWrites = j.actionHasRange, s.writes
s.combat = true
ranges.Lifebloom = false
ranges["Omen of Clarity"] = true
Event(s, "SPELLS_CHANGED")
Event(s, "SPELLS_CHANGED")
Check(j.actionHasRange == beforeLookup and j.actionHasRange.Lifebloom, "combat retains previous lookup")
Check(s.writes == beforeWrites and s.queries == initialQueries, "combat does not update macros or classify")
Check(j.Hotkeys.actionRangesDirty, "combat refresh marked pending")
s.combat = false
Event(s, "PLAYER_REGEN_ENABLED")
Check(not j.actionHasRange.Lifebloom and j.actionHasRange["Omen of Clarity"], "latest classification published on combat exit")
Check(Button(j, "Lifebloom"):GetAttribute("macrotext") == "/cast Lifebloom", "true to false macro refresh")
Check(Button(j, "Omen of Clarity"):GetAttribute("macrotext") == "/cast [@focus,exists] Omen of Clarity", "false to true macro refresh")
Check(not j.Hotkeys.actionRangesDirty, "pending refresh cleared")
local afterQueries, afterWrites = s.queries, s.writes
Event(s, "PLAYER_REGEN_ENABLED")
Check(s.queries == afterQueries and s.writes == afterWrites, "no unnecessary combat-exit refresh")
Event(s, "SPELLS_CHANGED")
Check(s.writes == afterWrites, "unchanged classification avoids attribute writes")
ranges.Lifebloom = true
Event(s, "PLAYER_ENTERING_WORLD")
Check(j.actionHasRange.Lifebloom, "world entry refreshes classification")

-- Exercise the actual local Warrior gate without loading unrelated routine state.
-- The full Warrior file is also parsed by the test runner.
local file = assert(io.open("Routines/Warrior.lua", "r"))
local source = file:read("*a"); file:close()
local gate = assert(source:match("local function ReadyCastSpellNoGCD%b()%s*.-\nend"))
local w, ws, wr, we = Setup("WARRIOR")
we.jungle = w
local ready = setfenv(assert(loadstring(gate .. "\nreturn ReadyCastSpellNoGCD")), we)()
ws.range = nil
Check(ready("Whirlwind", "target"), "Warrior AoE skips invalid unit range")
Check(ws.rangeQueries == 0, "Warrior AoE has no range query")
Check(not ready("Slam", "target"), "Warrior targeted spell rejects invalid range")
ws.range = 1
Check(ready("Slam", "target"), "Warrior targeted spell accepts live range")
ws.range = 0
Check(not ready("Slam", "target"), "Warrior target moving out of range rejected")
ws.unusable, ws.noMana = true, true
Check(not ready("Whirlwind", "target"), "Warrior resource gate preserved")
Check(ready("Whirlwind", "target", true), "Warrior resource reservation preserved")
local override = Button(w, "Battle Stance"):GetAttribute("macrotext")
Check(override == w.Hotkeys.MacroOverrides["Battle Stance"], "compound stance override preserved")
ws.focus = nil
w.Cast:CastSpell("Battle Stance", "target", 1)
Check(w.RaidTrace.intentStage == "spellIntent", "override follows API range without manual focus override")
print("ActionRange: " .. checks .. " checks passed")
