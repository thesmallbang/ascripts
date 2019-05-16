local Pyre = require('pyrecore')
local Tracker = {
    EnemyCounter = 0,
    EnemyCounterLastReset = 0,
    AreaIndex = 0,
    FightIndex = 0,
    Session = {},
    FightTracker = {
        Current = {}
        -- stopped tracking history its kind of redundant with the work already done with session
    },
    AreaTracker = {
        Current = {},
        History = {}
    }
}

Tracker.Commands = {
    {name = 'setarea', description = 'Nav to specific area', callback = 'OnTrackerSetAreaIndex'},
    {name = 'firstarea', description = 'Nav to current area', callback = 'OnTrackerSetAreaIndexFirst'},
    {name = 'newerarea', description = 'Nav to newer area', callback = 'OnTrackerSetAreaIndexNewer'},
    {name = 'olderarea', description = 'Nav to older area', callback = 'OnTrackerSetAreaIndexOlder'},
    {name = 'lastarea', description = 'Nav to oldest area', callback = 'OnTrackerSetAreaIndexLast'},
    {name = 'setfight', description = 'Nav to specific fight', callback = 'OnTrackerSetFightIndex'},
    {name = 'firstfight', description = 'Nav to current fight', callback = 'OnTrackerSetFightIndexFirst'},
    {name = 'newerfight', description = 'Nav to newer fight', callback = 'OnTrackerSetFightIndexNewer'},
    {name = 'olderfight', description = 'Nav to older fight', callback = 'OnTrackerSetFightIndexOlder'},
    {name = 'lastfight', description = 'Nav to oldest fight', callback = 'OnTrackerSetFightIndexLast'},
    {
        name = 'resetfights',
        description = 'Reset the all fight data (same as resetsession)',
        callback = 'OnResetSessionData'
    },
    {
        name = 'resetsession',
        description = 'Reset the all session data (same as resetfights)',
        callback = 'OnResetSessionData'
    },
    {name = 'resetfight', description = 'Reset the current fight data', callback = 'OnResetFightData'},
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
        name = 'areasize',
        description = 'How many previous areas to keep data on',
        value = tonumber(GetVariable('areasize')) or 10,
        setValue = function(setting, val)
            local parsed = tonumber(val) or 0
            setting.value = parsed
            SetVariable('areasize', setting.value)
        end
    },
    {
        name = 'sessionsize',
        description = 'How fights to limit the session to',
        value = tonumber(GetVariable('sessionsize')) or 100000,
        setValue = function(setting, val)
            local parsed = tonumber(val) or 100000
            setting.value = parsed
            SetVariable('sessionsize', setting.value)
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
            EndTime = nil,
            Duration = 0,
            Enemies = 0,
            XP = {Normal = 0, Rare = 0, Bonus = 0},
            Damage = {Enemy = 0, Player = 0}
        }
    end,
    EndFight = function(fight)
        if (fight == nil or fight.Area == nil or fight.StartTime == nil) then
            return fight
        end
        fight.EndTime = socket.gettime()
        fight.Duration = fight.EndTime - fight.StartTime
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
        area.EndTime = socket.gettime()
        area.Duration = area.EndTime - area.StartTime
        return area
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

        local fights =
            Pyre.Sum(
            session.Fights,
            function(f)
                return 1
            end
        ) or 0

        local duration = Pyre.Round((socket.gettime() - session.StartTime), 1)

        local fightSummary = Tracker.Factory.CreateFightSummary(Tracker.GetFightByIndex(0))

        if (fightSummary ~= nil) then
            exp = exp + (fightSummary.Experience or 0)
            normalExp = normalExp + (fightSummary.NormalExperience or 0)
            rareExp = normalExp + (fightSummary.RareExperience or 0)
            bonusExp = normalExp + (fightSummary.BonusExperience or 0)
            combatDuration = combatDuration + (fightSummary.Normal.Duration)
            duration = duration + (fightSummary.Normal.Duration)
            playerDamage = playerDamage + (fightSummary.PlayerDamage or 0)
            enemyDamage = enemyDamage + (fightSummary.PlayerDamage or 0)
            fights = fights + 1
        end

        local souls =
            Pyre.Sum(
            session.Fights,
            function(f)
                return f.Enemies
            end
        ) or 0
        local fightsForMath = 1

        if (fights > 0) then
            fightsForMath = fights
        end

        local soulsPerFight = Pyre.Round((souls / fightsForMath), 1)

        if (duration < combatDuration) then
            duration = combatDuration
        end

        if (duration == 0) then
            duration = 1
        end

        if (combatDuration == 0) then
            combatDuration = 1
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
            AverageSoulsPerFight = soulsPerFight,
            Fights = fights,
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
            Souls = souls
        }

        return summary
    end,
    CreateAreaSummary = function(area)
        local exp =
            Pyre.Sum(
            area.Fights,
            function(f)
                return f.XP.Normal + f.XP.Rare + f.XP.Bonus
            end
        ) or 0

        local normalExp =
            Pyre.Sum(
            area.Fights,
            function(f)
                return f.XP.Normal
            end
        ) or 0
        local rareExp =
            Pyre.Sum(
            area.Fights,
            function(f)
                return f.XP.Rare
            end
        ) or 0
        local bonusExp =
            Pyre.Sum(
            area.Fights,
            function(f)
                return f.XP.Bonus
            end
        ) or 0
        local playerDamage =
            Pyre.Sum(
            area.Fights,
            function(f)
                return f.Damage.Player
            end
        ) or 0

        local enemyDamage =
            Pyre.Sum(
            area.Fights,
            function(f)
                return f.Damage.Enemy
            end
        ) or 0

        local combatDuration =
            Pyre.Round(
            Pyre.Sum(
                area.Fights,
                function(f)
                    return f.Duration
                end
            ),
            1
        )

        local fights =
            Pyre.Sum(
            area.Fights,
            function(f)
                return 1
            end
        ) or 0

        local duration = Pyre.Round(((area.EndTime or socket.gettime()) - area.StartTime), 1)

        local fightSummary = Tracker.Factory.CreateFightSummary(Tracker.GetFightByIndex(0))

        if (fightSummary ~= nil) then
            exp = exp + (fightSummary.Experience or 0)
            normalExp = normalExp + (fightSummary.NormalExperience or 0)
            rareExp = normalExp + (fightSummary.RareExperience or 0)
            bonusExp = normalExp + (fightSummary.BonusExperience or 0)
            combatDuration = combatDuration + (fightSummary.Normal.Duration)
            duration = duration + (fightSummary.Normal.Duration)
            playerDamage = playerDamage + (fightSummary.PlayerDamage or 0)
            enemyDamage = enemyDamage + (fightSummary.PlayerDamage or 0)
            fights = fights + 1
        end

        local souls =
            Pyre.Sum(
            area.Fights,
            function(f)
                return f.Enemies
            end
        ) or 0
        local fightsForMath = 1

        if (fights > 0) then
            fightsForMath = fights
        end

        local soulsPerFight = Pyre.Round((souls / fightsForMath), 1)

        if (duration < combatDuration) then
            duration = combatDuration
        end

        if (duration == 0) then
            duration = 1
        end

        if (combatDuration == 0) then
            combatDuration = 1
        end

        local summary = {
            Area = string.upper(area.Area or ''),
            StartDate = os.date('%H:%M:%S - %d/%m/%Y', area.StartTime),
            EndDate = os.date('%H:%M:%S - %d/%m/%Y', socket.gettime()),
            PlayerDamage = Pyre.Round(playerDamage, 1),
            EnemyDamage = Pyre.Round(enemyDamage, 1),
            Experience = Pyre.Round(exp, 1),
            NormalExperience = Pyre.Round(normalExp, 1),
            RareExperience = Pyre.Round(rareExp, 1),
            BonusExperience = Pyre.Round(bonusExp, 1),
            AverageSoulsPerFight = soulsPerFight,
            Fights = fights,
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
            Souls = souls
        }
        return summary
    end,
    CreateFightSummary = function(fight)
        if (fight == nil or fight.XP == nil) then
            return nil
        end

        local exp = (fight.XP.Normal + fight.XP.Rare + fight.XP.Bonus) or 0

        local normalExp = fight.XP.Normal or 0
        local rareExp = fight.XP.Rare or 0
        local bonusExp = fight.XP.Bonus or 0
        local playerDamage = fight.Damage.Player or 0
        local enemyDamage = fight.Damage.Enemy or 0
        local duration = (fight.EndTime or socket.gettime()) - (fight.StartTime or 0)

        local souls = fight.Enemies or 0
        duration = Pyre.Round(duration, 1)

        if (duration == 0) then
            duration = 0.1
        end

        local summary = {
            StartDate = os.date('%H:%M:%S - %d/%m/%Y', fight.StartTime),
            EndDate = os.date('%H:%M:%S - %d/%m/%Y', fight.EndTime or socket.gettime()),
            PlayerDamage = Pyre.Round(playerDamage, 1),
            EnemyDamage = Pyre.Round(enemyDamage, 1),
            Experience = Pyre.Round(exp, 1),
            NormalExperience = Pyre.Round(normalExp, 1),
            RareExperience = Pyre.Round(rareExp, 1),
            BonusExperience = Pyre.Round(bonusExp, 1),
            AverageSoulsPerFight = soulsPerFight,
            Fights = fights,
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
            Souls = souls
        }
        return summary
    end
}

local started = false
function Tracker.FeatureStart()
    if (started == true) then
        return
    end

    started = true
    table.insert(Pyre.Events[Pyre.Event.StateChanged], TrackerOnStateChanged)
    table.insert(Pyre.Events[Pyre.Event.ZoneChanged], TrackerOnZoneChanged)
    Tracker.Session = Tracker.Factory.NewSession()
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
        'ph_trackerpdmg',
        '^(\\*)?\\[.*\\]?\\s?Your (\\w*) -?<?(.*)>?-? (.*)! \\[(.*)\\]$',
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.KeepEvaluating + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnTrackerPlayerDamage',
        0
    )

    AddTriggerEx(
        'ph_tracker_edmg',
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
    local element = wildcards[2]

    if (Tracker.EnemyCounterLastReset < socket.gettime() - 1.5) then
        Tracker.EnemyCounter = 0
        Tracker.EnemyCounterLastReset = socket.gettime()
    end

    if (element == 'swing') then
        Tracker.EnemyCounter = Tracker.EnemyCounter + 1
    end

    if (Tracker.FightTracker.Current ~= nil and Tracker.FightTracker.Current.Damage ~= nil) then
        Tracker.FightTracker.Current.Damage.Player = (Tracker.FightTracker.Current.Damage.Player or 0) + damage
    end
end

function OnTrackerEnemyDamage(name, line, wildcards)
    local damage = tonumber(wildcards[5]) or 0
    if (Tracker.FightTracker.Current ~= nil and Tracker.FightTracker.Current.Damage ~= nil) then
        Tracker.FightTracker.Current.Damage.Enemy = (Tracker.FightTracker.Current.Damage.Enemy or 0) + damage
    end
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
                    {Value = command.description, Tooltip = command.description}
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

function Tracker.GetFightByIndex(i)
    if (i == 0) then
        return Tracker.FightTracker.Current
    end
    local fight = Tracker.Session.Fights[i]
    if (fight == nil) then
        return Tracker.FightTracker.Current
    end
    return fight
end

function Tracker.GetAreaByIndex(i)
    if (i == 0) then
        return Tracker.AreaTracker.Current
    end

    local area = Tracker.AreaTracker.History[i]
    if (area == nil) then
        return Tracker.AreaTracker.Current
    end
    return area
end

function Tracker.ArchiveCurrentFight()
    Tracker.EnemyCounter = 0
    -- if the fight has anything useful then we archive it
    if ((Tracker.FightTracker.Current.Area or '') ~= '') then
        Tracker.FightTracker.Current = Tracker.Factory.EndFight(Tracker.FightTracker.Current)

        if
            not (Tracker.FightTracker.Current.XP.Normal == 0 and Tracker.FightTracker.Current.Damage.Enemy == 0 and
                Tracker.FightTracker.Current.Damage.Player == 0)
         then
            -- add area data

            if (Tracker.AreaTracker.Current ~= nil and Tracker.AreaTracker.Current.Fights ~= nil) then
                table.insert(Tracker.AreaTracker.Current.Fights, 1, Tracker.FightTracker.Current)
            end

            -- add session data
            table.insert(Tracker.Session.Fights, 1, Tracker.FightTracker.Current)

            if (Tracker.FightIndex > 0) then
                Tracker.FightIndex = Tracker.FightIndex + 1
                if (Tracker.FightIndex > #Tracker.Session.Fights) then
                    Tracker.FightIndex = #Tracker.Session.Fights
                end
            end

            local maxSessionFights = Pyre.GetSettingValue(Tracker.Settings, 'sessionsize')
            if (#Tracker.Session.Fights > maxSessionFights) then
                -- trim our session data
                local difference = (#Tracker.Session.Fights - maxSessionFights)
                if (difference > 0) then
                    Tracker.Session.Fights =
                        Pyre.Filter(
                        Tracker.Session.Fights,
                        function()
                            return true
                        end,
                        maxSessionFights
                    )
                end
            end
        end

        Tracker.FightTracker.Current = {}
    end
end

function Tracker.ArchiveCurrentArea()
    if
        (Tracker.AreaTracker.Current ~= nil and Tracker.AreaTracker.Current.Area ~= nil and
            Tracker.AreaTracker.Current.Area ~= '' and
            #Tracker.AreaTracker.Current.Fights > 0)
     then
        Tracker.AreaTracker.Current = Tracker.Factory.EndArea(Tracker.AreaTracker.Current)
        table.insert(Tracker.AreaTracker.History, 1, Tracker.AreaTracker.Current)

        if (Tracker.AreaIndex > 0) then
            Tracker.AreaIndex = Tracker.AreaIndex + 1
            if (Tracker.AreaIndex > #Tracker.AreaTracker.History) then
                Tracker.AreaIndex = #Tracker.AreaTracker.History
            end
        end

        local maxSize = Pyre.GetSettingValue(Tracker.Settings, 'areasize')
        local difference = (#Tracker.AreaTracker.History - maxSize)
        if (difference > 0) then
            Tracker.AreaTracker.History =
                Pyre.Filter(
                Tracker.AreaTracker.History,
                function()
                    return true
                end,
                maxSize
            )
        end
    end

    Tracker.AreaTracker.Current = Tracker.Factory.NewArea()
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

function OnTrackerSetFightIndex()
    local i = Pyre.AskIfEmpty(nil, 'Fight Index', Tracker.FightIndex)
    if (i ~= nil and i ~= '') then
        Tracker.FightIndex = tonumber(i) or 0
        if (Tracker.FightIndex > #Tracker.Session.Fights) then
            Tracker.FightIndex = #Tracker.Session.Fights
        end
        if (Tracker.FightIndex < 0) then
            Tracker.FightIndex = 0
        end
        Pyre.Log('Fight index set to ' .. (Tracker.FightIndex or 0) .. ' of ' .. (#Tracker.Session.Fights or 0))
    end
end

function OnTrackerSetFightIndexFirst()
    Tracker.FightIndex = 0
    Pyre.Log('Fight index set to ' .. (Tracker.FightIndex or 0) .. ' of ' .. (#Tracker.Session.Fights or 0))
end

function OnTrackerSetFightIndexNewer()
    Tracker.FightIndex = Tracker.FightIndex - 1
    if (Tracker.FightIndex < 0) then
        Tracker.FightIndex = 0
    end
    Pyre.Log('Fight index set to ' .. (Tracker.FightIndex or 0) .. ' of ' .. (#Tracker.Session.Fights or 0))
end

function OnTrackerSetFightIndexOlder()
    Tracker.FightIndex = Tracker.FightIndex + 1
    if (Tracker.FightIndex > #Tracker.Session.Fights) then
        Tracker.FightIndex = #Tracker.Session.Fights
    end
    Pyre.Log('Fight index set to ' .. (Tracker.FightIndex or 0) .. ' of ' .. (#Tracker.Session.Fights or 0))
end

function OnTrackerSetFightIndexLast()
    Tracker.FightIndex = #Tracker.Session.Fights or 0
    Pyre.Log('Fight index set to ' .. (Tracker.FightIndex or 0) .. ' of ' .. (#Tracker.Session.Fights or 0))
end

function OnTrackerSetAreaIndex()
    local i = Pyre.AskIfEmpty(nil, 'Area Index', Tracker.AreaIndex)
    if (i ~= nil and i ~= '') then
        Tracker.AreaIndex = tonumber(i) or 0
        if (Tracker.AreaIndex > #Tracker.AreaTracker.History) then
            Tracker.AreaIndex = #Tracker.AreaTracker.History
        end
        if (Tracker.AreaIndex < 0) then
            Tracker.AreaIndex = 0
        end
        Pyre.Log('Area index set to ' .. (Tracker.AreaIndex or 0) .. ' of ' .. (#Tracker.AreaTracker.History or 0))
    end
end

function OnTrackerSetAreaIndexFirst()
    Tracker.AreaIndex = 0
    Pyre.Log('Area index set to ' .. (Tracker.AreaIndex or 0) .. ' of ' .. (#Tracker.AreaTracker.History or 0))
end

function OnTrackerSetAreaIndexNewer()
    Tracker.AreaIndex = Tracker.AreaIndex - 1
    if (Tracker.AreaIndex < 0) then
        Tracker.AreaIndex = 0
    end
    Pyre.Log('Area index set to ' .. (Tracker.AreaIndex or 0) .. ' of ' .. (#Tracker.AreaTracker.History or 0))
end

function OnTrackerSetAreaIndexOlder()
    Tracker.AreaIndex = Tracker.AreaIndex + 1
    if (Tracker.AreaIndex > #Tracker.AreaTracker.History) then
        Tracker.AreaIndex = #Tracker.AreaTracker.History
    end
    Pyre.Log('Area index set to ' .. (Tracker.AreaIndex or 0) .. ' of ' .. (#Tracker.AreaTracker.History or 0))
end

function OnTrackerSetAreaIndexLast()
    Tracker.AreaIndex = #Tracker.AreaTracker.History or 0
    Pyre.Log('Area index set to ' .. (Tracker.AreaIndex or 0) .. ' of ' .. (#Tracker.AreaTracker.History or 0))
end

function OnResetFightData()
    Pyre.Log('Resetting fight data', Pyre.LogLevel.INFO)
    Tracker.FightTracker.Current = Tracker.Factory.NewFight()
end

function OnResetAreaData()
    Pyre.Log('Resetting area data', Pyre.LogLevel.INFO)
    Tracker.AreaTracker.Current = Tracker.Factory.NewArea()
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
