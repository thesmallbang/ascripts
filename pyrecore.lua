core_module = {}

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
-- @param loglevel  Pyre.LogLevel
-------------------------------------
function core_module.Log(msg, loglevel)
    core_module.ColorLog(msg, 'white', '', loglevel)
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
        [core_module.LogLevel.DEBUG] = function()
            ColourTell('#4D5057', '#FFFFFF', 'PYRE')
        end,
        [core_module.LogLevel.INFO] = function()
            ColourTell('#320A28', '#E0D68A', 'PYRE')
        end,
        [core_module.LogLevel.ERROR] = function()
            ColourTell('#EFA00B', '#591F0A', 'PYRE')
        end,
        default = function()
            skipLog = true
        end
    }

    if (not (skipLog)) then
        ColourNote(color, backcolor, ' ' .. msg)
    end
end

function core_module.AlignmentToCategory(alignment, useBuffer)
    local setting = 99
    local goodMin = 875
    local evilMin = -875
    local neutralMax = 874
    local neutralMin = -874

    if (useBuffer == nil) then
        useBuffer = false
    end

    if useBuffer then
        goodMin = goodMin + core_module.Settings.AlignmentBuffer
        evilMin = evilMin - core_module.Settings.AlignmentBuffer
        neutralMin = neutralMin + core_module.Settings.AlignmentBuffer
        neutralMax = neutralMax - core_module.Settings.AlignmentBuffer
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

function core_module.SaveSettings()
    SetVariable('Channel', core_module.Settings.Channel or 'echo')

    SetVariable('AlignmentBuffer', core_module.Settings.AlignmentBuffer or 300)

    SetVariable('LogLevel', core_module.Settings.LogLevel or core_module.LogLevel.INFO)

    SetVariable('SkillExpirationWarn', core_module.Settings.SkillExpirationWarn or 30)
    SetVariable('OnlyLeaderInitiate', core_module.Settings.OnlyLeaderInitiate or 0)
end

function core_module.ChangeSetting(setting, settingValue)
    if (string.lower(setting) == 'channel') then
        core_module.Settings.Channel = settingValue or 'echo'

        core_module.Log('channel : ' .. core_module.Settings.Channel)
    end

    if (string.lower(setting) == 'alignmentbuffer') then
        core_module.Settings.AlignmentBuffer = tonumber(settingValue) or 300

        core_module.Log('alignmentbuffer : ' .. core_module.Settings.AlignmentBuffer)
    end

    if (string.lower(setting) == 'loglevel') then
        core_module.Settings.LogLevel = tonumber(settingValue) or core_module.LogLevel.INFO

        core_module.Log('loglevel : ' .. core_module.Settings.LogLevel)
    end

    if (string.lower(setting) == 'skillexpirationwarn') then
        core_module.Settings.SkillExpirationWarn = tonumber(settingValue) or 30
        core_module.Log('skillexpirationwarn : ' .. core_module.Settings.SkillExpirationWarn)
    end

    if (string.lower(setting) == 'onlyleaderinitiate') then
        core_module.Settings.OnlyLeaderInitiate = tonumber(settingValue) or 0
        core_module.Log('OnlyLeaderInitiate : ' .. core_module.Settings.OnlyLeaderInitiate)
    end
end

function core_module.ShowSettings()
    core_module.Log('Channel : ' .. core_module.Settings.Channel)

    core_module.Log('AlignmentBuffer : ' .. core_module.Settings.AlignmentBuffer)

    core_module.Log('LogLevel : ' .. core_module.Settings.LogLevel)

    core_module.Log('SkillExpirationWarn : ' .. core_module.Settings.SkillExpirationWarn)

    -- probably need to move initiate delay to skills settings
    core_module.Log('OnlyLeaderInitiate : ' .. core_module.Settings.OnlyLeaderInitiate)
end

function core_module.SetState(state)
    if (core_module.Status.State == state) then
        return
    end

    core_module.Status.PreviousState = core_module.Status.State
    core_module.Status.PreviousStateTime = os.time()
    core_module.Status.State = state
    core_module.Log(
        'State Changed ' .. core_module.Status.PreviousState .. ' to ' .. state,
        core_module.LogLevel.VERBOSE
    )
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
    Level = 0,
    RawLevel = 0,
    Tier = 0,
    Subclass = '',
    Clan = '',
    IsLeader = true,
    Enemy = '',
    EnemyHp = 0
}

core_module.Event = {
    NewEnemy = 100
}

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

core_module.Events = {
    [core_module.Event.NewEnemy] = {}
}

core_module.Settings = {
    Channel = GetVariable('Channel') or 'echo',
    AlignmentBuffer = tonumber(GetVariable('AlignmentBuffer')) or 300,
    LogLevel = tonumber(GetVariable('LogLevel')) or core_module.LogLevel.INFO,
    SkillExpirationWarn = tonumber(GetVariable('SkillExpirationWarn')) or 10,
    OnlyLeaderInitiate = tonumber(GetVariable('OnlyLeaderInitiate')) or 1
}

core_module.Classes = {
    {
        Name = 'Blacksmith',
        CombatInit = {
            {Name = 'Attack ', Level = 1, AutoSend = false, Alias = '~'},
            {Name = 'Hammerswing', Level = 51, AutoSend = true, Alias = 'swing'}
        },
        CombatSkills = {
            {Name = 'Bash', Level = 11, AutoSend = true, Alias = 'bash'},
            {Name = 'Sap', Level = 50, AutoSend = true, Alias = 'sap'},
            {Name = 'Scalp', Level = 60, AutoSend = true, Alias = 'scalp'},
            {Name = 'Assault', Level = 88, AutoSend = true, Alias = 'mighty assault'},
            {Name = 'Uppercut', Level = 101, AutoSend = true, Alias = 'uppercut'},
            {Name = 'Stomp', Level = 137, AutoSend = true, Alias = 'stomp'},
            {Name = 'Bodycheck', Level = 151, AutoSend = true, Alias = 'bodycheck'},
            {Name = 'Cleave', Level = 165, AutoSend = true, Alias = 'cleave'},
            {Name = 'Hammering', Level = 178, AutoSend = true, Alias = 'hammering blow'}
        }
    }
}

function core_module.ShareEvent(eventType, eventObject)
    for _, evt in pairs(core_module.Events[eventType]) do
        evt(eventObject)
    end
end

function core_module.GetClassSkillByName(skillName)
    local matchSkill = nil
    for _, subclass in ipairs(core_module.Classes) do
        if string.lower(subclass.Name) == string.lower(core_module.Status.Subclass) then
            local skillTable = subclass.CombatSkills

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

return core_module
