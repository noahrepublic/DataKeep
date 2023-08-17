--!strict

--> Structure

local MockStore = {}
MockStore.__index = MockStore

--> Constructor

function MockStore.new()
	return setmetatable({
		_data = {},
	}, MockStore)
end

--> Types

export type MockStore = typeof(MockStore.new()) & {
	_data: any,
}

--> Public Methods

function MockStore:GetAsync(key: string)
	return self._data[key]
end

function MockStore:SetAsync(key: string, value: any)
	self._data[key] = value
end

function MockStore:UpdateAsync(key: string, callback: (any) -> any)
	local value = self._data[key]
	local newValue = callback(value)
	self._data[key] = newValue
	return newValue
end

return MockStore
