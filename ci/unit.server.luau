print("Running unit tests...")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestEZ = require(ReplicatedStorage.DevPackages.TestEZ)

local tests = {}

for _, module in ServerScriptService.ServerPackages:GetDescendants() do
	if module.Name:match("%.spec$") and module:IsA("ModuleScript") then
		table.insert(tests, module)
	end
end

-- Run tests
TestEZ.TestBootstrap:run(tests)
