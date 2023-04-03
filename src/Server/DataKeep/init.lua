--[[ DataKeep.lua
     The final data saving solution you need

    Using production quality patterns and techniques everyone should be using.
    DataKeep Provides functions and methods for a permanent data saving solution. 

    This is the main module of the DataKeep system. It is the only module that should be used by the developer.

    DataKeep is a singleton class that is used to create DataStore objects that are further used to create "Keeps" inside of the class for saving.
]]

--> Services

local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")

--> Class Structure

local Store = {
	mockStore = false, -- Enabled when DataStoreService & MemoryService is not available (Studio)
	backupStore = false, -- Enabled when DataStoreService is not available

	mockDataStore = {}, -- Mock data for when DataStoreService is not available

	_saveInterval = 30,

	_storeQueue = {}, -- Stores that are currently being saved
}
Store.__index = Store

--> Variables

local Keep = require(script.Keep)
local Mock = require(script.Mock)

--> Private Functions

local function deepCopy(target: table)
	local copy = {}

	for key, value in pairs(target) do
		if type(value) == "table" then
			copy[key] = deepCopy(value)
		else
			copy[key] = value
		end
	end

	return copy
end

local function fillMissingData(data: table, template: table)
	for key, value in pairs(template) do
		if not type(key) == "string" then
			continue
		end -- Should be string

		if data[key] == nil then
			if type(value) == "table" then
				data[key] = deepCopy(value)
			else
				data[key] = value
			end
		end

		if type(value) == "table" and type(data[key]) == "table" then
			fillMissingData(data[key], value)
		end
	end
end

--> Public Functions

--[[ Store:GetStore() 
    Initializes a Store object with the given information.
]]

function Store.GetStore(storeInfo: table, dataTemplate: table)
	if type(storeInfo) == "string" then
		storeInfo = { storeInfo }
	end

	assert(storeInfo.Name ~= nil or storeInfo[1] ~= nil, "GetStore() requires a store name passed")

	local self = setmetatable({}, Store)

	self._store_name = storeInfo.Name or storeInfo[1]
	self._store_scope = storeInfo.Scope or storeInfo[2] or nil
	self._store_template = dataTemplate or {}

	if RunService:IsStudio() then
		warn("DataStoreService is not available. Using mock datastores instead.")

		self.mockStore = true
	else
		local success = pcall(function()
			self._store = DataStoreService:GetDataStore(self._store_name, self._store_scope)
		end)

		if not success then
			self._backup_store = MemoryStoreService:GetQueue(self._store_name)
			self.backupStore = true
		end
	end

	self._keepsInQueue = {} -- Keeps that are currently owned by the session

	Store._storeQueue[self._store_name] = self
	return self
end

--[[ Store:LoadKeep(identifyingKey: string) 
	Loads datastore data and forms a Keep object.

	The keep object can be in overwriting mode, or viewing.

	@param identifyingKey: string
]]

function Store:LoadKeep(identifyingKey: string)
	local rawDataInStore
	if not RunService:IsStudio() then
		pcall(function()
			rawDataInStore = self._store:GetAsync(identifyingKey)
		end)
	end

	if rawDataInStore == nil then
		rawDataInStore = { Data = deepCopy(self._store_template) }
	end

	fillMissingData(rawDataInStore, self._store_template)

	local keep = Keep.new(rawDataInStore)

	if self.mockStore then
		keep:Mock()
		self.mockDataStore[identifyingKey] = keep
	end

	if keep._canSave then
		table.insert(self._keepsInQueue, keep)
	end

	return keep
end

Store.ViewKeep = Store.LoadKeep

--> Connections

local totalDt = 0

RunService.Heartbeat:Connect(function(dt)
	totalDt += dt

	if not (totalDt >= Store._saveInterval) then
		return
	end

	totalDt = 0

	for _, store in pairs(Store._storeQueue) do
		for keep in ipairs(store._keepsInQueue) do
			keep = store._keepsInQueue[keep]

			if keep == nil or not keep._canSave then
				continue
			end

			keep:Save()
		end
	end
end)

return Store
