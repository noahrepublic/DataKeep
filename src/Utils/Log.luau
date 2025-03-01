--!strict

local Config = require(script.Parent.Parent.Config)
local Enums = require(script.Parent.Parent.Enums)
local Message = require(script.Parent.Message)
local Promise = require(script.Parent.Parent.Parent.Promise)
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
	local logLevels = { Enums.LogLevel.All }
	local finalMessage = message

	if table.find(logLevels, Config.logLevel) then
		print("[DataKeep]", finalMessage)
	end

	if shouldEmitIssueSignal then
		emitIssueSignal(finalMessage)
	end

	return Message.new(finalMessage)
end

local function debugWarn(message: string, err: string?, shouldEmitIssueSignal: boolean?)
	local logLevels = { Enums.LogLevel.All, Enums.LogLevel.Warn }
	local finalMessage = message

	if table.find(logLevels, Config.logLevel) then
		if err then
			local isPromiseError = Promise.Error.is(err)

			if not isPromiseError or (isPromiseError and Config.logPromiseTraceback) then
				finalMessage ..= `\n{err}`
			end
		end

		warn("[DataKeep]", finalMessage)
	end

	if shouldEmitIssueSignal then
		emitIssueSignal(finalMessage)
	end

	return Message.new(finalMessage)
end

--[[
	Note: This function does not `error()`
]]

local function debugError(message: string, err: string?, shouldEmitIssueSignal: boolean?)
	local logLevels = { Enums.LogLevel.All, Enums.LogLevel.Warn, Enums.LogLevel.Error }
	local finalMessage = message

	if table.find(logLevels, Config.logLevel) then
		if err then
			local isPromiseError = Promise.Error.is(err)

			if not isPromiseError or (isPromiseError and Config.logPromiseTraceback) then
				finalMessage ..= `\n{err}`
			end
		end

		warn("[DataKeep]", finalMessage)
	end

	if shouldEmitIssueSignal then
		emitIssueSignal(finalMessage)
	end

	return Message.new(finalMessage)
end

return table.freeze({
	print = debugPrint,
	warn = debugWarn,
	error = debugError,
})
