local Core = require("pyre.core")

Core.Log("skills.lua loaded", Core.LogLevel.DEBUG)

Skills = {}
ClanSkills = {}

local adjustingAlignment = false

ClanSkills[1] = { -- APATHY

    Name = "Apathy",

    Setting = tonumber(GetVariable("Skill_Apathy")) or 1,

    Queued = true,

    DidWarn = 0,

    LastAttempt = nil,

    CanCast = function(skill)

        return (skill.Queued == true and skill.Setting > 0 and Core.Status.State == 3 and (skill.LastAttempt == nil or os.difftime(os.time(), skill.LastAttempt) > 4))

    end,

    Cast = function(skill)

        if not (Core.AlignmentToCategory(Core.Status.RawAlignment, adjustingAlignment) == skill.Setting) then

            if adjustingAlignment == false then

                Core.CleanLog("APATHY SKIPPED! Alignment: " .. string.upper(skill.DisplayValue(Core.AlignmentToCategory(Core.Status.RawAlignment))) .. " should be " .. string.upper(skill.DisplayValue(skill.Setting)))

                adjustingAlignment = true

            end

            return false

        end

        SendNoEcho(skill.Name)

        skill.LastAttempt = os.time()

    end,

    OnSuccess = function(skill)

        skill.Queued = false

        skill.LastAttempt = nil

        skill.DidWarn = 0

        adjustingAlignment = false

        -- get the duration of apathy

        CheckSkillDuration(skill)

    end,

    OnFailure = function(skill)

        skill.Queued = true

        skill.LastAttempt = nil

    end,

    Expiration = nil,

    Success = {

        "Sorrow infuses your soul with apathy.",

        "You have already succumbed to Sorrow."

    },

    Failures = {

        "Sorrow relinquishes your soul.",

        "Sorrow takes your measure and finds you lacking."

    },

    DisplayValue = function(val) return Core.AlignmentCategoryToString(val) end,

    ParseSetting = function(wildcard)

        setting = 0

        if (wildcard == nil) then return setting end

        Core.Switch(string.lower(wildcard)){

            ["good"] = function() setting = 1 end,

            ["1"] = function() setting = 1 end,

            ["neutral"] = function() setting = 2 end,

            ["2"] = function() setting = 2 end,

            ["evil"] = function() setting = 3 end,

            ["3"] = function() setting = 3 end,

            default = function(x) setting = 0 end,

        }

        return setting

    end

}

ClanSkills[2] = { -- GLOOM

    Name = "Gloom",

    Setting = tonumber(GetVariable("Skill_Gloom")) or 1,

    Queued = true,

    DidWarn = 0,

    LastAttempt = nil,

    CanCast = function(skill)

        return (skill.Queued == true and skill.Setting > 0 and Core.Status.State == 3 and (skill.LastAttempt == nil or os.difftime(os.time(), skill.LastAttempt) > 4))

    end,

    Cast = function(skill)

        SendNoEcho(skill.Name)

        skill.LastAttempt = os.time()

    end,

    OnSuccess = function(skill)

        skill.Queued = false

        skill.LastAttempt = nil

        skill.DidWarn = 0

    end,

    OnFailure = function(skill)

        skill.Queued = true

        skill.LastAttempt = nil

    end,

    Expiration = nil,

    Success = {

        "Waves of misery and suffering emanate from your soul as Sorrow engulfs you in a veil of gloom.",

        "It's people like you who give depression a bad name."

    },

    Failures = {

        "Your aura of gloom fades slowly into the background."

    },

    DisplayValue = function(val)

        local setting = "off"

        Core.Switch(val){

            [0] = function() setting = "off" end,

            [1] = function() setting = "on" end,

            default = function(x) setting = "invalid" end,

        }

        return setting

    end,

    ParseSetting = function(wildcard)

        setting = 0

        if (wildcard == nil) then return setting end

        Core.Switch(string.lower(wildcard)){

            ["on"] = function() setting = 1 end,

            ["1"] = function() setting = 1 end,

            default = function(x) setting = 0 end,

        }

        return setting

    end

}

ClanSkills[3] = { -- SANCTUARY

    Name = "Sanctuary",

    Setting = tonumber(GetVariable("Skill_Sanctuary")) or 1,

    Queued = false,

    DidWarn = 0,

    LastAttempt = nil,

    CanCast = function(skill)
        return (skill.Queued == true and skill.Setting > 0 and Core.Status.State == 3 and (skill.LastAttempt == nil or os.difftime(os.time(), skill.LastAttempt) > 4))
    end,
    Cast = function(skill)
        -- we dont actually want to cast sanc but just listen for it

    end,
    OnSuccess = function(skill)
        if (skill.Setting == 0) then return end
        skill.DidWarn = 0

        CheckSkillDuration(skill)

    end,

    OnFailure = function(skill) end,

    Expiration = nil,

    Success = {

        "You are surrounded by a shimmering white aura of divine protection.",

        "You are already in sanctuary."

    },

    Failures = {

        "You lost your concentration while trying to cast sanctuary."

    },

    DisplayValue = function(val)

        local setting = "off"

        Core.Switch(val){

            [0] = function() setting = "off" end,

            [1] = function() setting = "on" end,

            default = function(x) setting = "invalid" end,

        }

        return setting

    end,

    ParseSetting = function(wildcard)

        setting = 0

        if (wildcard == nil) then return setting end

        Core.Switch(string.lower(wildcard)){

            ["on"] = function() setting = 1 end,

            ["1"] = function() setting = 1 end,

            default = function(x) setting = 0 end,

        }

        return setting

    end

}

function FeatureStart() AddSkillTriggers() end
function FeatureStop() print("feature stopping") end
function FeatureSettingHandle(settingName, potentialValue)
    for _, skill in ipairs(ClanSkills) do
        if (string.lower(skill.Name) == string.lower(settingName)) then
            skill.Setting = skill.ParseSetting(skillValue)
            Core.Log(skill.Name .. " : " .. skill.DisplayValue(skill.Setting))
        end
    end
end

function FeatureTick()
    CheckSkillExpirations()
    ProcessSkillQueue()
end
function FeatureHelp() Core.Log("~ pyre skills ~") end
function FeatureSave()
    for _, skill in ipairs(ClanSkills) do SetVariable("Skill_" .. skill.Name, skill.Setting) end
end

function ProcessSkillQueue()
    for _, skill in ipairs(ClanSkills) do
        Core.Log(
            "ProcessQueue: " .. skill.Name,
            Core.LogLevel.VERBOSE
        )

        local canCast = skill.CanCast(skill)
        Core.Log(
            "canCast: " .. tostring(canCast),
            Core.LogLevel.VERBOSE
        )

        if (canCast == true) then skill.Cast(skill) end

    end

end

function CheckSkillExpirations()

    if (Core.Settings.SkillExpirationWarn < 1) then return end

    for _, skill in ipairs(ClanSkills) do

        if not (skill.Expiration == nil) then

            Core.Log(

                "CheckSkillExpiration: " .. skill.Name,

                Core.LogLevel.DEBUG

            )

            local expiringSeconds = os.difftime(skill.Expiration, os.time())
            local divider = skill.DidWarn + 1
            if expiringSeconds > 0 and (skill.DidWarn < 2 and expiringSeconds < (Core.Settings.SkillExpirationWarn / divider)) then

                Core.CleanLog(

                    skill.Name .. " will expire in [" .. expiringSeconds .. "] seconds",

                    "white",

                    "white",

                    Core.LogLevel.INFO

                )

                skill.DidWarn = skill.DidWarn + 1

                return

            end

        end

    end

end

function OnSkillFail(name, line, wildcards)
    Core.Log("OnSkillFail " .. name, Core.LogLevel.DEBUG)
    local skill = GetSkillByName(string.sub(name, 6))
    if skill == nil then return end
    skill.OnFailure(skill)

end

function OnSkillSuccess(name, line, wildcards)
    Core.Log("OnSkillSuccess " .. name, Core.LogLevel.DEBUG)
    local skillName = string.sub(name, 6)
    local skill = GetSkillByName(skillName)
    if (skill == nil) then return end
    skill.OnSuccess(skill)

end

function CheckSkillDuration(skill)

    Core.Log(

        "CheckSkillDuration " .. skill.Name .. " " .. Core.Settings.SkillExpirationWarn,

        Core.LogLevel.DEBUG

    )

    if (Core.Settings.SkillExpirationWarn < 1) then return end

    EnableTrigger("ph_sd" .. skill.Name, true)

    SendNoEcho("saf " .. skill.Name)

end

function OnSkillDuration(name, line, wildcards)

    Core.Log("OnSkillDuration " .. name, Core.LogLevel.DEBUG)

    local skill = GetSkillByName(string.sub(name, 6))

    if skill == nil then return end

    EnableTrigger("ph_sd" .. skill.Name, false)

    local minutes = tonumber(wildcards[3]) or 0

    local seconds = tonumber(wildcards[4]) or 0

    Core.Log(

        "OnSkillDuration " .. name .. " Minutes " .. minutes .. " Seconds " .. seconds,

        Core.LogLevel.DEBUG

    )

    skill.Expiration = os.time() + (minutes * 60) + seconds

end

function GetSkillByName(name)

    for _, skill in ipairs(ClanSkills) do
        if string.lower(skill.Name) == string.lower(name) then return skill end
    end

    return nil

end

function AddSkillTriggers()

    for _, skill in ipairs(ClanSkills) do

        Core.Log(
            "AddSkillTrigger: " .. skill.Name,
            Core.LogLevel.DEBUG
        )

        regexForFailures = ""
        regexForSuccess = ""

        for _, msg in ipairs(skill.Failures) do
            if not (regexForFailures == "") then regexForFailures = regexForFailures .. "|" end
            regexForFailures = regexForFailures .. "(" .. msg .. ")"
        end

        for _, msg in ipairs(skill.Success) do
            if not (regexForSuccess == "") then regexForSuccess = regexForSuccess .. "|" end
            regexForSuccess = regexForSuccess .. "(" .. msg .. ")"
        end

        regexForFailures = "^" .. regexForFailures .. "$"
        regexForSuccess = "^" .. regexForSuccess .. "$"

        AddTriggerEx(
            "ph_sf" .. skill.Name,
            regexForFailures,
            "",
            trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
            -1,
            0,
            "",
            "OnSkillFail",
            0
        )

        AddTriggerEx(
            "ph_ss" .. skill.Name,
            regexForSuccess,
            "",
            trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
            -1,
            0,
            "",
            "OnSkillSuccess",
            0
        )

        AddTriggerEx(
            "ph_sd" .. skill.Name,
            "^(Skill|Spell)? *.: (.*) \\((.*):(.*)\\)*.$",
            "",
            trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary,
            -1,
            0,
            "",
            "OnSkillDuration",
            0
        )

        regexForFailures = ""
        regexForSuccess = ""

    end

end

Skills.FeatureStart = FeatureStart
Skills.FeatureStop = FeatureStop
Skills.FeatureSettingHandle = FeatureSettingHandle
Skills.FeatureTick = FeatureTick
Skills.FeatureHelp = FeatureHelp
Skills.FeatureSave = FeatureSave
return Skills

