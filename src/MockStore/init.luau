--!strict

--> Includes

local DeepCopy = require(script.Parent.Utils.DeepCopy)
local Message = require(script.Parent.Utils.Message)
local MockStorePages = require(script.MockStorePages)
local Types = require(script.Parent.Types)
local keyInfo = require(script.keyInfo)

--> Structure

local MockStore = {}
MockStore.__index = MockStore

--> Constructor

function MockStore.new()
	return setmetatable({
		_data = {},
		_dataVersions = {},
	}, MockStore)
end

--> Private Functions

local function didyield(f, ...)
	local finished = false
	local data, userIds, metadata

	coroutine.wrap(function(...)
		data, userIds, metadata = f(...)
		finished = true
	end)(...)

	return not finished, data, userIds, metadata
end

--> Public Methods

function MockStore:GetAsync(key: string): (any, DataStoreKeyInfo?)
	local dataVersions: keyInfo.dataVersions? = if self._dataVersions then self._dataVersions[key] else nil
	return DeepCopy(self._data[key]), if dataVersions then dataVersions[#dataVersions].datastoreKeyInfo else nil :: any
end

function MockStore:SetAsync(key: string, value: any, userIds: Types.userIds?, metadata: Types.metadata?)
	self._data[key] = DeepCopy(value)

	local versionInfo = keyInfo.new(self, key, value, userIds, metadata)
	return versionInfo.Version, versionInfo
end

function MockStore:UpdateAsync(key: string, callback: (any, DataStoreKeyInfo?) -> (any, Types.userIds, Types.metadata)): (any?, DataStoreKeyInfo?)
	local value, datastoreKeyInfo: DataStoreKeyInfo? = self:GetAsync(key)

	local yielded, newValue, userIds, metadata = didyield(callback, value, datastoreKeyInfo)

	if yielded then
		error(Message.new("UpdateAsync yielded!"))
	end

	if not newValue then -- operation canceled
		return nil
	end

	self:SetAsync(key, newValue, userIds, metadata)
	return self:GetAsync(key)
end

function MockStore:RemoveAsync(key: string): (any, DataStoreKeyInfo)
	local oldData, oldDataStoreKeyInfo: DataStoreKeyInfo? = self:GetAsync(key)
	self._data[key] = nil

	local oldMetadata = if oldDataStoreKeyInfo then oldDataStoreKeyInfo:GetMetadata() else nil
	local oldUserIds = if oldDataStoreKeyInfo then oldDataStoreKeyInfo:GetUserIds() else nil

	local datastoreKeyInfo = keyInfo.new(self, key, nil, oldUserIds, oldMetadata)
	datastoreKeyInfo.Deleted = true

	return oldData, datastoreKeyInfo :: any
end

function MockStore:ListVersionsAsync(key: string, sortDirection: Enum.SortDirection, minDate: number, maxDate: number, limit: number)
	limit = limit or 1

	local versions: keyInfo.dataVersions = self._dataVersions[key]

	if not versions then
		return MockStorePages({}, sortDirection == Enum.SortDirection.Ascending, limit)
	end

	local filteredVersions = {}

	for _, versionData in versions do
		local createdTime = versionData.datastoreKeyInfo.CreatedTime

		minDate = minDate or 0
		maxDate = maxDate or math.huge

		if createdTime >= minDate and createdTime <= maxDate then
			table.insert(filteredVersions, 1, DeepCopy(versionData.datastoreKeyInfo))
		end
	end

	table.sort(filteredVersions, function(a, b)
		return a.CreatedTime < b.CreatedTime
	end)

	return MockStorePages(filteredVersions, sortDirection == Enum.SortDirection.Ascending, limit)
end

function MockStore:GetVersionAsync(key: string, version: string)
	local versions: keyInfo.dataVersions = self._dataVersions[key]

	if not versions then
		return
	end

	for _, versionData in versions do
		if versionData.datastoreKeyInfo.Version == version then
			return DeepCopy(versionData.data)
		end
	end

	return
end

return MockStore
