--!strict

local function deepCopy<T>(t: T): T
	if not (typeof(t) == "table") then
		return t
	end

	local function copyDeep(tbl: { any })
		local tCopy = table.clone(tbl)

		for k, v in tCopy do
			if typeof(v) == "table" then
				tCopy[k] = copyDeep(v)
			end
		end

		return tCopy
	end

	return copyDeep(t :: any) :: T
end

return deepCopy
