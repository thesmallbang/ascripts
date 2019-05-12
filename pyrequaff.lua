local Pyre = require('pyrecore')
require('socket')

Pyre.Log('skills.lua loaded', Pyre.LogLevel.DEBUG)

-- ------------------------
--  THESE ARE USING socket.gettime() instead of os.time() for millisecond accuracy
--  LastAttack / AttackQueue.QueuedTime
-- ------------------------

local isafk = false
local lastRoomChanged = socket.gettime()

Quaff = {
    LastQuaff = 0,
    Save = function(q)
        SetVariable('quaff_enabled', q.Enabled)
        SetVariable('quaff_topoff', q.Topoff)
        SetVariable('quaff_container', q.Container)
        q.Hp:Save()
        q.Mp:Save()
        q.Mv:Save()
    end,
    ResetRoomFailed = function(q)
        q.Hp.RoomFailed = false
        q.Mp.RoomFailed = false
        q.Mv.RoomFailed = false
    end,
    Enabled = tonumber(GetVariable('quaff_enabled')) or 0,
    Topoff = tonumber(GetVariable('quaff_topoff')) or 0,
    Container = GetVariable('quaff_container') or '',
    Hp = {
        Name = 'Hp',
        Failed = false,
        RoomFailed = false,
        Percent = tonumber(GetVariable('Quaff_hp_percent')) or 50,
        TopOffPercent = tonumber(GetVariable('Quaff_hp_topoff_percent')) or 50,
        Item = GetVariable('quaff_hp_item') or 'heal',
        DefaultItem = 'heal',
        Save = function(stat)
            SetVariable('quaff_hp_item', stat.Item or 'heal')
            SetVariable('Quaff_hp_topoff_percent', stat.TopOffPercent or 50)
            SetVariable('Quaff_hp_percent', stat.Percent or 50)
        end,
        Needed = function(stat)
            if (stat.Failed == true or stat.RoomFailed == true) then
                return false
            end

            local inCombat = (Pyre.Status.State == Pyre.States.COMBAT)
            return ((Pyre.Status.Hp < Quaff.Hp.Percent and inCombat == true) or
                (Pyre.Status.Hp < Quaff.Hp.TopOffPercent and inCombat == false))
        end
    },
    Mp = {
        Name = 'Mp',
        Failed = false,
        RoomFailed = false,
        Percent = tonumber(GetVariable('Quaff_mp_percent')) or 50,
        TopOffPercent = tonumber(GetVariable('Quaff_mp_topoff_percent')) or 50,
        Item = GetVariable('quaff_mp_item') or 'lotus',
        DefaultItem = 'lotus',
        Save = function(stat)
            SetVariable('quaff_mp_item', stat.Item or 'lotus')
            SetVariable('Quaff_mp_topoff_percent', stat.TopOffPercent or 50)
            SetVariable('Quaff_mp_percent', stat.Percent or 50)
        end,
        Needed = function(stat)
            if (stat.Failed == true or stat.RoomFailed == true) then
                return false
            end
            local inCombat = (Pyre.Status.State == Pyre.States.COMBAT)
            return ((Pyre.Status.Mana < stat.Percent and inCombat == true) or
                (Pyre.Status.Mana < stat.TopOffPercent and inCombat == false))
        end
    },
    Mv = {
        Name = 'Mv',
        Failed = false,
        RoomFailed = false,
        Percent = tonumber(GetVariable('Quaff_mv_percent')) or 50,
        TopOffPercent = tonumber(GetVariable('Quaff_mv_topoff_percent')) or 50,
        Item = GetVariable('quaff_mv_item') or 'move',
        DefaultItem = 'move',
        Save = function(stat)
            SetVariable('quaff_mv_item', stat.Item or 'move')
            SetVariable('Quaff_mv_topoff_percent', stat.TopOffPercent or 50)
            SetVariable('Quaff_mv_percent', stat.Percent or 50)
        end,
        Needed = function(stat)
            if (stat.Failed == true or stat.RoomFailed == true) then
                return false
            end
            local inCombat = (Pyre.Status.State == Pyre.States.COMBAT)
            return ((Pyre.Status.Moves < stat.Percent and inCombat == true) or
                (Pyre.Status.Moves < stat.TopOffPercent and inCombat == false))
        end
    }
}

function Quaff.FeatureStart()
    Quaff.Setup()
end

function Quaff.FeatureSettingHandle(settingName, p1, p2, p3, p4)
    if (string.lower(settingName) ~= 'quaff') then
        return
    end

    if (p2 == nil) then
        return
    end

    local stat = nil
    Pyre.Switch(string.lower(p1)) {
        ['clear'] = function()
            ClearFailedPots()
        end,
        ['enabled'] = function()
            Quaff.Enabled = tonumber(p2) or 0
            if (Quaff.Enabled < 0 or Quaff.Enabled > 1) then
                Quaf.Enabled = 0
            end
            Pyre.Log('quaff enabled: ' .. Quaff.Enabled)
        end,
        ['container'] = function()
            Quaff.Container = tostring(p2) or ''
            Pyre.Log('quaff container: ' .. Quaff.Container)
        end,
        ['topoff'] = function()
            Quaff.Topoff = tonumber(p2) or 0
            if (Quaff.Topoff < 0 or Quaff.Topoff > 1) then
                Quaf.Topoff = 0
            end
            Pyre.Log('quaff topoff: ' .. Quaff.Topoff)
        end,
        ['hp'] = function()
            stat = Quaff.Hp
        end,
        ['mp'] = function()
            stat = Quaff.Mp
        end,
        ['mv'] = function()
            stat = Quaff.Mv
        end
    }

    if (stat ~= nil) then
        Pyre.Switch(string.lower(p2)) {
            ['percent'] = function()
                stat.Percent = tonumber(p3) or 50
                if (stat.Percent < 0) then
                    stat.Percent = 0
                end
                if (stat.Percent > 99) then
                    stat.Percent = 99
                end
                Pyre.Log('quaff ' .. stat.Name .. ' percent : ' .. tostring(stat.Percent))
            end,
            ['topoffpercent'] = function()
                stat.TopOffPercent = tonumber(p3) or 50
                if (stat.TopOffPercent < 0) then
                    stat.TopOffPercent = 0
                end
                if (stat.TopOffPercent > 99) then
                    stat.TopOffPercent = 99
                end
                Pyre.Log('quaff ' .. stat.Name .. ' topoff percent : ' .. tostring(stat.TopOffPercent))
            end,
            ['item'] = function()
                local i = stat.DefaultItem
                if not (p3 == '') then
                    i = p3
                end
                stat.Item = i
                Pyre.Log('quaff ' .. stat.Name .. ' item : ' .. tostring(stat.Item))
            end
        }
    end
    Quaff:Save()
end

function Quaff.FeatureTick()
    --
    --  ALLOWED TO RUN WHILE AFK
    --

    if (Pyre.IsAFK) then
        return
    end
    --
    -- NOT ALLOWED TO RUN WHILE AFK
    --
    CheckForQuaff()
end

function Quaff.FeatureHelp()
    local logTable = {
        {
            {
                Value = 'enabled',
                Tooltip = 'Enable automatically quaffing potions'
            },
            {Value = Quaff.Enabled}
        },
        {
            {
                Value = 'container',
                Tooltip = 'Which container has the potions? Use . to clear'
            },
            {Value = Quaff.Container}
        },
        {
            {
                Value = 'hp item'
            },
            {Value = Quaff.Hp.Item}
        },
        {
            {
                Value = 'hp percent'
            },
            {Value = Quaff.Hp.Percent}
        },
        {
            {
                Value = 'hp topoffpercent'
            },
            {Value = Quaff.Hp.TopOffPercent}
        },
        {
            {
                Value = 'mp item'
            },
            {Value = Quaff.Mp.Item}
        },
        {
            {
                Value = 'mp percent'
            },
            {Value = Quaff.Mp.Percent}
        },
        {
            {
                Value = 'mp topoffpercent'
            },
            {Value = Quaff.Mp.TopOffPercent}
        },
        {
            {
                Value = 'mv item'
            },
            {Value = Quaff.Mv.Item}
        },
        {
            {
                Value = 'mv percent'
            },
            {Value = Quaff.Mv.Percent}
        },
        {
            {
                Value = 'mv topoffpercent'
            },
            {Value = Quaff.Mv.TopOffPercent}
        }
    }

    Pyre.LogTable(
        'Feature: Quaff ',
        'teal',
        {'Setting', 'Value'},
        logTable,
        1,
        true,
        'usage: pyre setting quaff <setting> <value>'
    )
end

function Quaff.FeatureSave()
    Quaff:Save()
end

function ClearFailedPots()
    Quaff.Hp.Failed = false
    Quaff.Mp.Failed = false
    Quaff.Mv.Failed = false
    Pyre.Log('Quaff potion failures have been reset')
end

function CheckForQuaff()
    if ((Quaff.Enabled == 0) or (isafk == true)) then
        return
    end

    if (not (Pyre.Status.State == Pyre.States.COMBAT) and not (Pyre.Status.State == Pyre.States.IDLE)) then
        return
    end

    -- do we need any pots?
    -- these stats need to be a table to avoid all this duplicate code i'm about to write
    -- hp

    if (Quaff.Hp:Needed()) then
        -- is there already another quaff queued for this stat?
        local queued =
            Pyre.First(
            Pyre.ActionQueue,
            function(q)
                return (q.Skill.SkillType == Pyre.SkillType.QuaffHeal or q.Skill.SkillType == Pyre.SkillType.QuaffMana or
                    q.Skill.SkillType == Pyre.SkillType.QuaffMove)
            end
        )

        if (queued == nil) then
            -- queue it
            Pyre.Log('Adding Quaff Hp to Queue', Pyre.LogLevel.DEBUG)

            table.insert(
                Pyre.ActionQueue,
                0,
                {
                    Stat = Quaff.Hp,
                    Skill = {Name = 'QuaffHeal', SkillType = Pyre.SkillType.QuaffHeal},
                    Expiration = socket.gettime() + 20,
                    Execute = function(skill)
                        if (Quaff.Hp:Needed()) then
                            Pyre.Log('Executing Quaff Hp From Queue', Pyre.LogLevel.DEBUG)
                        else
                            Pyre.Log('Aborting Quaff Hp - Virtal OK', Pyre.LogLevel.DEBUG)
                        end

                        if (not (Quaff.Container == '')) then
                            Execute('get ' .. Quaff.Hp.Item .. ' ' .. Quaff.Container)
                        end
                        Execute('quaff ' .. Quaff.Hp.Item)
                    end
                }
            )
        end
    end
    -- mana
    if (Quaff.Mp:Needed()) then
        -- is there already another quaff queued for this stat?
        local queued =
            Pyre.First(
            Pyre.ActionQueue,
            function(q)
                return (q.Skill.SkillType == Pyre.SkillType.QuaffHeal or q.Skill.SkillType == Pyre.SkillType.QuaffMana or
                    q.Skill.SkillType == Pyre.SkillType.QuaffMove)
            end
        )

        if (queued == nil) then
            -- queue it up

            -- to know where we should queue this up we will put it first unless an heal quaff is already queued
            local isHealQueued =
                Pyre.Any(
                Pyre.ActionQueue,
                function(v)
                    return (v.Skill.SkillType == Pyre.SkillType.QuaffHeal)
                end
            )
            local position = (isHealQueued == true and 0 or 1)

            Pyre.Log('Adding Quaff Mana to Queue', Pyre.LogLevel.DEBUG)

            table.insert(
                Pyre.ActionQueue,
                position,
                {
                    Stat = Quaff.Mp,
                    Skill = {Name = 'QuaffMana', SkillType = Pyre.SkillType.QuaffMana},
                    Expiration = socket.gettime() + 20,
                    Execute = function(skill)
                        if (Quaff.Mp:Needed()) then
                            Pyre.Log('Executing Quaff Mp From Queue', Pyre.LogLevel.DEBUG)
                        else
                            Pyre.Log('Aborting Quaff Mp - Virtal OK', Pyre.LogLevel.DEBUG)
                        end

                        if not (Quaff.Container == '') then
                            Execute('get ' .. Quaff.Mp.Item .. ' ' .. Quaff.Container)
                        end
                        Execute('quaff ' .. Quaff.Mp.Item)
                    end
                }
            )
        end
    end
    -- moves

    if (Quaff.Mv:Needed()) then
        -- is there already another quaff queued for this stat?
        local queued =
            Pyre.First(
            Pyre.ActionQueue,
            function(q)
                return (q.Skill.SkillType == Pyre.SkillType.QuaffHeal or q.Skill.SkillType == Pyre.SkillType.QuaffMana or
                    q.Skill.SkillType == Pyre.SkillType.QuaffMove)
            end,
            nil
        )

        if (queued == nil) then
            -- queue it up

            -- to know where we should queue this up we will put it first unless an heal quaff is already queued
            local isHealQueued =
                Pyre.Any(
                Pyre.ActionQueue,
                function(v)
                    return (v.Skill.SkillType == Pyre.SkillType.QuaffHeal)
                end,
                1
            )

            local isManaQueued =
                Pyre.Any(
                Pyre.ActionQueue,
                function(v)
                    return (v.Skill.SkillType == Pyre.SkillType.QuaffMana)
                end,
                2
            )

            -- this is our least priority state to queue so we want to make sure its behind the others
            local position = 0
            if (isHealQueued) then
                position = 1
            end
            if (isManaQueued) then
                position = position + 1
            end

            Pyre.Log('Adding Move Quaff to queue', Pyre.LogLevel.DEBUG)
            table.insert(
                Pyre.ActionQueue,
                position,
                {
                    Stat = Quaff.Mv,
                    Skill = {Name = 'QuaffMove', SkillType = Pyre.SkillType.QuaffMana},
                    Expiration = socket.gettime() + 20,
                    Execute = function(skill)
                        if (Quaff.Mv:Needed()) then
                            Pyre.Log('Executing Quaff Mv From Queue', Pyre.LogLevel.DEBUG)
                        else
                            Pyre.Log('Aborting Quaff Mv - Virtal OK', Pyre.LogLevel.DEBUG)
                        end

                        if not (Quaff.Container == '') then
                            Execute('get ' .. Quaff.Mv.Item .. ' ' .. Quaff.Container)
                        end
                        Execute('quaff ' .. Quaff.Mv.Item)
                    end
                }
            )
        end
    end
end

-- -----------------------------------------------
--  Trigger, Alias Callbacks
-- -----------------------------------------------

function OnQuaffUsed(name, line, wildcards)
    -- just going lazy for now to see what kind of results i get without tracking the potions quaffed at all or
    if (Pyre.ActionQueue == nil) then
        return
    end

    Pyre.Log('Quaff Execute Detected', Pyre.LogLevel.DEBUG)

    local potion =
        Pyre.First(
        Pyre.ActionQueue,
        function(v)
            return (v.Skill.SkillType == Pyre.SkillType.QuaffHeal or v.Skill.SkillType == Pyre.SkillType.QuaffMana or
                v.Skill.SkillType == Pyre.SkillType.QuaffMove)
        end,
        nil
    )

    if ((potion == nil) or (potion.Stat == nil)) then
        return
    end

    potion.Stat.Failed = false
    Quaff.LastQuaff = socket.gettime()
    Pyre.ActionQueue =
        Pyre.Except(
        Pyre.ActionQueue,
        function(v)
            return ((v.Skill.SkillType == Pyre.SkillType.QuaffHeal) or (v.Skill.SkillType == Pyre.SkillType.QuaffMana) or
                (v.Skill.SkillType == Pyre.SkillType.QuaffMove))
        end,
        1
    )
end

function OnQuaffFailed(name, line, wildcards)
    -- just going lazy for now to see what kind of results i get without tracking the potions quaffed at all or
    if (Pyre.ActionQueue == nil) then
        return
    end

    Pyre.Log('Quaff Fail Detected', Pyre.LogLevel.DEBUG)

    local potion =
        Pyre.First(
        Pyre.ActionQueue,
        function(v)
            return (v.Skill.SkillType == Pyre.SkillType.QuaffHeal or v.Skill.SkillType == Pyre.SkillType.QuaffMana or
                v.Skill.SkillType == Pyre.SkillType.QuaffMove)
        end,
        nil
    )

    if (potion == nil) then
        return
    end

    if (wildcards[1] == 'A powerful force quenches your magic.') then
        potion.Stat.RoomFailed = true
        Pyre.Log(
            'Quaff RoomDisabled for ' .. potion.Stat.Name .. " type 'pyre setting quaff clear' to reset",
            Pyre.LogLevel.INFO
        )
    else
        potion.Stat.Failed = true
        Pyre.Log(
            'Quaff Disabled for ' .. potion.Stat.Name .. " type 'pyre setting quaff clear' to reset",
            Pyre.LogLevel.INFO
        )
    end

    Quaff.LastQuaff = 0
    Pyre.ActionQueue =
        Pyre.Except(
        Pyre.ActionQueue,
        function(v)
            return ((v.Skill.SkillType == Pyre.SkillType.QuaffHeal) or (v.Skill.SkillType == Pyre.SkillType.QuaffMana) or
                (v.Skill.SkillType == Pyre.SkillType.QuaffMove))
        end,
        1
    )
end

function QuaffOnStateChanged(stateObject)
    if (stateObject.New == Pyre.States.IDLE) then
        CheckForQuaff()
    end
end

function QuaffOnRoomChanged(changeInfo)
    lastRoomChanged = socket.gettime()
    Quaff:ResetRoomFailed()
end

function Quaff.Setup()
    Pyre.Log('Quaff.Setup (alias+triggers)', Pyre.LogLevel.DEBUG)
    -- subscribe to some core events
    table.insert(Pyre.Events[Pyre.Event.StateChanged], QuaffOnStateChanged)
    table.insert(Pyre.Events[Pyre.Event.RoomChanged], QuaffOnRoomChanged)

    AddTriggerEx(
        'ph_qff',
        "^(You don't have that potion.|A powerful force quenches your magic.|The magic in .* is too strong for you.)$",
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnQuaffFailed',
        0
    )
    AddTriggerEx(
        'ph_qfs',
        '^You quaff (.*)$',
        '',
        trigger_flag.Enabled + trigger_flag.RegularExpression + trigger_flag.Replace + trigger_flag.Temporary, -- + trigger_flag.OmitFromOutput + trigger_flag.OmitFromLog,
        -1,
        0,
        '',
        'OnQuaffUsed',
        0
    )
end

return Quaff
