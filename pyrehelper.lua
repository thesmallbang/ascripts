-- "namespace" for all public helper functions
-- The helper is mostly a relay between our xml plugin and our .lua features

-- import our dependencies
local Core = require('pyrecore')
require('json')
require('gmcphelper')

PH = {}

PH.Config = {
    Events = {
        {
            Type = Core.Event.StateChanged,
            Callback = function(o)
                PH.StateChanged(o)
            end
        }
    },
    Commands = {
        {
            Name = 'features',
            Description = 'View available features',
            Callback = function(line, wildcards)
                PH.ShowFeatures()
            end
        },
        {
            Name = 'install',
            ExecuteWith = 'pyre install (.*)',
            Description = 'Install a feature',
            Callback = function(line, wildcards)
                PH.InstallFeature(wildcards[1])
            end
        },
        {
            Name = 'uninstall',
            ExecuteWith = 'pyre uninstall (.*)',
            Description = 'Uninstall a feature',
            Callback = function(line, wildcards)
                PH.UninstallFeature(wildcards[1])
            end
        },
        {
            Name = 'set',
            ExecuteWith = "pyre set ([a-zA-Z0-9']+\\s?)?([\\(\\)\\#a-zA-Z0-9']+\\s?)?([\\(\\)\\#a-zA-Z0-9\\.']+\\s?)?([\\(\\)\\#a-zA-Z0-9\\.']+\\s?)?([\\(\\)\\#a-zA-Z0-9\\.']+\\s?)?([\\(\\)\\#a-zA-Z0-9\\.']+\\s?)?([\\(\\)\\#a-zA-Z0-9\\.']+\\s?)?([\\(\\)\\#a-zA-Z0-9\\.']+\\s?)?",
            Description = 'Change settings',
            Callback = function(line, wildcards)
                PH.ChangeSetting(line, wildcards)
            end
        },
        {
            Name = 'help',
            Description = 'show help ',
            Callback = function(line, wildcards)
                PH.ShowHelp(line, wildcards)
            end
        }
    },
    LatestVersions = {},
    Versions = {},
    LoadedFeatures = {}
}

local afkcheckin = os.time()

-- Plugin install. This really happens at plugin startup from a mush perspective.
function PH.Install(remoteVersionData, featuresOnDisk)
    PH.Config.LatestVersions = remoteVersionData
    PH.Config.Versions = json.decode(GetVariable('ph_version') or '[]')

    if (PH.Config.Versions.Release == nil) then
        PH.Config.Versions = remoteVersionData
        PH.Config.Versions.Features = {}
    else
        -- remove any features no longer found on disk
        PH.Config.Versions.Features =
            Core.Filter(
            PH.Config.Versions.Features or {},
            function(vf)
                return Core.Any(
                    featuresOnDisk or {},
                    function(df)
                        return (df.Name == vf.Name and df.Version == vf.Version)
                    end
                )
            end
        ) or {}
    end

    Core.Each(
        PH.Config.Versions.Features,
        function(feature)
            PH.LoadFeature(feature)
        end
    )

    Core.Each(
        PH.Config.Events,
        function(evt)
            evt.Source = 'ph'
            table.insert(Core.Events[evt.Type], evt)
        end
    )

    Core.Each(
        PH.Config.Commands,
        function(cmd)
            local safename = cmd.Name:gsub('%s+', '')

            if (cmd.ExecuteWith == nil or cmd.ExecuteWith == '') then
                cmd.ExecuteWith = 'pyre ' .. string.lower(safename) .. '\\s?(.*)?'
            end

            AddAlias(
                'phc_' .. safename,
                '^' .. cmd.ExecuteWith .. '$',
                '',
                alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary + alias_flag.KeepEvaluating,
                'PHCommandHandler'
            )
        end
    )

    -- load settings
    if (Core.Config.Settings ~= nil) then
        Core.Each(
            Core.Config.Settings,
            function(s)
                s.Value = GetVariable('ph_' .. s.Name)
                if (s.Value == nil) then
                    s.Value = (s.Default or 0)
                end
                if (s.Min ~= nil or s.Max ~= nil) then
                    s.Value = tonumber(s.Value) or tonumber(s.Default)
                    if (s.Min ~= nil and s.Value < s.Min) then
                        s.Value = s.Min
                    end
                    if (s.Max ~= nil and s.Value > s.Max) then
                        s.Value = s.Max
                    end
                end
                Core.Log('setting loaded ph_' .. s.Name .. ' : ' .. s.Value, Core.LogLevel.VERBOSE)
            end
        )
    end

    -- register triggers
    if (PH.Config.Triggers ~= nil) then
        Core.Each(
            PH.Config.Triggers,
            function(trigger)
                local safename = trigger.Name:gsub('%s+', '')
                AddTriggerEx(
                    'phth_' .. safename,
                    '^' .. trigger.Match .. '$',
                    '',
                    trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
                    -1,
                    0,
                    '',
                    'PHTriggerHandler',
                    0
                )
            end
        )
    end

    Core.Log('PH Version ' .. PH.Config.Versions.Release.Version .. ' - ' .. PH.Config.Versions.Release.Description)
end

function PH.LoadFeature(feature)
    local loadedFeature =
        Core.First(
        PH.Config.LoadedFeatures,
        function(lf)
            return (lf.Name == feature.Name)
        end
    )

    if (loadedFeature ~= nil) then
        if (loadedFeature.Reference.Stop ~= nil) then
            loadedFeature.Reference.Stop()
            PH.UnregisterFeature(
                Core.First(
                    PH.Config.Versions.Features,
                    function(f)
                        return f.Name == loadedFeature.Name
                    end
                )
            )
        end
        PH.Config.LoadedFeatures =
            Core.Except(
            PH.Config.LoadedFeatures,
            function(f)
                return f.Name == feature.Name
            end
        )
    end

    loadedFeature = require(feature.Name)
    local fref = {Name = feature.Name, Version = feature.Version, Reference = loadedFeature}
    table.insert(PH.Config.LoadedFeatures, fref)
    return fref
end

function PH.Start()
    -- enable our aliases
    Core.Each(
        PH.Config.Commands,
        function(c)
            EnableAlias('phc_' .. c.Name:gsub('%s+', ''), true)
        end
    )

    Core.Each(
        PH.Config.Triggers,
        function(t)
            EnableTrigger('phth_' .. t.Name:gsub('%s+', ''), true)
        end
    )

    -- start features
    PH.StartFeatures()

    Core.Status.Started = true
end

function PH.Stop()
    Core.SetState(Core.States.NONE)
    Core.Each(
        PH.Config.Commands,
        function(c)
            EnableAlias('phc_' .. c.Name:gsub('%s+', ''), false)
        end
    )

    Core.Each(
        PH.Config.Triggers,
        function(t)
            EnableTrigger('phth_' .. t.Name:gsub('%s+', ''), false)
        end
    )

    -- same for each features
    PH.StopFeatures()

    Core.Status.Started = false
end

function PH.ResetAfk()
    afkcheckin = os.time()
end

-- Start on all features
function PH.StartFeatures()
    Core.Each(
        PH.Config.LoadedFeatures,
        function(lf)
            PH.RegisterFeature(lf)
            if (lf.Reference.Start ~= nil) then
                lf.Reference.Start()
            end
        end
    )
end

-- Stop on all features
function PH.StopFeatures()
    Core.Each(
        PH.Config.LoadedFeatures,
        function(f)
            if (f.Reference.Stop ~= nil) then
                f.Reference.Stop()
            end
            PH.UnregisterFeature(lf)
        end
    )
end

-- Save on all features
function PH.Save()
    SetVariable('ph_version', json.encode(PH.Config.Versions))

    Core.Each(
        Core.Config.Settings,
        function(s)
            SetVariable('ph_' .. s.Name, s.Value or s.Default or 0)
        end
    )

    Core.Each(
        PH.Config.LoadedFeatures,
        function(f)
            if (f.Reference ~= nil and f.Reference.Config ~= nil and f.Reference.Config.Settings ~= nil) then
                Core.Each(
                    f.Reference.Config.Settings,
                    function(s)
                        SetVariable(f.Name .. '_' .. s.Name, (s.Value or s.Default))
                    end
                )
            end
        end
    )
end

-- Tick on all features.
-- This occurs on an interval that mushclient estimates at 25 hits per second. We are limiting the ticks based on a time setting to slow our tick down
function PH.Tick()
    local secondsafk = os.time() - afkcheckin
    local allowedminutes = Core.GetSettingValue(Core, 'afkminutes')

    if (Core.IsAFK == true and (secondsafk < (allowedminutes * 60))) then
        Core.IsAFK = false
        Core.ShareEvent(Core.Event.AFKChanged, {New = false, Old = new})
    end

    if (Core.IsAFK == false and (secondsafk >= (allowedminutes * 60))) then
        Core.IsAFK = true
        Core.ShareEvent(Core.Event.AFKChanged, {New = true, Old = false})
    end

    Core.QueueCleanExpired()
    Core.QueueProcessNext()
    Core.ShareEvent(Core.Event.Tick)
end

function PH.OnPluginBroadcast(msg, id, name, text)
    if (Core.Status.State == Core.States.NONE) then
        Core.SetState(Core.States.REQUESTED) -- sent request
        Send_GMCP_Packet('request char')
        Send_GMCP_Packet('request room')
        Send_GMCP_Packet('request group')
    end

    if (id == '3e7dedbe37e44942dd46d264') then
        PH.OnGMCP(text)
        return
    end

    for _, feature in pairs(PH.Config.LoadedFeatures) do
        if (not (feature == nil) and not (feature.Reference == nil) and not (feature.Reference.OnBroadCast == nil)) then
            feature.OnBroadCast(msg, id, name, text)
        end
    end
end

function PH.OnGMCP(text)
    Core.Log('gmcp ' .. text, Core.LogLevel.VERBOSE)

    if (text == 'char.status') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'char')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        Core.SetState(tonumber(gmcpval('status.state')))
        Core.Status.RawAlignment = tonumber(gmcpval('status.align'))

        Core.Status.RawLevel = tonumber(gmcpval('status.level'))
        local newEnemy = gmcpval('status.enemy')
        local oldEnemy = Core.Status.Enemy
        Core.Status.Enemy = newEnemy
        Core.Status.EnemyHp = tonumber(gmcpval('status.enemypct'))
        Core.Status.Level = Core.Status.RawLevel + (10 * Core.Status.Tier)

        -- broadcast some change events
        if (not (string.lower(newEnemy) == string.lower(oldEnemy))) then
            Core.ShareEvent(Core.Event.NewEnemy, {new = newEnemy, old = oldEnemy})
        end
    end
    if (text == 'room.info') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'room')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        Core.SetMap(tonumber(gmcpval('info.num')), gmcpval('info.name') or '', gmcpval('info.zone') or '')
    end

    -- if (Core.Status.State >= Core.States.IDLE) then
    if (text == 'char.vitals') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'char')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        Core.Status.RawHp = tonumber(gmcpval('vitals.hp')) or 0
        Core.Status.RawMana = tonumber(gmcpval('vitals.mana')) or 0
        Core.Status.RawMoves = tonumber(gmcpval('vitals.moves')) or 0

        local hpPercent = tonumber((Core.Status.RawHp / Core.Status.MaxHp) * 100)
        if (hpPercent == nil) then
            Core.SetHp(0)
        else
            Core.SetHp(Core.Round(hpPercent, 0))
        end

        if (Core.Status.RawMana == 0) then
            Core.Status.Mana = 0
        else
            Core.Status.Mana = tonumber((Core.Status.RawMana / Core.Status.MaxMana) * 100) or 0
        end
        if (Core.Status.RawMoves == 0) then
            Core.Status.Moves = 0
        else
            Core.Status.Moves = tonumber((Core.Status.RawMoves / Core.Status.MaxMoves) * 100) or 0
        end
    end
    if (text == 'char.maxstats') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'char')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        Core.Status.MaxHp = tonumber(gmcpval('maxstats.maxhp')) or 0
        Core.Status.MaxMana = tonumber(gmcpval('maxstats.maxmana')) or 0
        Core.Status.MaxMoves = tonumber(gmcpval('maxstats.maxmoves')) or 0

        if (Core.Status.RawHp == 0) then
            Core.Status.Hp = 0
        else
            Core.Status.Hp = tonumber((Core.Status.RawHp / Core.Status.MaxHp) * 100) or 0
        end
        if (Core.Status.RawMana == 0) then
            Core.Status.Mana = 0
        else
            Core.Status.Mana = tonumber((Core.Status.RawMana / Core.Status.MaxMana) * 100) or 0
        end
        if (Core.Status.RawMoves == 0) then
            Core.Status.Moves = 0
        else
            Core.Status.Moves = tonumber((Core.Status.RawMoves / Core.Status.MaxMoves) * 100) or 0
        end
    end
    if (text == 'char.base') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'char')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        Core.Status.Name = gmcpval('base.name')
        Core.Status.Tier = tonumber(gmcpval('base.tier'))
        Core.Status.Subclass = gmcpval('base.subclass')
        Core.Status.Clan = gmcpval('base.clan')
        Core.Status.Level = Core.Status.RawLevel + (10 * Core.Status.Tier)
    end

    if (text == 'group') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'group')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        local leader = gmcpval('group.leader')
        Core.Status.IsLeader = ((Core.Status.Name == leader) or (leader == ''))
    end
    --  end
end

function PHCommandHandler(name, line, wildcards)
    local cmd =
        Core.First(
        PH.Config.Commands,
        function(c)
            return 'phc_' .. c.Name:gsub('%s+', '') == name
        end
    )

    if (cmd ~= nil) then
        cmd.Callback(line, wildcards)
        return
    end

    Core.Each(
        PH.Config.LoadedFeatures,
        function(f)
            if (f.Reference ~= nil and f.Reference.Config ~= nil and f.Reference.Config.Commands ~= nil) then
                cmd =
                    Core.First(
                    f.Reference.Config.Commands,
                    function(c)
                        return 'phc_' .. f.Name .. '_' .. c.Name:gsub('%s+', '') == name
                    end
                )

                if (cmd ~= nil) then
                    cmd.Callback(line, wildcards)
                end
            end
        end
    )
end

function PHTriggerHandler(name, line, wildcards)
    local trigger =
        Core.First(
        PH.Config.Triggers,
        function(t)
            return 'phth_' .. t.Name:gsub('%s+', '') == name
        end
    )

    if (trigger ~= nil) then
        trigger.Callback(line, wildcards)
    end

    Core.Each(
        PH.Config.LoadedFeatures,
        function(f)
            if (f ~= nil and f.Reference ~= nil and f.Reference.Config ~= nil and f.Reference.Config.Triggers ~= nil) then
                -- PHTriggerHandler
                trigger =
                    Core.First(
                    f.Reference.Config.Triggers,
                    function(t)
                        return 'pht_' .. f.Name .. '_' .. t.Name:gsub('%s+', '') == name
                    end
                )

                if (trigger ~= nil) then
                    trigger.Callback(line, wildcards)
                end
            end
        end
    )
end

function PH.ShowHelp(line, wildcards)
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

        for _, feat in ipairs(PH.Config.LoadedFeatures) do
            table.insert(
                logTable,
                {
                    {
                        Value = feat.Name,
                        Color = 'orange',
                        Tooltip = 'click for ' .. feat.Name .. ' specific help/settings',
                        Action = 'pyre help ' .. feat.Name
                    }
                }
            )
        end

        Core.LogTable('Pyre Help', 'teal', {'Topic'}, logTable, 3, true, 'usage: pyre help <topic> or click topic')
        return
    end

    for _, feat in ipairs(PH.Config.LoadedFeatures) do
        if ((topic == feat.Name or ('pyre' .. topic == feat.Name)) and (feat.Reference ~= nil)) then
            PH.BuildConfigHelp(feat.Name, feat.Reference.Config)
            return
        end
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

        Core.LogTable(
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
        if (Core.Config ~= nil) then
            PH.BuildConfigHelp('core', Core.Config)
            return
        end
    end
end

function PH.BuildConfigHelp(name, config)
    local logTable = {}

    table.insert(logTable, {{Value = 'Command'}, {Value = 'Description'}})

    Core.Each(
        config.Commands,
        function(c)
            local execute =
                string.gsub(c.ExecuteWith, '[\\?\\(\\.\\*\\)]', ''):match '^%s*(.*)':match '(.-)%s*$':sub(1, -2)
            table.insert(
                logTable,
                {
                    {
                        Value = c.Name,
                        Color = 'orange',
                        Tooltip = c.Description .. ' .. ' .. execute,
                        Action = execute
                    },
                    {
                        Value = c.Description,
                        Tooltip = c.Description .. ' .. ' .. execute
                    }
                }
            )
        end
    )

    table.insert(logTable, {{Value = ''}, {Value = ''}})
    table.insert(logTable, {{Value = 'Setting'}, {Value = 'Value'}})

    Core.Each(
        config.Settings,
        function(s)
            local execute = 'pyre set ' .. name .. ' ' .. s.Name
            table.insert(
                logTable,
                {
                    {
                        Value = s.Name,
                        Color = 'orange',
                        Tooltip = s.Description .. '  (Default: ' .. s.Default .. ')',
                        Action = execute
                    },
                    {
                        Value = s.Value,
                        Tooltip = s.Description
                    }
                }
            )
        end
    )

    Core.LogTable(
        'Topic: ' .. string.upper(name:gsub('pyre', '')),
        'teal',
        {'', ''},
        logTable,
        1,
        false,
        'Interact with orange text, Mouseover for more information'
    )
end

function PH.ShowFeatures()
    local logTable = {}

    Core.Each(
        PH.Config.LatestVersions.Features,
        function(latestFeature)
            local installed =
                Core.First(
                PH.Config.Versions.Features,
                function(feat)
                    return (feat.Name == latestFeature.Name)
                end
            )

            local versionColumn = latestFeature.Version

            if (installed == nil) then
                versionColumn = 'Not Installed'
            end
            if (installed ~= nil and ((tonumber(installed.Version) or 0) < (tonumber(latestFeature.Version) or 0))) then
                versionColumn = installed.Version .. ' -> ' .. latestFeature.Version
            end

            table.insert(
                logTable,
                {
                    {
                        Value = latestFeature.Name,
                        Color = 'orange',
                        Tooltip = latestFeature.Description,
                        Action = 'pyre install ' .. latestFeature.Name
                    },
                    {Value = latestFeature.Description},
                    {Value = versionColumn}
                }
            )
        end
    )

    Core.LogTable(
        'Features ',
        'teal',
        {'Name', 'Description', 'Status'},
        logTable,
        1,
        true,
        'usage: pyre install/uninstall <name> '
    )
end

function PH.InstallFeature(name)
    local feature =
        Core.First(
        PH.Config.LatestVersions.Features,
        function(f)
            return (string.upper(f.Name) == string.upper(name))
        end
    )

    if (feature == nil) then
        Core.Log(name .. ' is not a valid feature. Use "pyre features" to get a list')
        return
    end

    Core.Log('Installing ' .. feature.Name .. ' : ' .. feature.Version)
    download(
        'https://raw.githubusercontent.com/thesmallbang/ascripts/RefactoringPluginEvents/' .. feature.Filename,
        function(retval, page, status, headers, full_status, request_url)
            saveDownload(retval, page, status, headers, full_status, request_url)

            -- update our Versions to include or replace the existing feature data
            PH.Config.Versions.Features =
                Core.Except(
                PH.Config.Versions.Features,
                function(f)
                    return f.Name == feature.Name
                end
            )

            table.insert(PH.Config.Versions.Features, feature)

            local lf = PH.LoadFeature(feature)

            if (Core.Status.Started == true and lf.Reference ~= nil and lf.Reference.Start ~= nil) then
                lf.Reference.Start()
            end
            PH.Save()
            Core.Log('Installed ' .. feature.Name .. ' : ' .. feature.Version)
        end
    )
end

function PH.UninstallFeature(name)
    local feature =
        Core.First(
        PH.Config.LoadedFeatures,
        function(f)
            return (string.upper(f.Name) == string.upper(name))
        end
    )

    if (feature == nil) then
        Core.Log(name .. ' is not a valid feature or is not installed. Use "pyre features" to get a list')
        return
    end

    if (feature.Reference ~= nil and feature.Reference.Stop ~= nil) then
        feature.Reference.Stop()
    end

    PH.UnregisterFeature(feature)

    PH.Config.Versions.Features =
        Core.Except(
        PH.Config.Versions.Features,
        function(f)
            return f.Name == feature.Name
        end
    )
    PH.Config.LoadedFeatures =
        Core.Except(
        PH.Config.LoadedFeatures,
        function(f)
            return f.Name == feature.Name
        end
    )
    os.execute('del /S ' .. feature.Name .. '.lua')
    PH.Save()
    Core.Log('Uninstalled ' .. feature.Name .. ' : ' .. feature.Version)
end

function PH.RegisterFeature(feature)
    if (feature == nil or feature.Reference == nil or feature.Reference.Config == nil) then
        return
    end

    -- register events
    if (feature.Reference.Config.Events ~= nil) then
        Core.Each(
            feature.Reference.Config.Events,
            function(evt)
                evt.Source = feature.Name
                table.insert(Core.Events[evt.Type], evt)
            end
        )
    end

    -- register commands and settings
    if (feature.Reference.Config.Commands ~= nil) then
        Core.Each(
            feature.Reference.Config.Commands,
            function(cmd)
                local safename = cmd.Name:gsub('%s+', '')
                if (cmd.ExecuteWith == nil or cmd.ExecuteWith == '') then
                    cmd.ExecuteWith = 'pyre ' .. string.lower(safename) .. '\\s?(.*)?'
                end
                AddAlias(
                    'phc_' .. feature.Name .. '_' .. safename,
                    '^' .. cmd.ExecuteWith .. '$',
                    '',
                    alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary +
                        alias_flag.KeepEvaluating,
                    'PHCommandHandler'
                )
            end
        )
    end

    -- load settings
    if (feature.Reference.Config.Settings ~= nil) then
        Core.Each(
            feature.Reference.Config.Settings,
            function(s)
                s.Value = GetVariable(feature.Name .. '_' .. s.Name)
                if (s.Value == nil) then
                    s.Value = (s.Default or 0)
                end
                if (s.Min ~= nil or s.Max ~= nil) then
                    s.Value = tonumber(s.Value) or tonumber(s.Default)
                    if (s.Min ~= nil and s.Value < s.Min) then
                        s.Value = s.Min
                    end
                    if (s.Max ~= nil and s.Value > s.Max) then
                        s.Value = s.Max
                    end
                end
                Core.Log('setting loaded ' .. feature.Name .. '_' .. s.Name .. ' : ' .. s.Value, Core.LogLevel.VERBOSE)
            end
        )
    end

    -- register triggers
    if (feature.Reference.Config.Triggers ~= nil) then
        Core.Each(
            feature.Reference.Config.Triggers,
            function(trigger)
                local safename = trigger.Name:gsub('%s+', '')
                AddTriggerEx(
                    'pht_' .. feature.Name .. '_' .. safename,
                    '^' .. trigger.Match .. '$',
                    '',
                    trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace +
                        trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
                    -1,
                    0,
                    '',
                    'PHTriggerHandler',
                    0
                )
            end
        )
    end
end

function PH.UnregisterFeature(feature)
    if (feature == nil or feature.Reference == nil or feature.Reference.Config == nil) then
        return
    end

    -- unregister commands
    if (feature.Reference.Config.Commands ~= nil) then
        Core.Each(
            feature.Reference.Config.Commands,
            function(cmd)
                local safename = cmd.Name:gsub('%s+', '')
                DeleteAlias('phc_' .. feature.Name .. '_' .. safename)
            end
        )
    end

    -- unregister events
    if (feature.Reference.Config.Events ~= nil) then
        Core.Each(
            feature.Reference.Config.Events,
            function(evt)
                Core.Events[evt.Type] =
                    Core.Except(
                    Core.Events[evt.Type],
                    function(e)
                        return e.Source == feature.Name
                    end
                )
            end
        )
    end

    PH.Save()

    -- unregister triggers
    if (feature.Reference.Config.Triggers ~= nil) then
        Core.Each(
            feature.Reference.Config.Triggers,
            function(trigger)
                local safename = trigger.Name:gsub('%s+', '')
                DeleteTrigger('pht_' .. feature.Name .. '_' .. safename)
            end
        )
    end
end

function PH.StateChanged(state)
    if (state.New == Core.States.IDLE and state.Old < Core.States.IDLE) then
        PH.Start()
    end

    if (state.New < Core.States.IDLE and state.Old >= Core.States.IDLE) then
        PH.Stop()
    end
end

function PH.ChangeSetting(line, wildcards)
    local p1 = (wildcards[1] or ''):match '^%s*(.*)':match '(.-)%s*$'
    local p2 = (wildcards[2] or ''):match '^%s*(.*)':match '(.-)%s*$'
    local p3 = (wildcards[3] or ''):match '^%s*(.*)':match '(.-)%s*$'
    local p4 = (wildcards[4] or ''):match '^%s*(.*)':match '(.-)%s*$'

    if (p1 == nil) then
        Core.Log('settingname or feature + settingname is required', Core.LogLevel.ERROR)
        return
    end

    -- see if p1 is a primary helper setting before going to features
    local setting =
        Core.First(
        Core.Config.Settings,
        function(s)
            return (string.lower(s.Name) == string.lower(p1))
        end
    )

    if (setting ~= nil) then
        -- do we have a feature match, a setting match and no value passed in
        if (p2 == '') then
            p2 = Core.AskIfEmpty(p2, setting.Name, setting.Default)

            if (p2 == nil or p2 == '') then
                p2 = (setting.Default or 0)
            end
        end

        local originalValue = setting.Value or ''
        if (setting.OnBeforeSet ~= nil) then
            local result = setting:OnBeforeSet(originalValue, p2)
            if (result == false) then
                return
            end
        end
        if (setting.Min ~= nil or setting.Max ~= nil) then
            setting.Value = tonumber(p2) or tonumber(setting.Default)
            if (setting.Min ~= nil and setting.Value < setting.Min) then
                setting.Value = setting.Min
            end
            if (setting.Max ~= nil and setting.Value > setting.Max) then
                setting.Value = setting.Max
            end
        else
            setting.Value = p2
        end
        if (setting.OnAfterSet ~= nil) then
            setting:OnAfterSet(setting.Value, originalValue)
        end
        PH.Save()
        Core.Log(setting.Name .. ' changed from ' .. originalValue .. ' to ' .. setting.Value)

        return
    end

    if (p1 == 'core') then
        local setting =
            Core.First(
            Core.Config.Settings,
            function(s)
                return (string.lower(s.Name) == string.lower(p2))
            end
        )

        if (setting ~= nil) then
            -- do we have a feature match, a setting match and no value passed in
            if (p3 == '') then
                p3 = Core.AskIfEmpty(p3, setting.Name, setting.Default)

                if (p3 == nil or p3 == '') then
                    p3 = (setting.Default or 0)
                end
            end

            local originalValue = setting.Value or ''
            local result = setting:OnBeforeSet(originalValue, p3)
            if (result == false) then
                return
            end

            if (setting.Min ~= nil or setting.Max ~= nil) then
                setting.Value = tonumber(p3) or tonumber(setting.Default)
                if (setting.Min ~= nil and setting.Value < setting.Min) then
                    setting.Value = setting.Min
                end
                if (setting.Max ~= nil and setting.Value > setting.Max) then
                    setting.Value = setting.Max
                end
            else
                setting.Value = p3
            end
            if (setting.OnAfterSet ~= nil) then
                setting:OnAfterSet(setting.Value, originalValue)
            end
            PH.Save()
            Core.Log(setting.Name .. ' changed from ' .. originalValue .. ' to ' .. setting.Value)

            return
        end
    end

    -- is p1 a feature name instead?
    local feature =
        Core.First(
        PH.Config.LoadedFeatures,
        function(f)
            return ((string.lower(f.Name) == string.lower(p1)) or (string.lower(f.Name) == string.lower('pyre' .. p1)))
        end
    )

    if (feature == nil) then
        Core.Log(p1 .. ' is not a setting or feature')
        return
    end

    if (feature.Reference ~= nil and feature.Reference.Config ~= nil and feature.Reference.Config.Settings) then
        local setting =
            Core.First(
            feature.Reference.Config.Settings,
            function(s)
                return (string.lower(s.Name) == string.lower(p2))
            end
        )
        if (setting == nil) then
            Core.Log(p2 .. ' is not a setting for feature ' .. feature.Name)
            return
        end

        -- do we have a feature match, a setting match and no value passed in
        if (p3 == '') then
            p3 = Core.AskIfEmpty(p3, setting.Name, setting.Default)

            if (p3 == nil or p3 == '') then
                p3 = (setting.Default or 0)
            end
        end

        local originalValue = setting.Value or ''
        local result = setting:OnBeforeSet(originalValue, p3)
        if (result == false) then
            return
        end
        if (setting.Min ~= nil or setting.Max ~= nil) then
            setting.Value = tonumber(p3) or tonumber(setting.Default)
            if (setting.Min ~= nil and setting.Value < setting.Min) then
                setting.Value = setting.Min
            end
            if (setting.Max ~= nil and setting.Value > setting.Max) then
                setting.Value = setting.Max
            end
        else
            setting.Value = p3
        end
        if (setting.OnAfterSet ~= nil) then
            setting:OnAfterSet(setting.Value, originalValue)
        end
        PH.Save()
        Core.Log(feature.Name .. ' ' .. setting.Name .. ' changed from ' .. originalValue .. ' to ' .. setting.Value)
    end
end
-- export our helper
return PH
