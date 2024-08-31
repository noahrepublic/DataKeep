--!strict

local Types = require(script.Parent.Types)

local states = {
	isUseMockStore = false, -- enabled when DataStoreService is not available (Studio)
	isServiceDone = false, -- is shutting down?
	isCriticalState = false, -- closet thing to tracking if they are down, will be set to true after many failed requests

	activeSaveJobs = 0,

	cachedKeepPromises = {},

	loadedKeeps = {} :: { [string]: Types.keep<{}> },

	issueQueue = {} :: { number },
	criticalStateStartTime = 0,
}

return states
