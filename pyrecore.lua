core_module = {}

local json = require('json')

function core_module.Switch(case)
    return function(codetable)
        local f
        f = codetable[case] or codetable.default
        if f then
            if type(f) == 'function' then
                return f(case)
            else
                error('case ' .. tostring(case) .. ' not a function')
            end
        end
    end
end

-------------------------------------
-- Output a message to the console. These may or may not show depending on the user's Settings.LogLevel
-- @param msg Message to show the user
-- @param loglevel  core_module.LogLevel
-------------------------------------
function core_module.Log(msg, loglevel)
    core_module.ColorLog(msg, 'white', '', loglevel)
end

function core_module.ReportToChannel(reportType, msg)
    local channel = core_module.Settings.Channel or 'echo'
    if (channel == 'echo') then
        core_module.Log(msg, core_module.LogLevel.INFO)
    else
        Execute(channel .. ' @cPR ' .. reportType .. '@w ' .. msg)
    end
end

function core_module.ToString(o)
    return json.encode(o)
end

function core_module.CleanLog(msg, color, backcolor, loglevel)
    core_module.ColorLog('                                                              ', '', backcolor, loglevel)

    core_module.ColorLog(msg, color, '', loglevel)

    core_module.ColorLog('                                                              ', '', backcolor, loglevel)
end

function core_module.ColorLog(msg, color, backcolor, loglevel)
    if (color == nil or color == '') then
        color = ''
    end

    if (backcolor == nil) then
        backcolor = ''
    end

    if (loglevel == nil or tonumber(loglevel) == nil) then
        loglevel = core_module.LogLevel.INFO
    end

    if (core_module.Settings.LogLevel > loglevel) then
        return
    end

    local skipLog = false

    core_module.Switch(loglevel) {
        [core_module.LogLevel.ERROR] = function()
            ColourTell('#FF0000', '#000000', 'PYREERR')
        end,
        [core_module.LogLevel.INFO] = function()
            ColourTell('#1D5057', '#000000', 'PYRE   ')
        end,
        [core_module.LogLevel.DEBUG] = function()
            ColourTell('#4D5057', '#FFFFFF', 'PYREDBG')
        end,
        [core_module.LogLevel.VERBOSE] = function()
            ColourTell('#320A28', '#E0D68A', 'PYREVRB')
        end,
        default = function()
            skipLog = true
        end
    }

    if (not (skipLog)) then
        ColourNote(color, backcolor, ' ' .. msg)
    end
end

function core_module.AlignmentToCategory(alignment, buffer, useBuffer)
    local setting = 99
    local goodMin = 875
    local evilMin = -875
    local neutralMax = 874
    local neutralMin = -874

    if (useBuffer == nil) then
        useBuffer = false
    end

    if useBuffer then
        goodMin = goodMin + buffer
        evilMin = evilMin - buffer
        neutralMin = neutralMin + buffer
        neutralMax = neutralMax - buffer
    end

    if (alignment >= goodMin) then
        setting = 1
    end

    if (alignment >= neutralMin and alignment <= neutralMax) then
        setting = 2
    end

    if (alignment <= evilMin) then
        setting = 3
    end

    return setting
end

function core_module.AlignmentCategoryToString(category)
    local setting = 'off'

    core_module.Switch(category) {
        [0] = function()
            setting = 'off'
        end,
        [1] = function()
            setting = 'good'
        end,
        [2] = function()
            setting = 'neutral'
        end,
        [3] = function()
            setting = 'evil'
        end,
        default = function(x)
            setting = 'invalid'
        end
    }

    return setting
end

function core_module.GetSettingValue(settings, settingName, default)
    if (default == nil) then
        default = 0
    end
    local setting = core_module.GetSetting(settings, settingName)
    if (setting == nil) then
        return default
    end

    return setting.value
end

function core_module.GetSetting(settings, settingName)
    local setting =
        core_module.First(
        settings,
        function(s)
            return s.name == settingName
        end
    )
    if (setting == nil) then
        core_module.Log('Attempted to get missing setting [' .. settingName .. ']', core_module.LogLevel.ERROR)
        return default
    end
    return setting
end

function core_module.SaveSettings()
    SetVariable('Channel', core_module.Settings.Channel or 'echo')
    SetVariable('LogLevel', core_module.Settings.LogLevel or core_module.LogLevel.INFO)
    SetVariable('AddToQueueDelay', core_module.Settings.AddToQueueDelay or 0)
    SetVariable('QueueSize', core_module.Settings.QueueSize or 2)
end

function core_module.AskIfEmpty(settingValue, settingName, default)
    if (settingValue ~= nil and settingValue ~= '') then
        return settingValue
    end

    local result =
        utils.inputbox(
        'Enter a value for ' ..
            settingName .. '. If you meant to leave it blank click cancel. Otherwise enter a value below',
        'Set Value for ' .. settingName,
        default,
        'Courier',
        9
    )
    if (result == '') then
        result = nil
    end
    if (result == nil) then
        result = default
    end

    return result
end

function core_module.ChangeSetting(setting, settingValue)
    if (string.lower(setting) == 'channel') then
        settingValue = core_module.AskIfEmpty(settingValue, settingName, core_module.Settings.Channel)
        core_module.Settings.Channel = settingValue
        core_module.Log('Channel : ' .. core_module.Settings.Channel)
    end

    if (string.lower(setting) == 'loglevel') then
        core_module.Settings.LogLevel = tonumber(settingValue) or core_module.LogLevel.INFO
        core_module.Log('LogLevel : ' .. core_module.Settings.LogLevel)
    end

    if (string.lower(setting) == 'addtoqueuedelay') then
        core_module.Settings.AddToQueueDelay = tonumber(settingValue) or 0
        core_module.Log('AddToQueueDelay : ' .. core_module.Settings.AddToQueueDelay)
    end

    if (string.lower(setting) == 'queuesize') then
        core_module.Settings.QueueSize = tonumber(settingValue) or 2
        core_module.Log('QueueSize : ' .. core_module.Settings.QueueSize)
    end
end

function core_module.ShowSettings()
    local logTable = {
        {
            {
                Value = 'Channel',
                Tooltip = 'What channel to use for reporting. Use echo for local only'
            },
            {Value = core_module.Settings.Channel}
        },
        {
            {
                Value = 'LogLevel',
                Tooltip = '0 = OFF, 1 = VERBOSE, 2 = DEBUG, 3 = INFO (default), 4 = ERRORONLY'
            },
            {Value = core_module.Settings.LogLevel}
        },
        {
            {
                Value = 'AddToQueueDelay',
                Tooltip = 'At this point it is really a Queue delay.How long between adding to the queue.'
            },
            {Value = core_module.Settings.AddToQueueDelay}
        },
        {
            {
                Value = 'QueueSize',
                Tooltip = 'How big is the "Attack Queue" allowed to get (potions can still get added when full)'
            },
            {Value = core_module.Settings.QueueSize}
        }
    }

    core_module.LogTable(
        'Feature: Core',
        'teal',
        {'Setting', 'Value'},
        logTable,
        1,
        true,
        'usage: pyre set <setting> <value>'
    )
end

function core_module.GetClassSkillByName(skillName)
    local matchSkill = nil

    for _, subclass in ipairs(core_module.Classes) do
        if string.lower(subclass.Name) == string.lower(core_module.Status.Subclass) then
            local skillTable = subclass.Skills

            for _, skill in ipairs(skillTable) do
                if
                    (string.match(string.lower(skillName), string.lower(skill.Name)) or
                        (string.match(string.lower(skillName), string.lower(skill.Alias))))
                 then
                    matchSkill = skill
                end
            end
        end
    end
    return matchSkill
end

function core_module.SetState(state)
    if (core_module.Status.State == state) then
        return
    end

    core_module.Status.PreviousState = core_module.Status.State
    core_module.Status.PreviousStateTime = os.time()
    local oldstate = core_module.Status.State
    core_module.Status.State = state
    core_module.ShareEvent(core_module.Event.StateChanged, {New = state, Old = oldstate})
    core_module.Log(
        'State Changed ' .. core_module.Status.PreviousState .. ' to ' .. state,
        core_module.LogLevel.VERBOSE
    )
end

function core_module.SetMap(id, name, zone)
    if ((core_module.Status.RoomId == id) and (core_module.Status.Room == name)) then
        return
    end

    local oldid = core_module.Status.RoomId
    local oldname = core_module.Status.Room
    local oldzone = core_module.Status.Zone

    core_module.Status.RoomId = id
    core_module.Status.Room = name
    core_module.Status.Zone = zone

    local eventData = {
        New = {Id = core_module.Status.RoomId, Name = core_module.Status.Room, Zone = core_module.Status.Zone},
        Old = {Id = oldid, Name = oldname, Zone = oldzone}
    }

    core_module.Log('Map Changed ' .. core_module.ToString(eventData), core_module.LogLevel.VERBOSE)
    core_module.ShareEvent(core_module.Event.RoomChanged, eventData)

    if not (oldzone == zone) then
        core_module.Log('Zone Changed ' .. core_module.ToString(eventData), core_module.LogLevel.VERBOSE)
        core_module.ShareEvent(core_module.Event.ZoneChanged, eventData)
    end
end

core_module.LogLevel = {OFF = 0, VERBOSE = 1, DEBUG = 2, INFO = 3, ERROR = 4}

core_module.States = {
    NONE = -1,
    REQUESTED = 0,
    LOGIN = 1,
    MOTD = 2,
    IDLE = 3,
    AFK = 4,
    NOTE = 5,
    EDITMODE = 6,
    PAGING = 7,
    COMBAT = 8,
    SLEEPING = 9,
    RESTING = 11,
    RUNNING = 12
}

core_module.Status = {
    Started = false,
    State = core_module.States.NONE,
    PreviousState = -1,
    PreviousStateTime = nil,
    Name = '',
    RawAlignment = 0,
    Room = '',
    RoomId = 0,
    Zone = '',
    Level = 0,
    RawLevel = 0,
    Tier = 0,
    Subclass = '',
    Clan = '',
    IsLeader = true,
    Enemy = '',
    EnemyHp = 0,
    Hp = 0,
    MaxHp = 0,
    RawHp = 0,
    Mana = 0,
    MaxMana = 0,
    RawMana = 0,
    Moves = 0,
    MaxMoves = 0,
    RawMoves = 0
}

-------------------------------------
--  Action Queue
-------------------------------------
core_module.ActionQueue = {}
core_module.LastSkillExecute = 0
core_module.LastSkillUniqueId = 0

function core_module.QueueCleanExpired()
    core_module.Log('QueueCleanExpired', core_module.LogLevel.VERBOSE)

    i = 0
    for _, item in pairs(core_module.ActionQueue) do
        i = i + 1
        if not (item.Expiration == nil) then
            if (socket.gettime() > item.Expiration) then
                core_module.Log('Queue had expiration: ' .. item.Skill.Name, core_module.LogLevel.DEBUG)

                if (core_module.ActionQueue == nil) then
                    return
                end
                core_module.ActionQueue =
                    core_module.Except(
                    core_module.ActionQueue,
                    function(v)
                        return (v.Skill.Name == item.Skill.Name)
                    end,
                    1
                )
                return
            end
        end
    end
end
function core_module.QueueProcessNext()
    core_module.Log('QueueProcessNext', core_module.LogLevel.VERBOSE)

    item =
        core_module.First(
        core_module.ActionQueue,
        function()
            return true
        end
    )

    if (item == nil) then
        return
    end

    -- our pending skill hasnt been cleared via expiration or detection
    local lastId = core_module.LastSkillUniqueId or 0
    if ((item.uid or 0) == lastId and (lastId ~= 0)) then
        return
    end

    -- check that we are not execeting too quickly for combat types
    local waitTime = 2.5
    if (item.Skill.SkillType == core_module.SkillType.CombatInitiate) then
        waitTime = waitTime + 2
    end
    if
        (((item.Skill.SkillType == core_module.SkillType.CombatInitiate) or
            (item.Skill.SkillType == core_module.SkillType.CombatMove)) and
            ((socket.gettime() - core_module.LastSkillExecute) < waitTime))
     then
        core_module.Log('Queue Wait ' .. core_module.TableLength(core_module.ActionQueue), core_module.LogLevel.DEBUG)
        return
    end

    -- this may be silly but i wasn't sure how objects were handled and if 2 identical commands would equal the same object
    -- and just did it in case
    local newUniqueId = math.random(1, 1000000)
    item.uid = newUniqueId
    item.Execute(item.Skill, item)
    core_module.Log(
        'Queue Length (Including This Still until detected) : ' .. core_module.TableLength(core_module.ActionQueue),
        core_module.LogLevel.VERBOSE
    )
    core_module.LastSkillUniqueId = item.uid
    core_module.LastSkillExecute = socket.gettime()
end
-- Reset queue leaves potions alone
function core_module.QueueReset()
    core_module.Log('Resetting queue', core_module.LogLevel.VERBOSE)
    core_module.ActionQueue =
        core_module.Filter(
        core_module.ActionQueue,
        function(v)
            return ((v.Skill.SkillType == core_module.SkillType.QuaffHeal) or
                (v.Skill.SkillType == core_module.SkillType.QuaffMana) or
                (v.Skill.SkillType == core_module.SkillType.QuaffMove))
        end
    )
end

-------------------------------------
--  AFK Functionality
-------------------------------------

function CheckForAFK()
    if (core_module.IsAFK == true) then
        return
    end

    local afkTime = socket.gettime() - (3 * 60) -- 3 minutes = afk
    core_module.IsAFK = ((lastRoomChanged <= afkTime) and (core_module.Status.State == core_module.States.IDLE))

    if (core_module.IsAFK == true) then
        core_module.Log('AFK - Some features will have limited or no functionality.')
    end
end

-------------------------------------
--  HELPER FUNCTIONS
-------------------------------------

function core_module.Split(inputstr, sep)
    if sep == nil then
        sep = '%s'
    end
    local t = {}
    for str in string.gmatch(inputstr, '([^' .. sep .. ']+)') do
        table.insert(t, str)
    end
    return t
end

function core_module.TableLength(T, filterFn)
    local count = 0
    if (filterFn == nil) then
        filterFn = function()
            return true
        end
    end
    for _ in pairs(T) do
        count = count + 1
    end
    return count
end

function core_module.Round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

local tableizeHeader = function(h, hcolor, width, buffer)
    local b = string.rep(' ', buffer)
    ColourTell('white', '', b .. '|')

    local w = (width - buffer) - 2 -- left/right | for table display can't be used
    local stringLen = #h
    local remainingSpace = w - stringLen

    if (remainingSpace < 0) then
        h = string.sub(h, 0 - remainingSpace)
    else
        h = string.rep(' ', math.ceil(remainingSpace / 2)) .. h .. string.rep(' ', math.ceil(remainingSpace / 2))
    end

    remainingSpace = w - #h
    h = h .. string.rep(' ', remainingSpace)

    ColourTell(hcolor, '', h)
    ColourNote('white', '', '|')
end

local tableizeDescription = function(tabledesc)
end

local tableizeRow = function(perRow, columns, data, width, buffer)
    local rowOutput = ''
    local specials = 0
    local originalData = #data
    while (#data < perRow) do
        table.insert(data, {})
    end

    local b = string.rep(' ', buffer)
    ColourTell('white', '', b .. '|')
    --rowOutput = rowOutput .. b .. '|'

    local rowWidth = (width)
    -----------------------end pipes - pyrespaces   / sections per row - 1     (-1 for | between each column )
    local propertyWidth = (((width - 2) - buffer) / (perRow * #columns)) - (#columns - 1)
    local counter = 0

    for sectionCounter = 1, perRow, 1 do
        counter = counter + 1
        if (counter > (perRow)) then
            return
        end
        local record = data[counter]

        core_module.Each(
            record,
            function(col, index)
                local data = tostring(col.Value)

                if (#data > propertyWidth) then
                    data = string.sub(data, 1, propertyWidth - 1) .. '^'
                end

                local remainingSpace = propertyWidth - #data
                if (remainingSpace < 0) then
                    data = string.sub(data, 1, 0 - remainingSpace)
                end

                if (col.Action ~= nil or col.Tooltip ~= nil) then
                    Hyperlink(col.Action or ' ', data, col.Tooltip or '', col.Color or 'white', '', false, true)
                else
                    ColourTell(col.Color or 'white', '', data)
                end

                if (remainingSpace >= 0) then
                    data = data .. string.rep(' ', remainingSpace)
                    ColourTell('', '', string.rep(' ', remainingSpace))
                end

                rowOutput = rowOutput .. data
                --ColourTell('', '', data)

                if (index < #columns) then
                    specials = specials + 2
                    rowOutput = rowOutput .. ': '
                    ColourTell('white', '', ': ')
                end
            end,
            #columns
        )

        if (counter < (perRow)) then
            specials = specials + 1

            if (counter < originalData) then
                rowOutput = rowOutput .. '|'
                ColourTell('white', '', '|')
            else
                rowOutput = rowOutput .. ' '
                ColourTell('white', '', ' ')
            end
        end
    end

    local remainingSpace = ((width - 2) - buffer) - #rowOutput
    if (remainingSpace > 0) then
        ColourTell('', '', string.rep(' ', remainingSpace))
    end

    ColourNote('white', '', '|')
    return core_module.Except(
        data,
        function()
            return true
        end,
        perRow
    )
end

local tableizeColumns = function(perRow, columns, width, buffer)
    local rowOutput = ''
    local specials = 0

    local b = string.rep(' ', buffer)
    ColourTell('white', '', b .. '|')
    --rowOutput = rowOutput .. b .. '|'

    local rowWidth = (width)
    -----------------------end pipes - pyrespaces   / sections per row - 1     (-1 for | between each column )
    local propertyWidth = (((width - 2) - buffer) / (perRow * #columns)) - (#columns - 1)
    local counter = 0

    for sectionCounter = 1, perRow, 1 do
        counter = counter + 1
        if (counter > (perRow)) then
            return
        end

        core_module.Each(
            columns,
            function(col, index)
                local h = tostring(col)

                if (#h > propertyWidth) then
                    h = string.sub(h, 1, propertyWidth - 1) .. '^'
                end

                local remainingSpace = propertyWidth - #h
                if (remainingSpace < 0) then
                    h = string.sub(h, 1, 0 - remainingSpace)
                else
                    h = h .. string.rep(' ', remainingSpace)
                end

                rowOutput = rowOutput .. h

                ColourTell('white', '', h)

                if (index < #columns) then
                    specials = specials + 2
                    rowOutput = rowOutput .. ': '
                    ColourTell('white', '', ': ')
                end
            end,
            #columns
        )

        if (counter < (perRow)) then
            specials = specials + 1

            rowOutput = rowOutput .. '|'
            ColourTell('white', '', '|')
        end
    end

    local remainingSpace = ((width - 2) - buffer) - #rowOutput
    if (remainingSpace > 0) then
        ColourTell('', '', string.rep(' ', remainingSpace))
    end

    ColourNote('white', '', '|')
end

function core_module.LogTable(header, headercolor, columns, values, perRow, showColumnHeaders, footer, footercolor)
    buffer = 8 --  "PYRE    "  prefix for lines
    if (showColumnHeaders == nil) then
        showColumnHeaders = false
    end

    local tableDescription = {
        buffer = buffer,
        width = 75, -- full width block
        perRow = perRow,
        columns = columns,
        values = values
    }

    core_module.Log('+-----------------------------------------------------------------+')
    tableizeHeader(header, headercolor, tableDescription.width, buffer)
    core_module.Log('+-----------------------------------------------------------------+')
    -- tableDescription(tableDescription)

    if (showColumnHeaders) then
        tableizeColumns(
            tableDescription.perRow,
            tableDescription.columns,
            tableDescription.width,
            tableDescription.buffer
        )
        core_module.Log('+-----------------------------------------------------------------+')
    end

    local howMany = core_module.TableLength(tableDescription.values) / tableDescription.perRow
    local counter = 0

    while (core_module.TableLength(tableDescription.values) > 0) do
        tableDescription.values =
            tableizeRow(
            tableDescription.perRow,
            tableDescription.columns,
            tableDescription.values,
            tableDescription.width,
            tableDescription.buffer
        )
    end

    if (footer ~= nil) then
        core_module.Log('+-----------------------------------------------------------------+')
        tableizeHeader(footer, footer, tableDescription.width, buffer)
    end

    core_module.Log('+-----------------------------------------------------------------+')
end

function core_module.SecondsToClock(seconds)
    local seconds = tonumber(seconds)

    if seconds <= 0 then
        return '00:00:00'
    else
        hours = string.format('%02.f', math.floor(seconds / 3600))
        mins = string.format('%02.f', math.floor(seconds / 60 - (hours * 60)))
        secs = string.format('%02.f', math.floor(seconds - hours * 3600 - mins * 60))
        return hours .. ':' .. mins .. ':' .. secs
    end
end
-------------------------------------
-- TABLE QUERY FUNCTIONS
-------------------------------------
function core_module.First(tbl, checkFn, default)
    local match = default

    for _, v in pairs(tbl) do
        if (checkFn(v)) then
            return v
        end
    end
    return match
end

function core_module.Filter(tbl, checkFn, limit)
    local match = {}
    if (limit == nil) then
        limit = 100000
    end
    local matches = 0

    for _, v in pairs(tbl) do
        if (checkFn(v)) then
            matches = matches + 1
            table.insert(match, v)
        end
        if (matches > limit) then
            return match
        end
    end
    return match
end
function core_module.Except(tbl, checkFn, exceptHowMany)
    local match = {}
    if (exceptHowMany == nil) then
        exceptHowMany = 100000
    end
    local excludedCount = 0
    for _, v in pairs(tbl) do
        if ((not (checkFn(v))) or (excludedCount >= exceptHowMany)) then
            table.insert(match, v)
        else
            excludedCount = excludedCount + 1
        end
    end
    return match
end

function core_module.Any(table, checkFn, limit)
    if (limit == nil) then
        limit = 100000
    end
    local i = 0
    for _, v in pairs(table) do
        i = i + 1
        if (i > limit) then
            return false
        end
        if (checkFn(v)) then
            return true
        end
    end
    return false
end

function core_module.Each(table, executeFn, limit)
    if (limit == nil) then
        limit = 50000000
    end
    local counter = 0

    for _, v in pairs(table) do
        counter = counter + 1
        if (counter > limit) then
            return
        end
        executeFn(v, counter)
    end
end

function core_module.Sum(table, executeFn)
    local sum = 0
    for _, v in pairs(table) do
        sum = sum + (executeFn(v, _)) or 0
    end
    return sum
end

-------------------------------------
-- EVENTS
-------------------------------------

core_module.Event = {
    StateChanged = 10,
    AFKChanged = 11,
    NewEnemy = 100,
    EnemyDied = 110,
    RoomChanged = 200,
    ZoneChanged = 201
}

core_module.Events = {
    [core_module.Event.NewEnemy] = {},
    [core_module.Event.StateChanged] = {},
    [core_module.Event.EnemyDied] = {},
    [core_module.Event.RoomChanged] = {},
    [core_module.Event.AFKChanged] = {},
    [core_module.Event.ZoneChanged] = {}
}

function core_module.ShareEvent(eventType, eventObject)
    for _, evt in pairs(core_module.Events[eventType]) do
        evt(eventObject)
    end
end

-------------------------------------
-- OTHER OBJECTS
-------------------------------------

core_module.Settings = {
    Channel = GetVariable('Channel') or 'echo',
    LogLevel = tonumber(GetVariable('LogLevel')) or core_module.LogLevel.INFO,
    AddToQueueDelay = tonumber(GetVariable('AddToQueueDelay')) or 0,
    QueueSize = tonumber(GetVariable('QueueSize')) or 30
}

core_module.SkillType = {
    Basic = 0,
    Heal = 20,
    CombatInitiate = 100,
    CombatMove = 110,
    CombatHeal = 120,
    QuaffHeal = 500,
    QuaffMana = 510,
    QuaffMove = 520
}

core_module.Classes = {
    {
        Name = 'Blacksmith',
        Skills = {
            {
                SkillType = core_module.SkillType.CombatInitiate,
                Name = 'Attack ',
                Level = 1,
                AutoSend = false,
                Alias = '~',
                Attempts = {'Who are you trying to attack?'}
            },
            {
                SkillType = core_module.SkillType.CombatInitiate,
                Name = 'Hammerswing',
                Level = 51,
                AutoSend = true,
                Alias = 'swing',
                Attempts = {
                    'You swing your hammer wildly but find nobody to hit',
                    'You are not using a hammer.',
                    'You start to build momentum with your hammer.',
                    'You are stunned.'
                }
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Bash',
                Level = 11,
                AutoSend = true,
                Alias = 'bash',
                Attempts = {'Bash whom?', "You don't know how to bash someone.", 'You are stunned.'}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Sap',
                Level = 50,
                AutoSend = true,
                Alias = 'sap',
                Attempts = {'Sap whom?', "You don't know how to sap someone.", 'You are stunned.'}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Scalp',
                Level = 60,
                AutoSend = true,
                Alias = 'scalp',
                Attempts = {'Scalp whom?', "You don't know how to scalp someone.", 'You are stunned.'}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Assault',
                Level = 88,
                AutoSend = true,
                Alias = 'mighty assault',
                Attempts = {'Assault whom?', "You don't know how to assault someone.", 'You are stunned.'}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Uppercut',
                Level = 101,
                AutoSend = true,
                Alias = 'uppercut',
                Attempts = {'Uppercut whom?', "You don't know how to uppercut someone.", 'You are stunned.'}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Stomp',
                Level = 137,
                AutoSend = true,
                Alias = 'stomp',
                Attempts = {'Stomp whom?', "You don't know how to stomp someone.", 'You are stunned.'}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Bodycheck',
                Level = 151,
                AutoSend = true,
                Alias = 'bodycheck',
                Attempts = {'Bodycheck whom?', "You don't know how to bodycheck someone.", 'You are stunned.'}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Cleave',
                Level = 165,
                AutoSend = true,
                Alias = 'cleave',
                Attempts = {'Cleave whom?', "You don't know how to cleave.", 'You are stunned.'}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Hammering',
                Level = 178,
                AutoSend = true,
                Alias = 'hammering blow',
                Attempts = {'Hammering Blow whom?', "You sit down and sing 'If I had a hammer!'.", 'You are stunned.'}
            }
        }
    }
}

return core_module
