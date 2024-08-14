--> Services

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

--> Includes

local Promise = require(script.Parent.Promise)
local Signal = require(script.Parent.Signal)

local DeepCopy = require(script.Utils.DeepCopy)
local DefaultData = require(script.DefaultData)
local Keep = require(script.Keep)
local MockStore = require(script.MockStore)
local UpdateKeepAsync = require(script.UpdateKeepAsync)

--> Structure

--[=[
	@class Store
	@server
	A store is a class that holds inner savable objects, Keep(s), from a datastore [DataStoreService:GetDataStore()](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetDataStore)
]=]

local Store = {
	LoadMethods = {
		ForceLoad = "ForceLoad",
		Steal = "Steal",
		Cancel = "Cancel",
	},

	_mockStore = false, -- enabled when DataStoreService is not available (Studio)

	_saveInterval = 30,
	_internalKeepCleanupInterval = 2, -- used to clean up released keeps
	_assumeDeadLock = 10 * 60, -- how long without updates to assume the session is dead
	-- according to clv2, os.time is synced roblox responded in a bug report. I don't see why it would in the first place anyways
	_forceLoadMaxAttempts = 6, -- attempts taken before ForceLoad request steals the active session for a keep
	_releaseRetryMaxAttempts = 5, -- retry attempts taken before keep:Release() will be marked as failed

	ServiceDone = false, -- is shutting down?

	CriticalState = false, -- closet thing to tracking if they are down, will be set to true after many failed requests
	_criticalStateThreshold = 5, -- how many failed requests before we assume they are down
	CriticalStateSignal = Signal.new(), -- fires when we enter critical state

	IssueSignal = Signal.new(), -- fires when we have an issue (issue logging)
	_issueQueue = {}, -- queue of issues to keep track of if CriticalState should activate
	_maxIssueTime = 60, -- how long to keep issues in the queue

	_storeQueue = {}, -- list of stores that are currently loaded
}
Store.__index = Store

Keep._releaseRetryMaxAttempts = Store._releaseRetryMaxAttempts

local GlobalUpdates = {}
GlobalUpdates.__index = GlobalUpdates

--> Types

--[=[
	@type StoreInfo { Name: string, Scope: string? }
	@within Store

	Table format for a store's info in [.GetStore()](#GetStore)
]=]

export type StoreInfo = {
	Name: string,
	Scope: string?,
}

type MockStore = MockStore.MockStore

export type Promise = typeof(Promise.new(function() end))

export type Keep = Keep.Keep

--[=[
	@type Store { LoadMethods: LoadMethods, Mock: MockStore, LoadKeep: (string, unreleasedHandler?) -> Promise<Keep>, ViewKeep: (string) -> Promise<Keep>, PreSave: (({ any }) -> { any }) -> (), PreLoad: (({ any }) -> { any }) -> (), PostGlobalUpdate: (string, (GlobalUpdates) -> ()) -> Promise<void>, IssueSignal: Signal, CriticalStateSignal: Signal, CriticalState: boolean }
	@within Store

	Stores are used to load and save Keeps from a [DataStoreService:GetDataStore()](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetDataStore)
]=]

--[=[
	@prop LoadMethods LoadMethods
	@within Store
]=]

--[=[
	@prop Wrapper {}
	@within Store

	Wrapper functions that are inheritted by Keeps when they are loaded

	:::info
	Any wrapper changes post [.GetStore()](#GetStore) will not apply to that store but the next one.
	:::info
]=]

--[=[
	@prop Mock MockStore
	@within Store

	A mock store that mirrors the real store, but doesn't save data
]=]

--[=[
	@prop IssueSignal Signal
	@within Store

	Fired when an issue occurs, like a failed request

	```lua
	keepStore.IssueSignal:Connect(function(err)
		print("Issue!", err)
	end)
	```
]=]

--[=[
	@prop CriticalStateSignal Signal
	@within Store

	Fired when the store enters critical state. After it has failed many requests and maybe dangerous to proceed with purchases or other important actions

	```lua
	keepStore.CriticalStateSignal:Connect(function()
		print("Critical State!")
	end)
	```
]=]

--[=[
	@prop CriticalState boolean
	@within Store

	Whether the store is in critical state or not. See [CriticalStateSignal](#CriticalStateSignal)

	```lua
	if keepStore.CriticalState then
		warn("Critical State!")
		return
	end

	-- process purchase
	```
]=]

--[=[
	@prop validate ({ [string]: any }) -> true | (false & string)
	@within Store

	Used to validate data before saving. Ex. type guards

	```lua
	keepStore.validate = function(data)
		for key, value in data do
			local dataTempVersion = dataTemplate[key]

			if typeof(data[key]) ~= typeof(dataTempVersion) then
				return false, `Invalid type for key: {key}`
			end
		end

		return true
	end
	```
]=]

export type Store = typeof(Store) & {
	_store_info: StoreInfo,
	_data_template: { [string]: any },

	_store: DataStore,
	Mock: MockStore.MockStore,

	_isMockEnabled: boolean,

	Wrapper: { [string]: (any) -> any },

	validate: (data: { [string]: any }) -> (boolean, string?),

	_cachedKeepPromises: { [string]: Promise },
}

export type GlobalUpdates = typeof(setmetatable({}, GlobalUpdates))

--[=[
	@type LoadMethods { ForceLoad: string, Steal: string, Cancel: string }
	@within Store

	### "ForceLoad" (default)

	Attempts to load the Keep. If the Keep is session-locked, it will either be released for that remote server or "stolen" if it's not responding (possibly in dead lock).


	### "Steal"

	Loads keep immediately, ignoring an existing remote session lock and applying a session lock for this session.


	### "Cancel"

	Cancels the load of the Keep
]=]

--[=[
	@type unreleasedHandler (Keep.ActiveSession) -> string
	@within Store

	Used to determine how to handle an session locked Keep.

	:::info
	Check [LoadMethods] for more info.
	:::info
]=]

export type unreleasedHandler = (Keep.Session) -> string -- use a function for any purposes, logging, whitelist only certain places, etc

--> Private Variables

local Keeps: { [string]: Keep } = {} -- queues to save

local autoSaveCycle = 0
local internalKeepCleanupCycle = 0

--> Private Functions

local function createMockStore(storeInfo: StoreInfo, dataTemplate) -- complete mirror of real stores, minus mock related data as we are in a mock store
	return setmetatable({
		_store_info = storeInfo,
		_data_template = dataTemplate,

		_store = MockStore.new(),

		_isMockEnabled = true,

		_cachedKeepPromises = {},

		_processError = (nil :: any) :: (err: string, priority: number) -> (),

		Wrapper = require(script.Wrapper),

		validate = function()
			return true
		end,
	}, Store)
end

local function releaseKeepInternally(keep: Keep)
	Keeps[keep:Identify()] = nil

	keep._keep_store._cachedKeepPromises[keep:Identify()] = nil

	keep:Destroy()
end

--[[
	Future idea: I doubt it is needed so it may just throttle speed.

	local function getRequestBudget(keep)
		return keep._store:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
	end
]]

--> Public Functions

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
	Store._mockStore = if not Store.ServiceDone then not isLive else true -- check for Store.ServiceDone to prevent loading keeps during BindToClose()
end)

--[=[
	@function GetStore
	@within Store

	@param storeInfo StoreInfo | string
	@param dataTemplate any

	@return Promise<Store>

	Loads a store from a [DataStoreService:GetDataStore()](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetDataStore) and returns a Store object

	```lua
	local keepStore = DataKeep.GetStore("TestStore", {
		Test = "Hello World!",
	}):expect()
	```
]=]

function Store.GetStore(storeInfo: StoreInfo | string, dataTemplate: { [string]: any }): Promise
	local info: StoreInfo

	if typeof(storeInfo) == "string" then
		info = {
			Name = storeInfo,
			Scope = nil,
		}
	else
		info = storeInfo
	end

	local id = `{info.Name}{info.Scope or ""}`

	if Store._storeQueue[id] then
		return Promise.resolve(Store._storeQueue[id])
	end

	return mockStoreCheck:andThen(function()
		local self = setmetatable({
			_store_info = info,
			_data_template = dataTemplate,

			_store = if Store._mockStore then MockStore.new() else DataStoreService:GetDataStore(info.Name, info.Scope), -- this always returns even with datastores down, so only way of tracking is via failed requests

			Mock = createMockStore(info, dataTemplate), -- revealed to api

			_isMockEnabled = if Store._mockStore then true else false, -- studio only/datastores not available

			_cachedKeepPromises = {},

			validate = function()
				return true
			end,

			Wrapper = require(script.Wrapper),
		}, Store)

		Store._storeQueue[id] = self._store

		local function processError(err: string, priority: number): ()
			Store.IssueSignal:Fire(err)

			priority = priority or 1

			-- priorities:
			-- 0: no issue signal, warn
			-- 1: warn
			-- 2: error issue signal

			if priority > 1 then
				error(`[DataKeep] {err}`)
			else
				warn(`[DataKeep] {err}`)
			end

			local clock = os.clock()

			if priority ~= 0 then
				table.insert(Store._issueQueue, clock)
			end

			if Store._issueQueue[Store._criticalStateThreshold + 1] then
				table.remove(Store._issueQueue, Store._criticalStateThreshold + 1)
			end

			local issueCount = 0

			for _, issueTime in Store._issueQueue do
				if clock - issueTime < Store._maxIssueTime then
					issueCount += 1
				end
			end

			if issueCount >= Store._criticalStateThreshold then
				Store.CriticalState = true
				Store.CriticalStateSignal:Fire()
			end
		end

		self._processError = processError
		self.Mock._processError = processError

		return Promise.resolve(self)
	end)
end

--[=[
	@method LoadKeep
	@within Store

	@param key string
	@param unreleasedHandler unreleasedHandler?

	@return Promise<Keep?>

	Loads a Keep from the store and returns a Keep object

	```lua
	keepStore:LoadKeep(`Player_{player.UserId}`, function()
		return keepStore.LoadMethods.ForceLoad
	end)):andThen(function(keep)
		if not keep then
			player:Kick("Session lock interrupted!")
			return
		end

		print(`Loaded {keep:Identify()}!`)
	end)
	```

	:::info
	Stores can be loaded multiple times as they are cached, that way you can call [:LoadKeep()](#LoadKeep) and get the same cached Keeps.
	:::info
]=]

function Store:LoadKeep(key: string, unreleasedHandler: unreleasedHandler?): Promise
	local store = self._store

	if unreleasedHandler == nil then
		unreleasedHandler = function(_)
			return Store.LoadMethods.ForceLoad
		end
	end

	if typeof(unreleasedHandler) ~= "function" then
		error("[DataKeep] unreleasedHandler must be a function")
	end

	local id = `{self._store_info.Name}/{self._store_info.Scope or ""}{self._store_info.Scope and "/" or ""}{key}`

	if not Keeps[id] and Store.ServiceDone then
		warn(`[DataKeep] Server is closing, unable to load new keep for {id}`)
		return Promise.resolve(nil)
	end

	local promise = Promise.try(function()
		if Keeps[id] then
			if not Keeps[id]._releasing and not Keeps[id]._released then
				return Keeps[id]
			end

			-- wait for keep to be released on the same server: https://github.com/noahrepublic/DataKeep/issues/21

			local timer = Store._assumeDeadLock -- in normal conditions there is no way to hit that

			repeat
				timer -= task.wait()
			until Keeps[id] == nil or timer < 0

			if Keeps[id] then
				releaseKeepInternally(Keeps[id]) -- additional cleanup to prevent memory leaks
			end
		elseif self._cachedKeepPromises[id] then
			local promiseStatus = self._cachedKeepPromises[id]:getStatus()

			if promiseStatus ~= Promise.Status.Rejected and promiseStatus ~= Promise.Status.Cancelled then
				-- already loading keep
				return self._cachedKeepPromises[id]
			end
		end

		-- keep released so we can load new keep

		return nil
	end)
		:andThen(function(cachedKeep)
			if cachedKeep then
				return cachedKeep
			end

			if self._isMockEnabled then
				print(`[DataKeep] Using mock store on {id}`)
			end

			local shouldForceLoad = false
			local requestForceLoad = false
			local shouldStealSessionOnForceLoad = false -- used only with ForceLoad
			local shouldStealSession = false -- unreleasedHandler() == Store.LoadMethods.Steal

			local forceLoadAttempts = 0

			return Promise.try(function()
				while true do
					local loadedData, dataStoreKeyInfo = UpdateKeepAsync(key, store, {
						onExisting = function(latestData)
							if Store.ServiceDone then
								return true
							end

							local activeSession = latestData.MetaData.ActiveSession
							local forceLoadSession = latestData.MetaData.ForceLoad

							if activeSession == nil then
								latestData.MetaData.ActiveSession = DeepCopy(DefaultData.MetaData.ActiveSession)
								latestData.MetaData.ForceLoad = nil
							elseif typeof(activeSession) == "table" then
								if not Keep._isThisSession(activeSession) then
									local lastUpdate = latestData.MetaData.LastUpdate

									if lastUpdate ~= nil then
										if os.time() - lastUpdate > Store._assumeDeadLock then
											shouldStealSession = true
										end
									end

									if shouldStealSessionOnForceLoad or shouldStealSession then
										local forceLoadInterrupted = false

										if forceLoadSession ~= nil then
											forceLoadInterrupted = Keep._isThisSession(forceLoadSession) == false
										end

										if not forceLoadInterrupted or shouldStealSession then
											latestData.MetaData.ActiveSession = DeepCopy(DefaultData.MetaData.ActiveSession)
											latestData.MetaData.ForceLoad = nil
										end
									elseif requestForceLoad then
										latestData.MetaData.ForceLoad = DeepCopy(DefaultData.MetaData.ActiveSession)
									end
								else
									latestData.MetaData.ForceLoad = nil
								end
							end

							return false
						end,
						onMissing = function(latestData)
							latestData.Data = DeepCopy(self._data_template)
							latestData.MetaData = DeepCopy(DefaultData.MetaData)
							latestData.MetaData.Created = os.time()
							latestData.UserIds = DeepCopy(DefaultData.UserIds)
						end,
						edit = function(latestData)
							if Store.ServiceDone then
								return true
							end

							local activeSession = latestData.MetaData.ActiveSession

							if activeSession ~= nil and Keep._isThisSession(activeSession) then
								latestData.MetaData.LoadCount += 1
								latestData.MetaData.LastUpdate = os.time()

								if self._preLoad then
									local processedData = self._preLoad(DeepCopy(latestData.Data))

									if not processedData then
										self._processError(":PreLoad() must return a table", 2)
										return true
									end

									latestData.Data = processedData
								end
							end

							return false
						end,
					})

					if not loadedData or not dataStoreKeyInfo then
						-- cancel :LoadKeep() attempt
						return nil
					end

					local activeSession = loadedData.MetaData.ActiveSession

					if not (typeof(activeSession) == "table") then
						-- probably because of Store.ServiceDone
						return nil
					end

					if Keep._isThisSession(activeSession) then
						return {
							loadedData = loadedData,
							dataStoreKeyInfo = dataStoreKeyInfo,
						}
					end

					if shouldForceLoad then
						local forceLoadSession = loadedData.MetaData.ForceLoad
						local forceLoadInterrupted = false

						if forceLoadSession ~= nil then
							forceLoadInterrupted = Keep._isThisSession(forceLoadSession) == false
						end

						if forceLoadInterrupted then
							-- another session tried to force load this keep
							return nil
						end

						if not requestForceLoad then
							forceLoadAttempts += 1

							if forceLoadAttempts == Store._forceLoadMaxAttempts then
								shouldStealSessionOnForceLoad = true
							else
								local attemptsLeft = Store._forceLoadMaxAttempts - forceLoadAttempts
								task.wait(2 ^ (Store._forceLoadMaxAttempts - attemptsLeft)) -- don't ask why, it just works :)
							end
						end

						requestForceLoad = false -- only request a force load once
					else
						local loadMethod = unreleasedHandler(activeSession)

						if not Store.LoadMethods[loadMethod] then
							warn(`[DataKeep] unreleasedHandler returned an invalid value, defaulting to {Store.LoadMethods.ForceLoad}`) -- TODO: Custom Error Class to fire to IssueSignal

							loadMethod = Store.LoadMethods.ForceLoad
						end

						if loadMethod == Store.LoadMethods.Cancel then
							return nil
						elseif loadMethod == Store.LoadMethods.ForceLoad then
							shouldForceLoad = true
							requestForceLoad = true
						elseif loadMethod == Store.LoadMethods.Steal then
							shouldStealSession = true
						end
					end
				end
			end):andThen(function(keepData)
				self._cachedKeepPromises[id] = nil

				if not keepData then
					return nil
				end

				local loadedData = keepData.loadedData
				local dataStoreKeyInfo = keepData.dataStoreKeyInfo

				local keepClass = Keep.new(loadedData, self._data_template)

				if dataStoreKeyInfo then
					keepClass._keyInfo = {
						CreatedTime = dataStoreKeyInfo.CreatedTime,
						UpdatedTime = dataStoreKeyInfo.UpdatedTime,
						Version = dataStoreKeyInfo.Version,
					}
				end

				keepClass._key = key
				keepClass._store = store -- mock store or real store
				keepClass._store_info.Name = self._store_info.Name
				keepClass._store_info.Scope = self._store_info.Scope or ""
				keepClass._keep_store = self

				for functionName, func in self.Wrapper do
					keepClass[functionName] = function(...)
						return func(...)
					end
				end

				Keeps[keepClass:Identify()] = keepClass

				return keepClass
			end)
		end)
		:catch(function(err)
			self._processError(`Unable to load keep for {id}: {err}`, 1)
		end)

	self._cachedKeepPromises[id] = promise
	return promise
end

--[=[
	@method ViewKeep
	@within Store

	@param key string
	@param version string?

	@return Promise<Keep>

	Loads a Keep from the store and returns a Keep object, but doesn't save it

	View-only Keeps have the same functions as normal Keeps, but can not operate on data

	```lua
	keepStore:ViewKeep(`Player_{player.UserId}`):andThen(function(viewOnlyKeep)
		print(`Viewing {viewOnlyKeep:Identify()}!`)
	end)
	```

	:::warning
	View-only Keeps are not cached!
	:::warning

	:::warning
	[Keep:Destroy()](Keep#Destroy) must be called when view-only Keep is not needed anymore.
	:::warning
]=]

function Store:ViewKeep(key: string, version: string?): Promise
	local id = `{self._store_info.Name}/{self._store_info.Scope or ""}{self._store_info.Scope and "/" or ""}{key}`

	if Store.ServiceDone then
		warn(`[DataKeep] Server is closing, unable to view keep for {id}`)
		return Promise.reject(nil)
	end

	return Promise.try(function()
		local loadedData, dataStoreKeyInfo = UpdateKeepAsync(key, self._store, {
			onMissing = function(latestData)
				latestData.Data = DeepCopy(self._data_template)
				latestData.MetaData = DeepCopy(DefaultData.MetaData)
				latestData.MetaData.Created = os.time()
				latestData.UserIds = DeepCopy(DefaultData.UserIds)

				latestData.MetaData.ActiveSession = nil
			end,
		}, { version = version })

		if self._preLoad then
			local processedData = self._preLoad(DeepCopy(loadedData.Data))

			if not processedData then
				self._processError(":PreLoad() must return a table", 2)
				return
			end

			loadedData.Data = processedData
		end

		local keepClass = Keep.new(loadedData, self._data_template)

		if dataStoreKeyInfo then
			keepClass._keyInfo = {
				CreatedTime = dataStoreKeyInfo.CreatedTime,
				UpdatedTime = dataStoreKeyInfo.UpdatedTime,
				Version = dataStoreKeyInfo.Version,
			}
		end

		keepClass._view_only = true
		keepClass._releasing = true
		keepClass._released = true -- incase they call :Release() and it tries to save

		keepClass._key = key
		keepClass._store = self._store -- mock store or real store
		keepClass._store_info.Name = self._store_info.Name
		keepClass._store_info.Scope = self._store_info.Scope or ""
		keepClass._keep_store = self

		for functionName, func in self.Wrapper do -- attach wrapper functions
			keepClass[functionName] = function(...)
				return func(...)
			end
		end

		return keepClass
	end)
end

--[=[
	@method PreSave
	@within Store

	@param callback ({ [string]: any }) -> { [string]: any }

	Runs before saving a Keep, allowing you to modify the data before, like compressing data

	:::caution
	Callback **must** return a new data table.
	:::caution

	:::warning
	```:PreSave()``` can only be set once.
	:::warning

	Compression example:

	```lua
	keepStore:PreSave(function(data)
		local newData = {}

		for key, value in data do
			newData[key] = HttpService:JSONEncode(value)
		end

		return newData
	end)
	```
]=]

function Store:PreSave(callback: ({ [string]: any }) -> { [string]: any }): ()
	assert(self._preSave == nil, "[DataKeep] :PreSave() can only be set once")
	assert(callback and typeof(callback) == "function", "[DataKeep] :PreSave() callback must be a function")

	self._preSave = callback
end

--[=[
	@method PreLoad
	@within Store

	@param callback ({ [string]: any }) -> { [string]: any }

	Runs before loading a Keep, allowing you to modify the data before, like decompressing compressed data

	:::caution
	Callback **must** return a new data table.
	:::caution

	:::warning
	```:PreLoad()``` can only be set once.
	:::warning

	Decompression example:

	```lua
	keepStore:PreLoad(function(data)
		local newData = {}

		for key, value in data do
			newData[key] = HttpService:JSONDecode(value)
		end

		return newData
	end)
	```
]=]

function Store:PreLoad(callback: ({ [string]: any }) -> { [string]: any }): ()
	assert(self._preLoad == nil, "[DataKeep] :PreLoad() can only be set once")
	assert(callback and typeof(callback) == "function", "[DataKeep] :PreLoad() callback must be a function")

	self._preLoad = callback
end

--[=[
	@method PostGlobalUpdate
	@within Store

	@param key string
	@param updateHandler (GlobalUpdates) -> ()

	@return Promise<updatedData,DataStoreKeyInfo>

	Posts a global update to a Keep

	```updateHandler``` reveals globalUpdates to the API

	```lua
	keepStore:PostGlobalUpdate(`Player_{player.UserId}`, function(globalUpdates)
		globalUpdates:AddGlobalUpdate({
			Hello = "World!",
		}):andThen(function(updateId)
			print("Added Global Update!")
		end)
	end)
	```
]=]

function Store:PostGlobalUpdate(key: string, updateHandler: (GlobalUpdates) -> ()): Promise -- gets passed add, lock & change functions
	return Promise.try(function()
		if Store.ServiceDone then
			error("[DataKeep] Server is closing, unable to post global update")
		end

		local store = self._store

		return UpdateKeepAsync(key, store, {
			edit = function(latestData)
				local globalUpdateObject = {
					_updates = latestData.GlobalUpdates,
				}

				setmetatable(globalUpdateObject, GlobalUpdates)

				updateHandler(globalUpdateObject)
			end,
		})
	end):catch(function(err)
		self._processError(`Unable to post GlobalUpdate: {err}`, 1)
	end)
end

--> Global Updates

--[=[
	@class GlobalUpdates
	@server

	Used to add, lock and change global updates

	Revealed through [:PostGlobalUpdate()](Store#PostGlobalUpdate)
]=]

--[=[
	@type GlobalId number
	@within GlobalUpdates

	Used to identify a global update
]=]

--[=[
	@method AddGlobalUpdate
	@within GlobalUpdates

	@param globalData {}

	@return Promise<GlobalId>

	Adds a global update to the Keep

	```lua
	globalUpdates:AddGlobalUpdate({
		Hello = "World!",
	}):andThen(function(updateId)
		print("Added Global Update!")
	end)
	```
]=]

function GlobalUpdates:AddGlobalUpdate(globalData: {}): Promise
	return Promise.new(function(resolve, reject)
		if Store.ServiceDone then
			return reject()
		end

		local globalUpdates = self._updates

		local updateId: number = globalUpdates.Id
		updateId += 1

		globalUpdates.Id = updateId

		table.insert(globalUpdates.Updates, {
			Id = updateId,
			Locked = false,
			Data = globalData,
		})

		return resolve(updateId)
	end)
end

--[=[
	@method GetActiveUpdates
	@within GlobalUpdates

	@return { GlobalUpdate }

	Returns all **active** global updates

	```lua
	local updates = globalUpdates:GetActiveUpdates()

	for _, update in updates do
		print("ActiveUpdate data:", update.Data)
	end
	```
]=]

function GlobalUpdates:GetActiveUpdates(): { Keep.GlobalUpdate }
	if Store.ServiceDone then
		warn("[DataKeep] Server is closing, unable to get active updates") -- maybe shouldn't error incase they don't :catch()?
	end

	local globalUpdates = self._updates

	local updates = {}

	for _, update in globalUpdates.Updates do
		if not update.Locked then
			table.insert(updates, update)
		end
	end

	return updates
end

--[=[
	@method RemoveActiveUpdate
	@within GlobalUpdates

	@param updateId GlobalId

	@return Promise<void>

	Removes an active global update

	```lua
	local updates = globalUpdates:GetActiveUpdates()

	for _, update in updates do
		globalUpdates:RemoveActiveUpdate(update.Id):andThen(function()
			print("Removed Global Update!")
		end)
	end
	```
]=]

function GlobalUpdates:RemoveActiveUpdate(updateId: number): Promise
	return Promise.new(function(resolve, reject)
		if Store.ServiceDone then
			return reject()
		end

		if not updateId or not (typeof(updateId) == "number") then
			return reject()
		end

		local globalUpdates = self._updates

		if globalUpdates.Id < updateId then
			return reject()
		end

		local globalUpdateIndex = nil

		for i = 1, #globalUpdates.Updates do
			if globalUpdates.Updates[i].Id == updateId then
				globalUpdateIndex = i
				break
			end
		end

		if globalUpdateIndex == nil then
			return reject()
		end

		if globalUpdates.Updates[globalUpdateIndex].Locked then
			error("[DataKeep] Unable to remove active update on a locked update")
			return reject()
		end

		table.remove(globalUpdates.Updates, globalUpdateIndex) -- instantly removes internally, unlike locked updates. This is because locked updates can still be deleted mid-processing
		return resolve()
	end)
end

--[=[
	@method ChangeActiveUpdate
	@within GlobalUpdates

	@param updateId GlobalId
	@param globalData {}

	@return Promise<void>

	Change an **active** global update's data to the new data.

	Useful for stacking updates to save space for Keeps that maybe receiving lots of globals. Ex. a content creator receiving gifts
]=]

function GlobalUpdates:ChangeActiveUpdate(updateId: number, globalData: {}): Promise
	return Promise.new(function(resolve, reject)
		if Store.ServiceDone then
			return reject()
		end

		if not updateId or not (typeof(updateId) == "number") then
			return reject()
		end

		local globalUpdates = self._updates

		if globalUpdates.Id < updateId then
			return reject()
		end

		for _, update in globalUpdates.Updates do
			if update.Id == updateId and not update.Locked then
				update.Data = globalData

				return resolve()
			end
		end

		return reject()
	end)
end

game:BindToClose(function()
	Store.ServiceDone = true

	Store._mockStore = true -- mock any new stores

	-- loop through and release (release saves too)

	for _, keep in Keeps do
		if keep._releasing or keep._released then
			continue
		end

		keep:Release()
	end

	-- delay server closing process until all save jobs are completed
	while Keep._activeSaveJobs > 0 do
		task.wait()
	end
end)

local function runAutoSave(deltaTime: number)
	if Store.ServiceDone then
		return
	end

	autoSaveCycle += deltaTime

	if autoSaveCycle < 1 then -- I'm not sure if there will be any performance impact, keeps are still saved within the Store._saveInterval
		return
	end

	autoSaveCycle = 0 -- reset awaiting cycle

	local clock = os.clock()

	for _, keep in Keeps do
		if keep._releasing or keep._released then
			continue
		end
		if clock - keep._last_save < Store._saveInterval then
			continue
		end

		keep:Save():timeout(Store._saveInterval):catch(function(err)
			warn(`[DataKeep] Auto save failed for {keep:Identify()}. {err}`)
		end)
	end
end

local function runKeepCleanup(deltaTime: number)
	-- view-only Keeps are not saved in the Keeps table!
	-- dev needs to cleanup them manually by calling keep:Destroy()

	internalKeepCleanupCycle += deltaTime

	if internalKeepCleanupCycle < Store._internalKeepCleanupInterval then
		return
	end

	internalKeepCleanupCycle = 0 -- reset awaiting cycle

	for _, keep in Keeps do
		if not keep._released then
			continue
		end

		releaseKeepInternally(keep)
	end
end

RunService.Heartbeat:Connect(function(deltaTime)
	runKeepCleanup(deltaTime)
	runAutoSave(deltaTime)
end)

return Store
