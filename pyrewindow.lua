local Core = require('pyrecore')
Window = {
    Views = {},
    Config = {
        Events = {},
        Commands = {
            {
                Name = 'show',
                Description = 'Show pyre window',
                Callback = function(line, wildcards)
                    PH.ShowFeatures()
                end
            },
            {
                Name = 'hide',
                Description = 'Hide pyre window',
                Callback = function(line, wildcards)
                    PH.InstallFeature(wildcards[1])
                end
            }
        },
        Settings = {
            {
                Name = 'updaterate',
                Description = 'Keep updating the window data after how many seconds',
                Value = nil,
                Min = 0.5,
                Max = 5,
                Default = 1
            },
            {
                Name = 'view',
                Description = 'What amount of plugin activity to show. (0 None, 1 Verbose, 2 Debug, 3 *Info, 4 Errors)',
                Value = nil,
                Min = 0,
                Max = 999999,
                Default = 0,
                OnAfterSet = function(setting)
                    if (setting.Value > #Window.Views) then
                        Core.Log('Invalid view. Using ' .. setting.Default, Core.LogLevel.ERROR)
                        setting.Value = setting.Default
                    end
                end
            }
        },
        Triggers = {}
    }
}

return Window
