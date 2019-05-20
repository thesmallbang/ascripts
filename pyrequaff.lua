local Core = require('pyrecore')
local Quaff = {
    Enabled = true, -- set with the settings not here,
    RoomFailed = true,
    DetectedFailures = {} -- state names that have failed
}

Quaff.Config = {
    Events = {
        {
            Type = Core.Event.Tick,
            Callback = function(o)
                Quaff.Tick()
            end
        },
        {
            Type = Core.Event.RoomChanged,
            Callback = function(o)
                Quaff.RoomFailed = false
            end
        }
    },
    Commands = {
        {
            Name = 'quaffreset',
            Description = 'Reset failures',
            Callback = function(line, wildcards)
                -- reset failurs
                Quaff.DetectedFailures = {}
            end
        }
    },
    Settings = {
        {
            Name = 'enabled',
            Description = 'Is automatic quaffing enabled',
            Value = nil,
            Min = 0,
            Max = 1,
            Default = 1,
            OnAfterSet = function(setting)
                if (Core.Status.Started) then
                    Quaff.Enabled = setting.Value
                end
            end
        },
        {
            Name = 'container',
            Description = 'what container are your potions in?',
            Value = nil,
            Default = ''
        },
        {
            Name = 'hpitem',
            Description = 'what container are your potions in?',
            Value = nil,
            Default = 'heal'
        },
        {
            Name = 'hp',
            Description = 'a keyword for your potion',
            Value = nil,
            Min = 1,
            Max = 99,
            Default = 50
        },
        {
            Name = 'hpcombat',
            Description = 'What percent to heal during combat',
            Value = nil,
            Min = 1,
            Max = 99,
            Default = 50
        },
        {
            Name = 'mpitem',
            Description = 'a keyword for your potion',
            Value = nil,
            Default = 'lotus'
        },
        {
            Name = 'mp',
            Description = 'What percent to heal to when out of combat',
            Value = nil,
            Min = 1,
            Max = 99,
            Default = 50
        },
        {
            Name = 'mpcombat',
            Description = 'What percent to heal during combat',
            Value = nil,
            Min = 1,
            Max = 99,
            Default = 50
        },
        {
            Name = 'mvitem',
            Description = 'a keyword for your potion',
            Value = nil,
            Default = 'move'
        },
        {
            Name = 'mv',
            Description = 'What percent to heal to when out of combat',
            Value = nil,
            Min = 1,
            Max = 99,
            Default = 50
        },
        {
            Name = 'mvcombat',
            Description = 'What percent to heal during combat',
            Value = nil,
            Min = 1,
            Max = 99,
            Default = 50
        }
    },
    Triggers = {
        {
            Name = 'WasAbleToQuaff',
            Match = 'You quaff (.*)',
            Callback = function(line, wildcards)
                Quaff.OnQuaffSuccess(line, wildcards)
            end
        },
        {
            Name = 'WasUnableToQuaff',
            Match = "(You don't have that potion.|A powerful force quenches your magic.|The magic in .* is too strong for you.)",
            Callback = function(line, wildcards)
                Quaff.OnQuaffFailed(line, wildcards)
            end
        }
    }
}

function Quaff.Start()
    local shouldEnable = Core.GetSettingValue(Quaff, 'enabled')
    if (shouldEnable == true) then
        Quaff.Enabled = true
    end
end

function Quaff.End()
    Quaff.Enabled = false
end

-- tick could definately be replaced by events with a little work
function Quaff.Tick()
    if (Core.IsAFK or Quaff.Enabled == false) then
        return
    end

    Quaff.QueuePotionIfNeeded()
end

function Quaff.QueuePotionIfNeeded()
    local stats = {
        {Name = 'hp', Type = Core.ActionType.QuaffHeal},
        {Name = 'mp', Type = Core.ActionType.QuaffMana},
        {Name = 'mv', Type = Core.ActionType.QuaffMove}
    }

    Core.Each(
        stats,
        function(s)
            local needed = Quaff.IsStatNeeded(s.Name)
            if
                (needed == true and
                    not (Core.Any(
                        Quaff.DetectedFailures,
                        function(d)
                            return d == s.Name
                        end
                    )))
             then
                -- is there already one in queue?
                if
                    not (Core.Any(
                        Core.ActionQueue,
                        function(a)
                            return (a.Info.ActionType == Core.ActionType.QuaffHeal or
                                a.Info.ActionType == Core.ActionType.QuaffMana or
                                a.Info.ActionType == Core.ActionType.QuaffMove)
                        end
                    ))
                 then
                    Core.AddAction(
                        s.Name,
                        s.Type,
                        function(executedAction)
                            -- get settings
                            local container = Core.GetSettingValue(Quaff, 'container')
                            local item = Core.GetSettingValue(Quaff, s.Name .. 'item')
                            if (container ~= '') then
                                Core.Execute('get ' .. item .. ' ' .. container)
                            end
                            Core.Execute('quaff ' .. item .. '')
                        end,
                        1
                    )
                end
                -- we dont want more than 1 in the queue
                -- so it there was already one or we just added one then leave
                return
            end
        end
    )
end

function Quaff.IsStatNeeded(statname)
    local combatFlag = ''

    if (Core.Status.State == Core.States.COMBAT) then
        combatFlag = 'combat'
    end
    local percent = Core.GetSettingValue(Quaff, statname .. combatFlag)
    local current = 0

    if (statname == 'hp') then
        current = Core.Status.Hp
    end
    if (statname == 'mp') then
        current = Core.Status.Mana
    end
    if (statname == 'mv') then
        current = Core.Status.Moves
    end
    return current <= percent
end

function Quaff.OnQuaffSuccess(line, wildcards)
    Core.RemoveAction('mv')
    Core.RemoveAction('mp')
    Core.RemoveAction('hp')
end

function Quaff.OnQuaffFailed(line, wildcards)
    local potion =
        Core.First(
        Core.ActionQueue,
        function(v)
            return (v.Info.ActionType == Core.ActionType.QuaffHeal or v.Info.ActionType == Core.ActionType.QuaffMana or
                v.Info.ActionType == Core.ActionType.QuaffMove)
        end,
        nil
    )

    if (potion == nil) then
        return
    end

    if (wildcards[1] == 'A powerful force quenches your magic.') then
        Quaff.RoomFailed = true
        Core.Log("Quaff RoomDisabled type 'pyre setting quaff clear' to reset", Core.LogLevel.INFO)
    else
        table.insert(Quaff.DetectedFailures, potion.Info.Name)
        Core.Log(
            'Quaff Disabled for ' .. potion.Info.Name .. " type 'pyre setting quaff clear' to reset",
            Core.LogLevel.INFO
        )
    end

    Quaff.LastQuaff = 0
    Core.RemoveAction(potion.Info.Name)
end

return Quaff
