---@type ProcLoader.Manifest
return {
	type = "ProcLoader",
	---@type ProcLoader.Manifest.DrawnResourceOptions
	options = {
		type = "Drawn",
		script = [[
love.graphics.polygon("fill",
	10, 8,
	24, 16,
	10, 24
)
]],
		width = 32,
		height = 32
	},
	cache = {
		checkMode = "onChange",
	}
}
