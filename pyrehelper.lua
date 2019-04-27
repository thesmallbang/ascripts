require 'gmcphelper'

local Pyre = require('pyrecore')

Pyre.Log('helper.lua loaded', Pyre.LogLevel.DEBUG)

local Helper = {}

local Version = '1.1.0'
local Features = {
    {Name = 'skills', Feature = nil, Encapsulated = true},
    {Name = 'scanner', Feature = nil, Encapsulated = true}
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
        Pyre.Status.Tier = tonumber(gmcpval('base.tier'))
        Pyre.Status.Subclass = gmcpval('base.subclass')
        Pyre.Status.Clan = gmcpval('base.clan')
        Pyre.Status.Level = Pyre.Status.RawLevel + (10 * Pyre.Status.Tier)
    end
    if (text == 'room.info') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'room')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        Pyre.Status.Room = gmcpval('info.name')
        Pyre.Status.RoomId = gmcpval('info.num')
    end
    if (text == 'group') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'group')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        Pyre.Status.IsLeader = Pyre.Status.Name == gmcpval('group.leader')
    end
end

function OnHelp()
    Pyre.CleanLog('Pyre Helper by Tamon')

    Pyre.ColorLog('Reloader', 'orange')
    Pyre.Log('pyre update|reload')
    Pyre.ColorLog('update - download the latest versions of all components and reload the plugin', '')
    Pyre.ColorLog('reload - reload the plugin and all related component code', '')
    Pyre.Log('')
    Pyre.Log('')
    Pyre.ColorLog('pyre setting settingname 0|1|2|3|4|on|off|good|evil|neutral', 'orange')

    Pyre.Log('')
    Pyre.ColorLog('Core', 'orange')

    Pyre.ShowSettings()

    for _, feat in ipairs(Features) do
        if (feat.Encapsulated == true) then
            Pyre.Log('')
            feat.Feature.FeatureHelp()
        end
    end
end

function OnSetting(name, line, wildcards)
    Pyre.Log('OnSetting', Pyre.LogLevel.DEBUG)

    local setting = wildcards[1]

    local potentialValue = (wildcards[2])

    if (setting == nil or potentialValue == nil or setting == '' or potentialValue == '') then
        return
    end

    for _, feat in ipairs(Features) do
        if (feat.Encapsulated == true) then
            feat.Feature.FeatureSettingHandle(setting, potentialValue)
        end
    end

    Pyre.ChangeSetting(setting, potentialValue)
end

function Helper.Setup()
    Helper.LoadFeatures()

    AddTimer('ph_tick', 0, 0, 2.0, '', timer_flag.Enabled + timer_flag.Replace + timer_flag.Temporary, 'Tick')

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
        '^[pP]yre [sS]etting ([a-zA-Z]+) ([a-zA-Z0-9]+)$',
        '',
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        'OnSetting'
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
