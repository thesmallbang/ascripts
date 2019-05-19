local Core = require('pyrecore')
Window = {
    Visible = false,
    ViewIndex = 0,
    Config = {
        Events = {
            {
                Type = Core.Event.Tick,
                Callback = function(o)
                    Window.Tick()
                end
            }
        },
        Commands = {
            {
                Name = 'show',
                Description = 'Show pyre window',
                Callback = function(line, wildcards)
                    Window.Visible = true
                end
            },
            {
                Name = 'hide',
                Description = 'Hide pyre window',
                Callback = function(line, wildcards)
                    Window.Visible = false
                end
            }
        },
        Settings = {
            {
                Name = 'refreshrate',
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
            },
            {
                Name = 'layer',
                Description = 'Determines what other windows this is above or below',
                Value = nil,
                Min = 0,
                Max = 999999,
                Default = 50
            },
            {
                Name = 'height',
                Description = 'Height of the window',
                Value = nil,
                Min = 100,
                Max = 1000,
                Default = 300
            },
            {
                Name = 'width',
                Description = 'Width of the window',
                Value = nil,
                Min = 0,
                Max = 999999,
                Default = 400
            },
            {
                Name = 'left',
                Description = 'Distance away from the left side of the screen',
                Value = nil,
                Min = 0,
                Max = 2000,
                Default = 1000
            },
            {
                Name = 'top',
                Description = 'Distance away from the top side of the screen',
                Value = nil,
                Min = 0,
                Max = 2000,
                Default = 200
            }
        },
        Triggers = {}
    },
    Drawing = {}
}

local Views = {}

function Window.Start()
end

function Window.Stop()
end

function Window.Tick()
    if not (Window.Visible) then
        return
    end
end

function Window.RegisterView(name, drawingCallback, atStart)
    Core.Log('View ' .. name .. ' registered in window.', Core.LogLevel.DEBUG)
    if (atStart == nil) then
        atStart = false
    end

    if (atStart) then
        table.insert(Views, 0, {Name = name, Callback = drawingCallback})
    else
        table.insert(Views, {Name = name, Callback = drawingCallback})
    end
end

function Window.UnregisterView(name)
    Core.Log('View ' .. name .. ' unregistered in window.', Core.LogLevel.DEBUG)
    Views =
        Core.Except(
        Views,
        function(v)
            return v.Name == name
        end
    )
end

return Window
