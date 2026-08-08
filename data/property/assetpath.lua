local Property = require "data.property"
---@type Adore.Loader
local Loader = require "loader"

---@class Property.AssetPath: Property
local AssetP = Property:extend()
AssetP.TYPE = "AssetPath"

function AssetP:new(class, property, collectionName, defaultValue, setter)
	AssetP.super.new(self, class, property, defaultValue or class[property] or "")

	---@type string # The collection
	self.collectionName = collectionName

	if setter then self:withSetter(setter) end
end

function AssetP:add(a, b)
	return a
end

function AssetP:serialize(obj, propertyName, value, resources)
	if value then
		local collection = Loader.getCollection(self.collectionName)
		local path, _ = collection:getAssetPath(value)

		if path then
			return path
		else
			print(
				("[Property.AssetPath] Couldn't find the path for the asset in %s (on %s:%s)")
				:format(self.collectionName, tostring(obj), propertyName)
			)
		end
	end
end

function AssetP:deserialize(obj, propertyName, deserializedValue, resources)
	if deserializedValue ~= "" then
		local collection = Loader.getCollection(self.collectionName)
		local asset = collection:get(deserializedValue)
		if asset then
			self:set(obj, propertyName, asset)
		end
	end
end

return AssetP
