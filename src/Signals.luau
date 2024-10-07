--!strict

local Signal = require(script.Parent.Parent.Signal)

type signals = {
	CriticalStateSignal: Signal.ScriptSignal<boolean>,
	IssueSignal: Signal.ScriptSignal<string>,
}

local signals: signals = {
	CriticalStateSignal = Signal.new(), -- fires when we enter critical state
	IssueSignal = Signal.new(), -- fires when we have an issue (issue logging)
}

return signals
