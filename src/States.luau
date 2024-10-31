--!strict

local Types = require(script.Parent.Types)

local states = {
	--- enabled when DataStoreService is not available (Studio)
	isUseMockStore = false,

	--- is shutting down?
	isServiceDone = false,

	--- closet thing to tracking if they are down, will be set to true after many failed requests
	isCriticalState = false,

	activeSaveJobs = 0,

	cachedKeepPromises = {},

	loadedKeeps = {} :: { [string]: Types.keep<{}, {}> },

	--- queue used for critical state
	issueQueue = {} :: { number },

	criticalStateStartTime = 0,
}

return states
