--!nonstrict

--> Services

local DataStoreService = game:GetService("DataStoreService")

local RunService = game:GetService("RunService")

--> Includes

local Promise = require(script.Promise)
local Signal = require(script.Signal)

local MockStore = require(script.MockStore)

local Keep = require(script.Keep)

--> Structure

local Store = {
	mockStore = false, -- Enabled when DataStoreService is not available (Studio)

	_saveInterval = 30,

	_storeQueue = {}, -- Stores that are currently loaded in the save cycle

	assumeDeadLock = 10 * 60, -- how long without updates to assume the session is dead
	-- according to clv2, os.time is synced roblox responded in a bug report. I don't see why it would in the first place anyways

	ServiceDone = false, -- is shutting down?

	CriticalState = false, -- closet thing to tracking if they are down, will be set to true after many failed requests
	CriticalStateThreshold = 5, -- how many failed requests before we assume they are down
	CriticalStateSignal = Signal.new(), -- fires when we enter critical state

	IssueSignal = Signal.new(), -- fires when we have an issue (issue logging)
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

export type StoreInfo = {
	Name: string,
	Scope: string | nil,
}

type MockStore = MockStore.MockStore

export type Promise = typeof(Promise.new(function() end))

export type Store = typeof(Store) & {
	_store_info: StoreInfo,
	_data_template: any,

	_store: DataStore | nil,
	_mock_store: MockStore | nil,

	_mock: boolean,

	_keeps: { [string]: Keep.Keep },
}

export type GlobalUpdates = typeof(setmetatable({}, GlobalUpdates))

export type UnReleasedHandler = (Keep.ActiveSession) -> string -- use a function for any purposes, logging, whitelist only certain places, etc

--> Private Variables

local saveCycle = 0 -- total heartbeat dt

--> Private Functions

local function len(tbl: { [any]: any })
	local count = 0

	for _ in pairs(tbl) do
		count += 1
	end

	return count
end

local function canLoad(keep: Keep.KeepStruct)
	return not keep.MetaData
		or not keep.MetaData.ActiveSession -- no active session, so we can load (most likely a new Keep)
		or keep.MetaData.ActiveSession.PlaceID == PlaceID and keep.MetaData.ActiveSession.JobID == JobID
		or os.time() - keep.MetaData.LastUpdate < Store.assumeDeadLock
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
end

local function saveKeep(keep: Keep.Keep, release: boolean): Promise
	return Promise.new(function(resolve)
		if keep._store then -- 100% of the time
			if keep._released then -- already was saved
				releaseKeepInternally(keep)
				resolve()
			end

			keep._store:UpdateAsync(keep._key, function(newestData)
				return keep:Save(newestData, release or false)
			end)
		end

		keep._last_save = os.clock()

		print(`Saved Keep: {keep:Identify()}`)

		resolve()
	end)
end

--> Public Functions

if RunService:IsStudio() then
	Store.mockStore = true
end

function Store.GetStore(storeInfo: StoreInfo | string, dataTemplate): Promise
	local info: StoreInfo

	if type(storeInfo) == "string" then
		info = {
			Name = storeInfo,
			Scope = nil,
		}
	end

	local self
	self = setmetatable({
		_store_info = info,
		_data_template = dataTemplate,

		_store = if Store.mockStore then MockStore.new() else DataStoreService:GetDataStore(info.Name, info.Scope), -- this always returns even with datastores down, so only way of tracking is via failed requests

		Mock = createMockStore(info, dataTemplate), -- revealed to api

		_mock = if Store.mockStore then true else false, -- studio only/datastores not available

		_keeps = {},
	}, Store)

	local identifier = info.Name .. (info.Scope and info.Scope or "")

	Store._storeQueue[identifier] = self._store

	return Promise.resolve(self)
end

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

	return Promise.new(function(resolve, reject)
		local keep: Keep.KeepStruct = store:GetAsync(key) or {} -- support versions

		local success = canLoad(keep)

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
				keep.MetaData.ForceLoad = {
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

		self._storeQueue[key] = keepClass

		Keeps[keepClass:Identify()] = keepClass

		resolve(keepClass)
	end)
end

function Store:ViewKeep(key: string): Keep.Keep | nil
	return Promise.new(function(resolve)
		local id = string.format(
			"%s/%s%s",
			self._store_info.Name,
			string.format("%s%s", self._store_info.Scope or "", if self._store_info.Scope ~= nil then "/" else ""),
			key
		)

		local keep = Keeps[id]

		if not keep then
			local data = self._store:GetAsync(key) or {}

			local keepObject = Keep.new(data, self._data_template)

			keepObject._view_only = true
			keepObject._released = true -- incase they call :release and it tries to save

			keep = keepObject
		end

		resolve(keep)
	end)
end

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
			keep = self:LoadKeep(key):awaitValue()
		end

		local globalUpdateObject = {
			_updates = keep.GlobalUpdates,
			_pending_removal = keep._pending_global_lock_removes,
		}

		setmetatable(globalUpdateObject, GlobalUpdates)

		updateHandler(globalUpdateObject)

		return resolve()
	end)
end

--> Global Updates

function GlobalUpdates:AddGlobalUpdate(globalData: {})
	return Promise.new(function(resolve, reject)
		if Store.ServiceDone then
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

function GlobalUpdates:GetActiveUpdates()
	if Store.ServiceDone then
		warn("Game is closing, can't get active updates") -- maybe shouldn't error incase they don't :catch?
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

function GlobalUpdates:RemoveActiveUpdate(updateId: number)
	return Promise.new(function(resolve, reject)
		if Store.ServiceDone then
			return reject()
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

function GlobalUpdates:ChangeActiveUpdate(updateId: number, globalData: {})
	return Promise.new(function(resolve, reject)
		if Store.ServiceDone then
			return reject()
		end

		local globalUpdates = self._updates

		print(globalUpdates)

		if globalUpdates.ID < updateId then
			print("rejected :/")
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
		print("Saving close")
		local keeps = {}

		for _, keep in Keeps do
			table.insert(keeps, saveKeep(keep, true))

			releaseKeepInternally(keep)
		end

		Promise.all(keeps):await()
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

		local clock = os.clock() -- offset the saves so not all at once

		local keeps = {}

		for _, keep in Keeps do
			if clock - keep._last_save < Store._saveInterval then
				continue
			end

			table.insert(keeps, keep)
		end

		Promise.each(keeps, function(keep, _)
			return Promise.delay(saveSpeed):andThen(function() -- used to offset save times so not all at once
				saveKeep(keep, false)
			end)
		end):andThen(function() end)
	end
end)

--[[ Saves
	keep:Save()

	if stealing or released then release from queue

]]

return Store
