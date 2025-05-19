--!nocheck

-- selene: allow(incorrect_standard_library_use)

local process = require("@lune/process")

local installResult = process.exec("wally", { "install" }, {
	cwd = process.cwd,
})

if not installResult.ok then
	print(installResult.stderr)
	process.exit(1)
end

local sourcemapResult = process.exec("rojo", { "sourcemap", "test-place.project.json", "--output", "sourcemap.json" }, {
	cwd = process.cwd,
})

if not sourcemapResult.ok then
	print(sourcemapResult.stderr)
	process.exit(1)
end

process.exec("wally-package-types", { "--sourcemap", "sourcemap.json", "Packages/" }, {
	cwd = process.cwd,
})

process.exec("wally-package-types", { "--sourcemap", "sourcemap.json", "DevPackages/" }, {
	cwd = process.cwd,
})

print("Installed all packages")
