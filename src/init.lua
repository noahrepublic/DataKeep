--!nonstrict

--> Services

local DataStoreService = game:GetService("DataStoreService")

local RunService = game:GetService("RunService")

--> Includes

local Promise = require(script.Parent.Promise)
local Signal = require(script.Parent.Signal)

local MockStore = require(script.MockStore)

local Keep = require(script.Keep)

--> Structure

--[=[
	@class Store
	@server
	A store is a class that holds inner savable objects, Keep(s), from a datastore (DataStoreService:GetDataStore())
]=]

local Store = {
	mockStore = false, -- Enabled when DataStoreService is not available (Studio)

	_saveInterval = 30,

	_storeQueue = {}, -- Stores that are currently loaded in the save cycle

	assumeDeadLock = 10 * 60, -- how long without updates to assume the session is dead
	-- according to clv2, os.time is synced roblox responded in a bug report. I don't see why it would in the first place anyways

	ServiceDone = false, -- is shutting down?

	CriticalState = false, -- closet thing to tracking if they are down, will be set to true after many failed requests
	_criticalStateThreshold = 5, -- how many failed requests before we assume they are down
	CriticalStateSignal = Signal.new(), -- fires when we enter critical state

	IssueSignal = Signal.new(), -- fires when we have an issue (issue logging)
	_issueQueue = {}, -- queue of issues to keep track of if CriticalState should activate
	_maxIssueTime = 60, -- how long to keep issues 'valid' in the queue
}
Store.__index = Store

Keep.assumeDeadLock = Store.assumeDeadLock

local GlobalUpdates = {}
GlobalUpdates.__index = GlobalUpdates

--> Private Variables

local Keeps = {} -- queues to save

local JobID = game.JobId
local PlaceID = game.PlaceId
--> Types

--[=[
	@type StoreInfo {Name: string, Scope: string?}

	@within Store

	Table format for a store's info in :GetStore()
]=]

export type StoreInfo = {
	Name: string,
	Scope: string | nil,
}

type MockStore = MockStore.MockStore

export type Promise = typeof(Promise.new(function() end))

--[=[
	@type Store {Mock: MockStore, LoadKeep: (string, UnReleasedHandler?) -> Promise<Keep>, ViewKeep: (string) -> Keep, PostGlobalUpdate: (string, (GlobalUpdates) -> nil) -> Promise<void>}

	@within Store

	Stores are used to load and save Keeps from a DataStoreService:GetDataStore()
]=]

export type Store = typeof(Store) & {
	_store_info: StoreInfo,
	_data_template: any,

	_store: DataStore | nil,
	_mock_store: MockStore | nil,

	_mock: boolean,

	_keeps: { [string]: Keep.Keep },
}

export type GlobalUpdates = typeof(setmetatable({}, GlobalUpdates))

--[=[
	@type UnReleasedActions {Ignore: string, Cancel: string}
	@within Store
]=]

--[=[
	@type UnReleasedHandler (Keep.ActiveSession) -> UnReleasedActions

	@within Store

	Used to determine how to handle an session locked Keep

	### Default: "Ignore"
	
	Ignores the locked Keep and steals the lock, releasing the previous session 

	
	### "Cancel"
	
	Cancels the load of the Keep
]=]
export type UnReleasedHandler = (Keep.ActiveSession) -> string -- use a function for any purposes, logging, whitelist only certain places, etc

--> Private Variables

local saveCycle = 0 -- total heartbeat dt

--> Private Functions

local function len(tbl: { [any]: any })
	local count = 0

	for _ in tbl do
		count += 1
	end

	return count
end

local function canLoad(keep: Keep.KeepStruct)
	-- return not keep.MetaData
	-- 	or not keep.MetaData.ActiveSession -- no active session, so we can load (most likely a new Keep)
	-- 	or keep.MetaData.ActiveSession.PlaceID == PlaceID and keep.MetaData.ActiveSession.JobID == JobID
	-- 	or os.time() - keep.MetaData.LastUpdate < Store.assumeDeadLock

	if not keep.MetaData then
		return true
	end

	if not keep.MetaData.ActiveSession then
		return true
	end

	if keep.MetaData.ActiveSession.PlaceID == PlaceID and keep.MetaData.ActiveSession.JobID == JobID then
		return true
	end

	if os.time() - keep.MetaData.LastUpdate > Store.assumeDeadLock then
		return true
	end

	return false
end

local function createMockStore(storeInfo: StoreInfo, dataTemplate) -- complete mirror of real stores, minus mock related data as we are in a mock store
	return setmetatable({
		_store_info = storeInfo,
		_data_template = dataTemplate,

		_store = MockStore.new(),

		_mock = true,

		_keeps = {},
	}, Store)
end

local function releaseKeepInternally(keep: Keep.Keep)
	Keeps[keep:Identify()] = nil

	local keepStore = keep._keep_store

	print("Releasing Keep", keep:Identify())
	keepStore._cachedKeepPromises[keep:Identify()] = nil
end

local function saveKeep(keep: Keep.Keep, release: boolean): Promise
	return Promise.new(function(resolve)
		local recentKeyInfo: DataStoreKeyInfo

		if keep._store then
			if keep._released then -- already was saved
				releaseKeepInternally(keep)
				resolve()
			end

			recentKeyInfo = keep._store:UpdateAsync(keep._key, function(newestData)
				return keep:_save(newestData, release or false)
			end)
		else
			releaseKeepInternally(keep)
			error("Keep invalid, internally released | Create a GitHub issue if issue persists")
		end

		keep._last_save = os.clock()

		keep._keyInfo = { -- have to map the tuple to a table for type checking (even though tuples are arrays in lua)
			CreatedTime = recentKeyInfo.CreatedTime,
			UpdatedTime = recentKeyInfo.UpdatedTime,
			Version = recentKeyInfo.Version,
		}

		if release then
			keep._released = true
			keep.OnRelease:Fire()

			releaseKeepInternally(keep)
		end

		resolve(recentKeyInfo or {})
	end)
end

--[[
	Future idea: I doubt it is needed so it may just throttle speed.

	local function getRequestBudget(keep) 
		return keep._store:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
	end
]]

--> Public Functions

if RunService:IsStudio() then
	local isLive = false

	Promise.new(function(resolve)
		if game.GameId == 0 then
			isLive = true

			print("[DataKeep] Local file, using mock store")
			return resolve()
		end

		local ok, message = pcall(function()
			DataStoreService:GetDataStore("__LiveCheck"):SetAsync("__LiveCheck", os.time())
		end)

		isLive = ok

		if message then
			if message:find("ConnectFail", 1, true) then
				warn("[DataKeep] No internet connection, using mock store")
			end

			if message:find("403", 1, true) ~= nil or message:find("must publish", 1, true) ~= nil then
				print("[DataKeep] Datastores are not available, using mock store")
			else
				print("[DataKeep] Datastores are available, using real store")
			end
		end

		return resolve()
	end):andThen(function()
		Store.mockStore = isLive
	end)
end

--[=[
	@function GetStore
	@within Store

	@param storeInfo StoreInfo | string
	@param dataTemplate any

	@return Promise<Store>

	Loads a store from a DataStoreService:GetDataStore() and returns a Store object

	```lua
	local keepStore = DataKeep.GetStore("TestStore", {
		Test = "Hello World!",
	}):awaitValue()
	```
]=]

function Store.GetStore(storeInfo: StoreInfo | string, dataTemplate): Promise
	local info: StoreInfo

	if type(storeInfo) == "string" then
		info = {
			Name = storeInfo,
			Scope = nil,
		}
	end

	local identifier = info.Name .. (info.Scope and info.Scope or "")

	if Store._storeQueue[identifier] then
		return Promise.resolve(Store._storeQueue[identifier])
	end

	local self
	self = setmetatable({
		_store_info = info,
		_data_template = dataTemplate,

		_store = if Store.mockStore then MockStore.new() else DataStoreService:GetDataStore(info.Name, info.Scope), -- this always returns even with datastores down, so only way of tracking is via failed requests

		Mock = createMockStore(info, dataTemplate), -- revealed to api

		_mock = if Store.mockStore then true else false, -- studio only/datastores not available

		_cachedKeepPromises = {},
	}, Store)

	Store._storeQueue[identifier] = self._store

	return Promise.resolve(self)
end

--[=[
	@method LoadKeep
	@within Store

	@param key string
	@param unReleasedHandler UnReleasedHandler?

	@return Promise<Keep>

	Loads a Keep from the store and returns a Keep object

	```lua
	keepStore:LoadKeep("Player_" .. player.UserId, function() return "Ignore" end)):andThen(function(keep)
		print("Loaded Keep!")
	end)
	```

	:::info
	Stores can be loaded multiple times as they are cached, that way you can call :LoadKeep() and get the same cached Keeps
	:::info
]=]

function Store:LoadKeep(key: string, unReleasedHandler: UnReleasedHandler): Promise
	local store = self._store

	if self._mock then
		print("Using mock store!")
	end

	if unReleasedHandler == nil then
		unReleasedHandler = function(_)
			return "Ignore"
		end
	end

	if type(unReleasedHandler) ~= "function" then
		error("UnReleasedHandler must be a function")
	end

	local identifier = string.format(
		"%s/%s%s",
		self._store_info.Name,
		if self._store_info.Scope ~= nil then self._store_info.Scope .. "/" else "",
		key
	)

	if Keeps[identifier] then -- TODO: check if got rejected before returning cache
		return Promise.resolve(Keeps[identifier])
	elseif
		self._cachedKeepPromises[identifier]
		and self._cachedKeepPromises[identifier].Status ~= Promise.Status.Rejected
		and self._cachedKeepPromises[identifier].Status ~= Promise.Status.Cancelled
	then
		return self._cachedKeepPromises[identifier]
	end

	local promise
	promise = Promise.new(function(resolve, reject)
		local keep: Keep.KeepStruct = store:GetAsync(key) or {} -- support versions

		local success = canLoad(keep)

		local forceload = nil

		if not success and keep.MetaData.ActiveSession then
			local loadMethod = unReleasedHandler(keep.MetaData.ActiveSession)

			if loadMethod ~= "Ignore" and loadMethod ~= "Cancel" then
				warn("UnReleasedHandler returned an invalid value, defaulting to Ignore") -- TODO: Custom Error Class to fire to IssueSignal

				loadMethod = "Ignore"
			end

			if loadMethod == "Cancel" then
				reject(nil) -- should this return an error object?
				return
			end

			if loadMethod == "Ignore" then
				forceload = {
					PlaceID = PlaceID,
					JobID = JobID,
				}
			end
		end

		local keepClass = Keep.new(keep, self._data_template) -- why does typing break here? no idea.

		keepClass._store = store -- mock store or real store
		keepClass._key = key
		keepClass._store_info.Name = self._store_info.Name
		keepClass._store_info.Scope = self._store_info.Scope or ""

		keepClass._keep_store = self

		keepClass.MetaData.ForceLoad = forceload

		keepClass.MetaData.LoadCount = (keepClass.MetaData.LoadCount or 0) + 1

		self._storeQueue[key] = keepClass

		saveKeep(keepClass, false)

		Keeps[keepClass:Identify()] = keepClass

		self._cachedKeepPromises[identifier] = nil

		resolve(keepClass)
	end)

	self._cachedKeepPromises[identifier] = promise

	return promise
end

--[=[
	@method ViewKeep
	@within Store

	@param key string
	@param version string?

	@return Promise<Keep?>

	Loads a Keep from the store and returns a Keep object, but doesn't save it

	View only Keeps have the same functions as normal Keeps, but can not operate on data

	```lua
	keepStore:ViewKeep("Player_" .. player.UserId):andThen(function(viewOnlyKeep)
		print(`Viewing {viewOnlyKeep:Identify()}`)
	end)
	```
]=]

function Store:ViewKeep(key: string, version: string?): Promise
	return Promise.new(function(resolve)
		local id = string.format(
			"%s/%s%s",
			self._store_info.Name,
			string.format("%s%s", self._store_info.Scope or "", if self._store_info.Scope ~= nil then "/" else ""),
			key
		)

		if Keeps[id] then -- TODO: check if got rejected before returning cache
			return Promise.resolve(Keeps[id])
		elseif
			self._cachedKeepPromises[id]
			and self._cachedKeepPromises[id].Status ~= Promise.Status.Rejected
			and self._cachedKeepPromises[id].Status ~= Promise.Status.Cancelled
		then
			return self._cachedKeepPromises[id]
		end

		local data = self._store:GetAsync(key, version) or {}

		local keepObject = Keep.new(data, self._data_template)

		self._cachedKeepPromises[id] = nil

		keepObject._view_only = true
		keepObject._released = true -- incase they call :release and it tries to save

		return resolve(keepObject)
	end)
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
	keepStore:PostGlobalUpdate("Player_" .. player.UserId, function(globalUpdates)
		globalUpdates:AddGlobalUpdate({
			Hello = "World!",
		}):andThen(function(updateId)
			print("Added Global Update!")
		end)
	end)
	```
]=]

function Store:PostGlobalUpdate(key: string, updateHandler: (GlobalUpdates) -> nil) -- gets passed add, lock & change functions
	return Promise.new(function(resolve)
		if Store.ServiceDone then
			error("Game is closing, can't post global update")
		end

		local id = string.format(
			"%s/%s%s",
			self._store_info.Name,
			string.format("%s%s", self._store_info.Scope or "", if self._store_info.Scope ~= nil then "/" else ""),
			key
		)

		local keep = Keeps[id]

		if not keep then
			keep = self:ViewKeep(key):awaitValue()

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

		return resolve()
	end)
end

--> Global Updates

--[=[
	@class GlobalUpdates
	@server
	
	Used to add, lock and change global updates

	Revealed through ```PostGlobalUpdate```
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

function GlobalUpdates:AddGlobalUpdate(globalData: {})
	return Promise.new(function(resolve, reject)
		if Store.ServiceDone then
			return reject()
		end

		if self._view_only and not self._global_updates_only then -- shouldn't happen, fail safe for anyone trying to break the API
			error("Can't add global update to a view only Keep")
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

	@return {GlobalUpdate}

	Returns all **active** global updates

	```lua
	local updates = globalUpdates:GetActiveUpdates()

	for _, update in ipairs(updates) do
		print(update.Data)
	end
	```
]=]

function GlobalUpdates:GetActiveUpdates()
	if Store.ServiceDone then
		warn("Game is closing, can't get active updates") -- maybe shouldn't error incase they don't :catch?
	end

	if self._view_only and not self._global_updates_only then
		error("Can't get active updates from a view only Keep")
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

function GlobalUpdates:RemoveActiveUpdate(updateId: number)
	return Promise.new(function(resolve, reject)
		if Store.ServiceDone then
			return reject()
		end

		if self._view_only and not self._global_updates_only then
			error("Can't remove active update from a view only Keep")
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
			error("Can't RemoveActiveUpdate on a locked update")
			return reject()
		end

		table.remove(globalUpdates.Updates, globalUpdateIndex) -- instantly removes internally, unlike locked updates. this is because locked updates can still be deleted mid-processing
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

	Useful for stacking updates to save space for Keeps that maybe recieving lots of globals. Ex. A YouTuber recieving gifts
]=]

function GlobalUpdates:ChangeActiveUpdate(updateId: number, globalData: {}): Promise
	return Promise.new(function(resolve, reject)
		if Store.ServiceDone then
			return reject()
		end

		if self._view_only and not self._global_updates_only then
			error("Can't change active update from a view only Keep")
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

local saveLoop

game:BindToClose(function()
	Store.ServiceDone = true
	Keep.ServiceDone = true

	saveLoop:Disconnect()

	-- loop through and release (release saves too)

	local saveSize = len(Keeps)

	if saveSize > 0 then
		local keeps = {}

		for _, keep in Keeps do
			table.insert(keeps, saveKeep(keep, true))
		end

		Promise.allSettled(keeps):await()
	end
end)

saveLoop = RunService.Heartbeat:Connect(function(dt)
	saveCycle += dt

	if saveCycle < Store._saveInterval then
		return
	end

	if Store.ServiceDone then
		return
	end

	saveCycle = 0

	local saveSize = len(Keeps)

	if saveSize > 0 then
		local saveSpeed = Store._saveInterval / saveSize

		saveSpeed = 1

		local clock = os.clock() -- offset the saves so not all at once

		local keeps = {}

		for _, keep in Keeps do
			if clock - keep._last_save < Store._saveInterval then
				continue
			end

			table.insert(
				keeps,
				Promise.delay(saveSpeed)
					:andThen(function()
						saveKeep(keep, false)
					end)
					:catch(function(err)
						Store.IssueSignal:Fire(err)

						table.insert(Store._issueQueue, clock)

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
					end)
			)
		end

		Promise.allSettled(keeps):awaitValue()
	end
end)

return Store
