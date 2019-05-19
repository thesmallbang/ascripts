local Core = require('pyrecore')
require('socket')
Window = {
    IsMoving = false,
    MovingPositions = {X = 0, Y = 0},
    LastDraw = 0,
    Visible = true,
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
                Default = 200
            },
            {
                Name = 'width',
                Description = 'Width of the window',
                Value = nil,
                Min = 200,
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
            },
            {
                Name = 'windowid',
                Description = 'unique id for the window. no real reeson to change it',
                Value = nil,
                Default = 'ph_windowId',
                OnBeforeSet = function(ov, nv)
                    Window.Visible = false
                end,
                OnAfterSet = function()
                    Window.Visible = true
                end
            },
            {
                Name = 'backcolor',
                Description = 'window backcolor',
                Value = nil,
                Default = 'black',
                OnBeforeSet = function(ov, nv)
                    local test = ColourNameToRGB(nv or '')
                    return test >= 0
                end
            },
            {
                Name = 'bordercolor',
                Description = 'window border',
                Value = nil,
                Default = 'teal',
                OnBeforeSet = function(ov, nv)
                    local test = ColourNameToRGB(nv or '')
                    return test >= 0
                end
            },
            {
                Name = 'textcolor1',
                Description = 'theme text color 1',
                Value = nil,
                Default = 'white',
                OnBeforeSet = function(ov, nv)
                    local test = ColourNameToRGB(nv or '')
                    return test >= 0
                end
            },
            {
                Name = 'textcolor2',
                Description = 'theme text color 2',
                Value = nil,
                Default = 'teal',
                OnBeforeSet = function(ov, nv)
                    local test = ColourNameToRGB(nv or '')
                    return test >= 0
                end
            },
            {
                Name = 'textcolor3',
                Description = 'theme text color 3',
                Value = nil,
                Default = 'red',
                OnBeforeSet = function(ov, nv)
                    local test = ColourNameToRGB(nv or '')
                    return test >= 0
                end
            },
            {
                Name = 'linkcolor',
                Description = 'clickable items on the window will be this color',
                Value = nil,
                Default = 'orange',
                OnBeforeSet = function(ov, nv)
                    local test = ColourNameToRGB(nv or '')
                    return test >= 0
                end
            },
            {
                Name = 'rowheight',
                Description = 'how tall is each line of data',
                Value = nil,
                Min = 10,
                Max = 30,
                Default = 20
            },
            {
                Name = 'font',
                Description = 'What font the text will be',
                Value = nil,
                Default = 'Times Roman'
            },
            {
                Name = 'fontandpitch',
                Description = 'No need to change in most cases',
                Value = nil,
                Min = 0,
                Max = 88,
                Default = 0
            }
        }
    },
    Drawing = {
        DrawWindow = function()
            if (Window.LastDraw > socket.gettime() - Core.GetSettingValue(Window.Config.Settings, 'refreshrate')) then
                return
            end
            Window.LastDraw = socket.gettime()

            local windowId = Core.GetSettingValue(Window.Config.Settings, 'windowid')
            local windowWidth = Core.GetSettingValue(Window.Config.Settings, 'width')
            local windowHeight = Core.GetSettingValue(Window.Config.Settings, 'height')
            local left = Core.GetSettingValue(Window.Config.Settings, 'left')
            local top = Core.GetSettingValue(Window.Config.Settings, 'top')
            local rowHeight = Core.GetSettingValue(Window.Config.Settings, 'rowheight')
            local fontName = Core.GetSettingValue(Window.Config.Settings, 'font')
            local fontPitch = Core.GetSettingValue(Window.Config.Settings, 'fontandpitch')

            WindowCreate(
                windowId,
                left,
                top,
                windowWidth,
                windowHeight,
                0,
                miniwin.create_absolute_location,
                ColourNameToRGB(Core.GetSettingValue(Window.Config.Settings, 'backcolor'))
            )

            WindowFont(windowId, 'l', fontName, 12, false, false, false, false, 1, fontPitch)
            WindowFont(windowId, 'm', fontName, 10, false, false, false, false, fontPitch)
            WindowFont(windowId, 'mb', fontName, 10, true, false, false, false, fontPitch)
            WindowFont(windowId, 's', fontName, 8, false, false, false, false, fontPitch)
            WindowFont(windowId, 'sb', fontName, 8, true, false, false, false, fontPitch)
            WindowFont(windowId, 'su', fontName, 8, false, false, true, false, fontPitch)

            WindowSetZOrder(windowId, Core.GetSettingValue(Window.Config.Settings, 'layer'))

            -- Primary Window Border
            WindowCircleOp(
                windowId,
                3,
                0,
                0,
                windowWidth,
                windowHeight,
                ColourNameToRGB(Core.GetSettingValue(Window.Config.Settings, 'bordercolor')),
                0,
                0,
                ColourNameToRGB('transparent'),
                0,
                0,
                0
            )

            -- title bar seperator line
            WindowLine(
                windowId,
                0,
                rowHeight + 3,
                windowWidth,
                rowHeight + 3,
                ColourNameToRGB(Core.GetSettingValue(Window.Config.Settings, 'bordercolor')),
                0,
                1
            )

            WindowAddHotspot(
                windowId,
                'movewindowhs',
                0,
                0,
                windowWidth - rowHeight,
                rowHeight + 3,
                '',
                '',
                'OnWindowMouseDown',
                '',
                '',
                'Drag to move window', -- tooltip text
                10, -- hand cursor
                0
            ) -- flags
            WindowDragHandler(windowId, 'movewindowhs', 'OnWindowMove', 'OnWindowMoveRelease', 0)

            local title = 'PH ' .. PH.Config.Versions.Release.Version .. ' SomeViewName'
            local titleWidth = WindowTextWidth(windowId, 'm', title, false)
            local textleft = (windowWidth / 2) - (titleWidth / 2)

            Window.Drawing.DrawTextLine(
                windowId,
                1,
                title,
                textleft,
                Core.GetSettingValue(Window.Config.Settings, 'textcolor2'),
                'm'
            )

            Window.Drawing.DrawTextLine(
                windowId,
                1,
                'O',
                windowWidth - rowHeight,
                Core.GetSettingValue(Window.Config.Settings, 'linkcolor'),
                'su'
            )
            WindowAddHotspot(
                windowId,
                'contextmenu',
                windowWidth - rowHeight,
                0,
                windowWidth,
                rowHeight,
                '',
                '',
                'OnTrackerWindowShowContextMenu',
                '',
                '',
                'Show Options', -- tooltip text
                1, -- hand cursor
                miniwin.hotspot_got_rh_mouse
            ) -- flags

            WindowShow(windowId, Window.Visible)
        end,
        DrawTextLine = function(windowid, line, text, left, color, fontid, clickFnName, tooltip)
            left = left or 10
            top = Window.Drawing.GetLineHeight(line)
            if (color == nil or color == '') then
                color = 'white'
            end
            fontid = fontid or 's'
            if (text == nil) then
                text = ''
            end

            WindowText(
                windowid,
                fontid,
                text,
                left,
                top + 1.5,
                0,
                0,
                ColourNameToRGB(color) or ColourNameToRGB('white')
            )

            if (clickFnName ~= nil) then
                local msgWidth = WindowTextWidth(windowId, fontid, text, false)
                local msgHeight = WindowFontInfo(windowId, fontid, 1)
                WindowAddHotspot(
                    windowId,
                    'hs_' .. line .. '_' .. left,
                    left,
                    top,
                    left + msgWidth,
                    top + msgHeight,
                    '',
                    '',
                    clickFnName,
                    '',
                    '',
                    tooltip or '',
                    1, -- hand cursor
                    0
                )
            end
        end,
        GetLineHeight = function(line)
            local top = 2
            if (line > 1) then
                top = 3 + ((line - 1) * Core.GetSettingValue(Window.Config.Settings, 'rowheight'))
            end
            return top
        end
    }
}

local Views = {}

function OnWindowMouseDown()
    local windowId = Core.GetSettingValue(Window.Config.Settings, 'windowid')
    Window.MovingPositions.X = WindowInfo(windowId, 14)
    Window.MovingPositions.Y = WindowInfo(windowId, 15)
end

function OnWindowMove()
    local windowId = Core.GetSettingValue(Window.Config.Settings, 'windowid')

    local posx, posy = WindowInfo(windowId, 17), WindowInfo(windowId, 18)
    Window.IsMoving = true
    if posx < 0 or posx > GetInfo(281) or posy < 0 or posy > GetInfo(280) then
        check(SetCursor(11)) -- X cursor
    else
        check(SetCursor(10)) -- move cursor
        -- move the window to the new location
        WindowPosition(windowId, posx - Window.MovingPositions.X, posy - Window.MovingPositions.Y, 0, 2)
    end
end

function OnWindowMoveRelease()
    local windowId = Core.GetSettingValue(Window.Config.Settings, 'windowid')
    local left = Core.GetSetting(Window.Config.Settings, 'left')
    left.Value = WindowInfo(windowId, 10)

    local top = Core.GetSetting(Window.Config.Settings, 'top')
    top.Value = WindowInfo(windowId, 11)

    Window.IsMoving = false
end

function OnTrackerWindowShowContextMenu()
    local windowId = Core.GetSettingValue(Window.Config.Settings, 'windowid')

    local nameAndCheckedTab = function(name)
        local checked = ''
        if (name == 'Session' and Core.GetSettingValue(Window.Config.Settings, 'view') == 0) then
            checked = '+'
        end
        if (name == 'Area' and Core.GetSettingValue(Window.Config.Settings, 'view') == 1) then
            checked = '+'
        end
        if (name == 'Fight' and Core.GetSettingValue(Window.Config.Settings, 'view') == 2) then
            checked = '+'
        end
        return checked .. name
    end

    result =
        WindowMenu(
        windowId,
        WindowInfo(windowId, 14), -- x
        WindowInfo(windowId, 15), -- y
        '>View|' .. '|<|Help'
    )

    if (result == 'Help') then
        Execute('pyre help')
        Execute('pyre help window')
    end

    if (result == 'Session') then
        Execute('pyre set tracker view 0')
    end
    if (result == 'Area') then
        Execute('pyre set tracker view 1')
    end
    if (result == 'Fight') then
        Execute('pyre set tracker view 2')
    end
end

function Window.Start()
    Window.SetVisible(true)
end

function Window.Stop()
    Window.SetVisible(false)
end

function Window.Tick()
    if (Window.IsMoving == true or Window.Visible ~= true) then
        return
    end

    Window.Drawing.DrawWindow()
end

function Window.RegisterView(name, drawingCallback, atStart)
    Core.Log('View ' .. name .. ' registered in window.', Core.LogLevel.DEBUG)
    if (atStart == nil) then
        atStart = false
    end

    if (atStart) then
        table.insert(Views, 0, {Name = name, Callback = drawingCallback, Cache = nil, LastUpdate = nil})
    else
        table.insert(Views, {Name = name, Callback = drawingCallback, Cache = nil, LastUpdate = nil})
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

function Window.SetVisible(visible)
    Window.Visible = visible
    WindowShow(Core.GetSettingValue(Window.Config.Settings, 'windowid'), visible)
end

return Window
