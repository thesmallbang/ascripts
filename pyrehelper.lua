-- "namespace" for all public helper functions
-- The helper is mostly a relay between our xml plugin and our .lua features

-- import our dependencies
local Core = require('pyrecore')
require('json')

PH = {}

PH.Config = {
    Events = {},
    Commands = {},
    Settings = {},
    LatestVersions = {},
    Versions = {},
    LoadedFeatures = {}
}

-- Plugin install. This really happens at plugin startup from a mush perspective.
function PH.Install(remoteVersionData, featuresOnDisk)
    PH.Config.LatestVersions = remoteVersionData
    Core.Log(Versions.Release.Version)
    Core.Log(Versions.Release.Description)

    local versionData = json.decode(GetVariable('ph_version'))
    if not (versionData) then
        versionData = remoteVersionData
        versionData.Features = {}
    else
        -- remove any features no longer found on disk
        PH.Config.Features =
            Core.Filter(
            versionData.Features or {},
            function(vf)
                return Core.Any(
                    featuresOnDisk or {},
                    function(df)
                        return (df.Name == vf.Name and df.Version == vf.Name)
                    end
                )
            end
        )
    end

    Core.Each(
        PH.Config.Features,
        function(feature)
            PH.LoadFeature(feature)
        end
    )
    PH.Start()
end

function PH.LoadFeature(feature)
    local alreadyLoaded =
        Core.Any(
        PH.Config.LoadedFeatures,
        function(lf)
            return (lf.Name == feature.Name)
        end
    )

    if (alreadyLoaded) then
        return
    end

    local loadedFeature = require(feature.Filename)
    table.insert(PH.Config.LoadedFeatures, {Name = feature.Name, Version = feature.Version, Reference = loadedFeature})
end

function PH.Start()
    print('start')
end

function PH.Stop()
    print('stop')
end

-- Start on all features
function PH.StartFeatures()
    Core.Each(
        PH.Config.LoadedFeatures,
        function(lf)
            print(lf.Name)
        end
    )
end

-- Stop on all features
function PH.StopFeatures()
end

-- Save on all features
function PH.Save()
    print('save')
end

-- Tick on all features.
-- This occurs on an interval that mushclient estimates at 25 hits per second. We are limiting the ticks based on a time setting to slow our tick down
function PH.Tick()
end

return PH
