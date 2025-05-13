--!strict

--> Services

local DataStoreService = game:GetService("DataStoreService")

--> Includes

local Config = require(script.Parent.Config)
local DeepCopy = require(script.Parent.Utils.DeepCopy)
local DefaultData = require(script.Parent.DefaultData)
local Enums = require(script.Parent.Enums)
local GlobalUpdates = require(script.Parent.GlobalUpdates)
local Keep = require(script.Parent.Keep)
local Log = require(script.Parent.Utils.Log)
local Message = require(script.Parent.Utils.Message)
local MockStore = require(script.Parent.MockStore)
local Promise = require(script.Parent.Parent.Promise)
local PromiseTypes = require(script.Parent.PromiseTypes)
local RemoveKeepInternally = require(script.Parent.Utils.RemoveKeepInternally)
local States = require(script.Parent.States)
local Types = require(script.Parent.Types)
local UpdateAsync = require(script.Parent.Utils.UpdateAsync)

--> Structure

local Store = {}
Store.__index = Store

--> Types

--[=[
	@class Store
	@server
]=]

--[=[
	@prop Mock MockStore
	@within Store

	Same as [Store](Store) but it operates on a fake datastore.

	```lua
	local store = DataKeep.GetStore("TestStore", {}, {}):expect()

	local keep = store.Mock:LoadKeep("TestKey"):expect()
	keep:Release():await()

	-- must be used when done with the keep on live servers
	store.Mock:RemoveKeep("TestKey")
	```
]=]

--[=[
	@prop validate ({ [string]: any }) -> true | (false&string)
	@within Store

	Used to validate data before saving. Ex. type guards.

	```lua
	store.validate = function(data)
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

--> Private Functions

local function createMockStore<T, R>(storeInfo: Types.storeInfo, dataTemplate: Types.dataTemplate<T>, wrapper: R): Types.mockStore<T, R> -- complete mirror of real stores, minus mock related data as we are in a mock store
	local self = {
		_storeInfo = storeInfo,
		_dataTemplate = dataTemplate,

		_datastore = MockStore.new(),

		_isMockEnabled = true,

		_wrapper = wrapper,

		validate = function()
			return true
		end,
	}

	return setmetatable(self, Store) :: any
end

--[[
	Future idea: I doubt it is needed so it may just throttle speed.

	local function getRequestBudget(keep)
		return keep._datastore:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
	end
]]

--> Constructor

function Store.new<T, R>(storeInfo: Types.storeInfo, dataTemplate: Types.dataTemplate<T>, wrapper: R): Types.store<T, R>
	local self = {
		_storeInfo = storeInfo,
		_dataTemplate = dataTemplate,

		_datastore = if States.isUseMockStore then MockStore.new() else DataStoreService:GetDataStore(storeInfo.Name, storeInfo.Scope), -- this always returns even with datastores down, so only way of tracking is via failed requests

		Mock = createMockStore(storeInfo, dataTemplate, wrapper), -- revealed to api

		_isMockEnabled = if States.isUseMockStore then true else false, -- studio only/datastores not available

		_wrapper = wrapper,

		validate = function()
			return true
		end,
	}

	return setmetatable(self, Store) :: any
end

--> Public Methods

--[=[
	@method Identify
	@within Store

	@return string

	Returns the string identifier for the Store.
]=]

function Store.Identify<T, R>(self: Types.store<T, R>)
	if not self._storeInfo.Scope then
		return self._storeInfo.Name
	end

	return `{self._storeInfo.Name}/{self._storeInfo.Scope}`
end

--[=[
	@method LoadKeep
	@within Store

	@param key string
	@param unreleasedHandler unreleasedHandler?

	@return Promise<Keep>

	Loads a Keep from the store and returns a Keep object.

	```lua
	store:LoadKeep(`Player_{player.UserId}`, function()
		return DataKeep.Enums.LoadMethod.ForceLoad
	end)):andThen(function(keep)
		print(`Loaded {keep:Identify()}!`)
	end):catch(function()
		player:Kick("Data failed to load")
	end)
	```

	:::info
	Keeps are cached, that way you can call [:LoadKeep()](#LoadKeep) multiple times and get the same Keeps.
	:::

	:::info
	DataKeep will retry failed load attempts.
	:::
]=]

function Store.LoadKeep<T, R>(self: Types.store<T, R>, key: string, unreleasedHandler: Types.unreleasedHandler?): PromiseTypes.TypedPromise<Types.keep<T, R>>
	if unreleasedHandler ~= nil and typeof(unreleasedHandler) ~= "function" then
		return Promise.reject(Message.new("unreleasedHandler must be a function"))
	end

	if unreleasedHandler == nil then
		unreleasedHandler = function(_)
			return Enums.LoadMethod.ForceLoad
		end
	end

	local id = `{self:Identify()}/{key}`

	local promise = Promise.try(function()
		if States.loadedKeeps[id] then
			if not States.loadedKeeps[id]._releasing and not States.loadedKeeps[id]._released then
				return States.loadedKeeps[id]
			end

			-- wait for keep to be released on the same server: https://github.com/noahrepublic/DataKeep/issues/21

			local timer = Config.assumeDeadLock -- in normal conditions there is no way to hit that

			repeat
				timer -= task.wait()
			until States.loadedKeeps[id] == nil or timer < 0

			if States.loadedKeeps[id] then
				RemoveKeepInternally(States.loadedKeeps[id]) -- additional cleanup to prevent memory leaks
			end
		elseif States.cachedKeepPromises[id] then
			local promiseStatus = States.cachedKeepPromises[id]:getStatus()

			if promiseStatus ~= Promise.Status.Rejected and promiseStatus ~= Promise.Status.Cancelled then
				-- already loading keep
				return States.cachedKeepPromises[id]
			end
		end

		-- keep released so we can load new keep

		return nil :: any
	end)
		:andThen(function(cachedKeep)
			if cachedKeep then
				return cachedKeep
			end

			if States.isServiceDone then
				error(Message.new(`Server is closing, unable to load keep for {id}`))
			end

			if self._isMockEnabled then
				Log.print(`Using mock store on {id}.`)
			end

			States.activeDataStoreJobs += 1

			local shouldForceLoad = false
			local requestForceLoad = false

			local shouldStealSessionOnForceLoad = false -- used only with ForceLoad
			local shouldStealSession = false -- unreleasedHandler() == Enums.LoadMethod.Steal

			return Promise.try(function(): { loadedData: Types.keepStruct<T>, datastoreKeyInfo: DataStoreKeyInfo }?
				local forceLoadAttempts = 0
				local forceLoadWaitTime = 1

				-- time to wait between failed datastore calls (exponential backoff)
				local waitTime = 1
				local startTime = os.clock()

				while true do
					local success: boolean, loadedData: Types.keepStruct<T>?, datastoreKeyInfo: DataStoreKeyInfo? = Promise.try(function()
						return UpdateAsync(key, self._datastore, {
							onCheck = function()
								return States.isServiceDone
							end,
							onExisting = function(latest)
								local activeSession = latest.metadata.ActiveSession
								local forceLoadSession = latest.metadata.ForceLoad

								if activeSession == nil then
									latest.metadata.ActiveSession = DeepCopy(DefaultData.Metadata.ActiveSession)
									latest.metadata.ForceLoad = nil
								elseif typeof(activeSession) == "table" then
									if not Keep._isThisSession(activeSession) then
										local lastUpdate = latest.metadata.LastUpdate

										if lastUpdate ~= nil then
											if os.time() - lastUpdate > Config.assumeDeadLock then
												shouldStealSession = true
											end
										end

										if shouldStealSessionOnForceLoad or shouldStealSession then
											local forceLoadInterrupted = false

											if forceLoadSession ~= nil then
												forceLoadInterrupted = Keep._isThisSession(forceLoadSession) == false
											end

											if not forceLoadInterrupted or shouldStealSession then
												latest.metadata.ActiveSession = DeepCopy(DefaultData.Metadata.ActiveSession)
												latest.metadata.ForceLoad = nil
											end
										elseif requestForceLoad then
											latest.metadata.ForceLoad = DeepCopy(DefaultData.Metadata.ActiveSession)
										end
									else
										latest.metadata.ForceLoad = nil
									end
								end

								return false
							end,
							onMissing = function(latest)
								latest.data.Data = DeepCopy(self._dataTemplate)
								latest.metadata = DeepCopy(DefaultData.Metadata)
								latest.metadata.Created = os.time()
								latest.userIds = DeepCopy(DefaultData.UserIds)

								return false
							end,
							edit = function(latest)
								local activeSession = latest.metadata.ActiveSession

								if activeSession ~= nil and Keep._isThisSession(activeSession) then
									latest.metadata.LoadCount += 1
									latest.metadata.LastUpdate = os.time()

									if self._preLoad then
										local processedData = self._preLoad(DeepCopy(latest.data.Data))

										if not processedData then
											error(Message.new(":PreLoad() must return a table"))
										end

										latest.data.Data = processedData
									end
								end

								return false
							end,
						}, {})
					end):await()

					local currentTime = os.clock()

					if not success then
						if currentTime - startTime >= Config.loadKeepDataStoreFailTimeout then
							-- datastores were unavailable for too long
							error(Message.new("Datastores were unavailable for too long"))
						end

						-- :UpdateAsync() failed, wait and retry
						task.wait(waitTime)
						waitTime = math.min(20, waitTime * 2)
						continue
					elseif currentTime - startTime >= 60 then
						-- reset the time after one minute to prevent exceeding the datastore limits in case if some of the requests fail and some not

						waitTime = 1
						startTime = currentTime
					end

					if not loadedData or not datastoreKeyInfo then
						-- :UpdateAsync() was canceled
						error(Message.new(":UpdateAsync() was canceled"))
					end

					local metadata = datastoreKeyInfo:GetMetadata()
					local activeSession = metadata.ActiveSession

					if not (typeof(activeSession) == "table") then
						-- probably because of States.isServiceDone
						error(Message.new("Active session was not set"))
					end

					if Keep._isThisSession(activeSession) then
						return {
							loadedData = loadedData,
							datastoreKeyInfo = datastoreKeyInfo,
						}
					end

					if shouldForceLoad then
						local forceLoadSession = metadata.ForceLoad
						local forceLoadInterrupted = false

						if forceLoadSession ~= nil then
							forceLoadInterrupted = Keep._isThisSession(forceLoadSession) == false
						end

						if forceLoadInterrupted then
							-- another session tried to force load this keep
							error(Message.new("ForceLoad was interrupted"))
						end

						if requestForceLoad then
							-- only request a force load once
							requestForceLoad = false
							continue
						end

						forceLoadAttempts += 1

						if forceLoadAttempts >= Config.forceLoadMaxAttempts then
							shouldStealSessionOnForceLoad = true
						else
							-- delay next attempt
							task.wait(forceLoadWaitTime)
							forceLoadWaitTime = math.min(20, forceLoadWaitTime * 2)
						end
					else
						local handler = unreleasedHandler :: Types.unreleasedHandler
						local loadMethod = handler(activeSession)

						if not Enums.LoadMethod[loadMethod] then
							Log.warn(`unreleasedHandler returned an invalid value, defaulting to {Enums.LoadMethod.ForceLoad}.`)

							loadMethod = Enums.LoadMethod.ForceLoad
						end

						if loadMethod == Enums.LoadMethod.Cancel then
							error(Message.new("Operation was canceled"))
						elseif loadMethod == Enums.LoadMethod.ForceLoad then
							shouldForceLoad = true
							requestForceLoad = true
						elseif loadMethod == Enums.LoadMethod.Steal then
							shouldStealSession = true
						end
					end
				end
			end)
				:andThen(function(data: { loadedData: Types.keepStruct<T>, datastoreKeyInfo: DataStoreKeyInfo }?)
					States.cachedKeepPromises[id] = nil

					if not data then
						error(Message.new("Something went wrong"))
					end

					local loadedData = data.loadedData
					local datastoreKeyInfo = data.datastoreKeyInfo

					local keepClass = Keep.new(loadedData, datastoreKeyInfo, self._dataTemplate)

					if datastoreKeyInfo then
						keepClass._keyInfo = datastoreKeyInfo
					end

					keepClass._key = key
					keepClass._datastore = self._datastore -- mock datastore or real datastore
					keepClass._store = self :: any -- TypeError: Internal error: Code is too complex to typecheck!

					if typeof(self._wrapper) == "table" then
						for functionName, func in self._wrapper do -- attach wrapper functions
							keepClass[functionName] = function(...)
								return func(...)
							end
						end
					end

					States.loadedKeeps[id] = keepClass

					Log.print(`Loaded keep {id}.`)

					return keepClass
				end)
				:finally(function()
					States.activeDataStoreJobs -= 1
				end)
		end)
		:catch(function(err)
			return Promise.reject(Log.error(`Unable to load keep for {id}.`, err, true))
		end)

	States.cachedKeepPromises[id] = promise
	return promise
end

--[=[
	@method ViewKeep
	@within Store

	@param key string
	@param version string?

	@return Promise<Keep>

	Loads a Keep from the store and returns a Keep object, but doesn't save it.

	View-only Keeps have the same functions as normal Keeps, but cannot operate on data.

	```lua
	store:ViewKeep(`Player_{player.UserId}`):andThen(function(viewOnlyKeep)
		print(`Viewing {viewOnlyKeep:Identify()}!`)
	end):catch(function(err)
		warn(`Something went wrong! {err}`)
	end)
	```

	:::danger
	View-only Keeps are not cached!
	:::

	:::danger
	[Keep:Destroy()](Keep#Destroy) must be called when view-only Keep is not needed anymore.
	:::
]=]

function Store.ViewKeep<T, R>(self: Types.store<T, R>, key: string, version: string?): PromiseTypes.TypedPromise<Types.viewOnlyKeep<T, R>>
	local id = `{self:Identify()}/{key}`

	if States.isServiceDone then
		return Promise.reject(Message.new(`Server is closing, unable to view keep for {id}`))
	end

	if self._isMockEnabled then
		Log.print(`Using mock store on {id}.`)
	end

	States.activeDataStoreJobs += 1

	return Promise.try(function()
		-- uses :GetAsync()

		local loadedData, datastoreKeyInfo = UpdateAsync(key, self._datastore, {
			onMissing = function(latest)
				latest.data.Data = DeepCopy(self._dataTemplate)
				latest.metadata = DeepCopy(DefaultData.Metadata)
				latest.metadata.Created = os.time()
				latest.userIds = DeepCopy(DefaultData.UserIds)

				latest.metadata.ActiveSession = nil

				return false
			end,
			edit = function(latest)
				if self._preLoad then
					local processedData = self._preLoad(DeepCopy(latest.data.Data))

					if not processedData then
						error(Message.new(":PreLoad() must return a table"))
					end

					latest.data.Data = processedData
				end

				return false
			end,
		}, {
			useGet = { version = version },
		})

		if not loadedData then
			-- :UpdateAsync() was canceled
			error(Message.new("Operation was canceled"))
		end

		local keepClass = Keep.new(loadedData, datastoreKeyInfo, self._dataTemplate)

		if datastoreKeyInfo then
			keepClass._keyInfo = datastoreKeyInfo
		end

		keepClass._viewOnly = true
		keepClass._releasing = true
		keepClass._released = true -- in case they call :Release() and it tries to save

		keepClass._key = key
		keepClass._datastore = self._datastore -- mock datastore or real datastore
		keepClass._store = self :: any -- TypeError: Internal error: Code is too complex to typecheck!

		if typeof(self._wrapper) == "table" then
			for functionName, func in self._wrapper do -- attach wrapper functions
				keepClass[functionName] = function(...)
					return func(...)
				end
			end
		end

		return keepClass
	end)
		:tap(function(keep)
			Log.print(`Loaded view-only keep {keep:Identify()}.`)
		end)
		:catch(function(err)
			return Promise.reject(Log.error(`Unable to view keep for {id}.`, err, true))
		end)
		:finally(function()
			States.activeDataStoreJobs -= 1
		end)
end

--[=[
	@method RemoveKeep
	@within Store

	@param key string

	@return Promise<previousData, DataStoreKeyInfo>

	Removes the ```key``` from the DataStore.

	:::info
	Calling ```:RemoveKeep()``` on the loaded Keep will release it before removing.
	:::

	:::info
	If the previous values were already deleted, the function will return ```nil```, ```nil```.
	:::

	:::warning
	In live servers ```:RemoveKeep()``` must be used on Keeps created through mock stores.
	:::
]=]

function Store.RemoveKeep<T, R>(self: Types.store<T, R>, key: string): PromiseTypes.TypedPromise<Types.keepStruct<T>, DataStoreKeyInfo>
	local id = `{self:Identify()}/{key}`

	States.activeDataStoreJobs += 1

	return Promise.try(function()
		local keep = States.loadedKeeps[id]

		if keep then
			-- no saving, but fire .Released signal
			Keep._release(keep, Promise.resolve()):await()
		end

		return self._datastore:RemoveAsync(key)
	end)
		:tap(function()
			Log.print(`Removed {id}.`)
		end)
		:catch(function(err)
			return Promise.reject(Log.error(`Unable to remove {id}.`, err, true))
		end)
		:finally(function()
			States.activeDataStoreJobs -= 1
		end)
end

--[=[
	@method PreLoad
	@within Store

	@param callback ({ [string]: any }) -> { [string]: any }

	Runs before loading a Keep, allowing you to modify the data before, like decompressing compressed data.

	Decompression example:

	```lua
	store:PreLoad(function(data)
		local newData = {}

		for key, value in data do
			newData[key] = HttpService:JSONDecode(value)
		end

		return newData
	end)
	```

	:::warning
	Callback **must** return a new data table.
	:::

	:::danger
	```:PreLoad()``` can only be set once.
	:::
]=]

function Store.PreLoad<T, R>(self: Types.store<T, R>, callback: (data: Types.data<T>) -> Types.data<T>)
	assert(self._preLoad == nil, "[DataKeep] :PreLoad() can only be set once")
	assert(callback and typeof(callback) == "function", "[DataKeep] :PreLoad() callback must be a function")

	self._preLoad = callback
end

--[=[
	@method PreSave
	@within Store

	@param callback ({ [string]: any }) -> { [string]: any }

	Runs before saving a Keep, allowing you to modify the data before, like compressing data.

	Compression example:

	```lua
	store:PreSave(function(data)
		local newData = {}

		for key, value in data do
			newData[key] = HttpService:JSONEncode(value)
		end

		return newData
	end)
	```

	:::warning
	Callback **must** return a new data table.
	:::

	:::danger
	```:PreSave()``` can only be set once.
	:::
]=]

function Store.PreSave<T, R>(self: Types.store<T, R>, callback: (data: Types.data<T>) -> Types.data<T>)
	assert(self._preSave == nil, "[DataKeep] :PreSave() can only be set once")
	assert(callback and typeof(callback) == "function", "[DataKeep] :PreSave() callback must be a function")

	self._preSave = callback
end

--[=[
	@method PostGlobalUpdate
	@within Store

	@param key string
	@param updateHandler (GlobalUpdates) -> ()

	@return Promise<updatedData, DataStoreKeyInfo>

	Posts a global update to a Keep.

	```lua
	store:PostGlobalUpdate(`Player_{player.UserId}`, function(globalUpdates)
		globalUpdates:AddGlobalUpdate({
			Hello = "World!",
		}):andThen(function(updateId)
			print("Added Global Update!")
		end)
	end)
	```

	:::info
	Check [GlobalUpdates](GlobalUpdates) for more info.
	:::

	:::danger
	Yielding inside ```updateHandler``` is not allowed.
	:::
]=]

function Store.PostGlobalUpdate<T, R>(self: Types.store<T, R>, key: string, updateHandler: (globalUpdates: Types.globalUpdatesClass) -> ()): PromiseTypes.TypedPromise<any, DataStoreKeyInfo>
	if States.isServiceDone then
		return Promise.reject(Message.new("Server is closing, unable to post global update"))
	end

	if self._isMockEnabled then
		Log.print(`Using mock store on {self:Identify()}/{key}.`)
	end

	States.activeDataStoreJobs += 1

	return Promise.try(function()
		return UpdateAsync(key, self._datastore, {
			edit = function(latest)
				local globalUpdateObject = {
					_updates = latest.data.GlobalUpdates,
				}

				setmetatable(globalUpdateObject, GlobalUpdates)

				updateHandler(globalUpdateObject :: any)

				return false
			end,
		}, {})
	end)
		:tap(function()
			Log.print(`Posted global update to {self:Identify()}/{key}.`)
		end)
		:catch(function(err)
			return Promise.reject(Log.error(`Unable to post global update to {self:Identify()}/{key}.`, err, true))
		end)
		:finally(function()
			States.activeDataStoreJobs -= 1
		end)
end

return Store
