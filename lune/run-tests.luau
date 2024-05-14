local process = require("@lune/process")
process.spawn("wally", { "install" }, {
	cwd = process.cwd .. "/test",
})

process.spawn("rojo", {
	"build",
	"-o",
	"game.rbxl",
	"test-place.project.json",
})

local result = process.spawn("run-in-roblox", { "--script", "ci/unit.server.lua", "--place", "game.rbxl" })

print(result.stdout)
