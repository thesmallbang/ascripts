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
    SetVariable('AttackDelay', core_module.Settings.AttackDelay or 0)
    SetVariable('AttackMaxQueue', core_module.Settings.AttackMaxQueue or 2)
end

function core_module.ChangeSetting(setting, settingValue)
    if (string.lower(setting) == 'channel') then
        core_module.Settings.Channel = settingValue or 'echo'
        core_module.Log('Channel : ' .. core_module.Settings.Channel)
    end

    if (string.lower(setting) == 'alignmentbuffer') then
        core_module.Settings.AlignmentBuffer = tonumber(settingValue) or 300
        core_module.Log('AlignmentBuffer : ' .. core_module.Settings.AlignmentBuffer)
    end

    if (string.lower(setting) == 'loglevel') then
        core_module.Settings.LogLevel = tonumber(settingValue) or core_module.LogLevel.INFO
        core_module.Log('LogLevel : ' .. core_module.Settings.LogLevel)
    end

    if (string.lower(setting) == 'skillexpirationwarn') then
        core_module.Settings.SkillExpirationWarn = tonumber(settingValue) or 30
        core_module.Log('SkillExpirationWarn : ' .. core_module.Settings.SkillExpirationWarn)
    end

    if (string.lower(setting) == 'onlyleaderinitiate') then
        core_module.Settings.OnlyLeaderInitiate = tonumber(settingValue) or 0
        core_module.Log('OnlyLeaderInitiate : ' .. core_module.Settings.OnlyLeaderInitiate)
    end

    if (string.lower(setting) == 'attackdelay') then
        core_module.Settings.AttackDelay = tonumber(settingValue) or 0
        core_module.Log('AttackDelay : ' .. core_module.Settings.AttackDelay)
    end

    if (string.lower(setting) == 'attackmaxqueue') then
        core_module.Settings.AttackMaxQueue = tonumber(settingValue) or 2
        core_module.Log('AttackMaxQueue : ' .. core_module.Settings.AttackMaxQueue)
    end
end

function core_module.ShowSettings()
    core_module.Log('Channel : ' .. core_module.Settings.Channel)

    core_module.Log('AlignmentBuffer : ' .. core_module.Settings.AlignmentBuffer)

    core_module.Log('LogLevel : ' .. core_module.Settings.LogLevel)

    core_module.Log('SkillExpirationWarn : ' .. core_module.Settings.SkillExpirationWarn)

    -- probably need to move these to skills settings
    core_module.Log('OnlyLeaderInitiate : ' .. core_module.Settings.OnlyLeaderInitiate)
    core_module.Log('AttackDelay : ' .. core_module.Settings.AttackDelay)
    core_module.Log('AttackMaxQueue : ' .. core_module.Settings.AttackMaxQueue)
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
    core_module.ShareEvent(core_module.Event.StateChanged, {new = state, old = oldstate})
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

function core_module.TableLength(T)
    local count = 0
    for _ in pairs(T) do
        count = count + 1
    end
    return count
end

-------------------------------------
-- TABLE QUERY FUNCTIONS
-------------------------------------
function core_module.First(table, checkFn, default)
    local match = default

    for _, v in pairs(table) do
        if (checkFn(v)) then
            return v
        end
    end
    return match
end

function core_module.Filter(table, checkFn, limit)
    local match = {}
    if (limit == nil) then
        limit = 100000
    end

    local matches = 0

    for _, v in pairs(table) do
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
        if (not checkFn(v)) then
            if not (excludedCount > exceptHowMany) then
                table.insert(match, v)
            end
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

function core_module.Each(table, executeFn)
    for _, v in pairs(table) do
        executeFn(v, _)
    end
end

-------------------------------------
-- EVENTS
-------------------------------------

core_module.Event = {
    StateChanged = 10,
    NewEnemy = 100
}

core_module.Events = {
    [core_module.Event.NewEnemy] = {},
    [core_module.Event.StateChanged] = {}
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
    AlignmentBuffer = tonumber(GetVariable('AlignmentBuffer')) or 300,
    LogLevel = tonumber(GetVariable('LogLevel')) or core_module.LogLevel.INFO,
    SkillExpirationWarn = tonumber(GetVariable('SkillExpirationWarn')) or 10,
    OnlyLeaderInitiate = tonumber(GetVariable('OnlyLeaderInitiate')) or 1,
    AttackDelay = tonumber(GetVariable('AttackDelay')) or 0,
    AttackMaxQueue = tonumber(GetVariable('AttackMaxQueue')) or 2
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
                Attempts = {'You swing your hammer wildly but find nobody to hit', 'You are not using a hammer.'}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Bash',
                Level = 11,
                AutoSend = true,
                Alias = 'bash',
                Attempts = {'Bash whom?', "You don't know how to bash someone."}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Sap',
                Level = 50,
                AutoSend = true,
                Alias = 'sap',
                Attempts = {'Sap whom?', "You don't know how to sap someone."}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Scalp',
                Level = 60,
                AutoSend = true,
                Alias = 'scalp',
                Attempts = {'Scalp whom?', "You don't know how to scalp someone."}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Assault',
                Level = 88,
                AutoSend = true,
                Alias = 'mighty assault',
                Attempts = {'Assault whom?', "You don't know how to assault someone."}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Uppercut',
                Level = 101,
                AutoSend = true,
                Alias = 'uppercut',
                Attempts = {'Uppercut whom?', "You don't know how to uppercut someone."}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Stomp',
                Level = 137,
                AutoSend = true,
                Alias = 'stomp',
                Attempts = {'Stomp whom?', "You don't know how to stomp someone."}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Bodycheck',
                Level = 151,
                AutoSend = true,
                Alias = 'bodycheck',
                Attempts = {'Bodycheck whom?', "You don't know how to bodycheck someone."}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Cleave',
                Level = 165,
                AutoSend = true,
                Alias = 'cleave',
                Attempts = {'Cleave whom?', "You don't know how to cleave."}
            },
            {
                SkillType = core_module.SkillType.CombatMove,
                Name = 'Hammering',
                Level = 178,
                AutoSend = true,
                Alias = 'hammering blow',
                Attempts = {'Hammering Blow whom?', "You sit down and sing 'If I had a hammer!'."}
            }
        }
    }
}

return core_module
