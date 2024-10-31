--!strict

--> Services

local DataStoreService = game:GetService("DataStoreService")

--> Includes

local Promise = require(script.Parent.Parent.Promise)

local Config = require(script.Parent.Config)
local DeepCopy = require(script.Parent.Utils.DeepCopy)
local DefaultData = require(script.Parent.DefaultData)
local Enums = require(script.Parent.Enums)
local GlobalUpdates = require(script.Parent.GlobalUpdates)
local Keep = require(script.Parent.Keep)
local Log = require(script.Parent.Utils.Log)
local MockStore = require(script.Parent.MockStore)
local PromiseTypes = require(script.Parent.PromiseTypes)
local RemoveKeepInternally = require(script.Parent.Utils.RemoveKeepInternally)
local States = require(script.Parent.States)
local Types = require(script.Parent.Types)
local UpdateKeepAsync = require(script.Parent.Utils.UpdateKeepAsync)

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

	@return Promise<Keep?>

	Loads a Keep from the store and returns a Keep object.

	```lua
	store:LoadKeep(`Player_{player.UserId}`, function()
		return DataKeep.Enums.LoadMethod.ForceLoad
	end)):andThen(function(keep)
		if not keep then
			player:Kick("Session lock interrupted!")
			return
		end

		print(`Loaded {keep:Identify()}!`)
	end)
	```

	:::info
	Stores can be loaded multiple times as they are cached, that way you can call [:LoadKeep()](#LoadKeep) multiple times and get the same cached Keeps.
	:::info
]=]

function Store.LoadKeep<T, R>(self: Types.store<T, R>, key: string, unreleasedHandler: Types.unreleasedHandler?): PromiseTypes.TypedPromise<Types.keep<T, R>>
	if unreleasedHandler ~= nil and typeof(unreleasedHandler) ~= "function" then
		return Promise.try(function()
			Log.error("[DataKeep] unreleasedHandler must be a function")
			return Promise.reject()
		end)
	end

	if unreleasedHandler == nil then
		unreleasedHandler = function(_)
			return Enums.LoadMethod.ForceLoad
		end
	end

	local id = `{self:Identify()}/{key}`

	if not States.loadedKeeps[id] and States.isServiceDone then
		Log.warn(`[DataKeep] Server is closing, unable to load new keep for {id}`)
		return Promise.resolve(nil)
	end

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
				RemoveKeepInternally(States.loadedKeeps[id] :: any) -- additional cleanup to prevent memory leaks
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

			if self._isMockEnabled then
				Log.print(`[DataKeep] Using mock store on {id}`)
			end

			local shouldForceLoad = false
			local requestForceLoad = false
			local shouldStealSessionOnForceLoad = false -- used only with ForceLoad
			local shouldStealSession = false -- unreleasedHandler() == Enums.LoadMethod.Steal

			local forceLoadAttempts = 0

			return Promise.try(function(): { loadedData: any, dataStoreKeyInfo: DataStoreKeyInfo }?
				while true do
					local loadedData, dataStoreKeyInfo = UpdateKeepAsync(key, self._datastore, {
						onExisting = function(latestData)
							if States.isServiceDone then
								return true
							end

							local activeSession = latestData.MetaData.ActiveSession
							local forceLoadSession = latestData.MetaData.ForceLoad

							if activeSession == nil then
								latestData.MetaData.ActiveSession = DeepCopy(DefaultData.MetaData.ActiveSession)
								latestData.MetaData.ForceLoad = nil
							elseif typeof(activeSession) == "table" then
								if not Keep._isThisSession(activeSession) then
									local lastUpdate = latestData.MetaData.LastUpdate

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
											latestData.MetaData.ActiveSession = DeepCopy(DefaultData.MetaData.ActiveSession)
											latestData.MetaData.ForceLoad = nil
										end
									elseif requestForceLoad then
										latestData.MetaData.ForceLoad = DeepCopy(DefaultData.MetaData.ActiveSession)
									end
								else
									latestData.MetaData.ForceLoad = nil
								end
							end

							return false
						end,
						onMissing = function(latestData)
							latestData.Data = DeepCopy(self._dataTemplate)
							latestData.MetaData = DeepCopy(DefaultData.MetaData)
							latestData.MetaData.Created = os.time()
							latestData.UserIds = DeepCopy(DefaultData.UserIds)

							return false
						end,
						edit = function(latestData)
							if States.isServiceDone then
								return true
							end

							local activeSession = latestData.MetaData.ActiveSession

							if activeSession ~= nil and Keep._isThisSession(activeSession) then
								latestData.MetaData.LoadCount += 1
								latestData.MetaData.LastUpdate = os.time()

								if self._preLoad then
									local processedData = self._preLoad(DeepCopy(latestData.Data))

									if not processedData then
										Log.error("[DataKeep] :PreLoad() must return a table")
										return true
									end

									latestData.Data = processedData
								end
							end

							return false
						end,
					})

					if not loadedData or not dataStoreKeyInfo then
						-- cancel :LoadKeep() attempt
						return nil
					end

					local activeSession = loadedData.MetaData.ActiveSession

					if not (typeof(activeSession) == "table") then
						-- probably because of States.isServiceDone
						return nil
					end

					if Keep._isThisSession(activeSession) then
						return {
							loadedData = loadedData,
							dataStoreKeyInfo = dataStoreKeyInfo,
						}
					end

					if shouldForceLoad then
						local forceLoadSession = loadedData.MetaData.ForceLoad
						local forceLoadInterrupted = false

						if forceLoadSession ~= nil then
							forceLoadInterrupted = Keep._isThisSession(forceLoadSession) == false
						end

						if forceLoadInterrupted then
							-- another session tried to force load this keep
							return nil
						end

						if not requestForceLoad then
							forceLoadAttempts += 1

							if forceLoadAttempts == Config.forceLoadMaxAttempts then
								shouldStealSessionOnForceLoad = true
							else
								local attemptsLeft = Config.forceLoadMaxAttempts - forceLoadAttempts
								task.wait(2 ^ (Config.forceLoadMaxAttempts - attemptsLeft)) -- don't ask why, it just works :)
							end
						end

						requestForceLoad = false -- only request a force load once
					else
						local handler = unreleasedHandler :: Types.unreleasedHandler
						local loadMethod = handler(activeSession)

						if not Enums.LoadMethod[loadMethod] then
							Log.warn(`[DataKeep] unreleasedHandler returned an invalid value, defaulting to {Enums.LoadMethod.ForceLoad}`)

							loadMethod = Enums.LoadMethod.ForceLoad
						end

						if loadMethod == Enums.LoadMethod.Cancel then
							return nil
						elseif loadMethod == Enums.LoadMethod.ForceLoad then
							shouldForceLoad = true
							requestForceLoad = true
						elseif loadMethod == Enums.LoadMethod.Steal then
							shouldStealSession = true
						end
					end
				end
			end):andThen(function(keepData)
				States.cachedKeepPromises[id] = nil

				if not keepData then
					return nil
				end

				local loadedData = keepData.loadedData
				local dataStoreKeyInfo = keepData.dataStoreKeyInfo

				local keepClass = Keep.new(loadedData, self._dataTemplate)

				if dataStoreKeyInfo then
					keepClass._keyInfo = dataStoreKeyInfo
				end

				keepClass._key = key
				keepClass._datastore = self._datastore -- mock datastore or real datastore
				keepClass._store = self :: any -- TypeError: Internal error: Code is too complex to typecheck! Consider adding type annotations around this area

				if typeof(self._wrapper) == "table" then
					for functionName, func in self._wrapper do -- attach wrapper functions
						keepClass[functionName] = function(...)
							return func(...)
						end
					end
				end

				States.loadedKeeps[keepClass:Identify()] = keepClass

				Log.print(`[DataKeep] Loaded keep {keepClass:Identify()}`)

				return keepClass
			end)
		end)
		:catch(function(err)
			Log.error(`[DataKeep] Unable to load keep for {id}: {err}`, true)
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
	end)
	```

	:::warning
	View-only Keeps are not cached!
	:::warning

	:::warning
	[Keep:Destroy()](Keep#Destroy) must be called when view-only Keep is not needed anymore.
	:::warning
]=]

function Store.ViewKeep<T, R>(self: Types.store<T, R>, key: string, version: string?): PromiseTypes.TypedPromise<Types.viewOnlyKeep<T, R>>
	local id = `{self:Identify()}/{key}`

	if States.isServiceDone then
		Log.warn(`[DataKeep] Server is closing, unable to view keep for {id}`)
		return Promise.reject()
	end

	return Promise.new(function(resolve, reject)
		local loadedData, dataStoreKeyInfo = UpdateKeepAsync(key, self._datastore, {
			onMissing = function(latestData)
				latestData.Data = DeepCopy(self._dataTemplate)
				latestData.MetaData = DeepCopy(DefaultData.MetaData)
				latestData.MetaData.Created = os.time()
				latestData.UserIds = DeepCopy(DefaultData.UserIds)

				latestData.MetaData.ActiveSession = nil

				return false
			end,
		}, { version = version })

		if self._preLoad then
			local processedData = self._preLoad(DeepCopy(loadedData.Data))

			if not processedData then
				Log.error("[DataKeep] :PreLoad() must return a table")
				return reject()
			end

			loadedData.Data = processedData
		end

		local keepClass = Keep.new(loadedData, self._dataTemplate)

		if dataStoreKeyInfo then
			keepClass._keyInfo = dataStoreKeyInfo
		end

		keepClass._viewOnly = true
		keepClass._releasing = true
		keepClass._released = true -- incase they call :Release() and it tries to save

		keepClass._key = key
		keepClass._datastore = self._datastore -- mock datastore or real datastore
		keepClass._store = self :: any -- TypeError: Internal error: Code is too complex to typecheck! Consider adding type annotations around this area

		if typeof(self._wrapper) == "table" then
			for functionName, func in self._wrapper do -- attach wrapper functions
				keepClass[functionName] = function(...)
					return func(...)
				end
			end
		end

		return resolve(keepClass)
	end)
		:tap(function(keep)
			Log.print(`[DataKeep] Loaded view-only keep {keep:Identify()}`)
		end)
		:catch(function(err)
			Log.error(`[DataKeep] Unable to view keep for {id}: {err}`, true)
		end)
end

--[=[
	@method PreLoad
	@within Store

	@param callback ({ [string]: any }) -> { [string]: any }

	Runs before loading a Keep, allowing you to modify the data before, like decompressing compressed data.

	:::caution
	Callback **must** return a new data table.
	:::caution

	:::warning
	```:PreLoad()``` can only be set once.
	:::warning

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
]=]

function Store.PreLoad<T, R>(self: Types.store<T, R>, callback: (Types.data<T>) -> Types.data<T>)
	assert(self._preLoad == nil, "[DataKeep] :PreLoad() can only be set once")
	assert(callback and typeof(callback) == "function", "[DataKeep] :PreLoad() callback must be a function")

	self._preLoad = callback
end

--[=[
	@method PreSave
	@within Store

	@param callback ({ [string]: any }) -> { [string]: any }

	Runs before saving a Keep, allowing you to modify the data before, like compressing data.

	:::caution
	Callback **must** return a new data table.
	:::caution

	:::warning
	```:PreSave()``` can only be set once.
	:::warning

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
]=]

function Store.PreSave<T, R>(self: Types.store<T, R>, callback: (Types.data<T>) -> Types.data<T>)
	assert(self._preSave == nil, "[DataKeep] :PreSave() can only be set once")
	assert(callback and typeof(callback) == "function", "[DataKeep] :PreSave() callback must be a function")

	self._preSave = callback
end

--[=[
	@method PostGlobalUpdate
	@within Store

	@param key string
	@param updateHandler (GlobalUpdates) -> ()

	@return Promise<updatedData,DataStoreKeyInfo>

	Posts a global update to a Keep.

	```updateHandler``` reveals globalUpdates to the API.

	```lua
	store:PostGlobalUpdate(`Player_{player.UserId}`, function(globalUpdates)
		globalUpdates:AddGlobalUpdate({
			Hello = "World!",
		}):andThen(function(updateId)
			print("Added Global Update!")
		end)
	end)
	```
]=]

function Store.PostGlobalUpdate<T, R>(self: Types.store<T, R>, key: string, updateHandler: (Types.globalUpdatesClass) -> ()): PromiseTypes.TypedPromise<any, DataStoreKeyInfo> -- gets passed add, lock & change functions
	return Promise.try(function()
		if States.isServiceDone then
			Log.error("[DataKeep] Server is closing, unable to post global update")
			return Promise.reject()
		end

		return UpdateKeepAsync(key, self._datastore, {
			edit = function(latestData)
				if States.isServiceDone then
					Log.error("[DataKeep] Server is closing, unable to post global update")
					return true
				end

				local globalUpdateObject = {
					_updates = latestData.GlobalUpdates,
				}

				setmetatable(globalUpdateObject, GlobalUpdates)

				updateHandler(globalUpdateObject :: any)

				return false
			end,
		})
	end)
		:tap(function()
			Log.print(`[DataKeep] Posted global update to {self:Identify()}/{key}`)
		end)
		:catch(function(err)
			Log.error(`[DataKeep] Unable to post GlobalUpdate: {err}`, true)
		end)
end

return Store
