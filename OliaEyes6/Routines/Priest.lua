local Jungle, jungle = ...
local unitCache = jungle.unitCache

local noStopChanneling,_,_,_,_,_,_,_ = UnitChannelInfo('player')
local _, instanceType = IsInInstance()


local function priestShadowBasic(_target)
	local noStopChanneling,_,_,_,_,_,_,_ = UnitChannelInfo('player')
    local set = {
		[1]= {'dps',
			'Void Bolt',
			(
				IsSpellKnown(228260)
				and jungle.Buff('Voidform', 'player')
				and jungle.ReadyCastSpell('Void Bolt', _target)
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
				and not jungle.isTargetBehind(_target)
			),
			1, 
			0 
		},
		[2]= {'dps',
			'Void Torrent',
			(
				jungle.ReadyCastSpell('Void Torrent', _target)
				and GetUnitSpeed('player')==0 -- if talet picked u can do it in moving
				and jungle.Debuff('Vampiric Touch', _target, '|PLAYER')
				and jungle.Debuff('Devouring Plague', _target, '|PLAYER')
				and not UnitChannelInfo('player')
			),
			1, 
			0 
		},				
		[3]= {'dps',
			'Devouring Plague',
			(
				jungle.ReadyCastSpell('Devouring Plague', _target)
				and not UnitCastingInfo('player')
				and jungle.Debuff('Vampiric Touch', _target, '|PLAYER')
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
			),
			1, 
			0 
		},
		[4]= {'dps',
			'Void Blast',
			(
				IsSpellKnown(450983)
				-- and (jungle.Buff('Mind Melt', 'player') and IsPlayerSpell(73510))
				and (GetSpellCooldown('Void Blast')==0)
				and (GetUnitSpeed('player')==0 or jungle.Buff('Shadowy Insight', 'player'))
				and not UnitCastingInfo('player')
				and not jungle.CheckIfSpellCastedRecently(1.5, 'Void Blast')
				and not UnitChannelInfo('player')
				and not jungle.isTargetBehind(_target)
			),
			1, 
			0 
		},
		[5]= {'',
			'Mind Flay: Insanity',
			(
				-- (jungle.Buff('Mind Flay: Insanity', 'player') or jungle.Buff('Mind Spike: Insanity', 'player')) 
				-- and (jungle.ReadyCastSpell('Mind Flay', 'target') or jungle.ReadyCastSpell('Mind Spike', 'target'))
				-- and ((not jungle.Buff('Mind Melt', 'player') or GetSpellCooldown('Mind Blast')==0) and (jungle.Buff('Mind Melt', 'player') and IsPlayerSpell(73510)))
				-- and GetUnitSpeed('player')==0
				-- and not jungle.CheckIfSpellCastedRecently(1.5, 'Mind Sike: Insanity')
				-- and not UnitCastingInfo('player')
				-- and not UnitChannelInfo('player')
				-- and not jungle.isTargetBehind(_target)
				false
			),
			1, 
			0 
		},		
		[6]= {'one time purge',
			'Dispel Magic',
			(
				jungle.ReadyCastSpell('Dispel Magic', _target)
				and jungle.CheckIfSpellCastedRecently(5, 'Dispel Magic')
				and jungle.hasAuraType(_target, 'HELPFUL', 'Magic')
				and not UnitCastingInfo('player')
				and not UnitChannelInfo('player')

			),
			1, 
			0 
		},	
		
		[7]= {'dps',
			'Shadow Word: Death',
			(
				jungle.ReadyCastSpell('Shadow Word: Death', _target)
				and (jungle.LifePercent(_target)<0.2 or jungle.Buff('Deathspeaker', 'player'))
				and not UnitCastingInfo('player')
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
			),
			1, 
			0 
		},
		[8]= {'dps',
			'Stopcasting',
			(
				-- UnitCastingInfo('player')=='Vampiric Touch'
				-- and (jungle.Debuff('Vampiric Touch', _target, '|PLAYER'))
				false

			),
			1, 
			0 
		},			
		[9]= {'dps',
			'Vampiric Touch',
			(
				jungle.ReadyCastSpell('Vampiric Touch', _target)
				and not UnitCastingInfo('player')
				and not jungle.CheckIfSpellCastedRecently(1, 'Vampiric Touch')
				and (GetUnitSpeed('player')==0 or jungle.Buff('Unfurling Darkness', 'player'))
				and (
					(not jungle.Debuff('Vampiric Touch', _target, '|PLAYER') or jungle.Debuff('Vampiric Touch', _target, '|PLAYER', 1.5) or jungle.Buff('Unfurling Darkness', 'player', 2))
					and
					UnitName(_target)~=jungle.shadowCrashTarget()
				)
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'

			),
			1, 
			0 
		},
		[10]= {'dps',
			'Mind Blast',
			(
				jungle.ReadyCastSpell('Mind Blast', _target)
				and (jungle.Buff('Mind Melt', 'player') or not IsPlayerSpell(73510))
				and (GetUnitSpeed('player')==0 or jungle.Buff('Shadowy Insight', 'player'))
				and not UnitCastingInfo('player')
				and not jungle.CheckIfSpellCastedRecently(1.5, 'Mind Blast')
				and not UnitChannelInfo('player')
				and not jungle.isTargetBehind(_target)
			),
			1, 
			0 
		},
		[11]= {'dps',
			'Halo',
			(
				IsSpellKnown(120644)
				and jungle.ReadyCastSpell('Halo')
				and GetUnitSpeed('player')==0
				and not UnitChannelInfo('player')
				and C_Spell.IsSpellInRange('Psychic Horror', _target)
			),
			1, 
			0 
		},				
		[12]= {'dps',
			'Divine Star',
			(
				IsSpellKnown(122121)
				and jungle.ReadyCastSpell('Divine Star')
				and not UnitChannelInfo('player')
				and CheckInteractDistance(_target, 3)
			),
			1, 
			0 
		},		
		[13]= {'',
			'Mind Flay',
			(
				-- (jungle.ReadyCastSpell('Mind Flay', _target) or jungle.ReadyCastSpell('Mind Spike', _target))
				jungle.ReadyCastSpell('Mind Flay', _target)
				-- and jungle.Debuff('Shadow Word: Pain', _target, '|PLAYER')
				and GetUnitSpeed('player')==0
				and not UnitCastingInfo('player')
				and not jungle.CheckIfSpellCastedRecently(1.5, 'Mind Sike')
				and not UnitChannelInfo('player')
				and not jungle.isTargetBehind(_target)
			),
			1, 
			0 
		},		
		[14]= {'dps',
			'Shadow Word: Pain',
			(
				jungle.ReadyCastSpell('Shadow Word: Pain', _target)
				and (not jungle.Debuff('Shadow Word: Pain', _target, '|PLAYER') or jungle.Debuff('Shadow Word: Pain', _target, '|PLAYER', 1))
				and not UnitCastingInfo('player')
				and not UnitChannelInfo('player')
			),
			1, 
			0 
		},	
		[15]= {'dps',
			'Dispel Magic',
			(
				jungle.ReadyCastSpell('Dispel Magic', _target)
				and jungle.hasAuraType(_target, 'HELPFUL', 'Magic')
				and not UnitCastingInfo('player')
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'

			),
			1, 
			0 
		},	
		[16]= {'dps',
			'Shadow Word: Death',
			(
				jungle.ReadyCastSpell('Shadow Word: Death', _target)
				and jungle.LifePercent('player')>0.5
				and not UnitCastingInfo('player')
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'

			),
			1, 
			0 
		},	
		[17]= {'dps',
			'Shadow Word: Pain',
			(
				jungle.ReadyCastSpell('Shadow Word: Pain', _target)
				and not UnitCastingInfo('player')
				and not UnitChannelInfo('player')
			),
			1, 
			0 
		},	
	}
	return set
end
jungle.priestShadowBasic = priestShadowBasic


local function priestShadowBurst(_target)
	local noStopChanneling,_,_,_,_,_,_,_ = UnitChannelInfo('player')
    local set = {
		[1]= {'dps',
			'Shadow Crash',
			(
				IsSpellKnown(457042)
				and jungle.ReadyCastSpell('Shadow Crash', _target)
				and (not jungle.Debuff('Vampiric Touch', _target, '|PLAYER') or jungle.Debuff('Vampiric Touch', _target, '|PLAYER', 1.5))
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
			),
			1, 
			0 
		},
		[2]= {'pvp on only, so check with ID',
			'Psyfiend',
			(
				IsSpellKnown(211522)
				and C_SpecializationInfo.CanPlayerUsePVPTalentUI()
				and jungle.ReadyCastSpell('Psyfiend', _target)
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
			),
			1, 
			0 
		},				
		[3]= {'dps',
			'fiend_fiend',
			(
				(C_Spell.GetSpellCooldown('Shadowfiend').startTime == 0)
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
			),
			1, 
			0 
		},				
		[4]= {'dps',
			'Void Eruption',
			(
				IsSpellKnown(228260)
				and jungle.ReadyCastSpell('Void Eruption', _target)
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
			),
			1, 
			0 
		},		
		[5]= {'dps',
			'Dark Ascension',
			(
				IsSpellKnown(391109)
				and jungle.ReadyCastSpell('Dark Ascension')
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
			),
			1, 
			0 
		},		
		[6]= {'pvp on only, so check with ID',
			'Mindgames',
			(
				IsSpellKnown(375901)
				and jungle.ReadyCastSpell('Mindgames', _target)
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
				and not jungle.isTargetBehind(_target)
			),
			1, 
			0 
		},		
	}
	return set
end
jungle.priestShadowBurst = priestShadowBurst


local function priestShadowCC(_target)
	local noStopChanneling,_,_,_,_,_,_,_ = UnitChannelInfo('player')
    local set = {
		[1]= {'pvp',
			'Silence',
			(
				instanceType ~= 'arena'
				and jungle.isCasting(_target, 0.5)
				and UnitExists('target') 
				and UnitCanAttack('player', 'target')
				and jungle.ReadyCastSpell('Silence', 'target') 
			),
			1, 
			0 
		},
		[2]= {'pvp',
			'Psychic Horror',
			(
				instanceType ~= 'arena'
				and jungle.isCasting(_target, 0.8)
				and UnitExists('target') 
				and UnitCanAttack('player', 'target')
				and  not jungle.ReadyCastSpell('Silence', 'target') 
				and jungle.ReadyCastSpell('Psychic Horror', 'target') 
			),
			1, 
			0 
		},
	}
	return set
end
jungle.priestShadowCC = priestShadowCC


local function priestShadowAoE(_target)
	local noStopChanneling,_,_,_,_,_,_,_ = UnitChannelInfo('player')
    local set = {
		[1]= {'dps',
			'Shadow Crash',
			(
				IsSpellKnown(457042)
				and jungle.ReadyCastSpell('Shadow Crash', _target)
				and (not jungle.Debuff('Vampiric Touch', _target, '|PLAYER') or jungle.Debuff('Vampiric Touch', _target, '|PLAYER', 1.5))
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
			),
			1, 
			0 
		},
		[2]= {'dps',
			'Void Eruption',
			(
				-- jungle.ReadyCastSpell('Void Eruption', _target)
				-- and noStopChanneling ~= 'Void Torrent'
				-- and noStopChanneling ~= 'Mind Flay: Insanity'
				false
			),
			1, 
			0 
		},
		[3]= {'',
			'Void Torrent',
			(
				jungle.ReadyCastSpell('Void Torrent', _target)
				and GetUnitSpeed('player')==0
				and not UnitChannelInfo('player')
			),
			1, 
			0 
		},	
		[4]= {'dps',
			'Halo',
			(
				IsSpellKnown(120644)
				and jungle.ReadyCastSpell('Halo')
				and GetUnitSpeed('player')==0
				and not UnitChannelInfo('player')
				and C_Spell.IsSpellInRange('Psychic Horror', _target)
			),
			1, 
			0 
		},								
	}
	return set
end
jungle.priestShadowAoE = priestShadowAoE


local function priestShadowInfusion(_friend)
	local _,engClass,_ = UnitClass(_friend)
	local friendStatus = jungle.unitCache[_friend]
	local noStopChanneling,_,_,_,_,_,_,_ = UnitChannelInfo('player')
    local set = {
		[1]= {'dps',
			'Power Infusion',
			(
				jungle.ReadyCastSpell('Power Infusion', _friend)
				and engClass == 'WARLOCK'
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
				and UnitAffectingCombat('player')
			),
			1, 
			0 
		},
		[2]= {'dps',
			'Power Infusion',
			(
				jungle.ReadyCastSpell('Power Infusion', _friend)
				and engClass == 'MAGE'
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
				and UnitAffectingCombat('player')
			),
			1, 
			0 
		},
		[3]= {'dps',
			'Power Infusion',
			(
				jungle.ReadyCastSpell('Power Infusion', _friend)
				and engClass == 'PRIEST'
				and not friendStatus.isMe
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
				and UnitAffectingCombat('player')
			),
			1, 
			0 
		},
		[4]= {'dps',
			'Power Infusion',
			(
				jungle.ReadyCastSpell('Power Infusion', _friend)
				and engClass == 'WARLOCK'
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
				and UnitAffectingCombat('player')
			),
			1, 
			0 
		},
		[5]= {'dps',
			'Power Infusion',
			(
				jungle.ReadyCastSpell('Power Infusion', _friend)
				and engClass == 'SHAMAN'
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
				and UnitAffectingCombat('player')
			),
			1, 
			0 
		},
		[6]= {'dps',
			'Power Infusion',
			(
				jungle.ReadyCastSpell('Power Infusion', _friend)
				and engClass == 'DRUID'
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
				and UnitAffectingCombat('player')
			),
			1, 
			0 
		},
		[7]= {'dps',
			'Power Infusion',
			(
				jungle.ReadyCastSpell('Power Infusion', _friend)
				and engClass == 'PALADIN'
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
				and UnitAffectingCombat('player')
			),
			1, 
			0 
		},
		[8]= {'dps',
			'Power Infusion',
			(
				jungle.ReadyCastSpell('Power Infusion', _friend)
				and engClass == 'MONK'
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
				and UnitAffectingCombat('player')
			),
			1, 
			0 
		},
		[9]= {'dps',
			'Power Infusion',
			(
				jungle.ReadyCastSpell('Power Infusion', _friend)
				and engClass == 'DRACTHYR '
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
				and UnitAffectingCombat('player')
			),
			1, 
			0 
		},
		[10]= {'dps',
			'Power Infusion',
			(
				jungle.ReadyCastSpell('Power Infusion', _friend)
				and friendStatus.isMe
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
				and UnitAffectingCombat('player')
			),
			1, 
			0 
		},
	}
	return set
end
jungle.priestShadowInfusion = priestShadowInfusion


local function priestShadowHeal(_friend)
	local noStopChanneling,_,_,_,_,_,_,_ = UnitChannelInfo('player')
    local set = {
		[1]= {'',
			'Flash Heal',
			(
				jungle.ReadyCastSpell('Flash Heal', _friend)
				and GetUnitSpeed('player')==0
				and not UnitChannelInfo('player')
				and jungle.LifePercent(_friend)<=0.8
			),
			1, 
			0 
		},		
		[2]= {'',
			'Power Word: Shield',
			(
				jungle.ReadyCastSpell('Power Word: Shield', _friend)
				and not jungle.unitCacheBuff(_friend, 'Power Word: Shield', '_PLAYER')
				and not UnitChannelInfo('player')
				and jungle.LifePercent(_friend)<=0.9
				and UnitAffectingCombat(_friend)
			),
			1, 
			0 
		},		
		[3]= {'',
			'Flash Heal',
			(
				jungle.ReadyCastSpell('Flash Heal', _friend)
				and not UnitChannelInfo('player')
				and GetUnitSpeed('player')==0
				and unitCache[_friend].isMe
			),
			1, 
			0 
		},	
	}
	return set
end
jungle.priestShadowHeal = priestShadowHeal


local function priestShadowSupport(_friend)
	local friendStatus = jungle.unitCache[_friend]
	local noStopChanneling,_,_,_,_,_,_,_ = UnitChannelInfo('player')
    local set = {
		[1]= {'dps',
			'Power Word: Fortitude',
			(
				jungle.ReadyCastSpell('Power Word: Fortitude', 'player')
				and not jungle.Buff('Power Word: Fortitude', 'player')
				and not UnitAffectingCombat('player')
			),
			1, 
			0 
		},
		[2]= {'dps',
			'Shadowform',
			(
				jungle.ReadyCastSpell('Shadowform')
				and not jungle.Buff('Shadowform', 'player')
				and not jungle.Buff('Voidform', 'player')
			),
			1, 
			0 
		},	
		[3]= {'',
			'Power Word: Life',
			(
				IsSpellKnown(373481)
				and jungle.ReadyCastSpell('Power Word: Life', _friend)
				and jungle.LifePercent(_friend)<0.35
				and UnitAffectingCombat(_friend)
				-- and noStopChanneling ~= 'Void Torrent'
				-- and noStopChanneling ~= 'Mind Flay: Insanity'

			),
			1, 
			0 
		},				
		[4]= {'',
			'Vampiric Embrace',
			(
				-- not jungle.ReadyCastSpell('Power Word: Life', _friend)
				jungle.ReadyCastSpell('Vampiric Embrace')
				and jungle.LifePercent(_friend)<0.35
				and UnitAffectingCombat('player')
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
			),
			1, 
			0 
		},				
		[5]= {'',
			'Desperate Prayer',
			(
				jungle.LifePercent('player')<0.3
				and (
					(IsSpellKnown(373481) and not jungle.ReadyCastSpell('Power Word: Life', _friend))
					or
					not IsSpellKnown(373481)
				)
				and jungle.ReadyCastSpell('Desperate Prayer')
				and UnitAffectingCombat('player')
			),
			1, 
			0 
		},				
		[6]= {'',
			'Void Shift',
			(
				-- save friend
				(
					IsSpellKnown(108968)
					and jungle.ReadyCastSpell('Void Shift', _friend)
					and not UnitIsUnit('player', _friend)
					and UnitAffectingCombat(_friend)
					and jungle.LifePercent(_friend)<0.25
					and (
						(IsSpellKnown(373481) and not jungle.ReadyCastSpell('Power Word: Life', _friend))
						or
						not IsSpellKnown(373481)
					)
				)
					or
				-- save me
				(
					IsSpellKnown(108968)
					and not friendStatus.isMe
					and jungle.IsUnitHealer(_friend)
					and jungle.ReadyCastSpell('Void Shift', _friend)
					and jungle.LifePercent('player')<0.25
					and UnitAffectingCombat('player')
					and (
						(IsSpellKnown(373481) and not jungle.ReadyCastSpell('Power Word: Life', 'player'))
						or
						not IsSpellKnown(373481)
					)
					and (
						(IsSpellKnown(19236) and not jungle.ReadyCastSpell('Desperate Prayer'))
						or
						not IsSpellKnown(19236)
					)
				)
			),
			1, 
			0 
		},				
	}
	return set
end
jungle.priestShadowSupport = priestShadowSupport


local function shadowAutoEmenemy(_target)
	local noStopChanneling,_,_,_,_,_,_,_ = UnitChannelInfo('player')

	local r_ = jungle.Controlled_Root_id
	local s_ = jungle.Controlled_Stun_id
	local d_ = jungle.Disorient_id
	local i_ = jungle.Incapacitate_id
	local si_ = jungle.Silence_id
	
    local set = {
		--remove reflect/graunding with pain + stopcasting
		[1]= {'dps',
			'Shadow Word: Pain',
			(
				jungle.Buff('Grounding Totem Effect', _target)
			),
			1, 
			0 
		},
		[2]= {'Interrupt CC',
			'Silence',
			(
				C_Spell.GetSpellCooldown('Silence').startTime == 0
				and C_Spell.IsSpellInRange('Silence', _target)
				and jungle.isCastingOneOfSpells(_target, 1, jungle.spellsCcInterrupt)
			),
			1, 
			0 
		},
		[3]= {'Interrupt CC',
			'Psychic Scream',
			(
				C_Spell.GetSpellCooldown('Psychic Scream').startTime == 0
				and C_Spell.IsSpellInRange('Psychic Scream', _target)
				and C_Spell.GetSpellCooldown('Silence').startTime ~= 0
				and jungle.isCastingOneOfSpells(_target, 1, jungle.spellsCcInterrupt)
			),
			1, 
			0 
		},
		[4]= {'Interrupt CC',
			'Psychic Horror',
			(
				C_Spell.GetSpellCooldown('Psychic Horror').startTime == 0
				and C_Spell.GetSpellCooldown('Silence').startTime ~= 0
				and C_Spell.GetSpellCooldown('Psychic Scream').startTime ~= 0
				and jungle.isCastingOneOfSpells(_target, 1, jungle.spellsCcInterrupt)
				and CheckInteractDistance(_target, 3)
			),
			1, 
			0 
		},
		[5]= {'Interrupt',
			'Silence',
			(
				C_Spell.GetSpellCooldown('Silence').startTime == 0
				and C_Spell.IsSpellInRange('Silence', _target)
				and jungle.isCastingOneOfSpells(_target, 1, jungle.spellsCcInterrupt)
			),
			1, 
			0 
		},
		--chain CCed healer [non diminishing chain]
		[6]= {'dps',
			'Silence',
			(
				C_Spell.GetSpellCooldown('Silence').startTime == 0
				and C_Spell.IsSpellInRange('Silence', _target)
				and not jungle.isHasOneOfBuffs(_target, jungle.ccImmunityBuffs)
				and not jungle.unitCacheBuff(_target, 'Grounding Totem Effect')
				and not jungle.unitCacheBuff(_target, 'Spell Reflection')
				and jungle.IsUnitHealer(_target)
				and jungle.getDR(_target, Silence_table)==0
				and jungle.getCasterUnitCCWindow(_target, {s_,d_,i_,si_}, 0.5)
			),
			1, 
			0 
		},
		[7]= {'dps',
			'Psychic Scream',
			(
				C_Spell.GetSpellCooldown('Psychic Scream').startTime == 0
				and not jungle.isHasOneOfBuffs(_target, jungle.ccImmunityBuffs)
				and not jungle.unitCacheBuff(_target, 'Grounding Totem Effect')
				and not jungle.unitCacheBuff(_target, 'Spell Reflection')
				and CheckInteractDistance(_target, 3)
				and jungle.IsUnitHealer(_target)
				and jungle.getDR(_target, Disorient_table)==0
				and jungle.getCasterUnitCCWindow(_target, {s_,d_,i_,si_}, 1)
			),
			1, 
			0 
		},
		[8]= {'dps',
			'Psychic Horror',
			(
				C_Spell.GetSpellCooldown('Psychic Horror').startTime == 0
				and not jungle.isHasOneOfBuffs(_target, jungle.ccImmunityBuffs)
				and not jungle.unitCacheBuff(_target, 'Grounding Totem Effect')
				and not jungle.unitCacheBuff(_target, 'Spell Reflection')
				and jungle.IsUnitHealer(_target)
				and jungle.getDR(_target, Controlled_Stun_table)==0
				and jungle.getCasterUnitCCWindow(_target, {s_,d_,i_,si_}, 0.8)
			),
			1, 
			0 
		},
		[9]= {'self Silence healer',
			'Silence',
			(
				-- C_Spell.GetSpellCooldown('Silence').startTime == 0
				-- and jungle.IsUnitHealer(_target)
				-- and not jungle.isHasOneOfBuffs(_target, jungle.ccImmunityBuffs)
				-- and not jungle.unitCacheBuff(_target, 'Grounding Totem Effect')
				-- and not jungle.unitCacheBuff(_target, 'Spell Reflection')
				-- and (jungle.isCasting(_target, 1) or UnitChannelInfo(_target))
				-- and jungle.getDR(_target, Silence_table)==0
				-- and jungle.getDR(_target, Controlled_Stun_table)==0
				false
			),
			1, 
			0 
		},
		-- purge important buffs
		[10]= {'dps',
			'Dispel Magic',
			(
				jungle.ReadyCastSpell('Dispel Magic', _target)
				and jungle.CheckIfSpellCastedRecently(5, 'Dispel Magic')
				and jungle.isHasOneOfBuffs(_target, jungle.purgeBuffs)
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
			),
			1, 
			0 
		},		
		[11]= {'dps',
			'Dispel Magic',
			(
				jungle.ReadyCastSpell('Dispel Magic', _target)
				and jungle.unitCacheBuff(_target, 'Nullifying Shroud')
				and jungle.IsUnitHealer(_target)
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
			),
			1, 
			0 
		},		
	}
	return set
end
jungle.shadowAutoEmenemy = shadowAutoEmenemy


local function shadowAutoDot(_target)
	local noStopChanneling,_,_,_,_,_,_,_ = UnitChannelInfo('player')
	local r_ = jungle.Controlled_Root_id
	local s_ = jungle.Controlled_Stun_id
	local d_ = jungle.Disorient_id
	local i_ = jungle.Incapacitate_id
	local si_ = jungle.Silence_id

    local set = {
		[1]= {'dps',
			'Stopcasting',
			(
				-- UnitCastingInfo('player')=='Vampiric Touch'
				-- and (jungle.Debuff('Vampiric Touch', _target, '|PLAYER'))
				false

			),
			1, 
			0 
		},	
		[2]= {'dot the dps',
			'Vampiric Touch',
			(
				jungle.ReadyCastSpell('Vampiric Touch', _target)
				and not UnitCastingInfo('player')
				and not jungle.CheckIfSpellCastedRecently(1, 'Vampiric Touch')
				and (GetUnitSpeed('player')==0 or jungle.Buff('Unfurling Darkness', 'player'))
				and (
					(not jungle.Debuff('Vampiric Touch', _target, '|PLAYER') or jungle.Debuff('Vampiric Touch', _target, '|PLAYER', 1.5) or jungle.Buff('Unfurling Darkness', 'player', 2))
					and
					UnitName(_target)~=jungle.shadowCrashTarget()
				)
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
				and not jungle.IsUnitHealer(_target)
				and not jungle.getCasterUnitCCWindow(_target, {d_,i_}, 8)
			),
			1, 
			0 
		},	
		[3]= {'dps',
			'Devouring Plague',
			(
				-- jungle.ReadyCastSpell('Devouring Plague', _target)
				-- and jungle.Debuff('Devouring Plague', 'target', '|PLAYER')
				-- and not jungle.Debuff('Devouring Plague', _target, '|PLAYER')
				-- and not jungle.IsUnitHealer(_target)
				false
			),
			1, 
			0 
		},	
		[4]= {'quick dot the dps',
			'Shadow Crash',
			(
				IsSpellKnown(457042)
				and jungle.ReadyCastSpell('Shadow Crash', _target)
				and not UnitIsUnit('target', _target)
				and jungle.Debuff('Vampiric Touch', 'target', '|PLAYER')
				and not jungle.Buff('Unfurling Darkness', 'player')
				and not jungle.IsUnitHealer(_target)
				and not jungle.Debuff('Vampiric Touch', _target, '|PLAYER')
				-- and GetUnitSpeed('player')~=0
			),
			1, 
			0 
		},	
		[5]= {'quick dot healer if all dotted and I have quick dot',
			'Vampiric Touch',
			(
				jungle.ReadyCastSpell('Vampiric Touch', _target)
				and not UnitCastingInfo('player')
				and not jungle.CheckIfSpellCastedRecently(1, 'Vampiric Touch')
				and jungle.Buff('Unfurling Darkness', 'player')
				and (
					(not jungle.Debuff('Vampiric Touch', _target, '|PLAYER') or jungle.Debuff('Vampiric Touch', _target, '|PLAYER', 1.5) or jungle.Buff('Unfurling Darkness', 'player', 2))
					and
					UnitName(_target)~=jungle.shadowCrashTarget()
				)
				and noStopChanneling ~= 'Void Torrent'
				and noStopChanneling ~= 'Mind Flay: Insanity'
				and jungle.IsUnitHealer(_target)
				and not jungle.getCasterUnitCCWindow(_target, {d_,i_}, 8)
			),
			1, 
			0 
		},	
		[6]= {'quick dot healer if all dotted and I have quick dot',
			'Shadow Crash',
			(
				IsSpellKnown(457042)
				and jungle.ReadyCastSpell('Shadow Crash', _target)
				and not UnitIsUnit('target', _target)
				and jungle.Debuff('Vampiric Touch', 'target', '|PLAYER')
				and not jungle.Buff('Unfurling Darkness', 'player')
				and jungle.IsUnitHealer(_target)
				and not jungle.Debuff('Vampiric Touch', _target, '|PLAYER')
				-- and GetUnitSpeed('player')~=0
			),
			1, 
			0 
		},	
	}
	return set
end
jungle.shadowAutoDot = shadowAutoDot


local function selfSpamCcOnHealer(_target)
	local noStopChanneling,_,_,_,_,_,_,_ = UnitChannelInfo('player')
	local s_ = jungle.Controlled_Stun_id
	local d_ = jungle.Disorient_id
	local i_ = jungle.Incapacitate_id
	local si_ = jungle.Silence_id
	
    local set = {
		[1]= {'self silence if cant cc',
			'Silence',
			(
				C_Spell.GetSpellCooldown('Silence').startTime == 0
				and not jungle.isHasOneOfBuffs(_target, jungle.ccImmunityBuffs)
				and not jungle.unitCacheBuff(_target, 'Grounding Totem Effect')
				and not jungle.unitCacheBuff(_target, 'Spell Reflection')
				and jungle.IsUnitHealer(_target)
				and jungle.getDR(_target, Silence_table)==0
				and not jungle.getCasterUnitCCWindow(_target, {s_,d_,i_,si_}, 8)
			),
			1, 
			0 
		},
		[2]= {'dps',
			'Psychic Scream',
			(
				C_Spell.GetSpellCooldown('Psychic Scream').startTime == 0
				and not jungle.isHasOneOfBuffs(_target, jungle.ccImmunityBuffs)
				and not jungle.unitCacheBuff(_target, 'Grounding Totem Effect')
				and not jungle.unitCacheBuff(_target, 'Spell Reflection')
				and CheckInteractDistance(_target, 3)
				and jungle.IsUnitHealer(_target)
				and jungle.getDR(_target, Disorient_table)==0
				and not jungle.getCasterUnitCCWindow(_target, {s_,d_,i_,si_}, 8)
			),
			1, 
			0 
		},
		[3]= {'dps',
			'Psychic Horror',
			(
				C_Spell.GetSpellCooldown('Psychic Horror').startTime == 0
				and not jungle.isHasOneOfBuffs(_target, jungle.ccImmunityBuffs)
				and not jungle.unitCacheBuff(_target, 'Grounding Totem Effect')
				and not jungle.unitCacheBuff(_target, 'Spell Reflection')
				and jungle.IsUnitHealer(_target)
				and jungle.getDR(_target, Controlled_Stun_table)==0
				and not jungle.getCasterUnitCCWindow(_target, {s_,d_,i_,si_}, 8)
			),
			1, 
			0 
		},
	}
	return set
end
jungle.selfSpamCcOnHealer = selfSpamCcOnHealer


