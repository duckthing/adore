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
		}

		-- Base button (no contents)
		default:setDrawable(BaseButton, nil, DrawBaseButton(buttonColors.normal, 4))
		default:setDrawable(BaseButton, "hovered", DrawBaseButton(buttonColors.hovered, 4))
		default:setDrawable(BaseButton, "pressed", DrawBaseButton(buttonColors.pressed, 4))

		-- Button (with contents)
		default:setDrawable(Button, nil, DrawButton(buttonColors.normal, 4, nil, {1, 1, 1, 0.75}))
		default:setDrawable(Button, "hovered", DrawButton(buttonColors.hovered, 4))
		default:setDrawable(Button, "pressed", DrawButton(buttonColors.pressed, 4, nil, {1, 1, 1, 0.5}))

		-- TextureButton
		default:setDrawable(TextureButton, nil, DrawTextureButton(buttonColors.normal, 4, nil, {1, 1, 1, 0.75}))
		default:setDrawable(TextureButton, "hovered", DrawTextureButton(buttonColors.hovered, 4))
		default:setDrawable(TextureButton, "pressed", DrawTextureButton(buttonColors.pressed, 4, nil, {1, 1, 1, 0.5}))

		-- LineEdit
		default:setDrawable(LineEdit, nil, DrawLineEdit(buttonColors.normal))

		-- TabBar
		default:setDrawable(TabBar, nil, DrawTabBar())

		-- TabContainer
		default:setDrawable(TabContainer, nil, DrawTabContainer())
	end

	default:setDrawable(Label, nil, DrawLabel())
	default:setDrawable(TextureRect, nil, DrawTexture())

	return default
end

return onRequire
