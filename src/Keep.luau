--!strict

--> Includes

local Promise = require(script.Parent.Parent.Promise)
local Signal = require(script.Parent.Parent.Signal)

local Config = require(script.Parent.Config)
local DeepCopy = require(script.Parent.Utils.DeepCopy)
local DefaultData = require(script.Parent.DefaultData)
local ProcessError = require(script.Parent.Utils.ProcessError)
local PromiseTypes = require(script.Parent.PromiseTypes)
local States = require(script.Parent.States)
local Types = require(script.Parent.Types)
local UpdateKeepAsync = require(script.Parent.Utils.UpdateKeepAsync)

--> Structure

local Keep = {}
Keep.__index = Keep

--> Types

--[=[
	@class Keep
	@server

	Keep class holds the data for a specific key in a store, and methods to manipulate data
]=]

local saveCache = {} -- used to cache in progress save promises
local releaseCache = {} -- used to cache in progress release promises
local overwriteCache = {} -- used to cache in progress overwrite promises

--> Constructor

--[=[
	@prop GlobalStateProcessor (updateData: GlobalUpdateData, lock: () -> (), remove: () -> ()) -> ()
	@within Keep

	Define how to process global updates, by default just locks the global update (this is only ran if the Keep is online)

	The function reveals the lock and remove global update function through the parameters.

	:::caution
	Updates **must** be locked eventually in order for [.OnGlobalUpdate](#OnGlobalUpdate) to get fired.
	:::caution

	:::warning
	The lock and remove function revealed here are **NOT** the same as the ones in the Keep class, they are only for this function.
	:::warning
]=]

--[=[
	@prop OnGlobalUpdate Signal<GlobalUpdateData, number>
	@within Keep

	Fired when a new global update is locked and ready to be processed, which can happen only during save

	:::caution
	**ONLY** locked globals are fired.
	:::caution
]=]

--[=[
	@prop Releasing Signal<Promise>
	@within Keep

	Fired when the Keep is releasing (fires before internally released, but during session release)

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

	Fired when the Keep is saving, resolves on complete

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

	Fired when the Keep has been overwritten. Keep will be released if ```isReleasingSession``` is set to ```true```

	```lua
	keep.Overwritten:Connect(function(isReleasingSession)
		print(`{keep:Identify()} has been overwritten. Is releasing session: {isReleasingSession}`)
	end)
	```
]=]

function Keep.new<T>(structure: Types.keepStruct<T>, dataTemplate: Types.dataTemplate<T>): Types.keep<T>
	local self = {
		Data = structure.Data,
		MetaData = structure.MetaData,
		GlobalUpdates = structure.GlobalUpdates,
		UserIds = structure.UserIds or DeepCopy(DefaultData.UserIds),

		_pending_global_lock_removes = {},
		_pending_global_locks = {},

		_requestForceLoad = false,
		_stealSession = false,

		_destroyed = false,

		Releasing = Signal.new(),
		_releasing = false,
		_released = false,

		_viewOnly = false,

		Overwritten = Signal.new(),

		OnGlobalUpdate = Signal.new(), -- fires on a new locked global update (ready to be processed)
		GlobalStateProcessor = function(_globalUpdate: Types.globalUpdate, lock: () -> (), _remove: () -> ()) -- by default just locks the global update (this is only ran if the keep is online)
			lock()
		end,

		_keyInfo = {},

		_lastSave = os.clock(),
		Saving = Signal.new(),

		_storeInfo = { Name = "", Scope = "" },
		_keep_store = nil :: any, -- the store class that created the keep
		_store = nil :: any,
		_key = "", -- the scope of the keep, used for the store class to know where to save it

		_dataTemplate = dataTemplate,
	}

	return setmetatable(self, Keep) :: any
end

--> Private Functions

function Keep._isThisSession(session: Types.session)
	return session.PlaceId == game.PlaceId and session.JobId == game.JobId
end

local function processGlobalUpdates<T>(keep: Types.keep<T>, latestData: Types.keepStruct<T>)
	-- this handles full profiles and if there are only global updates (globals posted with never loaded)

	local finalGlobals = latestData.GlobalUpdates -- the final global updates to save
	local globalUpdates = finalGlobals.Updates -- do we deep copy here..?

	local function lockGlobalUpdate(index: number) -- we take index instead, why take updateId just to loop through? we aren't doing any removing, all removals are on locked globals and will be passed to _pending_global_lock_removes
		return Promise.new(function(resolve, reject)
			if not keep:IsActive() then
				return reject()
			end

			if table.find(keep._pending_global_locks, index) then
				return resolve()
			end

			table.insert(keep._pending_global_locks, index) -- locked queue
			return resolve()
		end)
	end

	local function removeLockedUpdate(index: number, updateId: number)
		return Promise.new(function(resolve, reject)
			if not keep:IsActive() then
				return reject()
			end

			if globalUpdates[index].ID ~= updateId then -- shouldn't happen, but
				return reject()
			end

			if not globalUpdates[index].Locked and not keep._pending_global_locks[index] then
				ProcessError("Attempted to remove a global update that was not locked", 2)
				return reject()
			end

			if table.find(keep._pending_global_lock_removes, updateId) then
				return resolve()
			end

			table.insert(keep._pending_global_lock_removes, updateId) -- locked removal queue
			return resolve()
		end)
	end

	local processUpdates = {}

	for i = 1, #globalUpdates do
		if globalUpdates[i].Locked then
			continue
		end

		keep.GlobalStateProcessor(globalUpdates[i].Data, function()
			table.insert(processUpdates, function()
				lockGlobalUpdate(i)
			end)
		end, function()
			table.insert(processUpdates, function()
				removeLockedUpdate(i, globalUpdates[i].ID)
			end)
		end)
	end

	for _, updateProcessor in processUpdates do
		updateProcessor()
	end

	local recentlyLockedGlobalUpdates = {} -- list of locked GlobalUpdates for .OnGlobalUpdate

	for _, update in finalGlobals.Updates do
		if update.Locked then
			continue
		end

		for _, pendingLock in keep._pending_global_locks do
			if not (pendingLock == update.ID) then
				continue
			end

			update.Locked = true

			table.insert(recentlyLockedGlobalUpdates, DeepCopy(update))
			break
		end
	end

	for _, updateId in keep._pending_global_lock_removes do
		for i = 1, #finalGlobals.Updates do
			if finalGlobals.Updates[i].ID == updateId and finalGlobals.Updates[i].Locked then
				table.remove(finalGlobals.Updates, i)
				break
			end
		end
	end

	local pending_global_locks_left = {}

	for _, updateId in keep._pending_global_locks do
		if table.find(keep._pending_global_lock_removes, updateId) then
			continue
		end

		table.insert(pending_global_locks_left, updateId)
	end

	keep._pending_global_locks = pending_global_locks_left
	table.clear(keep._pending_global_lock_removes)

	latestData.GlobalUpdates = finalGlobals
	keep.GlobalUpdates = latestData.GlobalUpdates

	for _, recentUpdate in recentlyLockedGlobalUpdates do
		-- fire the global update event
		keep.OnGlobalUpdate:Fire(recentUpdate.Data, recentUpdate.ID)
	end
end

local function release<T>(self: Types.keep<T>, updater: PromiseTypes.Promise): PromiseTypes.Promise
	if releaseCache[self:Identify()] then -- already releasing
		return releaseCache[self:Identify()]
	end

	if self._released then
		return Promise.resolve(self)
	end

	States.activeSaveJobs += 1

	self._releasing = true
	self.Releasing:Fire(updater) -- unlocked, but not removed internally

	updater
		:catch(function(err)
			ProcessError(`Failed to release keep: {err}`, 2)
		end)
		:finally(function()
			-- mark the keep as released

			States.cachedKeepPromises[self:Identify()] = nil
			self._released = true

			releaseCache[self:Identify()] = nil

			States.activeSaveJobs -= 1
		end)

	if updater:getStatus() == Promise.Status.Started then
		releaseCache[self:Identify()] = updater
	end

	return updater
end

local function save<T>(keep: Types.keep<T>, isReleasing: boolean): PromiseTypes.Promise
	local keepStore = keep._keep_store

	if keep._viewOnly then
		ProcessError(`Attempted to save {keep:Identify()} which is a view-only keep, do you mean :Overwrite()?`, 2)
		return Promise.resolve()
	end

	local isOverwritten = false
	local isReleasingOnOverwrite = false

	return Promise.try(function()
		return UpdateKeepAsync(keep._key, keep._store, {
			edit = function(latestData)
				isOverwritten = latestData.MetaData.IsOverwriting == true
				isReleasingOnOverwrite = latestData.MetaData.ReleaseSessionOnOverwrite == true

				local isForceLoadRequested = false

				keep.MetaData.ActiveSession = latestData.MetaData.ActiveSession

				if not keep:IsActive() then
					-- session locked on a different server, data will not be saved
					ProcessError(`{keep:Identify()}'s session is no longer owned by this server and it will be marked for release.`, 0)

					release(keep, Promise.resolve(keep))
					return true -- cancel :UpdateAsync() operation
				end

				if latestData.MetaData.ForceLoad and not Keep._isThisSession(latestData.MetaData.ForceLoad) then
					-- release session on this server on remote ForceLoad request

					if keep:IsActive() then
						isForceLoadRequested = true
					else
						-- ForceLoad interrupted by another server
						release(keep, Promise.resolve(keep))
						return true -- cancel :UpdateAsync() operation
					end
				end

				isReleasing = isReleasing or isForceLoadRequested

				-- process global updates only if this server has the session lock and is not releasing
				if keep:IsActive() and not isReleasing then
					if typeof(latestData.GlobalUpdates) == "table" then
						processGlobalUpdates(keep, latestData)
					end
				end

				if keep:IsActive() then
					local isOverwriting = latestData.MetaData.IsOverwriting
					local shouldReleaseSessionOnOverwrite = latestData.MetaData.ReleaseSessionOnOverwrite

					if not isOverwriting then
						local valid, err = keepStore.validate(keep.Data) -- validate data before saving

						if valid then
							latestData.Data = keep.Data

							if keepStore._preSave then
								local processedData = keepStore._preSave(DeepCopy(keep.Data))

								if not processedData then
									ProcessError(":PreSave() must return a table", 2)
									return true -- cancel :UpdateAsync() operation
								end

								latestData.Data = processedData
							end

							latestData.UserIds = keep.UserIds
						else
							ProcessError(err :: string, 0)
							return true
						end
					end

					if isReleasing or (isOverwriting and shouldReleaseSessionOnOverwrite) then
						latestData.MetaData.ActiveSession = nil -- clear active session on this server

						if isOverwriting then
							latestData.MetaData.IsOverwriting = nil
							latestData.MetaData.ReleaseSessionOnOverwrite = nil
						end

						if latestData.MetaData.ForceLoad or isOverwriting then
							-- mark server as ready for cleanup
							release(keep, Promise.resolve(keep))
						end
					elseif isOverwriting and not shouldReleaseSessionOnOverwrite then
						-- keep active session on this server
						latestData.MetaData.IsOverwriting = nil
						latestData.MetaData.ReleaseSessionOnOverwrite = nil

						keep.Data = latestData.Data
						keep.MetaData = latestData.MetaData
						keep.GlobalUpdates = latestData.GlobalUpdates
						keep.UserIds = latestData.UserIds
					end

					latestData.MetaData.LastUpdate = os.time()
				end

				return false
			end,
		})
	end):andThen(function(_latestData, dataStoreKeyInfo: DataStoreKeyInfo)
		keep._lastSave = os.clock() -- reset the auto save timer

		if dataStoreKeyInfo then
			keep._keyInfo = dataStoreKeyInfo
		end

		if isOverwritten then
			keep.Overwritten:Fire(isReleasingOnOverwrite)
		end
	end)
end

--> Public Methods

--[=[
	@method Save
	@within Keep

	@return Promise

	Manually Saves a Keep. Commonly useful for speeding up global updates

	:::caution
	Calling ```:Save()``` manually will reset the auto save timer on the Keep.
	:::caution

	:::warning
	Using ```:Save()``` on a **view-only Keep** will error. Use [:Overwrite()](#Overwrite) instead.
	:::warning
]=]

function Keep.Save<T>(self: Types.keep<T>): PromiseTypes.Promise
	if saveCache[self:Identify()] then -- already saving
		return saveCache[self:Identify()]
	end

	if self._releasing or self._released then
		return Promise.resolve()
	end

	States.activeSaveJobs += 1

	local savingState = save(self, false):catch(function(err)
		ProcessError(err, 1)
	end):finally(function()
		saveCache[self:Identify()] = nil

		States.activeSaveJobs -= 1
	end)

	self.Saving:Fire(savingState)

	if savingState:getStatus() == Promise.Status.Started then
		saveCache[self:Identify()] = savingState
	end

	return savingState
end

--[=[
	@method Release
	@within Keep

	@return Promise

	Releases the session lock to allow other servers to access the Keep

	:::warning
	This is called before internal release, but after session release, no edits can be made after this point.
	:::warning
]=]

function Keep.Release<T>(self: Types.keep<T>): PromiseTypes.Promise
	if releaseCache[self:Identify()] then -- already releasing
		return releaseCache[self:Identify()]
	end

	if self._released then
		return Promise.resolve()
	end

	States.activeSaveJobs += 1

	local updater = Promise.retry(function()
		return save(self, true)
	end, Config.releaseRetryMaxAttempts)
		:catch(function(err)
			ProcessError(err, 1)
		end)
		:finally(function()
			States.activeSaveJobs -= 1
		end)

	self.Saving:Fire(updater)

	return release(self, updater)
end

--[=[
	@method Overwrite
	@within Keep

	@param shouldKeepExistingSession boolean?

	@return Promise

	Used to overwrite a view-only Keep.

	```shouldKeepExistingSession``` controls the behavior of the server with the active session lock, defaults to ```false```
]=]

function Keep.Overwrite<T>(self: Types.keep<T>, shouldKeepExistingSession: boolean?): PromiseTypes.Promise
	if overwriteCache[self:Identify()] then -- already overwriting
		return overwriteCache[self:Identify()]
	end

	shouldKeepExistingSession = if typeof(shouldKeepExistingSession) == "boolean" then shouldKeepExistingSession else false

	local shouldReleaseSession = shouldKeepExistingSession == false

	local keepStore = self._keep_store

	States.activeSaveJobs += 1

	local overwritingState = Promise.try(function()
		return UpdateKeepAsync(self._key, self._store, {
			edit = function(latestData)
				if typeof(latestData.Data) == "table" and typeof(latestData.MetaData) == "table" then -- full profile
					local valid, err = keepStore.validate(self.Data) -- validate data before saving

					if valid then
						latestData.Data = self.Data

						if keepStore._preSave then
							local processedData = keepStore._preSave(DeepCopy(self.Data))

							if not processedData then
								ProcessError(":PreSave() must return a table", 2)
								return true -- cancel :UpdateAsync() operation
							end

							latestData.Data = processedData
						end

						latestData.UserIds = self.UserIds
					else
						ProcessError(err :: string, 0)
						return true
					end
				end

				if latestData.MetaData.ActiveSession then
					latestData.MetaData.IsOverwriting = true -- tell the other server to release session
					latestData.MetaData.ReleaseSessionOnOverwrite = shouldReleaseSession
				end

				latestData.MetaData.LoadCount += 1

				self.MetaData.LoadCount = latestData.MetaData.LoadCount

				return false
			end,
		})
	end)
		:andThen(function(_latestData, dataStoreKeyInfo: DataStoreKeyInfo)
			self._lastSave = os.clock() -- reset the auto save timer

			if dataStoreKeyInfo then
				self._keyInfo = dataStoreKeyInfo
			end
		end)
		:catch(function(err)
			ProcessError(err, 1)
		end)
		:finally(function()
			overwriteCache[self:Identify()] = nil

			States.activeSaveJobs -= 1
		end)

	if overwritingState:getStatus() == Promise.Status.Started then
		overwriteCache[self:Identify()] = overwritingState
	end

	return overwritingState
end

--[=[
	@method Destroy
	@within Keep

	Destroys the Keep, removing all signals connections. Should be used only for cleaning view-only Keeps
]=]

function Keep.Destroy<T>(self: Types.keep<T>): ()
	if self._destroyed then
		return
	end

	self._destroyed = true

	self.Releasing:Destroy()
	self.Saving:Destroy()
	self.Overwritten:Destroy()
	self.OnGlobalUpdate:Destroy()
end

--[=[
	@method IsActive
	@within Keep

	@return boolean

	Returns ```true``` if the Keep is active in the session (not locked by another server)
]=]

function Keep.IsActive<T>(self: Types.keep<T>): boolean
	local activeSession = self.MetaData.ActiveSession

	if not activeSession then
		return false
	end

	return Keep._isThisSession(activeSession)
end

--[=[
	@method Identify
	@within Keep

	@return string

	Returns the string identifier for the Keep
]=]

function Keep.Identify<T>(self: Types.keep<T>): string
	return `{self._storeInfo.Name}/{self._storeInfo.Scope or ""}{if self._storeInfo.Scope ~= "" then "/" else ""}{self._key}`
end

--[=[
	@method GetKeyInfo
	@within Keep

	@return DataStoreKeyInfo

	Returns the ```DataStoreKeyInfo``` for the Keep
]=]

function Keep.GetKeyInfo<T>(self: Types.keep<T>): DataStoreKeyInfo
	return self._keyInfo
end

--[=[
	@method Reconcile
	@within Keep

	Fills in any missing data in the Keep, using the data template
]=]

function Keep.Reconcile<T>(self: Types.keep<T>): ()
	local function reconcileData(data: any, template: any)
		if typeof(data) ~= "table" then
			return template
		end

		for key, value in template do
			if data[key] == nil then
				data[key] = value
			elseif typeof(data[key]) == "table" then
				data[key] = reconcileData(data[key], value)
			end
		end

		return data
	end

	self.Data = reconcileData(self.Data, DeepCopy(self._dataTemplate))
	self.MetaData = reconcileData(self.MetaData, DeepCopy(DefaultData.MetaData))
end

--[=[
	@method AddUserId
	@within Keep

	@param userId number

	Associates a ```userId``` to a datastore to assist with GDPR requests (The right to erasure)
]=]

function Keep.AddUserId<T>(self: Types.keep<T>, userId: number): ()
	if table.find(self.UserIds, userId) then
		return
	end

	table.insert(self.UserIds, userId)
end

--[=[
	@method RemoveUserId
	@within Keep

	@param userId number

	Unassociates a ```userId``` from a datastore
]=]

function Keep.RemoveUserId<T>(self: Types.keep<T>, userId: number): ()
	local index = table.find(self.UserIds, userId)

	if not index then
		return
	end

	table.remove(self.UserIds, index)
end

--> Version API

--[[
	Design for public version API
	While ProfileService provides a very nice query API that automatically changes the version and saves on :OverwriteAsync()
	I think it is better to have a more manual approach, as it is more flexible and allows for more control over the versioning + migration process exists to handle any data changes
]]

--[=[
	@interface Iterator
	@within Keep

	.Current () -> DataStoreObjectVersionInfo? -- Returns the current versionInfo, nil if none
	.Next () -> DataStoreObjectVersionInfo? -- Returns the next versionInfo, nil if none
	.Previous () -> DataStoreObjectVersionInfo? -- Returns the previous versionInfo, nil if none
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
		local versionInfo = iterator.Current()

		while versionInfo do
			local keep = keepStore:ViewKeep(player.UserId, versionInfo.Version):expect()

			if keep.Data.Gems >= 200 then
				print("Found the version with 200 gems!")
				break
			end

			versionInfo = iterator.Next()
		end
	end)
	```
]=]

function Keep.GetVersions<T>(self: Types.keep<T>, minDate: number?, maxDate: number?): PromiseTypes.Promise
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
				return (versionMap[iteratorPage] and versionMap[iteratorPage][iteratorIndex]) or nil
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

	DataKeep provides a version list iterator. See [:GetVersions()](#GetVersions)

	Returns a Promise that resolves to the old Keep (before the migration) This is the **last** time the old Keep's GlobalUpdates will be accessible before **permanently** being removed

	:::warning
	Will not save until the next loop unless otherwise called using [:Save()](#Save) or [:Overwrite()](#Overwrite) for view-only Keeps.
	:::warning

	:::caution
	Any global updates not taken care of in ```migrateProcessor``` will be lost.
	:::caution
]=]

function Keep.SetVersion<T>(self: Types.keep<T>, version: string, migrateProcessor: ((versionKeep: Types.keep<T>) -> Types.keep<T>)?): PromiseTypes.TypedPromise<Types.keep<T>>
	if migrateProcessor == nil then
		migrateProcessor = function(versionKeep)
			return versionKeep
		end
	end

	if typeof(migrateProcessor) ~= "function" then
		error("[DataKeep] migrateProcessor must be a function")
	end

	return Promise.new(function(resolve, reject)
		if not self:IsActive() then
			reject()
			return
		end

		local oldKeep = {
			Data = DeepCopy(self.Data),
			MetaData = DeepCopy(self.MetaData),
			GlobalUpdates = DeepCopy(self.GlobalUpdates),
			UserIds = DeepCopy(self.UserIds),
		}

		local versionKeep = self._keep_store
			:ViewKeep(self._key, version)
			:catch(function(err)
				ProcessError(err, 1)
			end)
			:expect()

		versionKeep = migrateProcessor(versionKeep) -- Global updates are still able to be edited here, after this they are gone if not processed.

		self.Data = versionKeep.Data
		self.MetaData = versionKeep.MetaData
		self.GlobalUpdates = versionKeep.GlobalUpdates
		self.UserIds = versionKeep.UserIds

		versionKeep:Destroy()

		resolve(oldKeep)
	end)
end

--> Global Updates

--[=[
	@method GetActiveGlobalUpdates
	@within Keep

	@return { GlobalUpdate }

	Returns an array of active global updates (not locked/processed)
]=]

function Keep.GetActiveGlobalUpdates<T>(self: Types.keep<T>): { Types.globalUpdate }
	local activeUpdates = {}

	for _, update in self.GlobalUpdates.Updates do
		if update.Locked then
			continue
		end

		table.insert(activeUpdates, DeepCopy(update))
	end

	return activeUpdates
end

--[=[
	@method GetLockedGlobalUpdates
	@within Keep

	@return { GlobalUpdate }

	Returns an array of locked global updates (processed)

	:::caution
	Lock updates can **not** be changed, only cleared after done being used.
	:::caution
]=]

function Keep.GetLockedGlobalUpdates<T>(self: Types.keep<T>): { Types.globalUpdate }
	local lockedUpdates = {}

	for _, update in self.GlobalUpdates.Updates do
		if not update.Locked then
			continue
		end

		table.insert(lockedUpdates, DeepCopy(update))
	end

	return lockedUpdates
end

--[=[
	@method ClearLockedUpdate
	@within Keep

	@param id number

	@return Promise

	Clears a locked global update after being used

	:::warning
	Passing an **active** global update id will throw an error & reject the Promise.
	:::warning
]=]

function Keep.ClearLockedUpdate<T>(self: Types.keep<T>, id: number): PromiseTypes.Promise
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

		error("[DataKeep] Unable to clear locked update on an active update")
	end)
end

return Keep
