--!strict

local States = require(script.Parent.Parent.States)
local Types = require(script.Parent.Parent.Types)

local function releaseKeepInternally<T, R>(keep: Types.keep<T, R>)
	States.loadedKeeps[keep:Identify()] = nil

	States.cachedKeepPromises[keep:Identify()] = nil

	keep:Destroy()
end

return releaseKeepInternally
