local Core = {}

function Switch(case)

    return function(codetable)

        local f

        f = codetable[case] or codetable.default

        if f then

            if type(f) == "function" then

                return f(case)

            else

                error("case " .. tostring(case) .. " not a function")

            end

        end

    end

end

function Log(msg, loglevel) ColorLog(msg, "white", "", loglevel) end

function CleanLog(msg, color, backcolor, loglevel)

    ColorLog(

        "                                                              ",

        "",

        backcolor,

        loglevel

    )

    ColorLog(msg, color, "", loglevel)

    ColorLog(

        "                                                              ",

        "",

        backcolor,

        loglevel

    )

end

function ColorLog(msg, color, backcolor, loglevel)

    if (color == nil or color == "") then color = "" end

    if (backcolor == nil) then backcolor = "" end

    if (loglevel == nil or tonumber(loglevel) == nil) then loglevel = Core.LogLevel.INFO end

    if (Core.Settings.LogLevel > loglevel) then return end

    skipLog = false

    Switch(loglevel){

        [Core.LogLevel.DEBUG] = function() ColourTell("#4D5057", "#FFFFFF", "PYRE") end,

        [Core.LogLevel.INFO] = function() ColourTell("#320A28", "#E0D68A", "PYRE") end,

        [Core.LogLevel.ERROR] = function() ColourTell("#EFA00B", "#591F0A", "PYRE") end,

        default = function() skipLog = true end,

    }

    if (not (skipLog)) then ColourNote(color, backcolor, " " .. msg) end

end

function SendToChannel(msg) end

function AlignmentToCategory(alignment, useBuffer)

    local setting = 99

    local goodMin = 875

    local evilMin = -875

    local neutralMax = 874

    local neutralMin = -874

    if (useBuffer == nil) then useBuffer = false end

    if useBuffer then

        goodMin = goodMin + Core.Settings.AlignmentBuffer

        evilMin = evilMin - Core.Settings.AlignmentBuffer

        neutralMin = neutralMin + Core.Settings.AlignmentBuffer

        neutralMax = neutralMax - Core.Settings.AlignmentBuffer

    end

    if (alignment >= goodMin) then setting = 1 end

    if (alignment >= neutralMin and alignment <= neutralMax) then setting = 2 end

    if (alignment <= evilMin) then setting = 3 end

    return setting

end

function AlignmentCategoryToString(category)

    local setting = "off"

    Switch(category){

        [0] = function() setting = "off" end,

        [1] = function() setting = "good" end,

        [2] = function() setting = "neutral" end,

        [3] = function() setting = "evil" end,

        default = function(x) setting = "invalid" end,

    }

    return setting

end

function SaveSettings()

    SetVariable("Channel", Core.Settings.Channel or "echo")

    SetVariable(

        "AlignmentBuffer",

        Core.Settings.AlignmentBuffer or 300

    )

    SetVariable(

        "LogLevel",

        Core.Settings.LogLevel or Core.LogLevel.INFO

    )

    SetVariable(

        "SkillExpirationWarn",

        Core.Settings.SkillExpirationWarn or 30

    )

end

function ChangeSetting(setting, settingValue)

    if (string.lower(setting) == "channel") then

        Core.Settings.Channel = settingValue or "echo"

        Core.Log("channel : " .. Core.Settings.Channel)

    end

    if (string.lower(setting) == "alignmentbuffer") then

        Core.Settings.AlignmentBuffer = tonumber(settingValue) or 300

        Core.Log("alignmentbuffer : " .. Core.Settings.AlignmentBuffer)

    end

    if (string.lower(setting) == "loglevel") then

        Core.Settings.LogLevel = tonumber(settingValue) or Core.LogLevel.INFO

        Core.Log("loglevel : " .. Core.Settings.LogLevel)

    end

    if (string.lower(setting) == "skillexpirationwarn") then

        Core.Settings.SkillExpirationWarn = tonumber(settingValue) or 30

        Core.Log("skillexpirationwarn : " .. Core.Settings.SkillExpirationWarn)

        didApathyWarn = 0

    end

end

function ShowSettings()

    Core.Log("Channel : " .. Core.Settings.Channel)

    Core.Log("AlignmentBuffer : " .. Core.Settings.AlignmentBuffer)

    Core.Log("LogLevel : " .. Core.Settings.LogLevel)

    Core.Log("SkillExpirationWarn : " .. Core.Settings.SkillExpirationWarn)

end

-- assign any functions to our return object

Core.Log = Log
Core.ColorLog = ColorLog
Core.CleanLog = CleanLog

Core.LogLevel = {OFF = 0, VERBOSE = 1, DEBUG = 2, INFO = 3, ERROR = 4}

Core.AlignmentToCategory = AlignmentToCategory

Core.AlignmentCategoryToString = AlignmentCategoryToString

Core.SaveSettings = SaveSettings

Core.ShowSettings = ShowSettings

Core.ChangeSetting = ChangeSetting

Core.Status = {Started = false, State = -1, RawAlignment = 0}

Core.Switch = Switch

Core.Settings = {

    Channel = GetVariable("Channel") or "echo",

    AlignmentBuffer = tonumber(GetVariable("AlignmentBuffer")) or 300,

    LogLevel = tonumber(GetVariable("LogLevel")) or Core.LogLevel.INFO,

    SkillExpirationWarn = tonumber(GetVariable("SkillExpirationWarn")) or 30,

}

return Core
