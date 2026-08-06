local Jungle, jungle = ...
local unitCache = jungle.unitCache

local FISHING_DELETE_ITEM_IDS = {
    [27422] = true, -- Barbed Gill Trout
    [27425] = true, -- Spotted Feltail
}

local DELETE_INTERVAL_MIN = 10
local DELETE_INTERVAL_MAX = 60
local nextDeleteAttempt = 0
local OPEN_INTERVAL_MIN = 10
local OPEN_INTERVAL_MAX = 60
local nextOpenAttempt = 0

local function FindFishingItemToDelete()
    local maxBag = NUM_BAG_SLOTS or 4
    for bag = 0, maxBag do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and FISHING_DELETE_ITEM_IDS[info.itemID] and not info.isLocked then
                return bag, slot
            end
        end
    end
end

local function FindLootContainerToOpen()
    local maxBag = NUM_BAG_SLOTS or 4
    for bag = 0, maxBag do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hasLoot and not info.isLocked then
                return bag, slot
            end
        end
    end
end

-- DeleteCursorItem is restricted and fails when called directly by OnUpdate.
-- This function is invoked by the existing Fishing secure macro hotkey, so
-- no mouse hover is needed and the call occurs during the hotkey input event.
function _G.OliaFishingBagMaintenance()
    local now = GetTime()
    if CursorHasItem() or InCombatLockdown() then return end

    if now >= nextDeleteAttempt then
        local bag, slot = FindFishingItemToDelete()
        if bag then
            nextDeleteAttempt = now + math.random(DELETE_INTERVAL_MIN, DELETE_INTERVAL_MAX)

            C_Container.PickupContainerItem(bag, slot)
            if CursorHasItem() then
                DeleteCursorItem()

                -- If Blizzard rejects the deletion, put the item back instead
                -- of leaving it attached to the software cursor.
                if CursorHasItem() then
                    ClearCursor()
                end
            end
            return -- Perform at most one bag operation per Fishing press.
        end
    end

    if now >= nextOpenAttempt then
        local bag, slot = FindLootContainerToOpen()
        if bag then
            nextOpenAttempt = now + math.random(OPEN_INTERVAL_MIN, OPEN_INTERVAL_MAX)
            C_Container.UseContainerItem(bag, slot)
        end
    end
end

-- Backward-compatible manual command for anyone already using it.
function _G.OliaDeleteFishingItem()
    OliaFishingBagMaintenance()
end

local function Fishing()
    -- Prevent actions if currently casting (e.g. Lure)
    local castingName = UnitCastingInfo("player")
    if castingName then
        jungle.lastLureTime = GetTime()
        jungle.lastLureAttemptTime = GetTime() -- Reset attempt time to match actual casting state
        return {}
    end

    local hasMainHandEnchant, mainHandExpiration, mainHandEnchantID, hasOffHandEnchant, offHandExpiration, offHandEnchantID = GetWeaponEnchantInfo()

    -- Prevent double casting Lure due to server-client synchronization delay
    local isLureActive = hasMainHandEnchant
    if jungle.lastLureTime and (GetTime() - jungle.lastLureTime < 15) then
        isLureActive = true
    end

    -- Attempt to lure not often than once every 10 seconds if it fails to start casting
    if jungle.lastLureAttemptTime then
        local timeSinceAttempt = GetTime() - jungle.lastLureAttemptTime
        -- Give the bot a 3-second window to register the pixel and start casting.
        -- If no cast starts within 3 seconds, block Lure attempts until 10 seconds have passed.
        if timeSinceAttempt >= 3 and timeSinceAttempt < 10 then
            isLureActive = true
        end
    end

    -- If we are currently channeling (usually Fishing), we cannot cast Lure
    local channelName = UnitChannelInfo("player")
    if channelName then
        isLureActive = true
    end

    -- Record the lure attempt timestamp if we are choosing to Lure (only if outside current window)
    if not isLureActive then
        if not jungle.lastLureAttemptTime or (GetTime() - jungle.lastLureAttemptTime >= 10) then
            jungle.lastLureAttemptTime = GetTime()
        end
    end

    local set = {
		[1]= {'',
			'Lure',
			(
				not isLureActive
			),
			1, 
			0 
		},			
		[2]= {'',
			'Fishing',
			(
				not jungle.IsFishing()
			),
			1, 
			0 
		},			
	}
	return set
end
jungle.Fishing = Fishing
