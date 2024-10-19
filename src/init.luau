--!strict

--> Services

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

--> Includes

local Promise = require(script.Parent.Promise)

local Config = require(script.Config)
local PromiseTypes = require(script.PromiseTypes)
local ReleaseKeepInternally = require(script.Utils.ReleaseKeepInternally)
local Signals = require(script.Signals)
local States = require(script.States)
local Store = require(script.Store)
local Types = require(script.Types)
local Wrapper = require(script.Wrapper)

--> Structure

local DataKeep = {
	LoadMethods = Config.loadMethods,

	Wrapper = Wrapper,

	IssueSignal = Signals.IssueSignal, -- fires when we enter critical state
	CriticalStateSignal = Signals.CriticalStateSignal, -- fires when we have an issue (issue logging)

	IsCriticalState = States.isCriticalState,
}

Signals.CriticalStateSignal:Connect(function(isCriticalState)
	DataKeep.IsCriticalState = isCriticalState
end)

--> Types

export type LoadMethods = typeof(Config.loadMethods)
export type Store<T, R> = Types.store<T, R>
export type MockStore<T, R> = Types.mockStore<T, R>
export type Keep<T, R> = Types.keep<T, R>

export type Promise = PromiseTypes.Promise
export type TypedPromise<T...> = PromiseTypes.TypedPromise<T...>
export type Status = PromiseTypes.Status

--[=[
	@class DataKeep
	@server
]=]

--[=[
	@type LoadMethods { ForceLoad: string, Steal: string, Cancel: string }
	@within DataKeep

	### "ForceLoad" (default)

	Attempts to load the Keep. If the Keep is session-locked, it will either be released for that remote server or "stolen" if it's not responding (possibly in dead lock).


	### "Steal"

	Loads keep immediately, ignoring an existing remote session lock and applying a session lock for this session.


	### "Cancel"

	Cancels the load of the Keep
]=]

--[=[
	@type Wrapper { [string]: <T>(self: Keep, ...T) -> () }
	@within DataKeep

	Wrapper functions that are inheritted by Keeps when they are loaded

	:::info
	Any wrapper changes after [.GetStore()](#GetStore) will not apply to that store but the next one.
	:::info
]=]

--[=[
	@prop LoadMethods LoadMethods
	@within DataKeep
]=]

--[=[
	@prop Wrapper Wrapper
	@within DataKeep
]=]

--[=[
	@prop IssueSignal Signal<string>
	@within DataKeep

	Fired when an issue occurs, like a failed request

	```lua
	DataKeep.IssueSignal:Connect(function(err)
		print("Issue!", err)
	end)
	```
]=]

--[=[
	@prop CriticalStateSignal Signal<boolean>
	@within DataKeep

	Fired when the store enters or exits critical state. After it has failed many requests and maybe dangerous to proceed with purchases or other important actions

	```lua
	DataKeep.CriticalStateSignal:Connect(function(isInCriticalState)
		if isInCriticalState then
			print("Critical state started!")
		else
			print("Critical state ended!")
		end
	end)
	```
]=]

--> Private Variables

local autoSaveCycle = 0
local internalKeepCleanupCycle = 0
local loadedStores = {} -- list of stores that are currently loaded

local mockStoreCheck = Promise.new(function(resolve)
	if game.GameId == 0 then
		print("[DataKeep] Local file, using mock store")
		return resolve(false)
	end

	local success, message = pcall(function()
		return DataStoreService:GetDataStore("__LiveCheck"):SetAsync("__LiveCheck", os.time())
	end)

	if success then
		print("[DataKeep] Datastores are available, using real store")
	else
		if message then
			if string.find(message, "ConnectFail", 1, true) then
				warn("[DataKeep] No internet connection, using mock store")
			else
				print("[DataKeep] Datastores are not available, using mock store")
			end
		end
	end

	return resolve(success)
end):andThen(function(isLive)
	States.isUseMockStore = if not States.isServiceDone then not isLive else true -- check for States.isServiceDone to prevent loading keeps during BindToClose()
end)

--> Public Functions

--[=[
	@function GetStore
	@within DataKeep

	@param storeInfo StoreInfo | string
	@param dataTemplate { [string]: any }
	@param wrapper Wrapper | {}

	@return Promise<Store>

	Loads a store from a [DataStoreService:GetDataStore()](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetDataStore) and returns a Store object

	```lua
	local dataTemplate = {
		Test = "Hello World!",
	}

	local keepStore = DataKeep.GetStore("TestStore", dataTemplate, {}):expect()
	```
]=]

function DataKeep.GetStore<T, R>(storeInfo: Types.storeInfo | string, dataTemplate: Types.dataTemplate<T>, wrapper: R): PromiseTypes.TypedPromise<Store<T, R>>
	local info

	if typeof(storeInfo) == "string" then
		info = {
			Name = storeInfo,
			-- no scope
		}
	else
		info = storeInfo
	end

	local id = `{info.Name}{info.Scope or ""}`

	if loadedStores[id] then
		return Promise.resolve(loadedStores[id])
	end

	return mockStoreCheck:andThen(function()
		local self = Store.new(info, dataTemplate, wrapper)

		loadedStores[id] = self._store

		return Promise.resolve(self)
	end)
end

type config = {
	assumeDeadLock: number?,
	internalKeepCleanupInterval: number?,
	saveInterval: number?,
	forceLoadMaxAttempts: number?,
	releaseRetryMaxAttempts: number?,
	criticalStateThreshold: number?,
	maxIssueTime: number?,
	maxCriticalStateTime: number?,
}

--[=[
	@function SetConfig
	@within DataKeep

	@param overwrites { assumeDeadLock: number?, internalKeepCleanupInterval: number?, saveInterval: number?, forceLoadMaxAttempts: number?, releaseRetryMaxAttempts: number?, criticalStateThreshold: number?, maxIssueTime: number?, maxCriticalStateTime: number? }

	Allows to overwrite default config values. Only for experienced developers

	```lua
	DataKeep.SetConfig({
		saveInterval = 60
	})
	```
]=]

function DataKeep.SetConfig(overwrites: config)
	for key, value in overwrites do
		if key == "loadMethods" then -- ignore loadMethods
			continue
		end

		if not Config[key] then
			continue
		end

		if not (typeof(value) == typeof(Config[key])) then
			continue
		end

		Config[key] = value
	end
end

game:BindToClose(function()
	States.isServiceDone = true
	States.isUseMockStore = true -- mock any new stores

	-- loop through and release (release saves too)

	for _, keep in States.loadedKeeps do
		if keep._releasing or keep._released then
			continue
		end

		keep:Release()
	end

	-- delay server closing process until all save jobs are completed
	while States.activeSaveJobs > 0 do
		task.wait()
	end
end)

local function runAutoSave(deltaTime: number)
	if States.isServiceDone then
		return
	end

	autoSaveCycle += deltaTime

	if autoSaveCycle < 1 then -- I'm not sure if there will be any performance impact, keeps are still saved within the Config.saveInterval
		return
	end

	autoSaveCycle = 0 -- reset awaiting cycle

	local clock = os.clock()

	for _, keep in States.loadedKeeps do
		if keep._releasing or keep._released then
			continue
		end
		if clock - keep._lastSaveAttempt < Config.saveInterval then
			continue
		end

		keep:Save():timeout(Config.saveInterval):catch(function(err)
			warn(`[DataKeep] Auto save failed for {keep:Identify()}. {err}`)
		end)
	end
end

local function runKeepCleanup(deltaTime: number)
	-- view-only Keeps are not saved in the States.loadedKeeps table!
	-- dev needs to cleanup them manually by calling keep:Destroy()

	internalKeepCleanupCycle += deltaTime

	if internalKeepCleanupCycle < Config.internalKeepCleanupInterval then
		return
	end

	internalKeepCleanupCycle = 0 -- reset awaiting cycle

	for _, keep in States.loadedKeeps do
		if not keep._released then
			continue
		end

		ReleaseKeepInternally(keep :: any) -- Internal error: Code is too complex to typecheck! Consider adding type annotations around this
	end
end

local function runClearCriticalState()
	if not States.isCriticalState then
		return
	end

	if #States.issueQueue >= Config.criticalStateThreshold then
		-- update criticalStateStartTime until issue count gets below criticalStateThreshold

		States.criticalStateStartTime = os.clock()
	elseif os.clock() - States.criticalStateStartTime > Config.maxCriticalStateTime then
		States.isCriticalState = false
		Signals.CriticalStateSignal:Fire(States.isCriticalState)
	end
end

local function runIssueQueueCleanup()
	local issueTime = States.issueQueue[1]

	if not issueTime then
		return
	end

	if os.clock() - issueTime <= Config.maxIssueTime then
		return
	end

	table.remove(States.issueQueue, 1)
end

RunService.Heartbeat:Connect(function(deltaTime)
	runClearCriticalState()
	runIssueQueueCleanup()

	runKeepCleanup(deltaTime)
	runAutoSave(deltaTime)
end)

return DataKeep
