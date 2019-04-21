require "gmcphelper"

local Core = require("pyre.core")

Core.Log("helper.lua loaded", Core.LogLevel.DEBUG)

local Helper = {}

local Version = "1.0.18"
local Features = {
    {Name = "skills", Feature = nil, Encapsulated = true},
    {Name = "scanner", Feature = nil, Encapsulated = true},
    {Name = "items", Feature = nil, Encapsulated = true},
}

function LoadFeatures()
    for _, feat in ipairs(Features) do
        if (feat.Encapsulated == true) then
            feat.Feature = require("pyre." .. feat.Name)
            feat.Feature.FeatureStart()
        else
            require("pyre." .. feat.Name)
        end
        Core.Log("Loaded Feature " .. feat.Name, Core.LogLevel.DEBUG)
    end
end

--------------------------------------------------------------------------------------

--                  PLUGIN RELAY FUNCTIONS

--------------------------------------------------------------------------------------

function OnStart()
    Core.CleanLog(
        "Pyre Helper [" .. Version .. "] Loaded. (pyre help)",
        "white"
    )
    HelperSetup()
    Core.Status.Started = true

end

function OnStop()
    Core.Log("OnStop", Core.LogLevel.DEBUG)
    Core.Status.Started = false
    for _, feat in ipairs(Features) do
        if (not (feat == nil) and not (feat.Feature == nil)) then
            if (feat.Encapsulated == true) then feat.Feature.FeatureStop() end
        end
    end
end

function Save()
    if (Core.Status.State <= 0) then return end
    Core.Log("Saving", Core.LogLevel.DEBUG)
    Core.SaveSettings()
    for _, feat in ipairs(Features) do
        if (not (feat == nil) and not (feat.Feature == nil)) then
            if (feat.Encapsulated == true) then feat.Feature.FeatureSave() end
        end
    end

    -- SaveSkills()
end

function OnInstall() Core.Log("Installed", Core.LogLevel.DEBUG) end

function OnPluginBroadcast(msg, id, name, text)
    if (Core.Status.State == -1) then
        Core.Status.State = 0 -- sent request
        Send_GMCP_Packet("request char")
        Send_GMCP_Packet("request room")
    end
    if (id == '3e7dedbe37e44942dd46d264') then OnGMCP(text) end
end

function OnGMCP(text)
    Core.Log("gmcp " .. text, Core.LogLevel.VERBOSE)
    if (text == "char.status") then

        res, gmcparg = CallPlugin("3e7dedbe37e44942dd46d264", "gmcpval", "char")
        luastmt = "gmcpdata = " .. gmcparg
        assert(loadstring(luastmt or ""))()
        Core.Status.State = tonumber(gmcpval("status.state"))
        if (Core.Status.Started == false and Core.Status.State == 3) then OnStart() end

        Core.Status.RawAlignment = tonumber(gmcpval("status.align"))
        Core.Status.RawLevel = tonumber(gmcpval("status.level"))
        Core.Status.Level = Core.Status.RawLevel + (10 * Core.Status.Tier)
    end
    if (text == "char.base") then
        res, gmcparg = CallPlugin("3e7dedbe37e44942dd46d264", "gmcpval", "char")
        luastmt = "gmcpdata = " .. gmcparg
        assert(loadstring(luastmt or ""))()
        Core.Status.Tier = tonumber(gmcpval("base.tier"))
        Core.Status.Subclass = gmcpval("base.subclass")
        Core.Status.Clan = gmcpval("base.clan")
        Core.Status.Level = Core.Status.RawLevel + (10 * Core.Status.Tier)
    end
    if (text == "room.info") then
        res, gmcparg = CallPlugin("3e7dedbe37e44942dd46d264", "gmcpval", "room")
        luastmt = "gmcpdata = " .. gmcparg
        assert(loadstring(luastmt or ""))()
        Core.Status.Room = gmcpval("info.name")
        Core.Status.RoomId = gmcpval("info.num")
    end
end

function OnHelp()

    Core.CleanLog("Pyre Helper by Tamon")

    Core.ColorLog("Reloader", "orange")
    Core.Log("pyre update|reload")
    Core.ColorLog(
        "update - download the latest versions of all components and reload the plugin",
        ""
    )
    Core.ColorLog(
        "reload - reload the plugin and all related component code",
        ""
    )
    Core.Log("")
    Core.Log("")

    Core.ColorLog(
        "pyre setting settingname 0|1|2|3|4|on|off|good|evil|neutral",
        "orange"
    )

    Core.Log("")
    Core.ColorLog("Core", "orange")

    Core.ShowSettings()

    for _, feat in ipairs(Features) do
        if (feat.Encapsulated == true) then
            Core.Log("")
            feat.Feature.FeatureHelp()
        end
    end

end

function OnSetting(name, line, wildcards)

    Core.Log("OnSetting", Core.LogLevel.DEBUG)

    local setting = wildcards[1]

    local potentialValue = (wildcards[2])

    if (setting == nil or potentialValue == nil or setting == "" or potentialValue == "") then return end

    for _, feat in ipairs(Features) do
        if (feat.Encapsulated == true) then
            feat.Feature.FeatureSettingHandle(setting, potentialValue)
        end
    end

    Core.ChangeSetting(setting, potentialValue)

end

function HelperSetup()

    LoadFeatures()

    AddTimer(
        "ph_tick",
        0,
        0,
        2.0,
        "",
        timer_flag.Enabled + timer_flag.Replace + timer_flag.Temporary,
        "Tick"
    )
    -- add help alias
    AddAlias(
        "ph_help",
        "^pyre help$",
        "",
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        "OnHelp"
    )
    -- add settings alias
    AddAlias(

        "ph_setting",

        "^[pP]yre [sS]etting ([a-zA-Z]+) ([a-zA-Z0-9]+)$",

        "",

        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,

        "OnSetting"

    )

end

function Tick()
    -- dont tick if we are not started
    if (Core.Status.Started == false) then return end

    for _, feat in ipairs(Features) do
        if (not (feat == nil) and not (feat.Feature == nil)) then
            if (feat.Encapsulated == true) then feat.Feature.FeatureTick() end
        end
    end
    ResetTimer("ph_tick")
end

--------------------------------------------------------------------------------------

--                  PLUGIN EXPORTS

--------------------------------------------------------------------------------------

Helper.Save = Save

Helper.OnInstall = OnInstall

Helper.Tick = Tick

Helper.OnPluginBroadcast = OnPluginBroadcast

Helper.OnStart = OnStart

Helper.OnStop = OnStop

return Helper
