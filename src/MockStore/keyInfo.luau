--!strict

local DeepCopy = require(script.Parent.Parent.Utils.DeepCopy)
local Types = require(script.Parent.Parent.Types)

export type keyInfo = {
	Version: string,
	CreatedTime: number,
	UpdatedTime: number,
	Deleted: boolean,

	_metadata: Types.metadata,
	_userIds: Types.userIds,

	GetMetadata: (self: keyInfo) -> Types.metadata,
	GetUserIds: (self: keyInfo) -> Types.userIds,
}

export type dataVersions = {
	{
		keyInfo: keyInfo,
		data: any,
	}
}

local keyInfo = {}
keyInfo.__index = keyInfo

function keyInfo.new(store, key: string, data: any, userIds: Types.userIds?, metadata: Types.metadata?): keyInfo
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
		keyInfo = versionData :: any,
		data = DeepCopy(data),
	})

	local self = versionData
	return setmetatable(self, keyInfo) :: any
end

function keyInfo.GetMetadata(self: keyInfo)
	return DeepCopy(self._metadata)
end

function keyInfo.GetUserIds(self: keyInfo)
	return DeepCopy(self._userIds)
end

return keyInfo
