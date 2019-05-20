local Core = require('pyrecore')
require('socket')
local Skills = {
    adjustingAlignment = false
}

Skills.Config = {
    TickLimits = {LastTick = 0, Seconds = 2},
    Events = {
        {
            Type = Core.Event.Tick,
            Callback = function(o)
                Skills.Tick()
            end
        }
    },
    Commands = {
        {
            Name = 'attack',
            Description = 'Initiate a pyre attack',
            Callback = function(line, wildcards)
            end
        }
    },
    Settings = {
        {
            Name = 'onlyleaderinitiate',
            Description = 'You will not initiate combat when in a group and not the leader',
            Value = nil,
            Min = 0,
            Max = 1,
            Default = 1
        },
        {
            Name = 'expirationwarn',
            Description = 'Warn when a skill will expire. Also at half time it will warn. 0 to disable',
            Value = nil,
            Min = 0,
            Max = 240,
            Default = 10
        },
        {
            Name = 'apathy',
            Description = 'Enable alignment locking',
            Value = nil,
            Min = 0,
            Max = 1,
            Default = 0,
            OnAfterSet = function(setting, nv, ov)
                Skills.RemoveCustomSkills()
                Skills.AddCustomSkills()
            end
        },
        {
            Name = 'alignment',
            Description = 'Apathy will work on staying (0 off, 1 good, 2 neutral, 3 evil)',
            Value = nil,
            Min = 0,
            Max = 3,
            Default = 2
        },
        {
            Name = 'alignmentbuffer',
            Description = 'how much alignment to recover after a slip before locking again.',
            Value = nil,
            Min = 1,
            Max = 600,
            Default = 500
        },
        {
            Name = 'gloom',
            Description = 'should gloom be autocast',
            Value = nil,
            Min = 0,
            Max = 1,
            Default = 1,
            OnAfterSet = function(setting)
                Skills.RemoveCustomSkills()
                Skills.AddCustomSkills()
            end
        },
        {
            Name = 'sanctuary',
            Description = 'should sanctuary be tracked',
            Value = nil,
            Min = 0,
            Max = 1,
            Default = 1,
            OnAfterSet = function(setting)
                Skills.RemoveCustomSkills()
                Skills.AddCustomSkills()
            end
        },
        {
            Name = 'empathy',
            Description = 'should empathy be autocast',
            Value = nil,
            Min = 0,
            Max = 1,
            Default = 0,
            OnAfterSet = function(setting)
                Skills.RemoveCustomSkills()
                Skills.AddCustomSkills()
            end
        }
    },
    Triggers = {
        {
            Name = 'DurationWasFound',
            Match = '(Skill|Spell|Recovery)? *.: (.*) \\((.*):(.*)\\)*.',
            Callback = function(line, wildcards)
                local spell = Core.GetClassSkillByName(wildcards[2])

                if spell == nil then
                    return
                end

                local minutes = tonumber(wildcards[3]) or 0

                local seconds = tonumber(wildcards[4]) or 0
                Core.Log(spell.Name .. ' duration : Minutes ' .. minutes .. ' Seconds ' .. seconds, Core.LogLevel.DEBUG)
                spell.Expiration = socket.gettime() + (minutes * 60) + seconds
                Core.RemoveAction(spell.Name)
            end
        }
    }
}

function Skills.Start()
    Skills.AddCustomSkills()
end

function Skills.AddCustomSkills()
    -- we are going to stuff our setup skills in the custom section
    local custom = Core.GetClassByName('custom')
    if (custom == nil) then
        return
    end

    if (Core.GetSettingValue(Skills, 'apathy') > 0) then
        table.insert(
            custom.Spells,
            {
                ActionType = core_module.ActionType.Buff,
                Name = 'Apathy',
                CastWith = 'apathy',
                Level = 1,
                Applied = nil,
                Expiration = nil,
                OnBeforeCast = function(spell)
                    -- check alignment and cancel if needed

                    local buffer = Core.GetSettingValue(Skills, 'alignmentbuffer')
                    local alignmentWanted = Core.GetSettingValue(Skills, 'alignment')

                    local currentAlignmentCategory =
                        Core.AlignmentToCategory(Core.Status.RawAlignment, buffer, Skills.adjustingAlignment)

                    if (currentAlignmentCategory ~= alignmentWanted) then
                        if Skills.adjustingAlignment == false then
                            Core.Log('APATHY SKIPPED. Your alignment is not valid for locking.', Core.LogLevel.ERROR)
                            Skills.adjustingAlignment = true
                        end
                        return false
                    end
                end,
                Success = {
                    'Sorrow infuses your soul with apathy.',
                    'You have already succumbed to Sorrow.'
                },
                Failures = {
                    'Sorrow relinquishes your soul.',
                    'Sorrow takes your measure and finds you lacking.'
                }
            }
        )
    end
    if (Core.GetSettingValue(Skills, 'gloom') > 0) then
        table.insert(
            custom.Spells,
            {
                ActionType = core_module.ActionType.Buff,
                Name = 'Gloom',
                CastWith = 'gloom',
                Level = 1,
                Applied = nil,
                Expiration = nil,
                Success = {
                    'Waves of misery and suffering emanate from your soul as Sorrow engulfs you in a veil of gloom.',
                    "It's people like you who give depression a bad name."
                },
                Failures = {'Your aura of gloom fades slowly into the background.'}
            }
        )
    end
    if (Core.GetSettingValue(Skills, 'sanctuary') > 0) then
        table.insert(
            custom.Spells,
            {
                ActionType = core_module.ActionType.BuffDurationOnly,
                Name = 'Sanctuary',
                Level = 1,
                Applied = nil,
                Expiration = nil,
                Success = {
                    'You are surrounded by a shimmering white aura of divine protection.',
                    'You are already in sanctuary.'
                },
                Failures = {'You lost your concentration while trying to cast sanctuary.'}
            }
        )
    end
    if (Core.GetSettingValue(Skills, 'empathy') > 0) then
        table.insert(
            custom.Spells,
            {
                ActionType = core_module.ActionType.Buff,
                Name = 'Empathy',
                CastWith = 'cast 520',
                Level = 1,
                Applied = nil,
                Expiration = nil,
                Success = {
                    'You are ready to study combat through the eyes of your opponent.',
                    'You are still recovering your Empathy abilities.*'
                },
                Failures = {
                    'You are no longer focused on combat empathy.',
                    '\\#\\# You may now use empath based abilities.'
                }
            }
        )
    end

    Core.Each(
        custom.Spells,
        function(spell)
            Skills.HookIn(spell)
        end
    )
end

function Skills.RemoveCustomSkills()
    -- remove custom skills
    local custom = Core.GetClassByName('custom')
    if (custom == nil) then
        return
    end

    custom.Spells =
        Core.Except(
        custom.Spells,
        function(s)
            return (s.Name == 'Apathy' or s.Name == 'Gloom' or s.Name == 'Sanctuary' or s.Name == 'Empathy')
        end
    )
end

function Skills.Stop()
    Skills.RemoveCustomSkills()
end

function Skills.Tick()
    if (os.time() - Skills.Config.TickLimits.LastTick < Skills.Config.TickLimits.Seconds) then
        return
    end

    if (Core.Status.State == Core.States.IDLE) then
        Skills.CheckOnSkills()
    end
    Skills.Config.TickLimits.LastTick = os.time()
end

function Skills.HookIn(spell)
    -- we are going to do a trigger per spell for now
    local regexForFailures = ''
    local regexForSuccess = ''

    Core.Each(
        spell.Success,
        function(successMessage)
            if not (regexForSuccess == '') then
                regexForSuccess = regexForSuccess .. '|'
            end
            regexForSuccess = regexForSuccess .. '(' .. successMessage .. ')'
        end
    )

    Core.Each(
        spell.Failures,
        function(failuresMessage)
            if not (regexForFailures == '') then
                regexForFailures = regexForFailures .. '|'
            end
            regexForFailures = regexForFailures .. '(' .. failuresMessage .. ')'
        end
    )

    AddTriggerEx(
        'sf' .. spell.Name,
        regexForFailures,
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.KeepEvaluating + trigger_flag.Replace +
            trigger_flag.Temporary,
        -1,
        0,
        '',
        'OnSkillFailedDetected',
        0
    )

    AddTriggerEx(
        'ss' .. spell.Name,
        regexForSuccess,
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.KeepEvaluating + trigger_flag.Replace +
            trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnSkillSuccessDetected',
        0
    )
end

function Skills.Unhook(spell)
    -- delete triggers
end

function Skills.CheckOnSkills()
    local custom = Core.GetClassByName('custom')
    if (custom == nil) then
        return
    end

    Core.Each(
        custom.Spells,
        function(spell)
            -- check each spell for an expiration

            if
                (spell.ActionType == Core.ActionType.BuffDurationOnly and
                    (spell.Expiration == nil or spell.Expiration < os.time()))
             then
                -- not going to bother with the queue since this can be spammed
                if
                    not (Core.Any(
                        Core.ActionQueue,
                        function(a)
                            return a.Info.Name == spell.Name
                        end
                    ))
                 then
                    Core.AddAction(
                        spell.Name,
                        spell.ActionType,
                        function(action)
                            Core.Execute('saf ' .. spell.Name)
                        end
                    )
                end
            end

            if (spell.ActionType == Core.ActionType.Buff and spell.Applied ~= nil and spell.Expiration == nil) then
                -- we have casted the buff but do not know the duration/expiration yet

                if
                    not (Core.Any(
                        Core.ActionQueue,
                        function(a)
                            return a.Info.Name == spell.Name
                        end
                    ))
                 then
                    Core.AddAction(
                        spell.Name,
                        spell.ActionType,
                        function(action)
                            Core.Execute('saf ' .. spell.Name)
                        end
                    )
                end
            end

            if (spell.ActionType == Core.ActionType.Buff and (spell.Expiration == nil or spell.Expiration < os.time())) then
                -- queue up a casting action
                -- we are just going to refer to everything as buff for queue behaviour outside of this plugin

                if
                    not (Core.Any(
                        Core.ActionQueue,
                        function(a)
                            return a.Info.Name == spell.Name
                        end
                    ))
                 then
                    if (spell.OnBeforeCast ~= nil) then
                        local result = spell.OnBeforeCast(spell)
                        if (result == false) then
                            -- the before check pulled out of the cast
                            return
                        end
                    end
                    Core.AddAction(
                        spell.Name,
                        spell.ActionType,
                        function(action)
                            Core.Execute(spell.CastWith or ('cast ' .. spell.Name))
                            if (spell.OnAfterCast ~= nil) then
                                spell.OnAfterCast(spell, action)
                            end
                        end
                    )
                end
            end
        end
    )
end

function OnSkillSuccessDetected(name, line, wildcards)
    Core.Log('OnSkillSuccessDetected ' .. name, Core.LogLevel.DEBUG)
    local spell = Core.GetClassSkillByName(string.sub(name, 3))

    if spell == nil then
        Core.RemoveAction(name)
        return
    end

    spell.Applied = os.time()
    Core.RemoveAction(spell.Name)
end

function OnSkillFailedDetected(name, line, wildcards)
    Core.Log('OnSkillFailedDetected ' .. name, Core.LogLevel.DEBUG)
    local spell = Core.GetClassSkillByName(string.sub(name, 3))

    if spell == nil then
        Core.RemoveAction(name)
        return
    end
    Core.RemoveAction(spell.Name)
end

return Skills
