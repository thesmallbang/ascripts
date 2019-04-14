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

    Scanner.ScanEntities = {}
    Execute("scan")

    -- enable our timer to disable the scan since there is no end line
    EnableTimer("ph_scanner_disable", true)
    ResetTimer("ph_scanner_disable")
end

function OnScanAlias(name, line, wildcards)
    local command = wildcards[1]
    local param1 = wildcards[2]

    Switch(command){
        ["start"] = function() Scanner.Start(param1) end,
        ["stop"] = function() Scanner.Stop() end,
        ["report"] = function() Scanner.Report(param1) end,
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

function findLast(haystack, needle)
    local i = haystack:match(".*" .. needle .. "()")
    if i == nil then
        return nil
    else
        return i - 1
    end
end

local function Report(match)
    Core.Log("Scanner Report", Core.LogLevel.DEBUG)

    if match == nil then match = "" end
    Execute(Core.Settings.Channel .. " " .. "Scan Report For [RoomNameHereSomeDay] [" .. string.upper(match) .. "]")
    local lastLocation = ""
    local names = ""
    local nameCount = 0
    local totalCount = 0

    for k, v in pairs(Scanner.ScanEntities) do

        if not (lastLocation == v.Location) then
            if (not (lastLocation == "") and not (names == "")) then
                Execute(Core.Settings.Channel .. " " .. lastLocation .. " [" .. nameCount .. "]: " .. names)
            end
            names = ""
            lastLocation = v.Location
        end

        local index = findLast(v.Entity, "%)")
        if (index == -1 or index == nil) then
            index = 1
        else
            index = index + 2
        end
        local entityName = string.sub(v.Entity, index)

        if ((match == "" or string.match(string.lower(v.Entity), string.lower(match))) and not (entityName == nil)) then
            totalCount = totalCount + 1
            if (names == "") then
                names = entityName
                nameCount = 1
            else
                names = names .. ", " .. entityName
                nameCount = nameCount + 1
            end
        end

    end

    if not (names == "") then
        Execute(Core.Settings.Channel .. " " .. lastLocation .. " [" .. nameCount .. "]: " .. names)
    end
    if not (totalCount == 0) then
        Execute(Core.Settings.Channel .. " Total matched " .. totalCount)
    end

end

local function ShowHelp()
    Core.Log("pyre scan start optionalinterval")
    Core.Log("pyre scan stop")
    Core.Log("pyre scan report optionaltext")
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
        trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary,
        custom_colour.Custom15,
        0,
        "",
        "OnLocationLine",
        0
    )

    AddTriggerEx(
        "ph_scanner_entity",
        "^     - (.*)$",
        "",
        trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary,
        custom_colour.Custom15,
        0,
        "",
        "OnEntityLine",
        0
    )

    AddTimer(
        "ph_scanner_disable",
        0,
        0,
        3.0,
        "",
        timer_flag.Enabled + timer_flag.Replace + timer_flag.Temporary,
        "OnPyreScanTimerDisable"
    )
    EnableTimer("ph_scanner_disable", false)

end

Scanner.Start = Start
Scanner.Stop = Stop
Scanner.Setup = Setup
Scanner.Report = Report
Scanner.ShowHelp = ShowHelp
return Scanner

