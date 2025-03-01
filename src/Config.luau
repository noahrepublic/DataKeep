--!strict

local Enums = require(script.Parent.Enums)

local config = {
	--- how long without updates to assume the session is dead
	assumeDeadLock = 10 * 60,

	--- used to clean up released keeps
	internalKeepCleanupInterval = 2,

	--- for how long attempt to retry failed datastore calls in :LoadKeep() (only applies when every datastore call fails)
	loadKeepDataStoreFailTimeout = 2 * 60,

	--- how long to wait between auto saves
	saveInterval = 30,

	--- attempts taken before ForceLoad request steals the active session for a keep
	forceLoadMaxAttempts = 7,

	--- retry attempts taken before keep:Release() will be marked as failed
	releaseRetryMaxAttempts = 5,

	--- how many failed requests before we assume they are down
	criticalStateThreshold = 5,

	--- how long to keep issues in the queue
	maxIssueTime = 60,

	--- how long to keep DataKeep in critical state after issue count gets below criticalStateThreshold
	maxCriticalStateTime = 60,

	--- the verbosity of the logging
	logLevel = Enums.LogLevel.Warn,

	--- if promise traceback should be included in logs
	logPromiseTraceback = false,
}

return config
