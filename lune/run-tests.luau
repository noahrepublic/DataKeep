local process = require("@lune/process")
process.spawn("wally", { "install" }, {
	cwd = process.cwd,
})

print("Installed test packages")

process.spawn("rojo", {
	"build",
	"-o",
	"game.rbxl",
	"test-place.project.json",
})

print("Built test place")

local result = process.spawn("run-in-roblox", { "--script", "ci/unit.server.lua", "--place", "game.rbxl" })

print("Running")

print(result.stdout)
