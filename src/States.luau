--!strict

local Types = require(script.Parent.Types)

local states = {
	--- enabled when DataStoreService is not available (Studio) or when server is closing
	isUseMockStore = false,

	--- is server shutting down?
	isServiceDone = false,

	--- will be set to true after many failed datastore requests
	isCriticalState = false,

	--- indicator for :BindToClose() that not everything is done yet
	activeDataStoreJobs = 0,

	cachedKeepPromises = {},

	--- list of stores that are currently loaded
	loadedStores = {} :: { [string]: Types.store<{}> },

	--- list of keeps that are currently loaded
	loadedKeeps = {} :: { [string]: Types.keep<{}> },

	--- queue used for critical state
	issueQueue = {} :: { number },

	--- os.time() when DataKeep entered critical state
	criticalStateStartTime = 0,

	autoSaveCycle = 0,

	internalKeepCleanupCycle = 0,
}

return states
