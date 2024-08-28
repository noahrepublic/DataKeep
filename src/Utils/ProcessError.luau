--!strict

local Config = require(script.Parent.Parent.Config)
local Signals = require(script.Parent.Parent.Signals)
local States = require(script.Parent.Parent.States)

local function processError(err: string, priority: number)
	Signals.IssueSignal:Fire(err)

	priority = priority or 1

	-- priorities:
	-- 0: no issue signal, warn
	-- 1: warn
	-- 2: error issue signal

	if priority > 1 then
		error(`[DataKeep] {err}`)
	else
		warn(`[DataKeep] {err}`)
	end

	local clock = os.clock()

	if priority ~= 0 then
		table.insert(States.issueQueue, clock)
	end

	if States.issueQueue[Config.criticalStateThreshold + 1] then
		table.remove(States.issueQueue, Config.criticalStateThreshold + 1)
	end

	local issueCount = 0

	for _, issueTime in States.issueQueue do
		if clock - issueTime < Config.maxIssueTime then
			issueCount += 1
		end
	end

	if issueCount >= Config.criticalStateThreshold then
		States.isCriticalState = true
		Signals.CriticalStateSignal:Fire()
	end
end

return processError
