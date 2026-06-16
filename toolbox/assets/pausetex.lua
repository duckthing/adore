---@type ProcLoader.Manifest
return {
	type = "ProcLoader",
	---@type ProcLoader.Manifest.DrawnResourceOptions
	options = {
		type = "Drawn",
		script = [[
local TW, TH = 32, 32
local halfTW = TW * 0.5

local xMargin = 2
local width = 5
local height = 16
local radius = 3

local yMargin = (TH - height) * 0.5

love.graphics.rectangle("fill", halfTW - xMargin - width, yMargin, width, height, radius)
love.graphics.rectangle("fill", halfTW + xMargin        , yMargin, width, height, radius)
]],
		width = 32,
		height = 32
	},
	cache = {
		checkMode = "onChange",
	}
}
