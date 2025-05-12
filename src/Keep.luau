--!strict

--> Includes

local Promise = require(script.Parent.Parent.Promise)
local Signal = require(script.Parent.Parent.Signal)

local Config = require(script.Parent.Config)
local DeepCopy = require(script.Parent.Utils.DeepCopy)
local DefaultData = require(script.Parent.DefaultData)
local Log = require(script.Parent.Utils.Log)
local Message = require(script.Parent.Utils.Message)
local PromiseTypes = require(script.Parent.PromiseTypes)
local States = require(script.Parent.States)
local Types = require(script.Parent.Types)
local UpdateAsync = require(script.Parent.Utils.UpdateAsync)

--> Structure

local Keep = {}
Keep.__index = Keep

--> Types

--[=[
	@class Keep
	@server

	Keep class holds the data for a specific key in a store, and methods to manipulate data.
]=]

--[=[
	@prop GlobalStateProcessor (globalUpdateData: GlobalUpdateData, lock: () -> (), remove: () -> ()) -> ()
	@within Keep

	Define how to process global updates, by default just locks the global update (this is only ran if the Keep is online).

	The function reveals the lock and remove global update function through the parameters.

	:::warning
	Updates **must** be locked eventually in order for [.OnGlobalUpdate](#OnGlobalUpdate) to get fired.
	:::

	:::danger
	The lock and remove function revealed here are **NOT** the same as the ones in the Keep class, they are only for this function.
	:::
]=]

--[=[
	@prop OnGlobalUpdate Signal<GlobalUpdateData, number>
	@within Keep

	Fired when a new global update is locked and ready to be processed, which can happen only during save.

	:::warning
	**ONLY** locked globals are fired.
	:::
]=]

--[=[
	@prop Released Signal
	@within Keep

	Fires after the Keep is released.

	```lua
	keep.Released:Connect(function()
		print(`Released {keep:Identify()}`)
	end)
	```
]=]

--[=[
	@prop ReleaseFailed Signal
	@within Keep

	Fires after the Keep release attempt fails.

	```lua
	keep.ReleaseFailed:Connect(function()
		print(`{keep:Identify()} failed to release`)
	end)
	```
]=]

--[=[
	@prop Saved Signal
	@within Keep

	Fires after the Keep is saved.

	```lua
	keep.Saved:Connect(function()
		print(`Saved {keep:Identify()}`)
	end)
	```
]=]

--[=[
	@prop SaveFailed Signal
	@within Keep

	Fires after the Keep save attempt fails.

	```lua
	keep.SaveFailed:Connect(function()
		print(`{keep:Identify()} failed to save`)
	end)
	```
]=]

--[=[
	@prop Overwritten Signal<boolean>
	@within Keep

	Fires when the Keep has been overwritten. Keep will be released if ```isReleasingSession``` is set to ```true```.

	```lua
	keep.Overwritten:Connect(function(isReleasingSession)
		print(`{keep:Identify()} has been overwritten. Is releasing session: {isReleasingSession}`)
	end)
	```
]=]

--> Private Variables

local saveCache = {} -- used to cache in progress save promises
local releaseCache = {} -- used to cache in progress release promises
local overwriteCache = {} -- used to cache in progress overwrite promises

--> Constructor

function Keep.new<T, R>(structure: Types.keepStruct<T>, dataTemplate: Types.dataTemplate<T>): Types.keep<T, R>
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

		Released = Signal.new(),
		ReleaseFailed = Signal.new(),
		_releasing = false,
		_released = false,

		_viewOnly = false,

		Overwritten = Signal.new(),

		OnGlobalUpdate = Signal.new(), -- fires on a new locked global update (ready to be processed)
		GlobalStateProcessor = function(_globalUpdateData: Types.globalUpdateData, lock: () -> (), _remove: () -> ()) -- by default just locks the global update (this is only ran if the keep is online)
			lock()
		end,

		_keyInfo = {},

		_lastSaveAttempt = os.clock(),
		Saved = Signal.new(),
		SaveFailed = Signal.new(),

		_store = nil, -- the store class that created the keep
		_datastore = nil,
		_key = "", -- the key of the keep, used for the store class to know where to save it

		_dataTemplate = dataTemplate,
	}

	return setmetatable(self, Keep) :: any
end

--> Private Functions

local function processGlobalUpdates<T, R>(keep: Types.keep<T, R>, latestData: Types.keepStruct<T>)
	-- this handles full profiles and if there are only global updates (globals posted with never loaded)

	local finalGlobals = latestData.GlobalUpdates -- the final global updates to save
	local globalUpdates = finalGlobals.Updates -- do we deep copy here..?

	local function lockGlobalUpdate(index: number) -- we take index instead, why take updateId just to loop through? we aren't doing any removing, all removals are on locked globals and will be passed to _pending_global_lock_removes
		return Promise.new(function(resolve)
			if not keep:IsActive() then
				error(Message.new(`Failed to lock global update: Keep has inactive session`))
			end

			if table.find(keep._pending_global_locks, index) then
				return resolve()
			end

			table.insert(keep._pending_global_locks, index) -- locked queue
			return resolve()
		end)
	end

	local function removeLockedUpdate(index: number, updateId: number)
		return Promise.new(function(resolve)
			if not keep:IsActive() then
				error(Message.new(`Failed to remove locked update: Keep has inactive session`))
			end

			if globalUpdates[index].Id ~= updateId then -- shouldn't happen, but
				error(Message.new(`Failed to remove locked update: Invalid update id`))
			end

			if not globalUpdates[index].Locked and not keep._pending_global_locks[index] then
				error(Message.new(`Failed to remove locked update: Global update was not locked`))
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
				removeLockedUpdate(i, globalUpdates[i].Id)
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
			if not (pendingLock == update.Id) then
				continue
			end

			update.Locked = true

			table.insert(recentlyLockedGlobalUpdates, DeepCopy(update))
			break
		end
	end

	for _, updateId in keep._pending_global_lock_removes do
		for i = 1, #finalGlobals.Updates do
			if finalGlobals.Updates[i].Id == updateId and finalGlobals.Updates[i].Locked then
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
		keep.OnGlobalUpdate:Fire(recentUpdate.Data, recentUpdate.Id)
	end
end

local function save<T, R>(keep: Types.keep<T, R>, isReleasing: boolean): PromiseTypes.TypedPromise<()>
	local isOverwritten = false
	local isReleasingOnOverwrite = false

	return Promise.try(function()
		return UpdateAsync(keep._key, keep._datastore, {
			edit = function(latestData)
				isOverwritten = latestData.MetaData.IsOverwriting == true
				isReleasingOnOverwrite = latestData.MetaData.ReleaseSessionOnOverwrite == true

				local isForceLoadRequested = false

				keep.MetaData.ActiveSession = latestData.MetaData.ActiveSession

				if not keep:IsActive() then
					-- session locked on a different server, data will not be saved
					Log.print(`{keep:Identify()}'s session is no longer owned by this server and it will be marked for release.`)

					Keep._release(keep, Promise.resolve())
					return true -- cancel :UpdateAsync() operation
				end

				if latestData.MetaData.ForceLoad and not Keep._isThisSession(latestData.MetaData.ForceLoad) then
					-- release session on this server on remote ForceLoad request

					if keep:IsActive() then
						isForceLoadRequested = true
					else
						-- ForceLoad interrupted by another server
						Keep._release(keep, Promise.resolve())
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
						local valid, validationErr = keep._store.validate(keep.Data) -- validate data before saving

						if valid then
							latestData.Data = keep.Data

							if keep._store._preSave then
								local processedData = keep._store._preSave(DeepCopy(keep.Data))

								if not processedData then
									error(Message.new(":PreSave() must return a table"))
								end

								latestData.Data = processedData
							end

							latestData.UserIds = keep.UserIds
						else
							local errString = `Data has not passed validation`

							if validationErr then
								errString ..= `. {validationErr}`
							end

							error(Message.new(errString))
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
							Keep._release(keep, Promise.resolve())
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
		}, {})
	end)
		:andThen(function(_latestData, datastoreKeyInfo)
			if datastoreKeyInfo then
				keep._keyInfo = datastoreKeyInfo
			end

			keep.Saved:Fire()

			if isOverwritten then
				keep.Overwritten:Fire(isReleasingOnOverwrite)
			end
		end)
		:catch(function(err)
			keep.SaveFailed:Fire()
			return Promise.reject(err)
		end)
end

function Keep._isThisSession(session: Types.session)
	return session.PlaceId == game.PlaceId and session.JobId == game.JobId
end

function Keep._release<T, R>(self: Types.keep<T, R>, updater: PromiseTypes.TypedPromise<any?>): PromiseTypes.TypedPromise<()>
	if releaseCache[self:Identify()] then -- already releasing
		return releaseCache[self:Identify()]
	end

	if self._released then
		return Promise.resolve(self)
	end

	States.activeDataStoreJobs += 1

	self._releasing = true

	local promise = Promise.try(function()
		local success, resultOrError = updater:await()

		if success then
			self.Released:Fire()
		else
			self.ReleaseFailed:Fire()
		end

		-- mark the keep as released
		States.cachedKeepPromises[self:Identify()] = nil
		self._released = true

		releaseCache[self:Identify()] = nil
		States.activeDataStoreJobs -= 1

		if not success then
			return Promise.reject(resultOrError)
		end
	end)

	if promise:getStatus() == Promise.Status.Started then
		releaseCache[self:Identify()] = promise
	end

	return promise
end

--> Public Methods

--[=[
	@method Save
	@within Keep

	@return Promise<()>

	Performs a manual save.

	:::warning
	Calling ```:Save()``` manually will reset the auto save timer on the Keep.
	:::

	:::danger
	Using ```:Save()``` on a **view-only Keep** will error. Use [:Overwrite()](#Overwrite) instead.
	:::
]=]

function Keep.Save<T, R>(self: Types.keep<T, R>): PromiseTypes.TypedPromise<()>
	if self._viewOnly then
		return Promise.reject(Message.new(`This is a view-only keep, do you mean :Overwrite()?`))
	end

	if saveCache[self:Identify()] then -- already saving
		return saveCache[self:Identify()]
	end

	if self._releasing or self._released then
		return Promise.resolve()
	end

	States.activeDataStoreJobs += 1
	self._lastSaveAttempt = os.clock() -- reset the auto save timer

	local savingState = save(self, false)
		:tap(function()
			Log.print(`Saved {self:Identify()}.`)
		end)
		:catch(function(err)
			return Promise.reject(Log.error(`Failed to save {self:Identify()}.`, err, true))
		end)
		:finally(function()
			self._lastSaveAttempt = os.clock() -- reset the auto save timer
			saveCache[self:Identify()] = nil
			States.activeDataStoreJobs -= 1
		end)

	if savingState:getStatus() == Promise.Status.Started then
		saveCache[self:Identify()] = savingState
	end

	return savingState
end

--[=[
	@method Release
	@within Keep

	@return Promise<()>

	Releases the session lock to allow other servers to access the Keep.

	:::info
	DataKeep will retry failed release attempts.
	:::

	:::danger
	This is called before internal release, but after session release, no edits can be made after this point.
	:::
]=]

function Keep.Release<T, R>(self: Types.keep<T, R>): PromiseTypes.TypedPromise<()>
	if self._viewOnly then
		return Promise.reject(Message.new(`This is a view-only keep`))
	end

	if releaseCache[self:Identify()] then -- already releasing
		return releaseCache[self:Identify()]
	end

	if self._released then
		return Promise.resolve()
	end

	States.activeDataStoreJobs += 1
	self._lastSaveAttempt = os.clock() -- reset the auto save timer

	local updater = Keep._release(self, Promise.retry(save, Config.releaseRetryMaxAttempts, self, true))
		:tap(function()
			Log.print(`Released {self:Identify()}.`)
		end)
		:catch(function(err)
			return Promise.reject(Log.error(`Failed to release {self:Identify()}.`, err, true))
		end)
		:finally(function()
			self._lastSaveAttempt = os.clock() -- reset the auto save timer
			States.activeDataStoreJobs -= 1
		end)

	return updater
end

--[=[
	@method Overwrite
	@within Keep

	@param shouldKeepExistingSession boolean?

	@return Promise<()>

	Used to overwrite a view-only Keep.

	```shouldKeepExistingSession``` controls the behavior of the server with the active session lock, defaults to ```false```.
]=]

function Keep.Overwrite<T, R>(self: Types.keep<T, R>, shouldKeepExistingSession: boolean?): PromiseTypes.TypedPromise<()>
	if not self._viewOnly then
		return Promise.reject(Message.new(`This is not a view-only keep, do you mean :Save()?`))
	end

	if overwriteCache[self:Identify()] then -- already overwriting
		return overwriteCache[self:Identify()]
	end

	local shouldReleaseSession = if shouldKeepExistingSession then false else true

	States.activeDataStoreJobs += 1
	self._lastSaveAttempt = os.clock() -- reset the auto save timer

	local overwritingState = Promise.try(function()
		return UpdateAsync(self._key, self._datastore, {
			onMissing = function(latestData)
				latestData.Data = DeepCopy(self._dataTemplate)
				latestData.MetaData = DeepCopy(DefaultData.MetaData)
				latestData.UserIds = DeepCopy(DefaultData.UserIds)

				latestData.MetaData.ActiveSession = nil
				latestData.MetaData.Created = os.time()

				self.MetaData.Created = latestData.MetaData.Created

				return false
			end,
			edit = function(latestData)
				if typeof(latestData.Data) == "table" and typeof(latestData.MetaData) == "table" then -- full profile
					local valid, validationErr = self._store.validate(self.Data) -- validate data before saving

					if valid then
						latestData.Data = self.Data

						if self._store._preSave then
							local processedData = self._store._preSave(DeepCopy(self.Data))

							if not processedData then
								error(Message.new(":PreSave() must return a table"))
							end

							latestData.Data = processedData
						end

						latestData.UserIds = self.UserIds
					else
						local errString = `Data has not passed validation`

						if validationErr then
							errString ..= `. {validationErr}`
						end

						error(Message.new(errString))
					end
				end

				if latestData.MetaData.ActiveSession then
					latestData.MetaData.IsOverwriting = true -- tell the other server to release session
					latestData.MetaData.ReleaseSessionOnOverwrite = shouldReleaseSession
				end

				latestData.MetaData.LoadCount += 1
				latestData.MetaData.LastUpdate = os.time()

				self.MetaData.LoadCount = latestData.MetaData.LoadCount
				self.MetaData.LastUpdate = latestData.MetaData.LastUpdate

				return false
			end,
		}, {})
	end)
		:andThen(function(latestData, datastoreKeyInfo)
			if not latestData then -- idk if this is still possible, because you can overwrite empty keep
				error(Message.new("Keep was never loaded before"))
			end

			if datastoreKeyInfo then
				self._keyInfo = datastoreKeyInfo
			end
		end)
		:tap(function()
			Log.print(`Overwritten {self:Identify()}.`)
		end)
		:catch(function(err)
			return Promise.reject(Log.error(`Failed to overwrite {self:Identify()}.`, err, true))
		end)
		:finally(function()
			self._lastSaveAttempt = os.clock() -- reset the auto save timer
			overwriteCache[self:Identify()] = nil
			States.activeDataStoreJobs -= 1
		end)

	if overwritingState:getStatus() == Promise.Status.Started then
		overwriteCache[self:Identify()] = overwritingState
	end

	return overwritingState
end

--[=[
	@method Destroy
	@within Keep

	Destroys the Keep, removing all signals connections. Should be used only for cleaning view-only Keeps.
]=]

function Keep.Destroy<T, R>(self: Types.keep<T, R>)
	if self._destroyed then
		return
	end

	self._destroyed = true

	self.Released:Destroy()
	self.ReleaseFailed:Destroy()
	self.Saved:Destroy()
	self.SaveFailed:Destroy()
	self.Overwritten:Destroy()
	self.OnGlobalUpdate:Destroy()
end

--[=[
	@method IsActive
	@within Keep

	@return boolean

	Returns ```true``` if the Keep is active in the session (not locked by another server).
]=]

function Keep.IsActive<T, R>(self: Types.keep<T, R>): boolean
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

	Returns the string identifier for the Keep.
]=]

function Keep.Identify<T, R>(self: Types.keep<T, R>): string
	return `{self._store:Identify()}/{self._key}`
end

--[=[
	@method GetKeyInfo
	@within Keep

	@return DataStoreKeyInfo

	Returns the ```DataStoreKeyInfo``` for the Keep.
]=]

function Keep.GetKeyInfo<T, R>(self: Types.keep<T, R>): DataStoreKeyInfo
	return self._keyInfo
end

--[=[
	@method Reconcile
	@within Keep

	Fills in any missing data in the Keep using the data template.
]=]

function Keep.Reconcile<T, R>(self: Types.keep<T, R>)
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

	Associates a ```userId``` to a datastore to assist with GDPR requests (The right to erasure).
]=]

function Keep.AddUserId<T, R>(self: Types.keep<T, R>, userId: number)
	if table.find(self.UserIds, userId) then
		return
	end

	table.insert(self.UserIds, userId)
end

--[=[
	@method RemoveUserId
	@within Keep

	@param userId number

	Unassociates a ```userId``` from a datastore.
]=]

function Keep.RemoveUserId<T, R>(self: Types.keep<T, R>, userId: number)
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

	.Current () -> DataStoreObjectVersionInfo? -- Returns the current versionInfo, nil if none.
	.Next () -> DataStoreObjectVersionInfo? -- Returns the next versionInfo, nil if none.
	.Previous () -> DataStoreObjectVersionInfo? -- Returns the previous versionInfo, nil if none.
	.PageUp () -> () -- Goes to the next page of versions.
	.PageDown () -> () -- Goes to the previous page of versions.
	.SkipEnd () -> () -- Goes to the last page of versions.
	.SkipStart () -> () -- Goes to the first page of versions.
]=]

--[=[
	@method GetVersions
	@within Keep

	@param minDate number?
	@param maxDate number?

	@return Promise<Iterator>

	Grabs past versions of the Keep and returns an iterator to customize how to handle the versions.

	"I lost my progress! Last time I had 200 gems!"

	```lua
	keep:GetVersions():andThen(function(iterator)
		local versionInfo = iterator.Current()

		while versionInfo do
			local oldKeep = store:ViewKeep(player.UserId, versionInfo.Version):expect()

			if oldKeep.Data.Gems >= 200 then
				print("Found the version with 200 gems!")
				break
			end

			versionInfo = iterator.Next()
		end
	end)
	```
]=]

function Keep.GetVersions<T, R>(self: Types.keep<T, R>, minDate: number?, maxDate: number?): PromiseTypes.TypedPromise<Types.iterator>
	return Promise.new(function(resolve)
		local versions = self._datastore:ListVersionsAsync(self._key, Enum.SortDirection.Ascending, minDate, maxDate) -- we don't have to worry about order, the iterator will handle that

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

	Allows for a manual versioning process, where the version is set and the data is migrated to the new version using the optional ```migrateProcessor``` function.

	DataKeep provides a version list iterator. See [:GetVersions()](#GetVersions).

	Returns a Promise that resolves to the old Keep (before the migration) This is the **last** time the old Keep's GlobalUpdates will be accessible before **permanently** being removed.

	:::danger
	Will not save until the next loop unless otherwise called using [:Save()](#Save) or [:Overwrite()](#Overwrite) for view-only Keeps.
	:::

	:::warning
	Any global updates not taken care of in ```migrateProcessor``` will be lost.
	:::
]=]

function Keep.SetVersion<T, R>(self: Types.keep<T, R>, version: string, migrateProcessor: ((versionKeep: Types.keep<T, R>) -> Types.keep<T, R>)?): PromiseTypes.TypedPromise<Types.keep<T, R>>
	if migrateProcessor ~= nil and typeof(migrateProcessor) ~= "function" then
		return Promise.reject(Message.new(`migrateProcessor must be a function`))
	end

	if migrateProcessor == nil then
		migrateProcessor = function(versionKeep)
			return versionKeep
		end
	end

	local processor = migrateProcessor :: (versionKeep: Types.keep<T, R>) -> Types.keep<T, R>

	return Promise.new(function(resolve)
		if not self:IsActive() then
			error(Message.new("Keep has inactive session"))
		end

		local oldKeep = {
			Data = DeepCopy(self.Data),
			MetaData = DeepCopy(self.MetaData),
			GlobalUpdates = DeepCopy(self.GlobalUpdates),
			UserIds = DeepCopy(self.UserIds),
		}

		local versionKeep = self._store:ViewKeep(self._key, version):expect()

		versionKeep = processor(versionKeep) -- Global updates are still able to be edited here, after this they are gone if not processed.

		if not versionKeep then
			error(Message.new("migrateProcessor must return the Keep"))
		end

		self.Data = DeepCopy(versionKeep.Data)
		self.MetaData = DeepCopy(versionKeep.MetaData)
		self.GlobalUpdates = DeepCopy(versionKeep.GlobalUpdates)
		self.UserIds = DeepCopy(versionKeep.UserIds)

		versionKeep:Destroy()

		resolve(oldKeep)
	end)
end

--> Global Updates

--[=[
	@method GetActiveGlobalUpdates
	@within Keep

	@return { GlobalUpdate }

	Returns an array of active global updates (not locked / processed).
]=]

function Keep.GetActiveGlobalUpdates<T, R>(self: Types.keep<T, R>): { Types.globalUpdate }
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

	Returns an array of locked global updates (processed).

	:::warning
	Lock updates can **not** be changed, only cleared after done being used.
	:::
]=]

function Keep.GetLockedGlobalUpdates<T, R>(self: Types.keep<T, R>): { Types.globalUpdate }
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

	@return Promise<()>

	Clears a locked global update after being used.

	:::danger
	Passing an **active** global update id will throw an error & reject the Promise.
	:::
]=]

function Keep.ClearLockedUpdate<T, R>(self: Types.keep<T, R>, id: number): PromiseTypes.TypedPromise<()>
	return Promise.new(function(resolve)
		if not self:IsActive() then
			error(Message.new("Keep has inactive session"))
		end

		local globalUpdates = self.GlobalUpdates

		if id > globalUpdates.Id then
			error(Message.new("Invalid update id"))
		end

		for i = 1, #globalUpdates.Updates do
			if globalUpdates.Updates[i].Id == id and globalUpdates.Updates[i].Locked then
				table.insert(self._pending_global_lock_removes, id) -- locked removal queue
				return resolve()
			end
		end

		if table.find(self._pending_global_locks, id) then
			table.insert(self._pending_global_lock_removes, id)
			return resolve()
		end

		error(Message.new("This global update is active"))
	end)
end

return Keep
