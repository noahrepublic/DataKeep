--!strict

local MockStorePages = {}
MockStorePages.__index = MockStorePages

--> Types

export type MockStore = typeof(setmetatable({}, MockStorePages)) & {
	_data: any,
	_currentPage: number,
	_pageSize: number,
	IsFinished: boolean,
}

--> Public Methods

function MockStorePages:GetCurrentPage()
	local retValue = {}

	local currentPage: number = self._currentPage
	local pageSize: number = self._pageSize

	local minimumIndex = math.max(1, (currentPage - 1) * pageSize + 1)
	local maximumIndex = math.min(currentPage * pageSize, #self._data)

	for i = minimumIndex, maximumIndex do
		table.insert(retValue, { key = self._data[i].key, value = self._data[i].value })
	end

	return retValue
end

function MockStorePages:AdvanceToNextPageAsync()
	if self.IsFinished then
		warn("Cannot advance to next page, already finished")
		return
	end

	local currentPage: number = self._currentPage
	local pageSize: number = self._pageSize

	if #self._data > currentPage * pageSize then
		self._currentPage = currentPage + 1
	end

	self.IsFinished = #self._data <= self._currentPage * self._pageSize
end

return function(unparsedData, isAscending: boolean, pageSize: number)
	local data = {}

	for key, value in pairs(unparsedData) do
		table.insert(data, if not isAscending then math.max(#data, 1) else 1, { key = key, value = value })
	end

	pageSize = math.min(pageSize, 1024)

	return setmetatable({
		_data = data,
		_currentPage = 1,
		_pageSize = pageSize,
		IsFinished = #data == pageSize,
	}, MockStorePages)
end
