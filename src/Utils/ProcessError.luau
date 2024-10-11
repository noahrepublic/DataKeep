--!strict

local Config = require(script.Parent.Parent.Config)
local Signals = require(script.Parent.Parent.Signals)
local States = require(script.Parent.Parent.States)

local function processError(err: string, priority: number?)
	Signals.IssueSignal:Fire(err)

	priority = priority or 1

	-- priorities:
	-- 0: warn (no issue signal)
	-- 1: warn (issue signal)
	-- 2: error (no issue signal)

	if priority > 1 then
		error(`[DataKeep] {err}`)
	else
		warn(`[DataKeep] {err}`)
	end

	local clock = os.clock()

	if priority ~= 0 then
		table.insert(States.issueQueue, clock)
	end

	if not States.isCriticalState and #States.issueQueue >= Config.criticalStateThreshold then
		States.isCriticalState = true
		States.criticalStateStartTime = clock
		Signals.CriticalStateSignal:Fire(States.isCriticalState)
	end
end

return processError
