---@type AdoreInit
local Adore = require("")
---@alias DefaultTheme Theme

local function onRequire()
	local Nodes = Adore.Nodes
	local Resources = Adore.Resources

	local Theme = Resources("Theme")

	local ColorRect = Nodes("ColorRect")
	local BaseButton = Nodes("BaseButton")
	local Button = Nodes("Button")
	local TextureButton = Nodes("TextureButton")
	local Label = Nodes("Label")
	local TextureRect = Nodes("TextureRect")
	local NinePatchRect = Nodes("NinePatchRect")
	local LineEdit = Nodes("LineEdit")
	local TabBar = Nodes("TabBar")
	local TabContainer = Nodes("TabContainer")

	local Box = Resources("DrawRequest.Box")
	local DrawLabel = Resources("DrawRequest.Label")
	local DrawTexture = Resources("DrawRequest.TextureRect")
	local DrawBaseButton = Resources("DrawRequest.BaseButton")
	local DrawButton = Resources("DrawRequest.Button")
	local DrawTextureButton = Resources("DrawRequest.TextureButton")
	local DrawLineEdit = Resources("DrawRequest.LineEdit")
	local DrawNinePatchRect = Resources("DrawRequest.NinePatchRect")
	local DrawTabBar = Resources("DrawRequest.TabBar")
	local DrawTabContainer = Resources("DrawRequest.TabContainer")

	local default = Theme()

	default:setDrawable(ColorRect, nil, Box())
	default:setDrawable(NinePatchRect, nil, DrawNinePatchRect())

	do
		local buttonColors = {
			normal =  {0.21, 0.21, 0.25},
			hovered =  {0.3, 0.3, 0.32},
			pressed =  {0.15, 0.15, 0.17},
			transparent = {1, 1, 1, 0},
			normalText = {1, 1, 1, 0.75},
			hoveredText = {1, 1, 1, 1},
			pressedText = {1, 1, 1, 0.5},
		}

		-- Base button (no contents)
		default:setDrawable(BaseButton, "", DrawBaseButton(buttonColors.normal, 4))
		default:setDrawable(BaseButton, "hovered", DrawBaseButton(buttonColors.hovered, 4))
		default:setDrawable(BaseButton, "pressed", DrawBaseButton(buttonColors.pressed, 4))
		default:setVariant(BaseButton, "", {
			normal = "",
			hovered = "hovered",
			pressed = "pressed",
			focused = "hovered",
		})

		-- Button (with contents)
		default:setDrawable(Button, "", DrawButton(buttonColors.normal, 4, nil, buttonColors.normalText))
		default:setDrawable(Button, "hovered", DrawButton(buttonColors.hovered, 4, nil, buttonColors.hoveredText))
		default:setDrawable(Button, "pressed", DrawButton(buttonColors.pressed, 4, nil, buttonColors.pressedText))

		default:setVariant(Button, "flat", {
			normal = "flatnormal",
			hovered = "flathovered",
			focused = "flathovered",
			pressed = "flatpressed",
		})
		default:setDrawable(Button, "flatnormal", DrawButton(buttonColors.transparent, 4, nil, buttonColors.normalText))
		default:setDrawable(Button, "flathovered", DrawButton(buttonColors.transparent, 4, nil, buttonColors.pressedText))
		default:setDrawable(Button, "flatpressed", DrawButton(buttonColors.transparent, 4, nil, buttonColors.pressedText))

		-- TextureButton
		default:setDrawable(TextureButton, "", DrawTextureButton(buttonColors.normal, 4, nil, {1, 1, 1, 0.75}))
		default:setDrawable(TextureButton, "hovered", DrawTextureButton(buttonColors.hovered, 4))
		default:setDrawable(TextureButton, "pressed", DrawTextureButton(buttonColors.pressed, 4, nil, {1, 1, 1, 0.5}))

		-- LineEdit
		default:setDrawable(LineEdit, "", DrawLineEdit(buttonColors.normal))

		-- TabBar
		default:setDrawable(TabBar, "", DrawTabBar())

		-- TabContainer
		default:setDrawable(TabContainer, "", DrawTabContainer())
	end

	default:setDrawable(Label, "", DrawLabel())
	default:setDrawable(TextureRect, "", DrawTexture())

	return default
end

return onRequire
