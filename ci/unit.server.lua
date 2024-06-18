print("Running unit tests...")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
print(ReplicatedStorage.Test:GetChildren())
local TestEZ = require(ReplicatedStorage.Test.TestEZ)

-- Clear out package test files

local tests = {}
for _, module in ipairs(ServerScriptService.ServerPackages:GetDescendants()) do
	if module.Name:match("%.spec$") and module:IsA("ModuleScript") then
		table.insert(tests, module)
	end
end

-- Run tests
TestEZ.TestBootstrap:run(tests)
