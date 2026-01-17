local Jungle, jungle = ...
local unitCache = jungle.unitCache



local function druidBurstHeal(_friend)
    local set = {
		[1]= {'',
			'Swiftmend',
			(
				not jungle.SpellOnCD('Swiftmend')
				and (jungle.unitCacheBuff(_friend, 'Rejuvenation', '_PLAYER')
					or jungle.unitCacheBuff(_friend, 'Regrowth', '_PLAYER')
						-- or jungle.unitCacheBuff(_friend, 'Wild Growth', '_PLAYER')
				)
				and UnitAffectingCombat(_friend)
				and jungle.LifePercent(_friend)<0.8
			),
			1, 
			0 
		},		
		[2]= {'',
			'Nature\'s Swiftness',
			(
				not jungle.SpellOnCD('Nature\'s Swiftness')
				and jungle.SpellOnCD('Swiftmend')
				and not jungle.Buff('Nature\'s Swiftness', 'player')
				and not jungle.Buff('Incarnation: Tree of Life', 'player')
				and UnitAffectingCombat(_friend)
				and jungle.LifePercent(_friend)<=0.4
			),
			1, 
			0 
		},		
		[3]= {'',
			'Regrowth',
			(
				jungle.ReadyCastSpell('Regrowth', _friend)
				and C_Spell.GetSpellInfo(8936).castTime==0
				and UnitAffectingCombat(_friend)
				and jungle.LifePercent(_friend)<=0.5
			),
			1, 
			0 
		},
		[4]= {'',
			'Ironbark',
			(
				jungle.ReadyCastSpell('Ironbark', _friend)
				and UnitAffectingCombat(_friend)
				and jungle.LifePercent(_friend)<=0.6
			),
			1, 
			0 
		},
		[5]= {'',
			'Over growth pls',
			(
				jungle.ReadyCastSpell('Overgrowth', _friend)
				and not (jungle.unitCacheBuff(_friend, 'Rejuvenation', '_PLAYER')
					and  jungle.unitCacheBuff(_friend, 'Regrowth', '_PLAYER'))
				and not UnitCastingInfo('player')
				and UnitAffectingCombat(_friend)
				and (jungle.LifePercent(_friend)<=0.5 or jungle.targetedByCount(_friend)>=2)
			),
			1, 
			0 
		},		
		[6]= {'',
			'Grove Guardians',
			(
				jungle.ReadyCastSpell('Grove Guardians', _friend)
				and not UnitCastingInfo('player')
				and UnitAffectingCombat(_friend)
				and jungle.LifePercent(_friend)<=0.7
			),
			1, 
			0 
		},		
	}
	return set
end
jungle.druidBurstHeal = druidBurstHeal


local function druidSelfDef()
    local set = {
		[1]= {'',
			'Renewal',
			(
				jungle.ReadyCastSpell('Renewal')
				and jungle.LifePercent('player')<0.35
				and UnitAffectingCombat('player')
			),
			1, 
			0 
		},		
		[2]= {'',
			'Bear Form',
			(
				jungle.ReadyCastSpell('Bear Form')
				and jungle.SpellOnCD('Renewal')
				and not jungle.SpellOnCD('Frenzied Regeneration')
				and jungle.LifePercent('player')<0.35
				and UnitAffectingCombat('player')
				and GetShapeshiftForm()~=1
			),
			1, 
			0 
		},		
		[3]= {'',
			'Frenz Regen',
			(
				not jungle.SpellOnCD('Frenzied Regeneration')
				and jungle.SpellOnCD('Renewal')
				and jungle.LifePercent('player')<0.35
				and UnitAffectingCombat('player')
				and GetShapeshiftForm()==1
				and UnitPower('player', 1)>=10
			),
			1, 
			0 
		},		
	}
	return set
end
jungle.druidSelfDef = druidSelfDef


local function druidHealBasic(_friend)
    local set = {
		[1]= {'',
			'Regrowth',
			(
				jungle.ReadyCastSpell('Regrowth', _friend)
				and not UnitCastingInfo('player')
				and (GetUnitSpeed('player')==0 or C_Spell.GetSpellInfo(8936).castTime==0)
				and jungle.LifePercent(_friend)<=0.4
			),
			1, 
			0 
		},		
		[2]= {'',
			'Grove Guardians',
			(
				jungle.ReadyCastSpell('Grove Guardians', _friend)
				and not UnitCastingInfo('player')
				and GetUnitSpeed('player')~=0
				and UnitAffectingCombat(_friend)
				and jungle.LifePercent(_friend)<=0.6
			),
			1, 
			0 
		},		
		[3]= {'',
			'Cenarion Ward',
			(
				jungle.ReadyCastSpell('Cenarion Ward', _friend)
				and jungle.LifePercent(_friend)<0.8
			),
			1, 
			0 
		},		
		[4]= {'',
			'Rejuvenation',
			(
				jungle.ReadyCastSpell('Rejuvenation', _friend)
				and not jungle.unitCacheBuff(_friend, 'Rejuvenation', '_PLAYER')
				and jungle.targetedByCount(_friend)>=1		
			),
			1, 
			0 
		},		
		[5]= {'',
			'Lifebloom',
			(
				(IsPlayerSpell(392301) and jungle.bloomFriendsCount(0.9)<2)
				and not jungle.unitCacheBuff(_friend, 'Lifebloom', '_PLAYER', 3)
				and jungle.ReadyCastSpell('Lifebloom', _friend)
				and jungle.LifePercent(_friend)<0.9
			),
			1, 
			0 
		},		
		[6]= {'Germination',
			'Rejuvenation',
			(
				IsPlayerSpell(155675) 
				and jungle.ReadyCastSpell('Rejuvenation', _friend)
				and not jungle.unitCacheBuff(_friend, 'Rejuvenation (Germination)', '_PLAYER')
				and jungle.LifePercent(_friend)<0.9
			),
			1, 
			0 
		},				
		[7]= {'',
			'Regrowth',
			(
				jungle.ReadyCastSpell('Regrowth', _friend)
				and not UnitCastingInfo('player')
				and (GetUnitSpeed('player')==0 or C_Spell.GetSpellInfo(8936).castTime==0)
				and jungle.Buff('Clearcasting', 'player')
			),
			1, 
			0 
		},		
	}
	return set
end
jungle.druidHealBasic = druidHealBasic


local function druidPreHot(_friend)
    local set = {
		[1]= {'',
			'Regrowth',
			(
				jungle.ReadyCastSpell('Regrowth', _friend)
				and not UnitCastingInfo('player')
				and (GetUnitSpeed('player')==0 or C_Spell.GetSpellInfo(8936).castTime==0)
				and jungle.Buff('Clearcasting', 'player')
				and jungle.targetedByCount(_friend)>=1
			),
			1, 
			0 
		},		
		[2]= {'',
			'Cenarion Ward',
			(
				jungle.ReadyCastSpell('Cenarion Ward', _friend)
				and jungle.targetedByCount(_friend)>=1			
			),
			1, 
			0 
		},		
		[3]= {'',
			'Rejuvenation',
			(
				jungle.ReadyCastSpell('Rejuvenation', _friend)
				and not jungle.unitCacheBuff(_friend, 'Rejuvenation', '_PLAYER')
				and jungle.targetedByCount(_friend)>=1		
			),
			1, 
			0 
		},		
		[4]= {'',
			'Lifebloom',
			(
				(IsPlayerSpell(392301) and jungle.bloomFriendsCount(1)<2)
				and not jungle.unitCacheBuff(_friend, 'Lifebloom', '_PLAYER', 3)
				and jungle.ReadyCastSpell('Lifebloom', _friend)
				and jungle.targetedByCount(_friend)>=1
			),
			1, 
			0 
		},		
		[5]= {'',
			'Cenarion Ward',
			(
				jungle.ReadyCastSpell('Cenarion Ward', _friend)
				and jungle.targetedByCount(_friend)>=2	
			),
			1, 
			0 
		},		
		[6]= {'',
			'Cenarion Ward',
			(
				-- jungle.ReadyCastSpell('Cenarion Ward', _friend)
				-- and jungle.targetedByCount(_friend)>=1	
				false
			),
			1, 
			0 
		},		
		[7]= {'',
			'Rejuvenation',
			(
				jungle.ReadyCastSpell('Rejuvenation', _friend)
				and not jungle.unitCacheBuff(_friend, 'Rejuvenation', '_PLAYER')
			),
			1, 
			0 
		},		
		[8]= {'',
			'Regrowth',
			(
				jungle.ReadyCastSpell('Regrowth', _friend)
				and not UnitCastingInfo('player')
				and (GetUnitSpeed('player')==0 or C_Spell.GetSpellInfo(8936).castTime==0)
				and jungle.Buff('Clearcasting', 'player')
			),
			1, 
			0 
		},		
		[9]= {'',
			'Lifebloom',
			(
				(IsPlayerSpell(392301) and jungle.bloomFriendsCount(1)<2)
				and not jungle.unitCacheBuff(_friend, 'Lifebloom', '_PLAYER', 3)
				and jungle.ReadyCastSpell('Lifebloom', _friend)
			),
			1, 
			0 
		},	
		[10]= {'Germination',
			'Rejuvenation',
			(
				IsPlayerSpell(155675) 
				and jungle.ReadyCastSpell('Rejuvenation', _friend)
				and not jungle.unitCacheBuff(_friend, 'Rejuvenation (Germination)', '_PLAYER')
			),
			1, 
			0 
		},				
	}
	return set
end
jungle.druidPreHot = druidPreHot


local function druidDefaultAssist(_friend)
    local set = {
		[1]= {'',
			'Mark of the Wild',
			(
				jungle.ReadyCastSpell('Mark of the Wild', _friend)
				and not jungle.unitCacheBuff(_friend, 'Mark of the Wild')
				and (not UnitAffectingCombat('player') or not jungle.CheckIfSpellCastedRecently(10, 'Mark of the Wild'))
			),
			1, 
			0 
		},
	}
	return set
end
jungle.druidDefaultAssist = druidDefaultAssist


local function druidDispell(_friend)
    local set = {
		[1]= {'',
			'Nature\'s Cure',
			(
				jungle.ReadyCastSpell('Nature\'s Cure', _friend)
				and not jungle.unitDebuff(_friend, 'Vampiric Touch')
				and not jungle.unitDebuff(_friend, 'Unstable Affliction')
				and jungle.CheckDispellableDebuffs(_friend, jungle.allCcList , 'Magic', 'Curse', 'Poison')
			),
			1, 
			0 
		},
	}
	return set
end
jungle.druidDispell = druidDispell


local function druidCCHealer(_target)
	local s_ = jungle.Controlled_Stun_id
	local d_ = jungle.Disorient_id
	local i_ = jungle.Incapacitate_id
	local si_ = jungle.Silence_id
	local r_ = jungle.Controlled_Root_id

    local set = {
		[1]= {'',
			'Cyclone',
			(
				jungle.ReadyCastSpell('Cyclone', _target)
				and GetUnitSpeed('player')==0
				and not UnitCastingInfo('player')
				and jungle.IsUnitHealer(_target)
				and jungle.getDR(_target, Disorient_table)~=3
				and jungle.ReCastCyclone(_target, -0.2)
				and (
					(UnitExists('arena1') and not UnitIsUnit('arena1', 'player') and not UnitIsUnit('arena1target', _target)) 
					and 
					(UnitExists('arena2') and not UnitIsUnit('arena2', 'player') and not UnitIsUnit('arena2target', _target)) 
					and 
					(UnitExists('arena3') and not UnitIsUnit('arena3', 'player') and not UnitIsUnit('arena3target', _target))
				)

			),
			1, 
			0 
		},
		[2]= {'',
			'Cyclone',
			(
				jungle.ReadyCastSpell('Cyclone', _target)
				and GetUnitSpeed('player')==0
				and not jungle.isHasOneOfBuffs(_target, jungle.ccImmunityBuffs)
				and not jungle.unitCacheBuff(_target, 'Grounding Totem Effect')
				and not jungle.unitCacheBuff(_target, 'Spell Reflection')
				and jungle.IsUnitHealer(_target)
				and jungle.getDR(_target, Disorient_table)==0
				and jungle.getCasterUnitCCWindow(_target, {s_,d_,i_,si_}, 1.2)
			),
			1, 
			0 
		},
		[3]= {'',
			'Mighty Bash',
			(
				jungle.ReadyCastSpell('Mighty Bash', _target)
				and not jungle.isHasOneOfBuffs(_target, jungle.ccImmunityBuffs)
				and jungle.IsUnitHealer(_target)
				and jungle.getDR(_target, Controlled_Stun_table)==0
				and jungle.getCasterUnitCCWindow(_target, {s_,d_,i_,si_}, 0.8)
			),
			1, 
			0 
		},
		[4]= {'Cyclone on healer',
			'Cyclone',
			(
				jungle.ReadyCastSpell('Cyclone', _target)
				and jungle.IsUnitHealer(_target)
				and GetUnitSpeed('player')==0
				and jungle.getDR(_target, Disorient_table)==0
				and (
					(UnitExists('arena1') and not UnitIsUnit('arena1', 'player') and not UnitIsUnit('arena1target', _target)) 
					and 
					(UnitExists('arena2') and not UnitIsUnit('arena2', 'player') and not UnitIsUnit('arena2target', _target)) 
					and 
					(UnitExists('arena3') and not UnitIsUnit('arena3', 'player') and not UnitIsUnit('arena3target', _target))
				)
				and not jungle.CheckIfSpellCastedRecently(6, 'Cyclone')
				and not jungle.isHasOneOfBuffs(_target, jungle.ccImmunityBuffs)
				and not jungle.unitCacheBuff(_target, 'Grounding Totem Effect')
				and not jungle.unitCacheBuff(_target, 'Spell Reflection')
				and not jungle.getCasterUnitCCWindow(_target, {s_,d_,i_,si_}, 8)
			),
			1, 
			0 
		},
		[5]= {'random Cyclone on not targeted',
			'Cyclone',
			(
				jungle.ReadyCastSpell('Cyclone', _target)
				and GetUnitSpeed('player')==0
				and jungle.getDR(_target, Disorient_table)==0
				and (
					(UnitExists('arena1') and not UnitIsUnit('arena1', 'player') and not UnitIsUnit('arena1target', _target)) 
					and 
					(UnitExists('arena2') and not UnitIsUnit('arena2', 'player') and not UnitIsUnit('arena2target', _target)) 
					and 
					(UnitExists('arena3') and not UnitIsUnit('arena3', 'player') and not UnitIsUnit('arena3target', _target))
				)
				and jungle.LifePercent(_target)>0.9
				and not jungle.CheckIfSpellCastedRecently(6, 'Cyclone')
				and not jungle.isHasOneOfBuffs(_target, jungle.ccImmunityBuffs)
				and not jungle.unitCacheBuff(_target, 'Grounding Totem Effect')
				and not jungle.unitCacheBuff(_target, 'Spell Reflection')
				and not jungle.getCasterUnitCCWindow(_target, {s_,d_,i_,si_}, 8)
			),
			1, 
			0 
		},
		[6]= {'cast instant roots',
			'Entangling Roots',
			(
				jungle.ReadyCastSpell('Entangling Roots', _target)
				and C_Spell.GetSpellInfo(339).castTime==0
				and not jungle.CheckIfSpellCastedRecently(4, 'Entangling Roots')
				and not jungle.isHasOneOfBuffs(_target, jungle.ccImmunityBuffs)
				and not jungle.unitCacheBuff(_target, 'Grounding Totem Effect')
				and not jungle.unitCacheBuff(_target, 'Spell Reflection')
				and not jungle.isHasOneOfBuffs(_target, jungle.slowImmunityBuffs)
				and jungle.getDR(_target, Controlled_Root_table)<3
			),
			1, 
			0 
		},
	}
	return set
end
jungle.druidCCHealer = druidCCHealer


local function druidAntiCcSelf(_target)
    local set = {
		[1]= {'',
			'Bear Form',
			(
				jungle.isCastingOneOfSpells(_target, 1, jungle.druidGoToFormAntiCC)
				and GetShapeshiftForm()==0
				and C_Spell.IsSpellInRange('Cyclone', _target)
			),
			1, 
			0 
		},		
		[2]= {'',
			'Shadowmeld(Racial)',
			(
				not jungle.SpellOnCD('Shadowmeld(Racial)')
				and jungle.isCastingOneOfSpells(_target, 1.3, jungle.druidGoToShadowmeltAntiCC)
				and C_Spell.IsSpellInRange('Cyclone', _target)
			),
			1, 
			0 
		},		
	}
	return set
end
jungle.druidAntiCcSelf = druidAntiCcSelf


local function druidManualCC(_target)
	local s_ = jungle.Controlled_Stun_id
	local d_ = jungle.Disorient_id
	local i_ = jungle.Incapacitate_id
	local si_ = jungle.Silence_id
	local r_ = jungle.Controlled_Root_id

    local set = {
		[1]= {'',
			'Cyclone',
			(
				jungle.ReadyCastSpell('Cyclone', _target)
				and not jungle.CheckIfSpellCastedRecently(1, 'Cyclone')
				and not UnitCastingInfo('player')
				and GetUnitSpeed('player')==0
				and jungle.ReCastCyclone(_target, 0.05)
				and jungle.getDR(_target, Disorient_table)~=3
			),
			1, 
			0 
		},
	}
	return set
end
jungle.druidManualCC = druidManualCC

-- TBC ACTUAL ROTATION
local function druidBuff(_friend)
    local set = {
		[1]= {'',
			'Mark of the Wild',
			(
				jungle.ReadyCastSpell('Mark of the Wild', _friend)
				and (not jungle.unitCacheBuff(_friend, 'Mark of the Wild') and not jungle.unitCacheBuff(_friend, 'Gift of the Wild'))
			),
			1, 
			0 
		},
		[2]= {'',
			'Thorns',
			(
				jungle.ReadyCastSpell('Thorns', _friend)
				and not jungle.unitCacheBuff(_friend, 'Thorns')
			),
			1, 
			0 
		},
	}
	return set
end
jungle.druidBuff = druidBuff


local function druidDpsBasic(_target)
    local set = {
	--Caster Form
		[1]= {'',
			'Moonfire',
			(	
				GetShapeshiftForm()==0
				and (UnitAffectingCombat('player') or GetUnitSpeed('player')~=0)
				and jungle.ReadyCastSpell('Moonfire', _target)
				and not jungle.Debuff('Moonfire', _target, '|PLAYER')

			),
			1, 
			0 
		},		
		[2]= {'',
			'Wrath',
			(
				GetShapeshiftForm()==0
				and jungle.ReadyCastSpell('Wrath', _target)
				and GetUnitSpeed('player')==0
			),
			1, 
			0 
		},
	--Bear
		[3]= {'',
			'Maul',
			(	
				GetShapeshiftForm()==1
				and jungle.ReadyCastSpell('Maul')
				and not IsCurrentSpell(select(7, GetSpellInfo("Maul")))


			),
			1, 
			0 
		},		
		[4]= {'',
			'Attack',
			(
				not IsCurrentSpell(6603)
			),
			1, 
			0 
		},			
	}
	return set
end
jungle.druidDpsBasic = druidDpsBasic