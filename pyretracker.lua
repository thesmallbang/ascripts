local Pyre = require('pyrecore')
local PyreTracker = {}

Factory = {
    NewFight = function()
        return {
            Area = Pyre.Status.Zone,
            StartTime = socket.gettime(),
            EndTime = 0,
            XpMessages = {}, -- { Value, Type (Normal, Rare, Double) }
            DmgMessages = {}, -- { Value , SourceType (Player,Enemy) , IsCritical,  }
            HealMessages = {} -- { Value , SourceType (Player,Quaff) }
        }
    end,
    NewArea = function()
        return {
            Area = Pyre.Status.Zone,
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
PyreTracker.FightTracker = {
    Current = {},
    History = {}
}

PyreTracker.AreaTracker = {
    Current = {},
    History = {}
}

PyreTracker.Commands = {
    {name = 'resetfight', description = 'Reset the current fight data', callback = 'OnResetFightData'},
    {name = 'resetfights', description = 'Reset the all fight data', callback = 'OnResetFightsData'},
    {name = 'resetarea', description = 'Reset the current area tracking data', callback = 'OnResetAreaData'},
    {name = 'resetareas', description = 'Reset all area tracking data', callback = 'OnResetAreasData'},
    {name = 'reportfight', description = 'Report the current fight', callback = 'OnReportFightData'},
    {name = 'reportarea', description = 'Report the current area', callback = 'OnReportAreaData'}
}

PyreTracker.Settings = {
    {
        name = 'fightsize',
        description = 'How many previous fights to keep data on',
        value = tonumber(GetVariable('fightsize')) or 10,
        setValue = function(val)
            local parsed = tonumber(val) or 0
            value = parsed
        end
    },
    {
        name = 'areasize',
        description = 'How many previous areas to keep data on',
        value = tonumber(GetVariable('areasize')) or 10,
        setValue = function(val)
            local parsed = tonumber(val) or 0
            value = parsed
        end
    }
}

function PyreTracker.FeatureStart()
    table.insert(Pyre.Events[Pyre.Event.StateChanged], OnStateChange)
    table.insert(Pyre.Events[Pyre.Event.ZoneChanged], OnZoneChanged)

    -- create an alias for each of our PyreTracker.Commands
    Pyre.Each(
        PyreTracker.Commands,
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
end

function PyreTracker.FeatureSettingHandle(settingName, p1, p2, p3, p4)
    if (settingName ~= 'tracker') then
        return
    end
    for _, setting in ipairs(PyreTracker.Settings) do
        if (string.lower(setting.name) == string.lower(p1)) then
            setting.setValue(p2)
            Pyre.Log(settingName .. ' ' .. setting.name .. ' : ' .. setting.value)
        end
    end
end

function PyreTracker.FeatureHelp()
    local logTable = {}

    Pyre.Each(
        PyreTracker.Commands,
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
        PyreTracker.Settings,
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

function PyreTracker.ArchiveCurrentFight()
    -- if the fight has anything useful then we archive it
    if (PyreTracker.FightTracker.Current ~= {}) then
        table.insert(PyreTracker.FightTracker.History, PyreTracker.FightTracker.Current)
        PyreTracker.FightTracker.Current = {}
    end
end

function PyreTracker.ArchiveCurrentArea()
    if (PyreTracker.AreaTracker.Current ~= {}) then
        table.insert(PyreTracker.AreaTracker.History, PyreTracker.AreaTracker.Current)
        PyreTracker.AreaTracker.Current = {}
    end
end

function OnStateChange(stateObject)
    if (stateObject.New == Pyre.States.COMBAT) then
        PyreTracker.FightTracker.Current = Factory.NewFight()
    else
        PyreTracker.ArchiveCurrentFight()
    end
end

function OnZoneChanged(changeInfo)
    PyreTracker.ArchiveCurrentArea()
end

function OnResetFightData()
    Pyre.Log('Resetting fight data', Pyre.LogLevel.INFO)
end
function OnResetFightsData()
    Pyre.Log('Resetting all fight data', Pyre.LogLevel.INFO)
end

function OnReportFightData()
    Pyre.Log('OnReportFightData', Pyre.LogLevel.DEBUG)
    if (PyreTracker.FightTracker.Current.Area == nil) then
        Pyre.Log('No fight to report', Pyre.LogLevel.ERROR)
        return
    end
    print(PyreTracker.FightTracker.Current.Area .. ' report some fight')
end

return PyreTracker
