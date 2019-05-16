local Pyre = require('pyrecore')

Feature = {Location = '', ScanEntities = {}}

function Feature.FeatureStart()
    Feature.Setup()
end
function Feature.FeatureStop()
end
function Feature.FeatureSettingHandle(settingName, potentialValue)
end
function Feature.FeatureTick()
end
function Feature.FeatureHelp()
    local logTable = {
        {
            {
                Value = 'pyre scan start <optionalseconds>',
                Color = 'orange',
                Tooltip = 'Store scan results to be used for reporting',
                Action = 'pyre scan start'
            },
            {Value = 'Store scan results to be used for reporting'}
        },
        {
            {
                Value = 'pyre scan stop',
                Color = 'orange',
                Tooltip = 'Stop the scanner',
                Action = 'pyre scan stop'
            },
            {Value = 'Stop scanner'}
        },
        {
            {
                Value = 'pyre scan report <optionalfilters>',
                Color = 'orange',
                Tooltip = 'The filter can be like OPK or RAIDER etc',
                Action = 'pyre scan report'
            },
            {Value = 'Report. Use | between filters'}
        }
    }

    Pyre.LogTable('Feature: Scanner ', 'teal', {'Command', 'Description'}, logTable, 1, true, 'usage: pyre <command>')
end
function Feature.FeatureSave()
end

function Feature.Setup() -- add our alias / triggers
    Pyre.Log('Scanner Setup', Pyre.LogLevel.DEBUG)

    -- add settings alias
    AddAlias(
        'ph_scan',
        '^pyre scan ([a-zA-Z]+)?$',
        '',
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        'OnScanAlias'
    )
    -- can't seem to get the optional regex to work
    AddAlias(
        'ph_scan_newb',
        '^pyre scan ([a-zA-Z]+) (.+)$',
        '',
        alias_flag.Enabled + alias_flag.RegularExpression + alias_flag.Replace + alias_flag.Temporary,
        'OnScanAlias'
    )

    -- enable some triggers
    AddTriggerEx(
        'ph_scanner_location',
        '^(\\d?\\w*.*?).\\w* here you see:$',
        '',
        trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary + trigger_flag.OmitFromOutput,
        -1,
        0,
        '',
        'OnLocationLine',
        0
    )

    AddTriggerEx(
        'ph_scanner_door',
        '^You see a door (.*) you.$',
        '',
        trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary + trigger_flag.OmitFromOutput,
        -1,
        0,
        '',
        'OnDoorLine',
        0
    )

    AddTriggerEx(
        'ph_scanner_entity',
        '^(.*)-\\s*(.*)$',
        '',
        trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary,
        -1,
        0,
        '',
        'OnEntityLine',
        1
    )

    AddTimer(
        'ph_scanner_disable',
        0,
        0,
        2.5,
        '',
        timer_flag.Enabled + timer_flag.Replace + timer_flag.Temporary,
        'OnPyreScanTimerDisable'
    )
    EnableTimer('ph_scanner_disable', false)
end

function OnLocationLine(name, line, wildcards)
    local location = wildcards[1]
    if (location == 'Righ') then
        location = 'Here'
    end

    Feature.Location = location
    Pyre.Log('ScannerSetLocation' .. Feature.Location, Pyre.LogLevel.DEBUG)
    return false
end

function OnEntityLine(name, line, wildcards)
    local entity = wildcards[2]

    Pyre.Log('ScannerAddEntity ' .. entity, Pyre.LogLevel.DEBUG)
    table.insert(Feature.ScanEntities, {Location = Feature.Location, Entity = entity})
    DeleteLines(1)
    return false
end

function OnDoorLine(name, line, wildcards)
end

function OnPyreScanTimer()
    -- callback from timer if scanner is on
    Pyre.Log('OnPyreScanTimer', Pyre.LogLevel.DEBUG)

    EnableTrigger('ph_scanner_location', true)
    EnableTrigger('ph_scanner_door', true)
    EnableTrigger('ph_scanner_entity', true)

    Feature.ScanEntities = {}
    Pyre.Execute('scan')

    -- enable our timer to disable the scan since there is no end line
    EnableTimer('ph_scanner_disable', true)
    ResetTimer('ph_scanner_disable')
end

function OnScanAlias(name, line, wildcards)
    local command = wildcards[1]
    local param1 = wildcards[2]

    Pyre.Switch(command) {
        ['start'] = function()
            Start(param1)
        end,
        ['stop'] = function()
            Stop()
        end,
        ['report'] = function()
            Report(param1)
        end,
        default = function()
        end
    }
end

function OnPyreScanTimerDisable()
    Pyre.Log('OnPyreScanTimerDisable', Pyre.LogLevel.DEBUG)
    EnableTimer('ph_scanner_disable', false)
    -- disable triggers scan read
    EnableTrigger('ph_scanner_location', false)
    EnableTrigger('ph_scanner_door', false)
    EnableTrigger('ph_scanner_entity', false)
end

function Start(delay)
    if (delay == nil) then
        delay = 15
    end

    Pyre.Log('Pyre Scanner Started with interval: ' .. delay)
    OnPyreScanTimer()
    AddTimer(
        'ph_scanner',
        0,
        0,
        delay,
        '',
        timer_flag.Enabled + timer_flag.Replace + timer_flag.Temporary,
        'OnPyreScanTimer'
    )
end

function Stop()
    Pyre.Log('Pyre Scanner Stopped')
    EnableTimer('ph_scanner', false)
end

function findLast(haystack, needle)
    local i = haystack:match('.*' .. needle .. '()')
    if i == nil then
        return nil
    else
        return i - 1
    end
end

function Report(match)
    Pyre.Log('Scanner Report', Pyre.LogLevel.DEBUG)

    if match == nil then
        match = ''
    end
    Pyre.Execute(
        Pyre.Settings.Channel ..
            ' ' ..
                'Scan Report For [' ..
                    Pyre.Status.RoomId .. ' ' .. Pyre.Status.Room .. '] [' .. string.upper(match) .. ']'
    )
    local lastLocation = ''
    local names = ''
    local nameCount = 0
    local totalCount = 0

    for k, v in pairs(Feature.ScanEntities) do
        if not (lastLocation == v.Location) then
            if (not (lastLocation == '') and not (names == '')) then
                Pyre.Execute(Pyre.Settings.Channel .. ' ' .. lastLocation .. ' [' .. nameCount .. ']: ' .. names)
            end
            names = ''
            lastLocation = v.Location
        end

        local index = findLast(v.Entity, '%)')
        if (index == -1 or index == nil) then
            index = 1
        else
            index = index + 2
        end
        local entityName = string.sub(v.Entity, index)

        canAdd = true
        nameTags = ''

        if not (match == '') then
            canAdd = false
            local matchParts = csplit(match, '|')
            for i, p in pairs(matchParts) do
                if (string.match(string.lower(v.Entity), string.lower(p))) then
                    canAdd = true
                    entityName = '(' .. string.upper(p) .. ') ' .. entityName
                end
            end
        end

        if (canAdd and not (entityName == nil) and not (entityName == '')) then
            totalCount = totalCount + 1
            if (names == '') then
                names = entityName
                nameCount = 1
            else
                names = names .. ', ' .. entityName
                nameCount = nameCount + 1
            end
        end
    end

    if not (names == '') then
        Pyre.Execute(Pyre.Settings.Channel .. ' ' .. lastLocation .. ' [' .. nameCount .. ']: ' .. names)
    end
    if not (totalCount == 0) then
        Pyre.Execute(Pyre.Settings.Channel .. ' Total matched ' .. totalCount)
    else
        Pyre.Execute(Pyre.Settings.Channel .. ' No matches')
    end
end

return Feature
