local swindow = {}

swindow.Alignments = {
    Start = 0,
    Center = 1,
    End = 2
}

swindow.ContainerStyles = {
    Column = 0,
    Row = 1,
    RowWrap = 2
}

local D_FONT = 'Lucida Console'
local D_FONTSIZE = 9
local D_FONTCOLOR = ColourNameToRGB('white')
local D_BACKCOLOR = ColourNameToRGB('black')
local D_WIDTH = 300
local D_HEIGHT = 300
local D_LAYER = 100
local D_UPDATEINTERVAL = 1
local D_LEFT = 0
local D_TOP = 0
local D_TITLE = 'Simple Window by Tamon'
local D_BORDERWIDTH = 1
local D_TITLEALIGNMENT = swindow.Alignments.Start
local D_SAVESTATE = true
local D_ALLOWRESIZE = true
local D_MINWIDTH = 100
local D_MINHEIGHT = 50
local D_CONTAINERSTYLE = swindow.ContainerStyles.Column
local D_CONTAINERALIGNMENT = swindow.Alignments.Start
local D_CONTAINERSPACING = 3

local function isModuleAvailable(name)
    if package.loaded[name] then
        return true
    else
        for _, searcher in ipairs(package.searchers or package.loaders) do
            local loader = searcher(name)
            if type(loader) == 'function' then
                package.preload[name] = loader
                return true
            end
        end
        return false
    end
end

swindow.CreateWindow = function(config, theme)
    -- THE OPTIONS PASSED IN ON CONFIG MAY NOT RESPOND TO CHANGES AFTER CREATION

    local window = {
        __state = {
            views = {},
            viewIndex = 1, -- the currently "selected" view
            lastDraw = 0, -- time we last drew the window
            lastDrawConfig = nil, -- the config when we last drew our window, used to detect/apply window changes like updating a layer
            isMoving = false,
            isResizing = false,
            canMove = true,
            movingPositions = {X = 0, Y = 0},
            resizePositions = {X = 0, Y = 0},
            fontsLoaded = false,
            contentTop = 10,
            contentLeft = 10
        }
    }

    window.Config = config or swindow.CreateConfig()
    window.Theme = theme or swindow.CreateTheme()

    if (window.Config.SaveState == true) then
        window.Config.Left = tonumber(GetVariable(window.Config.Id .. '_left')) or window.Config.Left
        window.Config.Top = tonumber(GetVariable(window.Config.Id .. '_top')) or window.Config.Top
        window.Config.Width = tonumber(GetVariable(window.Config.Id .. '_width')) or window.Config.Width
        window.Config.Height = tonumber(GetVariable(window.Config.Id .. '_height')) or window.Config.Height
    end

    --------------------------------------------------
    -- Assign all the methods to our window function -
    --------------------------------------------------

    function window.RegisterView(view)
        table.insert(window.__state.views, view)
    end

    function window.GetTextStyle(name)
        local textStyle = nil

        if (name ~= nil) then
            for key, value in pairs(window.Theme.TextStyles) do
                if (textStyle == nil and key == name) then
                    textStyle = value
                end
            end
        end

        if (textStyle == nil) then
            for key, value in pairs(window.Theme.TextStyles) do
                if (textStyle == nil and value.Default == true) then
                    textStyle = value
                end
            end
        end

        if (textStyle == nil) then
            textStyle = window.Theme.TextStyles[0]
        end

        return textStyle
    end

    function window.GetTextWidth(textStyle, text)
        if (type(textStyle) ~= 'string') then
            textStyle = textStyle.Name
        end

        return WindowTextWidth(window.Config.Id, textStyle, text, false)
    end
    function window.GetTextHeight(textStyle)
        if (type(textStyle) ~= 'string') then
            textStyle = textStyle.Name
        end
        return WindowFontInfo(window.Config.Id, textStyle, 1)
    end

    function window.Tick()
        if (window.__state.isMoving or window.__state.isResizing) then
            return
        end

        local view = window.__state.views[window.__state.viewIndex]

        if (window.__state.lastDraw > (os.time() - 3)) then
            if (view ~= nil) then
                view.Containers = nil
            end
            return
        end

        window.__state.lastDraw = os.time()
        window.DrawWindow()

        if (window.__state.views == nil or #window.__state.views == 0) then
            window.DrawText {
                Text = 'No views are registered',
                TextStyle = window.GetTextStyle(),
                BackColor = 'red'
            }
            return
        end

        if (view == nil) then
            window.DrawText {
                Text = 'Invalid view state',
                TextStyle = window.GetTextStyle(),
                BackColor = 'red'
            }
            return
        end

        view.Draw()
    end

    function window.CreateView(options)
        local view = {Name = options.Name or 'A View', Containers = nil}

        view.Sizes =
            options.Sizes or
            {
                {Name = 'sm', To = 200},
                {Name = 'md', To = 300},
                {Name = 'lg', To = 500}
            }

        view.QuerySize = function()
            local size = {To = 0}

            for _, s in ipairs(view.Sizes) do
                if (s.To > size.To and window.Config.Width > size.To and window.Config.Width <= s.To) then
                    size = s
                end
            end
            if (size.Name == nil) then
                size = view.Sizes[#view.Sizes] -- take the last one
            end

            if (size.Name == nil) then
                assert('responsive query sizes are not configured (view.Sizes)')
                return
            end
            return size
        end

        view.OnUpdate = options.OnUpdate

        view.Draw = function(options)
            -- no content yet or we cache expired
            if (view.Containers == nil) then
                if (view.OnUpdate ~= nil) then
                    view:OnUpdate()
                end
            end

            -- ok now finally working on drawing some content...

            local viewBox = {
                Left = window.__state.contentLeft,
                Top = window.__state.contentTop,
                Right = (window.Config.Width - window.__state.contentLeft),
                Bottom = (window.Config.Height - window.__state.contentLeft)
            }

            local cursorInViewBox = {
                X = 0,
                Y = 0
            }

            local size = view.QuerySize()
            if (size == nil) then
                print('no size')
                return
            end
            local containerheight = 0
            for ic, container in ipairs(view.Containers) do
                -- query our current width and get the appropriate size
                -- for now we will just hope they are added in the correct detection order... smallest to largest
                local sizePercent = container.GetSizePercent(size.Name) or 1
                local containerwidth = ((viewBox.Right - viewBox.Left) / 100) * sizePercent

                local containerBox = {
                    Left = viewBox.Left + cursorInViewBox.X,
                    Top = viewBox.Top + cursorInViewBox.Y
                }
                containerBox.Right = containerBox.Left + containerwidth

                if (container.Height ~= nil) then
                    containerBox.Bottom = containerBox.Top + container.Height
                else
                    containerBox.Bottom = viewBox.Bottom
                end

                if (containerBox.Right > viewBox.Right) then
                    containerBox.Right = viewBox.Right
                end
                if (containerBox.Bottom > viewBox.Bottom) then
                    containerBox.Bottom = viewBox.Bottom
                end

                local cursorInContainerBox = {X = 0, Y = 0}

                local allcontentheight = 0
                local rowCompleted = false
                for _, content in pairs(container.Content) do
                    local contentBox = {
                        Left = containerBox.Left + cursorInContainerBox.X,
                        Top = containerBox.Top + cursorInContainerBox.Y
                    }

                    local sizePercent = content.GetSizePercent(size.Name) or 1
                    local contentwidth = ((containerBox.Right - containerBox.Left) / 100) * sizePercent
                    local contentheight = window.GetTextHeight(content.TextStyle)
                    contentBox.Right = contentBox.Left + contentwidth
                    contentBox.Bottom = contentBox.Top + contentheight

                    if (rowCompleted == false) then
                        window.DrawText {
                            Text = content.Text,
                            Bounds = contentBox,
                            TextStyle = content.TextStyle,
                            FontColor = content.FontColor,
                            BackColor = content.BackColor
                        }
                    end

                    cursorInContainerBox.X = cursorInContainerBox.X + contentwidth

                    -- auto go to next row
                    if (container.Style == swindow.ContainerStyles.Column) then
                        cursorInContainerBox.Y = cursorInContainerBox.Y + (contentBox.Bottom - contentBox.Top)
                        cursorInContainerBox.X = 0
                        allcontentheight = allcontentheight + contentheight
                    end

                    if (container.Style == swindow.ContainerStyles.RowWrap) then
                        if (cursorInContainerBox.X >= (containerBox.Right - containerBox.Left)) then
                            cursorInContainerBox.X = 0
                            cursorInContainerBox.Y = cursorInContainerBox.Y + contentheight
                            allcontentheight = allcontentheight + contentheight
                        end
                    end

                    if (container.Style == swindow.ContainerStyles.Row) then
                        allcontentheight = contentheight
                        if (cursorInContainerBox.X + 1 >= (containerBox.Right - containerBox.Left)) then
                            rowCompleted = true
                        end
                    end
                end

                if (allcontentheight > containerheight) then
                    containerheight = allcontentheight
                end

                cursorInViewBox.X = cursorInViewBox.X + containerwidth

                if (cursorInViewBox.X + 1 >= (viewBox.Right - viewBox.Left)) then
                    cursorInViewBox.X = 0
                    cursorInViewBox.Y = cursorInViewBox.Y + containerheight
                    containerheight = 0
                end
            end
        end

        view.AddContainer = function(options)
            view.Containers = view.Containers or {}

            local container = {}

            container.Name = container.Name or 'Lorem ipsum'
            container.Style = options.Style or D_CONTAINERSTYLE
            container.Height = options.Height
            container.Alignment = options.Alignment or D_CONTAINERALIGNMENT
            container.Spacing = options.Spacing or D_CONTAINERSPACING
            container.Content = options.Content or {}
            container.BackColor = options.BackColor

            if (type(container.BackColor) == 'string') then
                container.BackColor = ColourNameToRGB(container.BackColor)
            end

            container.Sizes =
                options.Sizes or
                {
                    {Name = 'sm', Percent = 100}
                }
            container.GetSizePercent = function(name)
                local potential = nil
                for _, s in ipairs(container.Sizes) do
                    if (s.Name == name) then
                        return s.Percent
                    else
                        potential = s.Percent
                    end
                end
                return potential
            end
            container.Bounds =
                options.Bounds or
                {
                    Left = window.Config.BorderWidth + window.Config.BodyPadding,
                    Top = window.Config.BorderWidth + window.Config.BodyPadding,
                    Right = window.Config.Width - (window.Config.BorderWidth + window.Config.BodyPadding),
                    Bottom = window.Config.Height - (window.Config.BorderWidth + window.Config.BodyPadding)
                }

            container.AddContent = function(options)
                container.Content = container.Content or {}

                local content = {}
                content.Id = options.Id or 'content_' .. math.random(1, 100000)
                content.Text = options.Text or 'Lorem ipsum'
                content.TextStyle = options.TextStyle
                content.Alignment = options.Alignment or container.Alignment or D_CONTAINERALIGNMENT
                content.Sizes =
                    options.Sizes or
                    {
                        {Name = 'sm', Percent = 100}
                    }
                content.GetSizePercent = function(name)
                    local potential = nil
                    for _, s in ipairs(content.Sizes) do
                        if (s.Name == name) then
                            return s.Percent
                        else
                            potential = s.Percent
                        end
                    end
                    return potential
                end
                if (content.TextStyle == nil or type(content.TextStyle) == 'string') then
                    content.TextStyle = window.GetTextStyle(content.TextStyle)
                end
                content.BackColor = options.BackColor or content.TextStyle.BackColor or theme.BackColor
                content.FontColor = options.FontColor or content.TextStyle.FontColor or theme.FontColor
                table.insert(container.Content, content)
                return content
            end

            table.insert(view.Containers, container)
            return container
        end

        return view
    end

    function window.DrawWindow()
        local lastConfig = window.__state.lastDrawConfig
        local drawConfig = window.Config

        -- we could give it a default but it's a teachable moment
        assert(drawConfig ~= nil, 'A configuration was not supplied to the window')
        assert(drawConfig.Id ~= nil and drawConfig.Id ~= '', 'Invalid id for a window')

        -- check previous config for changes we can apply before the window is created
        if (lastConfig ~= nil and lastConfig.Id ~= drawConfig.Id) then
            -- we need to remove the last window id
            WindowDelete(lastConfig.Id)
            window.__state.fontsLoaded = false
        end

        -- create our window
        WindowCreate(
            drawConfig.Id,
            drawConfig.Left,
            drawConfig.Top,
            drawConfig.Width,
            drawConfig.Height,
            0,
            miniwin.create_absolute_location + miniwin.create_keep_hotspots,
            window.Theme.BackColor
        )

        -- do we have fonts to load?
        -- we could just look through the text styles here for a loaded flag to catch new ones but i'm not sure i want that atm
        if (window.__state.fontsLoaded == false) then
            for _, textStyle in pairs(window.Theme.TextStyles) do
                WindowFont(
                    drawConfig.Id,
                    textStyle.Name,
                    textStyle.Font,
                    textStyle.FontSize,
                    textStyle.Bold or false,
                    textStyle.Italic or false,
                    textStyle.Underline or false,
                    textStyle.Strike or false,
                    textStyle.Charset or 1,
                    textStyle.Family or 0
                )
            end
        end

        -- check previous configs for changes we can apply after the window was created
        if (lastConfig == nil or lastConfig.Visible ~= drawConfig.Visible) then
            WindowShow(drawConfig.Id, drawConfig.Visible)
        end
        if (lastConfig == nil or lastConfig.Layer ~= drawConfig.Layer) then
            WindowSetZOrder(drawConfig.Id, drawConfig.Layer)
        end

        -- draw border
        WindowCircleOp(
            drawConfig.Id,
            2,
            0,
            0,
            drawConfig.Width,
            drawConfig.Height,
            window.Theme.BorderColor,
            0,
            drawConfig.BorderWidth,
            window.Theme.BackColor
        )

        -- draw our window title
        if (drawConfig.Title ~= nil) then
            local v = window.__state.views[0] or {}
            local vname = v.Name or ''

            local tstyle = window.GetTextStyle('title')
            local title = string.gsub(drawConfig.Title, ' {viewname}', vname)

            local drawnPosition =
                window.DrawText {
                Text = title,
                BackAttached = true,
                Bounds = {
                    Left = (drawConfig.BorderWidth + drawConfig.TitlePadding),
                    Top = (drawConfig.BorderWidth + drawConfig.TitlePadding),
                    Right = window.Config.Width - (drawConfig.BorderWidth + drawConfig.TitlePadding),
                    Bottom = window.Config.Height - (drawConfig.BorderWidth + drawConfig.TitlePadding)
                },
                Alignment = {X = drawConfig.TitleAlignment, Y = swindow.Alignments.Start},
                TextStyle = tstyle
            }

            tleft = drawnPosition.Left
            ttop = drawnPosition.Top
            local tright = (drawnPosition.Right or 0) + drawConfig.BorderWidth + drawConfig.TitlePadding
            local tbottom = (drawnPosition.Bottom or 0) + drawConfig.BorderWidth + drawConfig.TitlePadding

            _G['TitleMouseDown' .. window.Config.Id] = function(flags)
                if bit.band(flags, 0x10) ~= 0 then
                    window.__state.movingPositions.X = WindowInfo(window.Config.Id, 14)
                    window.__state.movingPositions.Y = WindowInfo(window.Config.Id, 15)
                else
                    print('show options')
                end
            end
            _G['TitleMoveStart' .. window.Config.Id] = function(flags)
                if bit.band(flags, 0x10) == 0 then
                    return
                end

                local posx = WindowInfo(window.Config.Id, 17)
                local posy = WindowInfo(window.Config.Id, 18)
                window.__state.isMoving = true
                if posx < 0 or posx > GetInfo(281) or posy < 0 or posy > GetInfo(280) then
                    check(SetCursor(11)) -- X cursor
                else
                    check(SetCursor(10)) -- move cursor
                    -- move the window to the new location
                    WindowPosition(
                        window.Config.Id,
                        posx - window.__state.movingPositions.X,
                        posy - window.__state.movingPositions.Y,
                        0,
                        2
                    )
                end
            end
            _G['TitleMoveStop' .. window.Config.Id] = function()
                window.__state.isMoving = false
                window.Config.Left = WindowInfo(window.Config.Id, 10)
                window.Config.Top = WindowInfo(window.Config.Id, 11)

                if (window.Config.SaveState == true) then
                    SetVariable(window.Config.Id .. '_left', window.Config.Left)
                    SetVariable(window.Config.Id .. '_top', window.Config.Top)
                    SetVariable(window.Config.Id .. '_width', window.Config.Width)
                    SetVariable(window.Config.Id .. '_height', window.Config.Height)
                end
            end

            WindowAddHotspot(
                drawConfig.Id,
                'titlehs',
                tleft,
                ttop,
                tright,
                tbottom,
                '',
                '',
                'TitleMouseDown' .. window.Config.Id,
                '',
                '',
                'Left click to move. Right click for options',
                1,
                0
            )
            WindowDragHandler(
                drawConfig.Id,
                'titlehs',
                'TitleMoveStart' .. window.Config.Id,
                'TitleMoveStop' .. window.Config.Id,
                0
            )

            tbottom = tbottom + drawConfig.TitlePadding + drawConfig.BorderWidth

            -- draw our title line
            WindowLine(
                drawConfig.Id,
                0,
                tbottom,
                drawConfig.Width,
                tbottom,
                window.Theme.BorderColor,
                0,
                drawConfig.BorderWidth
            )

            if (drawConfig.AllowResize == true) then
                -- draw our resizer
                WindowLine(
                    drawConfig.Id,
                    drawConfig.Width - drawConfig.BorderWidth,
                    drawConfig.Height - drawConfig.BorderWidth - 2,
                    drawConfig.Width - drawConfig.BorderWidth - 2,
                    drawConfig.Height - drawConfig.BorderWidth,
                    window.Theme.BorderColor,
                    0 and 0x1000,
                    1
                )
                WindowLine(
                    drawConfig.Id,
                    drawConfig.Width - drawConfig.BorderWidth,
                    drawConfig.Height - drawConfig.BorderWidth - 5,
                    drawConfig.Width - drawConfig.BorderWidth - 5,
                    drawConfig.Height - drawConfig.BorderWidth,
                    window.Theme.BorderColor,
                    0 and 0x1000,
                    1
                )
                WindowLine(
                    drawConfig.Id,
                    drawConfig.Width - drawConfig.BorderWidth,
                    drawConfig.Height - drawConfig.BorderWidth - 8,
                    drawConfig.Width - drawConfig.BorderWidth - 8,
                    drawConfig.Height - drawConfig.BorderWidth,
                    window.Theme.BorderColor,
                    0 and 0x1000,
                    1
                )

                _G['ResizeMouseDown' .. window.Config.Id] = function(flags)
                    window.__state.resizePositions.X = WindowInfo(window.Config.Id, 14) -- window.Config.Left
                    window.__state.resizePositions.Y = WindowInfo(window.Config.Id, 15) -- window.Config.Top
                end
                _G['ResizeStart' .. window.Config.Id] = function(flags)
                    local posx = WindowInfo(window.Config.Id, 17) - window.Config.Left
                    local posy = WindowInfo(window.Config.Id, 18) - window.Config.Top

                    window.__state.isResizing = true

                    window.Config.Width = posx
                    window.Config.Height = posy
                    WindowResize(window.Config.Id, window.Config.Width, window.Config.Height, 35434)
                    -- draw border
                    WindowCircleOp(
                        drawConfig.Id,
                        2,
                        0,
                        0,
                        drawConfig.Width,
                        drawConfig.Height,
                        window.Theme.BorderColor,
                        0,
                        drawConfig.BorderWidth,
                        ColourNameToRGB('gold'),
                        6
                    )
                    window.DrawText {
                        Text = 'X: ' .. window.Config.Width .. ' Y: ' .. window.Config.Height,
                        BackColor = 'white',
                        FontColor = 'black',
                        TextStyle = window.GetTextStyle(),
                        BackAttached = true,
                        Bounds = {
                            Left = 0,
                            Top = 0,
                            Right = window.Config.Width,
                            Bottom = window.Config.Height
                        },
                        Alignment = {
                            X = swindow.Alignments.Center,
                            Y = swindow.Alignments.Center
                        }
                    }

                    Redraw()
                end
                _G['ResizeStop' .. window.Config.Id] = function()
                    window.__state.isResizing = false
                    window.__state.lastDraw = 0
                    if (window.Config.SaveState == true) then
                        SetVariable(window.Config.Id .. '_left', window.Config.Left)
                        SetVariable(window.Config.Id .. '_top', window.Config.Top)
                        SetVariable(window.Config.Id .. '_width', window.Config.Width)
                        SetVariable(window.Config.Id .. '_height', window.Config.Height)
                    end
                end

                WindowAddHotspot(
                    drawConfig.Id,
                    'resizehs',
                    drawConfig.Width - drawConfig.BorderWidth - 8,
                    drawConfig.Height - drawConfig.BorderWidth - 8,
                    drawConfig.Width - drawConfig.BorderWidth,
                    drawConfig.Height - drawConfig.BorderWidth,
                    '',
                    '',
                    'ResizeMouseDown' .. window.Config.Id,
                    '',
                    '',
                    'Drag to resize window',
                    6,
                    0
                )
                WindowDragHandler(
                    drawConfig.Id,
                    'resizehs',
                    'ResizeStart' .. window.Config.Id,
                    'ResizeStop' .. window.Config.Id,
                    0
                )
            end

            window.__state.contentTop = tbottom + drawConfig.BorderWidth + drawConfig.BodyPadding
            window.__state.contentLeft = drawConfig.BorderWidth + drawConfig.BodyPadding
        end
    end

    function window.DrawText(options)
        --  id, txt, textStyle, pos, tooltip, action
        options = options or {}

        if (options.TextStyle == nil) then
            options.TextStyle = window.GetTextStyle()
            assert(options.TextStyle ~= nil, 'Attempted to draw text with no matching style or default')
        end

        if (type(options.TextStyle) == 'string') then
            options.TextStyle = window.GetTextStyle(options.TextStyle)
        end
        if (type(options.FontColor) == 'string') then
            options.FontColor = ColourNameToRGB(options.FontColor)
        end
        options.Alignment = options.Alignment or {X = swindow.Alignments.Start, Y = swindow.Alignments.Start}
        options.Bounds = options.Bounds or {}

        options.Bounds.Left = options.Bounds.Left or window.__state.contentLeft
        options.Bounds.Top = options.Bounds.Top or window.__state.contentTop
        options.Bounds.Right = options.Bounds.Right or window.Config.Width
        options.Bounds.Bottom = options.Bounds.Bottom or window.Config.Height

        if (options.BackAttached == nil) then
            options.BackAttached = false
        end

        options.Text = options.Text or 'Omnium enim rerum principia parva sunt'
        local textWidth = window.GetTextWidth(options.TextStyle, options.Text)
        local textHeight = window.GetTextHeight(options.TextStyle)

        -- by default everything is setup for start/start alignments so we just need to tweak positions for the rest
        local left = options.Bounds.Left
        local top = options.Bounds.Top

        if (options.Alignment.X == swindow.Alignments.Center) then
            left = (options.Bounds.Right - (options.Bounds.Left + textWidth)) / 2
        end
        if (options.Alignment.X == swindow.Alignments.End) then
            left = (options.Bounds.Right - textWidth)
        end

        if (options.Alignment.Y == swindow.Alignments.Center) then
            top = (options.Bounds.Bottom - (options.Bounds.Top + textHeight)) / 2
        end
        if (options.Alignment.Y == swindow.Alignments.End) then
            top = (options.Bounds.Bottom - textHeight)
        end

        if (left < options.Bounds.Left) then
            left = options.Bounds.Left
        end
        if (top < options.Bounds.Top) then
            top = options.Bounds.Top
        end

        local right = left + textWidth
        local bottom = top + textHeight

        if (right > options.Bounds.Right) then
            right = options.Bounds.Right
        end

        if (bottom > options.Bounds.Bottom) then
            bottom = options.Bounds.Bottom
        end

        -- in order to support background colors we need to just draw a rect behind the text
        if (options.BackColor ~= nil or options.TextStyle.BackColor ~= nil) then
            local backcolor = options.BackColor or options.TextStyle.BackColor
            if (type(backcolor) == 'string') then
                backcolor = ColourNameToRGB(backcolor)
            end

            if (options.BackAttached == true) then
                WindowCircleOp(window.Config.Id, 2, left, top, right, bottom, backcolor, 0, 0, backcolor)
            else
                WindowCircleOp(
                    window.Config.Id,
                    2,
                    options.Bounds.Left,
                    options.Bounds.Top,
                    options.Bounds.Right,
                    options.Bounds.Bottom,
                    backcolor,
                    0,
                    0,
                    backcolor
                )
            end
        end

        -- put our text down
        WindowText(
            window.Config.Id,
            options.TextStyle.Name,
            options.Text or 'Omnium enim rerum principia parva sunt',
            left,
            top,
            right,
            bottom,
            options.FontColor or options.TextStyle.Color
        )

        -- add a hotspot if we have an action or tooltip
        if (options.Action ~= nil or options.Tooltip ~= nil) then
            if (options.Action ~= nil) then
                cursor = 1
            end

            if (options.BackAttached == true) then
                WindowAddHotspot(
                    window.Config.Id,
                    'content' .. content.Name,
                    left,
                    top,
                    right,
                    bottom,
                    '',
                    '',
                    'OnWindowContentClick',
                    '',
                    '',
                    content.Tooltip or '',
                    cursor, -- hand cursor
                    0
                )
            else
                WindowAddHotspot(
                    window.Config.Id,
                    'content' .. content.Name,
                    options.Bounds.Left,
                    options.Bounds.Top,
                    options.Bounds.Right,
                    options.Bounds.Bottom,
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
        end

        return {Left = left, Top = top, Right = right, Bottom = bottom}
    end

    function window.Destroy()
        WindowDelete(window.Config.Id)
        return nil
    end

    return window
end

swindow.CreateTheme = function(options)
    local theme = {}

    if (options.BackColor ~= nil and type(options.BackColor) == 'string') then
        options.BackColor = ColourNameToRGB(options.BackColor)
    end

    if (options.BorderColor ~= nil and type(options.BorderColor) == 'string') then
        options.BorderColor = ColourNameToRGB(options.BorderColor)
    end

    theme.BackColor = options.BackColor or ColourNameToRGB('black')
    theme.BorderColor = options.BorderColor or ColourNameToRGB('teal')

    theme.DefaultFont = options.Font or D_FONT
    theme.DefaultFontSize = options.FontSize or D_FONTSIZE

    theme.TextStyles = {}

    function theme.AddTextStyle(textStyle)
        if (theme.TextStyles == nil) then
            theme.TextStyles = {}
        end

        -- just to make sure all our values are correctly set we are going to run this through a create text style and pickup anything missing
        textStyle =
            swindow.CreateTextStyle(
            textStyle.Name,
            textStyle.Color,
            textStyle.Default,
            textStyle.FontSize or theme.DefaultFontSize,
            textStyle.Font or theme.DefaultFont,
            textStyle.BackColor
        )

        theme.TextStyles[textStyle.Name] = textStyle
    end

    if (options.TextStyles == nil) then
        theme.AddTextStyle(swindow.CreateTextStyle('text', 'white', true))
    else
        -- again we want to run passed in styles through some validation/correction
        for _, ts in ipairs(options.TextStyles) do
            theme.AddTextStyle(ts)
        end
    end

    return theme
end

swindow.CreateConfig = function(options)
    local config = {}
    if (options == nil) then
        options = {}
    end

    config.Id = options.Id or ('swin_' .. math.random(1, 100000))
    config.Width = options.Width or D_WIDTH
    config.Height = options.Height or D_HEIGHT
    config.Left = options.Left or D_LEFT
    config.Top = options.Top or D_TOP
    config.BorderWidth = options.BorderWidth or D_BORDERWIDTH
    config.Title = options.Title or D_TITLE
    config.TitleAlignment = options.TitleAlignment or D_TITLEALIGNMENT
    config.BodyPadding = options.BodyPadding or 5
    config.TitlePadding = options.TitlePadding or 3
    config.UpdateInterval = options.UpdateInterval or D_UPDATEINTERVAL
    config.Layer = options.Layer or D_LAYER

    if (options.AllowResize == nil) then
        config.AllowResize = D_ALLOWRESIZE
    else
        config.AllowResize = options.AllowResize
    end

    config.Visible = options.Visible or true

    config.SaveState = options.SaveState or D_SAVESTATE

    return config
end

swindow.CreateTextStyle = function(name, color, isDefault, fontSize, font, backcolor)
    assert(name, 'Name is required to create a text style')
    if (color ~= nil and type(color) == 'string') then
        color = ColourNameToRGB(color)
    end

    return {
        -- leaving some values nil so theme defaults can be used later
        Name = name,
        Color = color or D_FONTCOLOR,
        BackColor = backcolor,
        Font = font,
        FontSize = fontSize,
        Default = isDefault or false
    }
end

return swindow
