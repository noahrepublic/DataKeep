local Signal = require(script.Parent.Parent.Signal)

local function getOrCreateListener(self, dataPath)
	if not self._listeners then
		self._listeners = {}

		self.OnRelease:Connect(function()
			for index, signal in pairs(self._listeners) do
				signal:Destroy()
			end
		end)
	end

	local listeners = self._listeners

	if not listeners[dataPath] then
		listeners[dataPath] = Signal.new()
	end

	return listeners[dataPath]
end

return {
	onDataChange = function(self, dataPath: string, callback)
		local listener = getOrCreateListener(self, dataPath)

		return if listener then listener:Connect(callback) else nil
	end,

	Mutate = function(self, dataPath: string, processor)
		local dataToFindSplit = string.split(dataPath, ".")

		local currentData = self.Data

		for i, part in ipairs(dataToFindSplit) do
			if i == #dataToFindSplit then
				currentData[part] = processor(currentData[part])

				local listeners = self._listeners

				if listeners then
					local signal = listeners[dataPath]

					if signal then
						signal:Fire(currentData[part])
					end
				end
			else
				currentData = currentData[part]
			end
		end
	end,
}
