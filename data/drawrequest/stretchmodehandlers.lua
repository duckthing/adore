---@type {[TextureRect.StretchMode]: fun(rect: TextureRect, tSource: TextureSource)}
local stretchModeHandler = {
	scale = function (rect, texture)
		-- Scale to fit the bounding rectangle
		local lcr = rect._localContentRect
		local w, h = lcr.w, lcr.h
		local _, _, texW, texH = texture.quad:getViewport()
		rect._textureX, rect._textureY, rect._textureScaleX, rect._textureScaleY =
			0, 0,
			w / texW, h / texH
	end,
	tile = function (rect, texture)
		-- Tile inside the bounding rectangle
		texture.texture:setWrap("repeat", "repeat")
		rect._textureX, rect._textureY, rect._textureScaleX, rect._textureScaleY =
			0, 0,
			1, 1
	end,
	keep = function (rect, texture)
		-- Keep original size, and puts the texture at the top-left corner
		texture.texture:setWrap("clamp", "clamp")
		rect._textureX, rect._textureY, rect._textureScaleX, rect._textureScaleY =
			0, 0,
			1, 1
	end,
	keepCentered = function (rect, texture)
		-- Keep original size, and puts the texture in the center
		local lcr = rect._localContentRect
		local w, h = lcr.w, lcr.h
		local _, _, texW, texH = texture.quad:getViewport()
		texture.texture:setWrap("clamp", "clamp")
		rect._textureX, rect._textureY, rect._textureScaleX, rect._textureScaleY =
			(w - texW) * 0.5, (h - texH) * 0.5,
			1, 1
	end,
	keepAspect = function (rect, texture)
		-- Scales and keeps the original aspect ratio, and puts the texture in the top-left
		local lcr = rect._localContentRect
		local w, h = lcr.w, lcr.h
		local _, _, texW, texH = texture.quad:getViewport()
		local ratio = math.min(w / texW, h / texH)
		texture.texture:setWrap("clamp", "clamp")
		rect._textureX, rect._textureY, rect._textureScaleX, rect._textureScaleY =
			0, 0,
			ratio, ratio
	end,
	keepAspectCentered = function (rect, texture)
		-- Scales and keeps the original aspect ratio, and puts the texture in the center
		local lcr = rect._localContentRect
		local w, h = lcr.w, lcr.h
		local _, _, texW, texH = texture.quad:getViewport()
		local ratio = math.min(w / texW, h / texH)
		texture.texture:setWrap("clamp", "clamp")
		rect._textureX, rect._textureY, rect._textureScaleX, rect._textureScaleY =
			(w - texW * ratio) * 0.5, (h - texH * ratio) * 0.5,
			ratio, ratio
	end,
}

return stretchModeHandler
