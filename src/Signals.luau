--!strict

local Signal = require(script.Parent.Parent.Signal)

local signals = {
	CriticalStateSignal = Signal.new(), -- fires when we enter critical state
	IssueSignal = Signal.new(), -- fires when we have an issue (issue logging)
}

return signals
