local Pyre = require('pyrecore')
require('socket')

Pyre.Log('skills.lua loaded', Pyre.LogLevel.DEBUG)

-- ------------------------
--  THESE ARE USING socket.gettime() instead of os.time() for millisecond accuracy
--  LastAttack / AttackQueue.QueuedTime
-- ------------------------

local isafk = false
local lastRoomChanged = socket.gettime()
local windowTab = tonumber(GetVariable('xp_mon_tab')) or 1
local lastAreaDelayed = 0
local areaLastDuration = 0

SkillFeature = {
    SkillFail = nil,
    LastSkill = nil,
    LastAttack = 0,
    AttackQueue = {},
    LastUnqueue = 0,
    LastSkillExecute = 0,
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
                (skill.LastAttempt == nil or os.difftime(socket.gettime(), skill.LastAttempt) > 4))
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

Factory = {
    NewFight = function()
        return {
            Area = 'Loading',
            StartTime = socket.gettime(),
            EndTime = 0,
            XpMessages = {}, -- { Value, Type (Normal, Rare, Double) }
            DmgMessages = {}, -- { Value , SourceType (Player,Enemy) , IsCritical,  }
            HealMessages = {} -- { Value , SourceType (Player,Quaff) }
        }
    end,
    NewArea = function()
        return {
            Area = 'Loading',
            StartTime = socket.gettime(),
            EndTime = 0,
            XP = {}, -- { Type = (Normal, Rare, Bonus), Value = 0, Date = socket.gettime(), Duration = 0 },
            Damage = {} -- { Source = (Player, Enemy), Duration = 0, Value = 0, bestDmg = 'bash'  }
        }
    end,
    NewAreaXp = function(type, value, startTime, stopTime)
        return {Type = type, Value = value, Duration = (stopTime - startTime)}
    end,
    NewAreaDamage = function(source, value, startTime, stopTime)
        return {Source = source, Value = value, Duration = (stopTime - startTime)}
    end
}

-- a "fight" is considered the time we go into COMBAT until IDLE. There can be many enemies in that time
FightTracker = {
    CurrentFight = Factory.NewFight(),
    LastFight = Factory.NewFight()
}

AreaTracker = Factory.NewArea()

AreaHistory = {}

local adjustingAlignment = false

function SkillFeature.FeatureStart()
    SkillsSetup()
end

function SkillFeature.FeatureStop()
    HideFightTrackerWindow()
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
                    ClearFailedPots()
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
    CheckForAFK()
    ShowFightTrackerWindow()
    --
    --  ALLOWED TO RUN WHILE AFK
    --
    CheckSkillExpirations()
    CheckClanSkills()
    CleanExpiredAttackQueue()

    if (isafk) then
        return
    end

    --
    -- NOT ALLOWED TO RUN WHILE AFK
    --

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

function ClearFailedPots()
    Quaff.Hp.Failed = false
    Quaff.Mp.Failed = false
    Quaff.Mv.Failed = false
    Pyre.Log('Quaff potion failures have been reset')
end

function CheckForQuaff()
    if ((Quaff.Enabled == 0) or (isafk == true)) then
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

function CheckForAFK()
    if (isafk == true) then
        return
    end

    local afkTime = socket.gettime() - (3 * 60) -- 3 minutes = afk
    isafk = ((lastRoomChanged <= afkTime) and (Pyre.Status.State == Pyre.States.IDLE))

    if (isafk == true) then
        Pyre.Log('AFK - Some features have been disabled. Change rooms to enable them again.')
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

        if (item == nil) then
            return
        end
    end

    -- our pending skill hasnt been cleared via expiration or detection
    local lastId = SkillFeature.LastSkillUniqueId
    if (item.uid == lastId) then
        return
    end

    -- check that we are not execeting too quickly for combat types
    local waitTime = 2.5
    if (item.Skill.SkillType == Pyre.SkillType.CombatInitiate) then
        waitTime = waitTime + 2
    end
    if
        (((item.Skill.SkillType == Pyre.SkillType.CombatInitiate) or (item.Skill.SkillType == Pyre.SkillType.CombatMove)) and
            ((socket.gettime() - SkillFeature.LastSkillExecute) < waitTime))
     then
        Pyre.Log('Queue Wait ' .. Pyre.TableLength(SkillFeature.AttackQueue), Pyre.LogLevel.DEBUG)
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
    SkillFeature.LastSkillExecute = socket.gettime()
end

function CheckSkillExpirations()
    if (Pyre.Settings.SkillExpirationWarn < 1) then
        return
    end

    for _, skill in ipairs(ClanSkills) do
        if not (skill.Expiration == nil) then
            Pyre.Log('CheckSkillExpiration: ' .. skill.Name, Pyre.LogLevel.VERBOSE)

            local expiringSeconds = os.difftime(skill.Expiration, socket.gettime())
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

function IAmNotAFK()
    isafk = false
    lastRoomChanged = socket.gettime()
    Pyre.Log('AFK mode reset manually')
end

-- -----------------------------------------------
--  Pyre Fight Tracker Window
-- -----------------------------------------------
local xpMonWindow = 'Pyre_XP_Monitor1'
local handleHeight = 22
local xpMonWindowMoving = false
local windowLayer = tonumber(GetVariable('win_' .. xpMonWindow .. '_layer')) or 100

function ShowFightTrackerWindow()
    if (xpMonWindowMoving == true) then
        return
    end
    WindowCreate(
        xpMonWindow,
        tonumber(GetVariable('win_' .. xpMonWindow .. '_x')) or 50,
        tonumber(GetVariable('win_' .. xpMonWindow .. '_y')) or 50,
        tonumber(GetVariable('win_' .. xpMonWindow .. '_x2')) or 400,
        tonumber(GetVariable('win_' .. xpMonWindow .. '_y2')) or 200,
        0,
        miniwin.create_absolute_location,
        ColourNameToRGB('white')
    ) -- create window

    WindowSetZOrder(xpMonWindow, windowLayer)

    WindowShow(xpMonWindow, true)

    -- Move Window
    WindowAddHotspot(
        xpMonWindow,
        'movewindowhs',
        0,
        0,
        WindowInfo(xpMonWindow, 3),
        handleHeight, -- rectangle
        '',
        '',
        'FightTrackerMouseDown',
        '',
        '',
        'Drag to move window', -- tooltip text
        10, -- hand cursor
        0
    ) -- flags
    WindowDragHandler(xpMonWindow, 'movewindowhs', 'FightTrackerMove', 'FightTrackerMoveRelease', 0)

    -- Primary Window Border
    WindowCircleOp(
        xpMonWindow,
        3,
        0,
        0,
        WindowInfo(xpMonWindow, 3),
        WindowInfo(xpMonWindow, 4),
        ColourNameToRGB('teal'),
        0,
        0,
        ColourNameToRGB('transparent'),
        0,
        0,
        0
    )

    -- Window Title Seperator Line
    WindowLine(xpMonWindow, 1, handleHeight, WindowInfo(xpMonWindow, 3), handleHeight, ColourNameToRGB('teal'), 0, 1)

    WindowFont(xpMonWindow, 'l', 'Trebuchet MS', 12, false, false, false, false)
    WindowFont(xpMonWindow, 'm', 'Trebuchet MS', 10, false, false, false, false)
    WindowFont(xpMonWindow, 'mb', 'Trebuchet MS', 10, true, false, false, false)
    WindowFont(xpMonWindow, 's', 'Trebuchet MS', 8, false, false, false, false)
    WindowFont(xpMonWindow, 'sb', 'Trebuchet MS', 8, true, false, false, false)
    WindowFont(xpMonWindow, 'su', 'Trebuchet MS', 8, false, false, true, false)

    WindowDrawTextLine_Line(xpMonWindow, 1, 'Pyre Helper', 'm')
    WindowDrawTextLine_Line(
        xpMonWindow,
        2,
        'Attack Queue: ' .. #SkillFeature.AttackQueue,
        's',
        nil,
        WindowInfo(xpMonWindow, 3) - 120
    )
    WindowDrawTextLine_Line(xpMonWindow, 3, 'Clear Queue', 'su', nil, WindowInfo(xpMonWindow, 3) - 80)
    -- Clear Queue Button
    local top = 2 + ((4 - 1) * 15)
    WindowAddHotspot(
        xpMonWindow,
        'winclearqueue',
        315,
        50,
        390,
        65, -- rectangle
        '',
        '',
        'ResetAttackQueue',
        '',
        '',
        'Clear attack queue', -- tooltip text
        1, -- hand cursor
        0
    ) -- flags

    if (isafk) then
        WindowAddHotspot(
            xpMonWindow,
            'notafk',
            295,
            90,
            390,
            105, -- rectangle
            '',
            '',
            'IAmNotAFK',
            '',
            '',
            '', -- tooltip text
            1, -- hand cursor
            0
        ) -- flags
        WindowDrawTextLine_Line(xpMonWindow, 5, 'Clear AFK', 'su', nil, WindowInfo(xpMonWindow, 3) - 80)
    end
    if (Quaff.Hp.Failed == true or Quaff.Mp.Failed == true or Quaff.Mv.Failed == true) then
        WindowAddHotspot(
            xpMonWindow,
            'clearfailedpots',
            295,
            71,
            390,
            85, -- rectangle
            '',
            '',
            'ClearFailedPots',
            '',
            '',
            'Clear potion failures so they attempt to quaff again', -- tooltip text
            1, -- hand cursor
            0
        ) -- flags
        WindowDrawTextLine_Line(xpMonWindow, 4, 'Clear Pots', 'su', nil, WindowInfo(xpMonWindow, 3) - 80)
    end

    -- draw tabs
    local tabs = {
        [0] = 'Fights',
        [1] = 'Areas'
    }

    local tabForeColor = 'red'
    local tabBackColor = 'white'
    local tabSelectedBackColor = 'teal'

    WindowDrawTextLine_Line(xpMonWindow, 1, '(Viewing ' .. tabs[windowTab] .. ')', 'm', nil, 100)

    if (windowTab == 0) then
        local duration = 1
        local totalExp = 0
        local enemies = 0
        local dpsIn = 0
        local dpsOut = 0

        -- calculate some current fight stats
        local fight = FightTracker.CurrentFight
        if ((fight == nil) or not (fight.EndTime or -1) == 0) then
            fight = FightTracker.LastFight
        end

        if (not (fight == nill) and not ((fight.Area or '') == '')) then
            local endTime = fight.EndTime
            if (endTime == 0) then
                endTime = socket.gettime()
            end

            duration = endTime - (fight.StartTime or 0)

            Pyre.Each(
                fight.XpMessages,
                function(xp)
                    totalExp = totalExp + xp.Value
                    if (xp.Type == 1) then
                        enemies = enemies + 1
                    end
                end
            )

            Pyre.Each(
                fight.DmgMessages,
                function(dmgRecord)
                    if (dmgRecord.SourceType == 1) then
                        dpsOut = dpsOut + dmgRecord.Value
                    end
                    if (dmgRecord.SourceType == 2) then
                        dpsIn = dpsIn + dmgRecord.Value
                    end
                end
            )
        end

        WindowDrawTextLine_Line(xpMonWindow, 2, 'Xp: ' .. totalExp, 's')
        WindowDrawTextLine_Line(
            xpMonWindow,
            2,
            'Duration: ' .. Pyre.SecondsToClock(duration),
            's',
            nil,
            WindowInfo(xpMonWindow, 3) / 3
        )

        WindowDrawTextLine_Line(xpMonWindow, 3, 'DPS: ' .. tostring(Pyre.Round((dpsOut / duration), 1)), 's')

        WindowDrawTextLine_Line(
            xpMonWindow,
            3,
            'EnemyDPS: ' .. tostring(Pyre.Round((dpsIn / duration), 1)),
            's',
            nil,
            WindowInfo(xpMonWindow, 3) / 3
        )

        WindowDrawTextLine_Line(xpMonWindow, 4, 'Killed: ' .. enemies, 's')
    end

    if (windowTab == 1) then
        WindowDrawTextLine_Line(xpMonWindow, 2, string.upper(AreaTracker.Area or ''), 'm', ColourNameToRGB('teal'))

        local fightCount =
            Pyre.Sum(
            AreaTracker.Damage,
            function(v)
                if (v.Source == 1) then
                    return 1
                else
                    return 0
                end
            end
        )

        local fightDuration =
            Pyre.Sum(
            AreaTracker.Damage,
            function(v)
                if (v.Source == 1) then
                    return v.Duration
                else
                    return 0
                end
            end
        ) or 1

        local areaDuration = (socket.gettime() - AreaTracker.StartTime)

        if (lastAreaDelayed < (socket.gettime() - 3)) then
            areaLastDuration = areaDuration
            lastAreaDelayed = socket.gettime()
        end

        local areaDurationSlowChange = areaLastDuration

        local fpm = ((fightCount / areaDurationSlowChange) * 60) or 0
        local fpcm = ((fightCount / fightDuration) * 60) or 0

        WindowDrawTextLine_Line(xpMonWindow, 3, 'In Area : ' .. Pyre.SecondsToClock(areaDuration), 's')
        WindowDrawTextLine_Line(xpMonWindow, 3, 'Combat  : ' .. Pyre.SecondsToClock(fightDuration), 's', nil, 150)

        WindowDrawTextLine_Line(xpMonWindow, 4, 'Fights  : ' .. fightCount, 's')
        WindowDrawTextLine_Line(xpMonWindow, 4, 'FPM     : ' .. Pyre.Round(fpm or 0, 1), 's', nil, 100)
        WindowDrawTextLine_Line(xpMonWindow, 4, 'FPCM    : ' .. Pyre.Round(fpcm or 0, 1), 's', nil, 200)

        local exp =
            Pyre.Sum(
            AreaTracker.XP,
            function(v)
                return v.Value
            end
        )
        local normalexp =
            Pyre.Sum(
            AreaTracker.XP,
            function(v)
                if (v.Type == 1) then
                    return v.Value
                else
                    return 0
                end
            end
        )
        local rareexp =
            Pyre.Sum(
            AreaTracker.XP,
            function(v)
                if (v.Type == 2) then
                    return v.Value
                else
                    return 0
                end
            end
        )
        local bonusexp =
            Pyre.Sum(
            AreaTracker.XP,
            function(v)
                if (v.Type == 3) then
                    return v.Value
                else
                    return 0
                end
            end
        )

        local epm = (((exp or 0) / areaDurationSlowChange) * 60) or 0
        local epcm = (((exp or 0) / fightDuration) * 60) or 0

        local npm = (((normalexp or 0) / areaDurationSlowChange) * 60) or 0
        local npcm = (((normalexp or 0) / fightDuration) * 60) or 0

        local rpm = (((rareexp or 0) / areaDurationSlowChange) * 60) or 0
        local rpcm = (((rareexp or 0) / fightDuration) * 60) or 0

        WindowDrawTextLine_Line(xpMonWindow, 5, 'EXP      : ' .. exp, 's')
        WindowDrawTextLine_Line(xpMonWindow, 5, 'EPM     : ' .. Pyre.Round(epm or 0, 1), 's', nil, 100)
        WindowDrawTextLine_Line(xpMonWindow, 5, 'EPCM    : ' .. Pyre.Round(epcm or 0, 1), 's', nil, 200)

        WindowDrawTextLine_Line(xpMonWindow, 6, 'Normal : ' .. normalexp, 's')
        WindowDrawTextLine_Line(xpMonWindow, 6, 'NPM    : ' .. Pyre.Round(npm, 1), 's', nil, 100)
        WindowDrawTextLine_Line(xpMonWindow, 6, 'NPCM   : ' .. Pyre.Round(npcm, 1), 's', nil, 200)

        WindowDrawTextLine_Line(xpMonWindow, 7, 'Rare     : ' .. rareexp, 's')
        WindowDrawTextLine_Line(xpMonWindow, 7, 'RPM    : ' .. Pyre.Round(rpm, 1), 's', nil, 100)
        WindowDrawTextLine_Line(xpMonWindow, 7, 'RPCM    : ' .. Pyre.Round(rpcm, 1), 's', nil, 200)
    end

    -- options Context MEnu hotspot
    WindowAddHotspot(
        xpMonWindow,
        'contextmenu',
        WindowInfo(xpMonWindow, 3) - handleHeight,
        0,
        WindowInfo(xpMonWindow, 3),
        handleHeight,
        '',
        '',
        'ShowContextMenu',
        '',
        '',
        'Show Options', -- tooltip text
        1, -- hand cursor
        miniwin.hotspot_got_rh_mouse
    ) -- flags
    WindowDrawTextLine_Line(xpMonWindow, 1, 'O', 'su', nil, WindowInfo(xpMonWindow, 3) - handleHeight)

    --WindowText(xpMonWindow, 'f', 'Pyre Helper', 5, 1, 0, 0, ColourNameToRGB('teal'), false)
end

function ShowContextMenu(flags, hotspot_id)
    local nameAndCheckedTab = function(name)
        local checked = ''
        if (name == 'Fights' and windowTab == 0) then
            checked = '+'
        end
        if (name == 'Areas' and windowTab == 1) then
            checked = '+'
        end
        return checked .. name
    end

    result =
        WindowMenu(
        xpMonWindow,
        WindowInfo(xpMonWindow, 14), -- x
        WindowInfo(xpMonWindow, 15), -- y
        '>View|' ..
            nameAndCheckedTab('Fights') ..
                '|' ..
                    nameAndCheckedTab('Areas') ..
                        '|<|>Change Layer (' ..
                            windowLayer .. ') |Top (1000)|Layer Up (+10)|Layer Down (-10)|Bottom (0)|<'
    )

    if (result == 'Areas') then
        windowTab = 1
        SetVariable('xp_mon_tab', windowTab)
    end
    if (result == 'Fights') then
        windowTab = 0
        SetVariable('xp_mon_tab', windowTab)
    end

    if (result) == 'Top (1000)' then
        windowLayer = 1000
    end
    if result == 'Layer Up (+10)' then
        windowLayer = windowLayer + 10
    end -- if
    if result == 'Layer Down (-10)' then
        windowLayer = windowLayer - 10
    end -- if
    if (result) == 'Bottom (0)' then
        windowLayer = 0
    end
    WindowSetZOrder(xpMonWindow, windowLayer)
    SetVariable('win_' .. xpMonWindow .. '_layer', windowLayer)
end

function WindowDrawTextLine_Line(win, line, text, fontid, colour, left)
    left = left or 10
    local top = 3 + ((line - 1) * 20)
    if (line > 1) then
        top = top + 5
    end

    colour = colour or ColourNameToRGB('white')
    fontid = fontid or 's'

    WindowText(win, fontid, text, left, top, 0, 0, colour)
end -- Display_Line

function HideFightTrackerWindow()
    WindowDelete(xpMonWindow)
end

local FightTrackerWindowStartX = 0
local FightTrackerWindowStartY = 0

function FightTrackerMouseDown(flags, hotspot_id)
    FightTrackerWindowStartX, FightTrackerWindowStartY = WindowInfo(xpMonWindow, 14), WindowInfo(xpMonWindow, 15)
end

function FightTrackerMoveRelease(flags, hotspot_id)
    SetVariable('win_' .. xpMonWindow .. '_x', WindowInfo(xpMonWindow, 10))
    SetVariable('win_' .. xpMonWindow .. '_y', WindowInfo(xpMonWindow, 11))
    xpMonWindowMoving = false
end -- dragrelease

function FightTrackerMove(flags, hotspot_id)
    local posx, posy = WindowInfo(xpMonWindow, 17), WindowInfo(xpMonWindow, 18)
    xpMonWindowMoving = true
    if posx < 0 or posx > GetInfo(281) or posy < 0 or posy > GetInfo(280) then
        check(SetCursor(11)) -- X cursor
    else
        check(SetCursor(10)) -- hand cursor
        -- move the window to the new location
        WindowPosition(xpMonWindow, posx - FightTrackerWindowStartX, posy - FightTrackerWindowStartY, 0, 2)
    end -- if

    -- change the mouse cursor shape appropriately
end -- dragmove

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
        SkillFeature.AttackDequeue(skill)
    end
end

function OnYouDamageEnemy(name, line, wildcards)
    -- verify the enemy is even correct
    -- if (not (string.lower(wildcards[3]) == string.lower(Pyre.Status.Enemy))) then
    --     return
    -- end

    local isCritical = (wildcards[1] == '*') or false
    local damageType = wildcards[2] or 'unknown'
    local damage = tonumber(wildcards[5]) or 0

    if not (FightTracker.CurrentFight == nil) then
        table.insert(
            FightTracker.CurrentFight.DmgMessages,
            {Value = damage, SourceType = 1, DamageType = damageType, IsCritical = isCritical}
        )
    end

    local skill = Pyre.GetClassSkillByName(damageType)
    if (skill == nil) then
        return
    end
    SkillFeature.AttackDequeue(skill)
end

function OnEnemyDamageYou(name, line, wildcards)
    local isCritical = (wildcards[1] == '*') or false
    local damageType = wildcards[3] or 'unknown'
    local damage = tonumber(wildcards[5]) or 0

    if not (FightTracker.CurrentFight == nil) then
        table.insert(
            FightTracker.CurrentFight.DmgMessages,
            {Value = damage, SourceType = 2, DamageType = damageType, IsCritical = isCritical}
        )
    end
end

function OnBasicExperienceGain(name, line, wildcards)
    local main = tonumber(wildcards[1]) or 0
    local additional1 = tonumber(wildcards[2]) or 0
    local additional2 = tonumber(wildcards[3]) or 0
    local isRare = (wildcards[4] == "'rare kill'") or false
    local isBonus = (wildcards[4] == 'bonus')
    local xpType = 1
    if (isRare) then
        xpType = 2
    end
    if (isBonus) then
        xpType = 3
    end

    if not (FightTracker.CurrentFight == nil) then
        table.insert(FightTracker.CurrentFight.XpMessages, {Value = (main + additional1 + additional2), Type = xpType})
    end
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

    if ((Pyre.Status.IsLeader == false) and (Pyre.Settings.OnlyLeaderInitiate == 1)) then
        Pyre.Log('Initiation blocked. You are not the group leader', Pyre.LogLevel.INFO)
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

        table.insert(
            SkillFeature.AttackQueue,
            {
                Skill = bestSkill,
                Expiration = socket.gettime() + expiration,
                Execute = function(s, qitem)
                    if ((Pyre.Status.IsLeader == false) and (Pyre.Settings.OnlyLeaderInitiate == 1)) then
                        Pyre.Log('Initiation cancelled. You are not the group leader', Pyre.LogLevel.INFO)
                        return
                    end

                    -- if we quaffed recently we will add a slight delay avoid queueing an attak when a heal may we required again soon
                    if ((socket.gettime() - 1.5) < SkillFeature.LastQuaff) then
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
                        qitem.Expiration = socket.gettime() + ((Pyre.TableLength(SkillFeature.AttackQueue) * 15) + 5)
                        table.insert(SkillFeature.AttackQueue, qitem)
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
                        qitem.Expiration = socket.gettime() + ((Pyre.TableLength(SkillFeature.AttackQueue) * 15) + 5)
                        table.insert(SkillFeature.AttackQueue, qitem)
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
                        qitem.Expiration = socket.gettime() + ((Pyre.TableLength(SkillFeature.AttackQueue) * 15) + 5)
                        table.insert(SkillFeature.AttackQueue, qitem)
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

        Pyre.Log(bestSkill.Name .. ' queued [' .. Pyre.TableLength(SkillFeature.AttackQueue) .. ']')

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

function ResetAttackQueue()
    Pyre.Log('Resetting attack queue', Pyre.LogLevel.VERBOSE)
    SkillFeature.SkillFail = nil
    SkillFeature.LastSkill = nil
    SkillFeature.AttackQueue = {}
end

function ReportLastFight()
    local fight = FightTracker.LastFight

    if (fight == nil) then
        return
    end

    local duration = fight.EndTime - fight.StartTime
    local totalExp = 0
    local enemies = 0
    local dpsIn = 0
    local dpsOut = 0

    Pyre.Each(
        fight.XpMessages,
        function(xp)
            totalExp = totalExp + xp.Value
            if (xp.Type == 1) then
                enemies = enemies + 1
            end
        end
    )

    Pyre.Each(
        fight.DmgMessages,
        function(dmgRecord)
            if (dmgRecord.SourceType == 1) then
                dpsOut = dpsOut + dmgRecord.Value
            end
            if (dmgRecord.SourceType == 2) then
                dpsIn = dpsIn + dmgRecord.Value
            end
        end
    )

    Pyre.Log('You fought ' .. enemies .. ' enemies in ' .. duration .. ' seconds for ' .. totalExp .. ' experience.')
    Pyre.Log(
        'DPS - You: ' ..
            tostring(Pyre.Round(dpsOut / duration), 1) .. ' Enemy: ' .. tostring(Pyre.Round(dpsIn / duration), 1)
    )
end

function OnStateChange(stateObject)
    if (stateObject.New == Pyre.States.IDLE) then
        -- remove all except for pending potions
        ResetAttackQueue()
        CheckForQuaff()

        if
            (FightTracker.CurrentFight ~= nil and
                (#FightTracker.CurrentFight.XpMessages > 1 or #FightTracker.CurrentFight.DmgMessages > 1))
         then
            FightTracker.CurrentFight.EndTime = socket.gettime()

            FightTracker.LastFight = FightTracker.CurrentFight

            -- store the area data
            local normalxp =
                Pyre.Sum(
                FightTracker.LastFight.XpMessages,
                function(v)
                    if (v.Type == 1) then
                        return v.Value
                    end
                    return 0
                end
            )
            local rarexp =
                Pyre.Sum(
                FightTracker.LastFight.XpMessages,
                function(v)
                    if (v.Type == 2) then
                        return v.Value
                    end
                    return 0
                end
            )
            local bonusxp =
                Pyre.Sum(
                FightTracker.LastFight.XpMessages,
                function(v)
                    if (v.Type == 3) then
                        return v.Value
                    end
                    return 0
                end
            )

            if (normalxp > 0) then
                -- store our xp gains
                table.insert(
                    AreaTracker.XP,
                    Factory.NewAreaXp(1, normalxp, FightTracker.LastFight.StartTime, FightTracker.LastFight.EndTime)
                )
            end

            if (rarexp > 0) then
                table.insert(
                    AreaTracker.XP,
                    Factory.NewAreaXp(2, rarexp, FightTracker.LastFight.StartTime, FightTracker.LastFight.EndTime)
                )
            end
            if (bonusxp > 0) then
                table.insert(
                    AreaTracker.XP,
                    Factory.NewAreaXp(3, bonusxp, FightTracker.LastFight.StartTime, FightTracker.LastFight.EndTime)
                )
            end

            local playerDps =
                Pyre.Sum(
                FightTracker.LastFight.DmgMessages,
                function(v)
                    if (v.SourceType == 1) then
                        return v.Value
                    else
                        return 0
                    end
                end
            )

            local enemyDps =
                Pyre.Sum(
                FightTracker.LastFight.DmgMessages,
                function(v)
                    if (v.SourceType == 2) then
                        return v.Value
                    else
                        return 0
                    end
                end
            )

            if (playerDps > 0) then
                table.insert(
                    AreaTracker.Damage,
                    Factory.NewAreaDamage(
                        1,
                        playerDps,
                        FightTracker.LastFight.StartTime,
                        FightTracker.LastFight.EndTime
                    )
                )
            end
            if (enemyDps > 0) then
                table.insert(
                    AreaTracker.Damage,
                    Factory.NewAreaDamage(2, enemyDps, FightTracker.LastFight.StartTime, FightTracker.LastFight.EndTime)
                )
            end

            -- report last fight
            -- Pyre.Log(Pyre.ToString(FightTracker.LastFight))
            -- ReportLastFight()

            -- clear current fight so nothing is added somehow
            FightTracker.CurrentFight = nil
        end
    end

    if (stateObject.New == Pyre.States.COMBAT) then
        FightTracker.CurrentFight = Factory.NewFight()
        FightTracker.CurrentFight.StartTime = socket.gettime()
        FightTracker.CurrentFight.Area = Pyre.Status.Zone
    end
end

function OnRoomChanged(changeInfo)
    lastRoomChanged = socket.gettime()
    ResetAttackQueue()

    if (isafk == true) then
        isafk = false
        Pyre.Log('AFK OFF - Full features were enabled again')
    end
end

function OnZoneChanged(changeInfo)
    if (AreaTracker ~= nil) then
        AreaTracker.EndTime = socket.gettime()
    end
    -- check to store area data
    if (AreaTracker ~= nil and ((#AreaTracker.XP > 0) or #AreaTracker.Damage > 0)) then
        -- story area history
        table.insert(AreaHistory, AreaTracker)

        -- dont keep more than 10 at a time
        if (#AreaHistory > 10) then
            local howManyToRemove = (#AreaHistory - 10)
            AreaHistory =
                Pyre.Except(
                AreaHistory,
                function()
                    return true
                end,
                howManyToRemove
            )
        end
    end

    AreaTracker = Factory.NewArea()
    AreaTracker.Area = Pyre.Status.Zone
    AreaTracker.StartTime = socket.gettime()
end

function SkillsSetup()
    Pyre.Log('SkillsSetup (alias+triggers)', Pyre.LogLevel.DEBUG)
    -- subscribe to some core events
    table.insert(Pyre.Events[Pyre.Event.StateChanged], OnStateChange)
    table.insert(Pyre.Events[Pyre.Event.RoomChanged], OnRoomChanged)
    table.insert(Pyre.Events[Pyre.Event.ZoneChanged], OnZoneChanged)

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
        '^(\\*)?\\[.*\\]?\\s?Your (\\w*) -?<?(.*)>?-? (.*)! \\[(.*)\\]$',
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnYouDamageEnemy',
        0
    )

    AddTriggerEx(
        'ph_enemyattack',
        "^(\\*)?\\[.*\\]?\\s?(.*)'s (\\w*) (.*) you[!|\\.] \\[(.*)\\]$",
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnEnemyDamageYou',
        0
    )

    AddTriggerEx(
        'ph_basicexp',
        "^You receive ([0-9]+)\\+?([0-9]+)?\\+?([0-9]+)? ?('rare kill'|bonus)? experience (points|bonus|).*$",
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnBasicExperienceGain',
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
