local Core = require("pyre.core")

Scanner = {Location = "", ScanEntities = {}}

function FeatureStart() ScannerSetup() end
function FeatureStop() 
 end
function FeatureSettingHandle(settingName, potentialValue) end
function FeatureTick() end
function FeatureHelp()
    Core.Log("pyre scan start optionalinterval")
    Core.Log("pyre scan stop")
    Core.Log("pyre scan report optionaltext")
end
function FeatureSave() end

function ScannerSetup() -- add our alias / triggers
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
        "^pyre scan ([a-zA-Z]+) (.+)$",
        "",
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        "OnScanAlias"
    )

    -- enable some triggers
    AddTriggerEx(
        "ph_scanner_location",
        "^(\\d?\\w*.*?).\\w* here you see:$",
        "",
        trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary + trigger_flag.OmitFromOutput,
        -1,
        0,
        "",
        "OnLocationLine",
        0
    )

    AddTriggerEx(
        "ph_scanner_door",
        "^You see a door (.*) you.$",
        "",
        trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary + trigger_flag.OmitFromOutput,
        -1,
        0,
        "",
        "OnDoorLine",
        0
    )

    AddTriggerEx(
        "ph_scanner_entity",
        "^(.*)-\\s*(.*)$",
        "",
        trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary,
        -1,
        0,
        "",
        "OnEntityLine",
        1
    )

    AddTimer(
        "ph_scanner_disable",
        0,
        0,
        2.5,
        "",
        timer_flag.Enabled + timer_flag.Replace + timer_flag.Temporary,
        "OnPyreScanTimerDisable"
    )
    EnableTimer("ph_scanner_disable", false)

end

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
    local entity = wildcards[2]

    Core.Log("ScannerAddEntity " .. entity, Core.LogLevel.DEBUG)
    table.insert(
        Scanner.ScanEntities,
        {Location = Scanner.Location, Entity = entity}
    )
    DeleteLines(1)
    return false
end

function OnDoorLine(name, line, wildcards) end

function OnPyreScanTimer()
    -- callback from timer if scanner is on
    Core.Log("OnPyreScanTimer", Core.LogLevel.DEBUG)

    EnableTrigger("ph_scanner_location", true)
    EnableTrigger("ph_scanner_door", true)
    EnableTrigger("ph_scanner_entity", true)

    Scanner.ScanEntities = {}
    SendNoEcho("scan")

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
    EnableTrigger("ph_scanner_door", false)
    EnableTrigger("ph_scanner_entity", false)

end

local function Start(delay)

    if (delay == nil) then delay = 15 end

    Core.Log("Pyre Scanner Started with interval: " .. delay)
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
    Execute(Core.Settings.Channel .. " " .. "Scan Report For [" .. Core.Status.RoomId .. " " .. Core.Status.Room .. "] [" .. string.upper(match) .. "]")
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

        canAdd = true
        nameTags = ""

        if not (match == "") then
            canAdd = false
            local matchParts = csplit(match, "|")
            for i, p in pairs(matchParts) do
                if (string.match(string.lower(v.Entity), string.lower(p))) then
                    canAdd = true
                    entityName = "(" .. string.upper(p) .. ") " .. entityName
                end
            end

        end

        if (canAdd and not (entityName == nil) and not (entityName == "")) then

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
    else
        Execute(Core.Settings.Channel .. " No matches")
    end

end

Scanner.FeatureStart = FeatureStart
Scanner.FeatureStop = FeatureStop
Scanner.FeatureSettingHandle = FeatureSettingHandle
Scanner.FeatureTick = FeatureTick
Scanner.FeatureHelp = FeatureHelp
Scanner.FeatureSave = FeatureSave
return Scanner

