---@type ProcLoader.Manifest
return {
	type = "ProcLoader",
	---@type ProcLoader.Manifest.DrawnResourceOptions
	options = {
		type = "Drawn",
		script = [[
local TW, TH = 32, 32
local halfTW, halfTH = TW * 0.5, TH * 0.5

local xMargin = 2
local width = 6
local height = 18
local radius = 3

local yMargin = (TH - height) * 0.5
local PI = math.pi

love.graphics.setLineWidth(3)
love.graphics.arc("line", "open",
	halfTW, halfTH,
5, 0.3, PI * 1.5 + 0.07)
love.graphics.rectangle("fill", 16, 8, 2, 7)
love.graphics.polygon("fill",
	18, 7,
	22, 12,
	18, 15
)
]],
		width = 32,
		height = 32
	},
	cache = {
		checkMode = "onChange",
	}
}
