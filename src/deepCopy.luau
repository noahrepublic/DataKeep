local function deepCopy<T>(t: T): T
	local function copyDeep(tbl: { any })
		local tCopy = table.clone(tbl)

		for k, v in tCopy do
			if type(v) == "table" then
				tCopy[k] = copyDeep(v)
			end
		end

		return tCopy
	end

	return copyDeep(t :: any) :: T
end

return deepCopy
