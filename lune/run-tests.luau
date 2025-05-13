--!nocheck

-- selene: allow(incorrect_standard_library_use)

local process = require("@lune/process")

local installResult = process.exec("lune", { "run", "lune/install-packages.luau" }, {
	cwd = process.cwd,
	stdio = "inherit",
})

if not installResult.ok then
	process.exit(1)
end

local buildResult = process.exec("rojo", { "build", "-o", "unit-tests.rbxl", "test-place.project.json" }, {
	stdio = "inherit",
})

if not buildResult.ok then
	process.exit(1)
end

local runResult = process.exec("run-in-roblox", { "--script", "ci/unit.server.luau", "--place", "unit-tests.rbxl" }, {
	stdio = "forward",
})

if not runResult.ok then
	process.exit(1)
end
