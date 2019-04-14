local Core = require("pyre.core")

Core.Log("scanner.lua loaded", Core.LogLevel.DEBUG)

Scanner = {}

function OnPyreScanTimer()
    -- callback from timer if scanner is on
    Core.Log("OnPyreScanTimer", Core.LogLevel.DEBUG)
end

function OnScanAlias(name, line, wildcards)

    local command = wildcards[1]

    Switch(command){

        ["start"] = function() Scanner.Start() end,

        ["stop"] = function() Scanner.Stop() end,

        ["report"] = function()
            Execute(Core.Settings.Channel .. " " .. "some scan report")
        end,

        default = function() end,

    }

end

local function Start()

    Core.Log("Pyre Scanner Started")
    OnPyreScanTimer()
    AddTimer(
        "ph_scanner",
        0,
        0,
        15,
        "",
        timer_flag.Enabled + timer_flag.Replace + timer_flag.Temporary,
        "OnPyreScanTimer"
    )

end

local function Stop()
    Core.Log("Pyre Scanner Stopped")
    EnableTimer("ph_scanner", false)
end

local function Report() Core.Log("Scanner Report") end

local function ShowHelp() Core.Log("pyre scan start|stop|report") end

local function Setup()

    -- add settings alias

    AddAlias(
        "ph_scan",
        "^pyre scan ([a-zA-Z]+)$",
        "",
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        "OnScanAlias"

    )
end

Scanner.Start = Start
Scanner.Stop = Stop
Scanner.Setup = Setup
Scanner.Report = Report
Scanner.ShowHelp = ShowHelp
return Scanner

