local Pyre = require('pyrecore')
local WindowFeature = {
    lastSessionCacheUpdate = 0,
    sessionCache = nil
}
local Tracker = nil

WindowFeature.Commands = {
    {name = 'show', description = 'Show the window', callback = 'OnTrackerWindowShow'},
    {name = 'hide', description = 'Hide the window', callback = 'OnTrackerWindowHide'}
}

WindowFeature.Settings = {
    {
        name = 'interval',
        description = 'How often to update the window data',
        value = tonumber(GetVariable('trackerwindow_interval')) or 3,
        setValue = function(setting, val)
            local parsed = tonumber(val) or 0
            setting.value = parsed
            SetVariable('trackerwindow_interval', setting.value)
        end
    },
    {
        name = 'view',
        description = 'What data to display Session,Area, or Fight',
        value = tonumber(GetVariable('trackerwindow_view')) or 0,
        setValue = function(setting, val)
            local parsed = tonumber(val) or 0
            setting.value = parsed
            SetVariable('trackerwindow_view', setting.value)
        end
    }
}

function WindowFeature.FeatureStart(featuresRunning)
    if
        not (Pyre.Any(
            featuresRunning,
            function(f)
                return (f.name == 'pyretracker')
            end
        ))
     then
        Pyre.Log('Unable to use pyretrackerwindow feature. You must have pyretracker installed.', Pyre.LogLevel.ERROR)
        return
    end

    Tracker = require('pyretracker')

    Pyre.Each(
        WindowFeature.Commands,
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

function WindowFeature.FeatureHelp()
    local logTable = {}

    Pyre.Each(
        WindowFeature.Commands,
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
        WindowFeature.Settings,
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
        'Feature: TrackerWindow ',
        'teal',
        {'cmd/setting', 'value'},
        logTable,
        1,
        true,
        'usage: pyre tracker <cmd> or pyre set tracker <setting> <value>'
    )
end

function WindowFeature.FeatureSettingHandle(settingName, p1, p2, p3, p4)
    if (settingName ~= 'tracker') then
        return
    end
    for _, setting in ipairs(WindowFeature.Settings) do
        if (string.lower(setting.name) == string.lower(p1)) then
            setting:setValue(p2)
            Pyre.Log(settingName .. ' ' .. setting.name .. ' : ' .. setting.value)
        end
    end
end

function WindowFeature.FeatureTick()
    if (os.time() > (WindowFeature.lastSessionCacheUpdate + 3)) then
        if (Tracker.Session ~= nil and Tracker.Session.StartTime ~= nil) then
            WindowFeature.sessionCache = Tracker.Factory.CreateSessionSummary(Tracker.Session)
            WindowFeature.lastSessionCacheUpdate = os.time()
        end
    end
end

return WindowFeature
