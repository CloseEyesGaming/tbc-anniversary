local AddonName, jungle = ...

-- Registry and profiles do all discovery/validation/compilation off the hot path.
-- IDs are persisted; function references, masks and row tables never are.
local Config = { definitions = {}, order = {}, rows = {}, defaults = {}, plans = {}, revision = 0, variantIDs = {}, resetters = {}, resetterSet = {} }
jungle.RoutineConfig = Config
local EMPTY = {}
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end
local function ThreadID(id) return type(id) == "number" and id >= 1 and id <= 7 and id == math.floor(id) end
local function Class() local _, token = UnitClass("player"); return token or "UNKNOWN" end
local function Combat() return InCombatLockdown and InCombatLockdown() end

function jungle.RoutineAllows(action)
    local entry = jungle.RoutineContext
    return not entry or entry.allEnabled or entry.actions[action] ~= false
end
function jungle.RoutineOption(key)
    local entry = jungle.RoutineContext
    if entry then return entry.options[key] end
end
-- Behavior follows the routine. Event observers use the recorded selection only
-- while its physical thread and configuration revision still match.
function jungle.GetRoutineEntry()
    local entry = jungle.RoutineContext
    if not entry then
        local cast = jungle.CurrentCast
        if cast and cast.configRevision == Config.revision and jungle.Engine
            and cast.engineThread == jungle.Engine.activeThread then entry = cast.configEntry end
    end
    return entry
end
function jungle.GetRoutineThread()
    local entry=jungle.GetRoutineEntry()
    if entry then
        if entry.behavior then return entry.behavior.legacyPolicy end
        return entry.policy
    end
    return jungle.Engine and jungle.Engine.activeThread
end
function Config:ResetDecisionState()
    -- Prospective per-placement plans only; factual swing/aura observers stay alive.
    for _,plan in pairs(self.plans) do
        for _,entry in ipairs(plan) do
            for key in pairs(entry.state or EMPTY) do entry.state[key]=nil end
        end
    end
    if jungle.ResetDruidEquipAttemptState then jungle.ResetDruidEquipAttemptState() end
    for _,reset in ipairs(self.resetters) do reset() end
    if jungle.CurrentCast then jungle.CurrentCast.configEntry=nil end
end
function Config:AddRows(name, rows, descriptions)
    self.rows[name] = { rows = rows, descriptions = descriptions or {} }
end
-- Static presentation only: never execute an evaluator to discover its steps.
local function BuildDisplayViews(config, definition)
    local authored = definition.displayViews or {{id="shared",label="Steps",sections={{label="Actions",rowSets=definition.rowSets,steps=definition.extraSteps}}}}
    if type(authored)~="table" or #authored==0 then return nil,"Missing display views" end
    local result, ids, covered, options = {}, {}, {}, {}
    local optionByID={}
    for _,option in ipairs(definition.options or EMPTY) do optionByID[option.key]=option end
    local declared={}
    for _,name in ipairs(definition.rowSets or EMPTY) do declared[name]=true end
    for _,view in ipairs(authored) do
        if type(view)~="table" or type(view.id)~="string" or view.id=="" or ids[view.id]
            or type(view.label)~="string" or type(view.sections)~="table" or #view.sections==0
            or (view.description~=nil and type(view.description)~="string") then return nil,"Invalid display view" end
        ids[view.id]=true
        local built={id=view.id,label=view.label,description=view.description,sections={},options={}}
        for _,section in ipairs(view.sections) do
            if type(section)~="table" or type(section.label)~="string"
                or (section.description~=nil and type(section.description)~="string")
                or (section.when~=nil and (type(section.when)~="string" or section.when==""))
                or (section.rowSets~=nil and type(section.rowSets)~="table")
                or (section.steps~=nil and type(section.steps)~="table") then return nil,"Invalid display section" end
            local block={label=section.label,description=section.description,when=section.when,collapsed=section.collapsed,steps={}}
            local byID={}
            local function Add(id,label,description,summary)
                local canonical=definition.stepByID[id]
                if not canonical then return false end
                local step=byID[id]
                if not step then
                    step={id=id,label=label or canonical.label,locked=canonical.locked,description=description or "",summary=summary}
                    byID[id]=step;block.steps[#block.steps+1]=step
                else
                    if description and description~="" then step.description=step.description.."\n"..description end
                    if summary then step.summary=summary end
                    if label then step.label=label end
                end
                covered[id]=true;return true
            end
            for _,name in ipairs(section.rowSets or EMPTY) do
                local schema=config.rows[name]
                if not declared[name] or not schema then return nil,"Undeclared display schema: "..tostring(name) end
                for index,row in ipairs(schema.rows) do
                    if row[2]~="" and not Add(row[2],nil,row[1]..": "..(schema.descriptions[index] or "Authored conditions and priority.")) then
                        return nil,"Undeclared display action: "..tostring(row[2])
                    end
                end
            end
            for _,step in ipairs(section.steps or EMPTY) do
                if type(step)~="table" or type(step.id)~="string"
                    or (step.label~=nil and type(step.label)~="string")
                    or (step.description~=nil and type(step.description)~="string")
                    or (step.summary~=nil and type(step.summary)~="string")
                    or not Add(step.id,step.label,step.description,step.summary) then return nil,"Invalid display action" end
            end
            -- Place dynamic alternatives next to the static row they replace.
            for _,extra in ipairs(section.steps or EMPTY) do
                if extra.after or extra.before then
                    local anchor=extra.after or extra.before
                    if type(anchor)~="string" or anchor==extra.id or not byID[anchor] then return nil,"Invalid display anchor" end
                    local moving=byID[extra.id]
                    for index,step in ipairs(block.steps) do if step==moving then table.remove(block.steps,index);break end end
                    for index,step in ipairs(block.steps) do
                        if step.id==anchor then table.insert(block.steps,index+(extra.after and 1 or 0),moving);break end
                    end
                end
            end
            built.sections[#built.sections+1]=block
        end
        local keys=view.options
        if keys~=nil and type(keys)~="table" then return nil,"Invalid display options" end
        if keys==nil then
            keys={};for _,option in ipairs(definition.options or EMPTY) do keys[#keys+1]=option.key end
        end
        local seen={}
        for _,key in ipairs(keys) do
            if not optionByID[key] or seen[key] then return nil,"Invalid display option: "..tostring(key) end
            seen[key]=true;options[key]=true;built.options[#built.options+1]=optionByID[key]
        end
        result[#result+1]=built
    end
    for _,step in ipairs(definition.steps) do
        if not covered[step.id] then return nil,"Action missing from display views: "..step.id end
    end
    for _,option in ipairs(definition.options or EMPTY) do
        if not options[option.key] then return nil,"Option missing from display views: "..option.key end
    end
    return result
end
function Config:Register(definition)
    if type(definition) ~= "table" or type(definition.id) ~= "string"
        or type(definition.label) ~= "string" or type(definition.source) ~= "string"
        or (definition.kind ~= "class" and definition.kind ~= "support")
        or (definition.kind == "class" and type(definition.class) ~= "string")
        or (definition.selector ~= "rotate" and definition.selector ~= "dpsRotate")
        or type(definition.functions) ~= "table" or #definition.functions == 0
        or self.definitions[definition.id] then return false, "Invalid/duplicate routine definition" end
    for i = 1, #definition.functions do
        if type(definition.functions[i]) ~= "function" then return false, "Missing evaluator: " .. definition.id end
    end
    if definition.class=="WARRIOR" then
        local behavior=definition.behavior
        if not jungle.RoutineBehaviors or type(behavior)~="table"
            or jungle.RoutineBehaviors.byName[behavior.name]~=behavior
            or (definition.mode~="original" and definition.mode~="wowsims" and definition.mode~="adaptive") then
            return false,"Missing/invalid routine behavior: "..definition.id
        end
    end
    if definition.reset~=nil and type(definition.reset)~="function" then return false,"Invalid routine reset" end
    local metadata=definition.metadataFrom and self.definitions[definition.metadataFrom]
    if definition.metadataFrom and (not metadata or definition.class~=metadata.class or definition.kind~=metadata.kind
        or definition.source~=metadata.source or definition.selector~=metadata.selector or definition.functions~=metadata.functions
        or definition.rowSets~=metadata.rowSets or definition.extraSteps~=metadata.extraSteps
        or definition.options~=metadata.options or definition.links~=metadata.links) then return false,"Invalid shared routine metadata" end
    if metadata then
        definition.steps,definition.stepByID,definition.validationError=metadata.steps,metadata.stepByID,metadata.validationError
    else
    definition.steps, definition.stepByID = {}, {}
    local function Add(action, label, description, locked)
        if type(action) ~= "string" or action == "" then return end
        local step = definition.stepByID[action]
        if not step then
            step = { id = action, label = label or action, default = true, description = description or "", locked = locked }
            definition.stepByID[action] = step
            definition.steps[#definition.steps + 1] = step
        elseif description and description ~= "" then step.description = step.description .. "\n" .. description end
    end
    for _, name in ipairs(definition.rowSets or EMPTY) do
        local set = self.rows[name]
        if not set then return false, "Missing row schema: " .. name end
        for index, row in ipairs(set.rows) do
            if type(row) ~= "table" or type(row[1]) ~= "string" or type(row[2]) ~= "string"
                or type(row[3]) ~= "boolean" then return false, "Invalid row: " .. name .. ":" .. index end
            Add(row[2], row[2], (row[1] ~= "" and row[1] or row[2]) .. ": " .. (set.descriptions[index] or "Authored conditions and priority."), row[2] == "Stopcasting" or row[2] == "StopFollow")
        end
    end
    for _, step in ipairs(definition.extraSteps or EMPTY) do Add(step.id, step.label, step.description, step.locked) end
    -- Validate executable action identities against the fixed binding registries.
    -- Support modules retain their own class-aware eligibility (e.g. Tree of Life).
    local hotkeys = jungle.Hotkeys
    if definition.kind == "class" and hotkeys and hotkeys.ClassSpells then
        local allowed = {}
        for _, action in ipairs(hotkeys.ClassSpells[definition.class] or EMPTY) do allowed[action.id] = true end
        for _, action in ipairs(hotkeys.GlobalDefaults or EMPTY) do allowed[action.id] = true end
        for _, step in ipairs(definition.steps) do
            if not allowed[step.id] then definition.validationError = "Unregistered action: " .. step.id; break end
        end
    end
    for action, owner in pairs(definition.links or EMPTY) do
        if not definition.stepByID[action] or not definition.stepByID[owner] then
            return false, "Invalid dependency in " .. definition.id
        end
    end
    end -- Shared metadata is validated once by its source definition.
    local views,viewError=BuildDisplayViews(self,definition)
    if not views then return false,viewError.." in "..definition.id end
    definition.views=views
    if definition.reset and not self.resetterSet[definition.reset] then
        self.resetterSet[definition.reset]=true;self.resetters[#self.resetters+1]=definition.reset
    end
    self.definitions[definition.id] = definition
    self.order[#self.order + 1] = definition
    if jungle.RaidTrace and jungle.RaidTrace.routineNames then
        for _, fn in ipairs(definition.functions) do
            jungle.RaidTrace.routineNames[fn] = jungle.RaidTrace.routineNames[fn] or definition.id
        end
    end
    return true
end
function Config:Available(thread, class)
    local result = {}
    for _, def in ipairs(self.order) do
        if not def.hidden and ((thread == 7 and def.kind == "support") or (ThreadID(thread) and thread < 7 and def.kind == "class" and def.class == (class or Class()))) then
            result[#result + 1] = def
        end
    end
    return result
end
function Config:RefreshUI()
    if jungle.Options and jungle.Options.Refresh then jungle.Options:Refresh() end
end
function Config:GetProfile()
    return self.db and self.db.profiles[self.selected]
end
function Config:GetClass(create)
    local profile = self:GetProfile()
    if type(profile) ~= "table" then return end
    if type(profile.classes) ~= "table" then profile.classes = {} end
    local token = Class()
    if create and type(profile.classes[token]) ~= "table" then
        profile.classes[token] = { threads = Copy(self.defaults[token] or self.defaults.UNKNOWN), options = Copy(type(self.legacy[token]) == "table" and self.legacy[token] or {}) }
    end
    local settings = profile.classes[token]
    if settings and type(settings.options) ~= "table" then settings.options = Copy(type(self.legacy[token]) == "table" and self.legacy[token] or {}) end
    if settings and not settings.migrated then
        if token == "WARRIOR" then self:MigrateWarrior(settings) end
        settings.migrated = true
    end
    if settings and token=="WARRIOR" then
        self:MigrateBehaviorSettings(settings)
        self:MigrateAdaptiveDemoPreference(settings)
    end
    return settings
end
function Config:GetThreads()
    local settings = self:GetClass(true)
    return settings and settings.threads
end
function Config:GetEntry(thread, index)
    local threads = self:GetThreads()
    local entry = threads and threads[thread] and threads[thread][index]
    return type(entry) == "table" and entry or nil
end
function Config:Compile()
    if not self.ready or Combat() then self.pending = true; return false end
    local settings = self:GetClass(true)
    if type(settings.threads) ~= "table" then settings.threads = Copy(self.defaults[Class()] or self.defaults.UNKNOWN) end
    local plans, errors = {}, {}
    for thread = 1, 7 do
        plans[thread] = {}
        local entries = settings.threads[thread]
        if type(entries) ~= "table" then entries = {}; settings.threads[thread] = entries end
        local seen = {}
        for index, saved in ipairs(entries) do
            local def = type(saved) == "table" and self.definitions[saved.id]
            local reason
            if type(saved)=="table" and saved.migrationError then reason=saved.migrationError
            elseif not def then reason = "Routine unavailable"
            elseif def.retired then reason = "Retired routine fallback"
            elseif def.validationError then reason = def.validationError
            elseif (thread == 7 and def.kind ~= "support") or (thread < 7 and (def.kind ~= "class" or def.class ~= Class())) then reason = "Routine belongs to another class/thread category"
            elseif seen[def.id] then reason = "Duplicate routine" end
            if reason then errors[thread .. ":" .. index] = reason
            else
                seen[def.id] = true
                if saved.enabled ~= false then
                    local entry = { definition = def, behavior = def.behavior,
                        policy = def.class~="WARRIOR" and (ThreadID(saved.policy) and saved.policy or def.policy or 2) or nil,
                        mode = def.class=="WARRIOR" and def.mode or ((saved.mode=="original" or saved.mode=="wowsims" or saved.mode=="adaptive") and saved.mode or def.mode or "original"),
                        state = {}, thread = thread, index = index,
                        actions = {}, options = {}, allEnabled = true, enabledCount = 0, revision = self.revision + 1 }
                    local steps = type(saved.steps) == "table" and saved.steps or EMPTY
                    for _, step in ipairs(def.steps) do
                        local allowed = step.locked or steps[step.id] ~= false
                        entry.actions[step.id] = allowed
                        if not allowed then entry.allEnabled = false end
                    end
                    for _, option in ipairs(def.options or EMPTY) do
                        local values = type(saved.options) == "table" and saved.options or EMPTY
                        local value = values[option.key]
                        if type(value) ~= "boolean" then value = option.default ~= false end
                        entry.options[option.key] = value
                    end
                    if def.behavior then
                        for kind,key in pairs(def.behavior.optionKeys) do
                            if entry.options[kind]==nil then
                                local value=settings.options[key]
                                if type(value)~="boolean" then value=not jungle.Options or not jungle.Options.IsEnabled or jungle.Options:IsEnabled(key,"WARRIOR") end
                                entry.options[kind]=value
                            end
                        end
                    end
                    entry.defaultShout = saved.defaultShout or settings.options.default_shout or "Battle Shout"
                    -- Linked actions form one semantic step; preparation cannot outlive its action.
                    for action, owner in pairs(def.links or EMPTY) do entry.actions[action] = entry.actions[action] ~= false and entry.actions[owner] ~= false end
                    entry.enabledCount = 0
                    for _, step in ipairs(def.steps) do
                        if entry.actions[step.id] and not step.locked then entry.enabledCount = entry.enabledCount + 1 end
                    end
                    if entry.enabledCount > 0 or #def.steps == 0 then
                        plans[thread][#plans[thread] + 1] = entry
                        if def.id == "support.fishing" then plans[thread].fishingEnabled = true end
                    end
                end
            end
        end
    end
    self.plans, self.errors, self.pending = plans, errors, false
    self.revision = self.revision + 1
    jungle.RoutineContext = nil
    self:ResetDecisionState()
    self:RefreshUI()
    return true
end
function Config:Changed()
    if Combat() then self.pending = true; self:RefreshUI() else self:Compile() end
end
function Config:Add(thread, id)
    if not ThreadID(thread) then return false end
    local def = self.definitions[id]
    if not def or def.hidden or def.retired or def.validationError or (thread == 7 and def.kind ~= "support") or (thread < 7 and (def.kind ~= "class" or def.class ~= Class())) then return false end
    local entries = self:GetThreads()[thread]
    for _, entry in ipairs(entries) do if type(entry)=="table" and entry.id == id then return false end end
    entries[#entries + 1] = {id = id, enabled = true, steps = {}, options = {}}
    self:Changed(); return true
end
function Config:Remove(thread, index)
    local entries = ThreadID(thread) and self:GetThreads()[thread]
    if not entries or type(index) ~= "number" or index ~= math.floor(index) or not entries[index] then return false end
    table.remove(entries, index); self:Changed(); return true
end
function Config:Move(thread, index, delta)
    if delta ~= -1 and delta ~= 1 then return false end
    local entries = ThreadID(thread) and self:GetThreads()[thread]
    if not entries or not entries[index] or not entries[index + delta] then return false end
    entries[index], entries[index + delta] = entries[index + delta], entries[index]
    self:Changed(); return true
end
function Config:SetEnabled(thread, index, enabled)
    local entry = self:GetEntry(thread, index)
    if not entry or type(enabled) ~= "boolean" then return false end
    entry.enabled = enabled; self:Changed(); return true
end
function Config:SetStep(thread, index, id, enabled)
    local entry = self:GetEntry(thread, index)
    local def = entry and self.definitions[entry.id]
    local step = def and def.stepByID[id]
    if not step or step.locked or type(enabled) ~= "boolean" then return false end
    if type(entry.steps) ~= "table" then entry.steps = {} end
    entry.steps[id] = enabled; self:Changed(); return true
end
function Config:SetOption(thread, index, key, enabled)
    local entry = self:GetEntry(thread, index)
    local def = entry and self.definitions[entry.id]
    if not def or type(enabled) ~= "boolean" then return false end
    for _, option in ipairs(def.options or EMPTY) do
        if option.key == key then
            if type(entry.options) ~= "table" then entry.options = {} end
            entry.options[key] = enabled; self:Changed(); return true
        end
    end
    return false
end
function Config:ResetThread(thread)
    if not ThreadID(thread) then return false end
    local settings=self:GetClass(true)
    settings.threads[thread] = Copy((self.defaults[Class()] or self.defaults.UNKNOWN)[thread])
    self:Changed(); return true
end
function Config:ProfileNames()
    local names = {}; for name, profile in pairs(self.db.profiles) do
        if type(name) == "string" and type(profile) == "table" then names[#names + 1] = name end
    end
    table.sort(names); return names
end
local function ValidName(name) return type(name) == "string" and #name > 0 and #name <= 80 and not name:find("[%c|]") and name:find("%S") end
function Config:SelectProfile(name)
    if type(self.db.profiles[name]) ~= "table" then return false end
    self.selected = name; self.db.characters[self.character] = name
    self:GetClass(true); self:Changed(); return true
end
function Config:NewProfile(name, copy)
    if not ValidName(name) or self.db.profiles[name] then return false end
    self.db.profiles[name] = copy and Copy(self:GetProfile()) or {classes = {}}
    return self:SelectProfile(name)
end
function Config:RenameProfile(name)
    if not ValidName(name) or self.db.profiles[name] then return false end
    self.db.profiles[name], self.db.profiles[self.selected] = self:GetProfile(), nil
    for character, selected in pairs(self.db.characters) do if selected == self.selected then self.db.characters[character] = name end end
    self.selected = name; self:Changed(); return true
end
function Config:DeleteProfile(name)
    if name == self.selected or not self.db.profiles[name] then return false end
    self.db.profiles[name] = nil
    for character, selected in pairs(self.db.characters) do if selected == name then self.db.characters[character] = nil end end
    self:RefreshUI(); return true
end
function Config:MigrateWarrior(settings)
    local options = settings.options
    local mode = options.arms_pve_mode or (options.universal_arms_wowsims_st and "wowsims") or "original"
    if mode ~= "original" and mode ~= "wowsims" and mode ~= "adaptive" then mode = "original" end
    local names = {
        [1]={demo="thread1_demoralizing_shout",thunderClap="thread1_thunder_clap",sunderInitial="thread1_sunder_initial",sunderStack="thread1_sunder_stack"},
        [2]={demo="thread2_demoralizing_shout",sweeping="thread2_sweeping_strikes",sunderInitial="thread2_sunder_routine",sunderStack="thread2_sunder_routine"},
        [3]={demo="thread3_demoralizing_shout",sunderInitial="thread3_sunder_fallback",sunderStack="thread3_sunder_fallback"},
    }
    if type(settings.threads) ~= "table" then settings.threads = Copy(self.defaults.WARRIOR) end
    for thread = 1, 7 do
        for _, entry in ipairs(type(settings.threads[thread]) == "table" and settings.threads[thread] or EMPTY) do
            if type(entry) == "table" then
                local def=self.definitions[entry.id]
                if entry.id=="warrior.original" or (def and def.legacyBase=="warrior.original") then
                    local policy=ThreadID(entry.policy) and entry.policy or (def and def.behavior and def.behavior.legacyPolicy) or 2
                    entry.id=self.variantIDs["warrior."..mode][mode][policy]
                end
                if entry.id == "warrior.maintenance" or entry.id == "warrior.sweeping" then entry.mode = mode end
                entry.options = type(entry.options) == "table" and entry.options or {}
                entry.steps = type(entry.steps) == "table" and entry.steps or {}
                for key, value in pairs(options) do if type(value) == "boolean" then entry.options[key] = value end end
                for kind, key in pairs(names[thread] or EMPTY) do
                    local value = options[key]
                    if type(value) == "boolean" then
                        if kind == "demo" then entry.steps["Demoralizing Shout"] = value
                        elseif kind == "thunderClap" then entry.steps["Thunder Clap"] = value
                        elseif kind == "sweeping" then entry.steps["Sweeping Strikes"] = value
                        else entry.options[kind] = value end
                    end
                end
            end
        end
    end
end
function Config:MigrateBehaviorSettings(settings)
    if type(settings.threads)~="table" then return end
    for thread=1,7 do
        local seen={}
        for _,entry in ipairs(type(settings.threads[thread])=="table" and settings.threads[thread] or EMPTY) do
            local def=type(entry)=="table" and self.definitions[entry.id]
            if def and def.class=="WARRIOR" then
                if seen[entry.id] then entry.migrationError="Duplicate routine before migration" end
                seen[entry.id]=true
                local policy=ThreadID(entry.policy) and entry.policy or def.behavior.legacyPolicy
                local mode=(entry.mode=="original" or entry.mode=="wowsims" or entry.mode=="adaptive") and entry.mode or def.mode
                local variants=self.variantIDs[def.legacyBase or def.id]
                local id=variants and variants[mode] and variants[mode][policy]
                if id then entry.id=id;entry.policy=nil;entry.mode=nil
                elseif not variants and entry.policy==nil and (entry.mode==nil or entry.mode==def.mode) then entry.mode=nil
                elseif entry.policy~=nil or entry.mode~=nil then entry.migrationError="Saved behavior cannot be imported by this routine" end
            end
        end
    end
    -- Archive fallback-only compatibility placements, preserving their raw
    -- preferences without leaving them runnable or visible in the thread menu.
    for thread=1,7 do
        local entries=type(settings.threads[thread])=="table" and settings.threads[thread] or EMPTY
        for index=#entries,1,-1 do
            local entry=entries[index]
            local def=type(entry)=="table" and self.definitions[entry.id]
            if def and def.retired then
                if type(settings.removedRoutineFallbacks)~="table" then settings.removedRoutineFallbacks={} end
                local archive=settings.removedRoutineFallbacks
                archive[#archive+1]={thread=thread,index=index,entry=Copy(entry)}
                table.remove(entries,index)
            end
        end
    end
    if type(settings.routineIsolationVersion)~="number" or settings.routineIsolationVersion<1 then settings.routineIsolationVersion=1 end
    if type(settings.routineBehaviorVersion)~="number" or settings.routineBehaviorVersion<2 then settings.routineBehaviorVersion=2 end
end
function Config:MigrateAdaptiveDemoPreference(settings)
    if type(settings.adaptiveDemoPreferenceVersion)=="number" and settings.adaptiveDemoPreferenceVersion>=1 then return end
    if type(settings.threads)~="table" then return end
    local value=type(settings.options)=="table" and settings.options.adaptive_demo
    if type(value)=="boolean" then
        for thread=1,7 do
            for _,entry in ipairs(type(settings.threads[thread])=="table" and settings.threads[thread] or EMPTY) do
                local def=type(entry)=="table" and self.definitions[entry.id]
                if def and def.class=="WARRIOR" and def.mode=="adaptive" then
                    if entry.options==nil then entry.options={} end
                    if type(entry.options)=="table" and entry.options.adaptive_demo==nil then
                        entry.options.adaptive_demo=value
                    end
                end
            end
        end
    end
    settings.adaptiveDemoPreferenceVersion=1
end
function Config:Initialize()
    if self.ready then return end
    local db = jungle.Options and jungle.Options.InitializeSettings and jungle.Options:InitializeSettings() or _G.OliaEyes6_Settings
    if type(db) ~= "table" then db = {}; _G.OliaEyes6_Settings = db end
    self.db = db
    if type(db.classes) ~= "table" then db.classes = {} end
    self.legacy = Copy(db.classes)
    if type(db.profiles) ~= "table" then db.profiles = {} end
    if type(db.characters) ~= "table" then db.characters = {} end
    local name, realm = UnitFullName("player")
    self.character = (name or "Player") .. " - " .. (realm or GetRealmName())
    local selected = db.characters[self.character]
    if type(selected) ~= "string" or type(db.profiles[selected]) ~= "table" then
        selected = self.character
        if type(db.profiles[selected]) ~= "table" then db.profiles[selected] = {classes = {}} end
        db.characters[self.character] = selected
    end
    self.selected = selected
    for _, profile in pairs(db.profiles) do
        if type(profile) == "table" and type(profile.classes) ~= "table" then profile.classes = {} end
    end
    -- Upgrade all saved Warrior classes, including profiles not selected by this character.
    for _,profile in pairs(db.profiles) do
        if type(profile)=="table" and type(profile.classes)=="table" then
            local settings=profile.classes.WARRIOR
            if type(settings)=="table" then
                if type(settings.options)~="table" then settings.options=Copy(self.legacy.WARRIOR or {}) end
                if not settings.migrated then self:MigrateWarrior(settings);settings.migrated=true end
                self:MigrateBehaviorSettings(settings)
                self:MigrateAdaptiveDemoPreference(settings)
            end
        end
    end
    self.ready = true
    local settings = self:GetClass(true)
    if type(settings.options) ~= "table" then settings.options = Copy(type(self.legacy[Class()]) == "table" and self.legacy[Class()] or {}) end
    if type(db.routineSchemaVersion)~="number" or db.routineSchemaVersion<3 then db.routineSchemaVersion=3 end
    self:Compile()
end
function Config:Run(engine)
    local plan = self.plans[engine.activeThread]
    if not plan then return false end
    local pole = engine.activeThread == 7 and IsEquippedItemType("Fishing Poles")
    local fishing = pole and plan.fishingEnabled
    for i = 1, #plan do
        local entry = plan[i]
        local def = entry.definition
        if not entry.invalid and not (def.id == "support.fishing" and not pole) and not (def.id == "support.follower" and fishing) then
            jungle.RoutineContext = entry
            -- Fixed Warrior definitions retain migrated behavior and evaluator mode.
            local owns = not def.owns or def.owns(engine.rotation)
            local acted = owns and engine.rotation[def.selector](engine.rotation, def.functions, 1)
            local held = owns and not entry.invalid and def.hold and def.hold()
            if entry.invalid then
                self.errors[entry.thread .. ":" .. entry.index] = entry.invalid
                if not entry.reported then print("|cffff5555[OliaEyes]|r " .. def.label .. ": " .. entry.invalid); entry.reported = true end
            end
            jungle.RoutineContext = nil
            if acted or held then return true end
        end
    end
    return false
end
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_REGEN_ENABLED")
loader:SetScript("OnEvent", function(_, event, loaded)
    if event == "ADDON_LOADED" and loaded == AddonName then Config:Initialize()
    elseif event == "PLAYER_REGEN_ENABLED" and Config.pending then Config:Compile() end
end)
