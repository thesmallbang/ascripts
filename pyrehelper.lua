require 'gmcphelper'

local Pyre = require('pyrecore')

Pyre.Log('helper.lua loaded', Pyre.LogLevel.DEBUG)

local Helper = {}

Version = '0.0'
local Features = {}
local VersionData = {}
function Helper.LoadFeatures()
    if (#Features == 0) then
        Pyre.Log("No features are installed. Type 'pyre features ' for a list")
        return
    end

    for _, feature in ipairs(Features) do
        Helper.LoadFeature(feature)
    end
end

function Helper.LoadFeature(feature)
    feature.Feature = require(feature.name)

    if (feature.Feature.FeatureStart ~= nil) then
        feature.Feature.FeatureStart(Features, VersionData)
    end
    Pyre.Log('Loaded Feature ' .. feature.name, Pyre.LogLevel.DEBUG)
end

function Helper.RestartFeatures()
    Pyre.Each(
        Features,
        function(feature)
            if (feature.Feature.FeatureStart ~= nil) then
                feature.Feature.FeatureStart(Features, VersionData)
            end
        end
    )
end

function Helper.ShowInstalledFeatureHelp()
    local installed = tostring(GetVariable('plugininstalled')) or ''
    if (installed ~= '') then
        Pyre.Execute('pyre help ' .. installed)
    end
end
function Helper.AddNewFeature(feature)
    Helper.LoadFeature(feature)
    table.insert(Features, feature)
    SetVariable('plugininstalled', feature.name)
    SetVariable('feature_version_' .. feature.name, feature.version)
    Pyre.Execute('pyre reload')
end
function Helper.RemoveFeature(feature)
    if (feature ~= nil and feature.Feature ~= nil and feature.Feature.FeatureStop ~= nil) then
        feature.Feature.FeatureStop()
    end
    Features =
        Pyre.Filter(
        Features,
        function(f)
            return (f.name ~= feature.name)
        end
    )

    SetVariable('feature_' .. feature.name, nil)
    SetVariable('feature_version_' .. feature.name, nil)

    os.remove('lua/' .. feature.name .. '.lua')
    Pyre.Log('Uninstalled Feature ' .. feature.name)
end

function csplit(inputstr, sep)
    if sep == nil then
        sep = '%s'
    end
    local t = {}
    for str in string.gmatch(inputstr, '([^' .. sep .. ']+)') do
        table.insert(t, str)
    end
    return t
end

function getFileName(path)
    local fileParts = csplit(path, '/')
    local fileName = fileParts[table.getn(fileParts)]
    return fileName
end
function saveFile(path, data)
    local file = io.open(path, 'w')
    file:write(data)
    file:flush()
    file:close()
end
function getFeatureName(path)
    local fileName = getFileName(path)
    local extParts = csplit(fileName, '.')
    return extParts[1]
end
function OnFeatureDownloaded(retval, page, status, headers, full_status, request_url)
    if status == 200 then
        local fileName = getFileName(request_url)
        saveFile('lua/' .. fileName, page)
        Helper.AddNewFeature({name = getFeatureName(fileName)})
    else
        Pyre.Log('Unable to download ' .. request_url, Pyre.LogLevel.ERROR)
    end
end

function Helper.DownloadFeature(feature)
    Pyre.Log('Downloading feature' .. feature.name)
    async.doAsyncRemoteRequest(
        'https://raw.githubusercontent.com/thesmallbang/ascripts/master/' .. feature.filename,
        OnFeatureDownloaded,
        'HTTPS',
        120
    )
end

--------------------------------------------------------------------------------------

--                  PLUGIN RELAY FUNCTIONS

--------------------------------------------------------------------------------------

function Helper.OnStart(data, features)
    Version = data.release.version
    VersionData = data
    Features = features
    Pyre.CleanLog('[' .. Version .. '] Loaded. (pyre help)', nil, nil, Pyre.LogLevel.INFO)

    Helper.Setup()
    Pyre.Status.Started = true
end

function Helper.OnStop()
    Pyre.Log('OnStop', Pyre.LogLevel.DEBUG)

    Pyre.Status.Started = false
    Pyre.Status.State = Pyre.States.NONE

    for _, feat in ipairs(Features) do
        if ((feat ~= nil) and (feat.Feature ~= nil) and feat.Feature.FeatureStop ~= nil) then
            feat.Feature.FeatureStop()
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
        if ((feat ~= nil) and (feat.Feature ~= nil) and feat.Feature.FeatureSave ~= nil) then
            feat.Feature.FeatureSave()
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

        local hpPercent = tonumber((Pyre.Status.RawHp / Pyre.Status.MaxHp) * 100)
        if (hpPercent == nil) then
            Pyre.SetHp(0)
        else
            Pyre.SetHp(Pyre.Round(hpPercent, 0))
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

function OnHelp(name, line, wildcards)
    local logTable = {}
    local topic = wildcards[1] or ''

    if (topic == '') then
        logTable = {
            {
                {
                    Value = 'reloader',
                    Color = 'orange',
                    Tooltip = 'click for: Reloader Plugin Help',
                    Action = 'pyre help reloader'
                }
            },
            {
                {
                    Value = 'core',
                    Color = 'orange',
                    Tooltip = 'click for: Core Help',
                    Action = 'pyre help core'
                }
            },
            {
                {
                    Value = 'features',
                    Color = 'orange',
                    Tooltip = 'click for a list of features',
                    Action = 'pyre features'
                }
            }
        }

        for _, feat in ipairs(Features) do
            table.insert(
                logTable,
                {
                    {
                        Value = feat.name,
                        Color = 'orange',
                        Tooltip = 'click for ' .. feat.name .. ' specific help/settings',
                        Action = 'pyre help ' .. feat.name
                    }
                }
            )
        end

        Pyre.LogTable('Pyre Help', 'teal', {'Topic'}, logTable, 3, true, 'usage: pyre help <topic> or pyre features')
    end

    if (topic == 'reloader') then
        logTable = {
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

        Pyre.LogTable(
            'Plugin: Reloader ',
            'teal',
            {'Command', 'Description'},
            logTable,
            1,
            true,
            'usage: pyre <command>'
        )
    end

    if (topic == 'core' or topic == 'pyrecore') then
        Pyre.ShowSettings()
    end

    for _, feat in ipairs(Features) do
        if
            ((topic == feat.name or ('pyre' .. topic == feat.name)) and (feat.Feature ~= nil) and
                (feat.Feature.FeatureHelp ~= nil))
         then
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

    if (setting == nil or setting == '') then
        return
    end

    for _, feat in ipairs(Features) do
        if ((feat ~= nil) and (feat.Feature ~= nil) and feat.Feature.FeatureSettingHandle ~= nil) then
            feat.Feature.FeatureSettingHandle(setting, p1, p2, p3, p4)
        end
    end

    Pyre.ChangeSetting(setting, p1, p2, p3, p4)
end

function OnFeatures()
    local logTable = {}

    Pyre.Each(
        VersionData.features,
        function(f)
            local installed =
                Pyre.Any(
                Features,
                function(feat)
                    return (feat.name == f.name)
                end
            )

            local versionColumn = f.version
            if not (installed) then
                versionColumn = 'Not Installed'
            end

            table.insert(
                logTable,
                {
                    {
                        Value = f.name,
                        Color = 'orange',
                        Tooltip = f.description,
                        Action = 'pyre install ' .. f.name
                    },
                    {Value = f.description},
                    {Value = versionColumn}
                }
            )
        end
    )

    Pyre.LogTable(
        'Features ',
        'teal',
        {'Name', 'Description', 'Status'},
        logTable,
        1,
        true,
        'usage: pyre install/uninstall <name> '
    )
end

function OnFeatureInstall(name, line, wildcards)
    Pyre.Log('OnFeatureInstall', Pyre.LogLevel.DEBUG)

    local featureParam = wildcards[1]
    local feature =
        Pyre.First(
        VersionData.features,
        function(f)
            return (f.name == featureParam)
        end
    )

    if (feature == nil) then
        Pyre.Log('Feature not found')
        return
    end

    Helper.RemoveFeature(feature)
    Helper.DownloadFeature(feature)
end

function OnFeatureUninstall(name, line, wildcards)
    Pyre.Log('OnFeatureUninstall', Pyre.LogLevel.DEBUG)

    local featureParam = wildcards[1]
    local feature =
        Pyre.First(
        Features,
        function(f)
            return (f.name == featureParam)
        end
    )

    if (feature == nil) then
        return
    end

    Helper.RemoveFeature(feature)
end

function OnEnemyDied()
    Pyre.Log('Event enemydied', Pyre.LogLevel.DEBUG)
    Pyre.ShareEvent(Pyre.Event.EnemyDied, {})
end

function CoreOnStateChange(stateObject)
    if (stateObject.New ~= Pyre.States.COMBAT) then
        Pyre.QueueReset()
    end
    if (stateObject.Old == Pyre.States.REQUESTED) then
    -- Helper.RestartFeatures()
    end
end

function CoreOnRoomChanged(changeInfo)
    Pyre.QueueReset()
end

function Helper.Setup()
    Helper.LoadFeatures()

    table.insert(Pyre.Events[Pyre.Event.StateChanged], CoreOnStateChange)
    table.insert(Pyre.Events[Pyre.Event.RoomChanged], CoreOnRoomChanged)

    -- add help alias
    AddAlias(
        'ph_help',
        '^pyre help\\s?(.*)?$',
        '',
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        'OnHelp'
    )
    -- add settings alias
    AddAlias(
        'ph_setting',
        "^[pP]yre [sS]e?t?t?i?n?g?\\s([a-zA-Z0-9']+\\s?)?([\\(\\)\\#a-zA-Z0-9']+\\s?)?([\\(\\)\\#a-zA-Z0-9\\.']+\\s?)?([\\(\\)\\#a-zA-Z0-9\\.']+\\s?)?([\\(\\)\\#a-zA-Z0-9\\.']+\\s?)?([\\(\\)\\#a-zA-Z0-9\\.']+\\s?)?([\\(\\)\\#a-zA-Z0-9\\.']+\\s?)?([\\(\\)\\#a-zA-Z0-9\\.']+\\s?)?$",
        '',
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        'OnSetting'
    )

    -- install new features
    AddAlias(
        'ph_featureinstall',
        '^pyre install (.*)$',
        '',
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        'OnFeatureInstall'
    )

    AddAlias(
        'ph_featureuninstall',
        '^pyre uninstall (.*)$',
        '',
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        'OnFeatureUninstall'
    )

    AddAlias(
        'ph_featurelist',
        '^pyre features$',
        '',
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        'OnFeatures'
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

function Helper.Tick()
    -- dont tick if we are not started
    Pyre.Log('Tick', Pyre.LogLevel.VERBOSE)
    if (Pyre.Status.Started == false) then
        return
    end

    Pyre.QueueCleanExpired()
    Pyre.QueueProcessNext()

    for _, feat in ipairs(Features) do
        if ((feat ~= nil) and (feat.Feature ~= nil) and (feat.Feature.FeatureTick ~= nil)) then
            feat.Feature.FeatureTick()
        end
    end

    -- ResetTimer('ph_tick')
end

--------------------------------------------------------------------------------------

--                  PLUGIN EXPORTS

--------------------------------------------------------------------------------------

return Helper
