local Core = require("pyre.core")

Core.Log("scanner.lua loaded", Core.LogLevel.DEBUG)

Scanner = {Location = "", ScanEntities = {}}

function OnLocationLine(name, line, wildcards)
    local location = wildcards[1]
    if (location == "Righ") then location = "Here" end

    Scanner.Location = location
    Core.Log(
        "ScannerSetLocation" .. Scanner.Location,
        Core.LogLevel.DEBUG
    )

    return false
end

function OnEntityLine(name, line, wildcards)
    local entity = wildcards[1]
    Core.Log("ScannerAddEntity " .. entity, Core.LogLevel.DEBUG)
    table.insert(
        Scanner.ScanEntities,
        {Location = Scanner.Location, Entity = entity}
    )
    return false
end

function OnPyreScanTimer()
    -- callback from timer if scanner is on
    Core.Log("OnPyreScanTimer", Core.LogLevel.DEBUG)

    EnableTrigger("ph_scanner_location", true)
    EnableTrigger("ph_scanner_entity", true)

    DoAfter(1, "scan")

    -- enable our timer to disable the scan since there is no end line
    EnableTimer("ph_scanner_disable", true)
end

function OnScanAlias(name, line, wildcards)
    local command = wildcards[1]
    local param1 = wildcards[2]

    Switch(command){
        ["start"] = function() Scanner.Start(param1) end,
        ["stop"] = function() Scanner.Stop() end,
        ["report"] = function() Scanner.Report() end,
        default = function() end,
    }
end

function OnPyreScanTimerDisable()
    Core.Log("OnPyreScanTimerDisable", Core.LogLevel.DEBUG)
    EnableTimer("ph_scanner_disable", false)
    -- disable triggers scan read
    EnableTrigger("ph_scanner_location", false)
    EnableTrigger("ph_scanner_entity", false)

end

local function Start(delay)

    if (delay == nil) then delay = 15 end

    Core.Log("Pyre Scanner Started - " .. delay)
    OnPyreScanTimer()
    AddTimer(
        "ph_scanner",
        0,
        0,
        delay,
        "",
        timer_flag.Enabled + timer_flag.Replace + timer_flag.Temporary,
        "OnPyreScanTimer"
    )

end

local function Stop()
    Core.Log("Pyre Scanner Stopped")
    EnableTimer("ph_scanner", false)
end

local function Report()
    Core.Log("Scanner Report")
    Execute(Core.Settings.Channel .. " " .. "some scan report")
end

local function ShowHelp()
    Core.Log("pyre scan start optionalinterval")
    Core.Log("pyre scan stop")
    Core.Log("pyre scan report")
end

local function Setup()
    Core.Log("Scanner Setup", Core.LogLevel.DEBUG)

    -- add settings alias
    AddAlias(
        "ph_scan",
        "^pyre scan ([a-zA-Z]+)?$",
        "",
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        "OnScanAlias"

    )
    -- can't seem to get the optional regex to work 
    AddAlias(
        "ph_scan_newb",
        "^pyre scan ([a-zA-Z]+) ([a-zA-Z0-9]+)$",
        "",
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        "OnScanAlias"
    )

    -- enable some triggers
    AddTriggerEx(
        "ph_scanner_location",
        "^(\\d?\\w*.*?).\\w* here you see:$",
        "",
        trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        custom_colour.Custom15,
        1,
        "",
        "OnLocationLine",
        0
    )

    AddTriggerEx(
        "ph_scanner_entity",
        "^     - (.*)$",
        "",
        trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        custom_colour.Custom15,
        1,
        "",
        "OnEntityLine",
        0
    )

    AddTimer(
        "ph_scanner_disable",
        0,
        0,
        4.0,
        "",
        timer_flag.Replace + timer_flag.Temporary + timer_flag.AtTime,
        "OnPyreScanTimerDisable"
    )

end

Scanner.Start = Start
Scanner.Stop = Stop
Scanner.Setup = Setup
Scanner.Report = Report
Scanner.ShowHelp = ShowHelp
return Scanner

