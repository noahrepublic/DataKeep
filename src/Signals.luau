--!strict

local Signal = require(script.Parent.Parent.Signal)

type signals = {
	CriticalStateSignal: Signal.ScriptSignal<boolean>,
	IssueSignal: Signal.ScriptSignal<string>,
}

local signals: signals = {
	--- fires when we enter critical state
	CriticalStateSignal = Signal.new(),

	--- fires when we have an issue (issue logging)
	IssueSignal = Signal.new(),
}

return signals
