local Pyre = require('pyrecore')
local Tracker = {
    AreaIndex = 0,
    FightIndex = 0,
    Session = {},
    FightTracker = {
        Current = {},
        History = {}
    },
    AreaTracker = {
        Current = {},
        History = {}
    }
}

Tracker.Commands = {
    {name = 'resetsession', description = 'Reset the current session tracking data', callback = 'OnResetSessionData'},
    {name = 'resetfight', description = 'Reset the current fight data', callback = 'OnResetFightData'},
    {name = 'resetfights', description = 'Reset the all fight data', callback = 'OnResetFightsData'},
    {name = 'resetarea', description = 'Reset the current area tracking data', callback = 'OnResetAreaData'},
    {name = 'resetareas', description = 'Reset all area tracking data', callback = 'OnResetAreasData'},
    {name = 'reportfight', description = 'Report the current fight', callback = 'OnReportFightData'},
    {name = 'reportarea', description = 'Report the current area', callback = 'OnReportAreaData'},
    {name = 'reportareac', description = 'Report the current area', callback = 'OnReportAreaCData'},
    {name = 'reportsessionxp', description = 'Report the current session xp rates', callback = 'OnReportSessionXPData'},
    {
        name = 'reportsessionxpc',
        description = 'Report the current session xp rates while in combat',
        callback = 'OnReportSessionXPCData'
    },
    {name = 'reportsessiondps', description = 'Report the current session dps', callback = 'OnReportSessionDPSData'}
}

Tracker.Settings = {
    {
        name = 'fightsize',
        description = 'How many previous fights to keep data on',
        value = tonumber(GetVariable('fightsize')) or 10,
        setValue = function(setting, val)
            local parsed = tonumber(val) or 0
            setting.value = parsed
            SetVariable('fightsize', value)
        end
    },
    {
        name = 'areasize',
        description = 'How many previous areas to keep data on',
        value = tonumber(GetVariable('areasize')) or 10,
        setValue = function(setting, val)
            local parsed = tonumber(val) or 0
            setting.value = parsed
            SetVariable('areasize', value)
        end
    },
    {
        name = 'sessionsize',
        description = 'How fights to limit the session to',
        value = tonumber(GetVariable('sessionsize')) or 100000,
        setValue = function(setting, val)
            local parsed = tonumber(val) or 100000
            setting.value = parsed
            SetVariable('sessionsize', value)
        end
    }
}

Tracker.Factory = {
    NewSession = function()
        return {
            StartTime = socket.gettime(),
            Fights = {}
        }
    end,
    NewFight = function()
        return {
            Area = Pyre.Status.Zone,
            StartTime = socket.gettime(),
            Duration = 0,
            Enemies = 0,
            XP = {Normal = 0, Rare = 0, Bonus = 0},
            Damage = {Enemy = 0, Player = 0}
        }
    end,
    EndFight = function(fight)
        if (fight == nil or fight.Area == nil or fight.StartTime == nil) then
            return
        end
        fight.Duration = socket.gettime() - fight.StartTime
        return fight
    end,
    NewArea = function()
        return {
            Area = Pyre.Status.Zone,
            StartTime = socket.gettime(),
            Duration = 0,
            Fights = {}
        }
    end,
    EndArea = function(area)
        if (area == nil or area.Area == nil or area.StartTime == nil) then
            return
        end
        area.Duration = socket.gettime() - area.StartTime
        return area
    end,
    NewAreaFightData = function(fight)
        local endtime = socket.gettime()
        local duration = endtime - fight.StartTime

        -- calculate the dps here
        local playerDps = Pyre.Round((fight.Damage.Player / duration), 1)
        local enemyDps = Pyre.Round((fight.Damage.Enemy / duration), 1)

        local fightData = {
            XP = {Normal = fight.XP.Normal, Rare = fight.XP.Rare, Bonus = fight.XP.Bonus},
            Damage = {
                Enemy = fight.Damage.Enemy,
                Player = fight.Damage.Player,
                EnemyDps = enemyDps,
                PlayerDps = playerDps
            },
            StartTime = fight.StartTime,
            EndTime = endtime,
            Duration = duration
        }
        return fightData
    end,
    CreateSessionSummary = function(session)
        local exp =
            Pyre.Sum(
            session.Fights,
            function(f)
                return f.XP.Normal + f.XP.Rare + f.XP.Bonus
            end
        ) or 0

        local normalExp =
            Pyre.Sum(
            session.Fights,
            function(f)
                return f.XP.Normal
            end
        ) or 0
        local rareExp =
            Pyre.Sum(
            session.Fights,
            function(f)
                return f.XP.Rare
            end
        ) or 0
        local bonusExp =
            Pyre.Sum(
            session.Fights,
            function(f)
                return f.XP.Bonus
            end
        ) or 0
        local playerDamage =
            Pyre.Sum(
            session.Fights,
            function(f)
                return f.Damage.Player
            end
        ) or 0

        local enemyDamage =
            Pyre.Sum(
            session.Fights,
            function(f)
                return f.Damage.Enemy
            end
        ) or 0

        local combatDuration =
            Pyre.Round(
            Pyre.Sum(
                session.Fights,
                function(f)
                    return f.Duration
                end
            ),
            1
        )

        local duration = Pyre.Round((socket.gettime() - session.StartTime), 1)

        if (duration < combatDuration) then
            duration = combatDuration
        end

        local summary = {
            StartDate = os.date('%H:%M:%S - %d/%m/%Y', session.StartTime),
            EndDate = os.date('%H:%M:%S - %d/%m/%Y', socket.gettime()),
            PlayerDamage = Pyre.Round(playerDamage, 1),
            EnemyDamage = Pyre.Round(enemyDamage, 1),
            Experience = Pyre.Round(exp, 1),
            NormalExperience = Pyre.Round(normalExp, 1),
            RareExperience = Pyre.Round(rareExp, 1),
            BonusExperience = Pyre.Round(bonusExp, 1),
            Normal = {
                Duration = duration,
                ExpPerMinute = Pyre.Round((((exp or 0) / duration) * 60) or 0, 1),
                ExpPerSecond = Pyre.Round(((exp or 0) / duration) or 0, 1),
                NormalPerMinute = Pyre.Round((((normalExp or 0) / duration) * 60) or 0, 1),
                NormalPerSecond = Pyre.Round(((normalExp or 0) / duration) or 0, 1),
                RarePerMinute = Pyre.Round((((rareExp or 0) / duration) * 60) or 0, 1),
                RarePerSecond = Pyre.Round(((rareExp or 0) / duration) or 0, 1),
                BonusPerMinute = Pyre.Round((((bonusExp or 0) / duration) * 60) or 0, 1),
                BonusPerSecond = Pyre.Round(((bonusExp or 0) / duration) or 0, 1),
                PlayerDps = Pyre.Round((playerDamage / duration) or 0, 1),
                EnemyDps = Pyre.Round((enemyDamage / duration) or 0, 1)
            },
            Combat = {
                Duration = combatDuration,
                ExpPerMinute = Pyre.Round((((exp or 0) / combatDuration) * 60) or 0, 1),
                ExpPerSecond = Pyre.Round(((exp or 0) / combatDuration) or 0, 1),
                NormalPerMinute = Pyre.Round((((normalExp or 0) / combatDuration) * 60) or 0, 1),
                NormalPerSecond = Pyre.Round(((normalExp or 0) / combatDuration) or 0, 1),
                RarePerMinute = Pyre.Round((((rareExp or 0) / combatDuration) * 60) or 0, 1),
                RarePerSecond = Pyre.Round(((rareExp or 0) / combatDuration) or 0, 1),
                BonusPerMinute = Pyre.Round((((bonusExp or 0) / combatDuration) * 60) or 0, 1),
                BonusPerSecond = Pyre.Round(((bonusExp or 0) / combatDuration) or 0, 1),
                PlayerDps = Pyre.Round((playerDamage / combatDuration) or 0, 1),
                EnemyDps = Pyre.Round((enemyDamage / combatDuration) or 0, 1)
            },
            Souls = Pyre.Sum(
                session.Fights,
                function(f)
                    return f.Enemies
                end
            )
        }
        return summary
    end,
    CreateAreaSummary = function(area)
        local summary = {}

        return summary
    end
}

function Tracker.FeatureStart()
    table.insert(Pyre.Events[Pyre.Event.StateChanged], TrackerOnStateChanged)
    table.insert(Pyre.Events[Pyre.Event.ZoneChanged], TrackerOnZoneChanged)

    -- create an alias for each of our Tracker.Commands
    Pyre.Each(
        Tracker.Commands,
        function(cmd)
            if (cmd.callback ~= nil) then
                AddAlias(
                    'ph_trackercmd_' .. cmd.name,
                    '^pyre tracker ' .. cmd.name .. '$',
                    '',
                    alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
                    cmd.callback
                )
            end
        end
    )

    AddTriggerEx(
        'ph_tracker_exp',
        "^You receive ([0-9]+)\\+?([0-9]+)?\\+?([0-9]+)? ?('rare kill'|bonus)? experience (points|bonus|).*$",
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnTrackerExperienceGain',
        0
    )

    AddTriggerEx(
        'ph_tracker_playerdmg',
        '^(\\*)?\\[.*\\]?\\s?Your (\\w*) -?<?(.*)>?-? (.*)! \\[(.*)\\]$',
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnTrackerPlayerDamage',
        0
    )

    AddTriggerEx(
        'ph_tracker_enemydmg',
        "^(\\*)?\\[.*\\]?\\s?(.*)'s (\\w*) (.*) you[!|\\.] \\[(.*)\\]$",
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnTrackerEnemyDamage',
        0
    )
end

function OnTrackerExperienceGain(name, line, wildcards)
    if (Tracker.FightTracker.Current.Area == nil) then
        return
    end

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

    Pyre.Switch(xpType) {
        [1] = function()
            Tracker.FightTracker.Current.XP.Normal =
                Tracker.FightTracker.Current.XP.Normal + (main + additional1 + additional2)
            Tracker.FightTracker.Current.Enemies = Tracker.FightTracker.Current.Enemies + 1
        end,
        [2] = function()
            Tracker.FightTracker.Current.XP.Rare =
                Tracker.FightTracker.Current.XP.Rare + (main + additional1 + additional2)
        end,
        [3] = function()
            Tracker.FightTracker.Current.XP.Bonus =
                Tracker.FightTracker.Current.XP.Bonus + (main + additional1 + additional2)
        end
    }
end

function OnTrackerPlayerDamage(name, line, wildcards)
    local damage = tonumber(wildcards[5]) or 0
    Tracker.FightTracker.Current.Damage.Player = Tracker.FightTracker.Current.Damage.Player + damage
end

function OnTrackerEnemyDamage(name, line, wildcards)
    local damage = tonumber(wildcards[5]) or 0
    Tracker.FightTracker.Current.Damage.Enemy = Tracker.FightTracker.Current.Damage.Enemy + damage
end

function Tracker.FeatureSettingHandle(settingName, p1, p2, p3, p4)
    if (settingName ~= 'tracker') then
        return
    end
    for _, setting in ipairs(Tracker.Settings) do
        if (string.lower(setting.name) == string.lower(p1)) then
            setting:setValue(p2)
            Pyre.Log(settingName .. ' ' .. setting.name .. ' : ' .. setting.value)
        end
    end
end

function Tracker.FeatureHelp()
    local logTable = {}

    Pyre.Each(
        Tracker.Commands,
        function(command)
            table.insert(
                logTable,
                {
                    {
                        Value = command.name,
                        Tooltip = command.description,
                        Color = 'orange',
                        Action = 'pyre tracker ' .. command.name
                    },
                    {Value = ''}
                }
            )
        end
    )

    -- spacer
    table.insert(logTable, {{Value = ''}})

    Pyre.Each(
        Tracker.Settings,
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

    Pyre.LogTable(
        'Feature: Tracker ',
        'teal',
        {'cmd/setting', 'value'},
        logTable,
        1,
        true,
        'usage: pyre tracker <cmd> or pyre set tracker <setting> <value>'
    )
end

function Tracker.ArchiveCurrentFight()
    -- if the fight has anything useful then we archive it
    if ((Tracker.FightTracker.Current.Area or '') ~= '') then
        table.insert(Tracker.FightTracker.History, Tracker.FightTracker.Current)
        Tracker.FightTracker.Current = Tracker.Factory.EndFight(Tracker.FightTracker.Current)

        -- create a new area on the first fight to start the timer after activity
        if (Tracker.AreaTracker.Current.Fights == nil or #Tracker.AreaTracker.Current.Fights == 0) then
            Tracker.AreaTracker.Current = Tracker.Factory.NewArea()
            Tracker.AreaTracker.Current.StartTime = Tracker.FightTracker.Current.StartTime
        end
        -- add area data

        table.insert(Tracker.AreaTracker.Current.Fights, Tracker.Factory.NewAreaFightData(Tracker.FightTracker.Current))

        -- add session data
        if (Tracker.Session.Fights == nil) then
            Tracker.Session = Tracker.Factory.NewSession()
        end
        table.insert(Tracker.Session.Fights, Tracker.FightTracker.Current)

        Tracker.FightTracker.Current = {}
    end
end

function Tracker.ArchiveCurrentArea()
    if (Tracker.AreaTracker.Current ~= {}) then
        table.insert(Tracker.AreaTracker.History, Tracker.AreaTracker.Current)
        Tracker.AreaTracker.Current = {}
    end
end

function TrackerOnStateChanged(stateObject)
    if (stateObject.New == Pyre.States.COMBAT) then
        Tracker.FightTracker.Current = Tracker.Factory.NewFight()
    else
        Tracker.ArchiveCurrentFight()
    end
end

function TrackerOnZoneChanged(changeInfo)
    Tracker.ArchiveCurrentArea()
end

function OnResetFightData()
    Pyre.Log('Resetting fight data', Pyre.LogLevel.INFO)
    if (Pyre.Status.State == Pyre.States.COMBAT) then
        Tracker.FightTracker.Current = Tracker.Factory.NewFight()
    else
        Tracker.FightTracker.Current = {}
    end
end

function OnResetFightsData()
    Pyre.Log('Resetting all fight data', Pyre.LogLevel.INFO)
    OnResetFightData()
    Tracker.FightTracker.History = {}
end

function OnResetAreaData()
    Pyre.Log('Resetting area data', Pyre.LogLevel.INFO)
    if (Pyre.Status.State == Pyre.States.COMBAT) then
        Tracker.AreaTracker.Current = Tracker.Factory.NewArea()
    else
        Tracker.AreaTracker.Current = {}
    end
end

function OnResetAreasData()
    Pyre.Log('Resetting all area data', Pyre.LogLevel.INFO)
    OnResetAreaData()
    Tracker.AreaTracker.History = {}
end

function OnResetSessionData()
    Pyre.Log('Resetting all session data', Pyre.LogLevel.INFO)
    Tracker.Session = Tracker.Factory.NewSession()
end

function OnReportFightData()
    Pyre.Log('OnReportFightData', Pyre.LogLevel.DEBUG)

    local fight = Tracker.FightTracker.Current

    if (fight.Area == nil) then
        Tracker.FightIndex = 1
    end

    if (Tracker.FightIndex > 0) then
        fight = Tracker.FightTracker.History[Tracker.FightIndex]
        if (fight == nil) then
            Tracker.FightIndex = 0
            fight = Tracker.FightTracker.Current
        end
    end

    if (fight.Area == nil) then
        Tracker.FightIndex = 0
        Pyre.Log('no current or last fight to report', Pyre.LogLevel.ERROR)
        return
    end
    Pyre.ReportToChannel('Fight', '..fight data')
end

function OnReportAreaData()
    Pyre.Log('OnReportAreaData', Pyre.LogLevel.DEBUG)

    local area = Tracker.AreaTracker.Current

    if (area.Area == nil) then
        Tracker.AreaIndex = 1
    end

    if (Tracker.AreaIndex > 0) then
        area = Tracker.AreaTracker.History[Tracker.AreaIndex]
        if (area == nil) then
            Tracker.AreaIndex = 0
            area = Tracker.AreaTracker.Current
        end
    end

    if (area.Area == nil) then
        Tracker.AreaIndex = 0
        Pyre.Log('no current or last area to report', Pyre.LogLevel.ERROR)
        return
    end

    Pyre.ReportToChannel('Area Report', 'Duration: ' .. Pyre.SecondsToClock(area.Duration))
end

function OnReportSessionXPData()
    Pyre.Log('Reporting session xp', Pyre.LogLevel.DEBUG)

    local session = Tracker.Session
    if (session.StartTime == nil) then
        Pyre.Log('No session data to report', Pyre.LogLevel.ERROR)
        return
    end

    local summary = Tracker.Factory.CreateSessionSummary(session)

    local normal = summary.Normal
    local combat = summary.Combat

    Pyre.ReportToChannel('Session XP Report', 'Duration: ' .. Pyre.SecondsToClock(normal.Duration))
    Pyre.ReportToChannel(
        'TOTAL',
        'XP: ' ..
            summary.Experience ..
                ' Normal: ' ..
                    summary.NormalExperience ..
                        ' Rare: ' .. summary.RareExperience .. ' Bonus: ' .. summary.BonusExperience
    )

    Pyre.ReportToChannel(
        'PERMIN',
        'Normal: ' .. normal.NormalPerMinute .. ' Rare: ' .. normal.RarePerMinute .. ' Bonus: ' .. normal.BonusPerMinute
    )

    Pyre.ReportToChannel(
        'PERSEC',
        'Normal: ' .. normal.NormalPerSecond .. ' Rare: ' .. normal.RarePerSecond .. ' Bonus: ' .. normal.BonusPerSecond
    )
end

function OnReportSessionXPCData()
    Pyre.Log('Reporting session xp', Pyre.LogLevel.DEBUG)

    local session = Tracker.Session
    if (session.StartTime == nil) then
        Pyre.Log('No session data to report', Pyre.LogLevel.ERROR)
        return
    end

    local summary = Tracker.Factory.CreateSessionSummary(session)

    local normal = summary.Normal
    local combat = summary.Combat

    Pyre.ReportToChannel(
        'Session XP Combat Report',
        'Duration: ' .. Pyre.SecondsToClock(normal.Duration) .. ' Combat: ' .. Pyre.SecondsToClock(combat.Duration)
    )
    Pyre.ReportToChannel(
        'TOTAL',
        'XP: ' ..
            summary.Experience ..
                ' Normal: ' ..
                    summary.NormalExperience ..
                        ' Rare: ' .. summary.RareExperience .. ' Bonus: ' .. summary.BonusExperience
    )

    Pyre.ReportToChannel(
        'PERMIN',
        'Normal: ' .. combat.NormalPerMinute .. ' Rare: ' .. combat.RarePerMinute .. ' Bonus: ' .. combat.BonusPerMinute
    )

    Pyre.ReportToChannel(
        'PERSEC',
        'Normal: ' .. combat.NormalPerSecond .. ' Rare: ' .. combat.RarePerSecond .. ' Bonus: ' .. combat.BonusPerSecond
    )
end

function OnReportSessionDPSData()
    Pyre.Log('Reporting session dps', Pyre.LogLevel.DEBUG)

    local session = Tracker.Session
    if (session.StartTime == nil) then
        Pyre.Log('No session data to report', Pyre.LogLevel.ERROR)
        return
    end

    local summary = Tracker.Factory.CreateSessionSummary(session)

    local normal = summary.Normal
    local combat = summary.Combat

    Pyre.ReportToChannel(
        'Session DPS Report',
        'Duration: ' .. Pyre.SecondsToClock(normal.Duration) .. ' Combat: ' .. Pyre.SecondsToClock(combat.Duration)
    )
    Pyre.ReportToChannel(
        'Player ',
        'Damage: ' .. summary.PlayerDamage .. ' DPS: ' .. normal.PlayerDps .. ' DPCS: ' .. combat.PlayerDps
    )
    Pyre.ReportToChannel(
        'Enemies',
        'Damage: ' .. summary.EnemyDamage .. ' DPS: ' .. normal.EnemyDps .. ' DPCS: ' .. combat.EnemyDps
    )
end

return Tracker
