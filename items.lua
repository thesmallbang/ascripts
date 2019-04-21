local Core = require("pyre.core")

Items = {}

function FeatureStart() ItemsSetup() end
function FeatureStop() end
function FeatureSettingHandle(settingName, potentialValue) end
function FeatureTick() end
function FeatureHelp()
    Core.ColorLog("Items", "orange")
    Core.ColorLog("pyre wear dinvsetname")
end
function FeatureSave() end

function OnWearAlias(name, line, wildcards)
    local set = wildcards[1]
    if (IsPluginInstalled("88c86ea252fc1918556df9fe")) then -- is aard_inventory installed?
        Execute("dinv set wear shield " .. Core.Status.Level)
    else
        Core.ColorLog("'DINV' plugin is required")
    end
end

function ItemsSetup() -- add our alias / triggers
    Core.Log("Items Setup", Core.LogLevel.DEBUG)

    AddAlias(
        "ph_wearset",
        "^pyre wear ([a-zA-Z]+)?$",
        "",
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        "OnWearAlias"
    )

end

Items.FeatureStart = FeatureStart
Items.FeatureStop = FeatureStop
Items.FeatureSettingHandle = FeatureSettingHandle
Items.FeatureTick = FeatureTick
Items.FeatureHelp = FeatureHelp
Items.FeatureSave = FeatureSave
return Items

