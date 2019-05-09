require 'gmcphelper'

local Pyre = require('pyrecore')

Pyre.Log('helper.lua loaded', Pyre.LogLevel.DEBUG)

local Helper = {}

Version = '1.2.20'
local Features = {
    {Name = 'skills', Feature = {}, Encapsulated = true},
    {Name = 'scanner', Feature = {}, Encapsulated = true}
}

function Helper.LoadFeatures()
    for _, feat in ipairs(Features) do
        if (feat.Encapsulated == true) then
            feat.Feature = require('pyre' .. feat.Name)
            feat.Feature.FeatureStart()
        else
            require('pyre' .. feat.Name)
        end
        Pyre.Log('Loaded Feature ' .. feat.Name, Pyre.LogLevel.DEBUG)
    end
end

--------------------------------------------------------------------------------------

--                  PLUGIN RELAY FUNCTIONS

--------------------------------------------------------------------------------------

function Helper.OnStart()
    Pyre.CleanLog('[' .. Version .. '] Loaded. (pyre help)', nil, nil, Pyre.LogLevel.INFO)
    Helper.Setup()
    Pyre.Status.Started = true
end

function Helper.OnStop()
    Pyre.Log('OnStop', Pyre.LogLevel.DEBUG)
    Pyre.Status.Started = false

    for _, feat in ipairs(Features) do
        if (not (feat == nil) and not (feat.Feature == nil)) then
            if (feat.Encapsulated == true) then
                feat.Feature.FeatureStop()
            end
        end
    end
end

function Helper.Save()
    if (Pyre.Status.State == Pyre.States.NONE) then
        return
    end
    Pyre.Log('Saving', Pyre.LogLevel.DEBUG)
    Pyre.SaveSettings()
    for _, feat in ipairs(Features) do
        if (not (feat == nil) and not (feat.Feature == nil)) then
            if (feat.Encapsulated == true) then
                feat.Feature.FeatureSave()
            end
        end
    end

    -- SaveSkills()
end

function Helper.OnInstall()
    Pyre.Log('Installed', Pyre.LogLevel.DEBUG)
end

function Helper.OnPluginBroadcast(msg, id, name, text)
    if (Pyre.Status.State == Pyre.States.NONE) then
        Pyre.SetState(Pyre.States.REQUESTED) -- sent request
        Send_GMCP_Packet('request char')
        Send_GMCP_Packet('request room')
        Send_GMCP_Packet('request group')
    end

    if (id == '3e7dedbe37e44942dd46d264') then
        Helper.OnGMCP(text)
        return
    end

    for _, feature in pairs(Features) do
        if (not (feature == nil) and not (feature.Feature == nil) and not (feature.OnBroadCast == nil)) then
            feature.OnBroadCast(msg, id, name, text)
        end
    end
end

function Helper.OnGMCP(text)
    Pyre.Log('gmcp ' .. text, Pyre.LogLevel.VERBOSE)
    if (text == 'char.vitals') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'char')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        Pyre.Status.RawHp = tonumber(gmcpval('vitals.hp')) or 0
        Pyre.Status.RawMana = tonumber(gmcpval('vitals.mana')) or 0
        Pyre.Status.RawMoves = tonumber(gmcpval('vitals.moves')) or 0

        if (Pyre.Status.RawHp == 0) then
            Pyre.Status.Hp = 0
        else
            Pyre.Status.Hp = tonumber((Pyre.Status.RawHp / Pyre.Status.MaxHp) * 100) or 0
        end
        if (Pyre.Status.RawMana == 0) then
            Pyre.Status.Mana = 0
        else
            Pyre.Status.Mana = tonumber((Pyre.Status.RawMana / Pyre.Status.MaxMana) * 100) or 0
        end
        if (Pyre.Status.RawMoves == 0) then
            Pyre.Status.Moves = 0
        else
            Pyre.Status.Moves = tonumber((Pyre.Status.RawMoves / Pyre.Status.MaxMoves) * 100) or 0
        end
    end
    if (text == 'char.maxstats') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'char')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        Pyre.Status.MaxHp = tonumber(gmcpval('maxstats.maxhp')) or 0
        Pyre.Status.MaxMana = tonumber(gmcpval('maxstats.maxmana')) or 0
        Pyre.Status.MaxMoves = tonumber(gmcpval('maxstats.maxmoves')) or 0

        if (Pyre.Status.RawHp == 0) then
            Pyre.Status.Hp = 0
        else
            Pyre.Status.Hp = tonumber((Pyre.Status.RawHp / Pyre.Status.MaxHp) * 100) or 0
        end
        if (Pyre.Status.RawMana == 0) then
            Pyre.Status.Mana = 0
        else
            Pyre.Status.Mana = tonumber((Pyre.Status.RawMana / Pyre.Status.MaxMana) * 100) or 0
        end
        if (Pyre.Status.RawMoves == 0) then
            Pyre.Status.Moves = 0
        else
            Pyre.Status.Moves = tonumber((Pyre.Status.RawMoves / Pyre.Status.MaxMoves) * 100) or 0
        end
    end

    if (text == 'char.status') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'char')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        Pyre.SetState(tonumber(gmcpval('status.state')))
        Pyre.Status.RawAlignment = tonumber(gmcpval('status.align'))

        Pyre.Status.RawLevel = tonumber(gmcpval('status.level'))
        local newEnemy = gmcpval('status.enemy')
        local oldEnemy = Pyre.Status.Enemy
        Pyre.Status.Enemy = newEnemy
        Pyre.Status.EnemyHp = tonumber(gmcpval('status.enemypct'))
        Pyre.Status.Level = Pyre.Status.RawLevel + (10 * Pyre.Status.Tier)

        -- broadcast some change events
        if (not (string.lower(newEnemy) == string.lower(oldEnemy))) then
            Pyre.ShareEvent(Pyre.Event.NewEnemy, {new = newEnemy, old = oldEnemy})
        end
    end
    if (text == 'char.base') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'char')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        Pyre.Status.Name = gmcpval('base.name')
        Pyre.Status.Tier = tonumber(gmcpval('base.tier'))
        Pyre.Status.Subclass = gmcpval('base.subclass')
        Pyre.Status.Clan = gmcpval('base.clan')
        Pyre.Status.Level = Pyre.Status.RawLevel + (10 * Pyre.Status.Tier)
    end
    if (text == 'room.info') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'room')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        Pyre.SetMap(tonumber(gmcpval('info.num')), gmcpval('info.name') or '', gmcpval('info.zone') or '')
    end
    if (text == 'group') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'group')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        local leader = gmcpval('group.leader')
        Pyre.Status.IsLeader = ((Pyre.Status.Name == leader) or (leader == ''))
    end
end

function OnHelp()
    local logTable = {
        {
            {
                Value = 'update',
                Color = 'orange',
                Tooltip = 'Update features to latest versions',
                Action = 'pyre update'
            },
            {Value = 'Update features to latest versions'}
        },
        {
            {
                Value = 'reload',
                Color = 'orange',
                Action = 'pyre reload'
            },
            {Value = 'Reload the plugin'}
        }
    }

    Pyre.LogTable('Plugin: Reloader ', 'teal', {'Command', 'Description'}, logTable, 1, true, 'usage: pyre <command>')

    Pyre.ShowSettings()

    for _, feat in ipairs(Features) do
        if (feat.Encapsulated == true) then
            Pyre.Log('')
            feat.Feature.FeatureHelp()
        end
    end
end

function all_trim(s)
    return s:match '^%s*(.*)':match '(.-)%s*$'
end

function OnSetting(name, line, wildcards)
    Pyre.Log('OnSetting', Pyre.LogLevel.DEBUG)

    local setting = wildcards[1]

    local p1 = wildcards[2]:gsub('%s+', '') or ''
    local p2 = wildcards[3]:gsub('%s+', '') or ''
    local p3 = wildcards[4]:gsub('%s+', '') or ''
    local p4 = wildcards[5]:gsub('%s+', '') or ''

    setting = all_trim(setting)
    p1 = all_trim(p1)
    p2 = all_trim(p2)
    p3 = all_trim(p3)
    p4 = all_trim(p4)

    if (setting == nil or setting == '' or p1 == '') then
        return
    end

    for _, feat in ipairs(Features) do
        if (feat.Encapsulated == true) then
            feat.Feature.FeatureSettingHandle(setting, p1, p2, p3, p4)
        end
    end

    Pyre.ChangeSetting(setting, p1, p2, p3, p4)
end

function OnEnemyDied()
    Pyre.Log('Event enemydied', Pyre.LogLevel.DEBUG)
    Pyre.ShareEvent(Pyre.Event.EnemyDied, {})
end

function Helper.Setup()
    Helper.LoadFeatures()

    AddTimer('ph_tick', 0, 0, 0.5, '', timer_flag.Enabled + timer_flag.Replace + timer_flag.Temporary, 'Tick')

    -- add help alias
    AddAlias(
        'ph_help',
        '^pyre help$',
        '',
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        'OnHelp'
    )
    -- add settings alias
    AddAlias(
        'ph_setting',
        "^[pP]yre [sS]e?t?t?i?n?g?\\s([a-zA-Z0-9']+\\s?)?([a-zA-Z0-9']+\\s?)?([a-zA-Z0-9\\.']+\\s?)?([a-zA-Z0-9\\.']+\\s?)?([a-zA-Z0-9\\.']+\\s?)?([a-zA-Z0-9\\.']+\\s?)?([a-zA-Z0-9\\.']+\\s?)?([a-zA-Z0-9\\.']+\\s?)?$",
        '',
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        'OnSetting'
    )

    -- enemy died trigger
    AddTriggerEx(
        'ph_enemydied',
        '^(.+)(DEAD!|it!!|him!!|her!!|.+is slain by.+!!)$',
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnEnemyDied',
        0
    )
end

function Tick()
    -- dont tick if we are not started
    Pyre.Log('Tick', Pyre.LogLevel.VERBOSE)
    if (Pyre.Status.Started == false) then
        return
    end

    for _, feat in ipairs(Features) do
        if (not (feat == nil) and not (feat.Feature == nil)) then
            if (feat.Encapsulated == true) then
                feat.Feature.FeatureTick()
            end
        end
    end

    ResetTimer('ph_tick')
end

--------------------------------------------------------------------------------------

--                  PLUGIN EXPORTS

--------------------------------------------------------------------------------------

Helper.OnStart()

return Helper
