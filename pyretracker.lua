local Core = require('pyrecore')

Tracker = {
    Config = {
        Events = {
            {
                Type = Core.Event.StateChanged,
                Callback = function(o)
                    Tracker.OnStateChanged(o)
                end
            },
            {
                Type = Core.Event.ZoneChanged,
                Callback = function(o)
                    Tracker.OnZoneChanged(o)
                end
            },
            {
                Type = Core.Event.AFKChanged,
                Callback = function(o)
                    Tracker.OnAFKChanged(o)
                end
            }
        },
        Commands = {
            {
                Name = 'setarea',
                Description = 'switch the area for view/reporting',
                Callback = function(line, wildcards)
                    Tracker.SetArea(line, wildcards)
                end
            },
            {
                Name = 'firstarea',
                Description = 'switch to the first area for view/reporting',
                Callback = function(line, wildcards)
                    Tracker.SetFirstArea()
                end
            },
            {
                Name = 'newerarea',
                Description = 'switch to a newer area for view/reporting',
                Callback = function(line, wildcards)
                    Tracker.SetNewerArea()
                end
            },
            {
                Name = 'olderarea',
                Description = 'switch to the first area for view/reporting',
                Callback = function(line, wildcards)
                    Tracker.SetOlderArea()
                end
            },
            {
                Name = 'lastarea',
                Description = 'switch to the first area for view/reporting',
                Callback = function(line, wildcards)
                    Tracker.SetLastArea()
                end
            },
            {
                Name = 'resetarea',
                Description = 'reset the current area tracking',
                Callback = function(line, wildcards)
                    Tracker.ResetCurrentArea()
                end
            },
            {
                Name = 'resetareas',
                Description = 'reset all areas',
                Callback = function(line, wildcards)
                    Tracker.ResetAreas()
                end
            },
            {
                Name = 'resetsession',
                Description = 'reset all fight data for the session',
                Callback = function(line, wildcards)
                    Tracker.ResetSession()
                end
            },
            {
                Name = 'resetfight',
                Description = 'reset the current fight data',
                Callback = function(line, wildcards)
                    Tracker.ResetCurrentFight()
                end
            },
            {
                Name = 'setfight',
                Description = 'switch the fight for view/reporting',
                Callback = function(line, wildcards)
                    Tracker.SetFight(line, wildcards)
                end
            },
            {
                Name = 'firstfight',
                Description = 'switch to the first fight for view/reporting',
                Callback = function(line, wildcards)
                    Tracker.SetFirstFight()
                end
            },
            {
                Name = 'newerfight',
                Description = 'switch to a newer fight for view/reporting',
                Callback = function(line, wildcards)
                    Tracker.SetNewerFight()
                end
            },
            {
                Name = 'olderfight',
                Description = 'switch to the first fight for view/reporting',
                Callback = function(line, wildcards)
                    Tracker.SetOlderFight()
                end
            },
            {
                Name = 'lastfight',
                Description = 'switch to the first fight for view/reporting',
                Callback = function(line, wildcards)
                    Tracker.SetLastFight()
                end
            }
        },
        Settings = {
            {
                Name = 'areasize',
                Description = 'How many previous areas to keep data on',
                Value = nil,
                Min = 1,
                Max = 1000000,
                Default = 10
            },
            {
                Name = 'sessionsize',
                Description = 'How fights to limit the session to',
                Value = nil,
                Min = 1,
                Max = 1000000,
                Default = 100000
            }
        },
        Triggers = {
            {
                Name = 'ExperienceGain',
                Match = "You receive ([0-9]+)\\+?([0-9]+)?\\+?([0-9]+)? ?('rare kill'|bonus)? experience (points|bonus|).*",
                Callback = function(line, wildcards)
                    Tracker.OnExperienceGain(line, wildcards)
                end
            },
            {
                Name = 'PlayerDidDamage',
                Match = '(\\*)?\\[.*\\]?\\s?Your (\\w*) -?<?(.*)>?-? (.*)! \\[(.*)\\]',
                Callback = function(line, wildcards)
                    Tracker.OnPlayerDidDamage(line, wildcards)
                end
            },
            {
                Name = 'EnemyDidDamage',
                Match = "(\\*)?\\[.*\\]?\\s?(.*)'s (\\w*) (.*) you[!|\\.] \\[(.*)\\]",
                Callback = function(line, wildcards)
                    Tracker.OnEnemyDidDamage(line, wildcards)
                end
            }
        }
    },
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

Tracker.Factory = {
    NewSession = function()
        return {
            StartTime = socket.gettime(),
            Fights = {}
        }
    end,
    NewFight = function()
        return {
            Area = Core.Status.Zone,
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
            Area = Core.Status.Zone,
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
            Core.Sum(
            session.Fights,
            function(f)
                return f.XP.Normal + f.XP.Rare + f.XP.Bonus
            end
        ) or 0

        local normalExp =
            Core.Sum(
            session.Fights,
            function(f)
                return f.XP.Normal
            end
        ) or 0
        local rareExp =
            Core.Sum(
            session.Fights,
            function(f)
                return f.XP.Rare
            end
        ) or 0
        local bonusExp =
            Core.Sum(
            session.Fights,
            function(f)
                return f.XP.Bonus
            end
        ) or 0
        local playerDamage =
            Core.Sum(
            session.Fights,
            function(f)
                return f.Damage.Player
            end
        ) or 0

        local enemyDamage =
            Core.Sum(
            session.Fights,
            function(f)
                return f.Damage.Enemy
            end
        ) or 0

        local combatDuration =
            Core.Round(
            Core.Sum(
                session.Fights,
                function(f)
                    return f.Duration
                end
            ),
            1
        )

        local fights =
            Core.Sum(
            session.Fights,
            function(f)
                return 1
            end
        ) or 0

        local duration = Core.Round((socket.gettime() - session.StartTime), 1)

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
            Core.Sum(
            session.Fights,
            function(f)
                return f.Enemies
            end
        ) or 0
        local fightsForMath = 1

        if (fights > 0) then
            fightsForMath = fights
        end

        local soulsPerFight = Core.Round((souls / fightsForMath), 1)

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
            PlayerDamage = Core.Round(playerDamage, 1),
            EnemyDamage = Core.Round(enemyDamage, 1),
            Experience = Core.Round(exp, 1),
            NormalExperience = Core.Round(normalExp, 1),
            RareExperience = Core.Round(rareExp, 1),
            BonusExperience = Core.Round(bonusExp, 1),
            AverageSoulsPerFight = soulsPerFight,
            Fights = fights,
            Normal = {
                Duration = duration,
                ExpPerMinute = Core.Round((((exp or 0) / duration) * 60) or 0, 1),
                ExpPerSecond = Core.Round(((exp or 0) / duration) or 0, 1),
                NormalPerMinute = Core.Round((((normalExp or 0) / duration) * 60) or 0, 1),
                NormalPerSecond = Core.Round(((normalExp or 0) / duration) or 0, 1),
                RarePerMinute = Core.Round((((rareExp or 0) / duration) * 60) or 0, 1),
                RarePerSecond = Core.Round(((rareExp or 0) / duration) or 0, 1),
                BonusPerMinute = Core.Round((((bonusExp or 0) / duration) * 60) or 0, 1),
                BonusPerSecond = Core.Round(((bonusExp or 0) / duration) or 0, 1),
                PlayerDps = Core.Round((playerDamage / duration) or 0, 1),
                EnemyDps = Core.Round((enemyDamage / duration) or 0, 1)
            },
            Combat = {
                Duration = combatDuration,
                ExpPerMinute = Core.Round((((exp or 0) / combatDuration) * 60) or 0, 1),
                ExpPerSecond = Core.Round(((exp or 0) / combatDuration) or 0, 1),
                NormalPerMinute = Core.Round((((normalExp or 0) / combatDuration) * 60) or 0, 1),
                NormalPerSecond = Core.Round(((normalExp or 0) / combatDuration) or 0, 1),
                RarePerMinute = Core.Round((((rareExp or 0) / combatDuration) * 60) or 0, 1),
                RarePerSecond = Core.Round(((rareExp or 0) / combatDuration) or 0, 1),
                BonusPerMinute = Core.Round((((bonusExp or 0) / combatDuration) * 60) or 0, 1),
                BonusPerSecond = Core.Round(((bonusExp or 0) / combatDuration) or 0, 1),
                PlayerDps = Core.Round((playerDamage / combatDuration) or 0, 1),
                EnemyDps = Core.Round((enemyDamage / combatDuration) or 0, 1)
            },
            Souls = souls
        }

        return summary
    end,
    CreateAreaSummary = function(area)
        if (area == nil) then
            return nil
        end

        local exp =
            Core.Sum(
            area.Fights,
            function(f)
                return f.XP.Normal + f.XP.Rare + f.XP.Bonus
            end
        ) or 0

        local normalExp =
            Core.Sum(
            area.Fights,
            function(f)
                return f.XP.Normal
            end
        ) or 0
        local rareExp =
            Core.Sum(
            area.Fights,
            function(f)
                return f.XP.Rare
            end
        ) or 0
        local bonusExp =
            Core.Sum(
            area.Fights,
            function(f)
                return f.XP.Bonus
            end
        ) or 0
        local playerDamage =
            Core.Sum(
            area.Fights,
            function(f)
                return f.Damage.Player
            end
        ) or 0

        local enemyDamage =
            Core.Sum(
            area.Fights,
            function(f)
                return f.Damage.Enemy
            end
        ) or 0

        local combatDuration =
            Core.Round(
            Core.Sum(
                area.Fights,
                function(f)
                    return f.Duration
                end
            ),
            1
        )

        local fights =
            Core.Sum(
            area.Fights,
            function(f)
                return 1
            end
        ) or 0

        local duration = Core.Round(((area.EndTime or socket.gettime()) - area.StartTime), 1)

        local fightSummary = Tracker.Factory.CreateFightSummary(Tracker.GetFightByIndex(0))

        if (fightSummary ~= nil) then
            exp = exp + (fightSummary.Experience or 0)
            normalExp = normalExp + (fightSummary.NormalExperience or 0)
            rareExp = rareExp + (fightSummary.RareExperience or 0)
            bonusExp = bonusExp + (fightSummary.BonusExperience or 0)
            combatDuration = combatDuration + (fightSummary.Normal.Duration)
            duration = duration + (fightSummary.Normal.Duration)
            playerDamage = playerDamage + (fightSummary.PlayerDamage or 0)
            enemyDamage = enemyDamage + (fightSummary.PlayerDamage or 0)
            fights = fights + 1
        end

        local souls =
            Core.Sum(
            area.Fights,
            function(f)
                return f.Enemies
            end
        ) or 0
        local fightsForMath = 1

        if (fights > 0) then
            fightsForMath = fights
        end

        local soulsPerFight = Core.Round((souls / fightsForMath), 1)

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
            PlayerDamage = Core.Round(playerDamage, 1),
            EnemyDamage = Core.Round(enemyDamage, 1),
            Experience = Core.Round(exp, 1),
            NormalExperience = Core.Round(normalExp, 1),
            RareExperience = Core.Round(rareExp, 1),
            BonusExperience = Core.Round(bonusExp, 1),
            AverageSoulsPerFight = soulsPerFight,
            Fights = fights,
            Normal = {
                Duration = duration,
                ExpPerMinute = Core.Round((((exp or 0) / duration) * 60) or 0, 1),
                ExpPerSecond = Core.Round(((exp or 0) / duration) or 0, 1),
                NormalPerMinute = Core.Round((((normalExp or 0) / duration) * 60) or 0, 1),
                NormalPerSecond = Core.Round(((normalExp or 0) / duration) or 0, 1),
                RarePerMinute = Core.Round((((rareExp or 0) / duration) * 60) or 0, 1),
                RarePerSecond = Core.Round(((rareExp or 0) / duration) or 0, 1),
                BonusPerMinute = Core.Round((((bonusExp or 0) / duration) * 60) or 0, 1),
                BonusPerSecond = Core.Round(((bonusExp or 0) / duration) or 0, 1),
                PlayerDps = Core.Round((playerDamage / duration) or 0, 1),
                EnemyDps = Core.Round((enemyDamage / duration) or 0, 1)
            },
            Combat = {
                Duration = combatDuration,
                ExpPerMinute = Core.Round((((exp or 0) / combatDuration) * 60) or 0, 1),
                ExpPerSecond = Core.Round(((exp or 0) / combatDuration) or 0, 1),
                NormalPerMinute = Core.Round((((normalExp or 0) / combatDuration) * 60) or 0, 1),
                NormalPerSecond = Core.Round(((normalExp or 0) / combatDuration) or 0, 1),
                RarePerMinute = Core.Round((((rareExp or 0) / combatDuration) * 60) or 0, 1),
                RarePerSecond = Core.Round(((rareExp or 0) / combatDuration) or 0, 1),
                BonusPerMinute = Core.Round((((bonusExp or 0) / combatDuration) * 60) or 0, 1),
                BonusPerSecond = Core.Round(((bonusExp or 0) / combatDuration) or 0, 1),
                PlayerDps = Core.Round((playerDamage / combatDuration) or 0, 1),
                EnemyDps = Core.Round((enemyDamage / combatDuration) or 0, 1)
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
        duration = Core.Round(duration, 1)

        if (duration == 0) then
            duration = 0.1
        end

        local summary = {
            StartDate = os.date('%H:%M:%S - %d/%m/%Y', fight.StartTime),
            EndDate = os.date('%H:%M:%S - %d/%m/%Y', fight.EndTime or socket.gettime()),
            PlayerDamage = Core.Round(playerDamage, 1),
            EnemyDamage = Core.Round(enemyDamage, 1),
            Experience = Core.Round(exp, 1),
            NormalExperience = Core.Round(normalExp, 1),
            RareExperience = Core.Round(rareExp, 1),
            BonusExperience = Core.Round(bonusExp, 1),
            AverageSoulsPerFight = soulsPerFight,
            Fights = fights,
            Normal = {
                Duration = duration,
                ExpPerMinute = Core.Round((((exp or 0) / duration) * 60) or 0, 1),
                ExpPerSecond = Core.Round(((exp or 0) / duration) or 0, 1),
                NormalPerMinute = Core.Round((((normalExp or 0) / duration) * 60) or 0, 1),
                NormalPerSecond = Core.Round(((normalExp or 0) / duration) or 0, 1),
                RarePerMinute = Core.Round((((rareExp or 0) / duration) * 60) or 0, 1),
                RarePerSecond = Core.Round(((rareExp or 0) / duration) or 0, 1),
                BonusPerMinute = Core.Round((((bonusExp or 0) / duration) * 60) or 0, 1),
                BonusPerSecond = Core.Round(((bonusExp or 0) / duration) or 0, 1),
                PlayerDps = Core.Round((playerDamage / duration) or 0, 1),
                EnemyDps = Core.Round((enemyDamage / duration) or 0, 1)
            },
            Souls = souls
        }
        return summary
    end
}

function Tracker.Start()
    Tracker.Session = Tracker.Factory.NewSession()

    if (Window ~= nil) then
        Window.RegisterView(
            'Session',
            function()
                local content = {}
                local addcontent = function(msgs, tooltip, color)
                    if (color == nil) then
                        color = 'textcolor1'
                    end
                    table.insert(content, {Display = msgs, ColorSetting = color, Tooltip = tooltip})
                end

                local summary = Tracker.Factory.CreateSessionSummary(Tracker.Session)

                local duration = Core.SecondsToClock(summary.Normal.Duration)
                if (Core.IsAFK) then
                    duration = 'AFK'
                end

                addcontent({'Session', duration}, '', 'textcolor2')
                addcontent({'Fighting', tostring(Tracker.EnemyCounter)}, '', 'textcolor3')
                addcontent({'Queue', tostring(#Core.ActionQueue)}, '', 'textcolor3')

                addcontent({'Exp', tostring(summary.Experience)})
                addcontent({'Normal', tostring(summary.NormalExperience)})
                addcontent({'Rare', tostring(summary.RareExperience)})
                addcontent({'Bonus', tostring(summary.BonusExperience)})

                addcontent({'Fights', tostring(summary.Fights)})
                addcontent({'Souls', tostring(summary.Souls)})
                addcontent({'SPF', tostring(summary.AverageSoulsPerFight)})

                addcontent({'XPM', tostring(summary.Normal.ExpPerMinute)})
                addcontent({'XPCM', tostring(summary.Combat.ExpPerMinute)})
                addcontent({'Dmg', tostring(summary.PlayerDamage)})
                addcontent({'DPS', tostring(summary.Normal.PlayerDps)})
                addcontent({'DPCS', tostring(summary.Combat.PlayerDps)})

                addcontent({'EDmg', tostring(summary.EnemyDamage)})
                addcontent({'EDPS', tostring(summary.Normal.EnemyDps)})
                addcontent({'EDPCS', tostring(summary.Combat.EnemyDps)})

                return content
            end
        )

        local pager = {
            Current = function()
                return Tracker.AreaIndex
            end,
            Min = function()
                return 0
            end,
            Max = function()
                return #Tracker.AreaTracker.History
            end,
            Set = function()
                Core.Execute('pyre setarea')
            end,
            First = function()
                Core.Execute('pyre firstarea')
            end,
            Newer = function()
                Core.Execute('pyre newerarea')
            end,
            Older = function()
                Core.Execute('pyre olderarea')
            end,
            Last = function()
                Core.Execute('pyre lastarea')
            end
        }

        Window.RegisterView(
            'Areas',
            function()
                local content = {}
                local addcontent = function(msgs, tooltip, color, callback)
                    table.insert(content, {Display = msgs, ColorSetting = (color or 'textcolor1'), Tooltip = tooltip})
                end

                local area = Tracker.GetAreaByIndex(Tracker.AreaIndex)
                if (area.Area == '') then
                    area.Area = Core.Status.Zone
                end
                local summary = Tracker.Factory.CreateAreaSummary(area)

                local duration = Core.SecondsToClock(summary.Normal.Duration)
                if (Core.IsAFK) then
                    duration = 'AFK'
                end

                addcontent({summary.Area, duration}, '', 'textcolor2')
                addcontent({'Fighting', tostring(Tracker.EnemyCounter)}, '', 'textcolor3')
                addcontent({'Queue', tostring(#Core.ActionQueue)}, '', 'textcolor3')

                addcontent({'Exp', tostring(summary.Experience)})
                addcontent({'Normal', tostring(summary.NormalExperience)})
                addcontent({'Rare', tostring(summary.RareExperience)})
                addcontent({'Bonus', tostring(summary.BonusExperience)})

                addcontent({'Fights', tostring(summary.Fights)})
                addcontent({'Souls', tostring(summary.Souls)})
                addcontent({'SPF', tostring(summary.AverageSoulsPerFight)})

                addcontent({'XPM', tostring(summary.Normal.ExpPerMinute)})
                addcontent({'XPCM', tostring(summary.Combat.ExpPerMinute)})
                addcontent({'Dmg', tostring(summary.PlayerDamage)})
                addcontent({'DPS', tostring(summary.Normal.PlayerDps)})
                addcontent({'DPCS', tostring(summary.Combat.PlayerDps)})

                addcontent({'EDmg', tostring(summary.EnemyDamage)})
                addcontent({'EDPS', tostring(summary.Normal.EnemyDps)})
                addcontent({'EDPCS', tostring(summary.Combat.EnemyDps)})

                return content
            end,
            pager
        )

        pager = {
            Current = function()
                return Tracker.FightIndex
            end,
            Min = function()
                return 0
            end,
            Max = function()
                return #Tracker.Session.Fights
            end,
            Set = function()
                Core.Execute('pyre setfight')
            end,
            First = function()
                Core.Execute('pyre firstfight')
            end,
            Newer = function()
                Core.Execute('pyre newerfight')
            end,
            Older = function()
                Core.Execute('pyre olderfight')
            end,
            Last = function()
                Core.Execute('pyre lastfight')
            end
        }
        Window.RegisterView(
            'Fights',
            function()
                local content = {}
                local addcontent = function(msgs, tooltip, color)
                    table.insert(content, {Display = msgs, ColorSetting = (color or 'textcolor1'), Tooltip = tooltip})
                end

                local fight = Tracker.GetFightByIndex(Tracker.FightIndex)
                local summary = Tracker.Factory.CreateFightSummary(fight)

                if (summary == nil and Tracker.FightIndex == 0) then
                    fight = Tracker.GetFightByIndex(1)
                    summary = Tracker.Factory.CreateFightSummary(fight)
                end

                if (summary == nil) then
                    addcontent({'Waiting on data'}, '', 'textcolor3')
                    return content
                end

                local duration = Core.SecondsToClock(summary.Normal.Duration)
                if (Core.IsAFK) then
                    duration = 'AFK'
                end

                addcontent({'Duration', duration}, '', 'textcolor2')
                addcontent({'Enemies', tostring(Tracker.EnemyCounter)}, '', 'textcolor3')
                addcontent({'Queue', tostring(#Core.ActionQueue)}, '', 'textcolor3')

                addcontent({'Exp', tostring(summary.Experience)})
                addcontent({'Normal', tostring(summary.NormalExperience)})
                addcontent({'Rare', tostring(summary.RareExperience)})
                addcontent({'Bonus', tostring(summary.BonusExperience)})

                addcontent({'Souls', tostring(summary.Souls)})

                addcontent({'XPS', tostring(summary.Normal.ExpPerSecond)})
                addcontent({'Dmg', tostring(summary.PlayerDamage)})
                addcontent({'DPS', tostring(summary.Normal.PlayerDps)})

                addcontent({'EDmg', tostring(summary.EnemyDamage)})
                addcontent({'EDPS', tostring(summary.Normal.EnemyDps)})

                return content
            end,
            pager
        )
    end
end

function Tracker.Stop()
    Tracker.Session = nil
    Tracker.FightTracker.Current = nil
    Tracker.AreaTracker.Current = nil
    Tracker.AreaTracker.History = {}

    if (Window ~= nil) then
        Window.UnregisterView('Session')
        Window.UnregisterView('Areas')
        Window.UnregisterView('Fights')
    end
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
    if (Tracker.FightTracker.Current ~= nil and (Tracker.FightTracker.Current.Area or '') ~= '') then
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

            local maxSessionFights = Core.GetSettingValue(Tracker, 'sessionsize')
            if (#Tracker.Session.Fights > maxSessionFights) then
                -- trim our session data
                local difference = (#Tracker.Session.Fights - maxSessionFights)
                if (difference > 0) then
                    Tracker.Session.Fights =
                        Core.Filter(
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

        local maxSize = Core.GetSettingValue(Tracker, 'areasize')
        local difference = (#Tracker.AreaTracker.History - maxSize)
        if (difference > 0) then
            Tracker.AreaTracker.History =
                Core.Filter(
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

function Tracker.OnStateChanged(state)
    if (Tracker.AreaTracker.Current == nil or Tracker.AreaTracker.Current.Fights == nil) then
        Tracker.AreaTracker.Current = Tracker.Factory.NewArea()
    end

    if (state.New == Core.States.COMBAT) then
        Tracker.FightTracker.Current = Tracker.Factory.NewFight()
    else
        Tracker.ArchiveCurrentFight()
    end
end

function Tracker.OnZoneChanged(zone)
    Tracker.ArchiveCurrentArea()
end

function Tracker.OnExperienceGain(line, wildcards)
    if (Tracker.FightTracker.Current == nil or Tracker.FightTracker.Current.Area == nil) then
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

    Core.Switch(xpType) {
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

function Tracker.OnAFKChanged(afk)
    if (afk.New == true) then
    else
    end
end

function Tracker.OnPlayerDidDamage(line, wildcards)
    local damage = tonumber(wildcards[5]) or 0
    local element = wildcards[2]

    if (element == 'swing') then
        if (Tracker.EnemyCounterLastReset < socket.gettime() - 0.5) then
            Tracker.EnemyCounter = 0
            Tracker.EnemyCounterLastReset = socket.gettime()
        end
        Tracker.EnemyCounter = Tracker.EnemyCounter + 1
    else
        Tracker.EnemyCounterLastReset = socket.gettime() - 10
    end

    if (Tracker.FightTracker.Current ~= nil and Tracker.FightTracker.Current.Damage ~= nil) then
        Tracker.FightTracker.Current.Damage.Player = (Tracker.FightTracker.Current.Damage.Player or 0) + damage
    end
end

function Tracker.OnEnemyDidDamage(line, wildcards)
    local damage = tonumber(wildcards[5]) or 0
    if (Tracker.FightTracker.Current ~= nil and Tracker.FightTracker.Current.Damage ~= nil) then
        Tracker.FightTracker.Current.Damage.Enemy = (Tracker.FightTracker.Current.Damage.Enemy or 0) + damage
    end
end

function Tracker.SetArea(line, wildcards)
    local i = Core.AskIfEmpty(wildcards[1], 'Area Index', Tracker.AreaIndex)
    if (i ~= nil and i ~= '') then
        Tracker.AreaIndex = tonumber(i) or 0
        if (Tracker.AreaIndex > #Tracker.AreaTracker.History) then
            Tracker.AreaIndex = #Tracker.AreaTracker.History
        end
        if (Tracker.AreaIndex < 0) then
            Tracker.AreaIndex = 0
        end
        Core.Log('Area index set to ' .. (Tracker.AreaIndex or 0) .. ' of ' .. (#Tracker.AreaTracker.History or 0))
    end
end

function Tracker.SetFirstArea()
    Tracker.AreaIndex = 0
    Core.Log('Area index set to ' .. (Tracker.AreaIndex or 0) .. ' of ' .. (#Tracker.AreaTracker.History or 0))
end

function Tracker.SetNewerArea()
    Tracker.AreaIndex = Tracker.AreaIndex - 1
    if (Tracker.AreaIndex < 0) then
        Tracker.AreaIndex = 0
    end
    Core.Log('Area index set to ' .. (Tracker.AreaIndex or 0) .. ' of ' .. (#Tracker.AreaTracker.History or 0))
end

function Tracker.SetOlderArea()
    Tracker.AreaIndex = Tracker.AreaIndex + 1
    if (Tracker.AreaIndex > #Tracker.AreaTracker.History) then
        Tracker.AreaIndex = #Tracker.AreaTracker.History
    end
    Core.Log('Area index set to ' .. (Tracker.AreaIndex or 0) .. ' of ' .. (#Tracker.AreaTracker.History or 0))
end

function Tracker.SetLastArea()
    Tracker.AreaIndex = #Tracker.AreaTracker.History or 0
    Core.Log('Area index set to ' .. (Tracker.AreaIndex or 0) .. ' of ' .. (#Tracker.AreaTracker.History or 0))
end

function Tracker.ResetSession()
    Core.Log('Resetting all session data', Core.LogLevel.INFO)
    Tracker.Session = Tracker.Factory.NewSession()
end
function Tracker.ResetCurrentArea()
    Core.Log('Resetting area data', Core.LogLevel.INFO)
    Tracker.AreaTracker.Current = Tracker.Factory.NewArea()
end
function Tracker.ResetAreas()
    Core.Log('Resetting all area data', Core.LogLevel.INFO)
    Tracker.ResetCurrentArea()
    Tracker.AreaTracker.History = {}
end
function Tracker.ResetCurrentFight()
    Core.Log('Resetting fight data', Core.LogLevel.INFO)
    Tracker.FightTracker.Current = Tracker.Factory.NewFight()
end

function Tracker.SetFight(line, wildcards)
    local i = Core.AskIfEmpty(nil, 'Fight Index', Tracker.FightIndex)
    if (i ~= nil and i ~= '') then
        Tracker.FightIndex = tonumber(i) or 0
        if (Tracker.FightIndex > #Tracker.Session.Fights) then
            Tracker.FightIndex = #Tracker.Session.Fights
        end
        if (Tracker.FightIndex < 0) then
            Tracker.FightIndex = 0
        end
        Core.Log('Fight index set to ' .. (Tracker.FightIndex or 0) .. ' of ' .. (#Tracker.Session.Fights or 0))
    end
end

function Tracker.SetFirstFight()
    Tracker.FightIndex = 0
    Core.Log('Fight index set to ' .. (Tracker.FightIndex or 0) .. ' of ' .. (#Tracker.Session.Fights or 0))
end

function Tracker.SetNewerFight()
    Tracker.FightIndex = Tracker.FightIndex - 1
    if (Tracker.FightIndex < 0) then
        Tracker.FightIndex = 0
    end
    Core.Log('Fight index set to ' .. (Tracker.FightIndex or 0) .. ' of ' .. (#Tracker.Session.Fights or 0))
end

function Tracker.SetOlderFight()
    Tracker.FightIndex = Tracker.FightIndex + 1
    if (Tracker.FightIndex > #Tracker.Session.Fights) then
        Tracker.FightIndex = #Tracker.Session.Fights
    end
    Core.Log('Fight index set to ' .. (Tracker.FightIndex or 0) .. ' of ' .. (#Tracker.Session.Fights or 0))
end

function Tracker.SetLastFight()
    Tracker.FightIndex = #Tracker.Session.Fights or 0
    Core.Log('Fight index set to ' .. (Tracker.FightIndex or 0) .. ' of ' .. (#Tracker.Session.Fights or 0))
end

return Tracker
