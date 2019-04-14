local Core = require("pyre.core")

Core.Log("scanner.lua loaded", Core.LogLevel.DEBUG)

Scanner = {}

local function Start() Core.Log("Start scanner") end

local function Stop() Core.Log("Stop scanner") end

local function Report() Core.Log("Scanner Report") end

local function ShowHelp() Core.Log("pyre scan start|stop|report") end

Scanner.Start = Start
Scanner.Stop = Stop
Scanner.Report = Report
Scanner.ShowHelp = ShowHelp
return Scanner

