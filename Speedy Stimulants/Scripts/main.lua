-- Speedy Stimulants
-- Speeds stim/medpack throw + self-use presentations.

local Settings = require("MXM")

local DELAY_TIME = 0.01 -- latent Delay misbehaves at exactly 0
local PRESENTATION_MAX_MS = 6000

local TAG = "[SpeedyStimulants]"
local presentation_active = false
local presentation_generation = 0

-- Baseline projectile props so mid-game multiplier changes do not stack.
local projectile_baselines = {}

local function log(fmt, ...)
    print(string.format(TAG .. " " .. fmt .. "\n", ...))
end

local function get_anim_mult()
    return tonumber(Settings.Get("anim_speed_multiplier"))
end

local function get_thrown_item_mult()
    return tonumber(Settings.Get("thrown_item_speed_multiplier"))
end

local function full_name(obj)
    if not obj or not obj:IsValid() then
        return "<invalid>"
    end
    local ok, name = pcall(function()
        return obj:GetFullName()
    end)
    return (ok and name) or "<unknown>"
end

local function get_prop(obj, name)
    local ok, value = pcall(function()
        return obj[name]
    end)
    if ok then
        return value
    end
    return nil
end

local function set_prop(obj, name, value)
    return pcall(function()
        obj[name] = value
    end)
end

local function foreach_of(class_name, fn)
    local ok, objects = pcall(FindAllOf, class_name)
    if not ok or objects == nil then
        return
    end
    if type(objects) == "table" then
        for _, obj in pairs(objects) do
            if obj and obj:IsValid() then
                fn(obj)
            end
        end
    elseif objects:IsValid() then
        fn(objects)
    end
end

local function unwrap(param)
    if type(param) == "userdata" then
        local ok, value = pcall(function()
            return param:get()
        end)
        if ok then
            return value
        end
    end
    return param
end

local function set_param(param, value)
    if type(param) ~= "userdata" then
        return false
    end
    return pcall(function()
        param:set(value)
    end)
end

local function is_default(obj)
    return full_name(obj):find("Default__", 1, true) ~= nil
end

local function is_stim_anim(name)
    return name:find("_Stim", 1, true) ~= nil
end

local function is_throw_stance(name)
    return name:find("1HThrowR_Crouch", 1, true) ~= nil
        or name:find("1HThrowR_Rex_Crouch", 1, true) ~= nil
end

local function is_general_stance(name)
    return name:find("Confirm_Stand", 1, true) ~= nil
        or name:find("Confirm_Standing", 1, true) ~= nil
        or name:find("Crouch_Aim_Exit", 1, true) ~= nil
        or name:find("Crouch_Exit", 1, true) ~= nil
        or name:find("Aim_Crouch_Exit", 1, true) ~= nil
        or name:find("Crouch_Aim_Enter", 1, true) ~= nil
        or name:find("Aim_Crouch_Enter", 1, true) ~= nil
        or name:find("Flinch_Crouch_Exit", 1, true) ~= nil
        or name:find("Flinch_Crouch_Enter", 1, true) ~= nil
end

local function is_throw_delay_duration(duration)
    return type(duration) == "number"
        and (math.abs(duration - 0.75) < 0.02 or math.abs(duration - 1.25) < 0.02)
end

--------------------------------------------------------------------------
-- Presentation window (gates Kismet Delay + shared stance Montage_Play)
--------------------------------------------------------------------------
local function begin_presentation()
    presentation_active = true
    presentation_generation = presentation_generation + 1
    local gen = presentation_generation
    local anim_mult = get_anim_mult()
    local thrown_mult = get_thrown_item_mult()
    log(
        "Speeding stimulant presentation (anim=%sx thrown=%sx window=%sms)",
        tostring(anim_mult),
        tostring(thrown_mult),
        tostring(PRESENTATION_MAX_MS)
    )
    ExecuteWithDelay(PRESENTATION_MAX_MS, function()
        if gen == presentation_generation then
            presentation_active = false
        end
    end)
end

NotifyOnNewObject(
    "/Game/Game/Abilities/Common/UtilityThrow/SM_UtilityThrow.SM_UtilityThrow_C",
    function(obj)
        if obj and obj:IsValid() and not is_default(obj) then
            begin_presentation()
        end
    end
)
NotifyOnNewObject(
    "/Game/Game/Abilities/Common/UtilitySelf/SM_UtilitySelf.SM_UtilitySelf_C",
    function(obj)
        if obj and obj:IsValid() and not is_default(obj) then
            begin_presentation()
        end
    end
)

--------------------------------------------------------------------------
-- Shorten UtilityThrow SimpleDelays (0.75s / 1.25s)
--------------------------------------------------------------------------
do
    local ok, err = pcall(function()
        RegisterHook("/Script/Engine.KismetSystemLibrary:Delay", function(_, _, Duration)
            if not presentation_active then
                return
            end
            local dur = unwrap(Duration)
            if is_throw_delay_duration(dur) then
                set_param(Duration, DELAY_TIME)
            end
        end)
    end)
    if not ok then
        log("ERROR: Kismet Delay hook failed: %s", tostring(err))
    end
end

--------------------------------------------------------------------------
-- Character anim RateScale (_Stim + throw-specific crouch)
--------------------------------------------------------------------------
local function patch_anim_rate(obj)
    if not obj or not obj:IsValid() then
        return
    end
    local name = full_name(obj)
    if not (is_stim_anim(name) or is_throw_stance(name)) then
        return
    end
    local anim_mult = get_anim_mult()
    local old = get_prop(obj, "RateScale")
    if old == anim_mult then
        return
    end
    set_prop(obj, "RateScale", anim_mult)
end

NotifyOnNewObject("/Script/Engine.AnimSequence", patch_anim_rate)
NotifyOnNewObject("/Script/Engine.AnimMontage", patch_anim_rate)

--------------------------------------------------------------------------
-- Projectile flight
--------------------------------------------------------------------------
local function patch_projectile(obj)
    if not obj or not obj:IsValid() or is_default(obj) then
        return
    end

    local name = full_name(obj)
    local baseline = projectile_baselines[name]
    if not baseline then
        baseline = {
            flight = get_prop(obj, "FlightSpeedModifier") or 1.0,
            fx = get_prop(obj, "FX_TimeToTargetEvent_Time"),
        }
        projectile_baselines[name] = baseline
    end

    local mult = get_thrown_item_mult()
    local desired_flight = baseline.flight * mult
    local current_flight = get_prop(obj, "FlightSpeedModifier") or 1.0
    if current_flight ~= desired_flight then
        set_prop(obj, "FlightSpeedModifier", desired_flight)
    end

    if baseline.fx and baseline.fx > 0 then
        local desired_fx = baseline.fx / mult
        local current_fx = get_prop(obj, "FX_TimeToTargetEvent_Time")
        if current_fx ~= desired_fx then
            set_prop(obj, "FX_TimeToTargetEvent_Time", desired_fx)
        end
    end
end

local PROJECTILE_CLASSES = {
    "/Game/Game/GameData/WeaponInfo/Projectiles/BP_Projectile_CombatStim.BP_Projectile_CombatStim_C",
    "/Game/Game/GameData/WeaponInfo/Projectiles/BP_Projectile_MedKit.BP_Projectile_MedKit_C",
    "/Game/Game/GameData/WeaponInfo/Projectiles/BP_Projectile_MedKit_SurgeonTool.BP_Projectile_MedKit_SurgeonTool_C",
}

for _, class_path in ipairs(PROJECTILE_CLASSES) do
    NotifyOnNewObject(class_path, patch_projectile)
end

--------------------------------------------------------------------------
-- Montage play-rate (stance wait + stim/throw montages)
--------------------------------------------------------------------------
do
    local ok, err = pcall(function()
        RegisterHook("/Script/Engine.AnimInstance:Montage_Play", function(Context, Montage, InPlayRate)
            local montage = unwrap(Montage)
            if not montage then
                return
            end
            local name = full_name(montage)
            local speed = is_stim_anim(name) or is_throw_stance(name)
                or (presentation_active and is_general_stance(name))
            if not speed then
                return
            end

            local anim_mult = get_anim_mult()
            set_param(InPlayRate, anim_mult)
            local anim = unwrap(Context)
            ExecuteWithDelay(0, function()
                if not anim or not montage then
                    return
                end
                pcall(function()
                    if anim.Montage_SetPlayRate then
                        anim:Montage_SetPlayRate(montage, anim_mult)
                    end
                end)
            end)
        end)
    end)
    if not ok then
        log("ERROR: Montage_Play hook failed: %s", tostring(err))
    end
end

--------------------------------------------------------------------------
-- Live re-apply when MXM settings change
--------------------------------------------------------------------------
local function reapply_settings(reason)
    local anim_mult = get_anim_mult()
    local thrown_mult = get_thrown_item_mult()
    log(
        "Re-applying settings (%s): anim=%sx thrown=%sx window=%sms",
        tostring(reason),
        tostring(anim_mult),
        tostring(thrown_mult),
        tostring(PRESENTATION_MAX_MS)
    )

    local anim_count = 0
    foreach_of("AnimSequence", function(obj)
        local name = full_name(obj)
        if is_stim_anim(name) or is_throw_stance(name) then
            patch_anim_rate(obj)
            anim_count = anim_count + 1
        end
    end)
    foreach_of("AnimMontage", function(obj)
        local name = full_name(obj)
        if is_stim_anim(name) or is_throw_stance(name) then
            patch_anim_rate(obj)
            anim_count = anim_count + 1
        end
    end)

    local proj_count = 0
    for _, class_path in ipairs(PROJECTILE_CLASSES) do
        local short = class_path:match("([^%.]+)$") or class_path
        foreach_of(short, function(obj)
            patch_projectile(obj)
            proj_count = proj_count + 1
        end)
    end

    log("Re-apply done: patched %d anim asset(s), %d projectile(s)", anim_count, proj_count)
end

Settings.OnChange(function(values, changed)
    log(
        "settings changed: %s (anim=%s thrown=%s)",
        table.concat(changed, ", "),
        tostring(values.anim_speed_multiplier),
        tostring(values.thrown_item_speed_multiplier)
    )
    reapply_settings("OnChange")
end)

--------------------------------------------------------------------------
-- Startup (patch assets already loaded)
--------------------------------------------------------------------------
foreach_of("AnimSequence", patch_anim_rate)
foreach_of("AnimMontage", patch_anim_rate)

log(
    "Mod Loaded. MXM available=%s ANIM=%sx THROWN=%sx WINDOW=%sms DELAY_TIME=%s",
    tostring(Settings.IsAvailable()),
    tostring(get_anim_mult()),
    tostring(get_thrown_item_mult()),
    tostring(PRESENTATION_MAX_MS),
    tostring(DELAY_TIME)
)
