local Jungle, jungle = ...


--Toggle area to not run all threads as one time
local thread1 = false
local thread2 = false
local thread3 = false
local thread4 = false
-- local pix

function run_thread1()
	thread1 = true
	thread2 = false
	thread3 = false
	thread4 = false
	-- pix = 1
end

function run_thread2()
	thread1 = false
	thread2 = true
	thread3 = false
	thread4 = false
	-- pix = 1
end

function run_thread3()
	thread1 = false
	thread2 = false
	thread3 = true
	thread4 = false
	-- pix = 1
end

function run_thread4()
	thread1 = false
	thread2 = false
	thread3 = false
	thread4 = true
	-- pix = 1
end


local function myClassRotation()
--[[
	main structure:
		...
		if thread1 then
			rotation = jungle.Rotation:new({rota1, rota2, rota3,}, pix) -- will run 1th
				rotation:rotate()		
			rotation = jungle.Rotation:new({rota1,}, pix) 				-- will run 2d
				rotation:dpsRotate()
			rotation = jungle.Rotation:new({rota1,}, pix) 				-- will run 3nd
				rotation:beaconRotate()		
			rotation = jungle.Rotation:new({rota1,}, pix)  				-- will run 4st
				rotation:rotate()		
		...
]]
	local _,engClass,_ = UnitClass('player')
	local _, instanceType = IsInInstance()
	local rotation = jungle.Rotation:new()
	local pixel_reset = jungle.Pixel:new({0,0,0}, 1)
	pixel_reset:clear()


	if engClass == 'PALADIN' then
		-- retri
		if C_Spell.GetSpellInfo('Templar\'s Verdict') then
			return
		end
	elseif engClass == "PRIEST" then
		if C_Spell.GetSpellInfo('Shadowform') then
			return
		end
	elseif engClass == "DRUID" then
		if C_Spell.GetSpellInfo('Lifebloom') then
			if thread1 then
				return
			elseif thread2 then
				if rotation:rotate({jungle.druidBurstHeal,}, 1) then return end
				if rotation:arenaRotate({jungle.druidAntiCcSelf,}, 1) then return end
				if rotation:rotate({jungle.druidSelfDef,}, 1) then return end
				if rotation:rotate({jungle.druidDispell,}, 1) then return end				
				if rotation:rotate({jungle.druidHealBasic,}, 1) then return end
				if rotation:arenaRotate({jungle.druidCCHealer}, 1) then return end
				if rotation:rotate({jungle.druidDefaultAssist,}, 1) then return end
				if rotation:rotate({jungle.druidPreHot,}, 1) then return end
			elseif thread3 then
				return
			elseif thread4 then
				if rotation:dpsRotate({jungle.druidManualCC,}, 1) then return end
			end
		end
	end
	return
end

local color = jungle.Color:new()

local f = CreateFrame("Frame");
function f:onUpdate(sinceLastUpdate)
	local _, instanceType = IsInInstance()
	self.sinceLastUpdate = (self.sinceLastUpdate or 0) + sinceLastUpdate;
	if ( self.sinceLastUpdate >= 0.05 ) then -- in seconds
		-- Do stuff----------------------------------------------
		jungle.updateUnitsData()
			jungle.TableTimerRemove(LoSTable, 1) --update Los table
			jungle.TableTimerRemove(UnitBehindTable, 1) --update Los table
			jungle.TableTimerRemove(UnitInFrontTable, 1) --update Los table
			if (instanceType == 'pvp' or instanceType == 'arena') and GetNumGroupMembers() <= 15 then
				jungle.subTableTimerRemove(Controlled_Root_table, 18)
				jungle.subTableTimerRemove(Controlled_Stun_table, 18)
				jungle.subTableTimerRemove(Disorient_table, 18)
				jungle.subTableTimerRemove(Incapacitate_table, 18)
				jungle.subTableTimerRemove(Silence_table, 18)
			end
			
			myClassRotation()
			-- draw pixel manualy:
			-- local testPix = jungle.Pixel:new({0.3294, 0.2118, 0.0314}, 1)
			-- testPix:set()
		-- Do stuff^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
		self.sinceLastUpdate = 0;
	end
end
f:SetScript("OnUpdate",f.onUpdate)


local example = {
'Mark of the Wild',
}

function tst()
	print(jungle.ReCastCyclone('target', -0.2))
end


function tst2()
	local unitCache = jungle.unitCache
	print((IsPlayerSpell(155675) and not jungle.unitCacheBuff('player', 'Rejuvenation (Germination)', '_PLAYER')))
end