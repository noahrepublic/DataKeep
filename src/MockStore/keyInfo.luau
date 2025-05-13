--!strict

local DeepCopy = require(script.Parent.Parent.Utils.DeepCopy)
local Types = require(script.Parent.Parent.Types)

local datastoreKeyInfo = {}
datastoreKeyInfo.__index = datastoreKeyInfo

export type datastoreKeyInfo = {
	Version: string,
	CreatedTime: number,
	UpdatedTime: number,
	Deleted: boolean,

	_metadata: Types.metadata,
	_userIds: { number },

	GetMetadata: (self: datastoreKeyInfo) -> Types.metadata,
	GetUserIds: (self: datastoreKeyInfo) -> { number },
}

export type dataVersions = {
	{
		datastoreKeyInfo: datastoreKeyInfo,
		data: any,
	}
}

function datastoreKeyInfo.new(store, key: string, data: any, userIds: Types.userIds?, metadata: Types.metadata?): datastoreKeyInfo
	if store._dataVersions[key] == nil then
		store._dataVersions[key] = {}
	end

	local dataVersions: dataVersions = store._dataVersions[key]

	local versionData = {
		Version = tostring(#dataVersions + 1),
		CreatedTime = os.time(),
		UpdatedTime = os.time(),
		Deleted = false,

		_metadata = if metadata then DeepCopy(metadata) else {},
		_userIds = if userIds then DeepCopy(userIds) else {},
	}

	table.insert(dataVersions, {
		datastoreKeyInfo = versionData :: any,
		data = DeepCopy(data),
	})

	local self = versionData
	return setmetatable(self, datastoreKeyInfo) :: any
end

function datastoreKeyInfo.GetMetadata(self: datastoreKeyInfo)
	return DeepCopy(self._metadata)
end

function datastoreKeyInfo.GetUserIds(self: datastoreKeyInfo)
	return DeepCopy(self._userIds)
end

return datastoreKeyInfo
