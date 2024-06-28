--> Services

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

--> Includes

local Promise = require(script.Parent.Promise)
local Signal = require(script.Parent.Signal)

local Keep = require(script.Keep)
local MockStore = require(script.MockStore)

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
	@type Store { LoadMethods: LoadMethods, Mock: MockStore, LoadKeep: (string, unreleasedHandler?) -> Promise<Keep>, ViewKeep: (string) -> Promise<Keep>, PreSave: (({ any }) -> { any }) -> nil, PreLoad: (({ any }) -> { any }) -> nil, PostGlobalUpdate: (string, (GlobalUpdates) -> nil) -> Promise<void>, IssueSignal: Signal, CriticalStateSignal: Signal, CriticalState: boolean }
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
				return false, "Invalid type for key " .. key
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
	Check [LoadMethods] for more info
	:::info
]=]

export type unreleasedHandler = (Keep.Session) -> string -- use a function for any purposes, logging, whitelist only certain places, etc

--> Private Variables

local Keeps: { [string]: Keep } = {} -- queues to save

local JobID = game.JobId
local PlaceID = game.PlaceId

local autoSaveCycle = 0
local internalKeepCleanupCycle = 0

--> Private Functions

local function len(tbl: { [any]: any })
	local count = 0

	for _ in tbl do
		count += 1
	end

	return count
end

local function deepCopy<T>(t: T): T
	local function copyDeep(tbl: { any })
		local tCopy = table.clone(tbl)

		for k, v in tCopy do
			if type(v) == "table" then
				tCopy[k] = copyDeep(v)
			end
		end

		return tCopy
	end

	return copyDeep(t :: any) :: T
end

local function canLoad(keep: Keep.KeepStruct)
	local metaData = keep.MetaData

	if not metaData then
		return true
	end

	local activeSession = metaData.ActiveSession

	if not activeSession then
		return true
	end

	if Keep._isThisSession(activeSession) then
		return true
	end

	return false
end

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

	local keepStore = keep._keep_store
	keepStore._cachedKeepPromises[keep:Identify()] = nil

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

	if type(storeInfo) == "string" then
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

			for _, issueTime in ipairs(Store._issueQueue) do
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
			player:Kick("Session lock interrupted")
			return
		end

		print(`Loaded {keep:Identify()}!`)
	end)
	```

	:::info
	Stores can be loaded multiple times as they are cached, that way you can call [:LoadKeep()](#LoadKeep) and get the same cached Keeps
	:::info
]=]

function Store:LoadKeep(key: string, unreleasedHandler: unreleasedHandler?): Promise
	local store = self._store

	if unreleasedHandler == nil then
		unreleasedHandler = function(_)
			return Store.LoadMethods.ForceLoad
		end
	end

	if type(unreleasedHandler) ~= "function" then
		error("[DataKeep] unreleasedHandler must be a function")
	end

	local id = `{self._store_info.Name}/{self._store_info.Scope or ""}{self._store_info.Scope and "/" or ""}{key}`

	if self._isMockEnabled then
		print(`[DataKeep] Using mock store on {id}`)
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
			until (Keeps[id]._released and not Keeps[id]) or timer < 0

			if Keeps[id] then
				releaseKeepInternally(Keeps[id]) -- additional cleanup to prevent memory leaks
			end
		elseif self._cachedKeepPromises[id] and self._cachedKeepPromises[id].Status ~= Promise.Status.Rejected and self._cachedKeepPromises[id].Status ~= Promise.Status.Cancelled then
			-- already loading keep
			return self._cachedKeepPromises[id]
		end

		-- keep released so we can load new keep

		return nil
	end):andThen(function(cachedKeep)
		if cachedKeep then
			return cachedKeep
		end

		return Promise.new(function(resolve, reject)
			local keep: Keep.KeepStruct = store:GetAsync(key) or {} -- support versions
			local isInDeadLock = if keep.MetaData then os.time() - keep.MetaData.LastUpdate > Store._assumeDeadLock else false

			local forceLoad = nil
			local shouldStealSession = false

			if isInDeadLock then
				shouldStealSession = true
			elseif not canLoad(keep) and keep.MetaData.ActiveSession then
				local loadMethod = unreleasedHandler(keep.MetaData.ActiveSession)

				if not Store.LoadMethods[loadMethod] then
					warn(`[DataKeep] unreleasedHandler returned an invalid value, defaulting to {Store.LoadMethods.ForceLoad}`) -- TODO: Custom Error Class to fire to IssueSignal

					loadMethod = Store.LoadMethods.ForceLoad
				end

				if loadMethod == Store.LoadMethods.Cancel then
					reject(nil) -- should this return an error object?
					return
				elseif loadMethod == Store.LoadMethods.Steal then
					shouldStealSession = true
				elseif loadMethod == Store.LoadMethods.ForceLoad then
					forceLoad = { PlaceID = PlaceID, JobID = JobID }
				end
			elseif keep.MetaData and keep.MetaData.ForceLoad then
				-- in case of .ForceLoad left in MetaData and no .ActiveSession
				forceLoad = { PlaceID = PlaceID, JobID = JobID }
			end

			if self._preLoad and keep.Data and len(keep.Data) > 0 then
				local processedData = self._preLoad(deepCopy(keep.Data))

				if not processedData then
					self._processError(":PreLoad() must return a table", 2)
					return
				end

				keep.Data = processedData
			end

			local keepClass = Keep.new(keep, self._data_template)

			keepClass._store = store -- mock store or real store
			keepClass._key = key
			keepClass._store_info.Name = self._store_info.Name
			keepClass._store_info.Scope = self._store_info.Scope or ""

			keepClass._keep_store = self

			keepClass.MetaData.LoadCount = (keepClass.MetaData.LoadCount or 0) + 1
			keepClass.MetaData.ForceLoad = forceLoad

			keepClass._forceLoadRequested = forceLoad ~= nil
			keepClass._stealSession = shouldStealSession

			Keeps[keepClass:Identify()] = keepClass

			if keepClass._forceLoadRequested and (not keepClass.MetaData.ActiveSession or not Keep._isThisSession(keepClass.MetaData.ActiveSession)) then
				-- wait for previous :Release() to finish (teleporting between places, etc.)

				local attemptsLeft = Store._forceLoadMaxAttempts

				repeat
					task.wait(2 ^ (Store._forceLoadMaxAttempts - attemptsLeft)) -- don't ask why, it just works :)

					attemptsLeft -= 1

					keepClass:Save():await()

					if keepClass._releasing or keepClass._released then
						resolve(nil) -- ForceLoad interrupted by another server
						return
					end
				until Keep._isThisSession(keepClass.MetaData.ActiveSession) or attemptsLeft == 0

				if keepClass.MetaData.ActiveSession and not Keep._isThisSession(keepClass.MetaData.ActiveSession) and attemptsLeft == 0 then
					keepClass._stealSession = true
					keepClass:Save():await()
				end
			else
				keepClass:Save():await()
			end

			for functionName, func in self.Wrapper do
				keepClass[functionName] = function(...)
					return func(...)
				end
			end

			self._cachedKeepPromises[id] = nil

			resolve(keepClass)
		end)
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
	[Keep:Destroy()](Keep#Destroy) must be called when view-only Keep is not needed anymore
	:::warning
]=]

function Store:ViewKeep(key: string, version: string?): Promise
	return Promise.new(function(resolve)
		local id = `{self._store_info.Name}/{self._store_info.Scope or ""}{self._store_info.Scope and "/" or ""}{key}`
		local isFoundLoadedKeep = false

		if Keeps[id] and not Keeps[id]._released then
			isFoundLoadedKeep = true
		end

		local keep

		if not isFoundLoadedKeep then
			keep = self._store:GetAsync(key, version) or {}
		else
			keep = {
				Data = deepCopy(Keeps[id].Data),
				MetaData = {
					Created = Keeps[id].MetaData.Created,
					LastUpdate = Keeps[id].MetaData.LastUpdate,
					LoadCount = Keeps[id].MetaData.LoadCount,
				},
				-- I think we don't want global updates here
				UserIds = deepCopy(Keeps[id].UserIds),
			}
		end

		if self._preLoad and keep.Data and len(keep.Data) > 0 then
			local processedData = self._preLoad(deepCopy(keep.Data))

			if not processedData then
				self._processError(":PreLoad() must return a table", 2)
				return
			end

			keep.Data = processedData
		end

		local keepObject = Keep.new(keep, self._data_template)

		keepObject._view_only = true
		keepObject._released = true -- incase they call :Release() and it tries to save

		keepObject._store = self._store -- mock store or real store
		keepObject._key = key
		keepObject._store_info.Name = self._store_info.Name
		keepObject._store_info.Scope = self._store_info.Scope or ""

		keepObject._keep_store = self

		for functionName, func in self.Wrapper do -- attach wrapper functions
			keepObject[functionName] = function(...)
				return func(...)
			end
		end

		return resolve(keepObject)
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
	```:PreSave()``` can only be set once
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
	assert(callback and type(callback) == "function", "[DataKeep] :PreSave() callback must be a function")

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
	```:PreLoad()``` can only be set once
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
	assert(callback and type(callback) == "function", "[DataKeep] :PreLoad() callback must be a function")

	self._preLoad = callback
end

--[=[
	@method PostGlobalUpdate
	@within Store

	@param key string
	@param updateHandler (GlobalUpdates) -> nil

	@return Promise<void>

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

function Store:PostGlobalUpdate(key: string, updateHandler: (GlobalUpdates) -> nil): Promise -- gets passed add, lock & change functions
	return Promise.new(function(resolve)
		if Store.ServiceDone then
			error("[DataKeep] Server is closing, can't post global update")
		end

		local id = `{self._store_info.Name}/{self._store_info.Scope or ""}{self._store_info.Scope and "/" or ""}{key}`

		local keep = Keeps[id]

		if not keep then
			keep = self:ViewKeep(key):expect()
			keep._global_updates_only = true
		end

		local globalUpdateObject = {
			_updates = keep.GlobalUpdates,
			_pending_removal = keep._pending_global_lock_removes,
			_view_only = keep._view_only,
			_global_updates_only = keep._global_updates_only,
		}

		setmetatable(globalUpdateObject, GlobalUpdates)

		updateHandler(globalUpdateObject)

		if not keep:IsActive() then
			keep:Release()
		end

		keep.MetaData.LoadCount = (keep.MetaData.LoadCount or 0) + 1

		return resolve()
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
	@type GlobalID number
	@within GlobalUpdates

	Used to identify a global update
]=]

--[=[
	@method AddGlobalUpdate
	@within GlobalUpdates

	@param globalData {}

	@return Promise<GlobalID>

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

		if self._view_only and not self._global_updates_only then -- shouldn't happen, fail safe for anyone trying to break the API
			error("[DataKeep] Can't add global update to a view-only Keep")
			return reject()
		end

		local globalUpdates = self._updates

		local updateId: number = globalUpdates.ID
		updateId += 1

		globalUpdates.ID = updateId

		table.insert(globalUpdates.Updates, {
			ID = updateId,
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

	for _, update in ipairs(updates) do
		print(update.Data)
	end
	```
]=]

function GlobalUpdates:GetActiveUpdates(): { Keep.GlobalUpdate }
	if Store.ServiceDone then
		warn("[DataKeep] Server is closing, can't get active updates") -- maybe shouldn't error incase they don't :catch()?
	end

	if self._view_only and not self._global_updates_only then
		error("[DataKeep] Can't get active updates from a view-only Keep")
		return {}
	end

	local globalUpdates = self._updates

	local updates = {}

	for _, update in ipairs(globalUpdates.Updates) do
		if not update.Locked then
			table.insert(updates, update)
		end
	end

	return updates
end

--[=[
	@method RemoveActiveUpdate
	@within GlobalUpdates

	@param updateId GlobalID

	@return Promise<void>

	Removes an active global update

	```lua
	local updates = globalUpdates:GetActiveUpdates()

	for _, update in ipairs(updates) do
		globalUpdates:RemoveActiveUpdate(update.ID):andThen(function()
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

		if self._view_only and not self._global_updates_only then
			error("[DataKeep] Can't remove active update from a view-only Keep")
			return {}
		end

		local globalUpdates = self._updates

		if globalUpdates.ID < updateId then
			return reject()
		end

		local globalUpdateIndex = nil

		for i = 1, #globalUpdates.Updates do
			if globalUpdates.Updates[i].ID == updateId and not globalUpdates.Updates[i].ID then
				globalUpdateIndex = i
				break
			end
		end

		if globalUpdateIndex == nil then
			return reject()
		end

		if globalUpdates.Updates[globalUpdateIndex].Locked then
			error("[DataKeep] Can't remove active update on a locked update")
			return reject()
		end

		table.remove(globalUpdates.Updates, globalUpdateIndex) -- instantly removes internally, unlike locked updates. This is because locked updates can still be deleted mid-processing
		return resolve()
	end)
end

--[=[
	@method ChangeActiveUpdate
	@within GlobalUpdates

	@param updateId GlobalID
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

		if self._view_only and not self._global_updates_only then
			error("[DataKeep] Can't change active update from a view-only Keep")
			return {}
		end

		local globalUpdates = self._updates

		if globalUpdates.ID < updateId then
			return reject()
		end

		for _, update in ipairs(globalUpdates.Updates) do
			if update.ID == updateId and not update.Locked then
				update.Data = globalData

				return resolve()
			end
		end

		return reject()
	end)
end

game:BindToClose(function()
	Store.ServiceDone = true

	Store._mockStore = true -- mock any new store

	-- loop through and release (release saves too)

	local saveSize = len(Keeps)

	if saveSize > 0 then
		Promise.each(Keeps, function(keep: Keep)
			-- we don't want to return new promise
			keep:Release()
		end)
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

	if autoSaveCycle < Store._saveInterval then
		return
	end

	autoSaveCycle = 0 -- reset awaiting cycle

	local saveSize = len(Keeps)

	if not (saveSize > 0) then
		return
	end

	local clock = os.clock() -- offset the saves so not all at once

	local keeps = {}

	for _, keep in Keeps do
		if keep._releasing or keep._released then
			continue
		end
		if clock - keep._last_save < Store._saveInterval then
			continue
		end

		table.insert(keeps, keep)
	end

	Promise.each(keeps, function(keep: Keep)
		-- we don't want to return new promise
		keep:Save():timeout(Store._saveInterval)
	end)
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
