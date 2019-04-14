local Core = require("pyre.core")

Core.Log("scanner.lua loaded", Core.LogLevel.DEBUG)

Scanner = {}

local function PyreScan() Core.Log("InPyreScan") end

local function Start()

    AddTimer(
        "ph_scanner",
        0,
        0,
        15,
        "",
        timer_flag.Enabled + timer_flag.Replace + timer_flag.Temporary,
        "PyreScan"
    )

end

local function Stop()
    Core.Log("Stop scanner")
    EnableTimer("ph_scanner", false)
end

local function Report() Core.Log("Scanner Report") end

local function ShowHelp() Core.Log("pyre scan start|stop|report") end

Scanner.Start = Start
Scanner.Stop = Stop
Scanner.Report = Report
Scanner.ShowHelp = ShowHelp
return Scanner

