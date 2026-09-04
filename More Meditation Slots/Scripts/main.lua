local UTILITY_TAG = "BitReactor.ItemType.Utility"
local SYNC_DELAY_MS = 500

local function log(fmt, ...)
    print(string.format("[MoreMeditationSlots] " .. fmt .. "\n", ...))
end

local function safe_full_name(obj)
    if not obj or not obj:IsValid() then
        return "<invalid>"
    end
    local ok, name = pcall(function()
        return obj:GetFullName()
    end)
    if ok and name then
        return name
    end
    return "<unknown>"
end

local function is_live_instance(obj)
    local name = safe_full_name(obj)
    return name:find("Default__", 1, true) == nil
        and name:find("Cinematics", 1, true) == nil
        and name:find("MovieScene", 1, true) == nil
end

local function make_tag(tag_name)
    return { TagName = FName(tag_name) }
end

local function foreach_of(class_name, fn)
    local ok, objects = pcall(function()
        return FindAllOf(class_name)
    end)
    if not ok or objects == nil then
        return 0
    end
    if type(objects) == "table" then
        for _, obj in pairs(objects) do
            if obj and obj:IsValid() then
                fn(obj)
            end
        end
    elseif objects.IsValid and objects:IsValid() then
        fn(objects)
    end
end

local function find_hq_inventory()
    local found = nil
    foreach_of("BP_BrunoHQInventory_C", function(obj)
        local name = safe_full_name(obj)
        if is_live_instance(obj) and name:find("PersistentLevel", 1, true) then
            found = obj
        end
    end)
    return found
end

local function sync_tel_utility_slots(tel)
    if not tel or not tel:IsValid() then
        log("Skipping sync due to invalid tel '%s'", safe_full_name(tel))
        return false
    end

    local inv = find_hq_inventory()
    if not inv then
        log("Skipping sync due to no inventory")
        return false
    end

    -- We need to call RefreshEquipmentSlots for Tel Rea in case the game is loaded from
    -- a save game created before the mod was installed
    -- Without this, the extra slots are not shown until you unequip and reequip a meditation
    inv:RefreshEquipmentSlots(tel, make_tag(UTILITY_TAG))
    return true
end

NotifyOnNewObject("/Script/Bruno.BrunoCharacter", function(obj)
    local name = safe_full_name(obj)
    if name:find("TelRea", 1, true) == nil then
        return
    end

    -- Not sure why this delay is necessary, but without it the call to RefreshEquipmentSlots doesn't work
    ExecuteWithDelay(SYNC_DELAY_MS, function()
        if not is_live_instance(obj) then
            log("Skippping sync due to not-live object '%s'", name)
            return
        end
        if sync_tel_utility_slots(obj) then
            log("Successfully synced '%s'", name)
        end
    end)
end)

log("Mod Loaded.")
