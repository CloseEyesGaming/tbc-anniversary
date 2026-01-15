local Jungle, jungle = ...
local unitCache = jungle.unitCache


local function retroPvpSingle(_target)
    local set = {
		[1]= {'',
			'Judgment',
			(
				jungle.ReadyCastSpell('Judgment', _target)
				and UnitPower('player', 9) <= 3
			),
			1, 
			0 
		},		
		[2]= {'Wake of Ashes proc',
			'Wake_of_Ashes',
			(
				C_Spell.GetSpellInfo('Wake of Ashes').iconID == 5342121
				and UnitPower('player', 9) == 5
				and C_Spell.IsSpellInRange('Hammer of Justice', _target)
			),
			1, 
			0 
		},
		[3]= {'Templar\'s Verdict with 5 Holy Power.',
			'Final Verdict',
			(
				jungle.ReadyCastSpell('Final Verdict', _target)
				-- and UnitPower('player', 9) >= 3
				and C_Spell.GetSpellInfo('Wake of Ashes').iconID == 1112939
			),
			1, 
			0 
		},
		[4]= {'Templar Slash to detect second combo',
			'Templar Strike',
			(
				C_Spell.GetSpellInfo('Templar Strike').iconID == 1112940
				and C_Spell.IsSpellInRange('Templar Strike', _target)
				and UnitPower('player', 9) <= 4
				-- false
			),
			1, 
			0 
		},
		[5]= {'',
			'Wake_of_Ashes',
			(
				jungle.ReadyCastSpell('Wake of Ashes')
				and C_Spell.IsSpellInRange('Hammer of Justice', _target)
				and UnitPower('player', 9) == 2
			),
			1, 
			0 
		},
		[6]= {'',
			'Hammer of Wrath',
			(
				jungle.ReadyCastSpell('Hammer of Wrath', _target)
				and UnitPower('player', 9) <= 4
			),
			1, 
			0 
		},
		[7]= {'',
			'Templar Strike',
			(
				jungle.ReadyCastSpell('Templar Strike', _target)
				and C_Spell.GetSpellCharges('Templar Strike').currentCharges == 1
				and UnitPower('player', 9) <= 4
				-- false
			),
			1, 
			0 
		},
		[8]= {'',
			'Blade of Justice',
			(
				jungle.ReadyCastSpell('Blade of Justice', _target)
				and UnitPower('player', 9) <= 4
			),
			1, 
			0 
		},
		[9]= {'dps',
			'Auto Attack',
			(
				UnitExists('target') and
				UnitCanAttack('player', 'target') and
				not C_Spell.IsCurrentSpell(jungle.offsets.AUTOATTACK_SPELL_ID) and
				not IsMounted()
			),
			1, 
			0 
		},
	}
	return set
end
jungle.retroPvpSingle = retroPvpSingle


local function retroPvpAoe(_target)
    local set = {
		[1]= {'',
			'Judgment',
			(
				jungle.ReadyCastSpell('Judgment', _target)
				and UnitPower('player', 9) <= 3
			),
			1, 
			0 
		},		
		[2]= {'',
			'Final Reckoning',
			(
				jungle.ReadyCastSpell('Final Reckoning')
				and C_Spell.IsSpellInRange('Templar Strike', _target)
			),
			1, 
			0 
		},
		[3]= {'',
			'Divine Storm',
			(
				jungle.ReadyCastSpell('Divine Storm')
				and C_Spell.IsSpellInRange('Templar Strike', _target)
			),
			1, 
			0 
		},
		[4]= {'',
			'Wake_of_Ashes',
			(
				jungle.ReadyCastSpell('Wake of Ashes')
				and C_Spell.IsSpellInRange('Hammer of Justice', _target)
				and UnitPower('player', 9) <= 2
			),
			1, 
			0 
		},		
		[5]= {'',
			'Divine Toll',
			(
				jungle.ReadyCastSpell('Divine Toll', _target)
				and (
					
					(
						jungle.enemiesInRange('Divine Toll')==1
						and UnitPower('player', 9)<=4 
					) or					(
						jungle.enemiesInRange('Divine Toll')==2
						and UnitPower('player', 9)<=3 
					) or					(
						jungle.enemiesInRange('Divine Toll')==3
						and UnitPower('player', 9)<=2 
					) or					(
						jungle.enemiesInRange('Divine Toll')>4
						and UnitPower('player', 9)<=1
					)
				)
			),
			1, 
			0 
		},		
		[6]= {'Templar Slash to detect second combo',
			'Templar Strike',
			(
				C_Spell.GetSpellInfo('Templar Strike').iconID == 1112940
				and C_Spell.IsSpellInRange('Templar Strike', _target)
				and UnitPower('player', 9) <= 4
			),
			1, 
			0 
		},
		[7]= {'',
			'Hammer of Wrath',
			(
				jungle.ReadyCastSpell('Hammer of Wrath', _target)
				and UnitPower('player', 9) <= 4
			),
			1, 
			0 
		},
		[8]= {'',
			'Templar Strike',
			(
				jungle.ReadyCastSpell('Templar Strike', _target)
				and C_Spell.GetSpellCharges('Templar Strike').currentCharges == 1
				and UnitPower('player', 9) <= 4
			),
			1, 
			0 
		},
		[9]= {'',
			'Blade of Justice',
			(
				jungle.ReadyCastSpell('Blade of Justice', _target)
				and UnitPower('player', 9) <= 4
			),
			1, 
			0 
		},
		[10]= {'dps',
			'Auto Attack',
			(
				UnitExists('target') and
				UnitCanAttack('player', 'target') and
				not C_Spell.IsCurrentSpell(jungle.offsets.AUTOATTACK_SPELL_ID) and
				not IsMounted()
			),
			1, 
			0 
		},

	}
	return set
end
jungle.retroPvpAoe = retroPvpAoe


local function retroPvpBurst(_target)
    local set = {
		[1]= {'',
			'Final Reckoning',
			(
				jungle.ReadyCastSpell('Final Reckoning')
				and C_Spell.IsSpellInRange('Templar Strike', _target)
			),
			1, 
			0 
		},		
		[2]= {'',
			'Divine Toll',
			(
				jungle.ReadyCastSpell('Divine Toll', _target)
				and (
					
					(
						jungle.enemiesInRange('Divine Toll')==1
						and UnitPower('player', 9)<=4 
					) or					(
						jungle.enemiesInRange('Divine Toll')==2
						and UnitPower('player', 9)<=3 
					) or					(
						jungle.enemiesInRange('Divine Toll')==3
						and UnitPower('player', 9)<=2 
					) or					(
						jungle.enemiesInRange('Divine Toll')>4
						and UnitPower('player', 9)<3
					)
				)
			),
			1, 
			0 
		},		
	}
	return set
end
jungle.retroPvpBurst = retroPvpBurst


local function retroPvpSelfAssist(_friend)
local friendStatus = jungle.unitCache[_friend]
    local set = {
		[1]= {'',
			'Word of Glory',
			(
				jungle.ReadyCastSpell('Word of Glory', _friend)
				and friendStatus.isMe
				and jungle.LifePercent(_friend)<=0.5
			),
			1, 
			0 
		},	
		[2]= {'',
			'Flash of Light',
			(
				jungle.ReadyCastSpell('Flash of Light', _friend)
				and friendStatus.isMe
				and jungle.LifePercent(_friend)<=0.8
			),
			1, 
			0 
		},	
		[3]= {'',
			'Shield of Vengeance',
			(
				jungle.ReadyCastSpell('Shield of Vengeance')
				and UnitAffectingCombat('player')
				and friendStatus.isMe
				and not jungle.ReadyCastSpell('Word of Glory', _friend)
				and jungle.LifePercent(_friend)<=0.5
			),
			1, 
			0 
		},	
	}
	return set
end
jungle.retroPvpSelfAssist = retroPvpSelfAssist


local function retroPvpEnemyAssist(_target)
    local set = {
		[1]= {'pvp',
			'Rebuke',
			(
				instanceType ~= 'arena'
				and jungle.isCasting(_target, 0.3)
				and UnitExists('target') 
				and UnitCanAttack('player', 'target')
				and jungle.ReadyCastSpell('Rebuke', 'target') 
			),
			1, 
			0 
		},
	}
	return set
end
jungle.retroPvpEnemyAssist = retroPvpEnemyAssist


local function retroPvpHeal(_friend)
local friendStatus = jungle.unitCache[_friend]
    local set = {
		[1]= {'',
			'Word of Glory',
			(
				jungle.ReadyCastSpell('Word of Glory', _friend)
				and jungle.LifePercent(_friend)<=0.75
			),
			1, 
			0 
		},	
		[2]= {'',
			'Flash of Light',
			(
				jungle.ReadyCastSpell('Flash of Light', _friend)
				and jungle.LifePercent(_friend)<=0.85
			),
			1, 
			0 
		},	
	}
	return set
end
jungle.retroPvpHeal = retroPvpHeal


local function shuffleAssist(_friend)

	local r_ = jungle.Controlled_Root_id
	local s_ = jungle.Controlled_Stun_id
	local d_ = jungle.Disorient_id
	local i_ = jungle.Incapacitate_id
	local si_ = jungle.Silence_id
	local _,engClass,_ = UnitClass(_friend)

    local set = {
		[1]= {'LoH',
			'Lay_on_Hands',
			(
				IsSpellKnown(633)
				and jungle.ReadyCastSpell('Lay on Hands', _friend)
				and not engClass=='PALADIN'
				and jungle.LifePercent(_friend)<=0.2
				and not jungle.Debuff('Forbearance', _friend)
				and UnitAffectingCombat(_friend)
			),
			1, 
			0 
		},
		[2]= {'LoH',
			'Lay_on_Hands',
			(
				IsSpellKnown(633)
				and jungle.ReadyCastSpell('Lay on Hands', _friend)
				and UnitIsUnit('player', _friend)
				and jungle.SpellOnCD('Divine Shield')
				and jungle.LifePercent('player')<=0.35
				and not jungle.Debuff('Forbearance', 'player')
				and UnitAffectingCombat('player')
			),
			1, 
			0 
		},
		[4]= {'dps',
			'Blessing of Sanctuary',
			(
				IsSpellKnown(210256)
				and jungle.ReadyCastSpell('Blessing of Sanctuary', _friend)
				and jungle.IsUnitHealer(_friend)
				and ( 
					jungle.isHasOneOfDebuffs(_friend, jungle.Controlled_Stun_id)
					or 
					jungle.isHasOneOfDebuffs(_friend, jungle.Silence_id)
					or
					jungle.isHasOneOfDebuffs(_friend, jungle.Disorient_id)					
				)
			),
			1, 
			0 
		},
		[6]= {'remove stun on heal',
			'Blessing_of_Protection',
			(
				IsSpellKnown(1022)
				and jungle.ReadyCastSpell('Blessing of Protection', _friend)
				and not engClass=='PALADIN'
				and jungle.SpellOnCD('Blessing of Sanctuary')
				and jungle.isHasOneOfDebuffs(_friend, jungle.Controlled_Stun_id)
				and jungle.IsUnitHealer(_friend)
				and not jungle.Debuff('Forbearance', _friend)
			),
			1, 
			0 
		},
		[7]= {'BoP from melee',
			'Blessing_of_Protection',
			(
				jungle.ReadyCastSpell('Blessing of Protection', _friend)
				and not engClass=='PALADIN'
				and jungle.LifePercent(_friend)<=0.4
				and UnitAffectingCombat(_friend)
				and not jungle.Debuff('Forbearance', _friend)
			),
			1, 
			0 
		},
		[8]= {'BoP on me',
			'Blessing_of_Protection',
			(
				jungle.ReadyCastSpell('Blessing of Protection', _friend)
				and UnitIsUnit('player', _friend)
				and jungle.SpellOnCD('Divine Shield')
				and jungle.SpellOnCD('Lay on Hands')
				and jungle.LifePercent('player')<=0.35
				and not jungle.Debuff('Forbearance', 'player')
				and UnitAffectingCombat('player')
			),
			1, 
			0 
		},
		[9]= {'dps',
			'Blessing of Freedom',
			(
				jungle.ReadyCastSpell('Blessing of Freedom', 'player')
				and ( 
					jungle.isHasOneOfDebuffs('player', jungle.rootDebuffs)
					or 
					jungle.isHasOneOfDebuffs('player', jungle.slowDebuffs)
				)
				and UnitAffectingCombat(_friend)
			),
			1, 
			0 
		},
		[10]= {'dps',
			'Blessing of Freedom',
			(
				jungle.ReadyCastSpell('Blessing of Freedom', _friend)
				and ( 
					jungle.isHasOneOfDebuffs(_friend, jungle.rootDebuffs)
					or 
					jungle.isHasOneOfDebuffs(_friend, jungle.slowDebuffs)
				)
				and UnitAffectingCombat(_friend)
			),
			1, 
			0 
		},
		[11]= {'Sacra',
			'Blessing of Sacrifice',
			(
				jungle.ReadyCastSpell('Blessing of Sacrifice', _friend)
				and jungle.LifePercent(_friend)<=0.5
				and not UnitIsUnit('player', _friend)
				and UnitAffectingCombat(_friend)
			),
			1, 
			0 
		},
		[12]= {'dps',
			'Word of Glory',
			(
				jungle.ReadyCastSpell('Word of Glory', _friend)
				and (
					(UnitIsUnit('player', _friend) and jungle.LifePercent(_friend)<0.5)
					or 
					(not UnitIsUnit('player', _friend) and jungle.LifePercent(_friend)<0.3)
				)

			),
			1, 
			0 
		},
		[13]= {'dps',
			'Flash of Light',
			(
				jungle.ReadyCastSpell('Flash of Light', _friend)
				and (
					(UnitIsUnit('player', _friend) and jungle.LifePercent(_friend)<0.7)
					or 
					(not UnitIsUnit('player', _friend) and jungle.LifePercent(_friend)<0.4)
				)
			),
			1, 
			0 
		},
		[14]= {'dps',
			'Gift of the Naaru',
			(
				not jungle.SpellOnCD('Gift of the Naaru')
				and IsSpellInRange('Gift of the Naaru', _friend)
				and (
						jungle.SpellOnCD('Flash of Light')
						and
						(jungle.SpellOnCD('Blessing of Sacrifice') and not UnitIsUnit('player', _friend))
						and
						(jungle.SpellOnCD('Blessing of Protection') or jungle.Debuff('Forbearance', _friend))
						and
						(jungle.SpellOnCD('Lay on Hands') or jungle.Debuff('Forbearance', _friend)) 
				)
				and jungle.LifePercent(_friend)<0.5
				
			),
			1, 
			0 
		},
	}
	return set
end
jungle.shuffleAssist = shuffleAssist
