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

local Promise = require(script.Parent.Promise)
local Signal = require(script.Parent.Signal)

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
	@type MetaData {ActiveSession: ActiveSession | nil, ForceLoad: ActiveSession | nil, LastUpdate: number}
	@within Keep
]=]

type MetaData = {
	ActiveSession: ActiveSession | nil,

	ForceLoad: ActiveSession | nil, -- the session stealing the session lock, if any

	LastUpdate: number,
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

	The function is revealed the lock and remove global update function

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

		OnGlobalUpdate = Signal.new(), -- fires on a new locked global update (ready to be progressed)
		GlobalStateProcessor = function(_: GlobalUpdate, lock: () -> boolean, _: () -> boolean) -- by default just locks the global update (this is only ran if the keep is online)
			lock()
		end,

		_store = nil,
		_key = "", -- the scope of the keep, used for the store class to know where to save it

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
	return metaData.ActiveSession
		and metaData.ActiveSession.PlaceID ~= game.PlaceId
		and metaData.ActiveSession.JobID ~= game.JobId
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
			else DefaultMetaData.ActiveSession -- give the session to the new keep

		if release then
			newestData.MetaData.ForceLoad = nil -- remove the force load, if any
		end

		newestData.MetaData.LastUpdate = os.time()

		if not empty then
			keep.LatestKeep = DeepCopy(newestData)
		end
	end

	if release and not isKeepLocked(newestData.MetaData) then -- if it is locked, we never had the lock, so we can't release it
		keep.OnRelease:Fire() -- unlocked, but not removed internally
		keep._released = true -- will tell the store class to remove internally
	end

	keep._last_save = os.clock()

	return newestData, newestData.UserIds
end

--> Public Methods

function Keep:_save(newestData: KeepStruct, release: boolean) -- used to internally save, so we can have :Save()
	if not self:IsActive() then
		return newestData
	end

	print("Saving Keep")

	if self._view_only then
		error("Attempted to save a view only keep")
		return newestData
	end

	release = release
		or if newestData
				and newestData.MetaData
				and newestData.MetaData.ForceLoad
				and newestData.MetaData.ForceLoad.PlaceID ~= game.PlaceId
				and newestData.MetaData.ForceLoad.JobID ~= game.JobId
			then true
			else false

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

	local processors = {}
	local processUpdates = {} -- we want to run them in batch, so half are saved and half aren't incase of specific needs

	for i = 1, #globalUpdates do
		if not globalUpdates[i].Locked then
			local processor = self.GlobalStateProcessor(globalUpdates[i].Data, function()
				table.insert(processUpdates, lockGlobalUpdate(i))
			end, function()
				table.insert(processUpdates, removeLockedUpdate(i, globalUpdates[i].ID))
			end)

			table.insert(processors, processor)
		end
	end

	Promise.all(processors):andThen(function()
		Promise.all(processUpdates):await() -- run in bulk
	end)

	return transformUpdate(self, newestData, release)
end

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
		local data = self._store:UpdateAsync(self._key, function(newestData)
			return self:_save(newestData, false)
		end)

		resolve(data)
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
	@method Release
	@within Keep

	@return Promise<Keep>

	:::warning
	This is called before internal release, but after session release, no edits can be made after this point
	:::warning
]=]

function Keep:Release()
	return Promise.new(function(resolve)
		if self._released then
			return resolve(self)
		end

		self._released = true

		self._store:UpdateAsync(self._key, function(newestData: KeepStruct)
			return self:Save(newestData, true)
		end)

		resolve(self) -- this is called before internal release, but after session release, no edits can be made after this point
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

	table.insert(self.UserIds, userId)
end

--[=[
	@method AddUserId
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