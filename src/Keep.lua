--!strict

--> Structure

--[=[
	@class Keep
	@server

	Keep class holds the data for a specific key in a store, and methods to manipulate data
]=]

local Keep = {
	assumeDeadLock = 0, -- it will be set from KeepStore

	ServiceDone = false, -- set to true when server shutdown

	_activeSaveJobs = 0, -- number of active saving jobs
}
Keep.__index = Keep

--> Includes

local Promise = require(script.Parent.Parent.Promise)
local Signal = require(script.Parent.Parent.Signal)

--> Types

export type KeepStruct = {
	Data: any,

	MetaData: MetaData,
	GlobalUpdates: GlobalUpdates,

	UserIds: { [number]: number },
}

--[=[
	@type Session {PlaceID: number, JobID: string}
	@within Keep
]=]

export type Session = {
	PlaceID: number,
	JobID: string,
}

--[=[
	@type MetaData {ActiveSession: Session?, ForceLoad: Session?, LastUpdate: number, Created: number, LoadCount: number}
	@within Keep
]=]

type MetaData = {
	ActiveSession: Session?,

	ForceLoad: Session?, -- the session stealing the session lock, if any

	IsOverwriting: boolean?, -- true if .ActiveSession is found during :Overwrite()
	ReleaseSessionOnOverwrite: boolean?,

	LastUpdate: number,
	Created: number,
	LoadCount: number,
}

type GlobalUpdate = {
	ID: number,
	Locked: boolean,
	Data: {},
}

--[=[
	@type GlobalUpdates {ID: number, Updates: { [number]: GlobalUpdate }}
	@within Keep
]=]

type GlobalUpdates = { -- unused right now, not sure about the type checking on this.
	[number]: number, -- most recent update index

	Updates: any,
}

export type Promise = typeof(Promise.new(function() end))

local DefaultMetaData: MetaData = {
	ActiveSession = { PlaceID = game.PlaceId, JobID = game.JobId }, -- we can change to number indexes for speed, but worse for types

	LastUpdate = 0,

	Created = 0,
	LoadCount = 0,
}

local DefaultGlobalUpdates = {
	ID = 0, -- [recentUpdateId] newest global update id to process in order

	--[[
		{ updateId, data }
	]]

	Updates = {},
}

local DefaultKeep: KeepStruct = {
	Data = {},
	-- can future add metatags or whateva
	MetaData = DefaultMetaData,
	GlobalUpdates = DefaultGlobalUpdates, -- really like how profile service supports these, so adding to this module as I use them lots.

	UserIds = {},
}

local releaseCache = {} -- used to cache promises, saves dead coroutine

local function deepCopy(tbl: { [any]: any })
	local copy = {}

	for key, value in pairs(tbl) do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end

	return copy
end

local function isType(value: any, reference: any): boolean
	if typeof(reference) == "table" then
		if typeof(value) ~= "table" then
			return false
		end

		for key, _ in pairs(reference) do
			if not isType(value[key], reference[key]) then
				return false
			end
		end

		return true
	end

	return typeof(value) == typeof(reference)
end

--> Constructor

--[=[
	@prop GlobalStateProcessor (updateData: GlobalUpdate, lock: () -> boolean, remove: () -> boolean) -> ()
	@within Keep

	Define how to process global updates, by default just locks the global update (this is only ran if the keep is online)

	The function reveals the lock and remove global update function through the parameters.

	:::caution
	Updates *must* be locked eventually in order for ```.OnGlobalUpdate``` to get fired
	:::caution

	:::warning
	The lock and remove function revealed here are **NOT** the same as the ones in the Keep class, they are only for this function.
	:::warning
]=]

--[=[
	@prop OnGlobalUpdate Signal<(updateData: {}, updateId: number)>
	@within Keep

	Fired when a new global update is locked and ready to be processed

	:::caution
	ONLY locked globals are fired
	:::caution
]=]

--[=[
	@prop Releasing Signal<Promise>
	@within Keep

	Fired when the keep is releasing (fires before internally released, but during session release)

	```lua
	keep.Releasing:Connect(function(state)
		print(`Releasing {keep:Identify()}`)

		state:andThen(function()
			print(`Released {keep:Identify()}`)
		end, function()
			print(`Failed to release {keep:Identify()}`)
		end)
	end)
	```
]=]

--[=[
	@prop Saving Signal<Promise>
	@within Keep

	Fired when the keep is saving, resolves on complete

	```lua
	keep.Saving:Connect(function(state)
		print(`Saving {keep:Identify()}`)

		state:andThen(function()
			print(`Saved {keep:Identify()}`)
		end):catch(function()
			print(`Failed to save {keep:Identify()}`)
		end)
	end)
	```
]=]

--[=[
	@prop Overwritten Signal<boolean>
	@within Keep

	Fired when the keep has been overwritten. Keep will be released if ```isReleasingSession``` is true

	```lua
	keep.Overwritten:Connect(function(isReleasingSession)
		print(`{keep:Identify()} has been overwritten. Is releasing session: {isReleasingSession}`)
	end)
	```
]=]

function Keep.new(structure: KeepStruct, dataTemplate: {}): Keep
	return setmetatable({
		Data = structure.Data or deepCopy(dataTemplate),
		MetaData = structure.MetaData or DefaultKeep.MetaData, -- auto locks the session too if new keep

		GlobalUpdates = structure.GlobalUpdates or DefaultKeep.GlobalUpdates,

		_pending_global_lock_removes = {},
		_pending_global_locks = {},

		UserIds = structure.UserIds or DefaultKeep.UserIds,

		LatestKeep = {
			Data = deepCopy(structure.Data or dataTemplate),
			GlobalUpdates = deepCopy(structure.GlobalUpdates or DefaultKeep.GlobalUpdates),

			MetaData = deepCopy(structure.MetaData or DefaultKeep.MetaData),

			UserIds = deepCopy(structure.UserIds or DefaultKeep.UserIds),
		},

		Releasing = Signal.new(),
		_released = false,

		_view_only = false,

		_overwriting = false,
		_releaseSessionOnOverwrite = nil,
		Overwritten = Signal.new(),

		_global_updates_only = false, -- if true, can access global updates but nothing else (used for global updates)

		OnGlobalUpdate = Signal.new(), -- fires on a new locked global update (ready to be processed)
		GlobalStateProcessor = function(_: GlobalUpdate, lock: () -> boolean, _: () -> boolean) -- by default just locks the global update (this is only ran if the keep is online)
			lock()
		end,

		_keyInfo = {},

		_store = nil,
		_key = "", -- the scope of the keep, used for the store class to know where to save it

		_keep_store = nil, -- the store class that created the keep

		_last_save = os.clock(),
		Saving = Signal.new(),
		_store_info = { Name = "", Scope = "" },

		_data_template = dataTemplate,
	}, Keep)
end

--[=[
	@type Keep { Data: {}, MetaData: MetaData, GlobalUpdates: GlobalUpdates, UserIds: {number}, OnGlobalUpdate: Signal<GlobalUpdate & number>, GlobalStateProcessor: (update: GlobalUpdate, lock: () -> boolean, remove: () -> boolean) -> (), Releasing: Signal<Promise>, Saving: Signal<Promise>, Overwritten: Signal<boolean> }
	@within Keep
]=]

export type Keep = typeof(Keep.new({
	Data = DefaultKeep.Data,

	MetaData = DefaultMetaData,
	GlobalUpdates = DefaultGlobalUpdates,

	UserIds = DefaultKeep.UserIds,
}, {})) -- the actual Keep class type

--> Private Functions

local function isForceLoadingKeepRemotely(metaData: MetaData) -- I know it's a weird name
	if metaData.ForceLoad == nil then
		return false
	end

	if metaData.ForceLoad.PlaceID == game.PlaceId and metaData.ForceLoad.JobID == game.JobId then
		return false
	end

	return true
end

local function isKeepLocked(metaData: MetaData)
	if metaData.ActiveSession == nil then
		return false
	end

	if metaData.ActiveSession.PlaceID ~= game.PlaceId or metaData.ActiveSession.JobID ~= game.JobId then
		return true
	end

	return false
end

local function isDataEmpty(newestData: KeepStruct)
	-- someone wants to fix this mess??

	return newestData == nil
		or type(newestData) ~= "table"
		or type(newestData.Data) ~= "table" and newestData.Data == nil and newestData.MetaData == nil and newestData.GlobalUpdates == nil -- might be global updates there
		or type(newestData.MetaData) ~= "table"
end

local function isDataCorrupted(newestData: KeepStruct)
	if newestData == nil then
		return false
	end

	if type(newestData) ~= "table" then
		return true
	end

	if type(newestData.Data) ~= "table" then
		return true
	end

	if type(newestData.MetaData) ~= "table" then
		return true
	end

	return false
end

local function transformUpdate(keep: Keep, newestData: KeepStruct, isReleasing: boolean)
	local empty = isDataEmpty(newestData)
	local corrupted = isDataCorrupted(newestData)

	if type(newestData) == "table" then
		if type(newestData.Data) == "table" and typeof(newestData.MetaData) == "table" then -- full profile
			-- save .Data only if this server owns session lock, when there is no ForceLoad and when there is no overwriting
			local isKeepAvailable = if not isKeepLocked(newestData.MetaData) and not isForceLoadingKeepRemotely(newestData.MetaData) and not newestData.MetaData.IsOverwriting then true else false

			if (isKeepAvailable or keep._overwriting) and keep._keep_store then
				local keepStore = keep._keep_store

				local valid, err = keepStore.validate(keep.Data) -- validate data before saving

				if valid then
					newestData.Data = keep.Data
					newestData.UserIds = keep.UserIds
				else
					if not keep._keep_store then
						return newestData
					end

					keep._keep_store._processError(err, 0)
				end
			end
		end

		-- save .GlobalUpdates only if this server is not being released on ForceLoad or on overwriting
		local isCanUpdateGlobalUpdates = if typeof(newestData.MetaData) == "table" then not isForceLoadingKeepRemotely(newestData.MetaData) and not newestData.MetaData.IsOverwriting else true

		if type(newestData.GlobalUpdates) == "table" and isCanUpdateGlobalUpdates then -- this handles full profiles and if there is just global updates but no data (globals posted with never loaded)
			-- support globals

			local latestKeep = keep.LatestKeep -- "old" to other servers

			local currentGlobals = latestKeep.GlobalUpdates
			local newGlobals = newestData.GlobalUpdates

			local finalGlobals = { ID = 0, Updates = {} } -- the final global updates to save

			local id = 0 -- used to fix any missing ids

			for _, newUpdate in newGlobals.Updates do
				id += 1
				finalGlobals.ID = id

				-- lets check if it was active, and now locked.

				local oldGlobal = nil

				local updates: { [number]: GlobalUpdate } = currentGlobals.Updates

				for _: number, oldUpdate: GlobalUpdate in updates do
					if oldUpdate.ID == newUpdate.ID then
						oldGlobal = oldUpdate
						break
					end
				end

				local isNewGlobal = oldGlobal == nil or newUpdate.Locked ~= oldGlobal.Locked

				if not isNewGlobal then
					oldGlobal.ID = id
					table.insert(finalGlobals.Updates, oldGlobal)
					continue
				end

				newUpdate.ID = id

				if not newUpdate.Locked then
					-- lets check if it is unlocked, but is being locked

					local isPendingLock = false

					for _, pendingLock in ipairs(keep._pending_global_locks) do
						if pendingLock == newUpdate.ID then
							isPendingLock = true

							break
						end
					end

					if isPendingLock then
						-- we are locking it, so lets add it to the final globals

						newUpdate.Locked = true
					end
				end

				-- ok it is locked, lets see if it is being removed

				local isPendingRemoval = false

				for _, pendingRemoval in ipairs(keep._pending_global_lock_removes) do
					if pendingRemoval == newUpdate.ID then
						isPendingRemoval = true
						break
					end
				end

				if isPendingRemoval then
					-- we are removing it, so lets not add it to the final globals
					continue
				end

				-- ok it is not being removed, lets add it to the final globals

				keep.OnGlobalUpdate:Fire(newUpdate.Data, newUpdate.ID) -- fire the global update event

				table.insert(finalGlobals.Updates, newUpdate)
			end

			newestData.GlobalUpdates = finalGlobals
		end
	end

	if empty then -- create new keep if empty
		keep.MetaData.Created = os.time()

		newestData = {
			Data = keep.Data,
			MetaData = keep.MetaData,

			GlobalUpdates = keep.GlobalUpdates,
			UserIds = keep.UserIds,
		}
	end

	if corrupted then -- fix keep if corrupted
		newestData = {
			Data = newestData.Data,
			MetaData = newestData.MetaData or DefaultKeep.MetaData, -- auto locks the session too if new keep

			GlobalUpdates = newestData.GlobalUpdates or DefaultKeep.GlobalUpdates,
			UserIds = newestData.UserIds or DefaultKeep.UserIds,
		}
	end

	if keep._overwriting then
		if newestData.MetaData.ActiveSession then
			newestData.MetaData.IsOverwriting = true -- tell the other server to release session
			newestData.MetaData.ReleaseSessionOnOverwrite = keep._releaseSessionOnOverwrite
		end

		keep.MetaData.LoadCount += 1
		keep.MetaData.ActiveSession = { PlaceID = 0, JobID = "" } -- set session on this server to not active just in case?

		newestData.MetaData.LoadCount = keep.MetaData.LoadCount
	elseif not isKeepLocked(newestData.MetaData) then -- keep is available for this server
		local activeSession = DefaultMetaData.ActiveSession -- give the session to the new keep
		local isOverwriting = newestData.MetaData.IsOverwriting

		if isReleasing or (isOverwriting and newestData.MetaData.ReleaseSessionOnOverwrite) then
			activeSession = if newestData.MetaData.ForceLoad and not isOverwriting then table.clone(newestData.MetaData.ForceLoad) else nil -- switch active session to the new server before releasing session on this server, if any or release session when overwriting

			newestData.MetaData.ForceLoad = nil -- remove the ForceLoad, if any

			keep.MetaData.ActiveSession = { PlaceID = 0, JobID = "" } -- set session on this server to not active just in case?

			if isOverwriting then
				newestData.MetaData.IsOverwriting = nil
				newestData.MetaData.ReleaseSessionOnOverwrite = nil
			end

			if activeSession or isOverwriting then
				keep:_release(Promise.resolve(keep)) -- release keep without saving data to prevent servers overwriting each other
			end
		elseif isOverwriting and not newestData.MetaData.ReleaseSessionOnOverwrite then
			newestData.MetaData.IsOverwriting = nil
			newestData.MetaData.ReleaseSessionOnOverwrite = nil

			keep.Data = newestData.Data
			keep.MetaData = newestData.MetaData
			keep.GlobalUpdates = newestData.GlobalUpdates
			keep.UserIds = newestData.UserIds
		else
			newestData.MetaData.LoadCount = keep.MetaData.LoadCount
		end

		newestData.MetaData.ActiveSession = activeSession
		newestData.MetaData.LastUpdate = os.time()

		if not empty then
			keep.LatestKeep = deepCopy(newestData)
		end
	else -- keep is not available for this server
		if keep.MetaData.ForceLoad then -- request different server to release session
			newestData.MetaData.ForceLoad = table.clone(keep.MetaData.ForceLoad)
			keep.MetaData.ForceLoad = nil
		end
	end

	keep._last_save = os.clock()

	return newestData, newestData.UserIds
end

function Keep:_release(updater)
	if releaseCache[self:Identify()] then -- already releasing
		return releaseCache[self:Identify()]
	end

	if self._released then
		return
	end

	Keep._activeSaveJobs += 1

	self.Releasing:Fire(updater) -- unlocked, but not removed internally

	updater
		:andThen(function()
			self.OnGlobalUpdate:Destroy()

			self._keep_store._cachedKeepPromises[self:Identify()] = nil
			self._released = true

			releaseCache[self:Identify()] = nil
		end)
		:catch(function(err)
			local keepStore = self._keep_store
			keepStore._processError("Failed to release: " .. err, 2)

			error(`[DataKeep] {err}`) -- dont want to silence the error
		end)
		:finally(function()
			Keep._activeSaveJobs -= 1
		end)

	releaseCache[self:Identify()] = updater

	return updater
end

function Keep:_save(newestData: KeepStruct, isReleasing: boolean) -- used to internally save, so we can better reveal :Save()
	if newestData and newestData.MetaData and not isKeepLocked(newestData.MetaData) then
		if newestData.MetaData.ActiveSession then -- reassign session to this server when different server releases session. Used with "ForceLoad"
			self.MetaData.ActiveSession = newestData.MetaData.ActiveSession
		end

		if newestData.MetaData.ForceLoad and not isForceLoadingKeepRemotely(newestData.MetaData) then
			newestData.MetaData.ForceLoad = nil -- just in case
		end
	end

	if not self:IsActive() and not self._overwriting then -- session released or locked on different server. It will not save data until session lock is released on different server. Used with "ForceLoad"
		if self.MetaData.ForceLoad == nil then
			return newestData
		end

		-- look for dead session and clear it, allowing "ForceLoad" to claim this session (ForceLoad started before session assumed as dead lock)
		local forceLoad = newestData and newestData.MetaData and newestData.MetaData.ForceLoad

		if forceLoad and not isForceLoadingKeepRemotely(newestData.MetaData) then
			if os.time() - newestData.MetaData.LastUpdate > Keep.assumeDeadLock then -- claim session
				newestData.MetaData.ActiveSession = DefaultMetaData.ActiveSession
				self.MetaData.ActiveSession = DefaultMetaData.ActiveSession

				newestData.MetaData.ForceLoad = nil
				-- don't need to clear self.MetaData.ForceLoad because it should be already cleared from previous save call
			end
		end
	end

	if self._view_only and not self._overwriting then
		self._keep_store._processError("Attempted to save a view only keep, do you mean :Overwrite()?", 2)
		return newestData
	end

	local remoteForceLoadRequest = false

	if newestData and newestData.MetaData then
		if isForceLoadingKeepRemotely(newestData.MetaData) then
			remoteForceLoadRequest = true
		end
	end

	isReleasing = isReleasing or remoteForceLoadRequest

	local latestGlobals = self.GlobalUpdates

	local globalClears = self._pending_global_lock_removes

	for _, updateId in ipairs(globalClears) do
		for i = 1, #latestGlobals.Updates do
			if latestGlobals.Updates[i].ID == updateId and latestGlobals.Updates[i].Locked then
				table.remove(latestGlobals.Updates, i)
				break
			end
		end
	end

	local globalUpdates = self.GlobalUpdates.Updates -- do we deep copy here..?

	local function lockGlobalUpdate(index: number) -- we take index instead, why take updateid just to loop through? we aren't doing any removing, all removals are on locked globals and will be passed to _pending_global_lock_removes
		return Promise.new(function(resolve, reject)
			if not self:IsActive() then
				return reject()
			end

			table.insert(self._pending_global_locks, globalUpdates[index].ID, index) -- locked queue

			return resolve()
		end)
	end

	local function removeLockedUpdate(index: number, updateId: number)
		return Promise.new(function(resolve, reject)
			if not self:IsActive() then
				return reject()
			end

			if globalUpdates[index].ID ~= updateId then -- shouldn't happen, but
				return reject()
			end

			if not globalUpdates[index].Locked and not self._pending_global_locks[index] then
				self._keep_store._processError("Attempted to remove a global update that was not locked", 2)
				return reject()
			end

			table.insert(self._pending_global_lock_removes, updateId) -- locked removal queue
			return resolve()
		end)
	end

	local processUpdates = {} -- we want to run them in batch, so half are saved and half aren't incase of specific needs

	if globalUpdates then
		for i = 1, #globalUpdates do
			if not globalUpdates[i].Locked then
				self.GlobalStateProcessor(globalUpdates[i].Data, function()
					table.insert(processUpdates, function()
						lockGlobalUpdate(i)
					end)
				end, function()
					table.insert(processUpdates, function()
						removeLockedUpdate(i, globalUpdates[i].ID)
					end)
				end)
			end
		end
	else
		self.GlobalUpdates = DefaultGlobalUpdates
	end

	for _, updateProcessor in processUpdates do
		updateProcessor()
	end

	local transformedData = transformUpdate(self, newestData, isReleasing)

	if self._keep_store and self._keep_store._preSave then
		local compressedData = self._keep_store._preSave(deepCopy(transformedData.Data))
		transformedData.Data = compressedData
	end

	if self._overwriting then
		self._overwriting = false -- already overwritten, so we can reset
		self._releaseSessionOnOverwrite = nil
	end

	return transformedData
end

--> Public Methods

--[=[
	@method Save
	@within Keep

	@return Promise<Keep>

	Manually Saves a keep and returns the data from ```:UpdateAsync()```

	Commonly useful for speeding up global updates

	:::caution
	RESETS AUTO SAVE TIMER ON THE KEEP
	:::caution

	:::warning
	Using ```:Save()``` on a **view only keep** will error. Use ```:Overwrite()``` instead
	:::warning
]=]

function Keep:Save()
	Keep._activeSaveJobs += 1

	local savingState = Promise.new(function(resolve)
		local isOverwritten = false
		local isReleasingSession = false

		local dataKeyInfo: DataStoreKeyInfo = self._store:UpdateAsync(self._key, function(newestData)
			isOverwritten = newestData and newestData.MetaData and newestData.MetaData.IsOverwriting == true
			isReleasingSession = newestData and newestData.MetaData and newestData.MetaData.ReleaseSessionOnOverwrite == true

			return self:_save(newestData, false)
		end)

		self._last_save = os.clock() -- reset the auto save timer

		if dataKeyInfo then
			self._keyInfo = { -- have to map the tuple to a table for type checking (even though tuples are arrays in lua)
				CreatedTime = dataKeyInfo.CreatedTime,
				UpdatedTime = dataKeyInfo.UpdatedTime,
				Version = dataKeyInfo.Version,
			}
		end

		if isOverwritten then
			self.Overwritten:Fire(isReleasingSession)
		end

		resolve(self)
	end)
		:catch(function(err)
			local keepStore = self._keep_store
			keepStore._processError(err, 1)
		end)
		:finally(function()
			Keep._activeSaveJobs -= 1
		end)

	self.Saving:Fire(savingState)

	return savingState
end

--[=[
	@method Overwrite
	@within Keep

	@param releaseExistingSession boolean?

	@return Promise<Keep>

	Used to overwrite on a view only keep.

	```releaseExistingSession``` controls the behavior of the server with the active session lock, defaults to true
]=]

function Keep:Overwrite(releaseExistingSession: boolean?)
	releaseExistingSession = if typeof(releaseExistingSession) == "boolean" then releaseExistingSession else true

	Keep._activeSaveJobs += 1

	local savingState = Promise.new(function(resolve)
		self._overwriting = true
		self._releaseSessionOnOverwrite = releaseExistingSession

		local dataKeyInfo: DataStoreKeyInfo = self._store:UpdateAsync(self._key, function(newestData)
			return self:_save(newestData, false)
		end)

		self._last_save = os.clock() -- reset the auto save timer

		self._keyInfo = { -- have to map the tuple to a table for type checking (even though tuples are arrays in lua)
			CreatedTime = dataKeyInfo.CreatedTime,
			UpdatedTime = dataKeyInfo.UpdatedTime,
			Version = dataKeyInfo.Version,
		}

		resolve(self)
	end)
		:catch(function(err)
			local keepStore = self._keep_store
			keepStore._processError(err, 1)
		end)
		:finally(function()
			Keep._activeSaveJobs -= 1
		end)

	self.Saving:Fire(savingState)

	return savingState
end

--[=[
	@method IsActive
	@within Keep

	@return boolean

	Returns ```true``` if the Keep is active in the session (not locked by another server)
]=]

function Keep:IsActive()
	return not isKeepLocked(self.MetaData)
end

--[=[
	@method Identify
	@within Keep

	@return string

	Returns the string identifier for the Keep
]=]

function Keep:Identify()
	return `{self._store_info.Name}/{self._store_info.Scope or ""}{if self._store_info.Scope ~= "" then "/" else ""}{self._key}`
end

--[=[
	@method GetKeyInfo
	@within Keep

	@return DataStoreKeyInfo

	Returns the ```DataStoreKeyInfo``` for the Keep
]=]

function Keep:GetKeyInfo(): DataStoreKeyInfo
	return self._keyInfo
end

--[=[
	@method Release
	@within Keep

	@return Promise<Keep>

	Releases the session lock to allow other servers to access the Keep

	:::warning
	This is called before internal release, but after session release, no edits can be made after this point
	:::warning
]=]

function Keep:Release()
	--[[
		if self.ServiceDone then -- I see no time where you don't want to release. If anyone thinks of one lmk.
			return Promise.resolve(self)
		end
	]]

	if releaseCache[self:Identify()] then -- already releasing
		return releaseCache[self:Identify()]
	end

	if self._released then
		return Promise.resolve(self)
	end

	local updater = Promise.new(function(resolve)
		local dataKeyInfo: DataStoreKeyInfo = self._store:UpdateAsync(self._key, function(newestData: KeepStruct)
			return self:_save(newestData, true)
		end)

		self._last_save = os.clock() -- reset the auto save timer

		if dataKeyInfo then
			self._keyInfo = { -- have to map the tuple to a table for type checking (even though tuples are arrays in lua)
				CreatedTime = dataKeyInfo.CreatedTime,
				UpdatedTime = dataKeyInfo.UpdatedTime,
				Version = dataKeyInfo.Version,
			}
		end

		resolve(self)
	end)

	self.Saving:Fire(updater)

	self._last_save = os.clock()

	return self:_release(updater)
end

--[=[
	@method Reconcile
	@within Keep

	Fills in any missing data in the Keep, using the data template
]=]

function Keep:Reconcile() -- fills in blank stuff
	local function reconcileData(data: any, template: any)
		if type(data) ~= "table" then
			return template
		end

		for key, value in pairs(template) do
			if data[key] == nil then
				data[key] = value
			elseif type(data[key]) == "table" then
				data[key] = reconcileData(data[key], value)
			end
		end

		return data
	end

	self.Data = reconcileData(self.Data, self._data_template)
	self.MetaData = reconcileData(self.MetaData, DefaultKeep.MetaData)
end

--[=[
	@method AddUserId
	@within Keep

	@param userId number

	Associates a ```userId``` to a datastore to assist with GDPR requests (The right to erasure)
]=]

function Keep:AddUserId(userId: number)
	if not self:IsActive() then
		return
	end

	if table.find(self.UserIds, userId) then
		return
	end

	table.insert(self.UserIds, userId)
end

--[=[
	@method RemoveUserId
	@within Keep

	@param userId number

	Unassociates a ```userId``` to a datastore
]=]

function Keep:RemoveUserId(userId: number)
	local index = table.find(self.UserIds, userId)

	if index then
		table.remove(self.UserIds, index)
	end
end

--> Version API

--[[
	Design for public version API
	While ProfileService provides a very nice query API that automatically changes the version and saves on :OverwriteAsync
	I think it is better to have a more manual approach, as it is more flexible and allows for more control over the versioning + migration process exists to handle any data changes
]]

--[=[
	@interface Iterator

	@within Keep

	.Current () -> version? -- Returns the current version, nil if none
	.Next () -> version? -- Returns the next version, nil if none
	.Previous () -> version? -- Returns the previous version, nil if none
	.PageUp () -> () -- Goes to the next page of versions
	.PageDown () -> () -- Goes to the previous page of versions
	.SkipEnd () -> () -- Goes to the last page of versions
	.SkipStart () -> () -- Goes to the first page of versions
]=]

--[=[
	@method GetVersions
	@within Keep

	@param minDate number?
	@param maxDate number?

	@return Promise<Iterator>

	Grabs past versions of the Keep and returns an iterator to customize how to handle the versions

	"I lost my progress! Last time I had 200 gems!"

	```lua
	keep:GetVersions():andThen(function(iterator)
		local version = iterator.Current()

		while version do
			local data = keepStore:ViewKeep(player.UserId, version.Version).Data

			if data.Gems >= 200 then
				print("Found the version with 200 gems!")
				break
			end

			version = iterator.Next()
		end
	end)
	```
]=]

function Keep:GetVersions(minDate: number?, maxDate: number?): Promise
	return Promise.new(function(resolve)
		local versions = self._store:ListVersionsAsync(self._key, Enum.SortDirection.Ascending, minDate, maxDate) -- we don't have to worry about order, the iterator will handle that

		local versionMap = {}

		table.insert(versionMap, versions:GetCurrentPage())
		while not versions.IsFinished do
			versions:AdvanceToNextPageAsync()

			table.insert(versionMap, versions:GetCurrentPage())
		end

		local iteratorIndex = 1
		local iteratorPage = 1

		local iterator = {
			Current = function()
				return versionMap[iteratorPage][iteratorIndex]
			end,

			Next = function()
				if #versionMap == 0 or #versionMap[iteratorPage] == 0 then
					return
				end

				if iteratorIndex >= #versionMap[iteratorPage] then
					iteratorPage += 1
					iteratorIndex = 0
				end

				iteratorIndex += 1

				local page = versionMap[iteratorPage]

				if page == nil then
					return nil
				end

				local version = page[iteratorIndex]

				return version
			end,

			PageUp = function()
				if #versionMap == 0 or #versionMap[iteratorPage] == 0 then
					return
				end

				if iteratorPage > #versionMap then
					iteratorPage = 0 -- wraps around
				end

				iteratorPage += 1
				iteratorIndex = 1
			end,

			PageDown = function()
				if #versionMap == 0 or #versionMap[iteratorPage] == 0 then
					return
				end

				if iteratorPage == 0 then
					iteratorPage = #versionMap -- wraps around
				end

				iteratorPage -= 1
				iteratorIndex = 1
			end,

			SkipEnd = function()
				iteratorPage = #versionMap
				iteratorIndex = #versionMap[iteratorPage]
			end,

			SkipStart = function()
				iteratorPage = 1
				iteratorIndex = 1
			end,

			Previous = function()
				if #versionMap == 0 or #versionMap[iteratorPage] == 0 then
					return
				end

				if iteratorIndex == 1 then
					iteratorPage -= 1

					if iteratorPage == 0 then
						return
					end

					iteratorIndex = #versionMap[iteratorPage] + 1
				end

				iteratorIndex -= 1

				local page = versionMap[iteratorPage]

				if page == nil then
					return
				end

				local version = page[iteratorIndex]

				return version
			end,
		}

		return resolve(iterator)
	end)
end

--[=[
	@method SetVersion
	@within Keep

	@param version string
	@param migrateProcessor ((versionKeep: Keep) -> Keep)?

	@return Promise<Keep>

	Allows for a manual versioning process, where the version is set and the data is migrated to the new version using the optional ```migrateProcessor``` function

	DataKeep provides a version list iterator. See *GetVersions*

	Returns a Promise that resolves to the old keep (before the migration) This is the **last** time the old keep's GlobalUpdates will be accessible before **permanently** being removed

	:::warning
	Will not save until the next loop unless otherwise called using ```:Save()``` or ```:Overwrite()``` for ViewOnly Keeps
	:::warning

	:::caution
	Any global updates not taken care of in ```migrateProcessor``` will be lost
	:::caution
]=]

function Keep:SetVersion(version: string, migrateProcessor: ((versionKeep: Keep) -> Keep)?): Promise
	if migrateProcessor == nil then
		migrateProcessor = function(versionKeep: Keep)
			return versionKeep
		end
	end

	if type(migrateProcessor) ~= "function" then
		error("[DataKeep] migrateProcessor must be a function")
	end

	return Promise.new(function(resolve, reject)
		if not self:IsActive() then
			return reject()
		end

		local oldKeep = {
			Data = deepCopy(self.Data),
			MetaData = deepCopy(self.MetaData),
			GlobalUpdates = deepCopy(self.GlobalUpdates),
			UserIds = deepCopy(self.UserIds),
		} -- was going to just return self.LatestKeep but worried on the timing of the save

		local versionKeep = self._keep_store
			:ViewKeep(self._key, version)
			:catch(function(err)
				self._keep_store._processError(err, 1)
			end)
			:expect()

		versionKeep = migrateProcessor(versionKeep) -- Global updates are still able to be edited here, after this they are gone if not processed.

		self.Data = versionKeep.Data
		self.MetaData = versionKeep.MetaData
		self.GlobalUpdates = versionKeep.GlobalUpdates
		self.UserIds = versionKeep.UserIds

		resolve(oldKeep)
	end)
end

--> Global Updates

--[=[
	@method GetActiveGlobalUpdates
	@within Keep

	@return {Array<{ Data: {}, ID: number }>}

	Returns an array of active global updates (not locked/processed)
]=]

function Keep:GetActiveGlobalUpdates()
	local activeUpdates = {}

	for _, update in ipairs(self.GlobalUpdates.Updates) do
		if not update.Locked then
			table.insert(activeUpdates, { Data = update.Data, ID = update.ID })
		end
	end

	return activeUpdates
end

--[=[
	@method GetLockedGlobalUpdates
	@within Keep

	@return {Array<{ Data: {}, ID: number }>}

	Returns an array of locked global updates (processed)

	:::caution
	Lock updates can **not** be changed, only cleared after done being used.
	:::caution
]=]

function Keep:GetLockedGlobalUpdates()
	local lockedUpdates = {}

	for _, update in ipairs(self.GlobalUpdates.Updates) do
		if update.Locked then
			table.insert(lockedUpdates, { Data = update.Data, ID = update.ID })
		end
	end

	return lockedUpdates
end

--[=[
	@method ClearLockedUpdate
	@within Keep

	@param id number

	@return Promise<void>

	Clears a locked global update after being used

	:::warning
	Passing an **active** global update id will throw an error & reject the Promise.
	:::warning
]=]

function Keep:ClearLockedUpdate(id: number): Promise
	return Promise.new(function(resolve, reject)
		if not self:IsActive() then
			return reject()
		end
		local globalUpdates = self.GlobalUpdates

		if id > globalUpdates.ID then
			return reject()
		end

		for i = 1, #globalUpdates.Updates do
			if globalUpdates.Updates[i].ID == id and globalUpdates.Updates[i].Locked then
				table.insert(self._pending_global_lock_removes, id) -- locked removal queue
				return resolve()
			end
		end

		if table.find(self._pending_global_locks, id) then
			table.insert(self._pending_global_lock_removes, id)
			return resolve()
		end

		error("[DataKeep] Can't clear locked update on an active update")
	end)
end

return Keep
