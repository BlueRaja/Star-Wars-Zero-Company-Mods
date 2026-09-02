local CAPACITOR_MULTIPLIER = 2

local function is_capacitor_reward(obj)
    if not obj or not obj:IsValid() then
        return false
    end

    local item = obj.InventoryItem
    if not item or not item:IsValid() then
        return false
    end

    return item:GetFullName():find("Resource_UpgradeFacilityResource") ~= nil
end

local function increase_amount(obj)
    if not is_capacitor_reward(obj) then
        return
    end

    local old_amount = obj.Amount
    if old_amount == nil then
        old_amount = 1 --default when the property is missing
    end

    local new_amount = old_amount * CAPACITOR_MULTIPLIER
    obj.Amount = new_amount

    print(string.format(
        "[MoreCapacitors]  Increased Capacitor reward for '%s' from %s to %s\n",
        obj:GetFullName(),
        tostring(old_amount),
        tostring(new_amount)
    ))
end

NotifyOnNewObject(
    "/Game/Game/GameData/Rewards/CustomRewards/CustomReward_InventoryItem.CustomReward_InventoryItem_C",
    increase_amount
)

print("[MoreCapacitors] Mod Loaded.\n")