local Pyre = require('pyrecore')
require('socket')

local lastAreaDelayed = 0
local areaLastDuration = 0

SkillFeature = {
    SkillFail = nil,
    LastSkill = nil,
    LastAttack = 0,
    LastUnqueue = 0,
    LastSkillExecute = 0,
    LastSkillUniqueId = 0,
    BurstMode = false
}

SkillFeature.Commands = {
    {
        name = 'pyre attack',
        description = 'Queue up a single pyre attack',
        callback = 'OnPyreAttack'
    }
}

SkillFeature.Settings = {
    {
        name = 'burstdamage',
        description = 'Focus on healing if your hp is taken down by this percent in a gmcp update. ie you took burst damage',
        value = tonumber(GetVariable('burstdamage')) or 30,
        setValue = function(setting, val)
            local parsed = tonumber(val) or 0
            if (parsed > 90 or parsed < 0) then
                parsed = 30
            end
            setting.value = parsed
            SetVariable('burstdamage', setting.value)
        end
    },
    {
        name = 'burstbuffer',
        description = 'Increase your hp percent by this amount during burst mode',
        value = tonumber(GetVariable('burstbuffer')) or 10,
        setValue = function(setting, val)
            local parsed = tonumber(val) or 0
            if (parsed > 90 or parsed < 0) then
                parsed = 10
            end
            setting.value = parsed
            SetVariable('burstbuffer', setting.value)
        end
    },
    {
        name = 'onlyleaderinitiate',
        description = 'Do not hammerswing not leading group',
        value = tonumber(GetVariable('onlyleaderinitiate')) or 0,
        setValue = function(setting, val)
            local parsed = tonumber(val) or 0
            if (parsed > 1 or parsed < 0) then
                parsed = 0
            end
            setting.value = parsed
            SetVariable('onlyleaderinitiate', setting.value)
        end
    },
    {
        name = 'expirationwarn',
        description = 'How many seconds out to start warning about skill expiration',
        value = tonumber(GetVariable('expirationwarn')) or 10,
        setValue = function(setting, val)
            local parsed = tonumber(val) or 0
            setting.value = parsed
            SetVariable('expirationwarn', setting.value)
        end
    },
    {
        name = 'alignmentbuffer',
        description = 'How much alignment to recover after a slip before locking',
        value = tonumber(GetVariable('alignmentbuffer')) or 500,
        setValue = function(setting, val)
            local parsed = tonumber(val) or 0
            setting.value = parsed
            SetVariable('alignmentbuffer', setting.value)
        end
    }

    --AlignmentBuffer
}

ClanSkills = {
    [1] = {
        -- APATHY

        Name = 'Apathy',
        Setting = tonumber(GetVariable('Skill_Apathy')) or 1,
        Queued = true,
        DidWarn = 0,
        LastAttempt = nil,
        CanCast = function(skill)
            return (skill.Queued == true and skill.Setting > 0 and Pyre.Status.State == Pyre.States.IDLE and
                (skill.LastAttempt == nil or os.difftime(socket.gettime(), skill.LastAttempt) > 4))
        end,
        Cast = function(skill)
            local buffer = Pyre.GetSettingValue(SkillFeature.Settings, 'alignmentbuffer')

            if not (Pyre.AlignmentToCategory(Pyre.Status.RawAlignment, buffer, adjustingAlignment) == skill.Setting) then
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

            skill.LastAttempt = socket.gettime()
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
    },
    [2] = {
        -- GLOOM

        Name = 'Gloom',
        Setting = tonumber(GetVariable('Skill_Gloom')) or 1,
        Queued = true,
        DidWarn = 0,
        LastAttempt = nil,
        CanCast = function(skill)
            return (skill.Queued == true and skill.Setting > 0 and Pyre.Status.State == Pyre.States.IDLE and
                (skill.LastAttempt == nil or os.difftime(socket.gettime(), skill.LastAttempt) > 4))
        end,
        Cast = function(skill)
            SendNoEcho(skill.Name)

            skill.LastAttempt = socket.gettime()
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
    },
    [3] = {
        -- SANCTUARY

        Name = 'Sanctuary',
        Setting = tonumber(GetVariable('Skill_Sanctuary')) or 1,
        Queued = false,
        DidWarn = 0,
        LastAttempt = nil,
        CanCast = function(skill)
            return (skill.Queued == true and skill.Setting > 0 and Pyre.Status.State == Pyre.States.IDLE and
                (skill.LastAttempt == nil or os.difftime(socket.gettime(), skill.LastAttempt) > 4))
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
    },
    [4] = {
        -- EMPATHY

        Name = 'Empathy',
        Setting = tonumber(GetVariable('Skill_Empathy')) or 0,
        Queued = true,
        DidWarn = 0,
        LastAttempt = nil,
        CanCast = function(skill)
            return (skill.Queued == true and skill.Setting > 0 and Pyre.Status.State == Pyre.States.IDLE and
                (skill.LastAttempt == nil or os.difftime(socket.gettime(), skill.LastAttempt) > 4))
        end,
        Cast = function(skill)
            SendNoEcho('cast 520')

            skill.LastAttempt = socket.gettime()
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
            'You are ready to study combat through the eyes of your opponent.',
            'You are still recovering your Empathy abilities.*'
        },
        Failures = {'You are no longer focused on combat empathy.'},
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
}

local adjustingAlignment = false

function SkillFeature.FeatureStart()
    SkillsSetup()

    -- create an alias for each of our PyreTracker.Commands
    Pyre.Each(
        SkillFeature.Commands,
        function(cmd)
            if (cmd.callback ~= nil) then
                local safename = cmd.name:gsub('%s+', '')
                AddAlias(
                    'ph_skillcmd_' .. safename,
                    '^' .. cmd.name .. '$',
                    '',
                    alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
                    cmd.callback
                )
            end
        end
    )
end

function SkillFeature.FeatureSettingHandle(settingName, p1, p2, p3, p4)
    if (settingName ~= 'skills') then
        return
    end

    for _, setting in ipairs(SkillFeature.Settings) do
        if (string.lower(setting.name) == string.lower(p1)) then
            setting:setValue(p2)
            Pyre.Log(settingName .. ' ' .. setting.name .. ' : ' .. setting.value)
        end
    end

    for _, skill in ipairs(ClanSkills) do
        if (string.lower(skill.Name) == string.lower(p1)) then
            skill.Setting = skill.ParseSetting(p2)
            Pyre.Log(skill.Name .. ' : ' .. skill.DisplayValue(skill.Setting))
        end
    end
end

function SkillFeature.FeatureTick()
    --
    --  ALLOWED TO RUN WHILE AFK
    --
    CheckSkillExpirations()
    CheckClanSkills()

    if (Pyre.IsAFK) then
        return
    end

    --
    -- NOT ALLOWED TO RUN WHILE AFK
    --
end

function SkillFeature.FeatureHelp()
    local logTable = {}

    Pyre.Each(
        SkillFeature.Commands,
        function(command)
            table.insert(
                logTable,
                {
                    {
                        Value = command.name,
                        Tooltip = command.description,
                        Color = 'orange',
                        Action = command.name
                    },
                    {Value = command.description, Tooltip = command.description}
                }
            )
        end
    )

    -- spacer
    table.insert(logTable, {{Value = ''}})

    Pyre.Each(
        SkillFeature.Settings,
        function(setting)
            table.insert(
                logTable,
                {
                    {
                        Value = setting.name,
                        Tooltip = setting.description
                    },
                    {Value = setting.value}
                }
            )
        end
    )

    -- spacer
    table.insert(logTable, {{Value = ''}})

    -- add clan skills
    for _, skill in ipairs(ClanSkills) do
        table.insert(
            logTable,
            {
                {Value = skill.Name},
                {Value = skill.DisplayValue(skill.Setting)}
            }
        )
    end

    Pyre.LogTable(
        'Feature: Skills',
        'teal',
        {'Setting', 'Value'},
        logTable,
        1,
        true,
        'usage: pyre set skills <setting> <value> '
    )
end

function SkillFeature.FeatureSave()
    for _, skill in ipairs(ClanSkills) do
        SetVariable('Skill_' .. skill.Name, skill.Setting)
    end
end

function CheckClanSkills()
    for _, skill in ipairs(ClanSkills) do
        Pyre.Log('CheckClanSkill: ' .. skill.Name, Pyre.LogLevel.VERBOSE)

        local canCast = skill.CanCast(skill)
        Pyre.Log('canCast: ' .. tostring(canCast), Pyre.LogLevel.VERBOSE)

        if (canCast == true) then
            skill.Cast(skill)
        end
    end
end

function CheckSkillExpirations()
    local warnSetting =
        Pyre.First(
        SkillFeature.Settings,
        function(s)
            return (s.name == 'expirationwarn')
        end
    )

    local expirationWarn = warnSetting.value or 10

    if (expirationWarn < 1) then
        return
    end

    for _, skill in ipairs(ClanSkills) do
        if not (skill.Expiration == nil) then
            Pyre.Log('CheckSkillExpiration: ' .. skill.Name, Pyre.LogLevel.VERBOSE)

            local expiringSeconds = os.difftime(skill.Expiration, socket.gettime())
            local divider = skill.DidWarn + 1
            if expiringSeconds > 0 and (skill.DidWarn < 2 and expiringSeconds < (expirationWarn / divider)) then
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

function CheckSkillDuration(skill)
    local warnSetting =
        Pyre.First(
        SkillFeature.Settings,
        function(s)
            return (s.name == 'expirationwarn')
        end
    )

    local expirationWarn = warnSetting.value or 10

    if (expirationWarn < 1) then
        return
    end

    Pyre.Log('CheckSkillDuration ' .. skill.Name .. ' ' .. expirationWarn, Pyre.LogLevel.VERBOSE)

    if (expirationWarn < 1) then
        return
    end

    EnableTrigger('ph_sd' .. skill.Name, true)

    SendNoEcho('saf ' .. skill.Name)
end

function SkillFeature.AttackDequeue(skill)
    local difftime = socket.gettime() - SkillFeature.LastUnqueue
    if (difftime < 1) then
        return
    end

    local match =
        Pyre.First(
        Pyre.ActionQueue,
        function(v)
            return true
        end,
        nil
    )

    if (match == nil) then
        return
    end

    if (match.Skill.Name == skill.Name) then
        --table.remove(Pyre.ActionQueue, i)
        Pyre.ActionQueue =
            Pyre.Except(
            Pyre.ActionQueue,
            function(v)
                return (v.Skill.Name == match.Skill.Name)
            end,
            1
        )

        SkillFeature.LastUnqueue = socket.gettime()
        Pyre.Log('Skill Dequeued ' .. skill.Name, Pyre.LogLevel.DEBUG)
        -- if there are no more skills with that name we need to disable the dequeue trigger
        return
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

function SkillFeature.GetClassSkillByLevel(subclassToCheck, level, filterFn)
    local foundSkill = nil

    if (filterFn == nil) then
        filterFn = function(skill)
            return true
        end
    end

    for _, subclass in ipairs(Pyre.Classes) do
        if string.lower(subclass.Name) == string.lower(subclassToCheck) then
            local skillTable = subclass.Skills

            local previousSkillLoopItem = nil
            for _, skill in ipairs(skillTable) do
                if
                    ((skill.Level <= level) and (foundSkill == nil or foundSkill.Level < skill.Level) and
                        not (not (SkillFeature.SkillFail == nil) and (skill.Level > SkillFeature.SkillFail.Level)) and
                        (filterFn(skill)))
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

-- -----------------------------------------------
--  Trigger, Alias Callbacks
-- -----------------------------------------------

function OnClassSkillAttempted(name, line, wildcards)
    Pyre.Log('OnClassSkillAttempted ' .. name, Pyre.LogLevel.VERBOSE)
    local skillName = string.sub(name, 6)

    local skill = Pyre.GetClassSkillByName(skillName)
    if (skill == nil) then
        return
    end
    SkillFeature.AttackDequeue(skill)
end

function OnClanSkillDurationFound(name, line, wildcards)
    Pyre.Log('OnClanSkillDurationFound ' .. name, Pyre.LogLevel.VERBOSE)

    local skill = SkillFeature.GetSkillByName(string.sub(name, 6))

    if skill == nil then
        return
    end

    EnableTrigger('ph_sd' .. skill.Name, false)

    local minutes = tonumber(wildcards[3]) or 0

    local seconds = tonumber(wildcards[4]) or 0

    Pyre.Log(
        'OnClanSkillDurationFound ' .. name .. ' Minutes ' .. minutes .. ' Seconds ' .. seconds,
        Pyre.LogLevel.DEBUG
    )

    skill.Expiration = socket.gettime() + (minutes * 60) + seconds
end

function OnSkillUnaffected(name, line, wildcards)
    Pyre.Log('OnSkillUnaffected', Pyre.LogLevel.VERBOSE)
    local enemyName = wildcards[1]

    -- verify the enemy is even correct
    if (not (string.lower(enemyName) == string.lower(Pyre.Status.Enemy))) then
        return
    end

    local skill = Pyre.GetClassSkillByName(wildcards[2])

    if (not (skill == nil) and (not (SkillFeature.LastSkill == nil) and (skill.Name == SkillFeature.LastSkill.Name))) then
        SkillFeature.SkillFail = skill
        -- replace all unaffected matches with next best option

        Pyre.ActionQueue =
            Pyre.Except(
            Pyre.ActionQueue,
            function(q)
                return (q.Skill.Name == skill.Name)
            end
        )
    end
end

function OnClanSkillFailed(name, line, wildcards)
    Pyre.Log('OnClanSkillFailed ' .. name, Pyre.LogLevel.VERBOSE)
    local skill = SkillFeature.GetSkillByName(string.sub(name, 6))
    if skill == nil then
        return
    end
    skill.OnFailure(skill)
end

function OnClassSkillUsed(name, line, wildcards)
    Pyre.Log('OnClassSkillUsed ' .. name, Pyre.LogLevel.VERBOSE)

    local match = wildcards[2]
    local skill = Pyre.GetClassSkillByName(match)
    if (skill == nil) then
        return true
    end
    SkillFeature.AttackDequeue(skill)
    return true
end

function OnClanSkillSuccess(name, line, wildcards)
    Pyre.Log('OnClanSkillSuccess ' .. name, Pyre.LogLevel.VERBOSE)
    local skillName = string.sub(name, 6)
    local skill = SkillFeature.GetSkillByName(skillName)
    if (skill == nil) then
        return
    end
    skill.OnSuccess(skill)
end

function OnPyreAttack()
    local inCombat = (Pyre.Status.State == Pyre.States.COMBAT)

    -- we only want a skill selection appriopriate to our combat status
    local skillFilter = function(skill)
        return ((inCombat and skill.SkillType == Pyre.SkillType.CombatMove) or
            (not (inCombat) and skill.SkillType == Pyre.SkillType.CombatInitiate))
    end
    local bestSkill = SkillFeature.GetClassSkillByLevel(Pyre.Status.Subclass, Pyre.Status.Level, skillFilter)

    if (not (Pyre.Status.State == Pyre.States.COMBAT) and not (Pyre.Status.State == Pyre.States.IDLE)) then
        Pyre.Log('Invalid State for attacking', Pyre.LogLevel.DEBUG)
        return
    end

    if ((Pyre.Status.IsLeader == false) and (Pyre.Settings.OnlyLeaderInitiate == 1)) then
        Pyre.Log('Initiation blocked. You are not the group leader', Pyre.LogLevel.INFO)
        return
    end

    local difftime = (SkillFeature.LastAttack + tonumber(Pyre.Settings.AddToQueueDelay)) - socket.gettime()
    if (tonumber(difftime) > 0) then
        Pyre.Log('Attack delay not met', Pyre.LogLevel.DEBUG)
        return
    end

    if (Pyre.Settings.QueueSize > 0 and Pyre.TableLength(Pyre.ActionQueue) >= Pyre.Settings.QueueSize) then
        Pyre.Log('Attack Queue is full', Pyre.LogLevel.DEBUG)
        return
    end

    if not (bestSkill == nil) then
        -- dont allow duplicate initiators
        if
            (Pyre.Any(
                Pyre.ActionQueue,
                function(v)
                    return (v.Skill.SkillType == Pyre.SkillType.CombatInitiate)
                end
            ))
         then
            Pyre.Log('Discarding duplicate initiator attack', Pyre.LogLevel.DEBUG)
            return
        end

        table.insert(
            Pyre.ActionQueue,
            {
                Skill = bestSkill,
                Expiration = nil,
                Execute = function(s, qitem)
                    if
                        ((Pyre.Status.IsLeader == false) and
                            (Pyre.GetSettingValue(SkillFeature.Settings, 'onlyleaderinitiate') == 1))
                     then
                        Pyre.Log('Initiation cancelled. You are not the group leader', Pyre.LogLevel.INFO)
                        -- remove initiations
                        Pyre.ActionQueue =
                            Pyre.Except(
                            Pyre.ActionQueue,
                            function(aq)
                                return aq.SkillType == Pyre.SkillType.CombatInitiate
                            end
                        )
                        return
                    end

                    if (SkillFeature.BurstMode and s.SkillType ~= Pyre.SkillType.QuaffHeal) then
                        Pyre.Log('Skipped attack for burst mode')
                        -- remove initiations
                        Pyre.ActionQueue =
                            Pyre.Except(
                            Pyre.ActionQueue,
                            function(aq)
                                return aq.uid ~= Pyre.SkillType.uid
                            end,
                            1
                        )
                        if (Pyre.addedWait == 0) then
                            Pyre.addedWait = 2
                        end
                        return
                    end

                    -- we are in combat we are skipping a combat init
                    if ((s.SkillType == Pyre.SkillType.CombatInitiate) and (Pyre.Status.State == Pyre.States.COMBAT)) then
                        Pyre.Log('Skipping Combat Initiator, already in combat', Pyre.LogLevel.DEBUG)
                        Pyre.ActionQueue =
                            Pyre.Except(
                            Pyre.ActionQueue,
                            function(aq)
                                return aq.SkillType == Pyre.SkillType.CombatInitiate
                            end
                        )
                        return
                    end

                    SkillFeature.LastSkill = s
                    if (s.AutoSend) then
                        local regexForAttempt = ''

                        for _, attempt in pairs(s.Attempts) do
                            if not (regexForAttempt == '') then
                                regexForAttempt = regexForAttempt .. '|'
                            end
                            regexForAttempt = regexForAttempt .. '(' .. attempt .. ')'
                        end

                        local triggerName = 'ph_sa' .. s.Name
                        AddTriggerEx(
                            triggerName,
                            '^' .. regexForAttempt .. '$',
                            '',
                            trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace +
                                trigger_flag.Temporary +
                                trigger_flag.KeepEvaluating, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
                            -1,
                            0,
                            '',
                            'OnClassSkillAttempted',
                            0
                        )

                        Execute(s.Name)
                    else
                        SetCommand(s.Name .. ' ')
                        return
                    end
                end
            }
        )

        Pyre.Log(bestSkill.Name .. ' queued [' .. Pyre.TableLength(Pyre.ActionQueue) .. ']')

        SkillFeature.LastAttack = socket.gettime()
    else
        Pyre.Log('This enemy is unaffected by your available skills.', Pyre.LogLevel.INFO)
    end
end

function SkillsFeatureOnQuaffHealUsed()
    Pyre.addedWait = Pyre.GetSettingValue(SkillFeature.Settings, 'delayAfterHeal')
end

function SkillsFeatureOnHpChanged(hpData)
    if (hpData.Old - hpData.New > Pyre.GetSettingValue(SkillFeature.Settings, 'burstdamage')) then
        if not (SkillFeature.BurstMode) then
            SkillFeature.BurstMode = true
            Pyre.Log('Burst mode enabled')
        end
    else
        if (SkillFeature.BurstMode) then
            if (hpData.New > hpData.Old) then
                SkillFeature.BurstMode = false
                Pyre.Log('Burst mode disabled')
            end
        end
    end
end

function SkillsFeatureOnStateChanged(stateData)
    if (stateData.New ~= Pyre.States.COMBAT) then
        SkillFeature.BurstMode = false
    end
end

function SkillsSetup()
    Pyre.Log('SkillsSetup (alias+triggers)', Pyre.LogLevel.DEBUG)
    table.insert(Pyre.Events[Pyre.Event.HpChanged], SkillsFeatureOnHpChanged)
    table.insert(Pyre.Events[Pyre.Event.StateChanged], SkillsFeatureOnStateChanged)

    AddTriggerEx(
        'ph_coreqfs',
        '^\\[.*\\] A warm feeling fills your body. \\[.*\\]$',
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary +
            trigger_flag.KeepEvaluating, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnCoreQuaffHealUsed',
        0
    )

    AddTriggerEx(
        'ph_clsskillused',
        '^(\\*)?\\[.*\\]?\\s?Your\\s(\\w*) -?<?(.*)>?-? (.*)! \\[(.*)\\]$',
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.KeepEvaluating + trigger_flag.Replace +
            trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnClassSkillUsed',
        1
    )

    AddTriggerEx(
        'ph_skillunaffected',
        '^(.*) is unaffected by your (.*)!$',
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.KeepEvaluating + trigger_flag.Replace +
            trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
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
            trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.KeepEvaluating + trigger_flag.Replace +
                trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
            -1,
            0,
            '',
            'OnClanSkillFailed',
            0
        )

        AddTriggerEx(
            'ph_ss' .. skill.Name,
            regexForSuccess,
            '',
            trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.KeepEvaluating + trigger_flag.Replace +
                trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
            -1,
            0,
            '',
            'OnClanSkillSuccess',
            0
        )

        AddTriggerEx(
            'ph_sd' .. skill.Name,
            '^(Skill|Spell|Recovery)? *.: (.*) \\((.*):(.*)\\)*.$',
            '',
            trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.KeepEvaluating + trigger_flag.Temporary,
            -1,
            0,
            '',
            'OnClanSkillDurationFound',
            0
        )
    end
end

return SkillFeature
