local Core = require('pyrecore')
require('socket')

local Views = {}

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
                    Window.SetVisible(true)
                end
            },
            {
                Name = 'hide',
                Description = 'Hide pyre window',
                Callback = function(line, wildcards)
                    Window.SetVisible(false)
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
                Description = 'Different features register different views to show data',
                Value = nil,
                Min = 0,
                Max = 999999,
                Default = 0,
                OnBeforeSet = function(setting, oldvalue, newvalue)
                    if (tonumber(newvalue) >= (#Views)) then
                        Core.Log('Invalid view. Using ' .. setting.Default, Core.LogLevel.ERROR)
                        setting.Value = setting.Default
                        return false
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
                Default = 300
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
                Default = 'tan',
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
                Name = 'rowspacer',
                Description = 'how much space between rows',
                Value = nil,
                Min = 1,
                Max = 50,
                Default = 5
            },
            {
                Name = 'columnspacer',
                Description = 'how much space between columns (formula is a little off atm)',
                Value = nil,
                Min = 1,
                Max = 50,
                Default = 5
            },
            {
                Name = 'columns',
                Description = 'how many columns per row. 0 for auto',
                Value = nil,
                Min = 0,
                Max = 10,
                Default = 0
            },
            {
                Name = 'font',
                Description = 'What font the text will be',
                Value = nil,
                Default = 'Lucida Console'
            },
            {
                Name = 'fontsize',
                Description = 'What size the text will be',
                Value = nil,
                Min = 6,
                Max = 24,
                Default = 10
            },
            {
                Name = 'pitchandfamily',
                Description = 'No need to change this for most fonts. Google "MushClient PitchAndFamily" for more. Often 0 or 1 is OK.',
                Value = nil,
                Min = 0,
                Max = 88,
                Default = 0
            }
        }
    },
    Overrides = {},
    Drawing = {
        DrawWindow = function()
            if (Window.LastDraw > socket.gettime() - Core.GetSettingValue(Window, 'refreshrate')) then
                return
            end
            Window.LastDraw = socket.gettime()

            local windowId = Core.GetSettingValue(Window, 'windowid')
            local windowWidth = Core.GetSettingValue(Window, 'width')
            local windowHeight = Core.GetSettingValue(Window, 'height')
            local left = Core.GetSettingValue(Window, 'left')
            local top = Core.GetSettingValue(Window, 'top')

            WindowCreate(
                windowId,
                left,
                top,
                windowWidth,
                windowHeight,
                0,
                miniwin.create_absolute_location,
                ColourNameToRGB(Core.GetSettingValue(Window, 'backcolor'))
            )

            local fontName = Core.GetSettingValue(Window, 'font')

            local fontPitch = Core.GetSettingValue(Window, 'pitchandfamily')
            local fontsize = Core.GetSettingValue(Window, 'fontsize')
            WindowFont(windowId, 'l', fontName, 12, false, false, false, false, 1, fontPitch)
            WindowFont(windowId, 'm', fontName, 10, false, false, false, false, fontPitch)
            WindowFont(windowId, 'mb', fontName, 10, true, false, false, false, fontPitch)
            WindowFont(windowId, 's', fontName, fontsize, false, false, false, false, fontPitch)
            WindowFont(windowId, 'sb', fontName, fontsize, true, false, false, false, fontPitch)
            WindowFont(windowId, 'su', fontName, fontsize, false, false, true, false, fontPitch)

            local viewName = ''
            local view = Views[Core.GetSettingValue(Window, 'view') + 1]
            if (view ~= nil) then
                viewName = view.Name
            end

            local title = 'Pyre Helper ' .. PH.Config.Versions.Release.Version .. ' | ' .. viewName
            local titleWidth = WindowTextWidth(windowId, 'm', title, false)
            local titleHeight = WindowFontInfo(windowId, 'm', 1)
            local rowSpacer = Core.GetSettingValue(Window, 'rowspacer')

            WindowSetZOrder(windowId, Core.GetSettingValue(Window, 'layer'))

            -- Primary Window Border
            WindowCircleOp(
                windowId,
                3,
                0,
                0,
                windowWidth,
                windowHeight,
                ColourNameToRGB(Core.GetSettingValue(Window, 'bordercolor')),
                0,
                0,
                ColourNameToRGB(Core.GetSettingValue(Window, 'backcolor')),
                0,
                0,
                0
            )

            -- title bar seperator line
            WindowLine(
                windowId,
                0,
                titleHeight + 3,
                windowWidth,
                titleHeight + 3,
                ColourNameToRGB(Core.GetSettingValue(Window, 'bordercolor')),
                0,
                1
            )

            WindowAddHotspot(
                windowId,
                'movewindowhs',
                0,
                0,
                windowWidth - 20,
                titleHeight + 3,
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

            local textleft = (windowWidth / 2) - (titleWidth / 2)
            local texttop = 2
            WindowText(
                windowId,
                'm',
                title,
                10,
                texttop,
                0,
                0,
                ColourNameToRGB(Core.GetSettingValue(Window, 'textcolor2'))
            )

            WindowText(
                windowId,
                'm',
                'O',
                windowWidth - 20,
                texttop,
                0,
                0,
                ColourNameToRGB(Core.GetSettingValue(Window, 'linkcolor'))
            )

            WindowAddHotspot(
                windowId,
                'contextmenu',
                windowWidth - 20,
                0,
                windowWidth,
                titleHeight,
                '',
                '',
                'OnTrackerWindowShowContextMenu',
                '',
                '',
                'Show Options', -- tooltip text
                1, -- hand cursor
                miniwin.hotspot_got_rh_mouse
            ) -- flags

            Window.Drawing.DrawView(titleHeight + 3 + rowSpacer, Views[Core.GetSettingValue(Window, 'view') + 1])

            WindowShow(windowId, Window.Visible)
        end,
        DrawView = function(ystart, view)
            local windowId = Core.GetSettingValue(Window, 'windowid')
            if (view == nil) then
                WindowText(
                    windowId,
                    's',
                    'No active views at the moment',
                    10,
                    30,
                    0,
                    0,
                    ColourNameToRGB(Core.GetSettingValue(Window, 'textcolor3'))
                )
                return
            end

            local oldCache = view.Cache
            view.Cache = view.Callback()
            if (view.Cache == nil) then
                view.Cache = oldCache
            end
            if (view.Cache == nil) then
                return
            end

            local windowWidth = Core.GetSettingValue(Window, 'width')
            local windowHeight = Core.GetSettingValue(Window, 'height')
            local lineHeight = WindowFontInfo(windowId, 's', 1)
            local rowspacer = Core.GetSettingValue(Window, 'rowspacer')
            local totalColumns = Core.GetSettingValue(Window, 'columns')
            local lineNumber = 0
            -- columns are in auto mode so.. lets just do something simple for now
            if (totalColumns == 0) then
                totalColumns = Core.Round((windowWidth / 150), 0)
            end

            -- subtract a bit of window width so we can have some border padding
            local columnSpacer = Core.GetSettingValue(Window, 'columnspacer')

            local xmargin = (windowWidth / 15) / 2
            local ymargin = rowspacer
            windowWidth = windowWidth - xmargin * 2

            -- figure out how big our columns are going to be
            local columnWidth = Core.Round(windowWidth / (totalColumns), 0) + (totalColumns + columnSpacer)

            local column = 0

            Core.Each(
                view.Cache,
                function(content)
                    local leftpos = (column * columnWidth) + xmargin
                    local toppos = ystart + ((lineNumber) * (lineHeight + ymargin))

                    local xoffset = 0
                    Core.Each(
                        content.Display,
                        function(d, i)
                            local subwidth = Core.Round((columnWidth / (#content.Display)), 0)
                            local charwidth = WindowTextWidth(windowId, 's', 'a', false)
                            local maxwidth = Core.Round((subwidth / charwidth), 0)
                            d = string.sub(d, 1, maxwidth)
                            local msgWidth = string.len(d)
                            -- is the text bigger than our subset
                            WindowText(
                                windowId,
                                's',
                                d,
                                leftpos + xoffset,
                                toppos,
                                0,
                                0,
                                ColourNameToRGB(Core.GetSettingValue(Window, content.ColorSetting))
                            )

                            xoffset = xoffset + subwidth
                        end
                    )

                    if ((content.Tooltip ~= nil and content.Tooltip ~= '') or content.OnClick ~= nil) then
                        local cursor = 0
                        if (content.OnClick ~= nil) then
                            cursor = 1
                        end
                        WindowAddHotspot(
                            windowId,
                            content.Id,
                            leftpos,
                            toppos,
                            leftpos + (columnWidth - 10),
                            toppos + lineHeight,
                            '',
                            '',
                            'OnWindowContentClick',
                            '',
                            '',
                            content.Tooltip or '',
                            cursor, -- hand cursor
                            0
                        )
                    end

                    column = column + 1
                    if (column >= totalColumns) then
                        lineNumber = lineNumber + 1
                        column = 0
                    end
                end
            )

            -- drawing our pager after content to ensure it is on top

            -- do we have a pager?

            if (view.Pager ~= nil) then
                local min = view.Pager.Min()
                local max = view.Pager.Max()
                local current = view.Pager.Current()

                if (min < max) then
                    -- Pager background
                    WindowCircleOp(
                        windowId,
                        3,
                        0,
                        windowHeight - (lineHeight + rowspacer),
                        Core.GetSettingValue(Window, 'width'),
                        windowHeight,
                        ColourNameToRGB(Core.GetSettingValue(Window, 'bordercolor')),
                        0,
                        0,
                        ColourNameToRGB(Core.GetSettingValue(Window, 'backcolor')),
                        0,
                        0,
                        0
                    )

                    local msgWidth = WindowTextWidth(windowId, 's', '<<', false)
                    local top = windowHeight - (lineHeight + rowspacer) + 2
                    local left = 10

                    -- left side
                    if (current > min) then
                        WindowText(
                            windowId,
                            's',
                            '<<',
                            left,
                            top,
                            0,
                            0,
                            ColourNameToRGB(Core.GetSettingValue(Window, 'linkcolor'))
                        )
                        WindowAddHotspot(
                            windowId,
                            'hs_pager_first',
                            left,
                            top,
                            left + msgWidth,
                            top + lineHeight,
                            '',
                            '',
                            'OnWindowPagerHandler',
                            '',
                            '',
                            'First',
                            1, -- hand cursor
                            0
                        )
                        left = left + msgWidth + 10

                        WindowText(
                            windowId,
                            's',
                            '<',
                            left,
                            top,
                            0,
                            0,
                            ColourNameToRGB(Core.GetSettingValue(Window, 'linkcolor'))
                        )
                        WindowAddHotspot(
                            windowId,
                            'hs_pager_newer',
                            left,
                            top,
                            left + msgWidth,
                            top + lineHeight,
                            '',
                            '',
                            'OnWindowPagerHandler',
                            '',
                            '',
                            'Newer',
                            1, -- hand cursor
                            0
                        )
                        left = left + msgWidth
                    end

                    local middleMsg = current .. ' / ' .. max
                    local middleWidth = WindowTextWidth(windowId, 's', middleMsg, false)
                    -- middle pager
                    WindowText(
                        windowId,
                        's',
                        middleMsg,
                        windowWidth / 2 - middleWidth / 2,
                        top,
                        0,
                        0,
                        ColourNameToRGB(Core.GetSettingValue(Window, 'linkcolor'))
                    )
                    WindowAddHotspot(
                        windowId,
                        'hs_pager_set',
                        (windowWidth / 2) - (middleWidth / 2),
                        top,
                        (windowWidth / 2) - (middleWidth / 2) + middleWidth,
                        windowHeight,
                        '',
                        '',
                        'OnWindowPagerHandler',
                        '',
                        '',
                        'Pick by number',
                        1, -- hand cursor
                        0
                    )

                    -- right side
                    if (current < max) then
                        left = 10
                        WindowText(
                            windowId,
                            's',
                            '>>',
                            windowWidth - left,
                            top,
                            0,
                            0,
                            ColourNameToRGB(Core.GetSettingValue(Window, 'linkcolor'))
                        )
                        WindowAddHotspot(
                            windowId,
                            'hs_pager_last',
                            windowWidth - left,
                            top,
                            (windowWidth - left) + msgWidth,
                            top + lineHeight,
                            '',
                            '',
                            'OnWindowPagerHandler',
                            '',
                            '',
                            'Last',
                            1, -- hand cursor
                            0
                        )
                        left = left + msgWidth

                        WindowText(
                            windowId,
                            's',
                            '>',
                            windowWidth - left,
                            top,
                            0,
                            0,
                            ColourNameToRGB(Core.GetSettingValue(Window, 'linkcolor'))
                        )
                        WindowAddHotspot(
                            windowId,
                            'hs_pager_older',
                            windowWidth - left,
                            top,
                            (windowWidth - left) + msgWidth,
                            top + lineHeight,
                            '',
                            '',
                            'OnWindowPagerHandler',
                            '',
                            '',
                            'Older',
                            1, -- hand cursor
                            0
                        )
                        left = left + msgWidth
                    end
                end
            end
        end,
        CreateContent = function(uid, msgs, tooltip, color, action)
            if (color == nil) then
                color = 'textcolor1'
            end
            return {Id = uid, Display = msgs, ColorSetting = color, Tooltip = tooltip, OnClick = action}
        end
    }
}

function OnWindowPagerHandler(a, name)
    local view = Views[Core.GetSettingValue(Window, 'view') + 1]
    if (view == nil or view.Pager == nil) then
        return
    end

    if (name == 'hs_pager_first') then
        if (view.Pager.First ~= nil) then
            view.Pager.First()
        end
    end
    if (name == 'hs_pager_newer') then
        if (view.Pager.Newer ~= nil) then
            view.Pager.Newer()
        end
    end
    if (name == 'hs_pager_older') then
        if (view.Pager.Older ~= nil) then
            view.Pager.Older()
        end
    end
    if (name == 'hs_pager_last') then
        if (view.Pager.Last ~= nil) then
            view.Pager.Last()
        end
    end

    if (name == 'hs_pager_set') then
        if (view.Pager.Set ~= nil) then
            view.Pager.Set()
        end
    end
end

function OnWindowContentClick(a, name)
    -- find content

    local view = Views[Core.GetSettingValue(Window, 'view') + 1]
    if (view == nil) then
        return
    end

    local content =
        Core.First(
        view.Cache,
        function(c)
            return c.Id == name
        end
    )

    if (content == nil or content.OnClick == nil) then
        return
    end

    content.OnClick()
end

function OnWindowMouseDown()
    local windowId = Core.GetSettingValue(Window, 'windowid')
    Window.MovingPositions.X = WindowInfo(windowId, 14)
    Window.MovingPositions.Y = WindowInfo(windowId, 15)
end

function OnWindowMove()
    local windowId = Core.GetSettingValue(Window, 'windowid')

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
    local windowId = Core.GetSettingValue(Window, 'windowid')
    local left = Core.GetSetting(Window, 'left')
    left.Value = WindowInfo(windowId, 10)

    local top = Core.GetSetting(Window, 'top')
    top.Value = WindowInfo(windowId, 11)

    Window.IsMoving = false
end

function OnTrackerWindowShowContextMenu()
    local windowId = Core.GetSettingValue(Window, 'windowid')

    local views = ''
    local selected = ''

    Core.Each(
        Views,
        function(v, i)
            if ((i - 1) == Core.GetSettingValue(Window, 'view')) then
                selected = '+'
            end
            views = views .. selected .. (i - 1) .. ' ' .. v.Name .. '|'
            selected = ''
        end
    )

    result =
        WindowMenu(
        windowId,
        WindowInfo(windowId, 14), -- x
        WindowInfo(windowId, 15), -- y
        '>View|' .. views .. '|<|Help'
    )

    if (result == 'Help') then
        Execute('pyre help')
        Execute('pyre help window')
    end

    Core.Each(
        Views,
        function(v, i)
            if (result == (i - 1) .. ' ' .. v.Name) then
                if ((i - 1) ~= Core.GetSettingValue(Window, 'view')) then
                    Execute('pyre set window view ' .. (i - 1))
                end
            end
        end
    )
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

function Window.RegisterView(name, drawingCallback, pager)
    Core.Log('View ' .. name .. ' registered in window.', Core.LogLevel.DEBUG)

    table.insert(Views, {Name = name, Pager = pager, Callback = drawingCallback, Cache = nil, LastUpdate = nil})
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

function Window.RegisterGlobal()
end

function Window.SetVisible(visible)
    Window.Visible = visible
    WindowShow(Core.GetSettingValue(Window, 'windowid'), visible)
end

return Window
