--!strict

local DeepFreeze = require(script.Parent.Utils.DeepFreeze)
local Types = require(script.Parent.Types)

type enums = {
	LogLevel: Types.logLevel,
	LoadMethod: Types.loadMethod,
}

-- Note: values have to be the same as keys!

local enums: enums = {
	LogLevel = {
		All = "All",
		Warn = "Warn",
		Error = "Error",
		None = "None",
	},

	LoadMethod = {
		ForceLoad = "ForceLoad",
		Steal = "Steal",
		Cancel = "Cancel",
	},
}

DeepFreeze(enums)

return enums
