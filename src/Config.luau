--!strict

local config = {
	assumeDeadLock = 10 * 60, -- how long without updates to assume the session is dead
	-- according to clv2, os.time is synced roblox responded in a bug report. I don't see why it would in the first place anyways

	internalKeepCleanupInterval = 2, -- used to clean up released keeps

	saveInterval = 30,
	forceLoadMaxAttempts = 6, -- attempts taken before ForceLoad request steals the active session for a keep
	releaseRetryMaxAttempts = 5, -- retry attempts taken before keep:Release() will be marked as failed

	criticalStateThreshold = 5, -- how many failed requests before we assume they are down
	maxIssueTime = 60, -- how long to keep issues in the queue

	loadMethods = table.freeze({
		ForceLoad = "ForceLoad",
		Steal = "Steal",
		Cancel = "Cancel",
	}),
}

return config
