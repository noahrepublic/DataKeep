--!strict

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

	_saveInterval = 5, --30,

	_storeQueue = {}, -- Stores that are currently loaded in the save cycle

	assumeDeadLock = 5 * 60, -- how long without updates to assume the session is dead
	-- according to clv2, os.time is synced roblox responded in a bug report. I don't see why it would in the first place anyways

	ServiceDone = false, -- is shutting down?

	CriticalState = false, -- closet thing to tracking if they are down, will be set to true after many failed requests
	CriticalStateThreshold = 5, -- how many failed requests before we assume they are down
	CriticalStateSignal = Signal.new(), -- fires when we enter critical state

	IssueSignal = Signal.new(), -- fires when we have an issue (issue logging)
}

local Keeps = {} -- queues to save

Store.__index = Store

Keep.assumeDeadLock = Store.assumeDeadLock

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

local function DeepCopy(tbl: { [any]: any })
	local copy = {}

	for key, value in pairs(tbl) do
		if type(value) == "table" then
			copy[key] = DeepCopy(value)
		else
			copy[key] = value
		end
	end

	return copy
end

local function canLoad(keep: Keep.KeepStruct)
	return not keep.MetaData
		or not keep.MetaData.ActiveSession -- no active session, so we can load (most likely a new Keep)
		or keep.MetaData.ActiveSession.PlaceID == PlaceID and keep.MetaData.ActiveSession.JobID == JobID
		or os.time() - keep.MetaData.LastUpdate < Store.assumeDeadLock
end

local function releaseKeepInternally(keep: Keep.Keep)
	print("Released internally")
	Keeps[keep:Identify()] = nil
end

local function saveKeep(keep: Keep.Keep) -- used to offset save times so not all at once
	return Promise.new(function(resolve)
		if keep._store then -- 100% of the time
			if keep._released then -- already was saved
				releaseKeepInternally(keep)
				resolve()
			end

			keep._store:UpdateAsync(keep._key, function(newestData)
				return keep:_Save(newestData)
			end)
		end

		print(`Saved Keep: {keep:Identify()}`)
		print(keep)

		resolve()
	end)
end

--> UnReleasedHandler Methods

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

		_store = nil,
		_mock_store = MockStore.new(),

		_mock = Promise.new(function(resolve, reject)
			if Store.mockStore then
				reject()
			end

			local store = DataStoreService:GetDataStore(info.Name, info.Scope) -- this always returns even with datastores down, so only way of tracking is via failed requests

			self._store = Promise.resolve(store)

			if Store.mockStore then
				reject()
			end

			resolve()
		end)
			:andThen(function()
				return true
			end)
			:catch(function()
				-- maybe now create a mock store? for now it will always be there
				return false
			end),

		_keeps = {},
	}, Store)

	local identifier = info.Name .. (info.Scope and info.Scope or "")

	Store._storeQueue[identifier] = self._store

	return Promise.resolve(self)
end

function Store:LoadKeep(key: string, unReleasedHandler: UnReleasedHandler): Promise
	local store = not self._mock and self._store or self._mock_store

	if unReleasedHandler == nil then
		unReleasedHandler = function(_)
			return "Ignore"
		end
	end

	if type(unReleasedHandler) ~= "function" then
		error("UnReleasedHandler must be a function")
	end

	return Promise.new(function(resolve, reject)
		local keep: Keep.KeepStruct = store:GetAsync(key)
			or { -- support versions
				Data = DeepCopy(self._data_template),
			}

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

		local keepClass = Keep.new(keep) -- why does typing break here? no idea.

		keepClass._store = store
		keepClass._key = key
		keepClass._store_info.Name = self._store_info.Name
		keepClass._store_info.Scope = self._store_info.Scope or ""

		self._storeQueue[key] = keepClass

		Keeps[keepClass:Identify()] = keepClass

		resolve(keepClass)
	end)
end

game:BindToClose(function()
	Store.ServiceDone = true
	Keep.ServiceDone = true

	-- loop through and release (release saves too)
end)

RunService.Heartbeat:Connect(function(dt)
	saveCycle += dt

	if saveCycle < Store._saveInterval then
		return
	end

	saveCycle = 0

	local saveSize = len(Keeps)

	if saveSize > 0 then
		local saveSpeed = Store._saveInterval / saveSize

		local clock = os.clock() -- offset the saves so not all at once

		local keeps = {}

		for _, keep in Keeps do
			if clock - keep._load_time < Store._saveInterval then
				continue
			end

			table.insert(keeps, keep)
		end

		Promise.each(keeps, function(keep, _)
			return Promise.delay(saveSpeed):andThen(function()
				saveKeep(keep)
			end)
		end)
	end
end)

--[[ Saves
	keep:Save()

	if stealing or released then release from queue

]]

return Store
