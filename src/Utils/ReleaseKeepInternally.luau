--!strict

local States = require(script.Parent.Parent.States)
local Types = require(script.Parent.Parent.Types)

local function releaseKeepInternally<T>(keep: Types.keep<T>)
	States.loadedKeeps[keep:Identify()] = nil

	States.cachedKeepPromises[keep:Identify()] = nil

	keep:Destroy()
end

return releaseKeepInternally
