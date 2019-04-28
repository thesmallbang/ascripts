local Pyre = require('pyrecore')
require('socket')

Pyre.Log('skills.lua loaded', Pyre.LogLevel.DEBUG)

-- ------------------------
--  THESE ARE USING socket.gettime() instead of os.time() for millisecond accuracy
--  LastAttack / AttackQueue.QueuedTime
-- ------------------------

SkillFeature = {
    SkillFail = nil,
    LastSkill = nil,
    LastAttack = 0,
    AttackQueue = {},
    LastUnqueue = 0,
    LastSkillUniqueId = 0,
    LastQuaff = 0
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
}

Quaff = {
    Save = function(q)
        SetVariable('quaff_enabled', q.Enabled)
        SetVariable('quaff_topoff', q.Topoff)
        SetVariable('quaff_container', q.Container)
        q.Hp:Save()
        q.Mp:Save()
        q.Mv:Save()
    end,
    Enabled = tonumber(GetVariable('quaff_enabled')) or 0,
    Topoff = tonumber(GetVariable('quaff_topoff')) or 0,
    Container = GetVariable('quaff_container') or '',
    Hp = {
        Name = 'Hp',
        Failed = false,
        Percent = tonumber(GetVariable('Quaff_hp_percent')) or 50,
        TopOffPercent = tonumber(GetVariable('Quaff_hp_topoff_percent')) or 50,
        Item = GetVariable('quaff_hp_item') or 'heal',
        DefaultItem = 'heal',
        Save = function(stat)
            SetVariable('quaff_hp_item', stat.Item or 'heal')
            SetVariable('Quaff_hp_topoff_percent', stat.TopOffPercent or 50)
            SetVariable('Quaff_hp_percent', stat.Percent or 50)
        end,
        Needed = function(stat)
            if (stat.Failed == true) then
                return false
            end

            local inCombat = (Pyre.Status.State == Pyre.States.COMBAT)
            return ((Pyre.Status.Hp < Quaff.Hp.Percent and inCombat == true) or
                (Pyre.Status.Hp < Quaff.Hp.TopOffPercent and inCombat == false))
        end
    },
    Mp = {
        Name = 'Mp',
        Failed = false,
        Percent = tonumber(GetVariable('Quaff_mp_percent')) or 50,
        TopOffPercent = tonumber(GetVariable('Quaff_mp_topoff_percent')) or 50,
        Item = GetVariable('quaff_mp_item') or 'lotus',
        DefaultItem = 'lotus',
        Save = function(stat)
            SetVariable('quaff_mp_item', stat.Item or 'lotus')
            SetVariable('Quaff_mp_topoff_percent', stat.TopOffPercent or 50)
            SetVariable('Quaff_mp_percent', stat.Percent or 50)
        end,
        Needed = function(stat)
            if (stat.Failed == true) then
                return false
            end
            local inCombat = (Pyre.Status.State == Pyre.States.COMBAT)
            return ((Pyre.Status.Mana < stat.Percent and inCombat == true) or
                (Pyre.Status.Mana < stat.TopOffPercent and inCombat == false))
        end
    },
    Mv = {
        Name = 'Mv',
        Failed = false,
        Percent = tonumber(GetVariable('Quaff_mv_percent')) or 50,
        TopOffPercent = tonumber(GetVariable('Quaff_mv_topoff_percent')) or 50,
        Item = GetVariable('quaff_mv_item') or 'move',
        DefaultItem = 'move',
        Save = function(stat)
            SetVariable('quaff_mv_item', stat.Item or 'move')
            SetVariable('Quaff_mv_topoff_percent', stat.TopOffPercent or 50)
            SetVariable('Quaff_mv_percent', stat.Percent or 50)
        end,
        Needed = function(stat)
            if (stat.Failed == true) then
                return false
            end
            local inCombat = (Pyre.Status.State == Pyre.States.COMBAT)
            return ((Pyre.Status.Moves < stat.Percent and inCombat == true) or
                (Pyre.Status.Moves < stat.TopOffPercent and inCombat == false))
        end
    }
}

local adjustingAlignment = false

function SkillFeature.FeatureStart()
    SkillsSetup()
end

function SkillFeature.FeatureStop()
end

function SkillFeature.FeatureSettingHandle(settingName, p1, p2, p3, p4)
    Pyre.Switch(string.lower(settingName)) {
        ['quaff'] = function()
            if (p2 == nil) then
                return
            end
            local stat = nil
            Pyre.Switch(string.lower(p1)) {
                ['clear'] = function()
                    Quaff.Hp.Failed = false
                    Quaff.Mp.Failed = false
                    Quaff.Mv.Failed = false
                    Pyre.Log('Quaff potion failures have been reset')
                end,
                ['enabled'] = function()
                    Quaff.Enabled = tonumber(p2) or 0
                    if (Quaff.Enabled < 0 or Quaff.Enabled > 1) then
                        Quaf.Enabled = 0
                    end
                    Pyre.Log('quaff enabled: ' .. Quaff.Enabled)
                end,
                ['container'] = function()
                    Quaff.Container = tostring(p2) or ''
                    Pyre.Log('quaff container: ' .. Quaff.Container)
                end,
                ['topoff'] = function()
                    Quaff.Topoff = tonumber(p2) or 0
                    if (Quaff.Topoff < 0 or Quaff.Topoff > 1) then
                        Quaf.Topoff = 0
                    end
                    Pyre.Log('quaff topoff: ' .. Quaff.Topoff)
                end,
                ['hp'] = function()
                    stat = Quaff.Hp
                end,
                ['mp'] = function()
                    stat = Quaff.Mp
                end,
                ['mv'] = function()
                    stat = Quaff.Mv
                end
            }

            if not (stat == nil) then
                Pyre.Switch(string.lower(p2)) {
                    ['percent'] = function()
                        stat.Percent = tonumber(p3) or 50
                        if (stat.Percent < 0) then
                            stat.Percent = 0
                        end
                        if (stat.Percent > 99) then
                            stat.Percent = 99
                        end
                        Pyre.Log('quaff ' .. stat.Name .. ' percent : ' .. tostring(stat.Percent))
                    end,
                    ['topoffpercent'] = function()
                        stat.TopOffPercent = tonumber(p3) or 50
                        if (stat.TopOffPercent < 0) then
                            stat.TopOffPercent = 0
                        end
                        if (stat.TopOffPercent > 99) then
                            stat.TopOffPercent = 99
                        end
                        Pyre.Log('quaff ' .. stat.Name .. ' topoff percent : ' .. tostring(stat.TopOffPercent))
                    end,
                    ['item'] = function()
                        local i = stat.DefaultItem
                        if not (p3 == '') then
                            i = p3
                        end
                        stat.Item = i
                        Pyre.Log('quaff ' .. stat.Name .. ' item : ' .. tostring(stat.Item))
                    end
                }
            end
            Quaff:Save()
        end,
        ['skill'] = function(p1, p2, p3)
            for _, skill in ipairs(ClanSkills) do
                if (string.lower(skill.Name) == string.lower(p1)) then
                    skill.Setting = skill.ParseSetting(p2)
                    Pyre.Log(skill.Name .. ' : ' .. skill.DisplayValue(skill.Setting))
                end
            end
        end
    }
end

function SkillFeature.FeatureTick()
    CheckSkillExpirations()
    CheckClanSkills()
    CleanExpiredAttackQueue()
    CheckForQuaff()
    ProcessAttackQueue()
end

function SkillFeature.FeatureHelp()
    Pyre.ColorLog('Skills', 'orange')
    Pyre.ColorLog('pyre attack - hammerswing or level appropriate bash skill', '')

    for _, skill in ipairs(ClanSkills) do
        Pyre.Log(skill.Name .. ': ' .. skill.DisplayValue(skill.Setting))
    end
end

function SkillFeature.FeatureSave()
    Quaff:Save()

    for _, skill in ipairs(ClanSkills) do
        SetVariable('Skill_' .. skill.Name, skill.Setting)
    end
end

function SkillFeature.OnBroadCast(msgId, pluginId, pluginName, msg)
end

function CleanExpiredAttackQueue()
    Pyre.Log('CleanExpiredAttackQueue', Pyre.LogLevel.VERBOSE)

    i = 0
    for _, item in pairs(SkillFeature.AttackQueue) do
        i = i + 1
        if not (item.Expiration == nil) then
            if (socket.gettime() > item.Expiration) then
                Pyre.Log('Queue had expiration: ' .. item.Skill.Name, Pyre.LogLevel.DEBUG)
                --table.remove(SkillFeature.AttackQueue, i)
                -- not sure why table.remove wasn't working? maybe cause we have a callback in it.. oh well new functionality was born
                if (SkillFeature.AttackQueue == nil) then
                    return
                end
                SkillFeature.AttackQueue =
                    Pyre.Except(
                    SkillFeature.AttackQueue,
                    function(v)
                        return (v.Skill.Name == item.Skill.Name)
                    end,
                    1
                )
                return
            end
        end
    end
end

function CheckForQuaff()
    if (Quaff.Enabled == 0) then
        return
    end

    if (not (Pyre.Status.State == Pyre.States.COMBAT) and not (Pyre.Status.State == Pyre.States.IDLE)) then
        return
    end

    -- do we need any pots?
    -- these stats need to be a table to avoid all this duplicate code i'm about to write
    -- hp

    if (Quaff.Hp:Needed()) then
        -- is there already another quaff queued for this stat?
        local queued =
            Pyre.First(
            SkillFeature.AttackQueue,
            function(q)
                return (q.Skill.SkillType == Pyre.SkillType.QuaffHeal or q.Skill.SkillType == Pyre.SkillType.QuaffMana or
                    q.Skill.SkillType == Pyre.SkillType.QuaffMove)
            end
        )

        if (queued == nil) then
            -- queue it
            Pyre.Log('Adding Quaff Hp to Queue', Pyre.LogLevel.DEBUG)

            table.insert(
                SkillFeature.AttackQueue,
                0,
                {
                    Stat = Quaff.Hp,
                    Skill = {Name = 'QuaffHeal', SkillType = Pyre.SkillType.QuaffHeal},
                    Expiration = socket.gettime() + 20,
                    Execute = function(skill)
                        if (Quaff.Hp:Needed()) then
                            Pyre.Log('Executing Quaff Hp From Queue', Pyre.LogLevel.DEBUG)
                        else
                            Pyre.Log('Aborting Quaff Hp - Virtal OK', Pyre.LogLevel.DEBUG)
                        end

                        if (not (Quaff.Container == '')) then
                            Execute('get ' .. Quaff.Hp.Item .. ' ' .. Quaff.Container)
                        end
                        Execute('quaff ' .. Quaff.Hp.Item)
                    end
                }
            )
        end
    end
    -- mana
    if (Quaff.Mp:Needed()) then
        -- is there already another quaff queued for this stat?
        local queued =
            Pyre.First(
            SkillFeature.AttackQueue,
            function(q)
                return (q.Skill.SkillType == Pyre.SkillType.QuaffHeal or q.Skill.SkillType == Pyre.SkillType.QuaffMana or
                    q.Skill.SkillType == Pyre.SkillType.QuaffMove)
            end
        )

        if (queued == nil) then
            -- queue it up

            -- to know where we should queue this up we will put it first unless an heal quaff is already queued
            local isHealQueued =
                Pyre.Any(
                SkillFeature.AttackQueue,
                function(v)
                    return (v.Skill.SkillType == Pyre.SkillType.QuaffHeal)
                end
            )
            local position = (isHealQueued == true and 0 or 1)

            Pyre.Log('Adding Quaff Mana to Queue', Pyre.LogLevel.DEBUG)

            table.insert(
                SkillFeature.AttackQueue,
                position,
                {
                    Stat = Quaff.Mp,
                    Skill = {Name = 'QuaffMana', SkillType = Pyre.SkillType.QuaffMana},
                    Expiration = socket.gettime() + 20,
                    Execute = function(skill)
                        if (Quaff.Mp:Needed()) then
                            Pyre.Log('Executing Quaff Mp From Queue', Pyre.LogLevel.DEBUG)
                        else
                            Pyre.Log('Aborting Quaff Mp - Virtal OK', Pyre.LogLevel.DEBUG)
                        end

                        if not (Quaff.Container == '') then
                            Execute('get ' .. Quaff.Mp.Item .. ' ' .. Quaff.Container)
                        end
                        Execute('quaff ' .. Quaff.Mp.Item)
                    end
                }
            )
        end
    end
    -- moves

    if (Quaff.Mv:Needed()) then
        -- is there already another quaff queued for this stat?
        local queued =
            Pyre.First(
            SkillFeature.AttackQueue,
            function(q)
                return (q.Skill.SkillType == Pyre.SkillType.QuaffHeal or q.Skill.SkillType == Pyre.SkillType.QuaffMana or
                    q.Skill.SkillType == Pyre.SkillType.QuaffMove)
            end,
            nil
        )

        if (queued == nil) then
            -- queue it up

            -- to know where we should queue this up we will put it first unless an heal quaff is already queued
            local isHealQueued =
                Pyre.Any(
                SkillFeature.AttackQueue,
                function(v)
                    return (v.Skill.SkillType == Pyre.SkillType.QuaffHeal)
                end,
                1
            )

            local isManaQueued =
                Pyre.Any(
                SkillFeature.AttackQueue,
                function(v)
                    return (v.Skill.SkillType == Pyre.SkillType.QuaffMana)
                end,
                2
            )

            -- this is our least priority state to queue so we want to make sure its behind the others
            local position = 0
            if (isHealQueued) then
                position = 1
            end
            if (isManaQueued) then
                position = position + 1
            end

            Pyre.Log('Adding Move Quaff to queue', Pyre.LogLevel.DEBUG)
            table.insert(
                SkillFeature.AttackQueue,
                position,
                {
                    Stat = Quaff.Mv,
                    Skill = {Name = 'QuaffMove', SkillType = Pyre.SkillType.QuaffMana},
                    Expiration = socket.gettime() + 20,
                    Execute = function(skill)
                        if (Quaff.Mv:Needed()) then
                            Pyre.Log('Executing Quaff Mv From Queue', Pyre.LogLevel.DEBUG)
                        else
                            Pyre.Log('Aborting Quaff Mv - Virtal OK', Pyre.LogLevel.DEBUG)
                        end

                        if not (Quaff.Container == '') then
                            Execute('get ' .. Quaff.Mv.Item .. ' ' .. Quaff.Container)
                        end
                        Execute('quaff ' .. Quaff.Mv.Item)
                    end
                }
            )
        end
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

function ProcessAttackQueue()
    Pyre.Log('ProcessAttackQueue', Pyre.LogLevel.VERBOSE)

    item =
        Pyre.First(
        SkillFeature.AttackQueue,
        function()
            return true
        end
    )
    if (item == nil) then
        return
    end

    -- if our current wait is for a skill that is not a heal potion but one in queue.. we will skip past it
    if ((Quaff.Hp:Needed()) and not (item.Skill.SkillType == Pyre.SkillType.QuaffHeal)) then
        SkillFeature.AttackQueue =
            Pyre.Except(
            SkillFeature.AttackQueue,
            function(v)
                return (v.Skill.Name == item.Skill.Name)
            end,
            1
        )
        item =
            Pyre.First(
            SkillFeature.AttackQueue,
            function()
                return true
            end
        )
    end

    -- our pending skill hasnt been cleared via expiration or detection
    local lastId = SkillFeature.LastSkillUniqueId
    if (item.uid == lastId) then
        return
    end

    -- this may be silly but i wasn't sure how objects were handled and if 2 identical commands would equal the same object
    -- and just did it in case
    local newUniqueId = math.random(1, 1000000)
    item.uid = newUniqueId
    item.Execute(item.Skill, item)
    Pyre.Log(
        'Queue Length (Including This Still until detected) : ' .. Pyre.TableLength(SkillFeature.AttackQueue),
        Pyre.LogLevel.VERBOSE
    )
    SkillFeature.LastSkillUniqueId = item.uid
end

function CheckSkillExpirations()
    if (Pyre.Settings.SkillExpirationWarn < 1) then
        return
    end

    for _, skill in ipairs(ClanSkills) do
        if not (skill.Expiration == nil) then
            Pyre.Log('CheckSkillExpiration: ' .. skill.Name, Pyre.LogLevel.VERBOSE)

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

function CheckSkillDuration(skill)
    Pyre.Log('CheckSkillDuration ' .. skill.Name .. ' ' .. Pyre.Settings.SkillExpirationWarn, Pyre.LogLevel.VERBOSE)

    if (Pyre.Settings.SkillExpirationWarn < 1) then
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
        SkillFeature.AttackQueue,
        function(v)
            return true
        end,
        nil
    )

    if (match == nil) then
        return
    end

    if (match.Skill.Name == skill.Name) then
        --table.remove(SkillFeature.AttackQueue, i)
        SkillFeature.AttackQueue =
            Pyre.Except(
            SkillFeature.AttackQueue,
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

function OnQueueAttempted(name, line, wildcards)
    Pyre.Log('OnQueueAttempted ' .. name, Pyre.LogLevel.VERBOSE)
    local skillName = string.sub(name, 6)
    local skill = Pyre.GetClassSkillByName(skillName)
    if (skill == nil) then
        return
    end
    SkillFeature.AttackDequeue(skill)
end

function OnSkillDuration(name, line, wildcards)
    Pyre.Log('OnSkillDuration ' .. name, Pyre.LogLevel.VERBOSE)

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
    Pyre.Log('OnSkillUnaffected', Pyre.LogLevel.VERBOSE)
    local enemyName = wildcards[1]

    -- verify the enemy is even correct
    if (not (string.lower(enemyName) == string.lower(Pyre.Status.Enemy))) then
        return
    end

    local skill = Pyre.GetClassSkillByName(wildcards[2])

    if (not (skill == nil) and (not (SkillFeature.LastSkill == nil) and (skill.Name == SkillFeature.LastSkill.Name))) then
        SkillFeature.SkillFail = skill
        SkillFeature.AttackDequeue(skill)
    end
end

function OnSkillUsed(name, line, wildcards)
    -- verify the enemy is even correct
    -- if (not (string.lower(wildcards[3]) == string.lower(Pyre.Status.Enemy))) then
    --     return
    -- end

    local skill = Pyre.GetClassSkillByName(wildcards[1])
    if (skill == nil) then
        return
    end
    SkillFeature.AttackDequeue(skill)
end

function OnSkillFail(name, line, wildcards)
    Pyre.Log('OnSkillFail ' .. name, Pyre.LogLevel.VERBOSE)
    local skill = SkillFeature.GetSkillByName(string.sub(name, 6))
    if skill == nil then
        return
    end
    skill.OnFailure(skill)
end

function OnSkillSuccess(name, line, wildcards)
    Pyre.Log('OnSkillSuccess ' .. name, Pyre.LogLevel.VERBOSE)
    local skillName = string.sub(name, 6)
    local skill = SkillFeature.GetSkillByName(skillName)
    if (skill == nil) then
        return
    end
    skill.OnSuccess(skill)
end

function OnSkillAttack()
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

    if (not (Pyre.Status.IsLeader == true) and Pyre.Settings.OnlyLeaderInitiate == 1) then
        Pyre.Log('Initiation blocked. You are not the group leader', Pyre.LogLevel.DEBUG)
        return
    end

    local difftime = (SkillFeature.LastAttack + tonumber(Pyre.Settings.AttackDelay)) - socket.gettime()
    if (tonumber(difftime) > 0) then
        Pyre.Log('Attack delay not met', Pyre.LogLevel.DEBUG)
        return
    end

    if (Pyre.Settings.AttackMaxQueue > 0 and Pyre.TableLength(SkillFeature.AttackQueue) >= Pyre.Settings.AttackMaxQueue) then
        Pyre.Log('Attack Queue is full', Pyre.LogLevel.DEBUG)
        return
    end

    if not (bestSkill == nil) then
        local expiration = ((Pyre.TableLength(SkillFeature.AttackQueue) * 15) + 5)

        -- dont allow duplicate initiators
        if
            (Pyre.Any(
                SkillFeature.AttackQueue,
                function(v)
                    return (v.Skill.SkillType == Pyre.SkillType.CombatInitiate)
                end
            ))
         then
            Pyre.Log('Discarding duplicate initiator attack', Pyre.LogLevel.DEBUG)
            return
        end

        Pyre.Log(bestSkill.Name .. ' queued')

        table.insert(
            SkillFeature.AttackQueue,
            {
                Skill = bestSkill,
                Expiration = socket.gettime() + expiration,
                Execute = function(s, qitem)
                    -- if we quaffed recently we will add a slight delay avoid queueing an attak when a heal may we required again soon
                    if ((socket.gettime() - 2) < SkillFeature.LastQuaff) then
                        Pyre.Log('Quaff too recently .. skipping attack', Pyre.LogLevel.DEBUG)
                        SkillFeature.AttackQueue =
                            Pyre.Except(
                            SkillFeature.AttackQueue,
                            function(v)
                                if (v == nil or v.Skill == nil or s == nil) then
                                    return false
                                end
                                return (v.Skill.Name == s.Name)
                            end,
                            1
                        )
                        SkillFeature.LastAttack = socket.gettime()
                        return
                    end

                    -- we are in combat we are skipping a combat init
                    if
                        ((qitem.SkillType == Pyre.SkillType.CombatInitiate) and
                            (Pyre.Status.State == Pyre.States.COMBAT))
                     then
                        Pyre.Log('Skipping Combat Initiator, already in combat', Pyre.LogLevel.DEBUG)
                        SkillFeature.AttackQueue =
                            Pyre.Except(
                            SkillFeature.AttackQueue,
                            function(v)
                                if (v == nil or v.Skill == nil or s == nil) then
                                    return false
                                end
                                return (v.Skill.Name == s.Name)
                            end,
                            1
                        )
                        SkillFeature.LastAttack = socket.gettime()
                        return
                    end

                    if (Quaff.Hp:Needed()) then
                        Pyre.Log('Skipping Combat Move, Need Hp', Pyre.LogLevel.DEBUG)
                        SkillFeature.AttackQueue =
                            Pyre.Except(
                            SkillFeature.AttackQueue,
                            function(v)
                                if (v == nil or v.Skill == nil or s == nil) then
                                    return false
                                end
                                return (v.Skill.Name == s.Name)
                            end,
                            1
                        )
                        SkillFeature.LastAttack = socket.gettime()
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
                                trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
                            -1,
                            0,
                            '',
                            'OnQueueAttempted',
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
        SkillFeature.LastAttack = socket.gettime()
    else
        Pyre.Log('This enemy is unaffected by your available skills.', Pyre.LogLevel.INFO)
    end
end

function OnQuaffUsed(name, line, wildcards)
    -- just going lazy for now to see what kind of results i get without tracking the potions quaffed at all or
    if (SkillFeature.AttackQueue == nil) then
        return
    end

    Pyre.Log('Quaff Execute Detected', Pyre.LogLevel.DEBUG)

    local potion =
        Pyre.First(
        SkillFeature.AttackQueue,
        function(v)
            return (v.Skill.SkillType == Pyre.SkillType.QuaffHeal or v.Skill.SkillType == Pyre.SkillType.QuaffMana or
                v.Skill.SkillType == Pyre.SkillType.QuaffMove)
        end,
        nil
    )

    if ((potion == nil) or (potion.Stat == nil)) then
        return
    end

    potion.Stat.Failed = false
    SkillFeature.LastQuaff = socket.gettime()
    SkillFeature.AttackQueue =
        Pyre.Except(
        SkillFeature.AttackQueue,
        function(v)
            return ((v.Skill.SkillType == Pyre.SkillType.QuaffHeal) or (v.Skill.SkillType == Pyre.SkillType.QuaffMana) or
                (v.Skill.SkillType == Pyre.SkillType.QuaffMove))
        end,
        1
    )
end

function OnQuaffFailed(name, line, wildcards)
    -- just going lazy for now to see what kind of results i get without tracking the potions quaffed at all or
    if (SkillFeature.AttackQueue == nil) then
        return
    end

    Pyre.Log('Quaff Fail Detected', Pyre.LogLevel.DEBUG)

    local potion =
        Pyre.First(
        SkillFeature.AttackQueue,
        function(v)
            return (v.Skill.SkillType == Pyre.SkillType.QuaffHeal or v.Skill.SkillType == Pyre.SkillType.QuaffMana or
                v.Skill.SkillType == Pyre.SkillType.QuaffMove)
        end,
        nil
    )

    if (potion == nil) then
        return
    end

    potion.Stat.Failed = true
    SkillFeature.LastQuaff = 0
    Pyre.Log(
        'Quaff Disabled for ' .. potion.Stat.Name .. " type 'pyre setting quaff clear' to reset",
        Pyre.LogLevel.INFO
    )
    SkillFeature.AttackQueue =
        Pyre.Except(
        SkillFeature.AttackQueue,
        function(v)
            return ((v.Skill.SkillType == Pyre.SkillType.QuaffHeal) or (v.Skill.SkillType == Pyre.SkillType.QuaffMana) or
                (v.Skill.SkillType == Pyre.SkillType.QuaffMove))
        end,
        1
    )
end

function OnNewEnemy(enemyObject)
    SkillFeature.SkillFail = nil
    SkillFeature.LastSkill = nil
end

function OnStateChange(stateObject)
    if (stateObject.new == Pyre.States.IDLE) then
        SkillFeature.AttackQueue = {}
        CheckForQuaff()
    end
end

function SkillsSetup()
    Pyre.Log('SkillsSetup (alias+triggers)', Pyre.LogLevel.DEBUG)
    -- subscribe to some core events
    table.insert(Pyre.Events[Pyre.Event.NewEnemy], OnNewEnemy)
    table.insert(Pyre.Events[Pyre.Event.StateChanged], OnStateChange)

    AddTriggerEx(
        'ph_qff',
        "^You don't have that potion.$",
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnQuaffFailed',
        0
    )
    AddTriggerEx(
        'ph_qfs',
        '^You quaff (.*)$',
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnQuaffUsed',
        0
    )

    AddAlias(
        'ph_skills_attack',
        '^pyre attack$',
        '',
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        'OnSkillAttack'
    )

    AddTriggerEx(
        'ph_skillused',
        '^Your (\\w*) -?<(.*)>-? (.*)! \\[(.*)\\]$',
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnSkillUsed',
        0
    )

    AddTriggerEx(
        'ph_skillunaffected',
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
