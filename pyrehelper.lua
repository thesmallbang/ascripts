-- "namespace" for all public helper functions
-- The helper is mostly a relay between our xml plugin and our .lua features

-- import our dependencies
local Core = require('pyrecore')
require('json')
require 'gmcphelper'

PH = {}

PH.Config = {
    Events = {},
    Commands = {
        {
            Name = 'features',
            ExecuteWith = 'pyre features',
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
        }
    },
    Settings = {},
    LatestVersions = {},
    Versions = {},
    LoadedFeatures = {}
}

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
        PH.Config.Commands,
        function(cmd)
            local safename = cmd.Name:gsub('%s+', '')
            AddAlias(
                'phc_' .. safename,
                '^' .. cmd.ExecuteWith .. '$',
                '',
                alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary + alias_flag.KeepEvaluating,
                'PHCommandHandler'
            )
        end
    )

    Core.Log(PH.Config.Versions.Release.Version .. ' - ' .. PH.Config.Versions.Release.Description)

    if (PH.Config.Versions.Release.Version ~= PH.Config.LatestVersions.Release.Version) then
        Core.Log(
            'Update Available. (Requires you to download the xml file) ' .. PH.Config.LatestVersions.Release.Version
        )
        Core.Log(PH.Config.LatestVersions.Release.Description)
    end

    PH.Start()
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
    table.insert(PH.Config.LoadedFeatures, {Name = feature.Name, Version = feature.Version, Reference = loadedFeature})
end

function PH.Start()
    -- enable our aliases
    Core.Each(
        PH.Config.Commands,
        function(c)
            EnableAlias('phc_' .. c.Name:gsub('%s+', ''), true)
        end
    )
    -- same for each features

    -- start features
    PH.StartFeatures()
end

function PH.Stop()
    -- disable our aliases
    Core.Each(
        PH.Config.Commands,
        function(c)
            EnableAlias('phc_' .. c.Name:gsub('%s+', ''), false)
        end
    )

    -- same for each features
    PH.StopFeatures()
end

-- Start on all features
function PH.StartFeatures()
    Core.Each(
        PH.Config.LoadedFeatures,
        function(lf)
            PH.RegisterFeature(lf)
        end
    )
end

-- Stop on all features
function PH.StopFeatures()
    Core.Each(
        PH.Config.LoadedFeatures,
        function(lf)
            PH.UnregisterFeature(lf)
        end
    )
end

-- Save on all features
function PH.Save()
    SetVariable('ph_version', json.encode(PH.Config.Versions))
end

-- Tick on all features.
-- This occurs on an interval that mushclient estimates at 25 hits per second. We are limiting the ticks based on a time setting to slow our tick down
function PH.Tick()
end

function PH.OnPluginBroadcast(msg, id, name, text)
    if (Core.Status.State == Core.States.NONE) then
        Core.SetState(Core.States.REQUESTED) -- sent request
        Send_GMCP_Packet('request char')
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
    if (text == 'room.info') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'room')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        Core.SetMap(tonumber(gmcpval('info.num')), gmcpval('info.name') or '', gmcpval('info.zone') or '')
    end
    if (text == 'group') then
        res, gmcparg = CallPlugin('3e7dedbe37e44942dd46d264', 'gmcpval', 'group')
        luastmt = 'gmcpdata = ' .. gmcparg
        assert(loadstring(luastmt or ''))()
        local leader = gmcpval('group.leader')
        Core.Status.IsLeader = ((Core.Status.Name == leader) or (leader == ''))
    end
end

function PHCommandHandler(name, line, wildcards)
    local cmd =
        Core.First(
        PH.Config.Commands,
        function(c)
            return 'phc_' .. c.Name:gsub('%s+', '') == name
        end
    )

    if (cmd == nil) then
        Core.Log('Command callback not handled correctly', Core.LogLevel.ERROR)
        return
    end

    cmd.Callback(line, wildcards)
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
            PH.LoadFeature(feature)
            -- update our Versions to include or replace the existing feature data
            PH.Config.Versions.Features =
                Core.Except(
                PH.Config.Versions.Features,
                function(f)
                    return f.Name == feature.Name
                end
            )
            table.insert(PH.Config.Versions.Features, feature)
            PH.Save()
            Core.Log('Installed ' .. feature.Name .. ' : ' .. feature.Version)
        end
    )
end

function PH.RegisterFeature(feature)
    if (feature == nil or feature.Config == nil) then
        return
    end

    -- register commands and settings
    Core.Each(
        feature.Config.Commands,
        function(cmd)
            local safename = cmd.Name:gsub('%s+', '')
            AddAlias(
                'phc_' .. safename .. '_' .. feature.Name,
                '^' .. cmd.ExecuteWith .. '$',
                '',
                alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary + alias_flag.KeepEvaluating,
                'PHCommandHandler'
            )
        end
    )
end

function PH.UnregisterFeature(feature)
    if (feature == nil or feature.Config == nil) then
        return
    end

    if (feature.Config.Commands ~= nil) then
        Core.Each(
            feature.Config.Commands,
            function(cmd)
                local safename = cmd.Name:gsub('%s+', '')
                DeleteAlias('phc_' .. safename .. '_' .. feature.Name)
            end
        )
    end
end

-- export our helper
return PH
