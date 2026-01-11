local Jungle, jungle = ...

-- Determine player class to assign the correct GCD spell
local _, playerClass = UnitClass("player")
local gcdSpellID = 61304 -- Default fallback (Global Cooldown dummy) returns nill always4

if playerClass == "DRUID" then
    gcdSpellID = 1126 -- Mark of the Wild (Rank 1)
elseif playerClass == "WARRIOR" then
    gcdSpellID = 6673 -- Battle Shout (Rank 1)
elseif playerClass == "PALADIN" then
    gcdSpellID = 21084 -- Seal of Righteousness (Rank 1)
elseif playerClass == "HUNTER" then
    gcdSpellID = 1130 -- Hunter's Mark (Rank 1)
elseif playerClass == "ROGUE" then
    gcdSpellID = 1752 -- Sinister Strike (Rank 1)
elseif playerClass == "PRIEST" then
    gcdSpellID = 1243 -- Power Word: Fortitude (Rank 1)
elseif playerClass == "SHAMAN" then
    gcdSpellID = 8017 -- Rockbiter Weapon (Rank 1)
elseif playerClass == "MAGE" then
    gcdSpellID = 1459 -- Arcane Intellect (Rank 1)
elseif playerClass == "WARLOCK" then
    gcdSpellID = 687 -- Demon Skin (Rank 1)
end

offsets = {
    GCD_SPELL_ID = gcdSpellID, -- Corrected name from GCD_SELL_ID
    AUTOATTACK_SPELL_ID = 6603, -- Attack
}

jungle.offsets = offsets