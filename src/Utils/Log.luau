--!strict

local Config = require(script.Parent.Parent.Config)
local Enums = require(script.Parent.Parent.Enums)
local Signals = require(script.Parent.Parent.Signals)
local States = require(script.Parent.Parent.States)

local function checkCriticalState()
	if States.isCriticalState then
		return
	end

	if #States.issueQueue < Config.criticalStateThreshold then
		return
	end

	States.criticalStateStartTime = os.clock()
	States.isCriticalState = true
	Signals.CriticalStateSignal:Fire(States.isCriticalState)
end

local function emitIssueSignal(message: string)
	table.insert(States.issueQueue, os.clock())
	Signals.IssueSignal:Fire(message)

	checkCriticalState()
end

local function debugPrint(message: string, shouldEmitIssueSignal: boolean?)
	if shouldEmitIssueSignal then
		emitIssueSignal(message)
	end

	local allowedLogLevels = { Enums.LogLevel.All }

	if table.find(allowedLogLevels, Config.logLevel) then
		print(message)
	end

	return message
end

local function debugWarn(message: string, shouldEmitIssueSignal: boolean?)
	if shouldEmitIssueSignal then
		emitIssueSignal(message)
	end

	local allowedLogLevels = { Enums.LogLevel.All, Enums.LogLevel.Warn }

	if table.find(allowedLogLevels, Config.logLevel) then
		warn(message)
	end

	return message
end

--[[
	Note: this function does not error()
]]

local function debugError(message: string, shouldEmitIssueSignal: boolean?)
	if shouldEmitIssueSignal then
		emitIssueSignal(message)
	end

	local allowedLogLevels = { Enums.LogLevel.All, Enums.LogLevel.Warn, Enums.LogLevel.Error }

	if table.find(allowedLogLevels, Config.logLevel) then
		warn(message)
	end

	return message
end

return table.freeze({
	print = debugPrint,
	warn = debugWarn,
	error = debugError,
})
