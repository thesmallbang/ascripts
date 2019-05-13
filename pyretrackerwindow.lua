local Pyre = require('pyrecore')
require('socket')

local WindowFeature = {
    lastSessionCacheUpdate = 0,
    lastAreaCacheUpdate = 0,
    lastAreaCacheIndex = 0,
    lastFightCacheUpdate = 0,
    lastFightCacheIndex = 0,
    sessionCache = nil,
    areaCache = nil,
    fightCache = nil,
    windowMoving = false,
    windowMoveStartX = 0,
    windowMoveStartY = 0,
    handleHeight = 15,
    visible = true,
    windowId = 'pyre_trackerwindow',
    AppVersion = '0.0',
    Tabs = {
        [0] = 'Session',
        [1] = 'Area',
        [2] = 'Fight'
    }
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
            local parsed = tonumber(val) or 3
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
    },
    {
        name = 'windowlayer',
        description = 'What layer of windows will this be drawn on top of',
        value = tonumber(GetVariable('trackerwindow_layer')) or 500,
        setValue = function(setting, val)
            local parsed = tonumber(val) or 500
            setting.value = parsed
            SetVariable('trackerwindow_layer', setting.value)
        end
    }
}

function WindowFeature.FeatureStart(featuresRunning, versionData)
    WindowFeature.AppVersion = versionData.release.version
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

    OnTrackerWindowShow()
end

function WindowFeature.FeatureStop()
    OnTrackerWindowHide()
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
                    {Value = command.description, Tooltip = command.description}
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
    if
        (socket.gettime() >=
            (WindowFeature.lastSessionCacheUpdate + Pyre.GetSettingValue(WindowFeature.Settings, 'interval', 3)))
     then
        if (Tracker.Session ~= nil and Tracker.Session.StartTime ~= nil) then
            WindowFeature.sessionCache = Tracker.Factory.CreateSessionSummary(Tracker.Session)
            WindowFeature.lastSessionCacheUpdate = socket.gettime()
        else
            WindowFeature.sessionCache = nil
        end
        if (Pyre.GetSettingValue(WindowFeature.Settings, 'view') == 0) then
            WindowFeature.DrawWindow()
        end
    end

    if
        (socket.gettime() >=
            (WindowFeature.lastAreaCacheUpdate + Pyre.GetSettingValue(WindowFeature.Settings, 'interval', 3)) or
            (Tracker.AreaIndex ~= WindowFeature.lastAreaCacheIndex))
     then
        local areaIndex = Tracker.AreaIndex
        local area = Tracker.GetAreaByIndex(areaIndex)
        if (area ~= nil and area.StartTime ~= nil) then
            WindowFeature.areaCache = Tracker.Factory.CreateAreaSummary(area)
            WindowFeature.lastAreaCacheUpdate = socket.gettime()
            WindowFeature.lastAreaCacheIndex = areaIndex
        else
            WindowFeature.areaCache = nil
        end
        if (Pyre.GetSettingValue(WindowFeature.Settings, 'view') == 1) then
            WindowFeature.DrawWindow()
        end
    end

    if
        (socket.gettime() >=
            (WindowFeature.lastFightCacheUpdate + Pyre.GetSettingValue(WindowFeature.Settings, 'interval', 3)) or
            (Tracker.FightIndex ~= WindowFeature.lastFightCacheIndex))
     then
        if (Pyre.GetSettingValue(WindowFeature.Settings, 'view') == 2) then
            WindowFeature.DrawWindow()
        end
    end
end

-- switch the view to show session/area/fight data
function WindowFeature.ChangeView(view)
end

-- Draw / Redraw our window with the latest information available
function WindowFeature.DrawWindow()
    if (WindowFeature.windowMoving == true or WindowFeature.visible ~= true) then
        return
    end

    WindowCreate(
        WindowFeature.windowId,
        tonumber(GetVariable('win_' .. WindowFeature.windowId .. '_x')) or 50,
        tonumber(GetVariable('win_' .. WindowFeature.windowId .. '_y')) or 50,
        tonumber(GetVariable('win_' .. WindowFeature.windowId .. '_x2')) or 400,
        tonumber(GetVariable('win_' .. WindowFeature.windowId .. '_y2')) or 200,
        0,
        miniwin.create_absolute_location,
        ColourNameToRGB('black')
    ) -- create window

    WindowFeature.AddFonts()

    WindowSetZOrder(WindowFeature.windowId, Pyre.GetSettingValue(WindowFeature.Settings, 'windowlayer', 10))

    WindowShow(WindowFeature.windowId, true)

    -- Primary Window Border
    WindowCircleOp(
        WindowFeature.windowId,
        3,
        0,
        0,
        WindowInfo(WindowFeature.windowId, 3),
        WindowInfo(WindowFeature.windowId, 4),
        ColourNameToRGB('teal'),
        0,
        0,
        ColourNameToRGB('transparent'),
        0,
        0,
        0
    )

    -- title bar seperator line
    WindowLine(
        WindowFeature.windowId,
        0,
        WindowFeature.handleHeight + 3,
        WindowInfo(WindowFeature.windowId, 3),
        WindowFeature.handleHeight + 3,
        ColourNameToRGB('teal'),
        0,
        1
    )

    -- title bar drag + text
    WindowFeature.DrawTitle(
        'PH Tracker v' ..
            WindowFeature.AppVersion ..
                ' - ' .. WindowFeature.Tabs[Pyre.GetSettingValue(WindowFeature.Settings, 'view')]
    )

    -- draw options + context setup
    WindowFeature.DrawTextLine(1, 'O', WindowInfo(WindowFeature.windowId, 3) - WindowFeature.handleHeight, nil, 'su')
    WindowAddHotspot(
        WindowFeature.windowId,
        'contextmenu',
        WindowInfo(WindowFeature.windowId, 3) - WindowFeature.handleHeight,
        0,
        WindowInfo(WindowFeature.windowId, 3),
        WindowFeature.handleHeight,
        '',
        '',
        'OnTrackerWindowShowContextMenu',
        '',
        '',
        'Show Options', -- tooltip text
        1, -- hand cursor
        miniwin.hotspot_got_rh_mouse
    ) -- flags

    -- draw view
    local view = Pyre.GetSettingValue(WindowFeature.Settings, 'view', 0)
    Pyre.Switch(view) {
        [0] = function()
            WindowFeature.DrawSessionView()
        end,
        [1] = function()
            WindowFeature.DrawAreaView()
        end,
        [2] = function()
            WindowFeature.DrawFightView()
        end
    }
end

-- draw app name / version with draggable hotspot to move window
function WindowFeature.DrawTitle(title)
    WindowAddHotspot(
        WindowFeature.windowId,
        'movewindowhs',
        0,
        0,
        WindowInfo(WindowFeature.windowId, 3) - WindowFeature.handleHeight,
        WindowFeature.handleHeight, -- rectangle
        '',
        '',
        'OnTrackerWindowTitleMouseDown',
        '',
        '',
        'Drag to move window', -- tooltip text
        10, -- hand cursor
        0
    ) -- flags
    WindowDragHandler(
        WindowFeature.windowId,
        'movewindowhs',
        'OnTrackerWindowMove',
        'OnTrackerWindowTitleMoveRelease',
        0
    )

    local titleWidth = WindowTextWidth(WindowFeature.windowId, 'm', title, false)
    local windowWidth = WindowInfo(WindowFeature.windowId, 3)
    local left = (windowWidth / 2) - (titleWidth / 2)

    WindowFeature.DrawTextLine(1, title, left, ColourNameToRGB('white'))
end

function OnTrackerWindowTitleMouseDown(flags, hotspot_id)
    WindowFeature.windowMoveStartX, WindowFeature.windowMoveStartY =
        WindowInfo(WindowFeature.windowId, 14),
        WindowInfo(WindowFeature.windowId, 15)
end

function OnTrackerWindowTitleMoveRelease(flags, hotspot_id)
    SetVariable('win_' .. WindowFeature.windowId .. '_x', WindowInfo(WindowFeature.windowId, 10))
    SetVariable('win_' .. WindowFeature.windowId .. '_y', WindowInfo(WindowFeature.windowId, 11))
    WindowFeature.windowMoving = false
end

function OnTrackerWindowMove(flags, hotspot_id)
    local posx, posy = WindowInfo(WindowFeature.windowId, 17), WindowInfo(WindowFeature.windowId, 18)
    WindowFeature.windowMoving = true
    if posx < 0 or posx > GetInfo(281) or posy < 0 or posy > GetInfo(280) then
        check(SetCursor(11)) -- X cursor
    else
        check(SetCursor(10)) -- move cursor
        -- move the window to the new location
        WindowPosition(
            WindowFeature.windowId,
            posx - WindowFeature.windowMoveStartX,
            posy - WindowFeature.windowMoveStartY,
            0,
            2
        )
    end -- if
end

function OnTrackerWindowShowContextMenu(flags, hotspot_id)
    local nameAndCheckedTab = function(name)
        local checked = ''
        if (name == 'Session' and Pyre.GetSettingValue(WindowFeature.Settings, 'view') == 0) then
            checked = '+'
        end
        if (name == 'Area' and Pyre.GetSettingValue(WindowFeature.Settings, 'view') == 1) then
            checked = '+'
        end
        if (name == 'Fight' and Pyre.GetSettingValue(WindowFeature.Settings, 'view') == 2) then
            checked = '+'
        end
        return checked .. name
    end

    result =
        WindowMenu(
        WindowFeature.windowId,
        WindowInfo(WindowFeature.windowId, 14), -- x
        WindowInfo(WindowFeature.windowId, 15), -- y
        '>View|' ..
            nameAndCheckedTab('Session') ..
                '|' .. nameAndCheckedTab('Area') .. '|' .. nameAndCheckedTab('Fight') .. '|<|Help'
    )

    if (result == 'Help') then
        Execute('pyre help tracker')
        Execute('pyre help trackerwindow')
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

function WindowFeature.AddFonts()
    WindowFont(WindowFeature.windowId, 'l', 'Trebuchet MS', 12, false, false, false, false)
    WindowFont(WindowFeature.windowId, 'm', 'Trebuchet MS', 10, false, false, false, false)
    WindowFont(WindowFeature.windowId, 'mb', 'Trebuchet MS', 10, true, false, false, false)
    WindowFont(WindowFeature.windowId, 's', 'Trebuchet MS', 8, false, false, false, false)
    WindowFont(WindowFeature.windowId, 'sb', 'Trebuchet MS', 8, true, false, false, false)
    WindowFont(WindowFeature.windowId, 'su', 'Trebuchet MS', 8, false, false, true, false)
end

function WindowFeature.DrawTextLine(line, text, left, colour, fontid)
    left = left or 10
    local top = 2
    if (line > 1) then
        top = 3 + ((line - 1) * 20)
    end

    if (colour == nil) then
        colour = ColourNameToRGB('white')
    end
    fontid = fontid or 's'
    if (text == nil) then
        text = ''
    end

    WindowText(WindowFeature.windowId, fontid, text, left, top, 0, 0, colour)
end -- Display_Line

-- draw message at center of window that the selected view doesnt have any cached data yet
function WindowFeature.DrawWaitingForData()
    local data = 'Waiting on data.'
    local titleWidth = WindowTextWidth(WindowFeature.windowId, 'm', data, false)
    local windowWidth = WindowInfo(WindowFeature.windowId, 3)
    local left = (windowWidth / 2) - (titleWidth / 2)
    WindowFeature.DrawTextLine(5, data, left, ColourNameToRGB('red'), 'm')
end

-- draw our session data on the window
function WindowFeature.DrawSessionView()
    local session = WindowFeature.sessionCache
    if (session == nil) then
        WindowFeature.DrawWaitingForData()
        return
    end

    WindowFeature.DrawTextLine(2, 'SESSION', nil, ColourNameToRGB('teal'), 'm')
    WindowFeature.DrawTextLine(2, Pyre.SecondsToClock(session.Normal.Duration), 340, ColourNameToRGB('teal'), 'm')

    WindowFeature.DrawTextLine(3, 'Exp')
    WindowFeature.DrawTextLine(3, session.Experience, 50)

    WindowFeature.DrawTextLine(3, 'Rare', 140)
    WindowFeature.DrawTextLine(3, session.RareExperience, 180)

    WindowFeature.DrawTextLine(3, 'Bonus', 280)
    WindowFeature.DrawTextLine(3, session.BonusExperience, 320)

    WindowFeature.DrawTextLine(4, 'Norm')
    WindowFeature.DrawTextLine(4, session.NormalExperience, 50)

    WindowFeature.DrawTextLine(4, 'Fights', 140)
    WindowFeature.DrawTextLine(4, session.Fights, 180)

    WindowFeature.DrawTextLine(4, 'Souls', 280)
    WindowFeature.DrawTextLine(4, session.Souls, 320)

    WindowFeature.DrawTextLine(5, 'XPM')
    WindowFeature.DrawTextLine(5, session.Normal.ExpPerMinute, 50)

    WindowFeature.DrawTextLine(5, 'XPCM', 140)
    WindowFeature.DrawTextLine(5, session.Combat.ExpPerMinute, 180)

    WindowFeature.DrawTextLine(5, 'SPF', 280)
    WindowFeature.DrawTextLine(5, session.AverageSoulsPerFight, 320)

    WindowFeature.DrawTextLine(6, 'Dmg')
    WindowFeature.DrawTextLine(6, session.PlayerDamage, 50)

    WindowFeature.DrawTextLine(6, 'DPS', 140)
    WindowFeature.DrawTextLine(6, session.Normal.PlayerDps, 180)

    WindowFeature.DrawTextLine(6, 'DPCS', 280)
    WindowFeature.DrawTextLine(6, session.Combat.PlayerDps, 320)
end

-- draw our area data on the window
function WindowFeature.DrawAreaView()
    local area = WindowFeature.areaCache
    if (area == nil) then
        WindowFeature.DrawWaitingForData()
        return
    end

    WindowFeature.DrawTextLine(2, area.Area, nil, ColourNameToRGB('teal'), 'm')
    WindowFeature.DrawTextLine(2, Pyre.SecondsToClock(area.Normal.Duration), 340, ColourNameToRGB('teal'), 'm')

    WindowFeature.DrawTextLine(3, 'Exp')
    WindowFeature.DrawTextLine(3, area.Experience, 50)

    WindowFeature.DrawTextLine(3, 'Rare', 140)
    WindowFeature.DrawTextLine(3, area.RareExperience, 180)

    WindowFeature.DrawTextLine(3, 'Bonus', 280)
    WindowFeature.DrawTextLine(3, area.BonusExperience, 320)

    WindowFeature.DrawTextLine(4, 'Norm')
    WindowFeature.DrawTextLine(4, area.NormalExperience, 50)

    WindowFeature.DrawTextLine(4, 'Fights', 140)
    WindowFeature.DrawTextLine(4, area.Fights, 180)

    WindowFeature.DrawTextLine(4, 'Souls', 280)
    WindowFeature.DrawTextLine(4, area.Souls, 320)

    WindowFeature.DrawTextLine(5, 'XPM')
    WindowFeature.DrawTextLine(5, area.Normal.ExpPerMinute, 50)

    WindowFeature.DrawTextLine(5, 'XPCM', 140)
    WindowFeature.DrawTextLine(5, area.Combat.ExpPerMinute, 180)

    WindowFeature.DrawTextLine(5, 'SPF', 280)
    WindowFeature.DrawTextLine(5, area.AverageSoulsPerFight, 320)

    WindowFeature.DrawTextLine(6, 'Dmg')
    WindowFeature.DrawTextLine(6, area.PlayerDamage, 50)

    WindowFeature.DrawTextLine(6, 'DPS', 140)
    WindowFeature.DrawTextLine(6, area.Normal.PlayerDps, 180)

    WindowFeature.DrawTextLine(6, 'DPCS', 280)
    WindowFeature.DrawTextLine(6, area.Combat.PlayerDps, 320)
end

-- draw our fight data on the window
function WindowFeature.DrawFightView()
    local fight = WindowFeature.fightCache
    if (fight == nil) then
        WindowFeature.DrawWaitingForData()
        return
    end
end

function OnTrackerWindowShow()
    WindowFeature.visible = true
    WindowShow(WindowFeature.windowId, true)
end
function OnTrackerWindowHide()
    WindowFeature.visible = false
    WindowShow(WindowFeature.windowId, false)
end

return WindowFeature
