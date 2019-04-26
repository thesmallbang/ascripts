local Pyre = require('pyrecore')

Pyre.Log('skills.lua loaded', Pyre.LogLevel.DEBUG)

SkillFeature = {
    SkillFail = nil,
    LastSkill = nil
}

ClanSkills = {}

local adjustingAlignment = false

ClanSkills[1] = {
    -- APATHY

    Name = 'Apathy',
    Setting = tonumber(GetVariable('Skill_Apathy')) or 1,
    Queued = true,
    DidWarn = 0,
    LastAttempt = nil,
    CanCast = function(skill)
        return (skill.Queued == true and skill.Setting > 0 and Pyre.Status.State == Pyre.States.IDLE and
            (skill.LastAttempt == nil or os.difftime(os.time(), skill.LastAttempt) > 4))
    end,
    Cast = function(skill)
        if not (Pyre.AlignmentToCategory(Pyre.Status.RawAlignment, adjustingAlignment) == skill.Setting) then
            if adjustingAlignment == false then
                Pyre.CleanLog(
                    'APATHY SKIPPED! Alignment: ' ..
                        string.upper(skill.DisplayValue(Pyre.AlignmentToCategory(Pyre.Status.RawAlignment))) ..
                            ' should be ' .. string.upper(skill.DisplayValue(skill.Setting))
                )

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
        'Sorrow infuses your soul with apathy.',
        'You have already succumbed to Sorrow.'
    },
    Failures = {
        'Sorrow relinquishes your soul.',
        'Sorrow takes your measure and finds you lacking.'
    },
    DisplayValue = function(val)
        return Pyre.AlignmentCategoryToString(val)
    end,
    ParseSetting = function(wildcard)
        setting = 0

        if (wildcard == nil) then
            return setting
        end

        Pyre.Switch(string.lower(wildcard)) {
            ['good'] = function()
                setting = 1
            end,
            ['1'] = function()
                setting = 1
            end,
            ['neutral'] = function()
                setting = 2
            end,
            ['2'] = function()
                setting = 2
            end,
            ['evil'] = function()
                setting = 3
            end,
            ['3'] = function()
                setting = 3
            end,
            default = function(x)
                setting = 0
            end
        }

        return setting
    end
}

ClanSkills[2] = {
    -- GLOOM

    Name = 'Gloom',
    Setting = tonumber(GetVariable('Skill_Gloom')) or 1,
    Queued = true,
    DidWarn = 0,
    LastAttempt = nil,
    CanCast = function(skill)
        return (skill.Queued == true and skill.Setting > 0 and Pyre.Status.State == Pyre.States.IDLE and
            (skill.LastAttempt == nil or os.difftime(os.time(), skill.LastAttempt) > 4))
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
        'Waves of misery and suffering emanate from your soul as Sorrow engulfs you in a veil of gloom.',
        "It's people like you who give depression a bad name."
    },
    Failures = {'Your aura of gloom fades slowly into the background.'},
    DisplayValue = function(val)
        local setting = 'off'

        Pyre.Switch(val) {
            [0] = function()
                setting = 'off'
            end,
            [1] = function()
                setting = 'on'
            end,
            default = function(x)
                setting = 'invalid'
            end
        }

        return setting
    end,
    ParseSetting = function(wildcard)
        setting = 0

        if (wildcard == nil) then
            return setting
        end

        Pyre.Switch(string.lower(wildcard)) {
            ['on'] = function()
                setting = 1
            end,
            ['1'] = function()
                setting = 1
            end,
            default = function(x)
                setting = 0
            end
        }

        return setting
    end
}

ClanSkills[3] = {
    -- SANCTUARY

    Name = 'Sanctuary',
    Setting = tonumber(GetVariable('Skill_Sanctuary')) or 1,
    Queued = false,
    DidWarn = 0,
    LastAttempt = nil,
    CanCast = function(skill)
        return (skill.Queued == true and skill.Setting > 0 and Pyre.Status.State == Pyre.States.IDLE and
            (skill.LastAttempt == nil or os.difftime(os.time(), skill.LastAttempt) > 4))
    end,
    Cast = function(skill)
        -- we dont actually want to cast sanc but just listen for it
    end,
    OnSuccess = function(skill)
        if (skill.Setting == 0) then
            return
        end
        skill.DidWarn = 0

        CheckSkillDuration(skill)
    end,
    OnFailure = function(skill)
    end,
    Expiration = nil,
    Success = {
        'You are surrounded by a shimmering white aura of divine protection.',
        'You are already in sanctuary.'
    },
    Failures = {'You lost your concentration while trying to cast sanctuary.'},
    DisplayValue = function(val)
        local setting = 'off'

        Pyre.Switch(val) {
            [0] = function()
                setting = 'off'
            end,
            [1] = function()
                setting = 'on'
            end,
            default = function(x)
                setting = 'invalid'
            end
        }

        return setting
    end,
    ParseSetting = function(wildcard)
        setting = 0

        if (wildcard == nil) then
            return setting
        end

        Pyre.Switch(string.lower(wildcard)) {
            ['on'] = function()
                setting = 1
            end,
            ['1'] = function()
                setting = 1
            end,
            default = function(x)
                setting = 0
            end
        }

        return setting
    end
}

function SkillFeature.FeatureStart()
    SkillsSetup()
end

function SkillFeature.FeatureStop()
end

function SkillFeature.FeatureSettingHandle(settingName, potentialValue)
    for _, skill in ipairs(ClanSkills) do
        if (string.lower(skill.Name) == string.lower(settingName)) then
            skill.Setting = skill.ParseSetting(potentialValue)
            Pyre.Log(skill.Name .. ' : ' .. skill.DisplayValue(skill.Setting))
        end
    end
end

function SkillFeature.FeatureTick()
    CheckSkillExpirations()
    ProcessSkillQueue()
end

function SkillFeature.FeatureHelp()
    Pyre.ColorLog('Skills', 'orange')
    Pyre.ColorLog('pyre attack - hammerswing or level appropriate bash skill', '')

    for _, skill in ipairs(ClanSkills) do
        Pyre.Log(skill.Name .. ': ' .. skill.DisplayValue(skill.Setting))
    end
end

function SkillFeature.FeatureSave()
    for _, skill in ipairs(ClanSkills) do
        SetVariable('Skill_' .. skill.Name, skill.Setting)
    end
end

function SkillFeature.OnBroadCast(msgId, pluginId, pluginName, msg)
    print('broadcast before id check ' .. pluginName)
    if (pluginId == GetPluginID()) then
        print('there was a broadcast: ' .. tostring(msgId) .. ' : ' .. tostring(msg))
    end
end

function ProcessSkillQueue()
    for _, skill in ipairs(ClanSkills) do
        Pyre.Log('ProcessQueue: ' .. skill.Name, Pyre.LogLevel.VERBOSE)

        local canCast = skill.CanCast(skill)
        Pyre.Log('canCast: ' .. tostring(canCast), Pyre.LogLevel.VERBOSE)

        if (canCast == true) then
            skill.Cast(skill)
        end
    end
end

function CheckSkillExpirations()
    if (Pyre.Settings.SkillExpirationWarn < 1) then
        return
    end

    for _, skill in ipairs(ClanSkills) do
        if not (skill.Expiration == nil) then
            Pyre.Log('CheckSkillExpiration: ' .. skill.Name, Pyre.LogLevel.DEBUG)

            local expiringSeconds = os.difftime(skill.Expiration, os.time())
            local divider = skill.DidWarn + 1
            if
                expiringSeconds > 0 and
                    (skill.DidWarn < 2 and expiringSeconds < (Pyre.Settings.SkillExpirationWarn / divider))
             then
                Pyre.CleanLog(
                    skill.Name .. ' will expire in [' .. expiringSeconds .. '] seconds',
                    'white',
                    'white',
                    Pyre.LogLevel.INFO
                )

                skill.DidWarn = skill.DidWarn + 1

                return
            end
        end
    end
end

function OnSkillFail(name, line, wildcards)
    Pyre.Log('OnSkillFail ' .. name, Pyre.LogLevel.DEBUG)
    local skill = SkillFeature.GetSkillByName(string.sub(name, 6))
    if skill == nil then
        return
    end
    skill.OnFailure(skill)
end

function OnSkillSuccess(name, line, wildcards)
    Pyre.Log('OnSkillSuccess ' .. name, Pyre.LogLevel.DEBUG)
    local skillName = string.sub(name, 6)
    local skill = SkillFeature.GetSkillByName(skillName)
    if (skill == nil) then
        return
    end
    skill.OnSuccess(skill)
end

function CheckSkillDuration(skill)
    Pyre.Log('CheckSkillDuration ' .. skill.Name .. ' ' .. Pyre.Settings.SkillExpirationWarn, Pyre.LogLevel.DEBUG)

    if (Pyre.Settings.SkillExpirationWarn < 1) then
        return
    end

    EnableTrigger('ph_sd' .. skill.Name, true)

    SendNoEcho('saf ' .. skill.Name)
end

function OnSkillDuration(name, line, wildcards)
    Pyre.Log('OnSkillDuration ' .. name, Pyre.LogLevel.DEBUG)

    local skill = SkillFeature.GetSkillByName(string.sub(name, 6))

    if skill == nil then
        return
    end

    EnableTrigger('ph_sd' .. skill.Name, false)

    local minutes = tonumber(wildcards[3]) or 0

    local seconds = tonumber(wildcards[4]) or 0

    Pyre.Log('OnSkillDuration ' .. name .. ' Minutes ' .. minutes .. ' Seconds ' .. seconds, Pyre.LogLevel.DEBUG)

    skill.Expiration = os.time() + (minutes * 60) + seconds
end

function OnSkillUnaffected(name, line, wildcards)
    local enemyName = wildcards[1]

    -- verify the enemy is even correct
    if (not (string.lower(enemyName) == string.lower(Pyre.Status.Enemy))) then
        return
    end

    print(wildcards[2])
    local skill = Pyre.GetClassSkillByName(wildcards[2])

    if (not (skill == nil) and (not (SkillFeature.LastSkill == nil) and (skill.Name == SkillFeature.LastSkill.Name))) then
        SkillFeature.SkillFail = skill
    end
end

function SkillFeature.GetSkillByName(name)
    for _, skill in ipairs(ClanSkills) do
        if (string.lower(skill.Name) == string.lower(name)) then
            return skill
        end
    end

    return nil
end

function SkillFeature.GetClassSkillByLevel(subclassToCheck, level, initiator)
    local foundSkill = nil
    if (initiator == nil) then
        initiator = false
    end

    for _, subclass in ipairs(Pyre.Classes) do
        if string.lower(subclass.Name) == string.lower(subclassToCheck) then
            local skillTable
            if (initiator) then
                skillTable = subclass.CombatInit
            else
                skillTable = subclass.CombatSkills
            end

            local previousSkillLoopItem = nil
            for _, skill in ipairs(skillTable) do
                if
                    ((skill.Level <= level) and (foundSkill == nil or foundSkill.Level < skill.Level) and
                        not (not (SkillFeature.SkillFail == nil) and (skill.Level > SkillFeature.SkillFail.Level)))
                 then
                    foundSkill = skill
                    if (not (SkillFeature.SkillFail == nil) and skill.Name == SkillFeature.SkillFail.Name) then
                        foundSkill = previousSkillLoopItem
                    end
                end
                previousSkillLoopItem = skill
            end
        end
    end
    return foundSkill
end

function OnSkillAttack()
    local inCombat = (Pyre.Status.State == Pyre.States.COMBAT)
    local bestSkill = SkillFeature.GetClassSkillByLevel(Pyre.Status.Subclass, Pyre.Status.Level, not (inCombat))

    if (not (Pyre.Status.State == Pyre.States.COMBAT) and not (Pyre.Status.State == Pyre.States.IDLE)) then
        Pyre.Log('Invalid State for attacking')
        return
    end

    if (not (Pyre.Status.IsLeader == true) and Pyre.Settings.OnlyLeaderInitiate == 1) then
        Pyre.Log('Initiation blocked. You are not the group leader')
        return
    end

    if not (bestSkill == nil) then
        if (bestSkill.AutoSend) then
            Execute(bestSkill.Name)
        else
            SetCommand(bestSkill.Name .. ' ')
        end
        SkillFeature.LastSkill = bestSkill
    else
        Pyre.Log('This enemy is unaffected by your available skills.', Pyre.LogLevel.INFO)
    end
end

function OnNewEnemy(enemyObject)
    SkillFeature.SkillFail = nil
    SkillFeature.LastSkill = nil
end

function SkillsSetup()
    table.insert(Pyre.Events[Pyre.Event.NewEnemy], OnNewEnemy)

    AddAlias(
        'ph_skills_attack',
        '^pyre attack$',
        '',
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        'OnSkillAttack'
    )

    AddTriggerEx(
        'ph_su',
        '^(.*) is unaffected by your (.*)!$',
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnSkillUnaffected',
        0
    )

    for _, skill in ipairs(ClanSkills) do
        Pyre.Log('AddSkillTrigger: ' .. skill.Name, Pyre.LogLevel.DEBUG)

        local regexForFailures = ''
        local regexForSuccess = ''

        for _, msg in ipairs(skill.Failures) do
            if not (regexForFailures == '') then
                regexForFailures = regexForFailures .. '|'
            end
            regexForFailures = regexForFailures .. '(' .. msg .. ')'
        end

        for _, msg in ipairs(skill.Success) do
            if not (regexForSuccess == '') then
                regexForSuccess = regexForSuccess .. '|'
            end
            regexForSuccess = regexForSuccess .. '(' .. msg .. ')'
        end

        regexForFailures = '^' .. regexForFailures .. '$'
        regexForSuccess = '^' .. regexForSuccess .. '$'

        AddTriggerEx(
            'ph_sf' .. skill.Name,
            regexForFailures,
            '',
            trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
            -1,
            0,
            '',
            'OnSkillFail',
            0
        )

        AddTriggerEx(
            'ph_ss' .. skill.Name,
            regexForSuccess,
            '',
            trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
            -1,
            0,
            '',
            'OnSkillSuccess',
            0
        )

        AddTriggerEx(
            'ph_sd' .. skill.Name,
            '^(Skill|Spell)? *.: (.*) \\((.*):(.*)\\)*.$',
            '',
            trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary,
            -1,
            0,
            '',
            'OnSkillDuration',
            0
        )
    end
end

return SkillFeature
