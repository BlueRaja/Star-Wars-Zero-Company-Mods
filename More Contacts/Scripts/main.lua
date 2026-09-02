local CONTACTS_MULTIPLIER = 2

local function is_contact_reward(obj)
    if not obj or not obj:IsValid() then
        return false
    end

    -- Check that the InventoryItem points to Resource_Contacts
    local item = obj.InventoryItem
    if not item or not item:IsValid() then
        return false
    end

    local item_name = item:GetFullName()
    return item_name:find("Resource_Contacts") ~= nil
end

local function increase_amount(obj)
    if not is_contact_reward(obj) then
        return
    end

    local old_amount = obj.Amount
    if old_amount == nil then
        old_amount = 1 --default when the property is missing
    end

    local new_amount = old_amount * CONTACTS_MULTIPLIER
    obj.Amount = new_amount

    print(string.format(
        "[MoreContacts] Increased Contact reward for '%s' from %s to %s\n",
        obj:GetFullName(),
        tostring(old_amount),
        tostring(new_amount)
    ))
end

NotifyOnNewObject(
    "/Game/Game/GameData/Rewards/CustomRewards/CustomReward_InventoryItem.CustomReward_InventoryItem_C",
    increase_amount
)

print("[MoreContacts] Mod Loaded.\n")