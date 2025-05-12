--!strict

--> Services

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

--> Includes

local Promise = require(script.Parent.Promise)

local Config = require(script.Config)
local Enums = require(script.Enums)
local Log = require(script.Utils.Log)
local PromiseTypes = require(script.PromiseTypes)
local RemoveKeepInternally = require(script.Utils.RemoveKeepInternally)
local Signals = require(script.Signals)
local States = require(script.States)
local Store = require(script.Store)
local Types = require(script.Types)
local Wrapper = require(script.Wrapper)

--> Structure

local DataKeep = {
	Enums = Enums,

	Wrapper = Wrapper,

	IssueSignal = Signals.IssueSignal, -- fires when we have an issue (issue logging)
	CriticalStateSignal = Signals.CriticalStateSignal, -- fires when we enter / exit critical state

	IsCriticalState = States.isCriticalState,
}

Signals.CriticalStateSignal:Connect(function(isCriticalState)
	DataKeep.IsCriticalState = isCriticalState

	Log.print(`Is in critical state: {isCriticalState}.`)
end)

--> Types

export type Store<T, R> = Types.store<T, R>
export type MockStore<T, R> = Types.mockStore<T, R>
export type Keep<T, R> = Types.keep<T, R>
export type ViewKeep<T, R> = Types.viewOnlyKeep<T, R>

export type Promise = PromiseTypes.Promise
export type TypedPromise<T...> = PromiseTypes.TypedPromise<T...>
export type Status = PromiseTypes.Status

--[=[
	@class DataKeep
	@server
]=]

--[=[
	@type Wrapper { [string]: <T>(self: Keep, ...T) -> () }
	@within DataKeep

	Wrapper functions that are inheritted by Keeps when they are loaded.

	:::info
	Any wrapper changes after [.GetStore()](#GetStore) will not apply to that store but the next one.
	:::
]=]

--[=[
	@type Enums { LoadMethod: LoadMethod, LogLevel: LogLevel }
	@within DataKeep
]=]

--[=[
	@prop Enums Enums
	@within DataKeep
]=]

--[=[
	@prop Wrapper Wrapper
	@within DataKeep
]=]

--[=[
	@prop IssueSignal Signal<string>
	@within DataKeep

	Fired when an issue occurs, like a failed request.

	```lua
	DataKeep.IssueSignal:Connect(function(err)
		print("Issue!", err)
	end)
	```
]=]

--[=[
	@prop CriticalStateSignal Signal<boolean>
	@within DataKeep

	Fired when the store enters or exits critical state. After it has failed many requests and maybe dangerous to proceed with purchases or other important actions.

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
	-- defer in case .SetConfig() was called

	task.defer(function()
		if not RunService:IsStudio() then
			Log.print("Live server, using real store.")
			resolve(true)
			return
		end

		if game.GameId == 0 then
			Log.warn("Local file, using mock store.")
			resolve(false)
			return
		end

		local success, message = pcall(function()
			return DataStoreService:GetDataStore("__LiveCheck"):SetAsync("__LiveCheck", os.time())
		end)

		if success then
			Log.print("Datastores are available, using real store.")
		else
			if message then
				if string.find(message, "ConnectFail", 1, true) then
					Log.warn("No internet connection, using mock store.")
				else
					Log.warn("Datastores are not available, using mock store.")
				end
			end
		end

		resolve(success)
	end)
end):andThen(function(isLive)
	States.isUseMockStore = if not States.isServiceDone then not isLive else true -- check for States.isServiceDone to prevent loading keeps during BindToClose()
end)

--> Public Methods

--[=[
	@function GetStore
	@within DataKeep

	@param storeInfo StoreInfo | string
	@param dataTemplate { [string]: any }
	@param wrapper Wrapper | {}

	@return Promise<Store>

	Loads a store from a [DataStoreService:GetDataStore()](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetDataStore) and returns a Store object.

	```lua
	local dataTemplate = {
		Test = "Hello World!",
	}

	local store = DataKeep.GetStore("TestStore", dataTemplate, {}):expect()
	```

	:::info
	Stores can be loaded multiple times as they are cached.
	:::
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

	local id = `{info.Name}/{info.Scope or ""}`

	if loadedStores[id] then
		return Promise.resolve(loadedStores[id])
	end

	return mockStoreCheck:andThen(function()
		local self = Store.new(info, dataTemplate, wrapper)

		loadedStores[id] = self

		return Promise.resolve(self)
	end)
end

type config = {
	assumeDeadLock: number?,
	internalKeepCleanupInterval: number?,
	loadKeepDataStoreFailTimeout: number?,
	saveInterval: number?,
	forceLoadMaxAttempts: number?,
	releaseRetryMaxAttempts: number?,
	criticalStateThreshold: number?,
	maxIssueTime: number?,
	maxCriticalStateTime: number?,
	logLevel: string?,
	logPromiseTraceback: boolean?,
}

--[=[
	@function SetConfig
	@within DataKeep

	@param overwrites { assumeDeadLock: number?, internalKeepCleanupInterval: number?, loadKeepDataStoreFailTimeout: number?, saveInterval: number?, forceLoadMaxAttempts: number?, releaseRetryMaxAttempts: number?, criticalStateThreshold: number?, maxIssueTime: number?, maxCriticalStateTime: number?, logLevel: string?, logPromiseTraceback: boolean? }

	Allows to overwrite default config values. Only for experienced developers.

	```lua
	DataKeep.SetConfig({
		logLevel = DataKeep.Enums.LogLevel.None,
		saveInterval = 60,
	})
	```

	:::info
	Should be used before any other functions.
	:::
]=]

function DataKeep.SetConfig(overwrites: config)
	for key, value in overwrites do
		if Config[key] == nil then
			continue
		end

		if not (typeof(value) == typeof(Config[key])) then
			continue
		end

		if key == "logLevel" then
			if not Enums.LogLevel[value] then
				continue
			end
		end

		Config[key] = value
	end
end

game:BindToClose(function()
	Log.print("Server is closing, releasing all loaded keeps.")

	States.isServiceDone = true
	States.isUseMockStore = true -- mock any new stores

	-- loop through and release (release saves too)

	for _, keep in States.loadedKeeps do
		if keep._releasing or keep._released then
			continue
		end

		keep:Release()
	end

	-- delay server closing process until all datastore jobs are completed
	while States.activeDataStoreJobs > 0 do
		task.wait()
	end

	Log.print("Released all loaded keeps.")
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

		keep:Save():timeout(Config.saveInterval):catch(function()
			Log.warn(`Auto save failed for {keep:Identify()}.`)
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

		RemoveKeepInternally(keep :: any) -- Internal error: Code is too complex to typecheck! Consider adding type annotations around this
		Log.print(`Removed {keep:Identify()} internally.`)
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
