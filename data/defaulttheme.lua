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
	local PopupMenu = Nodes("PopupMenu")
	local WindowPopup = Nodes("WindowPopup")

	local Box = Resources("DrawRequest.Box")
	local DrawLabel = Resources("DrawRequest.Label")
	local DrawTexture = Resources("DrawRequest.TextureRect")
	local DrawBaseButton = Resources("DrawRequest.BaseButton")
	local DrawButton = Resources("DrawRequest.Button")
	local DrawTextureButton = Resources("DrawRequest.TextureButton")
	local DrawLineEdit = Resources("DrawRequest.LineEdit")
	local DrawNinePatchRect = Resources("DrawRequest.NinePatchRect")
	local DrawTabBar = Resources("DrawRequest.TabBar")
	local DrawPopupMenu = Resources("DrawRequest.PopupMenu")
	local DrawWindowPopup = Resources("DrawRequest.WindowPopup")

	local default = Theme()

	default:setDrawable(ColorRect, nil, Box())
	default:setDrawable(NinePatchRect, nil, DrawNinePatchRect())

	do
		local buttonColors = {
			normal =  {0.21, 0.21, 0.25},
			hovered =  {0.3, 0.3, 0.32},
			pressed =  {0.15, 0.15, 0.17},
			disabled =  {0.12, 0.12, 0.14},
			transparent = {1, 1, 1, 0},
			normalText = {1, 1, 1, 0.75},
			hoveredText = {1, 1, 1, 1},
			pressedText = {1, 1, 1, 0.5},
			disabledText = {1, 1, 1, 0.4},
		}

		-- Base button (no contents)
		default:setDrawable(BaseButton, "", DrawBaseButton(buttonColors.normal, 4))
		default:setDrawable(BaseButton, "hovered", DrawBaseButton(buttonColors.hovered, 4))
		default:setDrawable(BaseButton, "pressed", DrawBaseButton(buttonColors.pressed, 4))
		default:setDrawable(BaseButton, "disabled", DrawBaseButton(buttonColors.disabled, 4))
		default:setVariant(BaseButton, "", {
			normal = "",
			hovered = "hovered",
			focused = "hovered",
			pressed = "pressed",
			disabled = "disabled",
		})

		-- Button (with contents)
		do
			-- Normal variant

			---@param dr DrawRequest.Button
			---@return DrawRequest.Button
			local function wm(dr)
				-- Applies the margin
				dr:setContentMargin(8, 8)
				return dr
			end
			default:setDrawable(Button, "", wm(DrawButton(buttonColors.normal, 4, nil, buttonColors.normalText)))
			default:setDrawable(Button, "hovered", wm(DrawButton(buttonColors.hovered, 4, nil, buttonColors.hoveredText)))
			default:setDrawable(Button, "pressed", wm(DrawButton(buttonColors.pressed, 4, nil, buttonColors.pressedText)))
			default:setDrawable(Button, "disabled", wm(DrawButton(buttonColors.disabled, 4, nil, buttonColors.disabledText)))

			-- Flat variant
			default:setVariant(Button, "flat", {
				normal = "flatnormal",
				hovered = "flathovered",
				focused = "flathovered",
				pressed = "flatpressed",
				disabled = "flatdisabled",
			})
			default:setDrawable(Button, "flatnormal", DrawButton(buttonColors.transparent, 4, nil, buttonColors.normalText))
			default:setDrawable(Button, "flathovered", DrawButton(buttonColors.transparent, 4, nil, buttonColors.hoveredText))
			default:setDrawable(Button, "flatpressed", DrawButton(buttonColors.transparent, 4, nil, buttonColors.pressedText))
			default:setDrawable(Button, "flatdisabled", DrawButton(buttonColors.transparent, 4, nil, buttonColors.disabledText))
		end

		-- TextureButton
		default:setDrawable(TextureButton, "", DrawTextureButton(nil, 4, buttonColors.normalText))
		default:setDrawable(TextureButton, "hovered", DrawTextureButton(nil, 4, buttonColors.hoveredText))
		default:setDrawable(TextureButton, "pressed", DrawTextureButton(nil, 4, buttonColors.pressedText))
		default:setDrawable(TextureButton, "disabled", DrawTextureButton(nil, 4, buttonColors.disabledText))

		-- LineEdit
		default:setDrawable(LineEdit, "", DrawLineEdit(buttonColors.normal):setContentMargin(8, 8))

		-- TabBar
		default:setDrawable(TabBar, "", DrawTabBar())

		-- PopupMenu
		default:setDrawable(PopupMenu, "", DrawPopupMenu())

		-- WindowPopup
		default:setDrawable(WindowPopup, "", DrawWindowPopup())
	end

	default:setDrawable(Label, "", DrawLabel())
	default:setDrawable(TextureRect, "", DrawTexture())

	return default
end

return onRequire
