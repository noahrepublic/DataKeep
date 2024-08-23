--!strict

local function freezeDeep<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end

	if not table.isfrozen(value) then
		table.freeze(value)
	end

	for _, innerValue in value do
		freezeDeep(innerValue)
	end

	return value
end

return freezeDeep
