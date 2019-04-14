require "gmcphelper"

local Core = require("pyre.core")
Core.Log("helper.lua loaded", Core.LogLevel.DEBUG)

local Scanner = require("pyre.scanner")
require("pyre.skills")

local Helper = {}

local Version = "1.0.9"

--------------------------------------------------------------------------------------

--                  PLUGIN RELAY FUNCTIONS

--------------------------------------------------------------------------------------

function OnStart()
    Core.Status.Started = true
    Core.CleanLog(
        "Pyre Helper [" .. Version .. "] Loaded. (pyre help)",
        "white"
    )

    Setup()
    ProcessSkillQueue()

end

function OnStop()
    Core.Log("OnStop", Core.LogLevel.DEBUG)
    Core.Status.Started = false
end

function Save()
    if (Core.Status.State <= 0) then return end
    Core.Log("Saving", Core.LogLevel.INFO)
    Core.SaveSettings()
    SaveSkills()
end

function OnInstall() Core.Log("Installed", Core.LogLevel.DEBUG) end

function OnPluginBroadcast(msg, id, name, text)
    if (Core.Status.State == -1) then
        Core.Status.State = 0 -- sent request
        Send_GMCP_Packet("request char")
    end
    if (id == '3e7dedbe37e44942dd46d264') then OnGMCP(text) end
end

function OnGMCP(text)
    if (Core.Status.Started == false) then OnStart() end
    if (text == "char.status") then
        res, gmcparg = CallPlugin("3e7dedbe37e44942dd46d264", "gmcpval", "char")
        luastmt = "gmcpdata = " .. gmcparg
        assert(loadstring(luastmt or ""))()
        Core.Status.State = tonumber(gmcpval("status.state"))
        Core.Status.RawAlignment = tonumber(gmcpval("status.align"))
    end
end

function OnHelp()

    Core.CleanLog("Pyre Helper by Tamon")

    Core.Log("Reloader Plugin", "orange")
    Core.Log("pyre update|reload", "orange")
    Core.Log(
        "update - download the latest versions of all components and reload the plugin",
        "white"
    )
    Core.Log(
        "reload - reload the plugin and all related component code",
        "white"
    )
    Core.Log("")
    Scanner.ShowHelp()
    Core.Log("")
    Core.Log(
        "pyre setting settingname 0|1|2|3|4|on|off|good|evil|neutral",
        "orange"
    )
    Core.ShowSettings()
    ShowSkillSettings()

end

function OnSetting(name, line, wildcards)

    Core.Log("OnSetting", Core.LogLevel.DEBUG)

    local setting = wildcards[1]

    local potentialValue = (wildcards[2])

    if (setting == nil or potentialValue == nil or setting == "" or potentialValue == "") then return end

    Core.ChangeSetting(setting, potentialValue)

    ChangeSkillSetting(setting, potentialValue)

end

function Setup()

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

    Scanner.Setup()
    AddSkillTriggers()

end

function Tick()

    -- dont tick if we are not started

    if (Core.Status.Started == false) then return end

    -- Check for skills that are expiring soon

    CheckSkillExpirations()

    -- Cast any pending skills

    ProcessSkillQueue()

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
