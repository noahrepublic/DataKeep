--!strict

--> Structure

--[=[
		@class Keep
		@server

		Keep class holds the data for a specific key in a store, and methods to manipulate data
	]=]

local Keep = {
	assumeDeadLock = 0,

	ServiceDone = false, -- set to true when server shutdown
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
		@type ActiveSession {PlaceID: number, JobID: number}
		@within Keep
	]=]

--[=[
		@type MetaData {ActiveSession: ActiveSession | nil, ForceLoad: ActiveSession | nil, LastUpdate: number, Created: number, LoadCount: number}
		@within Keep
	]=]

type MetaData = {
	ActiveSession: ActiveSession | nil,

	ForceLoad: ActiveSession | nil, -- the session stealing the session lock, if any

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

export type ActiveSession = {
	PlaceID: number,
	JobID: number,
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
			{
				updateId,
				data,
			}
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

--> Constructor

--[=[
		@prop GlobalStateProcessor (updateData: GlobalUpdate, lock: () -> boolean, remove: () -> boolean) -> void
		@within Keep

		Define how to process global updates, by default just locks the global update (this is only ran if the keep is online)

		The function reveals the lock and remove global update function through the parameters.



		:::caution
		Updates *must* be locked eventually in order for OnGlobalUpdate to get fired
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
		@prop OnRelease Signal<()>
		@within Keep

		Fired when the keep is released (fires before internally released, but after session release)
	]=]

function Keep.new(structure: KeepStruct, dataTemplate: {}): Keep
	return setmetatable({
		Data = structure.Data or DeepCopy(dataTemplate),
		MetaData = structure.MetaData or DefaultKeep.MetaData, -- auto locks the session too if new keep

		GlobalUpdates = structure.GlobalUpdates or DefaultKeep.GlobalUpdates,

		_pending_global_lock_removes = {},
		_pending_global_locks = {},

		UserIds = structure.UserIds or DefaultKeep.UserIds,

		LatestKeep = {
			Data = DeepCopy(structure.Data or dataTemplate),
			GlobalUpdates = DeepCopy(structure.GlobalUpdates or DefaultKeep.GlobalUpdates),

			MetaData = DeepCopy(structure.MetaData or DefaultKeep.MetaData),

			UserIds = DeepCopy(structure.UserIds or DefaultKeep.UserIds),
		},

		OnRelease = Signal.new(),
		_released = false,

		_view_only = false,
		_global_updates_only = false, -- if true, can access global updates but nothing else (used for global updates)

		OnGlobalUpdate = Signal.new(), -- fires on a new locked global update (ready to be progressed)
		GlobalStateProcessor = function(_: GlobalUpdate, lock: () -> boolean, _: () -> boolean) -- by default just locks the global update (this is only ran if the keep is online)
			lock()
		end,

		_keyInfo = {},

		_store = nil,
		_key = "", -- the scope of the keep, used for the store class to know where to save it

		_keep_store = nil, -- the store class that created the keep

		_last_save = os.clock(),
		_store_info = { Name = "", Scope = "" },

		_data_template = dataTemplate,
	}, Keep)
end

--[=[
		@type Keep { Data: {}, MetaData: MetaData, GlobalUpdates: GlobalUpdates, UserIds: {}, OnGlobalUpdate: Signal<GlobalUpdate & number>, GlobalStateProcessor: (update: GlobalUpdate, lock: () -> boolean, remove: () -> boolean) -> void, OnRelease: Signal}
		@within Keep
	]=]

export type Keep = typeof(Keep.new({
	Data = DefaultKeep.Data,

	MetaData = DefaultMetaData,
	GlobalUpdates = DefaultGlobalUpdates,

	UserIds = DefaultKeep.UserIds,
}, {})) -- the actual Keep class type

--> Private Functions

local function isKeepLocked(metaData: MetaData)
	if metaData.ActiveSession == nil then
		return false
	end

	if metaData.ActiveSession.PlaceID ~= game.PlaceId or metaData.ActiveSession.JobID ~= game.JobId then
		return true
	end

	return false
end

local function transformUpdate(keep: Keep, newestData: KeepStruct, release: boolean)
	local empty = newestData == nil
		or type(newestData) ~= "table"
		or type(newestData.Data) ~= "table"
			and newestData.Data == nil
			and newestData.MetaData == nil
			and newestData.GlobalUpdates == nil -- might be global updates there
		or type(newestData.MetaData) ~= "table"
	local corrupted = newestData ~= nil
		and (type(newestData) ~= "table" or type(newestData.Data) ~= "table" or type(newestData.MetaData) ~= "table")

	if type(newestData) == "table" then
		if
			type(newestData.Data) == "table" and typeof(newestData.MetaData) == "table"
			-- full profile
		then
			if not isKeepLocked(newestData.MetaData) then
				newestData.Data = keep.Data

				newestData.UserIds = keep.UserIds
			end
		end

		if type(newestData.GlobalUpdates) == "table" then -- this handles full profiles and if there is just global updates but no data (globals posted with never loaded)
			-- support globals

			local latestKeep = keep.LatestKeep -- "old" to other servers

			local currentGlobals = latestKeep.GlobalUpdates
			local newGlobals = newestData.GlobalUpdates

			local finalGlobals = {
				ID = 0,
				Updates = {},
			} -- the final global updates to save

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

	if empty then
		keep.MetaData.Created = os.time()

		newestData = {
			Data = keep.Data,
			MetaData = keep.MetaData,

			GlobalUpdates = keep.GlobalUpdates,
			UserIds = keep.UserIds,
		}
	end

	if corrupted then
		local replaceData = {
			Data = newestData.Data,
			MetaData = newestData.MetaData or DefaultKeep.MetaData, -- auto locks the session too if new keep

			GlobalUpdates = newestData.GlobalUpdates or DefaultKeep.GlobalUpdates,
			UserIds = newestData.UserIds or DefaultKeep.UserIds,
		}

		newestData = replaceData
	end

	if not isKeepLocked(newestData.MetaData) then
		newestData.MetaData.ActiveSession = if release and newestData.MetaData.ForceLoad
			then newestData.MetaData.ForceLoad
			else DefaultMetaData.ActiveSession

		local activeSession = DefaultMetaData.ActiveSession -- give the session to the new keep
		if release then
			if newestData.MetaData.ForceLoad then
				newestData.MetaData.ActiveSession = newestData.MetaData.ForceLoad
			else
				activeSession = nil
			end

			newestData.MetaData.ForceLoad = nil -- remove the force load, if any
		end

		newestData.MetaData.ActiveSession = activeSession

		newestData.MetaData.LastUpdate = os.time()

		if not empty then
			keep.LatestKeep = DeepCopy(newestData)
		end
	end

	keep._last_save = os.clock()
	newestData.MetaData.ForceLoad = keep.MetaData.ForceLoad

	return newestData, newestData.UserIds
end

function Keep:_save(newestData: KeepStruct, release: boolean) -- used to internally save, so we can better reveal have :Save()
	if not self:IsActive() then
		if self.MetaData.ForceLoad == nil then
			return newestData
		end
	end

	if self._view_only then
		error("Attempted to save a view only keep")
		return newestData
	end

	local waitingForceLoad = false

	if
		newestData
		and newestData.MetaData
		and newestData.MetaData.ForceLoad
		and (newestData.MetaData.ForceLoad.PlaceID ~= game.PlaceId or newestData.MetaData.ForceLoad.JobID ~= game.JobId)
	then
		waitingForceLoad = true
	elseif newestData and newestData.MetaData and newestData.MetaData.ForceLoad then
		newestData.MetaData.ForceLoad = nil -- shouldn't happen in theory, but just incase
	end

	release = release or waitingForceLoad

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
				error("Attempted to remove a global update that was not locked")
				return reject()
			end

			table.insert(self._pending_global_lock_removes, updateId) -- locked removal queue
			return resolve()
		end)
	end

	--local processors = {}
	local processUpdates = {} -- we want to run them in batch, so half are saved and half aren't incase of specific needs

	for i = 1, #globalUpdates do
		print(globalUpdates[i])
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

			--table.insert(processors, processor)
		end
	end

	-- Promise.all(processors):andThen(function()
	-- 	Promise.all(processUpdates):timeout(1 / 60):catch(function()
	-- 		error("GlobalUpdate processor cannot yield")
	-- 	end) -- run in bulk
	-- end)

	for _, updateProcessor in processUpdates do
		updateProcessor()
	end

	return transformUpdate(self, newestData, release)
end
--> Public Methods

--[=[
		@method Save
		@within Keep

		@return KeepStruct

		Manually Saves a keep and returns the data from UpdateAsync()

		Commonly useful for speeding up global updates

		:::caution
		RESETS AUTO SAVE TIMER ON THE KEEP
		:::caution
	]=]

function Keep:Save()
	return Promise.new(function(resolve)
		local dataKeyInfo: DataStoreKeyInfo = self._store:UpdateAsync(self._key, function(newestData)
			return self:_save(newestData, false)
		end)

		resolve(dataKeyInfo)
	end):catch(function(err)
		local keepStore = self._keep_store

		keepStore._processError(err)
	end)
end

--[=[
		@method IsActive
		@within Keep

		@return {boolean} 

		Returns if the Keep is active in the session (not locked by another server)
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
	return string.format(
		"%s/%s%s",
		self._store_info.Name,
		string.format("%s%s", self._store_info.Scope, if self._store_info.Scope ~= "" then "/" else ""),
		self._key
	)
end

--[=[
		@method GetKeyInfo
		@within Keep

		@return DataStoreKeyInfo

		Returns the DataStoreKeyInfo for the Keep
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
	if self.ServiceDone then
		return Promise.resolve(self)
	end

	if releaseCache[self:Identify()] then
		return releaseCache[self:Identify()]
	end

	if self._released then
		return
	end

	local updater = Promise.try(function()
		print("lets see")
		self._store:UpdateAsync(self._key, function(newestData: KeepStruct)
			print("updating")
			return self:_save(newestData, true)
		end)
	end):timeout(30)

	self._last_save = os.clock()

	return Promise.new(function(resolve)
		updater
			:andThen(function()
				resolve() -- else should auto reject because error
			end)
			:await()

		if not self._released then
			self.OnRelease:Fire() -- unlocked, but not removed internally
			self._released = true -- will tell the store class to remove internally
		end

		self.OnGlobalUpdate:Destroy()
	end):catch(function(err)
		local keepStore = self._keep_store

		keepStore._processError(err)

		error(err) -- dont want to silence the error
	end)
end

--[=[
		@method Reconcile
		@within Keep

		@return void

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

		Associates a userId to a datastore to assist with GDPR requests (The right to erasure)
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

		Unassociates a userId to a datastore
	]=]

function Keep:RemoveUserId(userId: number)
	local index = table.find(self.UserIds, userId)

	if index then
		table.remove(self.UserIds, index)
	end
end

--> Version API

--[[ Design for public version API
		While ProfileService provides a very nice query API that automatically changes the version and saves on :OverwriteAsync 
		I think it is better to have a more manual approach, as it is more flexible and allows for more control over the versioning + migration process exists to handle any data changes
	]]

--[=[
		@interface Iterator
		
		@within Keep

		.Current () -> version? -- Returns the current version, nil if none
		.Next () -> version? -- Returns the next version, nil if none
		.Previous () -> version? -- Returns the previous version, nil if none
		.PageUp () -> void -- Goes to the next page of versions
		.PageDown () -> void -- Goes to the previous page of versions
		.SkipEnd () -> void -- Goes to the last page of versions
		.SkipStart () -> void -- Goes to the first page of versions
	]=]

--[=[
		@method GetVersions
		@within Keep

		@param minDate? number
		@param maxDate? number

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

function Keep:GetVersions(minDate: number | nil, maxDate: number | nil): Promise
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
		@param migrateProcessor? (versionKeep: Keep) -> Keep

		@return Promise<Keep>

		Allows for a manual versioning process, where the version is set and the data is migrated to the new version using the optional migrateProcessor function

		DataKeep provides a version list iterator. See *GetVersions*

		Returns a Promise that resolves to the old keep (before the migration) This is the **last** time the old keep's GlobalUpdates will be accessible before **permanently** being removed

		:::warning
		Will not save until the next loop unless otherwise called using :Save or :Overwrite for ViewOnly Keeps
		:::warning

		:::caution
		Any global updates not taken care of in migrateProcessor will be lost
		:::caution
	]=]

function Keep:SetVersion(version: string, migrateProcessor: (versionKeep: Keep) -> Keep): Promise
	if migrateProcessor == nil then
		migrateProcessor = function(versionKeep: Keep)
			return versionKeep
		end
	end

	return Promise.new(function(resolve, reject)
		if not self:IsActive() then
			return reject()
		end

		local oldKeep = {
			Data = DeepCopy(self.Data),
			MetaData = DeepCopy(self.MetaData),
			GlobalUpdates = DeepCopy(self.GlobalUpdates),
			UserIds = DeepCopy(self.UserIds),
		} -- was going to just return self.LatestKeep but worried on the timing of the save

		local versionKeep = self._keep_store
			:ViewKeep(self._key, version)
			:catch(function(err)
				self._keep_store._processError(err)
			end)
			:awaitValue()

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

		@param id {number}

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

		error("Can't :ClearLockedUpdate on an active update")
	end)
end

return Keep
